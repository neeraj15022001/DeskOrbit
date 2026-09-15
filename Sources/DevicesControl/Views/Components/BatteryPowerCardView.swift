import SwiftUI

public struct BatteryPowerCardView: View {
    @ObservedObject var manager: DeviceManager
    public var isCompact: Bool = false

    public init(manager: DeviceManager = .shared, isCompact: Bool = false) {
        self.manager = manager
        self.isCompact = isCompact
    }

    private var info: BatteryPowerInfo {
        manager.batteryInfo
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // MARK: - Header & Primary Status
            HStack(alignment: .center, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(batteryColor.opacity(0.15))
                        .frame(width: isCompact ? 38 : 46, height: isCompact ? 38 : 46)

                    Image(systemName: batterySymbolName)
                        .font(.system(size: isCompact ? 18 : 22, weight: .semibold))
                        .foregroundColor(batteryColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(info.currentPercentage)%")
                            .font(.system(size: isCompact ? 22 : 26, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: true, vertical: false)

                        if info.isExternalConnected {
                            HStack(spacing: 3) {
                                Image(systemName: info.isCharging ? "bolt.fill" : "powerplug.fill")
                                    .font(.system(size: 9, weight: .bold))
                                Text(chargingPillText)
                                    .font(.system(size: 10, weight: .bold))
                                    .fixedSize(horizontal: true, vertical: false)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(info.isCharging ? Color.green.opacity(0.18) : Color.blue.opacity(0.18))
                            .foregroundColor(info.isCharging ? .green : .cyan)
                            .cornerRadius(5)
                        }
                    }

                    Text(info.statusDescription)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                // Basic vs Advanced Toggle
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        manager.isAdvancedPowerView.toggle()
                    }
                }) {
                    HStack(spacing: 3) {
                        Text(manager.isAdvancedPowerView ? "Basic" : "Advanced")
                            .font(.system(size: 10, weight: .semibold))
                        Image(systemName: manager.isAdvancedPowerView ? "chevron.up" : "chevron.down")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.12))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }

            // MARK: - Level Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.primary.opacity(0.08))
                        .frame(height: 7)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [batteryColor, batteryColor.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(info.currentPercentage) / 100.0)), height: 7)
                }
            }
            .frame(height: 7)

            // MARK: - Metrics Grid (Organized in 2 rows to avoid clipping)
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    MetricChip(
                        icon: "heart.fill",
                        iconColor: .pink,
                        label: "Health",
                        value: String(format: "%.0f%% (%@)", info.healthPercentage, info.healthCondition)
                    )

                    MetricChip(
                        icon: "arrow.triangle.2.circlepath",
                        iconColor: .orange,
                        label: "Cycle Count",
                        value: "\(info.cycleCount) / \(info.designCycleCount)"
                    )
                }

                if info.adapter.isConnected {
                    HStack(spacing: 8) {
                        MetricChip(
                            icon: "bolt.fill",
                            iconColor: .yellow,
                            label: "Input Power",
                            value: info.adapter.inputPowerWatts > 0 ? String(format: "%.1f W", info.adapter.inputPowerWatts) : "\(info.adapter.ratedWatts)W Rated"
                        )

                        MetricChip(
                            icon: "powerplug.fill",
                            iconColor: .cyan,
                            label: "Adapter",
                            value: info.adapter.ratedWatts > 0 ? "\(info.adapter.ratedWatts)W USB-C" : "AC Power"
                        )
                    }
                }
            }

            // MARK: - Advanced Detailed Telemetry (Expanded)
            if manager.isAdvancedPowerView {
                VStack(alignment: .leading, spacing: 12) {
                    Divider().opacity(0.3)

                    // Sub-section 1: Power Adapter & Real-time Input
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Adapter & Charging Contract", systemImage: "powerplug")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)

                        VStack(spacing: 5) {
                            DataRow(label: "Charger Name", value: info.adapter.name)
                            if !info.adapter.manufacturer.isEmpty {
                                DataRow(label: "Manufacturer", value: info.adapter.manufacturer)
                            }
                            if info.adapter.ratedWatts > 0 {
                                DataRow(label: "Rated Power", value: "\(info.adapter.ratedWatts) Watts")
                            }
                            if info.adapter.inputPowerWatts > 0 {
                                DataRow(label: "Real-Time Input", value: String(format: "%.2f W", info.adapter.inputPowerWatts), highlight: true)
                            }
                            if info.adapter.inputVoltageVolts > 0 {
                                DataRow(label: "Input Voltage", value: String(format: "%.2f V", info.adapter.inputVoltageVolts))
                            }
                            if info.adapter.inputCurrentAmps > 0 {
                                DataRow(label: "Input Current", value: String(format: "%.2f A", info.adapter.inputCurrentAmps))
                            }
                            if !info.adapter.serialNumber.isEmpty {
                                DataRow(label: "Serial", value: info.adapter.serialNumber)
                            }
                            if !info.adapter.firmwareVersion.isEmpty {
                                DataRow(label: "Firmware/HW", value: "\(info.adapter.firmwareVersion) (HW: \(info.adapter.hardwareVersion))")
                            }
                        }
                        .padding(8)
                        .background(Color.primary.opacity(0.03))
                        .cornerRadius(7)
                    }

                    // Sub-section 2: USB-PD Power Profiles
                    if !info.adapter.pdProfiles.isEmpty {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("USB-PD Voltage Profiles:")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.secondary)

                            HStack(spacing: 4) {
                                ForEach(info.adapter.pdProfiles) { profile in
                                    VStack(alignment: .center, spacing: 1) {
                                        Text(String(format: "%.0fV", profile.maxVoltageVolts))
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.primary)
                                        Text(String(format: "%.1fA", profile.maxCurrentAmps))
                                            .font(.system(size: 8))
                                            .foregroundColor(.secondary)
                                        Text(String(format: "%.0fW", profile.maxPowerWatts))
                                            .font(.system(size: 8, weight: .bold))
                                            .foregroundColor(.accentColor)
                                    }
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 4)
                                    .background(Color.accentColor.opacity(0.08))
                                    .cornerRadius(5)
                                }
                            }
                        }
                    }

                    // Sub-section 3: Battery Capacities & Health
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Battery Capacities & Specs", systemImage: "battery.100")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)

                        VStack(spacing: 5) {
                            DataRow(label: "Health Condition", value: info.healthCondition)
                            DataRow(label: "Maximum Capacity", value: String(format: "%.1f%%", info.healthPercentage), highlight: true)
                            if info.designCapacityMah > 0 {
                                DataRow(label: "Design Capacity", value: "\(info.designCapacityMah) mAh")
                            }
                            if info.fullChargeCapacityMah > 0 {
                                DataRow(label: "Full Charge Cap.", value: "\(info.fullChargeCapacityMah) mAh")
                            }
                            if info.nominalChargeCapacityMah > 0 {
                                DataRow(label: "Nominal Cap.", value: "\(info.nominalChargeCapacityMah) mAh")
                            }
                            DataRow(label: "Cycle Count", value: "\(info.cycleCount) of \(info.designCycleCount)")
                            if info.voltageVolts > 0 {
                                DataRow(label: "Battery Voltage", value: String(format: "%.3f V", info.voltageVolts))
                            }
                            if info.amperageMilliAmps != 0 {
                                DataRow(label: "Current Flow", value: "\(info.amperageMilliAmps) mA")
                            }
                            if info.batteryPowerWatts > 0 {
                                DataRow(label: "Power Flow", value: String(format: "%.2f W", info.batteryPowerWatts))
                            }
                            if let temp = info.temperatureCelsius {
                                DataRow(label: "Temperature", value: String(format: "%.1f °C", temp))
                            }
                            if !info.deviceName.isEmpty {
                                DataRow(label: "Controller Model", value: info.deviceName)
                            }
                            if !info.serialNumber.isEmpty {
                                DataRow(label: "Battery Serial", value: info.serialNumber)
                            }
                        }
                        .padding(8)
                        .background(Color.primary.opacity(0.03))
                        .cornerRadius(7)
                    }
                }
            }
        }
        .padding(isCompact ? 12 : 16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Helpers
    private var batteryColor: Color {
        if info.isCharging { return .green }
        if info.currentPercentage > 20 { return .accentColor }
        if info.currentPercentage > 10 { return .orange }
        return .red
    }

    private var batterySymbolName: String {
        if info.isExternalConnected {
            return "bolt.batteryblock.fill"
        }
        if info.currentPercentage >= 95 { return "battery.100" }
        if info.currentPercentage >= 75 { return "battery.75" }
        if info.currentPercentage >= 50 { return "battery.50" }
        if info.currentPercentage >= 25 { return "battery.25" }
        return "battery.0"
    }

    private var chargingPillText: String {
        if info.isCharging {
            if info.adapter.inputPowerWatts > 0 {
                return String(format: "%.0fW In", info.adapter.inputPowerWatts)
            }
            return "Charging"
        }
        if info.isFullyCharged {
            return "100%"
        }
        return "AC Power"
    }
}

// MARK: - Reusable Subviews
private struct MetricChip: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(iconColor)
                Text(label)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Text(value)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(6)
        .background(Color.primary.opacity(0.04))
        .cornerRadius(6)
    }
}

private struct DataRow: View {
    let label: String
    let value: String
    var highlight: Bool = false

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 10, weight: highlight ? .bold : .medium, design: .monospaced))
                .foregroundColor(highlight ? .accentColor : .primary)
                .lineLimit(1)
        }
    }
}
