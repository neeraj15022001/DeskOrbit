import Foundation
import Darwin

public final class WizLightService: @unchecked Sendable {
    public static let shared = WizLightService()

    private let udpPort: in_port_t = 38899
    private let storageKey = "DeskOrbit_Saved_WizLights"
    private let smartThingsTokenKey = "DeskOrbit_SmartThings_Token"

    private let workQueue = DispatchQueue(label: "com.deskorbit.smartthings.work", qos: .userInitiated)
    private let udpQueue = DispatchQueue(label: "com.deskorbit.wizlight.udp", qos: .userInitiated)

    public var onLightsChanged: (([WizLightItem]) -> Void)?

    @Published public private(set) var lights: [WizLightItem] = []
    @Published public var smartThingsToken: String = ""
    @Published public var isScanningLocal: Bool = false
    @Published public var isSyncingCloud: Bool = false

    private var pollTimer: Timer?
    private var sequenceId: Int = 1
    private var debounceWorkItems: [String: DispatchWorkItem] = [:]
    private var localUdpDebounceItems: [String: DispatchWorkItem] = [:]

    public init() {
        self.smartThingsToken = UserDefaults.standard.string(forKey: smartThingsTokenKey) ?? ""
        loadSavedLights()
        startPeriodicPoll()

        // Background auto-refresh on launch
        if !self.smartThingsToken.isEmpty {
            fetchSmartThingsDevices()
        }
        discoverLocalLights()
    }

    deinit {
        pollTimer?.invalidate()
    }

    // MARK: - SmartThings Token Configuration

    public func setSmartThingsToken(_ token: String) {
        self.smartThingsToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        UserDefaults.standard.set(self.smartThingsToken, forKey: smartThingsTokenKey)
        if !self.smartThingsToken.isEmpty {
            fetchSmartThingsDevices()
        }
    }

    // MARK: - Persistence

    private func loadSavedLights() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode([WizLightItem].self, from: data) {
            self.lights = saved
            onLightsChanged?(self.lights)
        }
    }

    private func saveLights() {
        if let data = try? JSONEncoder().encode(lights) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    // MARK: - Periodic Status Polling

    private func startPeriodicPoll() {
        DispatchQueue.main.async { [weak self] in
            self?.pollTimer?.invalidate()
            self?.pollTimer = Timer.scheduledTimer(withTimeInterval: 12.0, repeats: true) { [weak self] _ in
                self?.refreshAllLights()
            }
        }
    }

    public func refreshAllLights() {
        let currentLights = self.lights
        guard !currentLights.isEmpty else { return }

        // 1. Poll SmartThings cloud status
        if !smartThingsToken.isEmpty {
            for light in currentLights where light.hasCloudConnection {
                let targetId = resolveSmartThingsDeviceId(for: light)
                pollSmartThingsStatus(deviceId: targetId)
            }
        }

        // 2. Poll local UDP status for Wi-Fi connected bulbs
        udpQueue.async { [weak self] in
            guard let self = self else { return }
            for light in currentLights where light.hasLocalConnection {
                if let pilot = self.fetchPilot(ip: light.ip) {
                    DispatchQueue.main.async {
                        guard let idx = self.lights.firstIndex(where: { $0.id == light.id }) else { return }
                        var mod = self.lights[idx]
                        if let st = pilot.state { mod.isOn = st }
                        if let dim = pilot.dimming { mod.brightness = dim }
                        if let temp = pilot.temp {
                            mod.colorTemperature = temp
                            let rgb = self.kelvinToRGB(kelvin: temp)
                            mod.red = rgb.r; mod.green = rgb.g; mod.blue = rgb.b
                        } else if let r = pilot.r, let g = pilot.g, let b = pilot.b {
                            mod.red = r; mod.green = g; mod.blue = b
                            mod.colorTemperature = nil
                        }
                        mod.isReachable = true
                        if mod != self.lights[idx] {
                            self.lights[idx] = mod
                            self.saveLights()
                            self.onLightsChanged?(self.lights)
                        }
                    }
                } else if !light.hasCloudConnection {
                    // Mark unreachable only if it has no cloud fallback
                    DispatchQueue.main.async {
                        if let idx = self.lights.firstIndex(where: { $0.id == light.id }), self.lights[idx].isReachable {
                            self.lights[idx].isReachable = false
                            self.saveLights()
                            self.onLightsChanged?(self.lights)
                        }
                    }
                }
            }
        }
    }

    private func pollSmartThingsStatus(deviceId: String) {
        guard !smartThingsToken.isEmpty,
              let url = URL(string: "https://api.smartthings.com/v1/devices/\(deviceId)/status") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 8.0
        request.setValue("Bearer \(smartThingsToken)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self, let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let components = json["components"] as? [String: Any],
                  let main = components["main"] as? [String: Any] else { return }

            var isOn: Bool?
            if let switchComp = main["switch"] as? [String: Any],
               let switchVal = switchComp["switch"] as? [String: Any],
               let valStr = switchVal["value"] as? String {
                isOn = (valStr.lowercased() == "on")
            }

            var brightness: Int?
            if let levelComp = main["switchLevel"] as? [String: Any],
               let levelVal = levelComp["level"] as? [String: Any],
               let bVal = levelVal["value"] as? Int {
                brightness = bVal
            }

            var tempKelvin: Int?
            if let tempComp = main["colorTemperature"] as? [String: Any],
               let tempVal = tempComp["colorTemperature"] as? [String: Any],
               let kVal = tempVal["value"] as? Int {
                tempKelvin = kVal
            }

            var hue: Double?
            var sat: Double?
            if let colorComp = main["colorControl"] as? [String: Any] {
                if let hueObj = colorComp["hue"] as? [String: Any],
                   let hNum = hueObj["value"] as? NSNumber {
                    hue = hNum.doubleValue
                }
                if let satObj = colorComp["saturation"] as? [String: Any],
                   let sNum = satObj["value"] as? NSNumber {
                    sat = sNum.doubleValue
                }
            }

            DispatchQueue.main.async {
                guard let idx = self.lights.firstIndex(where: { $0.id == deviceId || $0.smartThingsDeviceId == deviceId }) else { return }
                var modified = self.lights[idx]
                if let o = isOn { modified.isOn = o }
                if let b = brightness { modified.brightness = b }
                if let k = tempKelvin {
                    modified.colorTemperature = k
                    let rgb = self.kelvinToRGB(kelvin: k)
                    modified.red = rgb.r
                    modified.green = rgb.g
                    modified.blue = rgb.b
                } else if let h = hue, let s = sat {
                    let rgb = self.hueSaturationToRGB(huePercent: h, satPercent: s)
                    modified.red = rgb.r
                    modified.green = rgb.g
                    modified.blue = rgb.b
                    modified.colorTemperature = nil
                }
                modified.isReachable = true
                if modified != self.lights[idx] {
                    self.lights[idx] = modified
                    self.saveLights()
                    self.onLightsChanged?(self.lights)
                }
            }
        }.resume()
    }

    // MARK: - Direct WiZ Local Integration (UDP 38899)

    public func discoverLocalLights(completion: (([WizLightItem]) -> Void)? = nil) {
        DispatchQueue.main.async { self.isScanningLocal = true }

        udpQueue.async { [weak self] in
            guard let self = self else { return }
            let msg = "{\"method\":\"getSystemConfig\",\"params\":{}}"
            let responses = self.sendUDPBroadcast(message: msg, timeoutSeconds: 2.0)

            var discovered: [WizLightItem] = []

            for (ip, respStr) in responses {
                if let data = respStr.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let result = json["result"] as? [String: Any] {
                    let mac = (result["mac"] as? String) ?? UUID().uuidString
                    let module = (result["moduleName"] as? String) ?? "Philips WiZ Bulb"
                    let fw = result["fwVersion"] as? String

                    self.registerWithBulb(ip: ip)
                    let pilot = self.fetchPilot(ip: ip)

                    let item = WizLightItem(
                        id: mac,
                        ip: ip,
                        name: module,
                        mac: mac,
                        isOn: pilot?.state ?? true,
                        brightness: pilot?.dimming ?? 100,
                        red: pilot?.r ?? 255,
                        green: pilot?.g ?? 214,
                        blue: pilot?.b ?? 170,
                        colorTemperature: pilot?.temp ?? 2700,
                        smartThingsDeviceId: nil,
                        isReachable: true,
                        firmwareVersion: fw,
                        moduleModel: module
                    )
                    discovered.append(item)
                }
            }

            DispatchQueue.main.async {
                self.isScanningLocal = false
                for disc in discovered {
                    // Check if already in list (by MAC, IP, or matching Cloud bulb)
                    if let idx = self.lights.firstIndex(where: {
                        $0.id == disc.id ||
                        $0.mac.lowercased() == disc.mac.lowercased() ||
                        $0.ip == disc.ip ||
                        ($0.name.lowercased() == disc.name.lowercased() && !$0.hasLocalConnection)
                    }) {
                        // Merge into existing item: promote to Hybrid if it had SmartThings!
                        var existing = self.lights[idx]
                        existing.ip = disc.ip
                        existing.mac = disc.mac
                        existing.isReachable = true
                        if existing.firmwareVersion == nil { existing.firmwareVersion = disc.firmwareVersion }
                        if existing.moduleModel == nil { existing.moduleModel = disc.moduleModel }
                        self.lights[idx] = existing
                    } else {
                        self.lights.append(disc)
                    }
                }
                self.saveLights()
                self.onLightsChanged?(self.lights)
                completion?(discovered)
            }
        }
    }

    public func addDirectLight(ip: String, customName: String? = nil, completion: @escaping (Result<WizLightItem, Error>) -> Void) {
        let trimmedIP = ip.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedIP.isEmpty else {
            completion(.failure(NSError(domain: "WizLightService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Please enter a valid IP address."])))
            return
        }

        udpQueue.async { [weak self] in
            guard let self = self else { return }

            self.registerWithBulb(ip: trimmedIP)
            let sysConfig = self.fetchSystemConfig(ip: trimmedIP)
            let pilot = self.fetchPilot(ip: trimmedIP)

            if sysConfig == nil && pilot == nil {
                DispatchQueue.main.async {
                    completion(.failure(NSError(
                        domain: "WizLightService",
                        code: 404,
                        userInfo: [NSLocalizedDescriptionKey: "Bulb at \(trimmedIP) did not respond over UDP port 38899.\n\nTips:\n1. Ensure Mac and bulb are on the same Wi-Fi.\n2. In the WiZ App, go to Settings → Security & Privacy → Enable 'Local network communication'."]
                    )))
                }
                return
            }

            let mac = sysConfig?.mac ?? pilot?.mac ?? UUID().uuidString.prefix(12).lowercased()
            let defaultName = sysConfig?.moduleName ?? "Philips WiZ A60 Bulb"
            let finalName = (customName?.isEmpty == false) ? customName! : defaultName

            var item = WizLightItem(
                id: mac,
                ip: trimmedIP,
                name: finalName,
                mac: mac,
                isOn: pilot?.state ?? true,
                brightness: pilot?.dimming ?? 100,
                red: pilot?.r ?? 255,
                green: pilot?.g ?? 214,
                blue: pilot?.b ?? 170,
                colorTemperature: pilot?.temp ?? 2700,
                smartThingsDeviceId: nil,
                isReachable: true,
                firmwareVersion: sysConfig?.fwVersion,
                moduleModel: sysConfig?.moduleName
            )

            DispatchQueue.main.async {
                // If a bulb with matching MAC, IP, or same name exists, merge them!
                if let idx = self.lights.firstIndex(where: {
                    $0.id == item.id ||
                    $0.mac.lowercased() == item.mac.lowercased() ||
                    $0.ip == item.ip ||
                    ($0.name.lowercased() == item.name.lowercased() && !$0.hasLocalConnection)
                }) {
                    var existing = self.lights[idx]
                    existing.ip = item.ip
                    existing.mac = item.mac
                    existing.isReachable = true
                    existing.firmwareVersion = item.firmwareVersion
                    existing.moduleModel = item.moduleModel
                    if customName?.isEmpty == false { existing.name = customName! }
                    self.lights[idx] = existing
                    item = existing
                } else {
                    self.lights.append(item)
                }
                self.saveLights()
                self.onLightsChanged?(self.lights)
                completion(.success(item))
            }
        }
    }

    public func linkLocalIP(bulbId: String, ip: String, completion: @escaping (Result<WizLightItem, Error>) -> Void) {
        let trimmedIP = ip.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedIP.isEmpty else {
            completion(.failure(NSError(domain: "WizLightService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid IP address."])))
            return
        }

        udpQueue.async { [weak self] in
            guard let self = self else { return }

            self.registerWithBulb(ip: trimmedIP)
            let sysConfig = self.fetchSystemConfig(ip: trimmedIP)
            let pilot = self.fetchPilot(ip: trimmedIP)

            if sysConfig == nil && pilot == nil {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "WizLightService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Bulb at \(trimmedIP) did not respond. Check WiZ App → Settings → Local network communication."])))
                }
                return
            }

            DispatchQueue.main.async {
                guard let idx = self.lights.firstIndex(where: { $0.id == bulbId }) else {
                    completion(.failure(NSError(domain: "WizLightService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Bulb not found in DeskOrbit."])))
                    return
                }

                self.lights[idx].ip = trimmedIP
                if let m = sysConfig?.mac, !m.isEmpty { self.lights[idx].mac = m }
                if let fw = sysConfig?.fwVersion { self.lights[idx].firmwareVersion = fw }
                if let mod = sysConfig?.moduleName { self.lights[idx].moduleModel = mod }
                self.lights[idx].isReachable = true
                self.saveLights()
                self.onLightsChanged?(self.lights)
                completion(.success(self.lights[idx]))
            }
        }
    }

    public func removeLight(id: String) {
        cancelDebounce(for: id)
        lights.removeAll(where: { $0.id == id })
        saveLights()
        onLightsChanged?(lights)
    }

    // MARK: - Dual-Route Light Controls (Direct LAN + SmartThings Cloud)

    public func setPower(for light: WizLightItem, isOn: Bool) {
        cancelDebounce(for: light.id)
        updateLocalState(id: light.id) { $0.isOn = isOn }

        // Route 1: Direct WiZ LAN UDP (instantaneous response)
        if light.hasLocalConnection {
            let id = nextId()
            let payload = "{\"id\":\(id),\"method\":\"setPilot\",\"params\":{\"state\":\(isOn)}}"
            sendLocalUDPCommand(ip: light.ip, payload: payload)
        }

        // Route 2: Samsung SmartThings Cloud API
        if light.hasCloudConnection && !smartThingsToken.isEmpty {
            let targetId = resolveSmartThingsDeviceId(for: light)
            sendSmartThingsCommands(deviceId: targetId, commands: [
                (capability: "switch", command: isOn ? "on" : "off", arguments: [])
            ])
        }
    }

    public func setBrightness(for light: WizLightItem, brightness: Int) {
        let clamped = max(10, min(100, brightness))
        updateLocalState(id: light.id) {
            $0.brightness = clamped
            $0.isOn = true
        }

        // Route 1: Direct WiZ LAN UDP (throttled to 40ms for ultra-smooth slider dragging)
        if light.hasLocalConnection {
            let id = nextId()
            let payload = "{\"id\":\(id),\"method\":\"setPilot\",\"params\":{\"state\":true,\"dimming\":\(clamped)}}"
            debounceLocalUDP(for: light.id, delay: 0.04) { [weak self] in
                self?.sendLocalUDPCommand(ip: light.ip, payload: payload)
            }
        }

        // Route 2: Samsung SmartThings Cloud API (debounced by 250ms to prevent cloud rate-limiting)
        if light.hasCloudConnection && !smartThingsToken.isEmpty {
            let targetId = resolveSmartThingsDeviceId(for: light)
            debounce(for: light.id, delay: 0.25) { [weak self] in
                guard let self = self else { return }
                self.sendSmartThingsCommands(deviceId: targetId, commands: [
                    (capability: "switch", command: "on", arguments: []),
                    (capability: "switchLevel", command: "setLevel", arguments: [clamped])
                ])
            }
        }
    }

    public func setRGBColor(for light: WizLightItem, red: Int, green: Int, blue: Int, brightness: Int? = nil) {
        let r = max(0, min(255, red))
        let g = max(0, min(255, green))
        let b = max(0, min(255, blue))
        let dim = brightness ?? light.brightness

        updateLocalState(id: light.id) {
            $0.red = r
            $0.green = g
            $0.blue = b
            $0.colorTemperature = nil
            $0.brightness = dim
            $0.isOn = true
        }

        // Route 1: Direct WiZ LAN UDP
        if light.hasLocalConnection {
            let id = nextId()
            let payload = "{\"id\":\(id),\"method\":\"setPilot\",\"params\":{\"state\":true,\"dimming\":\(dim),\"r\":\(r),\"g\":\(g),\"b\":\(b)}}"
            debounceLocalUDP(for: light.id, delay: 0.04) { [weak self] in
                self?.sendLocalUDPCommand(ip: light.ip, payload: payload)
            }
        }

        // Route 2: Samsung SmartThings Cloud API
        if light.hasCloudConnection && !smartThingsToken.isEmpty {
            let targetId = resolveSmartThingsDeviceId(for: light)
            let (hue, sat) = rgbToHueSaturation(r: r, g: g, b: b)
            let colorMap: [String: Any] = [
                "hue": hue,
                "saturation": sat
            ]
            debounce(for: light.id, delay: 0.20) { [weak self] in
                guard let self = self else { return }
                self.sendSmartThingsCommands(deviceId: targetId, commands: [
                    (capability: "switch", command: "on", arguments: []),
                    (capability: "colorControl", command: "setColor", arguments: [colorMap])
                ])
            }
        }
    }

    public func setColorTemperature(for light: WizLightItem, kelvin: Int, brightness: Int? = nil) {
        let clampedKelvin = max(2200, min(6500, kelvin))
        let dim = brightness ?? light.brightness
        let approxRGB = kelvinToRGB(kelvin: clampedKelvin)

        updateLocalState(id: light.id) {
            $0.colorTemperature = clampedKelvin
            $0.red = approxRGB.r
            $0.green = approxRGB.g
            $0.blue = approxRGB.b
            $0.brightness = dim
            $0.isOn = true
        }

        // Route 1: Direct WiZ LAN UDP
        if light.hasLocalConnection {
            let id = nextId()
            let payload = "{\"id\":\(id),\"method\":\"setPilot\",\"params\":{\"state\":true,\"dimming\":\(dim),\"temp\":\(clampedKelvin)}}"
            debounceLocalUDP(for: light.id, delay: 0.04) { [weak self] in
                self?.sendLocalUDPCommand(ip: light.ip, payload: payload)
            }
        }

        // Route 2: Samsung SmartThings Cloud API
        if light.hasCloudConnection && !smartThingsToken.isEmpty {
            let targetId = resolveSmartThingsDeviceId(for: light)
            debounce(for: light.id, delay: 0.25) { [weak self] in
                guard let self = self else { return }
                self.sendSmartThingsCommands(deviceId: targetId, commands: [
                    (capability: "switch", command: "on", arguments: []),
                    (capability: "colorTemperature", command: "setColorTemperature", arguments: [clampedKelvin])
                ])
            }
        }
    }

    public func setScene(for light: WizLightItem, sceneId: Int) {
        cancelDebounce(for: light.id)

        // Route 1: Direct WiZ LAN UDP (supports full native scenes: Warm White 11, Daylight 12, Cozy 6, Night Light 14, Fireplace 5, Sunset 9, Party 4)
        if light.hasLocalConnection {
            let id = nextId()
            let payload = "{\"id\":\(id),\"method\":\"setPilot\",\"params\":{\"state\":true,\"sceneId\":\(sceneId)}}"
            sendLocalUDPCommand(ip: light.ip, payload: payload)
        }

        // Route 2: Samsung SmartThings Cloud API
        if light.hasCloudConnection && !smartThingsToken.isEmpty {
            let targetId = resolveSmartThingsDeviceId(for: light)
            var commands: [(capability: String, command: String, arguments: [Any])] = [
                (capability: "switch", command: "on", arguments: [])
            ]

            switch sceneId {
            case 11: // Warm White (2700K)
                commands.append((capability: "colorTemperature", command: "setColorTemperature", arguments: [2700]))
                commands.append((capability: "switchLevel", command: "setLevel", arguments: [100]))
            case 12: // Daylight (5000K)
                commands.append((capability: "colorTemperature", command: "setColorTemperature", arguments: [5000]))
                commands.append((capability: "switchLevel", command: "setLevel", arguments: [100]))
            case 6: // Cozy (2200K)
                commands.append((capability: "colorTemperature", command: "setColorTemperature", arguments: [2200]))
                commands.append((capability: "switchLevel", command: "setLevel", arguments: [80]))
            case 14: // Night Light (2200K, 10% dim)
                commands.append((capability: "colorTemperature", command: "setColorTemperature", arguments: [2200]))
                commands.append((capability: "switchLevel", command: "setLevel", arguments: [10]))
            default:
                break
            }
            sendSmartThingsCommands(deviceId: targetId, commands: commands)
        }

        // Update local state for common scenes
        updateLocalState(id: light.id) {
            $0.isOn = true
            switch sceneId {
            case 11:
                $0.colorTemperature = 2700; $0.brightness = 100
                let rgb = self.kelvinToRGB(kelvin: 2700); $0.red = rgb.r; $0.green = rgb.g; $0.blue = rgb.b
            case 12:
                $0.colorTemperature = 5000; $0.brightness = 100
                let rgb = self.kelvinToRGB(kelvin: 5000); $0.red = rgb.r; $0.green = rgb.g; $0.blue = rgb.b
            case 6:
                $0.colorTemperature = 2200; $0.brightness = 80
                let rgb = self.kelvinToRGB(kelvin: 2200); $0.red = rgb.r; $0.green = rgb.g; $0.blue = rgb.b
            case 14:
                $0.colorTemperature = 2200; $0.brightness = 10
                let rgb = self.kelvinToRGB(kelvin: 2200); $0.red = rgb.r; $0.green = rgb.g; $0.blue = rgb.b
            default:
                break
            }
        }
    }

    private func updateLocalState(id: String, mutate: (inout WizLightItem) -> Void) {
        if let idx = lights.firstIndex(where: { $0.id == id }) {
            mutate(&lights[idx])
            saveLights()
            onLightsChanged?(lights)
        }
    }

    private func nextId() -> Int {
        sequenceId += 1
        return sequenceId
    }

    // MARK: - SmartThings Cloud REST Integration

    public func fetchSmartThingsDevices(completion: (([WizLightItem]) -> Void)? = nil) {
        guard !smartThingsToken.isEmpty,
              let url = URL(string: "https://api.smartthings.com/v1/devices") else {
            completion?([])
            return
        }

        DispatchQueue.main.async { self.isSyncingCloud = true }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10.0
        request.setValue("Bearer \(smartThingsToken)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self, let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let items = json["items"] as? [[String: Any]] else {
                DispatchQueue.main.async {
                    self?.isSyncingCloud = false
                    completion?([])
                }
                return
            }

            var discovered: [WizLightItem] = []
            for item in items {
                guard let deviceId = item["deviceId"] as? String,
                      let label = (item["label"] as? String) ?? (item["name"] as? String) else { continue }

                let newLight = WizLightItem(
                    id: deviceId,
                    ip: "SmartThings Cloud",
                    name: label,
                    mac: deviceId,
                    isOn: true,
                    brightness: 100,
                    red: 255,
                    green: 214,
                    blue: 170,
                    colorTemperature: 2700,
                    smartThingsDeviceId: deviceId,
                    isReachable: true
                )
                discovered.append(newLight)
            }

            DispatchQueue.main.async {
                self.isSyncingCloud = false
                // Intelligently merge: Preserve local Wi-Fi bulbs, upgrading matching ones to Hybrid!
                for disc in discovered {
                    if let idx = self.lights.firstIndex(where: {
                        $0.id == disc.id ||
                        $0.smartThingsDeviceId == disc.id ||
                        ($0.name.lowercased() == disc.name.lowercased() && !$0.hasCloudConnection)
                    }) {
                        self.lights[idx].smartThingsDeviceId = disc.id
                        self.lights[idx].isReachable = true
                    } else {
                        self.lights.append(disc)
                    }
                }
                self.saveLights()
                self.onLightsChanged?(self.lights)
                self.refreshAllLights()
                completion?(discovered)
            }
        }.resume()
    }

    public func resolveSmartThingsDeviceId(for light: WizLightItem) -> String {
        if let stId = light.smartThingsDeviceId, !stId.isEmpty {
            return stId
        }
        if light.id.contains("-") && light.id.count >= 32 {
            return light.id
        }
        if let matched = lights.first(where: { ($0.id.contains("-") && $0.id.count >= 32) && ($0.name.lowercased() == light.name.lowercased() || $0.mac.lowercased() == light.mac.lowercased()) }) {
            return matched.id
        }
        return light.id
    }

    private func sendSmartThingsCommands(deviceId: String, commands: [(capability: String, command: String, arguments: [Any])]) {
        guard !smartThingsToken.isEmpty,
              let url = URL(string: "https://api.smartthings.com/v1/devices/\(deviceId)/commands") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 8.0
        request.setValue("Bearer \(smartThingsToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let cmdDicts: [[String: Any]] = commands.map { item in
            var dict: [String: Any] = [
                "component": "main",
                "capability": item.capability,
                "command": item.command
            ]
            if !item.arguments.isEmpty {
                dict["arguments"] = item.arguments
            }
            return dict
        }

        let body: [String: Any] = ["commands": cmdDicts]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let httpResp = response as? HTTPURLResponse {
                if !(200...299).contains(httpResp.statusCode) {
                    if let data = data, let errStr = String(data: data, encoding: .utf8) {
                        NSLog("[WizLightService] SmartThings error (\(httpResp.statusCode)): \(errStr)")
                    }
                }
            }
        }.resume()
    }

    // MARK: - Low-Level UDP Communications (POSIX Sockets)

    private func sendLocalUDPCommand(ip: String, payload: String) {
        udpQueue.async { [weak self] in
            guard let self = self else { return }
            _ = self.sendUDPUnicast(to: ip, message: payload, timeoutSeconds: 0.5)
        }
    }

    private func debounceLocalUDP(for key: String, delay: TimeInterval, action: @escaping () -> Void) {
        localUdpDebounceItems[key]?.cancel()
        let item = DispatchWorkItem(block: action)
        localUdpDebounceItems[key] = item
        udpQueue.asyncAfter(deadline: .now() + delay, execute: item)
    }

    private func debounce(for key: String, delay: TimeInterval, action: @escaping () -> Void) {
        debounceWorkItems[key]?.cancel()
        let item = DispatchWorkItem(block: action)
        debounceWorkItems[key] = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    private func cancelDebounce(for key: String) {
        debounceWorkItems[key]?.cancel()
        debounceWorkItems.removeValue(forKey: key)
        localUdpDebounceItems[key]?.cancel()
        localUdpDebounceItems.removeValue(forKey: key)
    }

    private func registerWithBulb(ip: String) {
        let reg = "{\"id\":\(nextId()),\"method\":\"registration\",\"params\":{\"register\":true}}"
        _ = sendUDPUnicast(to: ip, message: reg, timeoutSeconds: 0.5)
    }

    private struct PilotResult {
        var state: Bool?
        var dimming: Int?
        var r: Int?
        var g: Int?
        var b: Int?
        var temp: Int?
        var mac: String?
    }

    private struct SystemConfigResult {
        var mac: String?
        var moduleName: String?
        var fwVersion: String?
    }

    private func fetchPilot(ip: String) -> PilotResult? {
        let req = "{\"method\":\"getPilot\",\"params\":{}}"
        guard let resp = sendUDPUnicast(to: ip, message: req, timeoutSeconds: 0.8),
              let data = resp.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let res = json["result"] as? [String: Any] else {
            return nil
        }

        return PilotResult(
            state: res["state"] as? Bool,
            dimming: res["dimming"] as? Int,
            r: res["r"] as? Int,
            g: res["g"] as? Int,
            b: res["b"] as? Int,
            temp: res["temp"] as? Int,
            mac: res["mac"] as? String
        )
    }

    private func fetchSystemConfig(ip: String) -> SystemConfigResult? {
        let req = "{\"method\":\"getSystemConfig\",\"params\":{}}"
        guard let resp = sendUDPUnicast(to: ip, message: req, timeoutSeconds: 0.8),
              let data = resp.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let res = json["result"] as? [String: Any] else {
            return nil
        }

        return SystemConfigResult(
            mac: res["mac"] as? String,
            moduleName: res["moduleName"] as? String,
            fwVersion: res["fwVersion"] as? String
        )
    }

    private func sendUDPUnicast(to ip: String, message: String, timeoutSeconds: Double = 0.8) -> String? {
        let sock = socket(AF_INET, SOCK_DGRAM, 0)
        guard sock >= 0 else { return nil }
        defer { close(sock) }

        var tv = timeval(
            tv_sec: Int(timeoutSeconds),
            tv_usec: Int32((timeoutSeconds.truncatingRemainder(dividingBy: 1.0)) * 1_000_000)
        )
        setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = udpPort.bigEndian
        addr.sin_addr.s_addr = inet_addr(ip)

        let sent = message.withCString { cstr in
            withUnsafePointer(to: &addr) { ptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                    sendto(sock, cstr, strlen(cstr), 0, sa, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }

        guard sent > 0 else { return nil }

        var buffer = [UInt8](repeating: 0, count: 2048)
        var srcAddr = sockaddr_in()
        var srcLen = socklen_t(MemoryLayout<sockaddr_in>.size)

        let received = withUnsafeMutablePointer(to: &srcAddr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                recvfrom(sock, &buffer, buffer.count, 0, sa, &srcLen)
            }
        }

        if received > 0 {
            return String(bytes: buffer[..<received], encoding: .utf8)
        }
        return nil
    }

    private func sendUDPBroadcast(message: String, timeoutSeconds: Double = 1.8) -> [(ip: String, response: String)] {
        let sock = socket(AF_INET, SOCK_DGRAM, 0)
        guard sock >= 0 else { return [] }
        defer { close(sock) }

        var broadcastEnable: Int32 = 1
        setsockopt(sock, SOL_SOCKET, SO_BROADCAST, &broadcastEnable, socklen_t(MemoryLayout<Int32>.size))

        var tv = timeval(
            tv_sec: 0,
            tv_usec: 350_000 // 350ms slice
        )
        setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))

        let targets = getBroadcastAddresses()

        for target in targets {
            var addr = sockaddr_in()
            addr.sin_family = sa_family_t(AF_INET)
            addr.sin_port = udpPort.bigEndian
            addr.sin_addr.s_addr = inet_addr(target)

            _ = message.withCString { cstr in
                withUnsafePointer(to: &addr) { ptr in
                    ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                        sendto(sock, cstr, strlen(cstr), 0, sa, socklen_t(MemoryLayout<sockaddr_in>.size))
                    }
                }
            }
        }

        var results: [(ip: String, response: String)] = []
        var seenIPs = Set<String>()
        let startTime = Date()

        while Date().timeIntervalSince(startTime) < timeoutSeconds {
            var buffer = [UInt8](repeating: 0, count: 2048)
            var srcAddr = sockaddr_in()
            var srcLen = socklen_t(MemoryLayout<sockaddr_in>.size)

            let received = withUnsafeMutablePointer(to: &srcAddr) { ptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                    recvfrom(sock, &buffer, buffer.count, 0, sa, &srcLen)
                }
            }

            if received > 0 {
                let respStr = String(bytes: buffer[..<received], encoding: .utf8) ?? ""
                var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                let nameRes = withUnsafePointer(to: &srcAddr) { ptr in
                    ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                        getnameinfo(sa, srcLen, &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST)
                    }
                }
                if nameRes == 0 {
                    let senderIP = String(cString: host)
                    if !seenIPs.contains(senderIP) {
                        seenIPs.insert(senderIP)
                        results.append((ip: senderIP, response: respStr))
                    }
                }
            }
        }

        return results
    }

    private func getBroadcastAddresses() -> [String] {
        var targets = ["255.255.255.255"]

        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
            return targets
        }
        defer { freeifaddrs(ifaddr) }

        var ptr = Optional(firstAddr)
        while let p = ptr {
            let flags = Int32(p.pointee.ifa_flags)
            let isUp = (flags & IFF_UP) != 0
            let isRunning = (flags & IFF_RUNNING) != 0
            let isBroadcast = (flags & IFF_BROADCAST) != 0
            let isLoopback = (flags & IFF_LOOPBACK) != 0

            if isUp && isRunning && isBroadcast && !isLoopback,
               let addr = p.pointee.ifa_dstaddr,
               addr.pointee.sa_family == sa_family_t(AF_INET) {
                var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                let sockLen = socklen_t(MemoryLayout<sockaddr_in>.size)
                let res = addr.withMemoryRebound(to: sockaddr.self, capacity: 1) { saPtr in
                    getnameinfo(saPtr, sockLen, &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST)
                }
                if res == 0 {
                    let str = String(cString: host)
                    if !targets.contains(str) {
                        targets.append(str)
                    }
                }
            }
            ptr = p.pointee.ifa_next
        }

        return targets
    }

    // MARK: - Color Conversion Helpers

    public func rgbToHueSaturation(r: Int, g: Int, b: Int) -> (hue: Double, saturation: Double) {
        let rf = Double(r) / 255.0
        let gf = Double(g) / 255.0
        let bf = Double(b) / 255.0

        let maxVal = max(rf, gf, bf)
        let minVal = min(rf, gf, bf)
        let delta = maxVal - minVal

        var h: Double = 0.0
        if delta == 0 {
            h = 0.0
        } else if maxVal == rf {
            h = 60.0 * (((gf - bf) / delta).truncatingRemainder(dividingBy: 6.0))
        } else if maxVal == gf {
            h = 60.0 * (((bf - rf) / delta) + 2.0)
        } else {
            h = 60.0 * (((rf - gf) / delta) + 4.0)
        }
        if h < 0 {
            h += 360.0
        }

        let s: Double = maxVal == 0 ? 0 : (delta / maxVal)

        let huePercent = (h / 360.0) * 100.0
        let satPercent = s * 100.0
        return (round(huePercent * 10.0) / 10.0, round(satPercent * 10.0) / 10.0)
    }

    public func hueSaturationToRGB(huePercent: Double, satPercent: Double) -> (r: Int, g: Int, b: Int) {
        let h = (huePercent / 100.0) * 360.0
        let s = satPercent / 100.0
        let v = 1.0

        let c = v * s
        let x = c * (1 - abs((h / 60.0).truncatingRemainder(dividingBy: 2.0) - 1))
        let m = v - c

        var r1 = 0.0, g1 = 0.0, b1 = 0.0
        if h < 60 {
            r1 = c; g1 = x; b1 = 0
        } else if h < 120 {
            r1 = x; g1 = c; b1 = 0
        } else if h < 180 {
            r1 = 0; g1 = c; b1 = x
        } else if h < 240 {
            r1 = 0; g1 = x; b1 = c
        } else if h < 300 {
            r1 = x; g1 = 0; b1 = c
        } else {
            r1 = c; g1 = 0; b1 = x
        }

        return (
            max(0, min(255, Int((r1 + m) * 255))),
            max(0, min(255, Int((g1 + m) * 255))),
            max(0, min(255, Int((b1 + m) * 255)))
        )
    }

    public func kelvinToRGB(kelvin: Int) -> (r: Int, g: Int, b: Int) {
        let temp = Double(kelvin) / 100.0
        var r: Double
        var g: Double
        var b: Double

        if temp <= 66 {
            r = 255
            g = 99.4708025861 * log(temp) - 161.1195681661
            b = temp <= 19 ? 0 : 138.5177312231 * log(temp - 10) - 305.0447927307
        } else {
            r = 329.698727446 * pow(temp - 60, -0.1332047592)
            g = 288.1221695283 * pow(temp - 60, -0.0755148492)
            b = 255
        }

        return (
            r: max(0, min(255, Int(r))),
            g: max(0, min(255, Int(g))),
            b: max(0, min(255, Int(b)))
        )
    }
}
