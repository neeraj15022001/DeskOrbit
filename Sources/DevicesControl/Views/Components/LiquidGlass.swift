import SwiftUI
import AppKit

// MARK: - Liquid Glass Visual Token System (macOS 27 / Golden Gate)
/// Implements Apple's Liquid Glass material guidelines (materials.md & liquid-glass.md):
/// - Functional floating layer with backdrop blur, luminosity balancing, and edge specular highlights.
/// - Graceful fallback to opaque surfaces when Reduce Transparency is active.
/// - Enhanced borders when Increase Contrast is active.
/// - GlassProminent styling for primary actions.

public enum LiquidGlassVariant {
    case regular  // Balanced blur & luminosity for text-heavy functional layers (sidebars, toolbars, popovers)
    case clear    // High translucency for floating media controls
    case tinted(Color) // Subtle accent tint for prominent controls
}

public struct LiquidGlassModifier: ViewModifier {
    var variant: LiquidGlassVariant = .regular
    var cornerRadius: CGFloat = 12
    var isInteractive: Bool = false

    @State private var isHovered: Bool = false
    @State private var reduceTransparency: Bool = NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
    @State private var increaseContrast: Bool = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast

    public func body(content: Content) -> some View {
        content
            .background(
                Group {
                    if reduceTransparency {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(Color(NSColor.windowBackgroundColor))
                    } else {
                        ZStack {
                            // Native macOS Visual Effect Vibrancy
                            VisualEffectView(
                                material: materialForVariant,
                                blendingMode: .behindWindow
                            )

                            // Subtle specular tint layer
                            switch variant {
                            case .tinted(let tintColor):
                                tintColor.opacity(0.12)
                            case .clear:
                                Color.primary.opacity(0.03)
                            case .regular:
                                Color.primary.opacity(0.04)
                            }

                            // Interactive hover glow
                            if isInteractive && isHovered {
                                Color.primary.opacity(0.05)
                            }
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        strokeGradient,
                        lineWidth: increaseContrast ? 1.5 : (isHovered && isInteractive ? 1.2 : 0.8)
                    )
            )
            .onHover { isHovered = $0 }
            .onReceive(NotificationCenter.default.publisher(for: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification)) { _ in
                reduceTransparency = NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
                increaseContrast = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
            }
    }

    private var materialForVariant: NSVisualEffectView.Material {
        switch variant {
        case .regular:
            return .headerView
        case .clear:
            return .sidebar
        case .tinted:
            return .popover
        }
    }

    private var strokeGradient: LinearGradient {
        if increaseContrast {
            return LinearGradient(
                colors: [Color.primary.opacity(0.4), Color.primary.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        // Apple Liquid Glass specular reflection: bright edge on top-left, subtle shadow on bottom-right
        return LinearGradient(
            colors: [
                Color.white.opacity(0.28),
                Color.white.opacity(0.08),
                Color.black.opacity(0.05)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

public extension View {
    func liquidGlass(
        _ variant: LiquidGlassVariant = .regular,
        cornerRadius: CGFloat = 12,
        isInteractive: Bool = false
    ) -> some View {
        self.modifier(LiquidGlassModifier(variant: variant, cornerRadius: cornerRadius, isInteractive: isInteractive))
    }
}

// MARK: - Apple Style Liquid Glass Button
public struct LiquidGlassButton<Label: View>: View {
    let action: () -> Void
    var isProminent: Bool = false
    var tint: Color = .accentColor
    @ViewBuilder let label: () -> Label

    @State private var isHovered: Bool = false
    @State private var isPressed: Bool = false

    public init(
        action: @escaping () -> Void,
        isProminent: Bool = false,
        tint: Color = .accentColor,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.action = action
        self.isProminent = isProminent
        self.tint = tint
        self.label = label
    }

    public var body: some View {
        Button(action: action) {
            label()
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            ZStack {
                if isProminent {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [tint, tint.opacity(0.85)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: tint.opacity(0.35), radius: 4, x: 0, y: 2)
                } else {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(NSColor.controlBackgroundColor).opacity(isHovered ? 0.9 : 0.6))
                }
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(isProminent ? 0.35 : 0.22),
                            Color.black.opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .foregroundColor(isProminent ? .white : .primary)
        .onHover { isHovered = $0 }
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .animation(.easeOut(duration: 0.12), value: isHovered)
    }
}
