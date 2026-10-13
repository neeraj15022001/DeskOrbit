import Foundation

public final class WizLightService {
    public static let shared = WizLightService()

    private let storageKey = "DeskOrbit_Saved_WizLights"
    private let smartThingsTokenKey = "DeskOrbit_SmartThings_Token"
    private let workQueue = DispatchQueue(label: "com.deskorbit.smartthings.work", qos: .userInitiated)

    public var onLightsChanged: (([WizLightItem]) -> Void)?

    @Published public private(set) var lights: [WizLightItem] = []
    @Published public var smartThingsToken: String = ""

    private var pollTimer: Timer?
    private var debounceWorkItems: [String: DispatchWorkItem] = [:]

    public init() {
        self.smartThingsToken = UserDefaults.standard.string(forKey: smartThingsTokenKey) ?? ""
        loadSavedLights()
        purgeWiFiLights()
        startPeriodicPoll()
        if !self.smartThingsToken.isEmpty {
            fetchSmartThingsDevices()
        }
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

    // MARK: - Persistence & Wi-Fi Purge

    public func purgeWiFiLights() {
        // Exclusively keep SmartThings bulbs, permanently removing Wi-Fi UDP discovered instances
        let filtered = lights.filter { isSmartThingsLight($0) }
        if filtered.count != lights.count {
            self.lights = filtered
            saveLights()
            onLightsChanged?(self.lights)
        }
    }

    private func isSmartThingsLight(_ light: WizLightItem) -> Bool {
        return light.ip == "SmartThings Cloud" ||
               (light.id.contains("-") && light.id.count >= 32) ||
               (light.smartThingsDeviceId != nil && !light.smartThingsDeviceId!.isEmpty)
    }

    private func loadSavedLights() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode([WizLightItem].self, from: data) {
            // Keep ONLY SmartThings devices
            self.lights = saved.filter { isSmartThingsLight($0) }
            saveLights()
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
            self?.pollTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in
                self?.refreshAllLights()
            }
        }
    }

    public func refreshAllLights() {
        guard !smartThingsToken.isEmpty, !lights.isEmpty else { return }

        for light in lights {
            pollDeviceStatus(deviceId: light.id)
        }
    }

    private func pollDeviceStatus(deviceId: String) {
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
                guard let idx = self.lights.firstIndex(where: { $0.id == deviceId }) else { return }
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

    // MARK: - Light Controls

    public func setPower(for light: WizLightItem, isOn: Bool) {
        cancelDebounce(for: light.id)
        updateLocalState(id: light.id) { $0.isOn = isOn }

        let targetId = resolveSmartThingsDeviceId(for: light)
        sendSmartThingsCommands(deviceId: targetId, commands: [
            (capability: "switch", command: isOn ? "on" : "off", arguments: [])
        ])
    }

    public func setBrightness(for light: WizLightItem, brightness: Int) {
        let clamped = max(10, min(100, brightness))
        updateLocalState(id: light.id) {
            $0.brightness = clamped
            $0.isOn = true
        }

        let targetId = resolveSmartThingsDeviceId(for: light)

        // Debounce by 250ms to prevent slider dragging from flooding the SmartThings API
        debounce(for: light.id, delay: 0.25) { [weak self] in
            guard let self = self else { return }
            self.sendSmartThingsCommands(deviceId: targetId, commands: [
                (capability: "switch", command: "on", arguments: []),
                (capability: "switchLevel", command: "setLevel", arguments: [clamped])
            ])
        }
    }

    public func setRGBColor(for light: WizLightItem, red: Int, green: Int, blue: Int, brightness: Int? = nil) {
        cancelDebounce(for: light.id)
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

        let targetId = resolveSmartThingsDeviceId(for: light)
        let (hue, sat) = rgbToHueSaturation(r: r, g: g, b: b)
        let colorMap: [String: Any] = [
            "hue": hue,
            "saturation": sat
        ]

        // Send atomic batch command: turns on and applies color in a single HTTP POST
        sendSmartThingsCommands(deviceId: targetId, commands: [
            (capability: "switch", command: "on", arguments: []),
            (capability: "colorControl", command: "setColor", arguments: [colorMap])
        ])
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

        let targetId = resolveSmartThingsDeviceId(for: light)

        // Debounce by 250ms for smooth slider dragging without API rate limiting
        debounce(for: light.id, delay: 0.25) { [weak self] in
            guard let self = self else { return }
            self.sendSmartThingsCommands(deviceId: targetId, commands: [
                (capability: "switch", command: "on", arguments: []),
                (capability: "colorTemperature", command: "setColorTemperature", arguments: [clampedKelvin])
            ])
        }
    }

    public func setScene(for light: WizLightItem, sceneId: Int) {
        cancelDebounce(for: light.id)
        let targetId = resolveSmartThingsDeviceId(for: light)

        var commands: [(capability: String, command: String, arguments: [Any])] = [
            (capability: "switch", command: "on", arguments: [])
        ]

        switch sceneId {
        case 11: // Warm White (2700K)
            commands.append((capability: "colorTemperature", command: "setColorTemperature", arguments: [2700]))
            commands.append((capability: "switchLevel", command: "setLevel", arguments: [100]))
            updateLocalState(id: light.id) {
                $0.colorTemperature = 2700
                $0.brightness = 100
                $0.isOn = true
                let rgb = self.kelvinToRGB(kelvin: 2700)
                $0.red = rgb.r; $0.green = rgb.g; $0.blue = rgb.b
            }
        case 12: // Daylight (5000K)
            commands.append((capability: "colorTemperature", command: "setColorTemperature", arguments: [5000]))
            commands.append((capability: "switchLevel", command: "setLevel", arguments: [100]))
            updateLocalState(id: light.id) {
                $0.colorTemperature = 5000
                $0.brightness = 100
                $0.isOn = true
                let rgb = self.kelvinToRGB(kelvin: 5000)
                $0.red = rgb.r; $0.green = rgb.g; $0.blue = rgb.b
            }
        case 6: // Cozy (2200K)
            commands.append((capability: "colorTemperature", command: "setColorTemperature", arguments: [2200]))
            commands.append((capability: "switchLevel", command: "setLevel", arguments: [80]))
            updateLocalState(id: light.id) {
                $0.colorTemperature = 2200
                $0.brightness = 80
                $0.isOn = true
                let rgb = self.kelvinToRGB(kelvin: 2200)
                $0.red = rgb.r; $0.green = rgb.g; $0.blue = rgb.b
            }
        case 14: // Night Light (2200K, 10% dim)
            commands.append((capability: "colorTemperature", command: "setColorTemperature", arguments: [2200]))
            commands.append((capability: "switchLevel", command: "setLevel", arguments: [10]))
            updateLocalState(id: light.id) {
                $0.colorTemperature = 2200
                $0.brightness = 10
                $0.isOn = true
                let rgb = self.kelvinToRGB(kelvin: 2200)
                $0.red = rgb.r; $0.green = rgb.g; $0.blue = rgb.b
            }
        default:
            break
        }

        sendSmartThingsCommands(deviceId: targetId, commands: commands)
    }

    public func removeLight(id: String) {
        cancelDebounce(for: id)
        lights.removeAll(where: { $0.id == id })
        saveLights()
        onLightsChanged?(lights)
    }

    private func updateLocalState(id: String, mutate: (inout WizLightItem) -> Void) {
        if let idx = lights.firstIndex(where: { $0.id == id }) {
            mutate(&lights[idx])
            saveLights()
            onLightsChanged?(lights)
        }
    }

    // MARK: - Debouncing Helper

    private func debounce(for key: String, delay: TimeInterval, action: @escaping () -> Void) {
        debounceWorkItems[key]?.cancel()
        let item = DispatchWorkItem(block: action)
        debounceWorkItems[key] = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    private func cancelDebounce(for key: String) {
        debounceWorkItems[key]?.cancel()
        debounceWorkItems.removeValue(forKey: key)
    }

    // MARK: - SmartThings Cloud REST Integration

    public func fetchSmartThingsDevices(completion: (([WizLightItem]) -> Void)? = nil) {
        guard !smartThingsToken.isEmpty,
              let url = URL(string: "https://api.smartthings.com/v1/devices") else {
            completion?([])
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10.0
        request.setValue("Bearer \(smartThingsToken)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self, let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let items = json["items"] as? [[String: Any]] else {
                DispatchQueue.main.async { completion?([]) }
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
                // Strictly keep only SmartThings lights
                self.lights = discovered
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

    // Helper: RGB to Hue (0-100) & Saturation (0-100)
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

    // Helper: Hue (0-100) & Saturation (0-100) to RGB
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

    // Helper: Approximate Kelvin to RGB for visual SwiftUI preview
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
