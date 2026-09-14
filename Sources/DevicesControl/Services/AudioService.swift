import Foundation
import CoreAudio
import AudioToolbox

public final class AudioService: @unchecked Sendable {
    public var onDevicesChanged: (() -> Void)?

    private var listenerBlock: AudioObjectPropertyListenerBlock?

    public init() {
        setupListener()
    }

    deinit {
        removeListener()
    }

    private func setupListener() {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.onDevicesChanged?()
            }
        }
        self.listenerBlock = block

        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            DispatchQueue.global(qos: .userInitiated),
            block
        )

        var defaultOutputAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &defaultOutputAddress,
            DispatchQueue.global(qos: .userInitiated),
            block
        )
    }

    private func removeListener() {
        guard let block = listenerBlock else { return }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectRemovePropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            DispatchQueue.global(qos: .userInitiated),
            block
        )

        var defaultOutputAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectRemovePropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &defaultOutputAddress,
            DispatchQueue.global(qos: .userInitiated),
            block
        )
    }

    public func fetchAudioDevices() -> [AudioItem] {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        let status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize
        )

        guard status == noErr, dataSize > 0 else {
            return []
        }

        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)

        let getStatus = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &deviceIDs
        )

        guard getStatus == noErr else {
            return []
        }

        let defaultOutputID = getDefaultOutputDeviceID()
        let defaultInputID = getDefaultInputDeviceID()

        return deviceIDs.compactMap { deviceID -> AudioItem? in
            guard let name = getDeviceName(deviceID: deviceID) else { return nil }

            let hasOutput = deviceHasStreams(deviceID: deviceID, scope: kAudioObjectPropertyScopeOutput)
            let hasInput = deviceHasStreams(deviceID: deviceID, scope: kAudioObjectPropertyScopeInput)

            guard hasOutput || hasInput else { return nil }

            let volume = getDeviceVolume(deviceID: deviceID)
            let isMuted = getDeviceMute(deviceID: deviceID)
            let transport = getDeviceTransportType(deviceID: deviceID)

            return AudioItem(
                id: deviceID,
                name: name,
                isDefaultOutput: deviceID == defaultOutputID,
                isDefaultInput: deviceID == defaultInputID,
                isOutput: hasOutput,
                isInput: hasInput,
                volume: volume,
                isMuted: isMuted,
                transportType: transport
            )
        }
    }

    public func getDefaultOutputDeviceID() -> AudioDeviceID {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID: AudioDeviceID = 0
        var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)

        AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &deviceID
        )
        return deviceID
    }

    public func getDefaultInputDeviceID() -> AudioDeviceID {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID: AudioDeviceID = 0
        var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)

        AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &deviceID
        )
        return deviceID
    }

    public func setDefaultOutputDevice(deviceID: AudioDeviceID) {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var id = deviceID
        let dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)

        AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            dataSize,
            &id
        )
    }

    public func getDeviceVolume(deviceID: AudioDeviceID) -> Float {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        var volume: Float32 = 0.5
        var dataSize = UInt32(MemoryLayout<Float32>.size)

        var status = AudioObjectGetPropertyData(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &volume
        )

        if status != noErr {
            // Fall back to channel 1 (master vs left channel)
            propertyAddress.mElement = 1
            status = AudioObjectGetPropertyData(
                deviceID,
                &propertyAddress,
                0,
                nil,
                &dataSize,
                &volume
            )
        }

        return (status == noErr) ? volume : 0.5
    }

    public func setDeviceVolume(deviceID: AudioDeviceID, volume: Float) {
        let clamped = max(0.0, min(1.0, volume))
        var val: Float32 = clamped
        let dataSize = UInt32(MemoryLayout<Float32>.size)

        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        let hasMaster = AudioObjectHasProperty(deviceID, &propertyAddress)
        if hasMaster {
            AudioObjectSetPropertyData(deviceID, &propertyAddress, 0, nil, dataSize, &val)
        } else {
            // Set channel 1 & channel 2
            propertyAddress.mElement = 1
            AudioObjectSetPropertyData(deviceID, &propertyAddress, 0, nil, dataSize, &val)
            propertyAddress.mElement = 2
            AudioObjectSetPropertyData(deviceID, &propertyAddress, 0, nil, dataSize, &val)
        }
    }

    public func getDeviceMute(deviceID: AudioDeviceID) -> Bool {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        var isMuted: UInt32 = 0
        var dataSize = UInt32(MemoryLayout<UInt32>.size)

        var status = AudioObjectGetPropertyData(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &isMuted
        )

        if status != noErr {
            propertyAddress.mElement = 1
            status = AudioObjectGetPropertyData(
                deviceID,
                &propertyAddress,
                0,
                nil,
                &dataSize,
                &isMuted
            )
        }

        return (status == noErr) ? (isMuted != 0) : false
    }

    public func setDeviceMute(deviceID: AudioDeviceID, mute: Bool) {
        var isMuted: UInt32 = mute ? 1 : 0
        let dataSize = UInt32(MemoryLayout<UInt32>.size)

        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        let hasMaster = AudioObjectHasProperty(deviceID, &propertyAddress)
        if hasMaster {
            AudioObjectSetPropertyData(deviceID, &propertyAddress, 0, nil, dataSize, &isMuted)
        } else {
            propertyAddress.mElement = 1
            AudioObjectSetPropertyData(deviceID, &propertyAddress, 0, nil, dataSize, &isMuted)
        }
    }

    private func getDeviceName(deviceID: AudioDeviceID) -> String? {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var unmanagedName: Unmanaged<CFString>?
        var dataSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)

        let status = withUnsafeMutablePointer(to: &unmanagedName) { ptr in
            AudioObjectGetPropertyData(
                deviceID,
                &propertyAddress,
                0,
                nil,
                &dataSize,
                ptr
            )
        }

        if status == noErr, let cf = unmanagedName?.takeRetainedValue() {
            return cf as String
        }
        return nil
    }

    private func deviceHasStreams(deviceID: AudioDeviceID, scope: AudioObjectPropertyScope) -> Bool {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        let status = AudioObjectGetPropertyDataSize(deviceID, &propertyAddress, 0, nil, &dataSize)
        return (status == noErr && dataSize > 0)
    }

    private func getDeviceTransportType(deviceID: AudioDeviceID) -> String {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyTransportType,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var transportType: UInt32 = 0
        var dataSize = UInt32(MemoryLayout<UInt32>.size)

        let status = AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, nil, &dataSize, &transportType)
        guard status == noErr else { return "Audio" }

        switch transportType {
        case kAudioDeviceTransportTypeBuiltIn: return "Built-In"
        case kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE: return "Bluetooth"
        case kAudioDeviceTransportTypeUSB: return "USB"
        case kAudioDeviceTransportTypeDisplayPort: return "DisplayPort"
        case kAudioDeviceTransportTypeHDMI: return "HDMI"
        case kAudioDeviceTransportTypeAirPlay: return "AirPlay"
        default: return "Audio"
        }
    }
}
