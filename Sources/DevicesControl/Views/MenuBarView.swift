import SwiftUI

public struct MenuBarView: View {
    @ObservedObject var manager: DeviceManager
    let onOpenDashboard: () -> Void
    let onQuit: () -> Void

    public init(
        manager: DeviceManager = .shared,
        onOpenDashboard: @escaping () -> Void,
        onQuit: @escaping () -> Void = { NSApp.terminate(nil) }
    ) {
        self.manager = manager
        self.onOpenDashboard = onOpenDashboard
        self.onQuit = onQuit
    }

    public var body: some View {
        VStack(spacing: 0) {
            // MARK: - Top Header Bar
            HStack(spacing: 8) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.accentColor)

                Text("DeskOrbit")
                    .font(.system(size: 13, weight: .bold))

                // Active Devices Capsule
                let activeCount = manager.displays.count + manager.smartLights.count + manager.bluetoothDevices.filter { $0.isConnected }.count
                Text("\(activeCount) active")
                    .font(.system(size: 10, weight: .semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.12))
                    .foregroundColor(.accentColor)
                    .clipShape(Capsule())

                Spacer()

                // Voice Assistant Mic Button
                Button(action: {
                    VoiceAssistantService.shared.toggleListening(manager: manager)
                }) {
                    Image(systemName: VoiceAssistantService.shared.state == .listening ? "waveform.circle.fill" : "mic.circle.fill")
                        .font(.system(size: 15))
                        .foregroundColor(VoiceAssistantService.shared.state == .listening ? .pink : .accentColor)
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Speak Voice Command (Apple Intelligence)")

                // Refresh Button (28x28 minimum hit target)
                Button(action: { manager.refreshAll() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Refresh All Connected Hardware")

                // Dashboard Button
                Button(action: onOpenDashboard) {
                    HStack(spacing: 4) {
                        Image(systemName: "macwindow")
                            .font(.system(size: 10))
                        Text("Dashboard")
                            .font(.system(size: 11, weight: .medium))
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Open Full DeskOrbit Dashboard Window")

                // Overflow / App Actions Menu
                Menu {
                    Button(action: onOpenDashboard) {
                        Label("Open Dashboard Window", systemImage: "macwindow")
                    }
                    Button(action: { manager.scanLocalWiZLights() }) {
                        Label("Scan Local WiZ Bulbs", systemImage: "wifi")
                    }
                    Button(action: { manager.refreshAll() }) {
                        Label("Refresh Hardware", systemImage: "arrow.clockwise")
                    }
                    Divider()
                    Button(role: .destructive, action: onQuit) {
                        Label("Quit DeskOrbit", systemImage: "power")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .menuIndicator(.hidden)
                .help("App Options")
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()

            // Status message banner if any
            if let status = manager.statusMessage {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.accentColor)
                        .font(.system(size: 11))
                    Text(status)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.accentColor.opacity(0.08))
            }

            // MARK: - Side-by-Side Main Content
            HStack(alignment: .top, spacing: 0) {
                // LEFT COLUMN: Device Controllers
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {

                        // 1. Display Brightness Section
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Label("Displays", systemImage: "display")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(manager.displays.count)")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }

                            if manager.displays.isEmpty {
                                Text("No external displays detected")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                    .padding(.vertical, 4)
                            } else {
                                ForEach(manager.displays) { display in
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack {
                                            Text(display.name)
                                                .font(.system(size: 12, weight: .medium))
                                                .lineLimit(1)
                                            if display.isMain {
                                                Text("Main")
                                                    .font(.system(size: 10, weight: .semibold))
                                                    .padding(.horizontal, 5)
                                                    .padding(.vertical, 1)
                                                    .background(Color.accentColor.opacity(0.12))
                                                    .foregroundColor(.accentColor)
                                                    .clipShape(Capsule())
                                            }
                                            Spacer()
                                        }

                                        OrbitCapsuleSlider(
                                            icon: "sun.max.fill",
                                            label: "Luminance",
                                            value: Binding(
                                                get: { display.brightness },
                                                set: { manager.setDisplayBrightness(displayID: display.id, brightness: $0) }
                                            ),
                                            tint: .accentColor
                                        )
                                    }
                                    .padding(10)
                                    .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
                                    .cornerRadius(10)
                                }
                            }
                        }

                        // 2. Smart Lights (Philips WiZ)
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Label("Smart Lights", systemImage: "lightbulb.fill")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Button(action: { manager.scanLocalWiZLights() }) {
                                    HStack(spacing: 4) {
                                        if manager.wizLightService.isScanningLocal {
                                            ProgressView().controlSize(.mini)
                                        } else {
                                            Image(systemName: "wifi")
                                        }
                                        Text("Scan")
                                    }
                                    .font(.system(size: 10, weight: .semibold))
                                }
                                .buttonStyle(.plain)
                                .foregroundColor(.green)
                                .help("Scan Local Wi-Fi (UDP 38899)")
                            }

                            if manager.smartLights.isEmpty {
                                HStack {
                                    Text("No WiZ bulbs configured")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Button(action: onOpenDashboard) {
                                        Text("Setup")
                                            .font(.system(size: 10, weight: .bold))
                                    }
                                    .controlSize(.small)
                                }
                                .padding(10)
                                .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
                                .cornerRadius(10)
                            } else {
                                ForEach(manager.smartLights) { light in
                                    WizLightCardView(manager: manager, light: light, isCompact: true)
                                }
                            }
                        }

                        // 3. Audio Control Section
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Label("Audio Output", systemImage: "speaker.wave.2")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.secondary)
                                Spacer()
                                if let defaultOut = manager.defaultAudioOutput {
                                    Text(defaultOut.name)
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            }

                            if let defaultDevice = manager.defaultAudioOutput {
                                VStack(spacing: 8) {
                                    HStack(spacing: 8) {
                                        Button(action: { manager.toggleAudioMute(device: defaultDevice) }) {
                                            Image(systemName: defaultDevice.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundColor(defaultDevice.isMuted ? .red : .accentColor)
                                                .frame(width: 28, height: 28)
                                                .background(Color.primary.opacity(0.04))
                                                .clipShape(Circle())
                                        }
                                        .buttonStyle(.plain)
                                        .help(defaultDevice.isMuted ? "Unmute Audio" : "Mute Audio")

                                        OrbitCapsuleSlider(
                                            icon: defaultDevice.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                                            label: "Volume",
                                            value: Binding(
                                                get: { defaultDevice.volume },
                                                set: { manager.setAudioVolume(deviceID: defaultDevice.id, volume: $0) }
                                            ),
                                            tint: defaultDevice.isMuted ? .gray : .accentColor,
                                            isEnabled: !defaultDevice.isMuted
                                        )
                                    }

                                    let outputs = manager.audioDevices.filter { $0.isOutput }
                                    if outputs.count > 1 {
                                        Picker("", selection: Binding(
                                            get: { defaultDevice.id },
                                            set: { newID in
                                                if let target = outputs.first(where: { $0.id == newID }) {
                                                    manager.setDefaultAudioOutput(device: target)
                                                }
                                            }
                                        )) {
                                            ForEach(outputs) { out in
                                                Text(out.name).tag(out.id)
                                            }
                                        }
                                        .pickerStyle(.menu)
                                        .labelsHidden()
                                        .controlSize(.small)
                                    }
                                }
                                .padding(10)
                                .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
                                .cornerRadius(10)
                            } else {
                                Text("No audio output device found")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }

                        // 4. Bluetooth Devices
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Label("Bluetooth", systemImage: "dot.radiowaves.left.and.right")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.secondary)
                                Spacer()
                                let connectedCount = manager.bluetoothDevices.filter { $0.isConnected }.count
                                Text("\(connectedCount) Connected")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.secondary)
                            }

                            let connectedBT = manager.bluetoothDevices.filter { $0.isConnected }
                            if connectedBT.isEmpty {
                                Text("No active Bluetooth devices")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            } else {
                                ForEach(connectedBT) { device in
                                    HStack {
                                        Image(systemName: "headphones")
                                            .font(.system(size: 12))
                                            .foregroundColor(.accentColor)
                                        Text(device.name)
                                            .font(.system(size: 11, weight: .medium))
                                            .lineLimit(1)
                                        Spacer()
                                        if let battery = device.batteryPercent {
                                            HStack(spacing: 3) {
                                                Image(systemName: batteryIcon(for: battery))
                                                    .font(.system(size: 11))
                                                    .foregroundColor(batteryColor(for: battery))
                                                Text("\(battery)%")
                                                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                            }
                                        }
                                        Button(action: { manager.toggleBluetooth(device: device) }) {
                                            Text("Disconnect")
                                                .font(.system(size: 10))
                                        }
                                        .controlSize(.mini)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
                                    .cornerRadius(8)
                                }
                            }
                        }

                        // 5. External Storage
                        if !manager.storageDevices.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Label("Storage", systemImage: "externaldrive")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }

                                ForEach(manager.storageDevices) { storage in
                                    HStack {
                                        Image(systemName: "externaldrive.fill")
                                            .font(.system(size: 13))
                                            .foregroundColor(.orange)
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(storage.name)
                                                .font(.system(size: 11, weight: .medium))
                                                .lineLimit(1)
                                            Text("\(storage.formattedFree) free of \(storage.formattedTotal)")
                                                .font(.system(size: 10))
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        Button(action: { manager.ejectStorage(device: storage) }) {
                                            Image(systemName: "eject.fill")
                                                .font(.system(size: 11))
                                                .frame(width: 24, height: 24)
                                        }
                                        .buttonStyle(.plain)
                                        .help("Eject \(storage.name)")
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
                                    .cornerRadius(8)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }
                .frame(width: 310)

                // Vertical Divider between columns
                Divider()

                // RIGHT COLUMN: Battery & Power Charging
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Label("Power & Battery", systemImage: "bolt.batteryblock.fill")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.secondary)
                            Spacer()
                        }

                        if manager.batteryInfo.isInstalled || manager.batteryInfo.isExternalConnected {
                            BatteryPowerCardView(manager: manager, isCompact: true)
                        } else {
                            Text("No internal battery detected (Desktop Mac)")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .padding(12)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }
                .frame(width: 280)
            }
            .frame(height: 430)

            Divider()

            // MARK: - Footer Action Bar
            Button(action: onOpenDashboard) {
                HStack {
                    Text("Open Full Dashboard")
                        .font(.system(size: 12, weight: .medium))
                    Spacer()
                    Image(systemName: "arrow.up.forward.app")
                        .font(.system(size: 11))
                }
                .foregroundColor(.accentColor)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .frame(width: 590)
        .background(
            ZStack {
                VisualEffectView(material: .popover, blendingMode: .behindWindow)
                LinearGradient(
                    colors: [Color.white.opacity(0.1), Color.clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.25), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }

    private func batteryIcon(for level: Int) -> String {
        switch level {
        case 75...100: return "battery.100"
        case 50..<75: return "battery.75"
        case 25..<50: return "battery.50"
        default: return "battery.25"
        }
    }

    private func batteryColor(for level: Int) -> Color {
        if level > 40 { return .green }
        if level > 20 { return .orange }
        return .red
    }
}

public struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    public init(material: NSVisualEffectView.Material = .popover, blendingMode: NSVisualEffectView.BlendingMode = .behindWindow) {
        self.material = material
        self.blendingMode = blendingMode
    }

    public func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    public func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
