import Foundation
import IOKit
import IOKit.ps

public final class BatteryPowerService {
    public static let shared = BatteryPowerService()

    private var updateTimer: Timer?
    public var onPowerDataChanged: ((BatteryPowerInfo) -> Void)?

    public init() {
        startMonitoring()
    }

    deinit {
        stopMonitoring()
    }

    public func startMonitoring() {
        // Initial fetch
        _ = fetchBatteryPowerInfo()

        // Timer for live battery & power metrics every 3 seconds
        DispatchQueue.main.async { [weak self] in
            self?.updateTimer?.invalidate()
            self?.updateTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                let info = self.fetchBatteryPowerInfo()
                self.onPowerDataChanged?(info)
            }
        }
    }

    public func stopMonitoring() {
        updateTimer?.invalidate()
        updateTimer = nil
    }

    public func fetchBatteryPowerInfo() -> BatteryPowerInfo {
        var info = BatteryPowerInfo()

        var iterator: io_iterator_t = 0
        let matching = IOServiceMatching("AppleSmartBattery")
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)

        guard result == KERN_SUCCESS else {
            return info
        }

        defer {
            IOObjectRelease(iterator)
        }

        let service = IOIteratorNext(iterator)
        guard service != 0 else {
            // Desktop Mac without internal battery
            info.isInstalled = false
            return info
        }

        defer {
            IOObjectRelease(service)
        }

        var props: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let dict = props?.takeRetainedValue() as? [String: Any] else {
            return info
        }

        info.isInstalled = (dict["BatteryInstalled"] as? Int ?? 1) == 1
        info.currentPercentage = dict["CurrentCapacity"] as? Int ?? 100
        info.isCharging = (dict["IsCharging"] as? Int ?? 0) == 1
        info.isFullyCharged = (dict["FullyCharged"] as? Int ?? 0) == 1
        info.isExternalConnected = (dict["ExternalConnected"] as? Int ?? 0) == 1
        info.cycleCount = dict["CycleCount"] as? Int ?? 0
        info.designCycleCount = dict["DesignCycleCount9C"] as? Int ?? 1000

        let rawVoltage = dict["Voltage"] as? Int ?? (dict["AppleRawBatteryVoltage"] as? Int ?? 0)
        info.voltageVolts = Double(rawVoltage) / 1000.0

        let rawAmperage = dict["InstantAmperage"] as? Int ?? (dict["Amperage"] as? Int ?? 0)
        info.amperageMilliAmps = rawAmperage
        info.deviceName = dict["DeviceName"] as? String ?? "Apple Smart Battery"
        info.serialNumber = dict["Serial"] as? String ?? ""

        // Extract Capacities & Health
        if let batteryData = dict["BatteryData"] as? [String: Any] {
            info.currentCapacityMah = batteryData["CurrentCapacity"] as? Int ?? info.currentPercentage
            info.remainingCapacityMah = batteryData["RemainingCapacity"] as? Int ?? 0
            info.fullChargeCapacityMah = batteryData["FullChargeCapacity"] as? Int ?? 0
            info.nominalChargeCapacityMah = batteryData["NominalChargeCapacity"] as? Int ?? 0
            info.designCapacityMah = batteryData["DesignCapacity"] as? Int ?? 0

            if info.designCapacityMah > 0 {
                let capacityToCompare = info.nominalChargeCapacityMah > 0 ? info.nominalChargeCapacityMah : info.fullChargeCapacityMah
                if capacityToCompare > 0 {
                    info.healthPercentage = (Double(capacityToCompare) / Double(info.designCapacityMah)) * 100.0
                }
            }

            if let pwr = batteryData["BatteryPower"] as? Int {
                info.batteryPowerWatts = Double(pwr) / 1000.0
            }
        }

        // Health Condition string
        if info.healthPercentage >= 80.0 && info.cycleCount < info.designCycleCount {
            info.healthCondition = "Normal"
        } else if info.healthPercentage < 80.0 {
            info.healthCondition = "Service Recommended"
        } else {
            info.healthCondition = "Fair"
        }

        // Temperature (from DeadBatteryBootData if available)
        if let deadData = dict["DeadBatteryBootData"] as? [String: Any],
           let genPayload = deadData["GeneralPayload"] as? [String: Any],
           let temp = genPayload["AverageBattVirtualTemp"] as? Double ?? (genPayload["AverageBattSkinTemp"] as? Double) {
            info.temperatureCelsius = temp
        } else if let deadData = dict["DeadBatteryBootData"] as? [String: Any],
                  let genPayload = deadData["GeneralPayload"] as? [String: Any],
                  let tempInt = genPayload["AverageBattVirtualTemp"] as? Int ?? (genPayload["AverageBattSkinTemp"] as? Int) {
            info.temperatureCelsius = Double(tempInt)
        }

        // Power Telemetry
        if let telemetry = dict["PowerTelemetryData"] as? [String: Any] {
            if let sysLoad = telemetry["SystemLoad"] as? Int {
                info.systemLoadWatts = Double(sysLoad) / 1000.0
            } else if let sysPwr = telemetry["SystemPowerIn"] as? Int {
                info.systemLoadWatts = Double(sysPwr) / 1000.0
            }
        }

        // Adapter Details
        var adapter = PowerAdapterInfo()
        if let adapterDict = dict["AdapterDetails"] as? [String: Any] {
            adapter.isConnected = true
            adapter.name = adapterDict["Name"] as? String ?? "Power Adapter"
            adapter.manufacturer = adapterDict["Manufacturer"] as? String ?? "Apple Inc."
            adapter.serialNumber = adapterDict["SerialString"] as? String ?? ""
            adapter.description = adapterDict["Description"] as? String ?? ""
            adapter.firmwareVersion = adapterDict["FwVersion"] as? String ?? ""
            adapter.hardwareVersion = adapterDict["HwVersion"] as? String ?? ""
            adapter.ratedWatts = adapterDict["Watts"] as? Int ?? 0

            if let menu = adapterDict["UsbHvcMenu"] as? [[String: Any]] {
                adapter.pdProfiles = menu.compactMap { item in
                    guard let idx = item["Index"] as? Int,
                          let mv = item["MaxVoltage"] as? Int,
                          let ma = item["MaxCurrent"] as? Int else { return nil }
                    return UsbPdProfile(
                        id: idx,
                        maxVoltageVolts: Double(mv) / 1000.0,
                        maxCurrentAmps: Double(ma) / 1000.0
                    )
                }
            }
        } else {
            adapter.isConnected = info.isExternalConnected
            if adapter.isConnected {
                adapter.name = "AC Power Adapter"
            }
        }

        // Real-Time Power Distribution
        if let dist = dict["PowerDistribution"] as? [String: Any] {
            if let ipdPwr = dist["IPDInputPower"] as? Int {
                adapter.inputPowerWatts = Double(ipdPwr) / 1000.0
            }
            if let ipdVolt = dist["IPDInputVoltage"] as? Int {
                adapter.inputVoltageVolts = Double(ipdVolt) / 1000.0
            }
            if let ipdCurr = dist["IPDInputCurrent"] as? Int {
                adapter.inputCurrentAmps = Double(ipdCurr) / 1000.0
            }
            adapter.isChargingAllowed = (dist["IPDChargingAllowed"] as? Int ?? 0) == 1
        }

        info.adapter = adapter
        return info
    }
}

// Extension to add remainingCapacityMah helper
extension BatteryPowerInfo {
    public var remainingCapacityMah: Int {
        get { currentCapacityMah }
        set { currentCapacityMah = newValue }
    }
}
