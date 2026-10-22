import Foundation
import Combine
import SwiftUI

public final class DeviceManager: ObservableObject {
    public static let shared = DeviceManager()

    @Published public var displays: [DisplayItem] = []
    @Published public var audioDevices: [AudioItem] = []
    @Published public var bluetoothDevices: [BluetoothItem] = []
    @Published public var storageDevices: [StorageItem] = []
    @Published public var batteryInfo: BatteryPowerInfo = BatteryPowerInfo()
    @Published public var smartLights: [WizLightItem] = []
    @Published public var activeLightModes: [String: String] = [:]
    @Published public var isAdvancedPowerView: Bool = false
    @Published public var isDiscoveringLights: Bool = false
    @Published public var isShowingAddBulbSheet: Bool = false
    @Published public var isShowingImportJsonSheet: Bool = false
    @Published public var newBulbIPInput: String = ""
    @Published public var newBulbNameInput: String = ""
    @Published public var jsonConfigTextInput: String = ""

    @Published public var defaultAudioOutput: AudioItem?
    @Published public var mainDisplay: DisplayItem?
    @Published public var activeCategory: DeviceCategory = .all
    @Published public var searchText: String = ""
    @Published public var statusMessage: String?

    public let audioService = AudioService()
    public let displayService = DisplayService()
    public let bluetoothService = BluetoothService()
    public let storageService = StorageService()
    public let batteryService = BatteryPowerService.shared
    public let wizLightService = WizLightService.shared

    private var timer: Timer?

    public init() {
        setupBindings()
        refreshAll()
        startPeriodicCheck()
    }

    deinit {
        timer?.invalidate()
    }

    private func setupBindings() {
        audioService.onDevicesChanged = { [weak self] in
            self?.refreshAudio()
        }

        storageService.onStorageChanged = { [weak self] in
            self?.refreshStorage()
        }

        batteryService.onPowerDataChanged = { [weak self] info in
            DispatchQueue.main.async {
                self?.batteryInfo = info
            }
        }

        wizLightService.onLightsChanged = { [weak self] lights in
            DispatchQueue.main.async {
                self?.smartLights = lights
            }
        }
    }

    private func startPeriodicCheck() {
        // Periodic refresh every 4 seconds to catch Bluetooth, Displays & Battery changes
        timer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { [weak self] _ in
            self?.refreshBluetooth()
            self?.refreshDisplays()
            self?.refreshBattery()
        }
    }

    public func refreshAll() {
        refreshBattery()
        refreshDisplays()
        refreshAudio()
        refreshBluetooth()
        refreshStorage()
        refreshLights()
    }

    public func refreshBattery() {
        let info = batteryService.fetchBatteryPowerInfo()
        DispatchQueue.main.async {
            self.batteryInfo = info
        }
    }

    public func refreshDisplays() {
        let items = displayService.fetchDisplays()
        DispatchQueue.main.async {
            self.displays = items
            self.mainDisplay = items.first(where: { $0.isMain }) ?? items.first
        }
    }

    public func refreshAudio() {
        let items = audioService.fetchAudioDevices()
        DispatchQueue.main.async {
            self.audioDevices = items
            self.defaultAudioOutput = items.first(where: { $0.isDefaultOutput })
        }
    }

    public func refreshBluetooth() {
        let items = bluetoothService.fetchBluetoothDevices()
        DispatchQueue.main.async {
            self.bluetoothDevices = items
        }
    }

    public func refreshStorage() {
        let items = storageService.fetchStorageDevices()
        DispatchQueue.main.async {
            self.storageDevices = items
        }
    }

    public func refreshLights() {
        smartLights = wizLightService.lights
        wizLightService.refreshAllLights()
    }

    // MARK: - Smart Light Controls (Philips WiZ)

    public func setLightPower(light: WizLightItem, isOn: Bool) {
        wizLightService.setPower(for: light, isOn: isOn)
        if let idx = smartLights.firstIndex(where: { $0.id == light.id }) {
            smartLights[idx].isOn = isOn
        }
    }

    public func toggleLightPower(light: WizLightItem) {
        let newState = !light.isOn
        setLightPower(light: light, isOn: newState)
    }

    public func setLightBrightness(light: WizLightItem, brightness: Int) {
        wizLightService.setBrightness(for: light, brightness: brightness)
        if let idx = smartLights.firstIndex(where: { $0.id == light.id }) {
            smartLights[idx].brightness = brightness
            smartLights[idx].isOn = true
        }
    }

    public func setLightRGBColor(light: WizLightItem, red: Int, green: Int, blue: Int) {
        activeLightModes[light.id] = "Colors"
        wizLightService.setRGBColor(for: light, red: red, green: green, blue: blue)
        if let idx = smartLights.firstIndex(where: { $0.id == light.id }) {
            smartLights[idx].red = red
            smartLights[idx].green = green
            smartLights[idx].blue = blue
            smartLights[idx].colorTemperature = nil
            smartLights[idx].isOn = true
        }
    }

    public func setLightTemperature(light: WizLightItem, kelvin: Int) {
        activeLightModes[light.id] = "Whites"
        wizLightService.setColorTemperature(for: light, kelvin: kelvin)
        if let idx = smartLights.firstIndex(where: { $0.id == light.id }) {
            smartLights[idx].colorTemperature = kelvin
            let rgb = wizLightService.kelvinToRGB(kelvin: kelvin)
            smartLights[idx].red = rgb.r
            smartLights[idx].green = rgb.g
            smartLights[idx].blue = rgb.b
            smartLights[idx].isOn = true
        }
    }

    public func setLightScene(light: WizLightItem, sceneId: Int) {
        wizLightService.setScene(for: light, sceneId: sceneId)
    }

    public func discoverSmartLights() {
        scanLocalWiZLights()
    }

    public func syncAllSmartLights() {
        scanLocalWiZLights()
    }

    public func scanLocalWiZLights() {
        isDiscoveringLights = true
        showStatus("Scanning local Wi-Fi for WiZ bulbs (UDP 38899)...")
        wizLightService.discoverLocalLights { [weak self] discovered in
            DispatchQueue.main.async {
                self?.isDiscoveringLights = false
                if discovered.isEmpty {
                    self?.showStatus("No WiZ bulbs responded to broadcast. You can add your bulb by IP!")
                } else {
                    self?.showStatus("Found \(discovered.count) WiZ bulb(s) on local Wi-Fi!")
                }
            }
        }
    }

    public func addDirectBulbByIP(ip: String, customName: String? = nil, completion: ((Bool) -> Void)? = nil) {
        showStatus("Connecting to WiZ bulb at \(ip)...")
        wizLightService.addDirectLight(ip: ip, customName: customName) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let bulb):
                    self?.showStatus("Successfully added \(bulb.name) (\(bulb.ip))!")
                    self?.isShowingAddBulbSheet = false
                    self?.newBulbIPInput = ""
                    self?.newBulbNameInput = ""
                    completion?(true)
                case .failure(let error):
                    self?.showStatus("Error: \(error.localizedDescription)")
                    completion?(false)
                }
            }
        }
    }

    public func linkLocalIPToBulb(bulbId: String, ip: String, completion: ((Bool) -> Void)? = nil) {
        showStatus("Linking local IP \(ip)...")
        wizLightService.linkLocalIP(bulbId: bulbId, ip: ip) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let bulb):
                    self?.showStatus("Linked \(bulb.name) to \(bulb.ip)!")
                    completion?(true)
                case .failure(let error):
                    self?.showStatus("Failed to link IP: \(error.localizedDescription)")
                    completion?(false)
                }
            }
        }
    }

    public func importWizJsonConfig(jsonString: String) {
        guard let data = jsonString.data(using: .utf8) else {
            showStatus("Invalid JSON data.")
            return
        }
        let result = wizLightService.importHomeConfig(data: data)
        switch result {
        case .success(let count):
            showStatus("Imported WiZ Home config with \(count) device(s)!")
            isShowingImportJsonSheet = false
            jsonConfigTextInput = ""
        case .failure(let err):
            showStatus("Failed to parse WiZ config JSON: \(err.localizedDescription)")
        }
    }

    public func importWizConfigFile(url: URL) {
        let result = wizLightService.importHomeConfigFile(url: url)
        switch result {
        case .success(let count):
            showStatus("Imported WiZ config file with \(count) device(s)!")
        case .failure(let err):
            showStatus("Error importing file: \(err.localizedDescription)")
        }
    }

    public func removeSmartLight(id: String) {
        wizLightService.removeLight(id: id)
        showStatus("Removed smart bulb.")
    }

    // MARK: - Display Controls
    public func setDisplayBrightness(displayID: UInt32, brightness: Float) {
        displayService.setBrightness(for: displayID, brightness: brightness)
        if let idx = displays.firstIndex(where: { $0.id == displayID }) {
            displays[idx].brightness = brightness
        }
        if mainDisplay?.id == displayID {
            mainDisplay?.brightness = brightness
        }
    }

    // MARK: - Audio Controls
    public func setAudioVolume(deviceID: UInt32, volume: Float) {
        audioService.setDeviceVolume(deviceID: deviceID, volume: volume)
        if let idx = audioDevices.firstIndex(where: { $0.id == deviceID }) {
            audioDevices[idx].volume = volume
        }
        if defaultAudioOutput?.id == deviceID {
            defaultAudioOutput?.volume = volume
        }
    }

    public func toggleAudioMute(device: AudioItem) {
        let newMute = !device.isMuted
        audioService.setDeviceMute(deviceID: device.id, mute: newMute)
        if let idx = audioDevices.firstIndex(where: { $0.id == device.id }) {
            audioDevices[idx].isMuted = newMute
        }
        if defaultAudioOutput?.id == device.id {
            defaultAudioOutput?.isMuted = newMute
        }
    }

    public func setDefaultAudioOutput(device: AudioItem) {
        audioService.setDefaultOutputDevice(deviceID: device.id)
        refreshAudio()
    }

    // MARK: - Bluetooth Controls
    public func toggleBluetooth(device: BluetoothItem) {
        _ = bluetoothService.toggleConnection(for: device.id)
        // Refresh with slight delay to allow connection handshake
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.refreshBluetooth()
        }
    }

    // MARK: - Storage Controls
    public func ejectStorage(device: StorageItem) {
        storageService.ejectVolume(at: device.mountPoint) { [weak self] result in
            switch result {
            case .success:
                self?.showStatus("Ejected \(device.name)")
                self?.refreshStorage()
            case .failure(let error):
                self?.showStatus("Failed to eject \(device.name): \(error.localizedDescription)")
            }
        }
    }

    public func showStatus(_ message: String) {
        statusMessage = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            if self?.statusMessage == message {
                self?.statusMessage = nil
            }
        }
    }
}
