import SwiftUI

// MARK: - Liquid glass building blocks

/// A material surface with a subtle tint, highlight, rim, and depth. It is deliberately
/// restrained: glass should clarify hierarchy, not compete with the map or the data.
public struct LiquidGlassCard: ViewModifier {
    public var tint: Color
    public var radius: CGFloat
    public var isEmphasized: Bool

    @Environment(\.colorScheme) private var colorScheme

    public init(
        tint: Color = Theme.Color.primary,
        radius: CGFloat = Theme.Radius.card,
        isEmphasized: Bool = false
    ) {
        self.tint = tint
        self.radius = radius
        self.isEmphasized = isEmphasized
    }

    public func body(content: Content) -> some View {
        content
            .background {
                let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
                ZStack {
                    shape.fill(.ultraThinMaterial)
                    shape.fill(
                        LinearGradient(
                            colors: [
                                tint.opacity(isEmphasized ? 0.20 : 0.11),
                                Color.white.opacity(colorScheme == .dark ? 0.04 : 0.22),
                                tint.opacity(0.035)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    shape.fill(
                        LinearGradient(
                            colors: [.white.opacity(colorScheme == .dark ? 0.14 : 0.50), .clear],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
                    .padding(1)
                }
                .clipShape(shape)
                .overlay {
                    shape.stroke(
                        LinearGradient(
                            colors: [.white.opacity(colorScheme == .dark ? 0.35 : 0.82), tint.opacity(isEmphasized ? 0.42 : 0.18), .white.opacity(0.12)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                }
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.22 : 0.10), radius: isEmphasized ? 20 : 14, x: 0, y: isEmphasized ? 10 : 6)
                .shadow(color: tint.opacity(isEmphasized ? 0.18 : 0.05), radius: isEmphasized ? 18 : 8, x: 0, y: 3)
            }
    }
}

public extension View {
    func liquidGlassCard(
        tint: Color = Theme.Color.primary,
        radius: CGFloat = Theme.Radius.card,
        isEmphasized: Bool = false
    ) -> some View {
        modifier(LiquidGlassCard(tint: tint, radius: radius, isEmphasized: isEmphasized))
    }
}

/// Shared tactile behavior for every action surface. Pressing compresses it just enough
/// to feel physical, while active state adds visual prominence without constant motion.
public struct TactileGlassButtonStyle: ButtonStyle {
    public var isActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(isActive: Bool = false) {
        self.isActive = isActive
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.965 : (isActive ? 1.015 : 1))
            .brightness(configuration.isPressed ? 0.025 : 0)
            .saturation(configuration.isPressed ? 1.08 : 1)
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .fill(.white.opacity(configuration.isPressed ? 0.12 : 0))
                    .allowsHitTesting(false)
            }
            .animation(reduceMotion ? .linear(duration: 0.01) : Theme.Animation.tactile, value: configuration.isPressed)
            .animation(reduceMotion ? .linear(duration: 0.01) : Theme.Animation.emphasis, value: isActive)
    }
}

/// A lightweight, native-feeling loading state for parcel and record network work.
/// It communicates progress without trapping the user in a large blocking overlay.
public struct ParcelLoadingIndicator: View {
    public var title: String
    public var subtitle: String?

    @State private var isAnimating = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(title: String = "Updating parcels", subtitle: String? = "Matching land boundaries") {
        self.title = title
        self.subtitle = subtitle
    }

    public var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            ZStack {
                Circle()
                    .stroke(Theme.Color.primary.opacity(0.16), lineWidth: 3)
                    .frame(width: 34, height: 34)
                Circle()
                    .trim(from: 0.10, to: 0.72)
                    .stroke(Theme.brandGradient, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 34, height: 34)
                    .rotationEffect(.degrees(isAnimating ? 360 : 0))
                Circle()
                    .fill(Theme.Color.primary)
                    .frame(width: 6, height: 6)
                    .scaleEffect(isAnimating ? 0.72 : 1.18)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(Theme.Typography.captionMedium.weight(.bold))
                    .foregroundStyle(Theme.Color.primaryText)
                if let subtitle {
                    Text(subtitle)
                        .font(Theme.Typography.subcaption)
                        .foregroundStyle(Theme.Color.secondaryText)
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, Theme.Spacing.xs)
        .liquidGlassCard(tint: Theme.Color.primary, radius: Theme.Radius.pill, isEmphasized: true)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
                isAnimating = true
            }
        }
    }
}

/// Ambient visual depth for full-screen sheets. There are no image assets to manage and
/// no constantly moving content, so it remains elegant on lower-power devices.
public struct AppAtmosphereBackground: View {
    public var body: some View {
        ZStack {
            LinearGradient(
                colors: [Theme.Color.canvasTop, Theme.Color.canvasBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Circle()
                .fill(Theme.Color.primary.opacity(0.16))
                .frame(width: 360, height: 360)
                .blur(radius: 38)
                .offset(x: 150, y: -250)
            Circle()
                .fill(Theme.Color.mint.opacity(0.13))
                .frame(width: 300, height: 300)
                .blur(radius: 42)
                .offset(x: -150, y: 330)
        }
        .ignoresSafeArea()
    }
}
