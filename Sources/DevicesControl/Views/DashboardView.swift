import SwiftUI

public struct DashboardView: View {
    @ObservedObject var manager: DeviceManager
    @State private var isShowingIntegrationGuide: Bool = false

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
                HStack(spacing: 10) {
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
                            .foregroundColor(.accentColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.accentColor.opacity(0.1))
                            .cornerRadius(8)
                    }

                    // Smart Bulb Actions
                    if manager.activeCategory == .all || manager.activeCategory == .lights {
                        HStack(spacing: 8) {
                            Button(action: { manager.scanLocalWiZLights() }) {
                                HStack(spacing: 4) {
                                    if manager.wizLightService.isScanningLocal {
                                        ProgressView().controlSize(.mini)
                                    } else {
                                        Image(systemName: "wifi")
                                    }
                                    Text("Scan Local Wi-Fi")
                                }
                            }
                            .controlSize(.regular)
                            .help("Scan local network for WiZ bulbs on UDP port 38899")

                            Button(action: { manager.isShowingAddBulbSheet = true }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus.circle")
                                    Text("Add by IP")
                                }
                            }
                            .controlSize(.regular)
                            .help("Add a WiZ bulb directly by its local IP address")

                            Button(action: { manager.isShowingImportJsonSheet = true }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "lock.doc.fill")
                                    Text("Import WiZ JSON")
                                }
                            }
                            .controlSize(.regular)
                            .help("Import WiZ v2 Home config JSON export (unlocks verified UDP controls)")
                        }
                    }

                    Button(action: { manager.refreshAll() }) {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .controlSize(.regular)
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 12)

                // WiZ v2 Local Control Hub Banner
                if manager.activeCategory == .lights || (manager.activeCategory == .all && !manager.smartLights.isEmpty) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.accentColor.opacity(0.15))
                                .frame(width: 32, height: 32)
                            Image(systemName: "lightbulb.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.accentColor)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text("WiZ Local Control Hub")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.primary)

                                Text("Direct LAN (UDP 38899)")
                                    .font(.system(size: 8, weight: .bold))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(Color.green.opacity(0.18))
                                    .foregroundColor(.green)
                                    .cornerRadius(4)

                                if let hid = manager.wizLightService.homeId {
                                    HStack(spacing: 3) {
                                        Image(systemName: "lock.shield.fill")
                                        Text("v2 Verified (Home #\(hid))")
                                    }
                                    .font(.system(size: 8, weight: .bold))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(Color.purple.opacity(0.18))
                                    .foregroundColor(.purple)
                                    .cornerRadius(4)
                                } else {
                                    Text("Open UDP Mode")
                                        .font(.system(size: 8, weight: .bold))
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 1)
                                        .background(Color.secondary.opacity(0.18))
                                        .foregroundColor(.secondary)
                                        .cornerRadius(4)
                                }
                            }

                            Text("DeskOrbit controls WiZ bulbs directly over your local Wi-Fi with cryptographic HMAC-SHA256 signing and zero cloud latency.")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Button(action: {
                            manager.wizLightService.autoImportConfigFromDownloads()
                            manager.showStatus("Checked ~/Downloads for WiZ config!")
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.down.circle")
                                Text("Auto-Import JSON")
                            }
                        }
                        .controlSize(.small)
                        .help("Auto-detect and import exported WiZ configuration from ~/Downloads")

                        Button(action: {
                            isShowingIntegrationGuide = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "book.fill")
                                Text("Protocol Guide")
                            }
                            .font(.system(size: 10, weight: .semibold))
                        }
                        .controlSize(.small)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Color.accentColor.opacity(0.06))
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
        // MARK: - Sheets
        .sheet(isPresented: $manager.isShowingAddBulbSheet) {
            AddBulbSheetView(manager: manager)
        }
        .sheet(isPresented: $manager.isShowingImportJsonSheet) {
            ImportJsonSheetView(manager: manager)
        }
        .sheet(isPresented: $isShowingIntegrationGuide) {
            WizIntegrationGuideSheetView(isPresented: $isShowingIntegrationGuide)
        }
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
            if manager.activeCategory == .lights || manager.activeCategory == .all {
                VStack(spacing: 16) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.yellow.opacity(0.85))

                    Text("No WiZ Smart Bulbs Found")
                        .font(.system(size: 16, weight: .bold))

                    Text("DeskOrbit communicates directly over your local Wi-Fi (UDP 38899) with cryptographic HMAC-SHA256 signing for instant, zero-latency light control without any cloud dependencies.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 480)

                    HStack(spacing: 12) {
                        Button(action: { manager.scanLocalWiZLights() }) {
                            HStack(spacing: 4) {
                                Image(systemName: "wifi")
                                Text("Scan Local Wi-Fi")
                            }
                        }
                        .buttonStyle(.borderedProminent)

                        Button(action: { manager.isShowingImportJsonSheet = true }) {
                            HStack(spacing: 4) {
                                Image(systemName: "lock.doc.fill")
                                Text("Import WiZ JSON")
                            }
                        }

                        Button(action: { manager.isShowingAddBulbSheet = true }) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus.circle")
                                Text("Add by IP")
                            }
                        }

                        Button(action: { isShowingIntegrationGuide = true }) {
                            HStack(spacing: 4) {
                                Image(systemName: "book")
                                Text("Setup Guide")
                            }
                        }
                    }
                    .padding(.top, 6)
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
        ForEach(manager.storageDevices) { device in
            DeviceCardView(
                title: device.name,
                subtitle: device.isRemovable ? "Removable Volume" : "External Volume",
                iconName: "externaldrive",
                iconColor: .orange,
                badgeText: device.isEjectable ? "Ejectable" : nil,
                badgeColor: .orange
            ) {
                VStack(spacing: 8) {
                    HStack {
                        Text("\(device.formattedFree) free of \(device.formattedTotal)")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int(device.usedPercentage * 100))% used")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                    }

                    ProgressView(value: device.usedPercentage)
                        .tint(device.usedPercentage > 0.9 ? .red : .accentColor)

                    HStack {
                        Spacer()
                        if device.isEjectable {
                            Button(action: { manager.ejectStorage(device: device) }) {
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

// MARK: - Add Bulb Modal Sheet
private struct AddBulbSheetView: View {
    @ObservedObject var manager: DeviceManager
    @State private var isTesting: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: "wifi")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.accentColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Add WiZ Bulb by IP Address")
                        .font(.system(size: 15, weight: .bold))
                    Text("Direct Wi-Fi Local Integration (UDP 38899)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button("Cancel") {
                    manager.isShowingAddBulbSheet = false
                }
                .controlSize(.small)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Bulb Local IP Address:")
                    .font(.system(size: 11, weight: .semibold))

                TextField("e.g. 192.168.1.6", text: $manager.newBulbIPInput)
                    .textFieldStyle(.roundedBorder)

                Text("Custom Name (Optional):")
                    .font(.system(size: 11, weight: .semibold))

                TextField("e.g. Desk Lamp", text: $manager.newBulbNameInput)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.secondary)
                    Text("Setup Note:")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                }
                Text("If your WiZ bulb has 'Only verified controls' enabled, make sure you have imported your WiZ v2 JSON export file.")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(8)
            .background(Color.primary.opacity(0.04))
            .cornerRadius(8)

            HStack {
                Button("Auto-Scan Subnet") {
                    manager.scanLocalWiZLights()
                }
                .controlSize(.regular)

                Spacer()

                Button(action: {
                    isTesting = true
                    manager.addDirectBulbByIP(ip: manager.newBulbIPInput, customName: manager.newBulbNameInput.isEmpty ? nil : manager.newBulbNameInput) { _ in
                        isTesting = false
                    }
                }) {
                    HStack(spacing: 4) {
                        if isTesting {
                            ProgressView().controlSize(.mini)
                        } else {
                            Image(systemName: "plus")
                        }
                        Text("Connect & Add")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .disabled(manager.newBulbIPInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isTesting)
            }
        }
        .padding(20)
        .frame(width: 440)
    }
}

// MARK: - Import JSON Config Sheet
private struct ImportJsonSheetView: View {
    @ObservedObject var manager: DeviceManager

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                ZStack {
                    Circle()
                        .fill(Color.purple.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: "lock.doc.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.purple)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Import WiZ v2 Home Config (.json)")
                        .font(.system(size: 15, weight: .bold))
                    Text("Authenticates local UDP commands via HMAC-SHA256 signing")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button("Close") {
                    manager.isShowingImportJsonSheet = false
                }
                .controlSize(.small)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Paste your exported WiZ Home JSON below:")
                    .font(.system(size: 11, weight: .semibold))

                TextEditor(text: $manager.jsonConfigTextInput)
                    .font(.system(size: 10, design: .monospaced))
                    .frame(height: 130)
                    .padding(4)
                    .background(Color(NSColor.controlBackgroundColor))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.1)))

                HStack {
                    Button(action: {
                        manager.wizLightService.autoImportConfigFromDownloads()
                        manager.showStatus("Checked ~/Downloads and loaded config!")
                        manager.isShowingImportJsonSheet = false
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down.circle")
                            Text("Auto-Import from ~/Downloads")
                        }
                    }
                    .controlSize(.regular)

                    Spacer()

                    Button("Import JSON") {
                        manager.importWizJsonConfig(jsonString: manager.jsonConfigTextInput)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .disabled(manager.jsonConfigTextInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("How to get this JSON file:")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                Text("1. In the WiZ v2 app, tap Settings (gear) → Integrations → Local Integrations.\n2. Tap the export button to generate the 15-minute download link.\n3. Open the link in a browser to save the .json file (e.g. into Downloads).\n4. Click 'Auto-Import from ~/Downloads' above, and DeskOrbit will instantly load your bulbs!")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(8)
            .background(Color.primary.opacity(0.04))
            .cornerRadius(8)
        }
        .padding(20)
        .frame(width: 490)
    }
}

// MARK: - Integration Guide Modal Sheet
private struct WizIntegrationGuideSheetView: View {
    @Binding var isPresented: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: "book.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.accentColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("WiZ v2 Local Integration Guide")
                        .font(.system(size: 15, weight: .bold))
                    Text("Direct UDP Local Network Control (Port 38899)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button("Done") {
                    isPresented = false
                }
                .controlSize(.small)
            }

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Step 1: Getting JSON
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "key.fill")
                                .foregroundColor(.purple)
                            Text("1. Exporting WiZ v2 Local Integration Config")
                                .font(.system(size: 12, weight: .bold))
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("1. Open the **WiZ v2 App** on your phone → Tap **Settings** (gear icon) → **Integrations**.")
                            Text("2. Select **Local Integrations**.")
                            Text("3. Generate the export download link. Open it in a web browser to download the configuration `.json` file.")
                            Text("4. In DeskOrbit, click **'Auto-Import JSON'** (or paste the JSON text in Import WiZ JSON).")
                        }
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .padding(10)
                        .background(Color.purple.opacity(0.08))
                        .cornerRadius(8)
                    }

                    // Does it expire?
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "clock.badge.checkmark.fill")
                                .foregroundColor(.green)
                            Text("2. Does the WiZ v2 Integration Expire?")
                                .font(.system(size: 12, weight: .bold))
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("• **The 15-Minute Link:** The download URL generated by the WiZ cloud expires after 15 minutes for safety during file transfer.")
                            Text("• **The Keys inside the file:** **NEVER EXPIRE**. The `udp_signing_key` and `home_id` inside your JSON file are burned into your bulb's local storage and remain valid indefinitely.")
                            Text("• They will only change if you physically factory-reset your bulbs or create a completely new home in the WiZ app.")
                        }
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .padding(10)
                        .background(Color.green.opacity(0.08))
                        .cornerRadius(8)
                    }

                    // Security Options
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "shield.lefthalf.filled")
                                .foregroundColor(.blue)
                            Text("3. WiZ Security Mode Options")
                                .font(.system(size: 12, weight: .bold))
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("In the WiZ App under **Settings → Security → Local network communication**:")
                            Text("• **'Only verified controls' (Default/Recommended):** Bulbs reject unsigned UDP packets. DeskOrbit automatically computes HMAC-SHA256 signatures for every command using your imported key.")
                            Text("• **'All controls':** Bulbs accept unauthenticated UDP packets from any LAN device. DeskOrbit will work with or without a key in this mode.")
                        }
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .padding(10)
                        .background(Color.blue.opacity(0.08))
                        .cornerRadius(8)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(20)
        .frame(width: 520, height: 490)
    }
}
