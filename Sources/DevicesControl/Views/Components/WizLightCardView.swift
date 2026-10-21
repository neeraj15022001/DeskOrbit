import SwiftUI

public struct WizLightCardView: View {
    @ObservedObject var manager: DeviceManager
    public let light: WizLightItem
    public var isCompact: Bool = false

    @State private var isShowingLinkIPPopover: Bool = false
    @State private var linkIPInput: String = ""

    public init(manager: DeviceManager = .shared, light: WizLightItem, isCompact: Bool = false) {
        self.manager = manager
        self.light = light
        self.isCompact = isCompact
    }

    private var isTemperatureMode: Bool {
        manager.activeLightModes[light.id] == "Whites" || (manager.activeLightModes[light.id] == nil && light.colorTemperature != nil)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: isCompact ? 10 : 14) {
            // MARK: - Header
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(bulbGlowColor.opacity(light.isOn ? 0.25 : 0.08))
                        .frame(width: isCompact ? 36 : 44, height: isCompact ? 36 : 44)

                    Image(systemName: light.isOn ? "lightbulb.fill" : "lightbulb.slash")
                        .font(.system(size: isCompact ? 18 : 22, weight: .semibold))
                        .foregroundColor(light.isOn ? bulbGlowColor : .secondary)
                        .shadow(color: light.isOn ? bulbGlowColor.opacity(0.6) : .clear, radius: 8)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(light.name)
                            .font(.system(size: isCompact ? 12 : 14, weight: .bold))
                            .lineLimit(1)

                        if !light.isReachable {
                            Text("Offline")
                                .font(.system(size: 8, weight: .semibold))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.red.opacity(0.15))
                                .foregroundColor(.red)
                                .cornerRadius(4)
                        }
                    }

                    // Dynamic Connection Mode Badge & Subtitle
                    HStack(spacing: 4) {
                        Image(systemName: light.connectionBadgeIcon)
                            .font(.system(size: 8))
                            .foregroundColor(badgeColor)

                        Text(connectionSubtitleText)
                            .font(.system(size: isCompact ? 9 : 10, design: .monospaced))
                            .foregroundColor(.secondary)
                            .lineLimit(1)

                        if !isCompact && !light.hasLocalConnection {
                            Button(action: {
                                isShowingLinkIPPopover = true
                            }) {
                                Text("+ Set IP")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.accentColor)
                            }
                            .buttonStyle(.plain)
                            .popover(isPresented: $isShowingLinkIPPopover) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Set Local Wi-Fi IP")
                                        .font(.system(size: 12, weight: .bold))
                                    Text("Enter your bulb's LAN IP for direct signed UDP control (port 38899).")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)

                                    TextField("e.g. 192.168.1.6", text: $linkIPInput)
                                        .textFieldStyle(.roundedBorder)
                                        .controlSize(.small)

                                    HStack {
                                        Button("Cancel") {
                                            isShowingLinkIPPopover = false
                                        }
                                        .controlSize(.small)

                                        Spacer()

                                        Button("Set IP") {
                                            manager.linkLocalIPToBulb(bulbId: light.id, ip: linkIPInput) { success in
                                                if success {
                                                    isShowingLinkIPPopover = false
                                                    linkIPInput = ""
                                                }
                                            }
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .controlSize(.small)
                                        .disabled(linkIPInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                    }
                                }
                                .padding(12)
                                .frame(width: 250)
                            }
                        }
                    }
                }

                Spacer()

                // Power Toggle Button
                Button(action: {
                    manager.toggleLightPower(light: light)
                }) {
                    Image(systemName: "power")
                        .font(.system(size: isCompact ? 12 : 14, weight: .bold))
                        .foregroundColor(light.isOn ? .white : .secondary)
                        .padding(isCompact ? 6 : 8)
                        .background(light.isOn ? Color.green : Color.primary.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help(light.isOn ? "Turn Off" : "Turn On")

                // Option Menu (Remove / Details)
                if !isCompact {
                    Menu {
                        if light.hasLocalConnection {
                            Text("IP: \(light.ip):38899")
                        }
                        if !light.mac.isEmpty {
                            Text("MAC: \(light.mac)")
                        }
                        if let fw = light.firmwareVersion {
                            Text("Firmware: \(fw)")
                        }
                        if let mdl = light.moduleModel {
                            Text("Model: \(mdl)")
                        }
                        Divider()
                        Button(role: .destructive, action: {
                            manager.removeSmartLight(id: light.id)
                        }) {
                            Label("Remove Bulb", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .menuIndicator(.hidden)
                }
            }

            // MARK: - Brightness Slider
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Text("Brightness")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(light.brightness)%")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(light.isOn ? .primary : .secondary)
                }

                Slider(value: Binding(
                    get: { Double(light.brightness) },
                    set: { manager.setLightBrightness(light: light, brightness: Int($0)) }
                ), in: 10...100)
                .controlSize(isCompact ? .mini : .small)
                .disabled(!light.isOn)
                .opacity(light.isOn ? 1.0 : 0.4)
            }

            // MARK: - Color & Temperature Controls
            if light.isOn {
                VStack(alignment: .leading, spacing: 8) {
                    // Mode Selector Pill Buttons
                    HStack(spacing: 8) {
                        Button(action: {
                            manager.activeLightModes[light.id] = "Colors"
                        }) {
                            Text("Colors")
                                .font(.system(size: 10, weight: !isTemperatureMode ? .bold : .medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(!isTemperatureMode ? Color.accentColor.opacity(0.2) : Color.primary.opacity(0.04))
                                .foregroundColor(!isTemperatureMode ? .accentColor : .secondary)
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)

                        Button(action: {
                            manager.activeLightModes[light.id] = "Whites"
                        }) {
                            Text("Whites")
                                .font(.system(size: 10, weight: isTemperatureMode ? .bold : .medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(isTemperatureMode ? Color.accentColor.opacity(0.2) : Color.primary.opacity(0.04))
                                .foregroundColor(isTemperatureMode ? .accentColor : .secondary)
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)

                        Spacer()
                    }

                    if !isTemperatureMode {
                        HStack(spacing: 8) {
                            // Native macOS RGB Color Picker
                            HStack(spacing: 4) {
                                ColorPicker("", selection: Binding(
                                    get: {
                                        Color(
                                            red: Double(light.red) / 255.0,
                                            green: Double(light.green) / 255.0,
                                            blue: Double(light.blue) / 255.0
                                        )
                                    },
                                    set: { newColor in
                                        if let rgb = NSColor(newColor).usingColorSpace(.sRGB) {
                                            let r = max(0, min(255, Int(round(rgb.redComponent * 255.0))))
                                            let g = max(0, min(255, Int(round(rgb.greenComponent * 255.0))))
                                            let b = max(0, min(255, Int(round(rgb.blueComponent * 255.0))))
                                            manager.setLightRGBColor(light: light, red: r, green: g, blue: b)
                                        }
                                    }
                                ), supportsOpacity: false)
                                .labelsHidden()
                                .frame(width: isCompact ? 22 : 26, height: isCompact ? 22 : 26)
                                .help("Custom RGB Color Picker (Wheel, Sliders, Palette)")

                                Text(String(format: "#%02X%02X%02X", light.red, light.green, light.blue))
                                    .font(.system(size: isCompact ? 8 : 9, weight: .bold, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.primary.opacity(0.06))
                            .cornerRadius(8)

                            Divider()
                                .frame(height: isCompact ? 18 : 22)

                            // RGB Preset Swatches
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    ForEach(colorPresets, id: \.name) { preset in
                                        Button(action: {
                                            manager.setLightRGBColor(light: light, red: preset.r, green: preset.g, blue: preset.b)
                                        }) {
                                            Circle()
                                                .fill(Color(red: Double(preset.r)/255, green: Double(preset.g)/255, blue: Double(preset.b)/255))
                                                .frame(width: isCompact ? 18 : 22, height: isCompact ? 18 : 22)
                                                .overlay(
                                                    Circle()
                                                        .stroke(Color.white.opacity(isPresetSelected(preset) ? 0.9 : 0.1), lineWidth: isPresetSelected(preset) ? 2 : 1)
                                                )
                                        }
                                        .buttonStyle(.plain)
                                        .help(preset.name)
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    } else {
                        // White Temperature Slider (Kelvin)
                        VStack(spacing: 4) {
                            HStack {
                                Text("Warm (2200K)")
                                    .font(.system(size: 9))
                                    .foregroundColor(.orange)
                                Spacer()
                                Text("\(light.colorTemperature ?? 2700)K")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)
                                Spacer()
                                Text("Cool (6500K)")
                                    .font(.system(size: 9))
                                    .foregroundColor(.cyan)
                            }

                            Slider(value: Binding(
                                get: { Double(light.colorTemperature ?? 2700) },
                                set: { manager.setLightTemperature(light: light, kelvin: Int($0)) }
                            ), in: 2200...6500)
                            .controlSize(isCompact ? .mini : .small)
                        }
                    }

                    // Quick Scenes Bar (Non-compact only)
                    if !isCompact {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                SceneChip(name: "Warm White", icon: "lamp.table.fill", sceneId: 11, light: light, manager: manager)
                                SceneChip(name: "Daylight", icon: "sun.max.fill", sceneId: 12, light: light, manager: manager)
                                SceneChip(name: "Cozy", icon: "flame.fill", sceneId: 6, light: light, manager: manager)
                                SceneChip(name: "Night Light", icon: "moon.stars.fill", sceneId: 14, light: light, manager: manager)
                                if light.hasLocalConnection {
                                    SceneChip(name: "Fireplace", icon: "fireplace.fill", sceneId: 5, light: light, manager: manager)
                                    SceneChip(name: "Sunset", icon: "sunset.fill", sceneId: 9, light: light, manager: manager)
                                    SceneChip(name: "Party", icon: "sparkles", sceneId: 4, light: light, manager: manager)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
                .transition(.opacity)
            }
        }
        .padding(isCompact ? 10 : 14)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(bulbGlowColor.opacity(light.isOn ? 0.35 : 0.08), lineWidth: 1)
        )
    }

    // MARK: - Helpers

    private var connectionSubtitleText: String {
        if light.hasLocalConnection {
            return "WiZ v2 Local: \(light.ip):38899"
        } else {
            return "WiZ v2 Local (Unassigned IP)"
        }
    }

    private var badgeColor: Color {
        return .green
    }

    private var bulbGlowColor: Color {
        Color(
            red: Double(light.red) / 255.0,
            green: Double(light.green) / 255.0,
            blue: Double(light.blue) / 255.0
        )
    }

    private func isPresetSelected(_ preset: ColorPreset) -> Bool {
        return abs(light.red - preset.r) < 10 &&
               abs(light.green - preset.g) < 10 &&
               abs(light.blue - preset.b) < 10
    }

    private struct ColorPreset {
        let name: String
        let r: Int
        let g: Int
        let b: Int
    }

    private var colorPresets: [ColorPreset] {
        [
            ColorPreset(name: "Warm Amber", r: 255, g: 160, b: 40),
            ColorPreset(name: "Candlelight", r: 255, g: 130, b: 20),
            ColorPreset(name: "Sunset Orange", r: 255, g: 75, b: 20),
            ColorPreset(name: "Crimson Red", r: 255, g: 25, b: 45),
            ColorPreset(name: "Neon Pink", r: 255, g: 20, b: 147),
            ColorPreset(name: "Deep Purple", r: 160, g: 32, b: 240),
            ColorPreset(name: "Ocean Blue", r: 0, g: 110, b: 255),
            ColorPreset(name: "Cyber Cyan", r: 0, g: 230, b: 255),
            ColorPreset(name: "Emerald Green", r: 35, g: 220, b: 90),
            ColorPreset(name: "Pure White", r: 255, g: 255, b: 255)
        ]
    }
}

private struct SceneChip: View {
    let name: String
    let icon: String
    let sceneId: Int
    let light: WizLightItem
    @ObservedObject var manager: DeviceManager

    var body: some View {
        Button(action: {
            manager.setLightScene(light: light, sceneId: sceneId)
        }) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 8))
                Text(name)
                    .font(.system(size: 9, weight: .medium))
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(Color.primary.opacity(0.04))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}
