import SwiftUI

// MARK: - Apple Control Center Style Capsule Slider
/// A tactile, full-height capsule slider inspired by macOS Control Center.
/// Features continuous horizontal drag scrubbing, leading dynamic iconography,
/// and trailing monospaced readouts with accessible contrast adaptation.
public struct OrbitCapsuleSlider: View {
    let icon: String
    let label: String
    @Binding var value: Float
    let tint: Color
    var isEnabled: Bool = true
    var onCommit: () -> Void = {}

    @State private var isDragging: Bool = false
    @State private var isHovering: Bool = false

    public init(
        icon: String,
        label: String,
        value: Binding<Float>,
        tint: Color = .accentColor,
        isEnabled: Bool = true,
        onCommit: @escaping () -> Void = {}
    ) {
        self.icon = icon
        self.label = label
        self._value = value
        self.tint = tint
        self.isEnabled = isEnabled
        self.onCommit = onCommit
    }

    public var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let clampedVal = max(0.0, min(1.0, CGFloat(value)))
            let fillWidth = max(0, min(width, width * clampedVal))

            ZStack(alignment: .leading) {
                // Background Track
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.8))

                // Active Fill Layer
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [tint.opacity(0.85), tint],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: fillWidth)

                // Liquid Glass Transient Interaction Sheen (macOS Golden Gate HIG)
                if isDragging || isHovering {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.18),
                                    Color.white.opacity(0.04),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }

                // Foreground Content & Accessibility Labels
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(clampedVal > 0.12 ? .white : .primary)
                        .frame(width: 18)

                    Text(label)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(clampedVal > 0.45 ? .white : .primary)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    Text("\(Int(round(value * 100)))%")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(clampedVal > 0.85 ? .white : .secondary)
                }
                .padding(.horizontal, 10)
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(
                        isDragging ? tint.opacity(0.6) : (isHovering ? Color.primary.opacity(0.12) : Color.primary.opacity(0.06)),
                        lineWidth: isDragging ? 1.5 : 1
                    )
            )
            .contentShape(Rectangle())
            .onHover { isHovering = $0 }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        guard isEnabled else { return }
                        isDragging = true
                        let percent = Float(max(0.0, min(1.0, gesture.location.x / width)))
                        value = percent
                        onCommit()
                    }
                    .onEnded { _ in
                        isDragging = false
                        onCommit()
                    }
            )
        }
        .frame(height: 28)
        .opacity(isEnabled ? 1.0 : 0.45)
    }
}

// MARK: - Apple Style Kelvin Temperature Slider
/// A specialized capsule slider with a warm-to-cool Kelvin temperature gradient.
public struct OrbitKelvinSlider: View {
    @Binding var kelvin: Int
    var isEnabled: Bool = true
    var onCommit: () -> Void = {}

    private let minKelvin: Float = 2200
    private let maxKelvin: Float = 6500

    @State private var isDragging: Bool = false
    @State private var isHovering: Bool = false

    public init(kelvin: Binding<Int>, isEnabled: Bool = true, onCommit: @escaping () -> Void = {}) {
        self._kelvin = kelvin
        self.isEnabled = isEnabled
        self.onCommit = onCommit
    }

    private var normalizedProgress: CGFloat {
        let val = Float(kelvin)
        return CGFloat(max(0.0, min(1.0, (val - minKelvin) / (maxKelvin - minKelvin))))
    }

    public var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let thumbX = max(10, min(width - 10, width * normalizedProgress))

            ZStack(alignment: .leading) {
                // Kelvin Spectrum Gradient Track
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: Color(red: 1.0, green: 0.65, blue: 0.3), location: 0.0), // 2200K Warm Candlelight
                                .init(color: Color(red: 1.0, green: 0.82, blue: 0.55), location: 0.25), // 2700K Warm White
                                .init(color: Color(red: 1.0, green: 0.95, blue: 0.85), location: 0.5), // 4000K Natural White
                                .init(color: Color(red: 0.85, green: 0.92, blue: 1.0), location: 0.75), // 5500K Daylight
                                .init(color: Color(red: 0.68, green: 0.84, blue: 1.0), location: 1.0)  // 6500K Cool White
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                // Dynamic Thumb Marker
                Circle()
                    .fill(Color.white)
                    .frame(width: 18, height: 18)
                    .shadow(color: Color.black.opacity(0.25), radius: 3, x: 0, y: 1)
                    .overlay(
                        Circle().stroke(Color.primary.opacity(0.15), lineWidth: 1)
                    )
                    .position(x: thumbX, y: geo.size.height / 2)
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(
                        isDragging ? Color.primary.opacity(0.3) : (isHovering ? Color.primary.opacity(0.15) : Color.primary.opacity(0.08)),
                        lineWidth: 1
                    )
            )
            .contentShape(Rectangle())
            .onHover { isHovering = $0 }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        guard isEnabled else { return }
                        isDragging = true
                        let pct = Float(max(0.0, min(1.0, gesture.location.x / width)))
                        let newKelvin = Int(round(minKelvin + pct * (maxKelvin - minKelvin)))
                        kelvin = newKelvin
                        onCommit()
                    }
                    .onEnded { _ in
                        isDragging = false
                        onCommit()
                    }
            )
        }
        .frame(height: 24)
        .opacity(isEnabled ? 1.0 : 0.45)
    }
}

// MARK: - Legacy Compatible ControlSlider Adapter
public struct ControlSlider: View {
    let icon: String
    let label: String
    @Binding var value: Float
    let onCommit: () -> Void

    public init(
        icon: String,
        label: String,
        value: Binding<Float>,
        onCommit: @escaping () -> Void = {}
    ) {
        self.icon = icon
        self.label = label
        self._value = value
        self.onCommit = onCommit
    }

    public var body: some View {
        OrbitCapsuleSlider(
            icon: icon,
            label: label,
            value: $value,
            tint: .accentColor,
            onCommit: onCommit
        )
    }
}
