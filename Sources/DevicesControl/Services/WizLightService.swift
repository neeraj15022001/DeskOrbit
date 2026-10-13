import Foundation
import Darwin

public final class WizLightService {
    public static let shared = WizLightService()

    private let udpPort: in_port_t = 38899
    private let storageKey = "DeskOrbit_Saved_WizLights"
    private let smartThingsTokenKey = "DeskOrbit_SmartThings_Token"
    private let queue = DispatchQueue(label: "com.deskorbit.wizlight", qos: .userInitiated)

    public var onLightsChanged: (([WizLightItem]) -> Void)?

    @Published public private(set) var lights: [WizLightItem] = []
    @Published public var smartThingsToken: String = ""

    private var pollTimer: Timer?
    private var sequenceId: Int = 1

    public init() {
        self.smartThingsToken = UserDefaults.standard.string(forKey: smartThingsTokenKey) ?? ""
        loadSavedLights()
        startPeriodicPoll()
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

    // MARK: - Periodic Polling

    private func startPeriodicPoll() {
        DispatchQueue.main.async { [weak self] in
            self?.pollTimer?.invalidate()
            self?.pollTimer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: true) { [weak self] _ in
                self?.refreshAllLights()
            }
        }
    }

    public func refreshAllLights() {
        queue.async { [weak self] in
            guard let self = self else { return }
            var updated = self.lights
            var didChange = false

            for i in 0..<updated.count {
                let light = updated[i]
                if let pilot = self.fetchPilot(ip: light.ip) {
                    var modified = light
                    modified.isOn = pilot.state ?? modified.isOn
                    modified.brightness = pilot.dimming ?? modified.brightness
                    if let r = pilot.r, let g = pilot.g, let b = pilot.b {
                        modified.red = r
                        modified.green = g
                        modified.blue = b
                    }
                    modified.colorTemperature = pilot.temp
                    modified.isReachable = true
                    if modified != light {
                        updated[i] = modified
                        didChange = true
                    }
                } else {
                    if updated[i].isReachable {
                        updated[i].isReachable = false
                        didChange = true
                    }
                }
            }

            if didChange {
                DispatchQueue.main.async {
                    self.lights = updated
                    self.saveLights()
                    self.onLightsChanged?(self.lights)
                }
            }
        }
    }

    // MARK: - Light Management

    public func addLight(ip: String, customName: String? = nil, completion: @escaping (Result<WizLightItem, Error>) -> Void) {
        queue.async { [weak self] in
            guard let self = self else { return }
            let trimmedIP = ip.trimmingCharacters(in: .whitespacesAndNewlines)

            // Register with bulb first
            self.registerWithBulb(ip: trimmedIP)

            let sysConfig = self.fetchSystemConfig(ip: trimmedIP)
            let pilot = self.fetchPilot(ip: trimmedIP)

            if sysConfig == nil && pilot == nil {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "WizLightService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Bulb at \(trimmedIP) did not respond over UDP 38899. Verify Mac and bulb are on the same Wi-Fi network."])))
                }
                return
            }

            let mac = sysConfig?.mac ?? pilot?.mac ?? UUID().uuidString.prefix(12).lowercased()
            let defaultName = sysConfig?.moduleName ?? "Philips WiZ A60 Bulb"
            let finalName = (customName?.isEmpty == false) ? customName! : defaultName

            let item = WizLightItem(
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
                isReachable: true
            )

            DispatchQueue.main.async {
                if let idx = self.lights.firstIndex(where: { $0.id == item.id || $0.ip == item.ip }) {
                    self.lights[idx] = item
                } else {
                    self.lights.append(item)
                }
                self.saveLights()
                self.onLightsChanged?(self.lights)
                completion(.success(item))
            }
        }
    }

    public func removeLight(id: String) {
        lights.removeAll(where: { $0.id == id })
        saveLights()
        onLightsChanged?(lights)
    }

    // MARK: - Discovery

    public func discoverLights(completion: @escaping ([WizLightItem]) -> Void) {
        queue.async { [weak self] in
            guard let self = self else { return }
            let msg = "{\"method\":\"getSystemConfig\",\"params\":{}}"
            let responses = self.sendUDPBroadcast(message: msg, timeoutSeconds: 2.5)

            var discovered: [WizLightItem] = []

            for (ip, respStr) in responses {
                if let data = respStr.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let result = json["result"] as? [String: Any] {
                    let mac = (result["mac"] as? String) ?? UUID().uuidString
                    let module = (result["moduleName"] as? String) ?? "Philips WiZ A60 Bulb"

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
                        colorTemperature: pilot?.temp,
                        isReachable: true
                    )
                    discovered.append(item)
                }
            }

            DispatchQueue.main.async {
                for item in discovered {
                    if let idx = self.lights.firstIndex(where: { $0.id == item.id || $0.ip == item.ip }) {
                        self.lights[idx] = item
                    } else {
                        self.lights.append(item)
                    }
                }
                self.saveLights()
                self.onLightsChanged?(self.lights)
                completion(discovered)
            }
        }
    }

    // MARK: - Light Controls

    public func setPower(for light: WizLightItem, isOn: Bool) {
        updateLocalState(id: light.id) { $0.isOn = isOn }

        queue.async { [weak self] in
            guard let self = self else { return }
            let id = self.nextId()

            // JSON-RPC 2.0 with ID format (required by WiZ 1.25+ firmwares)
            let payloadWithId = "{\"id\":\(id),\"method\":\"setPilot\",\"params\":{\"state\":\(isOn)}}"
            // Legacy format fallback
            let payloadLegacy = "{\"method\":\"setPilot\",\"params\":{\"state\":\(isOn)}}"

            self.sendUDPBurst(to: light.ip, messages: [payloadWithId, payloadLegacy])

            // If SmartThings token is configured, also send via SmartThings Cloud
            if !self.smartThingsToken.isEmpty {
                let targetId = self.resolveSmartThingsDeviceId(for: light)
                self.sendSmartThingsCommand(deviceId: targetId, capability: "switch", command: isOn ? "on" : "off")
            }
        }
    }

    public func setBrightness(for light: WizLightItem, brightness: Int) {
        let clamped = max(10, min(100, brightness))
        updateLocalState(id: light.id) {
            $0.brightness = clamped
            $0.isOn = true
        }

        queue.async { [weak self] in
            guard let self = self else { return }
            let id = self.nextId()

            let payloadWithId = "{\"id\":\(id),\"method\":\"setPilot\",\"params\":{\"state\":true,\"dimming\":\(clamped)}}"
            let payloadLegacy = "{\"method\":\"setPilot\",\"params\":{\"state\":true,\"dimming\":\(clamped)}}"

            self.sendUDPBurst(to: light.ip, messages: [payloadWithId, payloadLegacy])

            if !self.smartThingsToken.isEmpty {
                let targetId = self.resolveSmartThingsDeviceId(for: light)
                self.sendSmartThingsCommand(deviceId: targetId, capability: "switch", command: "on")
                self.sendSmartThingsCommand(deviceId: targetId, capability: "switchLevel", command: "setLevel", arguments: [clamped])
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

        queue.async { [weak self] in
            guard let self = self else { return }
            let id = self.nextId()

            let payloadWithId = "{\"id\":\(id),\"method\":\"setPilot\",\"params\":{\"state\":true,\"dimming\":\(dim),\"r\":\(r),\"g\":\(g),\"b\":\(b)}}"
            let payloadLegacy = "{\"method\":\"setPilot\",\"params\":{\"state\":true,\"dimming\":\(dim),\"r\":\(r),\"g\":\(g),\"b\":\(b)}}"

            self.sendUDPBurst(to: light.ip, messages: [payloadWithId, payloadLegacy])

            if !self.smartThingsToken.isEmpty {
                let targetId = self.resolveSmartThingsDeviceId(for: light)
                let (hue, sat) = self.rgbToHueSaturation(r: r, g: g, b: b)
                let colorMap: [String: Any] = [
                    "hue": hue,
                    "saturation": sat
                ]
                self.sendSmartThingsCommand(deviceId: targetId, capability: "switch", command: "on")
                self.sendSmartThingsCommand(deviceId: targetId, capability: "colorControl", command: "setColor", arguments: [colorMap])
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

        queue.async { [weak self] in
            guard let self = self else { return }
            let id = self.nextId()

            let payloadWithId = "{\"id\":\(id),\"method\":\"setPilot\",\"params\":{\"state\":true,\"dimming\":\(dim),\"temp\":\(clampedKelvin)}}"
            let payloadLegacy = "{\"method\":\"setPilot\",\"params\":{\"state\":true,\"dimming\":\(dim),\"temp\":\(clampedKelvin)}}"

            self.sendUDPBurst(to: light.ip, messages: [payloadWithId, payloadLegacy])

            if !self.smartThingsToken.isEmpty {
                let targetId = self.resolveSmartThingsDeviceId(for: light)
                self.sendSmartThingsCommand(deviceId: targetId, capability: "switch", command: "on")
                self.sendSmartThingsCommand(deviceId: targetId, capability: "colorTemperature", command: "setColorTemperature", arguments: [clampedKelvin])
            }
        }
    }

    public func setScene(for light: WizLightItem, sceneId: Int) {
        queue.async { [weak self] in
            guard let self = self else { return }
            let id = self.nextId()
            let payload = "{\"id\":\(id),\"method\":\"setPilot\",\"params\":{\"state\":true,\"sceneId\":\(sceneId)}}"
            self.sendUDPBurst(to: light.ip, messages: [payload])

            if !self.smartThingsToken.isEmpty {
                let targetId = self.resolveSmartThingsDeviceId(for: light)
                self.sendSmartThingsCommand(deviceId: targetId, capability: "switch", command: "on")
                switch sceneId {
                case 11: // Warm White (2700K)
                    self.sendSmartThingsCommand(deviceId: targetId, capability: "colorTemperature", command: "setColorTemperature", arguments: [2700])
                    self.sendSmartThingsCommand(deviceId: targetId, capability: "switchLevel", command: "setLevel", arguments: [100])
                case 12: // Daylight (5000K)
                    self.sendSmartThingsCommand(deviceId: targetId, capability: "colorTemperature", command: "setColorTemperature", arguments: [5000])
                    self.sendSmartThingsCommand(deviceId: targetId, capability: "switchLevel", command: "setLevel", arguments: [100])
                case 6: // Cozy (2200K)
                    self.sendSmartThingsCommand(deviceId: targetId, capability: "colorTemperature", command: "setColorTemperature", arguments: [2200])
                    self.sendSmartThingsCommand(deviceId: targetId, capability: "switchLevel", command: "setLevel", arguments: [80])
                case 14: // Night Light (2200K, 10% dim)
                    self.sendSmartThingsCommand(deviceId: targetId, capability: "colorTemperature", command: "setColorTemperature", arguments: [2200])
                    self.sendSmartThingsCommand(deviceId: targetId, capability: "switchLevel", command: "setLevel", arguments: [10])
                default:
                    break
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                self.refreshAllLights()
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

    // MARK: - UDP Registration

    private func registerWithBulb(ip: String) {
        let reg = "{\"id\":\(nextId()),\"method\":\"registration\",\"params\":{\"register\":true}}"
        _ = sendUDPUnicast(to: ip, message: reg, timeoutSeconds: 0.5)
    }

    // MARK: - Low-Level UDP Communications

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
    }

    private func fetchPilot(ip: String) -> PilotResult? {
        let req = "{\"method\":\"getPilot\",\"params\":{}}"
        guard let resp = sendUDPUnicast(to: ip, message: req, timeoutSeconds: 1.0),
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
        guard let resp = sendUDPUnicast(to: ip, message: req, timeoutSeconds: 1.0),
              let data = resp.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let res = json["result"] as? [String: Any] else {
            return nil
        }

        return SystemConfigResult(
            mac: res["mac"] as? String,
            moduleName: res["moduleName"] as? String
        )
    }

    // Sends a burst of UDP datagrams to overcome Wi-Fi 802.11 DTIM sleep drops
    private func sendUDPBurst(to ip: String, messages: [String]) {
        for msg in messages {
            _ = sendUDPUnicast(to: ip, message: msg, timeoutSeconds: 0.4)
            usleep(40_000) // 40ms spacing
        }
    }

    private func sendUDPUnicast(to ip: String, message: String, timeoutSeconds: Double = 1.0) -> String? {
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

    private func sendUDPBroadcast(message: String, timeoutSeconds: Double = 2.0) -> [(ip: String, response: String)] {
        let sock = socket(AF_INET, SOCK_DGRAM, 0)
        guard sock >= 0 else { return [] }
        defer { close(sock) }

        var broadcastEnable: Int32 = 1
        setsockopt(sock, SOL_SOCKET, SO_BROADCAST, &broadcastEnable, socklen_t(MemoryLayout<Int32>.size))

        var tv = timeval(
            tv_sec: 0,
            tv_usec: 400_000 // 400ms read slice
        )
        setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))

        // Broadcast to 255.255.255.255 and subnet broadcast targets
        let targets = ["255.255.255.255", "192.168.1.255", "192.168.0.255"]
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

            if received > 0, let respStr = String(bytes: buffer[..<received], encoding: .utf8) {
                var ipBuf = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                inet_ntop(AF_INET, &srcAddr.sin_addr, &ipBuf, socklen_t(INET_ADDRSTRLEN))
                let ipStr = String(cString: ipBuf)

                if !results.contains(where: { $0.ip == ipStr }) {
                    results.append((ip: ipStr, response: respStr))
                }
            }
        }

        return results
    }

    // MARK: - SmartThings Cloud REST Integration

    public func fetchSmartThingsDevices() {
        guard !smartThingsToken.isEmpty,
              let url = URL(string: "https://api.smartthings.com/v1/devices") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(smartThingsToken)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self, let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let items = json["items"] as? [[String: Any]] else { return }

            var discovered: [WizLightItem] = []
            for item in items {
                guard let deviceId = item["deviceId"] as? String,
                      let label = (item["label"] as? String) ?? (item["name"] as? String) else { continue }

                // Check if device has switch capability or is named Philips/WiZ
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

            if !discovered.isEmpty {
                DispatchQueue.main.async {
                    for item in discovered {
                        if let idx = self.lights.firstIndex(where: { $0.id == item.id || $0.name.lowercased() == item.name.lowercased() }) {
                            self.lights[idx].smartThingsDeviceId = item.id
                            self.lights[idx].isReachable = true
                        } else {
                            self.lights.append(item)
                        }
                    }
                    self.saveLights()
                    self.onLightsChanged?(self.lights)
                }
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

        // SmartThings expects hue 0..100 (percentage of 360) and saturation 0..100
        let huePercent = (h / 360.0) * 100.0
        let satPercent = s * 100.0
        return (round(huePercent * 10.0) / 10.0, round(satPercent * 10.0) / 10.0)
    }

    private func sendSmartThingsCommand(deviceId: String, capability: String, command: String, arguments: [Any] = []) {
        guard !smartThingsToken.isEmpty,
              let url = URL(string: "https://api.smartthings.com/v1/devices/\(deviceId)/commands") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(smartThingsToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var cmdDict: [String: Any] = [
            "component": "main",
            "capability": capability,
            "command": command
        ]
        if !arguments.isEmpty {
            cmdDict["arguments"] = arguments
        }

        let body: [String: Any] = ["commands": [cmdDict]]
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

    // Helper: Approximate Kelvin to RGB for visual SwiftUI preview
    private func kelvinToRGB(kelvin: Int) -> (r: Int, g: Int, b: Int) {
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
