import SwiftUI

public struct DeviceCardView<Content: View>: View {
    let title: String
    let subtitle: String
    let iconName: String
    let iconColor: Color
    let badgeText: String?
    let badgeColor: Color
    @ViewBuilder let content: () -> Content

    @State private var isHovered: Bool = false

    public init(
        title: String,
        subtitle: String,
        iconName: String,
        iconColor: Color = .accentColor,
        badgeText: String? = nil,
        badgeColor: Color = .secondary,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.iconName = iconName
        self.iconColor = iconColor
        self.badgeText = badgeText
        self.badgeColor = badgeColor
        self.content = content
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header Row
            HStack(alignment: .center, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(iconColor.opacity(0.14))
                        .frame(width: 38, height: 38)
                    Image(systemName: iconName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(iconColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if let badge = badgeText {
                    Text(badge)
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(badgeColor.opacity(0.12))
                        .foregroundColor(badgeColor)
                        .clipShape(Capsule())
                }
            }

            // Card Content
            content()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: Color.black.opacity(isHovered ? 0.08 : 0.03), radius: isHovered ? 6 : 2, x: 0, y: isHovered ? 2 : 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    isHovered ? Color.primary.opacity(0.12) : Color.primary.opacity(0.06),
                    lineWidth: 1
                )
        )
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.15), value: isHovered)
    }
}
