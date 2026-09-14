import SwiftUI

public struct DashboardView: View {
    @ObservedObject var manager: DeviceManager

    public init(manager: DeviceManager = .shared) {
        self.manager = manager
    }

    private let columns = [
        GridItem(.adaptive(minimum: 280, maximum: 400), spacing: 16)
    ]

    public var body: some View {
        NavigationSplitView {
            List(DeviceCategory.allCases, id: \.self, selection: Binding(
                get: { manager.activeCategory },
                set: { manager.activeCategory = $0 ?? .all }
            )) { category in
                NavigationLink(value: category) {
                    HStack {
                        Label(category.rawValue, systemImage: category.systemImage)
                        Spacer()
                        Text("\(deviceCount(for: category))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
        } detail: {
            VStack(spacing: 0) {
                // Top Header / Action Bar
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(manager.activeCategory.rawValue)
                            .font(.system(size: 22, weight: .bold))
                        Text("\(totalActiveDevicesText())")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if let status = manager.statusMessage {
                        Text(status)
                            .font(.system(size: 12))
                            .foregroundColor(.blue)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                    }

                    Button(action: { manager.refreshAll() }) {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .controlSize(.regular)
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 12)

                Divider()

                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        if manager.activeCategory == .all || manager.activeCategory == .display {
                            displaysSection
                        }

                        if manager.activeCategory == .all || manager.activeCategory == .audio {
                            audioSection
                        }

                        if manager.activeCategory == .all || manager.activeCategory == .bluetooth {
                            bluetoothSection
                        }

                        if manager.activeCategory == .all || manager.activeCategory == .storage {
                            storageSection
                        }
                    }
                    .padding(24)
                }
            }
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(minWidth: 820, minHeight: 540)
    }

    // MARK: - Sections
    @ViewBuilder
    private var displaysSection: some View {
        ForEach(manager.displays) { display in
            DeviceCardView(
                title: display.name,
                subtitle: "\(display.resolution) • \(display.isBuiltIn ? "Internal" : "External")",
                iconName: display.isBuiltIn ? "laptopcomputer" : "display",
                iconColor: .purple,
                badgeText: display.isMain ? "Main Display" : nil,
                badgeColor: .purple
            ) {
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "sun.max.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Text("Brightness")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int(display.brightness * 100))%")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    }

                    Slider(value: Binding(
                        get: { Double(display.brightness) },
                        set: { manager.setDisplayBrightness(displayID: display.id, brightness: Float($0)) }
                    ), in: 0.0...1.0)
                }
            }
        }
    }

    @ViewBuilder
    private var audioSection: some View {
        ForEach(manager.audioDevices) { audio in
            DeviceCardView(
                title: audio.name,
                subtitle: "\(audio.transportType) • \(audio.isOutput ? "Output" : "Input")",
                iconName: audio.isOutput ? "speaker.wave.2.fill" : "mic.fill",
                iconColor: .blue,
                badgeText: audio.isDefaultOutput ? "Default Output" : (audio.isDefaultInput ? "Default Input" : nil),
                badgeColor: .blue
            ) {
                VStack(spacing: 10) {
                    if audio.isOutput {
                        HStack {
                            Button(action: { manager.toggleAudioMute(device: audio) }) {
                                Image(systemName: audio.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                    .foregroundColor(audio.isMuted ? .red : .primary)
                            }
                            .buttonStyle(.plain)

                            Slider(value: Binding(
                                get: { Double(audio.volume) },
                                set: { manager.setAudioVolume(deviceID: audio.id, volume: Float($0)) }
                            ), in: 0.0...1.0)
                            .disabled(audio.isMuted)

                            Text("\(Int(audio.volume * 100))%")
                                .font(.system(size: 11, design: .monospaced))
                                .frame(width: 35, alignment: .trailing)
                        }
                    }

                    HStack {
                        if !audio.isDefaultOutput && audio.isOutput {
                            Button("Set as Default") {
                                manager.setDefaultAudioOutput(device: audio)
                            }
                            .controlSize(.small)
                        }
                        Spacer()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var bluetoothSection: some View {
        ForEach(manager.bluetoothDevices) { bt in
            DeviceCardView(
                title: bt.name,
                subtitle: bt.deviceType,
                iconName: bt.isConnected ? "dot.radiowaves.left.and.right" : "wave.3.left",
                iconColor: bt.isConnected ? .green : .gray,
                badgeText: bt.isConnected ? "Connected" : "Paired",
                badgeColor: bt.isConnected ? .green : .secondary
            ) {
                VStack(spacing: 8) {
                    if let battery = bt.batteryPercent {
                        HStack {
                            Image(systemName: "battery.100")
                                .foregroundColor(.green)
                            Text("Battery Level")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(battery)%")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        }
                    }

                    HStack {
                        Button(action: { manager.toggleBluetooth(device: bt) }) {
                            Text(bt.isConnected ? "Disconnect" : "Connect")
                        }
                        .controlSize(.small)
                        Spacer()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var storageSection: some View {
        ForEach(manager.storageDevices) { storage in
            DeviceCardView(
                title: storage.name,
                subtitle: "\(storage.formattedFree) available of \(storage.formattedTotal)",
                iconName: "externaldrive.fill",
                iconColor: .orange,
                badgeText: storage.isRemovable ? "Removable" : nil,
                badgeColor: .orange
            ) {
                VStack(spacing: 8) {
                    ProgressView(value: storage.usedPercentage)
                        .progressViewStyle(.linear)

                    HStack {
                        Text("\(Int(storage.usedPercentage * 100))% used")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Spacer()
                        if storage.isEjectable {
                            Button(action: { manager.ejectStorage(device: storage) }) {
                                Label("Eject", systemImage: "eject.fill")
                            }
                            .controlSize(.small)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers
    private func deviceCount(for category: DeviceCategory) -> Int {
        switch category {
        case .all:
            return manager.displays.count + manager.audioDevices.count + manager.bluetoothDevices.count + manager.storageDevices.count
        case .display: return manager.displays.count
        case .audio: return manager.audioDevices.count
        case .bluetooth: return manager.bluetoothDevices.count
        case .storage: return manager.storageDevices.count
        }
    }

    private func totalActiveDevicesText() -> String {
        let displays = manager.displays.count
        let audio = manager.audioDevices.count
        let btConnected = manager.bluetoothDevices.filter { $0.isConnected }.count
        let storage = manager.storageDevices.count
        return "\(displays) display\(displays == 1 ? "" : "s"), \(audio) audio, \(btConnected) bluetooth active, \(storage) storage"
    }
}
