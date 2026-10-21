import SwiftUI

public struct DashboardView: View {
    @ObservedObject var manager: DeviceManager
    @State private var isShowingIntegrationGuide: Bool = false

    public init(manager: DeviceManager = .shared) {
        self.manager = manager
    }

    private let columns = [
        GridItem(.adaptive(minimum: 340, maximum: 500), spacing: 16)
    ]

    public var body: some View {
        NavigationSplitView {
            List(DeviceCategory.allCases, id: \.self, selection: Binding(
                get: { manager.activeCategory },
                set: { manager.activeCategory = $0 ?? .all }
            )) { category in
                NavigationLink(value: category) {
                    HStack(spacing: 8) {
                        Image(systemName: category.systemImage)
                            .font(.system(size: 14))
                            .foregroundColor(.accentColor)
                            .frame(width: 20)

                        Text(category.rawValue)
                            .font(.system(size: 13, weight: .medium))

                        Spacer()

                        let count = deviceCount(for: category)
                        if count > 0 {
                            Text("\(count)")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Color.primary.opacity(0.06))
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 260)
        } detail: {
            VStack(spacing: 0) {
                // MARK: - Top Header / Action Toolbar
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(manager.activeCategory.rawValue)
                            .font(.system(size: 22, weight: .bold))

                        Text(totalActiveDevicesText())
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if let status = manager.statusMessage {
                        HStack(spacing: 5) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 11))
                            Text(status)
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.accentColor.opacity(0.1))
                        .clipShape(Capsule())
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
                                    Text("Scan Wi-Fi")
                                }
                                .font(.system(size: 12, weight: .medium))
                            }
                            .controlSize(.regular)
                            .help("Scan local network for WiZ bulbs on UDP port 38899")

                            Button(action: { manager.isShowingAddBulbSheet = true }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus")
                                    Text("Add by IP")
                                }
                                .font(.system(size: 12, weight: .medium))
                            }
                            .controlSize(.regular)
                            .help("Add a WiZ bulb directly by its local IP address")

                            Button(action: { manager.isShowingImportJsonSheet = true }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "lock.doc.fill")
                                    Text("Import JSON")
                                }
                                .font(.system(size: 12, weight: .medium))
                            }
                            .controlSize(.regular)
                            .help("Import WiZ v2 Home config JSON export (unlocks verified UDP controls)")
                        }
                    }

                    Button(action: { manager.refreshAll() }) {
                        Label("Refresh", systemImage: "arrow.clockwise")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .controlSize(.regular)
                    .help("Refresh All Connected Hardware")
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 14)

                // MARK: - WiZ Local Control Hub Status Banner
                if manager.activeCategory == .lights || (manager.activeCategory == .all && !manager.smartLights.isEmpty) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.accentColor.opacity(0.14))
                                .frame(width: 34, height: 34)
                            Image(systemName: "lightbulb.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.accentColor)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text("WiZ Local Control Hub")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.primary)

                                Text("Direct LAN (UDP 38899)")
                                    .font(.system(size: 10, weight: .semibold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 1)
                                    .background(Color.green.opacity(0.14))
                                    .foregroundColor(.green)
                                    .clipShape(Capsule())

                                if let hid = manager.wizLightService.homeId {
                                    Text("Home #\(hid)")
                                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 1)
                                        .background(Color.accentColor.opacity(0.14))
                                        .foregroundColor(.accentColor)
                                        .clipShape(Capsule())
                                }
                            }

                            Text("Direct local control over your Wi-Fi with cryptographic HMAC-SHA256 signing and sub-10ms response.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Button(action: {
                            manager.wizLightService.autoImportConfigFromDownloads()
                            manager.showStatus("Checked ~/Downloads for WiZ config!")
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.down.circle")
                                Text("Auto-Import")
                            }
                            .font(.system(size: 11, weight: .medium))
                        }
                        .controlSize(.small)
                        .help("Auto-detect and import exported WiZ configuration from ~/Downloads")

                        Button(action: {
                            isShowingIntegrationGuide = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "book.fill")
                                Text("Guide")
                            }
                            .font(.system(size: 11, weight: .medium))
                        }
                        .controlSize(.small)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.7))
                    .overlay(
                        Rectangle().frame(height: 1).foregroundColor(Color.primary.opacity(0.05)),
                        alignment: .bottom
                    )
                }

                Divider()

                // MARK: - Device Cards Grid
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
        .frame(minWidth: 860, minHeight: 580)
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
                    ZStack {
                        Circle()
                            .fill(Color.orange.opacity(0.12))
                            .frame(width: 56, height: 56)
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 26))
                            .foregroundColor(.orange)
                    }

                    Text("No WiZ Smart Bulbs Found")
                        .font(.system(size: 16, weight: .bold))

                    Text("DeskOrbit communicates directly over your local Wi-Fi (UDP 38899) with cryptographic HMAC-SHA256 signing for instant, zero-latency light control without cloud dependencies.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 460)

                    HStack(spacing: 12) {
                        Button(action: { manager.scanLocalWiZLights() }) {
                            HStack(spacing: 4) {
                                Image(systemName: "wifi")
                                Text("Scan Wi-Fi")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)

                        Button(action: { manager.isShowingImportJsonSheet = true }) {
                            HStack(spacing: 4) {
                                Image(systemName: "lock.doc.fill")
                                Text("Import JSON")
                            }
                        }
                        .controlSize(.regular)

                        Button(action: { manager.isShowingAddBulbSheet = true }) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                Text("Add by IP")
                            }
                        }
                        .controlSize(.regular)

                        Button(action: { isShowingIntegrationGuide = true }) {
                            HStack(spacing: 4) {
                                Image(systemName: "book")
                                Text("Setup Guide")
                            }
                        }
                        .controlSize(.regular)
                    }
                    .padding(.top, 4)
                }
                .padding(32)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(NSColor.controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                )
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
                subtitle: "\(display.resolution) • \(display.isBuiltIn ? "Internal Display" : "External Display")",
                iconName: display.isBuiltIn ? "laptopcomputer" : "display",
                iconColor: .accentColor,
                badgeText: display.isMain ? "Main Display" : nil,
                badgeColor: .accentColor
            ) {
                VStack(spacing: 10) {
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
            }
        }
    }

    @ViewBuilder
    private var audioSection: some View {
        ForEach(manager.audioDevices.filter { $0.isOutput }) { device in
            DeviceCardView(
                title: device.name,
                subtitle: "\(device.transportType) • Output Device",
                iconName: device.isOutput ? "speaker.wave.2.fill" : "mic.fill",
                iconColor: .accentColor,
                badgeText: device.isDefaultOutput ? "Default Output" : nil,
                badgeColor: .accentColor
            ) {
                VStack(spacing: 10) {
                    HStack(spacing: 8) {
                        Button(action: { manager.toggleAudioMute(device: device) }) {
                            Image(systemName: device.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(device.isMuted ? .red : .accentColor)
                                .frame(width: 28, height: 28)
                                .background(Color.primary.opacity(0.05))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .help(device.isMuted ? "Unmute Audio" : "Mute Audio")

                        OrbitCapsuleSlider(
                            icon: device.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                            label: "Volume",
                            value: Binding(
                                get: { device.volume },
                                set: { manager.setAudioVolume(deviceID: device.id, volume: $0) }
                            ),
                            tint: device.isMuted ? .gray : .accentColor,
                            isEnabled: !device.isMuted
                        )
                    }

                    if !device.isDefaultOutput {
                        Button(action: { manager.setDefaultAudioOutput(device: device) }) {
                            Text("Set as Default Output")
                                .font(.system(size: 11, weight: .medium))
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
                iconColor: .accentColor,
                badgeText: device.isConnected ? "Connected" : "Paired",
                badgeColor: device.isConnected ? .green : .secondary
            ) {
                HStack {
                    if let battery = device.batteryPercent {
                        HStack(spacing: 4) {
                            Image(systemName: "battery.100")
                                .foregroundColor(.green)
                            Text("\(battery)%")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        }
                    } else {
                        Text("Battery N/A")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button(action: { manager.toggleBluetooth(device: device) }) {
                        Text(device.isConnected ? "Disconnect" : "Connect")
                            .font(.system(size: 11))
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
                iconName: "externaldrive.fill",
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
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    }

                    ProgressView(value: device.usedPercentage)
                        .tint(device.usedPercentage > 0.9 ? .red : .accentColor)

                    HStack {
                        Spacer()
                        if device.isEjectable {
                            Button(action: { manager.ejectStorage(device: device) }) {
                                Label("Eject", systemImage: "eject.fill")
                                    .font(.system(size: 11, weight: .medium))
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
        return "\(batt), \(lights) light\(lights == 1 ? "" : "s"), \(displays) display\(displays == 1 ? "" : "s"), \(audio) audio, \(btConnected) bluetooth, \(storage) storage"
    }
}

// MARK: - Add Bulb Modal Sheet
private struct AddBulbSheetView: View {
    @ObservedObject var manager: DeviceManager
    @State private var isTesting: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.14))
                        .frame(width: 36, height: 36)
                    Image(systemName: "wifi")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.accentColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Add WiZ Bulb by IP")
                        .font(.system(size: 15, weight: .bold))
                    Text("Direct Local UDP Connection (Port 38899)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button("Cancel") {
                    manager.isShowingAddBulbSheet = false
                }
                .keyboardShortcut(.cancelAction)
                .controlSize(.regular)
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Text("Bulb Local IP Address:")
                    .font(.system(size: 11, weight: .semibold))

                TextField("e.g. 192.168.1.6", text: $manager.newBulbIPInput)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.regular)

                Text("Custom Name (Optional):")
                    .font(.system(size: 11, weight: .semibold))

                TextField("e.g. Desk Lamp", text: $manager.newBulbNameInput)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.regular)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text("Verification Notice:")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                }
                Text("For modern WiZ bulbs with 'Only verified controls' enabled, make sure you have imported your WiZ v2 JSON export file.")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(10)
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
                        Text("Connect Bulb")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .keyboardShortcut(.defaultAction)
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
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.14))
                        .frame(width: 36, height: 36)
                    Image(systemName: "lock.doc.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.accentColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Import WiZ v2 Home Config (.json)")
                        .font(.system(size: 15, weight: .bold))
                    Text("Unlocks cryptographic HMAC-SHA256 authenticated UDP pilot controls")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button("Done") {
                    manager.isShowingImportJsonSheet = false
                }
                .keyboardShortcut(.cancelAction)
                .controlSize(.regular)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Paste exported WiZ Home JSON content:")
                    .font(.system(size: 11, weight: .semibold))

                TextEditor(text: $manager.jsonConfigTextInput)
                    .font(.system(size: 10, design: .monospaced))
                    .frame(height: 120)
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
                    .keyboardShortcut(.defaultAction)
                    .disabled(manager.jsonConfigTextInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("How to obtain your WiZ config file:")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                Text("1. In WiZ v2 app, tap Settings (gear) → Integrations → Local Integrations.\n2. Tap export to generate the download link, then open it in a browser to save the .json file.\n3. Click 'Auto-Import from ~/Downloads' above, and DeskOrbit will automatically register your bulbs!")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(10)
            .background(Color.primary.opacity(0.04))
            .cornerRadius(8)
        }
        .padding(20)
        .frame(width: 480)
    }
}

// MARK: - Integration Guide Modal Sheet
private struct WizIntegrationGuideSheetView: View {
    @Binding var isPresented: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.14))
                        .frame(width: 36, height: 36)
                    Image(systemName: "book.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.accentColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("WiZ v2 Local Protocol Guide")
                        .font(.system(size: 15, weight: .bold))
                    Text("Direct UDP Local Network Control (Port 38899)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button("Done") {
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
                .keyboardShortcut(.cancelAction)
                .controlSize(.regular)
            }

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    // Step 1: Getting JSON
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "key.fill")
                                .foregroundColor(.accentColor)
                            Text("1. Exporting WiZ v2 Local Configuration")
                                .font(.system(size: 12, weight: .bold))
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("1. Open the **WiZ v2 App** → Tap **Settings** (gear icon) → **Integrations**.")
                            Text("2. Select **Local Integrations**.")
                            Text("3. Generate the export download link. Open it in Safari or Chrome to download the `.json` file.")
                            Text("4. In DeskOrbit, click **'Auto-Import JSON'**.")
                        }
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .padding(10)
                        .background(Color.accentColor.opacity(0.06))
                        .cornerRadius(8)
                    }

                    // Does it expire?
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "clock.badge.checkmark.fill")
                                .foregroundColor(.green)
                            Text("2. Do the Integration Keys Expire?")
                                .font(.system(size: 12, weight: .bold))
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("• **The 15-Minute Link:** The download URL expires after 15 minutes for security during download.")
                            Text("• **The Keys inside the file:** **NEVER EXPIRE**. The `udp_signing_key` and `home_id` are stored permanently in the bulb's flash memory.")
                            Text("• They only change if you perform a physical factory reset on your bulb or create a new home.")
                        }
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .padding(10)
                        .background(Color.green.opacity(0.06))
                        .cornerRadius(8)
                    }

                    // Security Options
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "shield.lefthalf.filled")
                                .foregroundColor(.accentColor)
                            Text("3. Security Mode Options")
                                .font(.system(size: 12, weight: .bold))
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("In the WiZ App under **Settings → Security → Local network communication**:")
                            Text("• **'Only verified controls' (Recommended):** Bulbs reject unsigned UDP packets. DeskOrbit automatically computes HMAC-SHA256 signatures using your imported home key.")
                            Text("• **'All controls':** Bulbs accept unauthenticated packets from any LAN device.")
                        }
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .padding(10)
                        .background(Color.accentColor.opacity(0.06))
                        .cornerRadius(8)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(20)
        .frame(width: 520, height: 480)
    }
}
