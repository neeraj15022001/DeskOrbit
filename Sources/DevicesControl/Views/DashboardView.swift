import SwiftUI

public struct DashboardView: View {
    @ObservedObject var manager: DeviceManager

    public init(manager: DeviceManager = .shared) {
        self.manager = manager
    }

    private let columns = [
        GridItem(.adaptive(minimum: 320, maximum: 500), spacing: 16)
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
            .navigationSplitViewColumnWidth(min: 180, ideal: 210, max: 250)
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

                    // Smart Bulb Actions
                    if manager.activeCategory == .all || manager.activeCategory == .lights {
                        Button(action: { manager.discoverSmartLights() }) {
                            HStack(spacing: 4) {
                                if manager.isDiscoveringLights {
                                    ProgressView().controlSize(.mini)
                                } else {
                                    Image(systemName: "lightbulb.and.waveform.fill")
                                }
                                Text("Scan WiZ")
                            }
                        }
                        .controlSize(.regular)

                        Button(action: {
                            manager.isShowingAddBulbSheet.toggle()
                        }) {
                            Label("Add IP", systemImage: "plus")
                        }
                        .controlSize(.regular)
                    }

                    Button(action: { manager.refreshAll() }) {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .controlSize(.regular)
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 12)

                // Inline Add Bulb IP Bar
                if manager.isShowingAddBulbSheet {
                    HStack(spacing: 12) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(.yellow)

                        TextField("Bulb IP Address (e.g. 192.168.1.50)", text: $manager.newBulbIPInput)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 240)

                        TextField("Name (e.g. Desk Lamp A60)", text: $manager.newBulbNameInput)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 200)

                        Button("Connect") {
                            guard !manager.newBulbIPInput.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                            manager.addSmartLightByIP(
                                ip: manager.newBulbIPInput,
                                customName: manager.newBulbNameInput.isEmpty ? nil : manager.newBulbNameInput
                            )
                            manager.newBulbIPInput = ""
                            manager.newBulbNameInput = ""
                            manager.isShowingAddBulbSheet = false
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)

                        Button("Cancel") {
                            manager.isShowingAddBulbSheet = false
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 8)
                    .background(Color.accentColor.opacity(0.08))
                }

                // WiZ Security & Integration Guidance Banner
                if manager.activeCategory == .lights || (manager.activeCategory == .all && !manager.smartLights.isEmpty) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 10) {
                            Image(systemName: "shield.lefthalf.filled")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.orange)

                            Text("WiZ App Requirement for Actions:")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.primary)

                            Text("In WiZ App > Settings ⚙️ > Security > Turn 'Allow local communication' ON (set to 'All controls'). If set to 'Only verified controls', the bulb detects but rejects commands.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)

                            Spacer()
                        }

                        // SmartThings Cloud Integration Toggle
                        HStack(spacing: 8) {
                            Image(systemName: "cloud.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.cyan)

                            Text("SmartThings Cloud Fallback:")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.secondary)

                            SecureField("Paste SmartThings PAT Token", text: Binding(
                                get: { manager.wizLightService.smartThingsToken },
                                set: { manager.wizLightService.setSmartThingsToken($0) }
                            ))
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 240)
                            .controlSize(.mini)

                            if let url = URL(string: "https://account.smartthings.com/tokens") {
                                Link("Get Token ↗", destination: url)
                                    .font(.system(size: 10))
                            }

                            Spacer()
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 8)
                    .background(Color.orange.opacity(0.06))
                }

                Divider()

                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        if manager.activeCategory == .all || manager.activeCategory == .battery {
                            batterySection
                        }

                        if manager.activeCategory == .all || manager.activeCategory == .lights {
                            lightsSection
                        }

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
        .frame(minWidth: 840, minHeight: 560)
    }

    // MARK: - Sections

    @ViewBuilder
    private var batterySection: some View {
        if manager.batteryInfo.isInstalled || manager.batteryInfo.isExternalConnected {
            BatteryPowerCardView(manager: manager, isCompact: false)
        }
    }

    @ViewBuilder
    private var lightsSection: some View {
        if manager.smartLights.isEmpty {
            if manager.activeCategory == .lights {
                VStack(spacing: 12) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.yellow.opacity(0.8))

                    Text("No WiZ Smart Bulbs Found")
                        .font(.system(size: 16, weight: .bold))

                    Text("DeskOrbit communicates directly with WiZ-connected Philips A60 bulbs over your local Wi-Fi via UDP port 38899 without cloud latency.\n\nMake sure your Mac and Philips WiZ bulb are on the same Wi-Fi network, then click 'Scan WiZ' or enter its IP address manually.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)

                    HStack(spacing: 12) {
                        Button("Scan Local Wi-Fi") {
                            manager.discoverSmartLights()
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Add Bulb by IP") {
                            manager.isShowingAddBulbSheet = true
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.top, 4)
                }
                .padding(32)
                .frame(maxWidth: .infinity)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(14)
            }
        } else {
            ForEach(manager.smartLights) { light in
                WizLightCardView(manager: manager, light: light, isCompact: false)
            }
        }
    }

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
                    .controlSize(.regular)
                }
            }
        }
    }

    @ViewBuilder
    private var audioSection: some View {
        ForEach(manager.audioDevices.filter { $0.isOutput }) { device in
            DeviceCardView(
                title: device.name,
                subtitle: "\(device.transportType) • \(device.isOutput ? "Output" : "Input")",
                iconName: device.isOutput ? "speaker.wave.2" : "mic",
                iconColor: .blue,
                badgeText: device.isDefaultOutput ? "Default Output" : nil,
                badgeColor: .blue
            ) {
                VStack(spacing: 10) {
                    HStack {
                        Button(action: { manager.toggleAudioMute(device: device) }) {
                            Image(systemName: device.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                .foregroundColor(device.isMuted ? .red : .accentColor)
                        }
                        .buttonStyle(.plain)

                        Slider(value: Binding(
                            get: { Double(device.volume) },
                            set: { manager.setAudioVolume(deviceID: device.id, volume: Float($0)) }
                        ), in: 0.0...1.0)
                        .disabled(device.isMuted)

                        Text("\(Int(device.volume * 100))%")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .frame(width: 36, alignment: .trailing)
                    }

                    if !device.isDefaultOutput {
                        Button(action: { manager.setDefaultAudioOutput(device: device) }) {
                            Text("Set as Default Output")
                                .frame(maxWidth: .infinity)
                        }
                        .controlSize(.small)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var bluetoothSection: some View {
        ForEach(manager.bluetoothDevices) { device in
            DeviceCardView(
                title: device.name,
                subtitle: device.deviceType,
                iconName: "headphones",
                iconColor: .cyan,
                badgeText: device.isConnected ? "Connected" : "Paired",
                badgeColor: device.isConnected ? .green : .secondary
            ) {
                HStack {
                    if let battery = device.batteryPercent {
                        HStack(spacing: 4) {
                            Image(systemName: "battery.100")
                                .foregroundColor(.green)
                            Text("\(battery)%")
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                        }
                    } else {
                        Text("Battery N/A")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button(action: { manager.toggleBluetooth(device: device) }) {
                        Text(device.isConnected ? "Disconnect" : "Connect")
                    }
                    .controlSize(.small)
                }
            }
        }
    }

    @ViewBuilder
    private var storageSection: some View {
        ForEach(manager.storageDevices) { storage in
            DeviceCardView(
                title: storage.name,
                subtitle: "\(storage.formattedFree) free of \(storage.formattedTotal)",
                iconName: "externaldrive.fill",
                iconColor: .orange,
                badgeText: storage.isEjectable ? "Removable" : nil,
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
            let batt = (manager.batteryInfo.isInstalled || manager.batteryInfo.isExternalConnected) ? 1 : 0
            return batt + manager.smartLights.count + manager.displays.count + manager.audioDevices.count + manager.bluetoothDevices.count + manager.storageDevices.count
        case .battery:
            return (manager.batteryInfo.isInstalled || manager.batteryInfo.isExternalConnected) ? 1 : 0
        case .lights:
            return manager.smartLights.count
        case .display: return manager.displays.count
        case .audio: return manager.audioDevices.count
        case .bluetooth: return manager.bluetoothDevices.count
        case .storage: return manager.storageDevices.count
        }
    }

    private func totalActiveDevicesText() -> String {
        let lights = manager.smartLights.count
        let displays = manager.displays.count
        let audio = manager.audioDevices.count
        let btConnected = manager.bluetoothDevices.filter { $0.isConnected }.count
        let storage = manager.storageDevices.count
        let batt = manager.batteryInfo.isInstalled ? "\(manager.batteryInfo.currentPercentage)% Battery" : "AC Connected"
        return "\(batt), \(lights) light\(lights == 1 ? "" : "s"), \(displays) display\(displays == 1 ? "" : "s"), \(audio) audio, \(btConnected) bluetooth active, \(storage) storage"
    }
}
