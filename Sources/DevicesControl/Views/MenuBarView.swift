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
                Image(systemName: "macmini")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.accentColor)
                Text("DeskOrbit")
                    .font(.system(size: 13, weight: .bold))

                Spacer()

                Button(action: { manager.refreshAll() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .help("Refresh Devices")

                Button(action: onOpenDashboard) {
                    Image(systemName: "rectangle.inset.filled.and.cursorarrow")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .help("Open Full Dashboard")

                Button(action: onQuit) {
                    Image(systemName: "power")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Quit Application")
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()

            // Status message banner if any
            if let status = manager.statusMessage {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 11))
                    Text(status)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Color.blue.opacity(0.1))
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
                                Text("No displays detected")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            } else {
                                ForEach(manager.displays) { display in
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text(display.name)
                                                .font(.system(size: 11, weight: .medium))
                                                .lineLimit(1)
                                            if display.isMain {
                                                Text("Main")
                                                    .font(.system(size: 8, weight: .bold))
                                                    .padding(.horizontal, 4)
                                                    .padding(.vertical, 1)
                                                    .background(Color.accentColor.opacity(0.15))
                                                    .foregroundColor(.accentColor)
                                                    .clipShape(Capsule())
                                            }
                                            Spacer()
                                            Text("\(Int(display.brightness * 100))%")
                                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                        }

                                        Slider(value: Binding(
                                            get: { Double(display.brightness) },
                                            set: { manager.setDisplayBrightness(displayID: display.id, brightness: Float($0)) }
                                        ), in: 0.0...1.0)
                                        .controlSize(.small)
                                    }
                                    .padding(8)
                                    .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
                                    .cornerRadius(8)
                                }
                            }
                        }

                        // 2. Audio Control Section
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
                                VStack(spacing: 6) {
                                    HStack {
                                        Button(action: { manager.toggleAudioMute(device: defaultDevice) }) {
                                            Image(systemName: defaultDevice.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                                .font(.system(size: 12))
                                                .foregroundColor(defaultDevice.isMuted ? .red : .accentColor)
                                        }
                                        .buttonStyle(.plain)

                                        Slider(value: Binding(
                                            get: { Double(defaultDevice.volume) },
                                            set: { manager.setAudioVolume(deviceID: defaultDevice.id, volume: Float($0)) }
                                        ), in: 0.0...1.0)
                                        .controlSize(.small)
                                        .disabled(defaultDevice.isMuted)

                                        Text("\(Int(defaultDevice.volume * 100))%")
                                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                                            .frame(width: 32, alignment: .trailing)
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
                                .padding(8)
                                .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
                                .cornerRadius(8)
                            } else {
                                Text("No audio output device found")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }

                        // 3. Bluetooth Devices
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
                                            .font(.system(size: 11))
                                            .foregroundColor(.accentColor)
                                        Text(device.name)
                                            .font(.system(size: 11, weight: .medium))
                                            .lineLimit(1)
                                        Spacer()
                                        if let battery = device.batteryPercent {
                                            HStack(spacing: 3) {
                                                Image(systemName: batteryIcon(for: battery))
                                                    .font(.system(size: 10))
                                                    .foregroundColor(batteryColor(for: battery))
                                                Text("\(battery)%")
                                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                            }
                                        }
                                        Button(action: { manager.toggleBluetooth(device: device) }) {
                                            Text("Disconnect")
                                                .font(.system(size: 9))
                                        }
                                        .controlSize(.mini)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
                                    .cornerRadius(6)
                                }
                            }
                        }

                        // 4. External Storage
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
                                        Image(systemName: "externaldrive.badge.icloud")
                                            .font(.system(size: 12))
                                            .foregroundColor(.orange)
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(storage.name)
                                                .font(.system(size: 11, weight: .medium))
                                                .lineLimit(1)
                                            Text("\(storage.formattedFree) free of \(storage.formattedTotal)")
                                                .font(.system(size: 9))
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        Button(action: { manager.ejectStorage(device: storage) }) {
                                            Image(systemName: "eject.fill")
                                                .font(.system(size: 10))
                                        }
                                        .buttonStyle(.plain)
                                        .help("Eject \(storage.name)")
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
                                    .cornerRadius(6)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }
                .frame(width: 310)

                // Vertical Divider between left and right
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
            .frame(height: 420)

            Divider()

            // MARK: - Footer action
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
                .padding(.vertical, 9)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .frame(width: 590)
        .background(VisualEffectView(material: .popover, blendingMode: .behindWindow))
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
