import Foundation

public enum DeviceCategory: String, CaseIterable, Identifiable {
    case all = "All"
    case display = "Displays"
    case audio = "Audio"
    case bluetooth = "Bluetooth"
    case storage = "Storage"

    public var id: String { rawValue }

    public var systemImage: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .display: return "display"
        case .audio: return "speaker.wave.2"
        case .bluetooth: return "dot.radiowaves.left.and.right"
        case .storage: return "externaldrive"
        }
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
