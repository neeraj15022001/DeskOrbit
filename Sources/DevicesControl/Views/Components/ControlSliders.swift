import SwiftUI

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
        VStack(spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int(value * 100))%")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(.primary)
            }

            Slider(value: Binding(
                get: { Double(value) },
                set: {
                    value = Float($0)
                    onCommit()
                }
            ), in: 0.0...1.0)
            .controlSize(.small)
        }
    }
}
