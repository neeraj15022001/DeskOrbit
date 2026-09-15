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
    @Published public var isAdvancedPowerView: Bool = false

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
