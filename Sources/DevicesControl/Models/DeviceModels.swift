import Foundation

public enum DeviceCategory: String, CaseIterable, Identifiable {
    case all = "All"
    case battery = "Power & Battery"
    case display = "Displays"
    case audio = "Audio"
    case bluetooth = "Bluetooth"
    case storage = "Storage"

    public var id: String { rawValue }

    public var systemImage: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .battery: return "bolt.batteryblock.fill"
        case .display: return "display"
        case .audio: return "speaker.wave.2"
        case .bluetooth: return "dot.radiowaves.left.and.right"
        case .storage: return "externaldrive"
        }
    }
}

public struct UsbPdProfile: Identifiable, Equatable {
    public var id: Int
    public var maxVoltageVolts: Double
    public var maxCurrentAmps: Double
    public var maxPowerWatts: Double

    public init(id: Int, maxVoltageVolts: Double, maxCurrentAmps: Double) {
        self.id = id
        self.maxVoltageVolts = maxVoltageVolts
        self.maxCurrentAmps = maxCurrentAmps
        self.maxPowerWatts = maxVoltageVolts * maxCurrentAmps
    }
}

public struct PowerAdapterInfo: Equatable {
    public var isConnected: Bool
    public var name: String
    public var manufacturer: String
    public var serialNumber: String
    public var description: String
    public var firmwareVersion: String
    public var hardwareVersion: String
    public var ratedWatts: Int
    public var inputPowerWatts: Double
    public var inputVoltageVolts: Double
    public var inputCurrentAmps: Double
    public var isChargingAllowed: Bool
    public var pdProfiles: [UsbPdProfile]

    public init(
        isConnected: Bool = false,
        name: String = "No Adapter Attached",
        manufacturer: String = "Apple Inc.",
        serialNumber: String = "",
        description: String = "",
        firmwareVersion: String = "",
        hardwareVersion: String = "",
        ratedWatts: Int = 0,
        inputPowerWatts: Double = 0.0,
        inputVoltageVolts: Double = 0.0,
        inputCurrentAmps: Double = 0.0,
        isChargingAllowed: Bool = false,
        pdProfiles: [UsbPdProfile] = []
    ) {
        self.isConnected = isConnected
        self.name = name
        self.manufacturer = manufacturer
        self.serialNumber = serialNumber
        self.description = description
        self.firmwareVersion = firmwareVersion
        self.hardwareVersion = hardwareVersion
        self.ratedWatts = ratedWatts
        self.inputPowerWatts = inputPowerWatts
        self.inputVoltageVolts = inputVoltageVolts
        self.inputCurrentAmps = inputCurrentAmps
        self.isChargingAllowed = isChargingAllowed
        self.pdProfiles = pdProfiles
    }
}

public struct BatteryPowerInfo: Equatable {
    public var isInstalled: Bool
    public var currentPercentage: Int // 0 - 100
    public var isCharging: Bool
    public var isFullyCharged: Bool
    public var isExternalConnected: Bool
    public var cycleCount: Int
    public var designCycleCount: Int
    public var healthPercentage: Double // e.g. 85.2%
    public var healthCondition: String
    public var voltageVolts: Double
    public var amperageMilliAmps: Int
    public var batteryPowerWatts: Double
    public var systemLoadWatts: Double
    public var temperatureCelsius: Double?
    public var currentCapacityMah: Int
    public var fullChargeCapacityMah: Int
    public var designCapacityMah: Int
    public var nominalChargeCapacityMah: Int
    public var deviceName: String
    public var serialNumber: String
    public var adapter: PowerAdapterInfo

    public var statusDescription: String {
        if !isInstalled {
            return "No Battery Detected (Desktop Mac)"
        }
        if isExternalConnected {
            if isCharging {
                if adapter.inputPowerWatts > 0 {
                    return String(format: "Charging at %.1fW (%d%%)", adapter.inputPowerWatts, currentPercentage)
                }
                return "Charging (\(currentPercentage)%)"
            } else if isFullyCharged {
                return "Fully Charged (AC Connected)"
            } else {
                return "On AC Power (Optimized Charging / Power Adapter)"
            }
        } else {
            return "Discharging on Battery (\(currentPercentage)%)"
        }
    }

    public init(
        isInstalled: Bool = true,
        currentPercentage: Int = 100,
        isCharging: Bool = false,
        isFullyCharged: Bool = false,
        isExternalConnected: Bool = false,
        cycleCount: Int = 0,
        designCycleCount: Int = 1000,
        healthPercentage: Double = 100.0,
        healthCondition: String = "Normal",
        voltageVolts: Double = 0.0,
        amperageMilliAmps: Int = 0,
        batteryPowerWatts: Double = 0.0,
        systemLoadWatts: Double = 0.0,
        temperatureCelsius: Double? = nil,
        currentCapacityMah: Int = 0,
        fullChargeCapacityMah: Int = 0,
        designCapacityMah: Int = 0,
        nominalChargeCapacityMah: Int = 0,
        deviceName: String = "",
        serialNumber: String = "",
        adapter: PowerAdapterInfo = PowerAdapterInfo()
    ) {
        self.isInstalled = isInstalled
        self.currentPercentage = currentPercentage
        self.isCharging = isCharging
        self.isFullyCharged = isFullyCharged
        self.isExternalConnected = isExternalConnected
        self.cycleCount = cycleCount
        self.designCycleCount = designCycleCount
        self.healthPercentage = healthPercentage
        self.healthCondition = healthCondition
        self.voltageVolts = voltageVolts
        self.amperageMilliAmps = amperageMilliAmps
        self.batteryPowerWatts = batteryPowerWatts
        self.systemLoadWatts = systemLoadWatts
        self.temperatureCelsius = temperatureCelsius
        self.currentCapacityMah = currentCapacityMah
        self.fullChargeCapacityMah = fullChargeCapacityMah
        self.designCapacityMah = designCapacityMah
        self.nominalChargeCapacityMah = nominalChargeCapacityMah
        self.deviceName = deviceName
        self.serialNumber = serialNumber
        self.adapter = adapter
    }
}

public struct DisplayItem: Identifiable, Equatable {
    public let id: UInt32
    public var name: String
    public var isMain: Bool
    public var isBuiltIn: Bool
    public var brightness: Float // 0.0 to 1.0
    public var resolution: String

    public init(
        id: UInt32,
        name: String,
        isMain: Bool = false,
        isBuiltIn: Bool = false,
        brightness: Float = 0.5,
        resolution: String = ""
    ) {
        self.id = id
        self.name = name
        self.isMain = isMain
        self.isBuiltIn = isBuiltIn
        self.brightness = brightness
        self.resolution = resolution
    }
}

public struct AudioItem: Identifiable, Equatable {
    public let id: UInt32
    public var name: String
    public var isDefaultOutput: Bool
    public var isDefaultInput: Bool
    public var isOutput: Bool
    public var isInput: Bool
    public var volume: Float // 0.0 to 1.0
    public var isMuted: Bool
    public var transportType: String

    public init(
        id: UInt32,
        name: String,
        isDefaultOutput: Bool = false,
        isDefaultInput: Bool = false,
        isOutput: Bool = true,
        isInput: Bool = false,
        volume: Float = 0.5,
        isMuted: Bool = false,
        transportType: String = "Internal"
    ) {
        self.id = id
        self.name = name
        self.isDefaultOutput = isDefaultOutput
        self.isDefaultInput = isDefaultInput
        self.isOutput = isOutput
        self.isInput = isInput
        self.volume = volume
        self.isMuted = isMuted
        self.transportType = transportType
    }
}

public struct BluetoothItem: Identifiable, Equatable {
    public let id: String // MAC address
    public var name: String
    public var isConnected: Bool
    public var isPaired: Bool
    public var batteryPercent: Int?
    public var deviceType: String

    public init(
        id: String,
        name: String,
        isConnected: Bool,
        isPaired: Bool = true,
        batteryPercent: Int? = nil,
        deviceType: String = "Peripheral"
    ) {
        self.id = id
        self.name = name
        self.isConnected = isConnected
        self.isPaired = isPaired
        self.batteryPercent = batteryPercent
        self.deviceType = deviceType
    }
}

public struct StorageItem: Identifiable, Equatable {
    public let id: String
    public var name: String
    public var mountPoint: URL
    public var totalBytes: Int64
    public var freeBytes: Int64
    public var isRemovable: Bool
    public var isEjectable: Bool

    public var usedBytes: Int64 {
        max(0, totalBytes - freeBytes)
    }

    public var usedPercentage: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(usedBytes) / Double(totalBytes)
    }

    public var formattedTotal: String {
        ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
    }

    public var formattedFree: String {
        ByteCountFormatter.string(fromByteCount: freeBytes, countStyle: .file)
    }

    public init(
        id: String,
        name: String,
        mountPoint: URL,
        totalBytes: Int64,
        freeBytes: Int64,
        isRemovable: Bool = true,
        isEjectable: Bool = true
    ) {
        self.id = id
        self.name = name
        self.mountPoint = mountPoint
        self.totalBytes = totalBytes
        self.freeBytes = freeBytes
        self.isRemovable = isRemovable
        self.isEjectable = isEjectable
    }
}
