import Foundation
import Darwin
import CommonCrypto

public func deskOrbitLog(_ message: String) {
    let line = "[\(Date())] \(message)\n"
    if let data = line.data(using: .utf8) {
        if let handle = try? FileHandle(forWritingTo: URL(fileURLWithPath: "/tmp/deskorbit.log")) {
            handle.seekToEndOfFile()
            handle.write(data)
            try? handle.close()
        } else {
            try? data.write(to: URL(fileURLWithPath: "/tmp/deskorbit.log"), options: .atomic)
        }
    }
    NSLog("%@", message)
}

// MARK: - WiZ v2 Home Structure Config Models (Exported JSON from WiZ App)
public struct WizConfigDevice: Codable, Equatable {
    public let device_id: Int?
    public let name: String?
    public let mac_address: String?
    public let fw_version: String?
    public let type: String?
}

public struct WizHomeConfig: Codable, Equatable {
    public let name: String?
    public let home_id: Int
    public let region: String?
    public let udp_signing_key: String
    public let version: String?
    public let devices: [WizConfigDevice]?
}

public final class WizLightService: @unchecked Sendable {
    public static let shared = WizLightService()

    private let udpPort: in_port_t = 38899
    private let storageKey = "DeskOrbit_Saved_WizLights"
    private let homeIdKey = "DeskOrbit_Wiz_HomeId"
    private let udpSigningKeyKey = "DeskOrbit_Wiz_UdpSigningKey"
    private let homeNameKey = "DeskOrbit_Wiz_HomeName"

    private let udpQueue = DispatchQueue(label: "com.deskorbit.wizlight.udp", qos: .userInitiated)

    public var onLightsChanged: (([WizLightItem]) -> Void)?

    @Published public private(set) var lights: [WizLightItem] = []
    @Published public var isScanningLocal: Bool = false
    @Published public var homeId: Int?
    @Published public var udpSigningKey: String?
    @Published public var homeName: String?

    private var pollTimer: Timer?
    private var sequenceId: Int = 1
    private var localUdpDebounceItems: [String: DispatchWorkItem] = [:]

    public init() {
        // Clean up legacy SmartThings token if present
        UserDefaults.standard.removeObject(forKey: "DeskOrbit_SmartThings_Token")

        let savedHomeId = UserDefaults.standard.integer(forKey: homeIdKey)
        if savedHomeId > 0 { self.homeId = savedHomeId }
        self.udpSigningKey = UserDefaults.standard.string(forKey: udpSigningKeyKey)
        self.homeName = UserDefaults.standard.string(forKey: homeNameKey)

        loadSavedLights()

        deskOrbitLog("[DeskOrbit WiZ] Initialized: homeId=\(String(describing: self.homeId)), key=\(self.udpSigningKey != nil ? "Present" : "nil"), lightsCount=\(self.lights.count)")

        // Auto-check for WiZ v2 JSON export in ~/Downloads
        autoImportConfigFromDownloads()

        startPeriodicPoll()
        discoverLocalLights()
    }

    deinit {
        pollTimer?.invalidate()
    }

    // MARK: - WiZ v2 Security Config & JSON Import

    public func setSecurityKey(homeId: Int, signingKey: String, homeName: String? = nil) {
        self.homeId = homeId
        self.udpSigningKey = signingKey.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        self.homeName = homeName

        UserDefaults.standard.set(homeId, forKey: homeIdKey)
        UserDefaults.standard.set(self.udpSigningKey, forKey: udpSigningKeyKey)
        if let hn = homeName {
            UserDefaults.standard.set(hn, forKey: homeNameKey)
        }
    }

    public func importHomeConfigFile(url: URL) -> Result<Int, Error> {
        do {
            let data = try Data(contentsOf: url)
            return importHomeConfig(data: data)
        } catch {
            return .failure(error)
        }
    }

    public func importHomeConfig(data: Data) -> Result<Int, Error> {
        do {
            let config = try JSONDecoder().decode(WizHomeConfig.self, from: data)
            setSecurityKey(homeId: config.home_id, signingKey: config.udp_signing_key, homeName: config.name)

            var importedCount = 0
            if let devices = config.devices {
                for dev in devices {
                    guard let mac = dev.mac_address, !mac.isEmpty else { continue }
                    let name = dev.name ?? "WiZ Smart Light"
                    let cleanMac = mac.replacingOccurrences(of: ":", with: "").replacingOccurrences(of: "-", with: "").lowercased()

                    // Try to resolve current IP from local network ARP table or probe
                    let existingIP = self.lights.first(where: { $0.id == cleanMac || $0.mac.lowercased() == cleanMac })?.ip
                    let resolvedIP = self.findIPForMAC(mac: cleanMac) ?? (existingIP?.isEmpty == false ? existingIP! : "192.168.1.6")

                    let item = WizLightItem(
                        id: cleanMac,
                        ip: resolvedIP,
                        name: name,
                        mac: cleanMac,
                        isOn: true,
                        brightness: 100,
                        red: 255,
                        green: 214,
                        blue: 170,
                        colorTemperature: 2700,
                        isReachable: true,
                        firmwareVersion: dev.fw_version,
                        moduleModel: dev.type
                    )

                    DispatchQueue.main.async {
                        if let idx = self.lights.firstIndex(where: { $0.id == cleanMac || $0.mac.lowercased() == cleanMac }) {
                            var existing = self.lights[idx]
                            existing.ip = resolvedIP
                            existing.mac = cleanMac
                            existing.name = name
                            existing.isReachable = true
                            existing.firmwareVersion = dev.fw_version
                            self.lights[idx] = existing
                        } else {
                            self.lights.append(item)
                        }
                        self.saveLights()
                        self.onLightsChanged?(self.lights)
                    }
                    importedCount += 1
                }
            }

            // Immediately poll bulb state using new signing key
            udpQueue.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.refreshAllLights()
            }

            return .success(importedCount)
        } catch {
            return .failure(error)
        }
    }

    public func autoImportConfigFromDownloads() {
        let downloadsUrl = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")
        guard let files = try? FileManager.default.contentsOfDirectory(at: downloadsUrl, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles]) else { return }

        // Find JSON files containing "udp_signing_key", sorted by latest modified date
        let jsonFiles = files
            .filter { $0.pathExtension.lowercased() == "json" }
            .sorted { u1, u2 in
                let d1 = (try? u1.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast
                let d2 = (try? u2.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast
                return d1 > d2
            }

        for file in jsonFiles {
            if let data = try? Data(contentsOf: file, options: .mappedIfSafe),
               let str = String(data: data.prefix(1024), encoding: .utf8),
               str.contains("udp_signing_key") && str.contains("home_id") {
                NSLog("[DeskOrbit WiZ] Auto-importing config from %@", file.lastPathComponent)
                _ = importHomeConfig(data: data)
                break
            }
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

    // MARK: - Periodic Status Polling (Local UDP)

    private func startPeriodicPoll() {
        DispatchQueue.main.async { [weak self] in
            self?.pollTimer?.invalidate()
            self?.pollTimer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: true) { [weak self] _ in
                self?.refreshAllLights()
            }
        }
    }

    public func refreshAllLights() {
        let currentLights = self.lights
        guard !currentLights.isEmpty else { return }

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
                }
            }
        }
    }

    // MARK: - Direct WiZ Local Integration (Signed UDP 38899)

    public func discoverLocalLights(completion: (([WizLightItem]) -> Void)? = nil) {
        DispatchQueue.main.async { self.isScanningLocal = true }

        udpQueue.async { [weak self] in
            guard let self = self else { return }
            self.autoImportConfigFromDownloads()

            // 1. Probe known bulbs
            for light in self.lights where light.hasLocalConnection {
                _ = self.fetchPilot(ip: light.ip)
            }

            // 2. Broadcast probe across subnet
            var probeParams: [String: Any] = [:]
            if let hid = self.homeId {
                probeParams["homeId"] = hid
            }
            let msg = self.buildUDPMessage(method: "getSystemConfig", params: probeParams)
            let responses = self.sendUDPBroadcast(message: msg, timeoutSeconds: 2.0)

            var discovered: [WizLightItem] = []

            for (ip, respStr) in responses {
                if let data = respStr.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let result = json["result"] as? [String: Any] {
                    let mac = (result["mac"] as? String) ?? UUID().uuidString
                    let module = (result["moduleName"] as? String) ?? "Philips WiZ Bulb"
                    let fw = result["fwVersion"] as? String

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
                    if let idx = self.lights.firstIndex(where: {
                        $0.id == disc.id || $0.mac.lowercased() == disc.mac.lowercased() || $0.ip == disc.ip
                    }) {
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

            let sysConfig = self.fetchSystemConfig(ip: trimmedIP)
            let pilot = self.fetchPilot(ip: trimmedIP)

            if sysConfig == nil && pilot == nil {
                DispatchQueue.main.async {
                    completion(.failure(NSError(
                        domain: "WizLightService",
                        code: 404,
                        userInfo: [NSLocalizedDescriptionKey: "Bulb at \(trimmedIP) did not respond over UDP port 38899.\n\nTips:\n1. If your WiZ app has 'Only verified controls' enabled, import your WiZ JSON export file in DeskOrbit.\n2. In the WiZ App, check Settings → Security → 'Local network communication'."]
                    )))
                }
                return
            }

            let mac = sysConfig?.mac ?? pilot?.mac ?? UUID().uuidString.prefix(12).lowercased()
            let defaultName = sysConfig?.moduleName ?? "Philips WiZ Smart Bulb"
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
                isReachable: true,
                firmwareVersion: sysConfig?.fwVersion,
                moduleModel: sysConfig?.moduleName
            )

            DispatchQueue.main.async {
                if let idx = self.lights.firstIndex(where: {
                    $0.id == item.id || $0.mac.lowercased() == item.mac.lowercased() || $0.ip == item.ip
                }) {
                    var existing = self.lights[idx]
                    existing.ip = item.ip
                    existing.mac = item.mac
                    existing.isReachable = true
                    existing.firmwareVersion = item.firmwareVersion
                    existing.moduleModel = item.moduleModel
                    if customName?.isEmpty == false { existing.name = customName! }
                    self.lights[idx] = existing
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
        let trimmed = ip.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            completion(.failure(NSError(domain: "WizLightService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid IP address"])))
            return
        }

        if let idx = lights.firstIndex(where: { $0.id == bulbId }) {
            lights[idx].ip = trimmed
            lights[idx].isReachable = true
            let updated = lights[idx]
            saveLights()
            onLightsChanged?(lights)
            completion(.success(updated))
        } else {
            completion(.failure(NSError(domain: "WizLightService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Bulb not found"])))
        }
    }

    public func removeLight(id: String) {
        cancelDebounce(for: id)
        lights.removeAll(where: { $0.id == id })
        saveLights()
        onLightsChanged?(lights)
    }

    // MARK: - Direct Local Light Controls (Signed UDP 38899)

    public func setPower(for light: WizLightItem, isOn: Bool) {
        deskOrbitLog("[DeskOrbit WiZ] setPower for '\(light.name)' (ip: \(light.ip)) -> isOn: \(isOn)")
        cancelDebounce(for: light.id)
        updateLocalState(id: light.id) { $0.isOn = isOn }
        sendSignedPilot(ip: light.ip, params: ["state": isOn])
    }

    public func setBrightness(for light: WizLightItem, brightness: Int) {
        let clamped = max(10, min(100, brightness))
        deskOrbitLog("[DeskOrbit WiZ] setBrightness for '\(light.name)' (ip: \(light.ip)) -> \(clamped)%")
        updateLocalState(id: light.id) {
            $0.brightness = clamped
            $0.isOn = true
        }

        debounceLocalUDP(for: light.id, delay: 0.04) { [weak self] in
            self?.sendSignedPilot(ip: light.ip, params: ["state": true, "dimming": clamped])
        }
    }

    public func setRGBColor(for light: WizLightItem, red: Int, green: Int, blue: Int, brightness: Int? = nil) {
        let r = max(0, min(255, red))
        let g = max(0, min(255, green))
        let b = max(0, min(255, blue))
        let dim = brightness ?? light.brightness
        deskOrbitLog("[DeskOrbit WiZ] setRGBColor for '\(light.name)' (ip: \(light.ip)) -> rgb(\(r),\(g),\(b)) dim: \(dim)")

        updateLocalState(id: light.id) {
            $0.red = r
            $0.green = g
            $0.blue = b
            $0.colorTemperature = nil
            $0.brightness = dim
            $0.isOn = true
        }

        debounceLocalUDP(for: light.id, delay: 0.04) { [weak self] in
            self?.sendSignedPilot(ip: light.ip, params: [
                "state": true,
                "dimming": dim,
                "r": r,
                "g": g,
                "b": b
            ])
        }
    }

    public func setColorTemperature(for light: WizLightItem, kelvin: Int, brightness: Int? = nil) {
        let clampedKelvin = max(2200, min(6500, kelvin))
        let dim = brightness ?? light.brightness
        let approxRGB = kelvinToRGB(kelvin: clampedKelvin)
        deskOrbitLog("[DeskOrbit WiZ] setColorTemperature for '\(light.name)' (ip: \(light.ip)) -> \(clampedKelvin)K dim: \(dim)")

        updateLocalState(id: light.id) {
            $0.colorTemperature = clampedKelvin
            $0.red = approxRGB.r
            $0.green = approxRGB.g
            $0.blue = approxRGB.b
            $0.brightness = dim
            $0.isOn = true
        }

        debounceLocalUDP(for: light.id, delay: 0.04) { [weak self] in
            self?.sendSignedPilot(ip: light.ip, params: [
                "state": true,
                "dimming": dim,
                "temp": clampedKelvin
            ])
        }
    }

    public func setScene(for light: WizLightItem, sceneId: Int) {
        deskOrbitLog("[DeskOrbit WiZ] setScene for '\(light.name)' (ip: \(light.ip)) -> sceneId: \(sceneId)")
        cancelDebounce(for: light.id)
        sendSignedPilot(ip: light.ip, params: ["state": true, "sceneId": sceneId])

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

    // MARK: - Low-Level UDP Communications (POSIX Sockets & HMAC-SHA256 Signing)

    private func sendSignedPilot(ip: String, params: [String: Any]) {
        let trimmedIP = ip.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedIP.isEmpty else {
            deskOrbitLog("[DeskOrbit WiZ] sendSignedPilot failed: IP address is empty")
            return
        }

        udpQueue.async { [weak self] in
            guard let self = self else { return }
            let id = self.nextId()
            let packet = self.buildUDPMessage(method: "setPilot", id: id, params: params)
            deskOrbitLog("[DeskOrbit WiZ] Dispatching UDP setPilot to \(trimmedIP):38899 -> \(packet)")
            let resp = self.sendUDPUnicast(to: trimmedIP, message: packet, timeoutSeconds: 1.0)
            deskOrbitLog("[DeskOrbit WiZ] Response from \(trimmedIP): \(resp ?? "<no response / timeout>")")
        }
    }

    private func buildUDPMessage(method: String, id: Int? = nil, params: [String: Any] = [:]) -> String {
        let msgId = id ?? nextId()
        var fullParams = params

        // If signing key is configured, include homeId, sigTs, and compute HMAC
        if let hid = homeId, let keyHex = udpSigningKey {
            let cleanKey = keyHex.trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleanKey.isEmpty {
                fullParams["homeId"] = hid
                fullParams["sigTs"] = Int(Date().timeIntervalSince1970)

                let keyData = hexToData(cleanKey)
                if let jsonData = try? JSONSerialization.data(withJSONObject: fullParams, options: [.sortedKeys]),
                   let paramsStr = String(data: jsonData, encoding: .utf8) {
                    let sig = hmacSha256(data: jsonData, key: keyData)
                    let msg = "{\"method\":\"\(method)\",\"id\":\(msgId),\"env\":\"pro\",\"params\":\(paramsStr),\"hmac\":\"\(sig)\"}"
                    return msg
                }
            }
        }

        deskOrbitLog("[DeskOrbit WiZ] WARNING: No signing key configured for packet! homeId=\(String(describing: homeId)), key=\(String(describing: udpSigningKey))")
        // Fallback for open controls
        if let jsonData = try? JSONSerialization.data(withJSONObject: fullParams, options: []),
           let paramsStr = String(data: jsonData, encoding: .utf8) {
            return "{\"method\":\"\(method)\",\"id\":\(msgId),\"params\":\(paramsStr)}"
        }

        return "{\"method\":\"\(method)\",\"id\":\(msgId),\"params\":{}}"
    }

    private func debounceLocalUDP(for key: String, delay: TimeInterval, action: @escaping () -> Void) {
        localUdpDebounceItems[key]?.cancel()
        let item = DispatchWorkItem(block: action)
        localUdpDebounceItems[key] = item
        udpQueue.asyncAfter(deadline: .now() + delay, execute: item)
    }

    private func cancelDebounce(for key: String) {
        localUdpDebounceItems[key]?.cancel()
        localUdpDebounceItems.removeValue(forKey: key)
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
        let req = buildUDPMessage(method: "getPilot")
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
        let req = buildUDPMessage(method: "getSystemConfig")
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

    private func sendUDPUnicast(to ip: String, message: String, timeoutSeconds: Double = 1.0) -> String? {
        let trimmedIP = ip.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedIP.isEmpty else { return nil }

        let sock = socket(AF_INET, SOCK_DGRAM, 0)
        guard sock >= 0 else { return nil }
        defer { close(sock) }

        var tv = timeval(
            tv_sec: Int(timeoutSeconds),
            tv_usec: Int32((timeoutSeconds.truncatingRemainder(dividingBy: 1.0)) * 1_000_000)
        )
        setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))

        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = udpPort.bigEndian
        addr.sin_addr.s_addr = inet_addr(trimmedIP)

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
            addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
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

    // Helper: Find current local IP for a given MAC address from system ARP table
    public func findIPForMAC(mac: String) -> String? {
        let cleanTarget = mac.replacingOccurrences(of: ":", with: "").replacingOccurrences(of: "-", with: "").lowercased()

        let pipe = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/arp")
        process.arguments = ["-a", "-n"]
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                for line in output.components(separatedBy: "\n") {
                    let parts = line.components(separatedBy: " ")
                    guard parts.count >= 4 else { continue }
                    let ipWithParens = parts[1]
                    let ip = ipWithParens.trimmingCharacters(in: CharacterSet(charactersIn: "()"))
                    let rawMac = parts[3]
                    let cleanMac = rawMac.replacingOccurrences(of: ":", with: "").replacingOccurrences(of: "-", with: "").lowercased()

                    if cleanMac == cleanTarget {
                        return ip
                    }
                }
            }
        } catch {
            return nil
        }
        return nil
    }

    // Helper: Convert hex string to binary Data
    private func hexToData(_ hex: String) -> Data {
        let cleanHex = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "-", with: "")
        var data = Data()
        var temp = ""
        for c in cleanHex {
            temp.append(c)
            if temp.count == 2 {
                if let byte = UInt8(temp, radix: 16) {
                    data.append(byte)
                }
                temp = ""
            }
        }
        return data
    }

    // Helper: Compute HMAC-SHA256 Base64 string
    private func hmacSha256(data: Data, key: Data) -> String {
        var hmac = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes { dPtr in
            key.withUnsafeBytes { kPtr in
                CCHmac(CCHmacAlgorithm(kCCHmacAlgSHA256), kPtr.baseAddress, key.count, dPtr.baseAddress, data.count, &hmac)
            }
        }
        return Data(hmac).base64EncodedString()
    }

    // MARK: - Color Conversion Helpers

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
