import Foundation
import AppIntents

// MARK: - App Shortcuts Provider for Siri AI
@available(macOS 14.0, *)
public struct DeskOrbitShortcutsProvider: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: TurnLightOnIntent(),
            phrases: [
                "\(.applicationName) lights on",
                "\(.applicationName) turn on lights",
                "Ask \(.applicationName) to turn on lights",
                "Switch on desk light with \(.applicationName)"
            ],
            shortTitle: "Turn Lights On",
            systemImageName: "lightbulb.fill"
        )

        AppShortcut(
            intent: TurnLightOffIntent(),
            phrases: [
                "\(.applicationName) lights off",
                "\(.applicationName) turn off lights",
                "Ask \(.applicationName) to turn off lights",
                "Switch off desk light with \(.applicationName)"
            ],
            shortTitle: "Turn Lights Off",
            systemImageName: "lightbulb"
        )

        AppShortcut(
            intent: SetBulbBrightnessIntent(),
            phrases: [
                "\(.applicationName) set brightness to \(\.$brightness)",
                "Ask \(.applicationName) to set brightness to \(\.$brightness)",
                "Dim \(.applicationName) lights to \(\.$brightness)"
            ],
            shortTitle: "Set Light Brightness",
            systemImageName: "sun.max.fill"
        )

        AppShortcut(
            intent: SetBulbColorIntent(),
            phrases: [
                "\(.applicationName) color \(\.$colorName)",
                "\(.applicationName) set color to \(\.$colorName)",
                "Ask \(.applicationName) to set color to \(\.$colorName)",
                "Make \(.applicationName) light \(\.$colorName)"
            ],
            shortTitle: "Set Light Color",
            systemImageName: "paintpalette.fill"
        )

        AppShortcut(
            intent: SetAudioVolumeIntent(),
            phrases: [
                "\(.applicationName) volume \(\.$volume)",
                "Ask \(.applicationName) to set volume to \(\.$volume)",
                "Change \(.applicationName) volume to \(\.$volume)"
            ],
            shortTitle: "Set Audio Volume",
            systemImageName: "speaker.wave.2.fill"
        )

        AppShortcut(
            intent: SetDisplayBrightnessIntent(),
            phrases: [
                "\(.applicationName) screen brightness \(\.$brightness)",
                "Ask \(.applicationName) to set screen brightness to \(\.$brightness)"
            ],
            shortTitle: "Set Screen Brightness",
            systemImageName: "display"
        )
    }
}

// MARK: - Intent 1: Turn Lights On
@available(macOS 14.0, *)
public struct TurnLightOnIntent: AppIntent {
    public static var title: LocalizedStringResource = "Turn Light On"
    public static var description = IntentDescription("Turn on smart bulb via WiZ v2 signed UDP")

    public init() {}

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let mgr = DeviceManager.shared
        if let light = mgr.smartLights.first {
            mgr.wizLightService.setPower(for: light, isOn: true)
            return .result(dialog: "Turned \(light.name) on.")
        } else {
            return .result(dialog: "No smart bulbs configured in DeskOrbit.")
        }
    }
}

// MARK: - Intent 2: Turn Lights Off
@available(macOS 14.0, *)
public struct TurnLightOffIntent: AppIntent {
    public static var title: LocalizedStringResource = "Turn Light Off"
    public static var description = IntentDescription("Turn off smart bulb via WiZ v2 signed UDP")

    public init() {}

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let mgr = DeviceManager.shared
        if let light = mgr.smartLights.first {
            mgr.wizLightService.setPower(for: light, isOn: false)
            return .result(dialog: "Turned \(light.name) off.")
        } else {
            return .result(dialog: "No smart bulbs configured in DeskOrbit.")
        }
    }
}

// MARK: - Intent 3: Bulb Brightness
@available(macOS 14.0, *)
public struct SetBulbBrightnessIntent: AppIntent {
    public static var title: LocalizedStringResource = "Set Light Brightness"
    public static var description = IntentDescription("Set smart light dimming level (10% to 100%)")

    @Parameter(title: "Brightness", default: 80, inclusiveRange: (10, 100))
    public var brightness: Int

    public init() {}

    public init(brightness: Int) {
        self.brightness = brightness
    }

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let mgr = DeviceManager.shared
        let clamped = max(10, min(100, brightness))
        if let light = mgr.smartLights.first {
            mgr.wizLightService.setBrightness(for: light, brightness: clamped)
            return .result(dialog: "Set \(light.name) brightness to \(clamped)%.")
        } else {
            return .result(dialog: "No smart bulbs configured in DeskOrbit.")
        }
    }
}

// MARK: - Intent 4: Bulb Color
@available(macOS 14.0, *)
public struct SetBulbColorIntent: AppIntent {
    public static var title: LocalizedStringResource = "Set Light Color"
    public static var description = IntentDescription("Change smart light color (red, blue, green, purple, warm white, etc.)")

    @Parameter(title: "Color", default: "Warm White")
    public var colorName: String

    public init() {}

    public init(colorName: String) {
        self.colorName = colorName
    }

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let parsed = OrbitNaturalLanguageParser.shared.parse(query: "change color to \(colorName)")
        let mgr = DeviceManager.shared

        if case .setBulbColor(let r, let g, let b, let name) = parsed.action {
            if let light = mgr.smartLights.first {
                mgr.wizLightService.setRGBColor(for: light, red: r, green: g, blue: b)
                return .result(dialog: "Changed light color to \(name).")
            } else {
                return .result(dialog: "No smart bulbs found in DeskOrbit.")
            }
        } else {
            return .result(dialog: "Color '\(colorName)' not recognized. Try red, green, blue, cyan, purple, or warm white.")
        }
    }
}

// MARK: - Intent 5: Audio Volume
@available(macOS 14.0, *)
public struct SetAudioVolumeIntent: AppIntent {
    public static var title: LocalizedStringResource = "Set Audio Volume"
    public static var description = IntentDescription("Change system master audio output volume")

    @Parameter(title: "Volume", default: 50, inclusiveRange: (0, 100))
    public var volume: Int

    public init() {}

    public init(volume: Int) {
        self.volume = volume
    }

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let mgr = DeviceManager.shared
        let clamped = max(0, min(100, volume))
        if let out = mgr.defaultAudioOutput {
            mgr.setAudioVolume(deviceID: out.id, volume: Float(clamped) / 100.0)
            return .result(dialog: "Set \(out.name) volume to \(clamped)%.")
        } else {
            return .result(dialog: "No default audio output found.")
        }
    }
}

// MARK: - Intent 6: Display Brightness
@available(macOS 14.0, *)
public struct SetDisplayBrightnessIntent: AppIntent {
    public static var title: LocalizedStringResource = "Set Display Brightness"
    public static var description = IntentDescription("Change external monitor or display luminance via DDC/CI or Gamma LUT")

    @Parameter(title: "Brightness", default: 80, inclusiveRange: (10, 100))
    public var brightness: Int

    public init() {}

    public init(brightness: Int) {
        self.brightness = brightness
    }

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let mgr = DeviceManager.shared
        let clamped = max(10, min(100, brightness))
        if let disp = mgr.mainDisplay ?? mgr.displays.first {
            mgr.setDisplayBrightness(displayID: disp.id, brightness: Float(clamped) / 100.0)
            return .result(dialog: "Set \(disp.name) brightness to \(clamped)%.")
        } else {
            return .result(dialog: "No displays detected.")
        }
    }
}
