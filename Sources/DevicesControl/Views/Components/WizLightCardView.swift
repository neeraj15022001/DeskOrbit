import SwiftUI

public struct WizLightCardView: View {
    @ObservedObject var manager: DeviceManager
    public let light: WizLightItem
    public var isCompact: Bool = false

    @State private var isShowingLinkIPPopover: Bool = false
    @State private var linkIPInput: String = ""
    @State private var isHovered: Bool = false

    public init(manager: DeviceManager = .shared, light: WizLightItem, isCompact: Bool = false) {
        self.manager = manager
        self.light = light
        self.isCompact = isCompact
    }

    private var isTemperatureMode: Bool {
        manager.activeLightModes[light.id] == "Whites" || (manager.activeLightModes[light.id] == nil && light.colorTemperature != nil)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: isCompact ? 10 : 12) {
            // MARK: - Header
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(bulbGlowColor.opacity(light.isOn ? 0.22 : 0.08))
                        .frame(width: isCompact ? 36 : 42, height: isCompact ? 36 : 42)

                    Image(systemName: light.isOn ? "lightbulb.fill" : "lightbulb.slash")
                        .font(.system(size: isCompact ? 17 : 20, weight: .semibold))
                        .foregroundColor(light.isOn ? bulbGlowColor : .secondary)
                        .shadow(color: light.isOn ? bulbGlowColor.opacity(0.4) : .clear, radius: 6)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(light.name)
                            .font(.system(size: isCompact ? 12 : 13, weight: .semibold))
                            .lineLimit(1)

                        if !light.isReachable {
                            Text("Offline")
                                .font(.system(size: 10, weight: .medium))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.red.opacity(0.12))
                                .foregroundColor(.red)
                                .clipShape(Capsule())
                        }
                    }

                    // Connection Badge & Subtitle
                    HStack(spacing: 4) {
                        Image(systemName: light.connectionBadgeIcon)
                            .font(.system(size: 9))
                            .foregroundColor(.green)

                        Text(connectionSubtitleText)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                            .lineLimit(1)

                        if !isCompact && !light.hasLocalConnection {
                            Button(action: {
                                isShowingLinkIPPopover = true
                            }) {
                                Text("+ Set IP")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.accentColor)
                            }
                            .buttonStyle(.plain)
                            .popover(isPresented: $isShowingLinkIPPopover) {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Set Local Wi-Fi IP")
                                        .font(.system(size: 13, weight: .semibold))
                                    Text("Enter your bulb's LAN IP address for direct authenticated UDP control (port 38899).")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)

                                    TextField("e.g. 192.168.1.6", text: $linkIPInput)
                                        .textFieldStyle(.roundedBorder)
                                        .controlSize(.regular)

                                    HStack {
                                        Button("Cancel") {
                                            isShowingLinkIPPopover = false
                                        }
                                        .controlSize(.regular)

                                        Spacer()

                                        Button("Save IP") {
                                            manager.linkLocalIPToBulb(bulbId: light.id, ip: linkIPInput) { success in
                                                if success {
                                                    isShowingLinkIPPopover = false
                                                    linkIPInput = ""
                                                }
                                            }
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .controlSize(.regular)
                                        .disabled(linkIPInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                    }
                                }
                                .padding(14)
                                .frame(width: 270)
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
                        .font(.system(size: isCompact ? 12 : 13, weight: .bold))
                        .foregroundColor(light.isOn ? .white : .secondary)
                        .frame(width: isCompact ? 28 : 32, height: isCompact ? 28 : 32)
                        .background(light.isOn ? Color.green : Color.primary.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help(light.isOn ? "Turn Off Light" : "Turn On Light")

                // Overflow Options Menu
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
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                    .menuIndicator(.hidden)
                }
            }

            // MARK: - Control Center Style Brightness Capsule Slider
            OrbitCapsuleSlider(
                icon: "sun.max.fill",
                label: "Brightness",
                value: Binding(
                    get: { Float(light.brightness) / 100.0 },
                    set: { manager.setLightBrightness(light: light, brightness: Int(round($0 * 100.0))) }
                ),
                tint: light.isOn ? (isTemperatureMode ? .orange : bulbGlowColor) : .gray,
                isEnabled: light.isOn
            )

            // MARK: - Color & Temperature Controls
            if light.isOn {
                VStack(alignment: .leading, spacing: 8) {
                    // Segmented Mode Selector Pills
                    HStack(spacing: 6) {
                        Button(action: {
                            manager.activeLightModes[light.id] = "Colors"
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "paintpalette.fill")
                                    .font(.system(size: 10))
                                Text("Colors")
                                    .font(.system(size: 11, weight: !isTemperatureMode ? .semibold : .medium))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(!isTemperatureMode ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.04))
                            .foregroundColor(!isTemperatureMode ? .accentColor : .secondary)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        Button(action: {
                            manager.activeLightModes[light.id] = "Whites"
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "sun.dust.fill")
                                    .font(.system(size: 10))
                                Text("Whites")
                                    .font(.system(size: 11, weight: isTemperatureMode ? .semibold : .medium))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(isTemperatureMode ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.04))
                            .foregroundColor(isTemperatureMode ? .accentColor : .secondary)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        Spacer()
                    }

                    if !isTemperatureMode {
                        HStack(spacing: 8) {
                            // Native macOS RGB Color Picker
                            HStack(spacing: 5) {
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
                                .help("Custom Color Wheel & Palette")

                                Text(String(format: "#%02X%02X%02X", light.red, light.green, light.blue))
                                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.primary.opacity(0.05))
                            .cornerRadius(8)

                            Divider().frame(height: 20)

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
                                                        .stroke(Color.white.opacity(isPresetSelected(preset) ? 0.9 : 0.15), lineWidth: isPresetSelected(preset) ? 2 : 1)
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
                        // White Temperature Spectrum Slider (Kelvin)
                        VStack(spacing: 4) {
                            HStack {
                                Text("2200K (Warm)")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.orange)
                                Spacer()
                                Text("\(light.colorTemperature ?? 2700)K")
                                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                    .foregroundColor(.primary)
                                Spacer()
                                Text("6500K (Cool)")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.cyan)
                            }

                            OrbitKelvinSlider(
                                kelvin: Binding(
                                    get: { light.colorTemperature ?? 2700 },
                                    set: { manager.setLightTemperature(light: light, kelvin: $0) }
                                ),
                                isEnabled: light.isOn
                            )
                        }
                    }

                    // Quick Scenes Bar
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
        .padding(isCompact ? 12 : 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: Color.black.opacity(isHovered ? 0.08 : 0.03), radius: isHovered ? 6 : 2, x: 0, y: isHovered ? 2 : 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    light.isOn ? bulbGlowColor.opacity(isHovered ? 0.35 : 0.18) : (isHovered ? Color.primary.opacity(0.12) : Color.primary.opacity(0.06)),
                    lineWidth: 1
                )
        )
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.15), value: isHovered)
    }

    // MARK: - Helpers

    private var connectionSubtitleText: String {
        if light.hasLocalConnection {
            return "\(light.ip):38899"
        } else {
            return "Local (Unassigned IP)"
        }
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
    @State private var isHovering: Bool = false

    var body: some View {
        Button(action: {
            manager.setLightScene(light: light, sceneId: sceneId)
        }) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                Text(name)
                    .font(.system(size: 10, weight: .medium))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isHovering ? Color.primary.opacity(0.08) : Color.primary.opacity(0.04))
            .foregroundColor(.primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}
