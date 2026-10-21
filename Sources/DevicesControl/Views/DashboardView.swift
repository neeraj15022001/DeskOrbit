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

                            Button(action: { manager.syncSmartThings() }) {
                                HStack(spacing: 4) {
                                    if manager.wizLightService.isSyncingCloud {
                                        ProgressView().controlSize(.mini)
                                    } else {
                                        Image(systemName: "cloud.fill")
                                    }
                                    Text("Sync SmartThings")
                                }
                            }
                            .controlSize(.regular)
                            .help("Sync devices linked to your Samsung SmartThings account")
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

                // Unified Dual Integration Banner (Direct WiZ LAN + Samsung SmartThings Cloud)
                if manager.activeCategory == .lights || (manager.activeCategory == .all && !manager.smartLights.isEmpty) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.accentColor.opacity(0.15))
                                .frame(width: 32, height: 32)
                            Image(systemName: "lightbulb.2.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.accentColor)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text("Dual WiZ Integration Supported")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.primary)

                                Text("Direct LAN (UDP)")
                                    .font(.system(size: 8, weight: .bold))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(Color.green.opacity(0.18))
                                    .foregroundColor(.green)
                                    .cornerRadius(4)

                                Text("SmartThings Cloud")
                                    .font(.system(size: 8, weight: .bold))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(Color.cyan.opacity(0.18))
                                    .foregroundColor(.cyan)
                                    .cornerRadius(4)

                                if let hid = manager.wizLightService.homeId {
                                    HStack(spacing: 3) {
                                        Image(systemName: "lock.shield.fill")
                                        Text("v2 Authenticated (\(hid))")
                                    }
                                    .font(.system(size: 8, weight: .bold))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(Color.purple.opacity(0.18))
                                    .foregroundColor(.purple)
                                    .cornerRadius(4)
                                }
                            }

                            Text("DeskOrbit communicates directly over local Wi-Fi (UDP 38899) with cryptographic HMAC-SHA256 signing and Samsung SmartThings Cloud.")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        SecureField("SmartThings PAT Token", text: Binding(
                            get: { manager.wizLightService.smartThingsToken },
                            set: { manager.wizLightService.setSmartThingsToken($0) }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 200)
                        .controlSize(.small)

                        if let url = URL(string: "https://account.smartthings.com/tokens") {
                            Link("Get Token ↗", destination: url)
                                .font(.system(size: 11))
                        }

                        Button(action: {
                            isShowingIntegrationGuide = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "book.fill")
                                Text("Setup Guide")
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
            if manager.activeCategory == .lights {
                VStack(spacing: 16) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.yellow.opacity(0.85))

                    Text("No WiZ Smart Bulbs Found")
                        .font(.system(size: 16, weight: .bold))

                    Text("DeskOrbit supports two ways to connect your WiZ smart bulbs:\n\n1. **Direct Wi-Fi (LAN):** Fast local communication over UDP 38899 with HMAC-SHA256 authentication.\n2. **Samsung SmartThings Cloud:** Connected via the WiZ app's third-party integration.")
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
                    Text("WiZ Third-Party Integration Guide")
                        .font(.system(size: 15, weight: .bold))
                    Text("How to connect your bulbs via SmartThings and Direct Wi-Fi LAN")
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
                    // Method 1
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "cloud.fill")
                                .foregroundColor(.cyan)
                            Text("Method 1: Samsung SmartThings Cloud Integration")
                                .font(.system(size: 12, weight: .bold))
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("1. Open the **WiZ App** on your phone → Tap **Settings** (gear) → **Integrations**.")
                            Text("2. Tap **SmartThings** and toggle it on. A 5-minute pairing code will appear.")
                            Text("3. Open the **SmartThings App** → Tap **+ (Add Device)** → Search **WiZ** → Select your bulb type and paste the pairing code.")
                            Text("4. In DeskOrbit, paste your **SmartThings Personal Access Token** in the header banner and click **Sync SmartThings**.")
                        }
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .padding(10)
                        .background(Color.cyan.opacity(0.08))
                        .cornerRadius(8)
                    }

                    // Method 2
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "wifi")
                                .foregroundColor(.green)
                            Text("Method 2: Direct WiZ Local Integration (Signed LAN UDP)")
                                .font(.system(size: 12, weight: .bold))
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("1. In the **WiZ App**, go to **Settings** → **Integrations** → **Local Integrations**.")
                            Text("2. Tap the export button to generate the 15-minute download link, and open it to save the `.json` file.")
                            Text("3. In DeskOrbit, click **'Import WiZ JSON'** (or Auto-Import from Downloads).")
                            Text("4. DeskOrbit extracts your **Home Security Key** (`udp_signing_key`) and Home ID, automatically finds your bulb's IP address, and signs all local UDP packets via HMAC-SHA256 for zero-lag local control!")
                        }
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .padding(10)
                        .background(Color.green.opacity(0.08))
                        .cornerRadius(8)
                    }

                    // Hybrid
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .foregroundColor(.purple)
                            Text("Hybrid Dual-Route (Best of Both Worlds)")
                                .font(.system(size: 12, weight: .bold))
                        }

                        Text("When a bulb is both on your local Wi-Fi and linked to SmartThings, DeskOrbit automatically operates in **Hybrid mode**:\n• Commands are sent locally over Wi-Fi with cryptographic HMAC-SHA256 signing for instantaneous, flicker-free dimming and color tuning.\n• State updates are synchronized with Samsung SmartThings Cloud so your mobile app and smart home automations stay perfectly in sync!")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .padding(10)
                            .background(Color.purple.opacity(0.08))
                            .cornerRadius(8)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(20)
        .frame(width: 520, height: 470)
    }
}
