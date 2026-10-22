import Foundation
import NaturalLanguage
#if canImport(FoundationModels)
import FoundationModels
#endif

public enum AssistantAction: Equatable, Sendable {
    case setBulbPower(isOn: Bool)
    case setBulbBrightness(percent: Int)
    case setBulbColor(red: Int, green: Int, blue: Int, name: String)
    case setBulbTemperature(kelvin: Int)
    case setBulbScene(sceneId: Int, name: String)
    case setThematicPreset(red: Int, green: Int, blue: Int, brightness: Int, kelvin: Int?, name: String)
    case setAudioVolume(percent: Int, deviceName: String?)
    case setAudioMute(isMuted: Bool, deviceName: String?)
    case setDisplayBrightness(percent: Int, displayName: String?)
    case unknown(query: String)
}

public struct AssistantParseResult: Equatable, Sendable {
    public let action: AssistantAction
    public let feedback: String
    public let confidence: Double
}

public final class OrbitNaturalLanguageParser: @unchecked Sendable {
    public static let shared = OrbitNaturalLanguageParser()

    private let embedding = NLEmbedding.wordEmbedding(for: .english)

    // Standard basic colors
    private let knownColors: [String: (r: Int, g: Int, b: Int)] = [
        "red": (255, 0, 0),
        "crimson": (220, 20, 60),
        "ruby": (224, 17, 95),
        "scarlet": (255, 36, 0),
        "pink": (255, 105, 180),
        "rose": (255, 0, 128),
        "green": (0, 255, 0),
        "lime": (50, 205, 50),
        "emerald": (0, 201, 87),
        "forest green": (34, 139, 34),
        "mint": (152, 255, 152),
        "blue": (0, 100, 255),
        "cyan": (0, 255, 255),
        "sky": (135, 206, 235),
        "ice blue": (175, 238, 238),
        "navy": (0, 0, 128),
        "indigo": (75, 0, 130),
        "purple": (160, 32, 240),
        "violet": (238, 130, 238),
        "magenta": (255, 0, 255),
        "lavender": (230, 230, 250),
        "yellow": (255, 255, 0),
        "amber": (255, 191, 0),
        "gold": (255, 215, 0),
        "orange": (255, 140, 0),
        "peach": (255, 218, 185),
        "coral": (255, 127, 80),
        "warm white": (255, 214, 170),
        "cool white": (200, 220, 255),
        "white": (255, 255, 255)
    ]

    // Pop Culture & Thematic Lighting Presets (Apple Generative / Semantic design)
    private struct ThematicPreset {
        let keywords: [String]
        let red: Int
        let green: Int
        let blue: Int
        let brightness: Int
        let kelvin: Int?
        let name: String
        let description: String
    }

    private let thematicPresets: [ThematicPreset] = [
        // 1. Money Heist (La Casa de Papel) -> Iconic Crimson Red Jumpsuit & Dali Mask
        ThematicPreset(
            keywords: ["money heist", "la casa de papel", "bella ciao", "professor heist", "dali mask", "heist theme"],
            red: 220, green: 20, blue: 60, brightness: 85, kelvin: nil,
            name: "Money Heist Crimson",
            description: "Dali mask & red jumpsuit iconic Money Heist theme"
        ),
        // 2. Cyberpunk / Blade Runner -> Neon Magenta / Cyber Cyan
        ThematicPreset(
            keywords: ["cyberpunk", "blade runner", "neon city", "synthwave", "retrowave", "vaporwave", "night city"],
            red: 255, green: 0, blue: 128, brightness: 90, kelvin: nil,
            name: "Cyberpunk Neon",
            description: "Futuristic high-contrast neon vibe"
        ),
        // 3. Matrix -> Terminal Code Green
        ThematicPreset(
            keywords: ["matrix", "neo", "hacker", "terminal", "cyber code"],
            red: 0, green: 255, blue: 65, brightness: 75, kelvin: nil,
            name: "Matrix Code Green",
            description: "Iconic digital rain terminal green"
        ),
        // 4. Stranger Things / Upside Down -> Eerie Deep Blood Red & Indigo
        ThematicPreset(
            keywords: ["stranger things", "upside down", "demogorgon", "hawkins"],
            red: 180, green: 0, blue: 20, brightness: 60, kelvin: nil,
            name: "Upside Down Red",
            description: "Moody vintage supernatural thriller glow"
        ),
        // 5. Star Wars Sith -> Darth Vader Imperial Crimson
        ThematicPreset(
            keywords: ["sith", "darth vader", "dark side", "empire"],
            red: 255, green: 0, blue: 10, brightness: 100, kelvin: nil,
            name: "Sith Lightsaber Red",
            description: "Dark side crimson illumination"
        ),
        // 6. Star Wars Jedi -> Skywalker Crystal Blue
        ThematicPreset(
            keywords: ["jedi", "skywalker", "light side", "lightsaber blue"],
            red: 0, green: 140, blue: 255, brightness: 90, kelvin: nil,
            name: "Jedi Guardian Blue",
            description: "Kyber crystal serene blue"
        ),
        // 7. Interstellar / Deep Space -> Cosmic Nebula Indigo
        ThematicPreset(
            keywords: ["interstellar", "deep space", "galaxy", "cosmic", "nebula", "outer space"],
            red: 75, green: 0, blue: 180, brightness: 50, kelvin: nil,
            name: "Cosmic Nebula",
            description: "Deep starlight cosmic purple-blue"
        ),
        // 8. Sunset / Golden Hour
        ThematicPreset(
            keywords: ["golden hour", "sunset vibe", "dusk", "evening glow", "warm horizon"],
            red: 255, green: 130, blue: 20, brightness: 65, kelvin: 2700,
            name: "Golden Hour Glow",
            description: "Warm amber horizon light"
        ),
        // 9. Ocean / Deep Sea
        ThematicPreset(
            keywords: ["ocean", "underwater", "aquarium", "marine", "deep blue sea", "caribbean"],
            red: 0, green: 180, blue: 240, brightness: 70, kelvin: nil,
            name: "Oceanic Turquoise",
            description: "Calm tropical sea ambient"
        ),
        // 10. Forest / Nature / Zen
        ThematicPreset(
            keywords: ["forest", "nature", "zen", "jungle", "earth", "rainforest"],
            red: 34, green: 180, blue: 60, brightness: 60, kelvin: nil,
            name: "Zen Forest Green",
            description: "Natural restorative botanical green"
        )
    ]

    // Mood & Activity lighting presets
    private struct MoodPreset {
        let keywords: [String]
        let kelvin: Int?
        let red: Int?
        let green: Int?
        let blue: Int?
        let brightness: Int
        let name: String
        let feedback: String
    }

    private let moodPresets: [MoodPreset] = [
        // Relaxing / Wind down / Cozy
        MoodPreset(
            keywords: ["relax", "relaxing", "unwind", "calm", "chill", "peaceful", "stress free", "soothing", "rest"],
            kelvin: 2400, red: 255, green: 190, blue: 130, brightness: 35,
            name: "Relaxation Warm Glow",
            feedback: "Set soft warm lighting (2400K at 35%) for relaxing."
        ),
        // Sleep / Bedtime / Candle
        MoodPreset(
            keywords: ["sleep", "bedtime", "sleeping", "nap", "drowsy", "tired", "goodnight", "night light", "midnight"],
            kelvin: 2000, red: 255, green: 147, blue: 41, brightness: 15,
            name: "Sleep Ambient",
            feedback: "Set ultra-low amber glow (2000K at 15%) to prepare for sleep."
        ),
        // Focus / Study / Productivity / Work
        MoodPreset(
            keywords: ["focus", "study", "studying", "work", "working", "productive", "productivity", "coding", "read", "reading", "sharp"],
            kelvin: 5200, red: 240, green: 245, blue: 255, brightness: 90,
            name: "Focus & Clarity",
            feedback: "Set crisp daylight (5200K at 90%) for deep focus and reading."
        ),
        // Party / Festive
        MoodPreset(
            keywords: ["party", "dance", "celebrate", "celebration", "disco", "club", "festive", "fun"],
            kelvin: nil, red: 255, green: 0, blue: 200, brightness: 100,
            name: "Party Magenta",
            feedback: "Turned on vibrant high-energy party lighting at 100%."
        ),
        // Romance / Date Night / Candlelight
        MoodPreset(
            keywords: ["romance", "romantic", "date night", "candlelight", "intimate"],
            kelvin: 2200, red: 255, green: 130, blue: 80, brightness: 25,
            name: "Romantic Candlelight",
            feedback: "Set intimate soft candlelight ambient at 25%."
        ),
        // Energy / Morning Wake Up
        MoodPreset(
            keywords: ["energize", "energetic", "wake up", "morning boost", "alert", "energy"],
            kelvin: 6500, red: 230, green: 240, blue: 255, brightness: 100,
            name: "Energy Boost",
            feedback: "Set invigorating cool daylight (6500K at 100%) for maximum alertness."
        )
    ]

    private let knownScenes: [String: Int] = [
        "warm": 11,
        "warm white": 11,
        "cozy": 6,
        "candlelight": 6,
        "fireplace": 14,
        "sunset": 12,
        "daylight": 12,
        "night": 14,
        "night light": 14
    ]

    #if canImport(FoundationModels)
    private var _systemModelSession: Any?
    #endif

    public init() {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            let model = SystemLanguageModel.default
            if model.availability == .available {
                let instructions = Instructions("""
                You are an intelligent device control assistant for DeskOrbit on macOS.
                DeskOrbit controls three hardware devices:
                1. "light" (smart bulb): "r" (0-255), "g" (0-255), "b" (0-255), "brightness" (1-100), "kelvin" (2000-6500 or null)
                2. "audio": "volume" (0-100), "muted" (true/false)
                3. "display": "brightness" (0-100)

                Always output pure valid JSON matching one of these categories.
                Format for light:
                {"target": "light", "r": <0-255>, "g": <0-255>, "b": <0-255>, "brightness": <1-100>, "kelvin": <2000-6500 or null>, "description": "<short phrase>"}
                Format for audio:
                {"target": "audio", "volume": <0-100 or null>, "muted": <true/false or null>, "description": "<short phrase>"}
                Format for display:
                {"target": "display", "brightness": <0-100>, "description": "<short phrase>"}
                """)
                self._systemModelSession = LanguageModelSession(model: model, instructions: instructions)
            }
        }
        #endif
    }

    public func parseAsync(query: String) async -> AssistantParseResult {
        let clean = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.isEmpty {
            return AssistantParseResult(action: .unknown(query: query), feedback: "Empty voice command.", confidence: 0.0)
        }

        // Direct rule/thematic match first for low latency
        let fastResult = self.parse(query: query)
        if fastResult.confidence >= 0.85 {
            return fastResult
        }

        // Use Apple on-device Foundation Model (Apple Intelligence SystemLanguageModel)
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            if let session = self._systemModelSession as? LanguageModelSession {
                do {
                    let response = try await session.respond(to: query)
                    let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
                    if let data = text.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        let target = (json["target"] as? String)?.lowercased() ?? ""
                        let desc = json["description"] as? String ?? query

                        if target == "audio" || json["volume"] != nil || json["muted"] != nil {
                            let devName = json["device"] as? String
                            if let vol = json["volume"] as? Int {
                                return AssistantParseResult(
                                    action: .setAudioVolume(percent: max(0, min(100, vol)), deviceName: devName),
                                    feedback: "Apple Foundation Model: Set \(devName ?? "audio") volume to \(vol)%",
                                    confidence: 0.95
                                )
                            }
                            if let muted = json["muted"] as? Bool {
                                return AssistantParseResult(
                                    action: .setAudioMute(isMuted: muted, deviceName: devName),
                                    feedback: "Apple Foundation Model: \(muted ? "Muted" : "Unmuted") \(devName ?? "audio")",
                                    confidence: 0.95
                                )
                            }
                        } else if target == "display" {
                            let dispName = json["device"] as? String
                            if let dispBrightness = json["brightness"] as? Int {
                                return AssistantParseResult(
                                    action: .setDisplayBrightness(percent: max(0, min(100, dispBrightness)), displayName: dispName),
                                    feedback: "Apple Foundation Model: Set \(dispName ?? "display") brightness to \(dispBrightness)%",
                                    confidence: 0.95
                                )
                            }
                        } else {
                            // Light target
                            let r = json["r"] as? Int ?? 255
                            let g = json["g"] as? Int ?? 214
                            let b = json["b"] as? Int ?? 170
                            let brightness = json["brightness"] as? Int ?? 80
                            let kelvin = json["kelvin"] as? Int

                            return AssistantParseResult(
                                action: .setThematicPreset(
                                    red: max(0, min(255, r)),
                                    green: max(0, min(255, g)),
                                    blue: max(0, min(255, b)),
                                    brightness: max(1, min(100, brightness)),
                                    kelvin: kelvin,
                                    name: "Apple Intelligence"
                                ),
                                feedback: "Apple Foundation Model: \(desc)",
                                confidence: 0.95
                            )
                        }
                    }
                } catch {
                    // Fall back to fastResult if LLM throws
                }
            }
        }
        #endif

        return fastResult
    }

    public func parse(query: String) -> AssistantParseResult {
        let clean = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.isEmpty {
            return AssistantParseResult(action: .unknown(query: query), feedback: "Empty voice command.", confidence: 0.0)
        }

        // 1. Daytime / Circadian Dynamic Lighting (e.g., "match the light with daytime", "sync with sun", "natural time")
        if isDaytimeIntent(clean) {
            let daytime = calculateCircadianLighting()
            return AssistantParseResult(
                action: .setThematicPreset(
                    red: daytime.r, green: daytime.g, blue: daytime.b,
                    brightness: daytime.brightness,
                    kelvin: daytime.kelvin,
                    name: "Circadian Daytime"
                ),
                feedback: "Matched lighting with current time of day: \(daytime.description) (\(daytime.kelvin)K at \(daytime.brightness)%).",
                confidence: 0.98
            )
        }

        // 2. Pop Culture & Thematic Lighting (e.g., "Money Heist", "Cyberpunk", "Matrix", "Interstellar")
        for preset in thematicPresets {
            for kw in preset.keywords {
                if clean.contains(kw) {
                    return AssistantParseResult(
                        action: .setThematicPreset(
                            red: preset.red, green: preset.green, blue: preset.blue,
                            brightness: preset.brightness,
                            kelvin: preset.kelvin,
                            name: preset.name
                        ),
                        feedback: "Set theme to \(preset.name): \(preset.description).",
                        confidence: 0.98
                    )
                }
            }
        }

        // 3. Mood & Activity Presets (e.g., "relaxing", "bedtime", "focus", "party", "reading")
        if let mood = matchMoodPreset(clean) {
            let r = mood.red ?? 255
            let g = mood.green ?? 214
            let b = mood.blue ?? 170
            return AssistantParseResult(
                action: .setThematicPreset(
                    red: r, green: g, blue: b,
                    brightness: mood.brightness,
                    kelvin: mood.kelvin,
                    name: mood.name
                ),
                feedback: mood.feedback,
                confidence: 0.95
            )
        }

        // 4. Audio Mute / Unmute
        if clean.contains("unmute") || (clean.contains("mute") && clean.contains("off")) {
            let target = extractAudioTarget(from: clean)
            let devName = target.mentionedName
            let label = target.matchedDevice?.name ?? devName ?? "master audio"
            return AssistantParseResult(action: .setAudioMute(isMuted: false, deviceName: devName), feedback: "Unmuted \(label)", confidence: 0.98)
        }
        if clean.contains("mute") || clean.contains("silence") {
            let target = extractAudioTarget(from: clean)
            let devName = target.mentionedName
            let label = target.matchedDevice?.name ?? devName ?? "master audio"
            return AssistantParseResult(action: .setAudioMute(isMuted: true, deviceName: devName), feedback: "Muted \(label)", confidence: 0.98)
        }

        // 5. Audio Volume
        let isVolumeIntent = clean.contains("volume") || clean.contains("sound") || clean.contains("audio") || clean.contains("speaker") || clean.contains("hear") || clean.contains("loud") || clean.contains("quiet") || clean.contains("listen")
        if isVolumeIntent {
            let target = extractAudioTarget(from: clean)
            let devName = target.mentionedName
            let activeDev = target.matchedDevice ?? DeviceManager.shared.defaultAudioOutput ?? DeviceManager.shared.audioDevices.first(where: { !$0.isInput })
            let currentVol = Int((activeDev?.volume ?? 0.5) * 100)
            let label = activeDev?.name ?? devName ?? "audio"

            if let number = extractPercentageOrWordNumber(from: clean) {
                return AssistantParseResult(action: .setAudioVolume(percent: number, deviceName: devName), feedback: "Set \(label) volume to \(number)%", confidence: 0.98)
            }
            if clean.contains("up") || clean.contains("louder") || clean.contains("increase") || clean.contains("boost") || clean.contains("raise") || clean.contains("higher") || clean.contains("more") || clean.contains("turn up") || clean.contains("crank") {
                let newVol = min(100, currentVol + 15)
                return AssistantParseResult(action: .setAudioVolume(percent: newVol, deviceName: devName), feedback: "Increased \(label) volume to \(newVol)%", confidence: 0.95)
            }
            if clean.contains("down") || clean.contains("softer") || clean.contains("lower") || clean.contains("decrease") || clean.contains("reduce") || clean.contains("less") || clean.contains("drop") || clean.contains("quieter") || clean.contains("turn down") {
                let newVol = max(0, currentVol - 15)
                return AssistantParseResult(action: .setAudioVolume(percent: newVol, deviceName: devName), feedback: "Decreased \(label) volume to \(newVol)%", confidence: 0.95)
            }
            // Generic "adjust volume", "change volume", etc.
            return AssistantParseResult(action: .setAudioVolume(percent: currentVol, deviceName: devName), feedback: "\(label) volume is at \(currentVol)%. Say 'volume to 60%' or 'volume up/down'.", confidence: 0.95)
        }

        // 6. Display Brightness / Monitor
        let isDisplayIntent = clean.contains("display") || clean.contains("monitor") || clean.contains("screen")
        if isDisplayIntent {
            let target = extractDisplayTarget(from: clean)
            let dispName = target.mentionedName
            let activeDisp = target.matchedDisplay ?? DeviceManager.shared.mainDisplay ?? DeviceManager.shared.displays.first
            let currentB = Int((activeDisp?.brightness ?? 0.7) * 100)
            let label = activeDisp?.name ?? dispName ?? "display"

            if let number = extractPercentageOrWordNumber(from: clean) {
                return AssistantParseResult(action: .setDisplayBrightness(percent: number, displayName: dispName), feedback: "Set \(label) brightness to \(number)%", confidence: 0.98)
            }
            if clean.contains("up") || clean.contains("brighter") || clean.contains("increase") || clean.contains("raise") || clean.contains("higher") || clean.contains("more") {
                let newB = min(100, currentB + 15)
                return AssistantParseResult(action: .setDisplayBrightness(percent: newB, displayName: dispName), feedback: "Increased \(label) brightness to \(newB)%", confidence: 0.95)
            }
            if clean.contains("down") || clean.contains("dim") || clean.contains("lower") || clean.contains("decrease") || clean.contains("reduce") || clean.contains("less") {
                let newB = max(10, currentB - 15)
                return AssistantParseResult(action: .setDisplayBrightness(percent: newB, displayName: dispName), feedback: "Dimmed \(label) brightness to \(newB)%", confidence: 0.95)
            }
            return AssistantParseResult(action: .setDisplayBrightness(percent: currentB, displayName: dispName), feedback: "\(label) brightness is at \(currentB)%. Say 'display to 80%' or 'screen brighter'.", confidence: 0.95)
        }

        // 7. Smart Light / Bulb Power
        let isLightContext = clean.contains("light") || clean.contains("bulb") || clean.contains("lamp") || clean.contains("room") || clean.contains("illumination") || clean.contains("glow")
        if !isVolumeIntent && !isDisplayIntent {
            if clean.contains("turn on") || clean.contains("switch on") || (isLightContext && clean.contains("on")) {
                return AssistantParseResult(action: .setBulbPower(isOn: true), feedback: "Turned smart light on", confidence: 0.95)
            }
            if clean.contains("turn off") || clean.contains("switch off") || (isLightContext && clean.contains("off")) {
                return AssistantParseResult(action: .setBulbPower(isOn: false), feedback: "Turned smart light off", confidence: 0.95)
            }
        }

        // 8. Smart Light Brightness
        if clean.contains("brightness") || clean.contains("dimming") || (isLightContext && (clean.contains("dim") || clean.contains("bright"))) {
            if let number = extractPercentageOrWordNumber(from: clean) {
                return AssistantParseResult(action: .setBulbBrightness(percent: number), feedback: "Set light brightness to \(number)%", confidence: 0.95)
            }
            if clean.contains("brighter") || clean.contains("brighten") {
                return AssistantParseResult(action: .setBulbBrightness(percent: 100), feedback: "Set light to maximum brightness", confidence: 0.85)
            }
            if clean.contains("dim") || clean.contains("darker") {
                return AssistantParseResult(action: .setBulbBrightness(percent: 20), feedback: "Dimmed light to 20%", confidence: 0.85)
            }
        }

        // 9. Smart Light Scenes
        for (sceneName, id) in knownScenes {
            if clean.contains(sceneName) {
                return AssistantParseResult(action: .setBulbScene(sceneId: id, name: sceneName.capitalized), feedback: "Set scene to \(sceneName.capitalized)", confidence: 0.9)
            }
        }

        // 10. Smart Light Color Temperature (Kelvin)
        if let kelvin = extractKelvin(from: clean) {
            return AssistantParseResult(action: .setBulbTemperature(kelvin: kelvin), feedback: "Set color temperature to \(kelvin)K", confidence: 0.95)
        }

        // 11. Smart Light Colors
        for (colorName, rgb) in knownColors {
            if clean.contains(colorName) {
                return AssistantParseResult(
                    action: .setBulbColor(red: rgb.r, green: rgb.g, blue: rgb.b, name: colorName.capitalized),
                    feedback: "Changed light color to \(colorName.capitalized)",
                    confidence: 0.95
                )
            }
        }

        // 12. Generic percentage
        if let number = extractPercentageOrWordNumber(from: clean) {
            if isLightContext {
                return AssistantParseResult(action: .setBulbBrightness(percent: number), feedback: "Set light brightness to \(number)%", confidence: 0.8)
            } else if isVolumeIntent {
                let target = extractAudioTarget(from: clean)
                let label = target.matchedDevice?.name ?? target.mentionedName ?? "volume"
                return AssistantParseResult(action: .setAudioVolume(percent: number, deviceName: target.mentionedName), feedback: "Set \(label) volume to \(number)%", confidence: 0.8)
            } else if isDisplayIntent {
                let target = extractDisplayTarget(from: clean)
                let label = target.matchedDisplay?.name ?? target.mentionedName ?? "display"
                return AssistantParseResult(action: .setDisplayBrightness(percent: number, displayName: target.mentionedName), feedback: "Set \(label) brightness to \(number)%", confidence: 0.8)
            }
        }

        return AssistantParseResult(action: .unknown(query: query), feedback: "Could not map '\(query)' to a known device action.", confidence: 0.1)
    }

    // MARK: - Daytime / Circadian Calculator
    private func isDaytimeIntent(_ text: String) -> Bool {
        let triggers = [
            "daytime", "day time", "match daylight", "match the daytime", "match daytime",
            "sync daylight", "circadian", "sunlight", "current time of day", "match the sun",
            "outside light", "natural light", "match outside"
        ]
        return triggers.contains { text.contains($0) }
    }

    private func calculateCircadianLighting() -> (kelvin: Int, brightness: Int, r: Int, g: Int, b: Int, description: String) {
        let hour = Calendar.current.component(.hour, from: Date())
        let minute = Calendar.current.component(.minute, from: Date())
        let currentDecimalHour = Double(hour) + Double(minute) / 60.0

        let kelvin: Int
        let brightness: Int
        let desc: String

        switch currentDecimalHour {
        case 5.5..<8.0:
            // Early sunrise: warm soft peach
            kelvin = 2700; brightness = 40; desc = "Gentle sunrise glow"
        case 8.0..<11.5:
            // Mid morning: crisp natural white
            kelvin = 4500; brightness = 80; desc = "Morning natural daylight"
        case 11.5..<15.5:
            // Midday peak: energetic 6000K daylight
            kelvin = 5800; brightness = 100; desc = "Midday peak sun"
        case 15.5..<18.5:
            // Late afternoon transition
            kelvin = 4000; brightness = 85; desc = "Afternoon balanced light"
        case 18.5..<21.0:
            // Sunset: warm cozy amber
            kelvin = 2800; brightness = 60; desc = "Sunset warm amber"
        case 21.0..<23.0:
            // Late evening: warm unwind
            kelvin = 2300; brightness = 35; desc = "Late evening warm unwind"
        default:
            // Night: ultra warm amber
            kelvin = 2000; brightness = 20; desc = "Nighttime sleep preparation"
        }

        let rgb = kelvinToRGB(kelvin: kelvin)
        return (kelvin, brightness, rgb.r, rgb.g, rgb.b, desc)
    }

    // MARK: - Semantic / Mood Matching via Apple NaturalLanguage NLEmbedding
    private func matchMoodPreset(_ text: String) -> MoodPreset? {
        // Direct keyword matching first
        for preset in moodPresets {
            for kw in preset.keywords {
                if text.contains(kw) {
                    return preset
                }
            }
        }

        // Semantic embedding distance check for user phrases like "i need peace", "unwind", "zen"
        if let emb = embedding {
            let tokens = text.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { $0.count > 3 }
            for token in tokens {
                var bestPreset: MoodPreset? = nil
                var bestDistance = 0.85 // threshold for cosine vector closeness

                for preset in moodPresets {
                    for targetWord in preset.keywords where !targetWord.contains(" ") {
                        let dist = emb.distance(between: token, and: targetWord)
                        if dist < bestDistance {
                            bestDistance = dist
                            bestPreset = preset
                        }
                    }
                }

                if let found = bestPreset {
                    return found
                }
            }
        }

        return nil
    }

    private func extractAudioTarget(from text: String) -> (matchedDevice: AudioItem?, mentionedName: String?) {
        let clean = text.lowercased()
        let outputDevices = DeviceManager.shared.audioDevices.filter { !$0.isInput }

        // 1. Direct contains check on full device name
        for dev in outputDevices {
            let dName = dev.name.lowercased()
            if clean.contains(dName) {
                return (dev, dev.name)
            }
        }

        // 2. Token matching (excluding generic filler words)
        let genericWords: Set<String> = [
            "audio", "device", "sound", "volume", "output", "the", "set", "adjust",
            "to", "for", "on", "in", "my", "a", "an", "at", "level", "turn", "make"
        ]
        for dev in outputDevices {
            let tokens = dev.name.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted).filter { $0.count >= 3 && !genericWords.contains($0) }
            for token in tokens {
                if clean.contains(token) {
                    return (dev, dev.name)
                }
            }
        }

        // 3. Synonym matching
        // Built-in MacBook speakers
        if clean.contains("macbook") || clean.contains("laptop") || clean.contains("internal") || clean.contains("built-in") || clean.contains("built in") || clean.contains("speaker") || clean.contains("speakers") {
            if let builtIn = outputDevices.first(where: {
                $0.transportType.lowercased() == "internal" ||
                $0.name.lowercased().contains("macbook") ||
                $0.name.lowercased().contains("built-in") ||
                $0.name.lowercased().contains("speaker")
            }) {
                return (builtIn, builtIn.name)
            }
        }

        // Bluetooth / Headphones / AirPods / external speakers
        if clean.contains("airpod") || clean.contains("headphone") || clean.contains("earphone") || clean.contains("earbud") || clean.contains("bluetooth") || clean.contains("wireless") || clean.contains("jbl") {
            if let bt = outputDevices.first(where: {
                $0.transportType.lowercased().contains("bluetooth") ||
                $0.name.lowercased().contains("airpod") ||
                $0.name.lowercased().contains("headphone") ||
                $0.name.lowercased().contains("jbl")
            }) {
                return (bt, bt.name)
            }
        }

        // HDMI / External monitor audio
        if clean.contains("hdmi") || clean.contains("monitor") || clean.contains("screen") || clean.contains("display") || clean.contains("acer") || clean.contains("tv") {
            if let ext = outputDevices.first(where: {
                $0.transportType.lowercased().contains("hdmi") ||
                $0.transportType.lowercased().contains("displayport") ||
                $0.name.lowercased().contains("sa272") ||
                $0.name.lowercased().contains("display")
            }) {
                return (ext, ext.name)
            }
        }

        return (nil, nil)
    }

    private func extractDisplayTarget(from text: String) -> (matchedDisplay: DisplayItem?, mentionedName: String?) {
        let clean = text.lowercased()
        let displays = DeviceManager.shared.displays

        // 1. Exact name match
        for disp in displays {
            let dName = disp.name.lowercased()
            if clean.contains(dName) {
                return (disp, disp.name)
            }
        }

        // 2. Token overlap
        let genericWords: Set<String> = ["display", "monitor", "screen", "the", "brightness", "dim", "bright", "set", "to", "my"]
        for disp in displays {
            let tokens = disp.name.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted).filter { $0.count >= 3 && !genericWords.contains($0) }
            for token in tokens {
                if clean.contains(token) {
                    return (disp, disp.name)
                }
            }
        }

        // 3. Synonyms
        if clean.contains("external") || clean.contains("second") || clean.contains("monitor") {
            if let ext = displays.first(where: { !$0.isBuiltIn }) {
                return (ext, ext.name)
            }
        }
        if clean.contains("internal") || clean.contains("built-in") || clean.contains("built in") || clean.contains("macbook") || clean.contains("laptop") {
            if let internalDisp = displays.first(where: { $0.isBuiltIn }) {
                return (internalDisp, internalDisp.name)
            }
        }

        return (nil, nil)
    }

    private func extractPercentage(from text: String) -> Int? {
        let regex = try? NSRegularExpression(pattern: #"(\d+)\s*(?:%|percent)?"#)
        let nsString = text as NSString
        if let match = regex?.firstMatch(in: text, options: [], range: NSRange(location: 0, length: nsString.length)) {
            let numberStr = nsString.substring(with: match.range(at: 1))
            if let num = Int(numberStr), num >= 0 && num <= 100 {
                return num
            }
        }
        return nil
    }

    private func extractPercentageOrWordNumber(from text: String) -> Int? {
        if let num = extractPercentage(from: text) {
            return num
        }

        let words = text.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
        let numberWords: [String: Int] = [
            "zero": 0, "one": 1, "two": 2, "three": 3, "four": 4, "five": 5,
            "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10,
            "eleven": 11, "twelve": 12, "thirteen": 13, "fourteen": 14, "fifteen": 15,
            "sixteen": 16, "seventeen": 17, "eighteen": 18, "nineteen": 19,
            "twenty": 20, "twenty-five": 25, "twenty five": 25,
            "thirty": 30, "thirty-five": 35, "thirty five": 35,
            "forty": 40, "forty-five": 45, "forty five": 45,
            "fifty": 50, "fifty-five": 55, "fifty five": 55,
            "sixty": 60, "sixty-five": 65, "sixty five": 65,
            "seventy": 70, "seventy-five": 75, "seventy five": 75,
            "eighty": 80, "eighty-five": 85, "eighty five": 85,
            "ninety": 90, "ninety-five": 95, "ninety five": 95,
            "hundred": 100, "half": 50, "max": 100, "maximum": 100, "full": 100,
            "min": 0, "minimum": 0
        ]

        for (phrase, val) in numberWords where phrase.contains(" ") {
            if text.contains(phrase) {
                return val
            }
        }

        for token in words {
            if let val = numberWords[token] {
                return val
            }
        }

        return nil
    }

    private func extractKelvin(from text: String) -> Int? {
        let regex = try? NSRegularExpression(pattern: #"(\d{4})\s*(?:k|kelvin)?"#)
        let nsString = text as NSString
        if let match = regex?.firstMatch(in: text, options: [], range: NSRange(location: 0, length: nsString.length)) {
            let numberStr = nsString.substring(with: match.range(at: 1))
            if let num = Int(numberStr), num >= 2000 && num <= 6500 {
                return num
            }
        }
        return nil
    }

    private func kelvinToRGB(kelvin: Int) -> (r: Int, g: Int, b: Int) {
        let temp = Double(kelvin) / 100.0
        var r: Double, g: Double, b: Double

        if temp <= 66 {
            r = 255.0
            g = 99.4708025861 * log(temp) - 161.1195681661
            if temp <= 19 {
                b = 0.0
            } else {
                b = 138.5177312231 * log(temp - 10) - 305.0447927307
            }
        } else {
            r = 329.698727446 * pow(temp - 60, -0.1332047592)
            g = 288.1221695283 * pow(temp - 60, -0.0755148492)
            b = 255.0
        }

        return (
            max(0, min(255, Int(r))),
            max(0, min(255, Int(g))),
            max(0, min(255, Int(b)))
        )
    }
}
