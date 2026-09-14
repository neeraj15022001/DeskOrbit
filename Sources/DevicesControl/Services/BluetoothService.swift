import Foundation
import IOBluetooth
import IOKit.ps

public final class BluetoothService: @unchecked Sendable {
    public init() {}

    public func fetchBluetoothDevices() -> [BluetoothItem] {
        guard let paired = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] else {
            return []
        }

        let batteryMap = fetchConnectedBatteryLevels()

        return paired.compactMap { device -> BluetoothItem? in
            let address = device.addressString ?? UUID().uuidString
            let name = device.nameOrAddress ?? "Bluetooth Device"
            let isConnected = device.isConnected()

            let battery = isConnected ? (batteryMap[name] ?? batteryMap[address]) : nil
            let type = determineDeviceType(device: device)

            return BluetoothItem(
                id: address,
                name: name,
                isConnected: isConnected,
                isPaired: true,
                batteryPercent: battery,
                deviceType: type
            )
        }
    }

    public func toggleConnection(for deviceAddress: String) -> Bool {
        guard let device = IOBluetoothDevice(addressString: deviceAddress) else {
            return false
        }

        if device.isConnected() {
            device.closeConnection()
            return false
        } else {
            let result = device.openConnection()
            return result == kIOReturnSuccess
        }
    }

    private func determineDeviceType(device: IOBluetoothDevice) -> String {
        let name = (device.nameOrAddress ?? "").lowercased()

        if name.contains("airpods") || name.contains("buds") || name.contains("headphone") || name.contains("headset") || name.contains("wh-") || name.contains("wf-") {
            return "Audio / Headphones"
        } else if name.contains("mouse") || name.contains("trackpad") {
            return "Pointing Device"
        } else if name.contains("keyboard") || name.contains("keychron") {
            return "Keyboard"
        } else if name.contains("controller") || name.contains("gamepad") || name.contains("dualsense") || name.contains("xbox") {
            return "Game Controller"
        } else if name.contains("iphone") || name.contains("ipad") || name.contains("phone") {
            return "Mobile Device"
        }

        let majorClass = device.deviceClassMajor
        switch majorClass {
        case 0x04: return "Audio Device"
        case 0x05: return "Peripheral"
        case 0x02: return "Phone"
        default: return "Bluetooth Device"
        }
    }

    private func fetchConnectedBatteryLevels() -> [String: Int] {
        var levels: [String: Int] = [:]

        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else {
            return levels
        }

        for source in sources {
            guard let desc = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }

            if let name = desc[kIOPSNameKey as String] as? String,
               let current = desc[kIOPSCurrentCapacityKey as String] as? Int,
               let max = desc[kIOPSMaxCapacityKey as String] as? Int,
               max > 0 {
                let percentage = Int((Double(current) / Double(max)) * 100.0)
                levels[name] = percentage
            }
        }

        return levels
    }
}
