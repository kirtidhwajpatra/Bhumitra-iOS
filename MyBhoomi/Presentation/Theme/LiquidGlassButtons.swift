import SwiftUI
import UIKit

// MARK: - 1. Bhumitra Native Liquid Glass Buttons (From LiquidGlassButtonsDemo)

/// Primary Pill Button from LiquidGlassButtonsDemo Section 10
public struct LiquidPrimaryButton: View {
    public let title: String
    public let icon: String?
    public let isEnabled: Bool
    public let height: CGFloat
    public let action: () -> Void
    
    public init(
        _ title: String = "Load plots",
        icon: String? = nil,
        isEnabled: Bool = true,
        height: CGFloat = Theme.ButtonHeight.cta,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.isEnabled = isEnabled
        self.height = height
        self.action = action
    }
    
    public init(
        title: String,
        icon: String? = nil,
        isEnabled: Bool = true,
        height: CGFloat = Theme.ButtonHeight.cta,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.isEnabled = isEnabled
        self.height = height
        self.action = action
    }
    
    public var body: some View {
        Button {
            guard isEnabled else { return }
            action()
        } label: {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                }
                Text(title)
            }
            .font(.headline)
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity)
            .frame(height: height)
        }
        .buttonStyle(.glassProminent)
        .tint(.accentColor)
        .clipShape(Capsule())
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1.0 : 0.55)
    }
}

/// Secondary Action Button from LiquidGlassButtonsDemo Section 6
public struct LiquidSecondaryButton: View {
    public let title: String
    public let icon: String?
    public let isEnabled: Bool
    public let height: CGFloat
    public let action: () -> Void
    
    public init(
        _ title: String = "Cancel",
        icon: String? = nil,
        isEnabled: Bool = true,
        height: CGFloat = Theme.ButtonHeight.cta,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.isEnabled = isEnabled
        self.height = height
        self.action = action
    }
    
    public init(
        title: String,
        icon: String? = nil,
        isEnabled: Bool = true,
        height: CGFloat = Theme.ButtonHeight.cta,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.isEnabled = isEnabled
        self.height = height
        self.action = action
    }
    
    public var body: some View {
        Button {
            guard isEnabled else { return }
            action()
        } label: {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                }
                Text(title)
            }
            .font(.headline)
            .padding(.horizontal, 26)
            .frame(maxWidth: .infinity)
            .frame(height: height)
        }
        .buttonStyle(.glass)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1.0 : 0.55)
    }
}

/// Circular Glass Button from LiquidGlassButtonsDemo Section 4 & 8
public struct LiquidFABButton: View {
    public let icon: String
    public let diameter: CGFloat
    public let isProminent: Bool
    public let accessibilityLabel: String?
    public let action: () -> Void
    
    public init(
        icon: String = "plus",
        diameter: CGFloat = 64,
        isProminent: Bool = true,
        accessibilityLabel: String? = nil,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.diameter = diameter
        self.isProminent = isProminent
        self.accessibilityLabel = accessibilityLabel
        self.action = action
    }
    
    public var body: some View {
        if isProminent {
            Button {
                action()
            } label: {
                Image(systemName: icon)
                    .font(.title2.weight(.semibold))
                    .frame(width: diameter, height: diameter)
            }
            .buttonStyle(.glassProminent)
            .tint(.accentColor)
            .accessibilityLabel(accessibilityLabel ?? icon)
        } else {
            Button {
                action()
            } label: {
                Image(systemName: icon)
                    .font(.title2.weight(.semibold))
                    .frame(width: diameter, height: diameter)
            }
            .buttonStyle(.glass)
            .accessibilityLabel(accessibilityLabel ?? icon)
        }
    }
}

// MARK: - 2. Circular Liquid Glass Controls

/// Interactive Spring Press ButtonStyle for circular glass buttons
public struct CircularGlassInteractiveStyle: ButtonStyle {
    public init() {}
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Reusable Native Liquid Glass Material Treatment

public struct BhumitraLiquidGlassMaterialModifier<S: Shape>: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    public let shape: S
    public let shadowRadius: CGFloat
    public let shadowY: CGFloat
    
    public init(shape: S, shadowRadius: CGFloat = 6, shadowY: CGFloat = 2) {
        self.shape = shape
        self.shadowRadius = shadowRadius
        self.shadowY = shadowY
    }
    
    public func body(content: Content) -> some View {
        content
            .glassEffect(
                .regular.interactive(),
                in: shape
            )
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.28 : 0.08),
                radius: shadowRadius,
                x: 0,
                y: shadowY
            )
    }
}

public extension View {
    func bhumitraLiquidGlass<S: Shape>(in shape: S, shadowRadius: CGFloat = 6, shadowY: CGFloat = 2) -> some View {
        modifier(BhumitraLiquidGlassMaterialModifier(shape: shape, shadowRadius: shadowRadius, shadowY: shadowY))
    }
}

/// Generic Circular Liquid Glass Action Button
public struct LiquidGlassCircleButton<Content: View>: View {
    public let diameter: CGFloat
    public let accessibilityLabel: String?
    public let action: () -> Void
    public let content: () -> Content
    
    public init(
        diameter: CGFloat = 42,
        accessibilityLabel: String? = nil,
        action: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.diameter = diameter
        self.accessibilityLabel = accessibilityLabel
        self.action = action
        self.content = content
    }
    
    public var body: some View {
        Button {
            Theme.haptic(.light)
            action()
        } label: {
            content()
                .frame(width: diameter, height: diameter)
                .contentShape(Circle())
        }
        .buttonStyle(CircularGlassInteractiveStyle())
        .bhumitraLiquidGlass(in: Circle(), shadowRadius: 6, shadowY: 2)
        .accessibilityLabel(accessibilityLabel ?? "Action")
    }
}

/// Dedicated Circular Liquid Glass Back Button
public struct LiquidGlassBackButton: View {
    @Environment(\.colorScheme) private var colorScheme
    public let diameter: CGFloat
    public let iconSize: CGFloat
    public let tintColor: Color?
    public let accessibilityLabel: String
    public let action: () -> Void
    
    public init(
        diameter: CGFloat = 42,
        iconSize: CGFloat = 16,
        tintColor: Color? = nil,
        accessibilityLabel: String = "Back",
        action: @escaping () -> Void
    ) {
        self.diameter = diameter
        self.iconSize = iconSize
        self.tintColor = tintColor
        self.accessibilityLabel = accessibilityLabel
        self.action = action
    }
    
    private var defaultIconColor: Color {
        tintColor ?? Theme.Color.bhumitraPrimaryText
    }
    
    public var body: some View {
        LiquidGlassCircleButton(
            diameter: diameter,
            accessibilityLabel: accessibilityLabel,
            action: action
        ) {
            Image(systemName: "chevron.left")
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundColor(defaultIconColor)
        }
    }
}

/// Dedicated Circular Liquid Glass Close / Cancel Button
public struct LiquidGlassCloseButton: View {
    @Environment(\.colorScheme) private var colorScheme
    public let diameter: CGFloat
    public let iconSize: CGFloat
    public let tintColor: Color?
    public let accessibilityLabel: String
    public let action: () -> Void
    
    public init(
        diameter: CGFloat = 38,
        iconSize: CGFloat = 13.5,
        tintColor: Color? = nil,
        accessibilityLabel: String = "Close",
        action: @escaping () -> Void
    ) {
        self.diameter = diameter
        self.iconSize = iconSize
        self.tintColor = tintColor
        self.accessibilityLabel = accessibilityLabel
        self.action = action
    }
    
    private var defaultIconColor: Color {
        tintColor ?? Theme.Color.bhumitraPrimaryText
    }
    
    public var body: some View {
        LiquidGlassCircleButton(
            diameter: diameter,
            accessibilityLabel: accessibilityLabel,
            action: action
        ) {
            Image(systemName: "xmark")
                .font(.system(size: iconSize, weight: .bold))
                .foregroundColor(defaultIconColor)
        }
    }
}

// MARK: - 4. Canonical Primary CTA (App-Wide Standard)
//
// The single source of truth for primary call-to-action buttons, matching the
// subscription page reference: glassProminent + brand tint + capsule + glow.
// Use this everywhere a full-width primary action is needed.

public struct PrimaryCTAButton: View {
    public let title: String
    public let systemImage: String?
    public let isLoading: Bool
    public let loadingTitle: String?
    public let isEnabled: Bool
    public let showsGlowWhenDisabled: Bool
    public let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    public init(
        _ title: String,
        systemImage: String? = nil,
        isLoading: Bool = false,
        loadingTitle: String? = nil,
        isEnabled: Bool = true,
        showsGlowWhenDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.isLoading = isLoading
        self.loadingTitle = loadingTitle
        self.isEnabled = isEnabled
        self.showsGlowWhenDisabled = showsGlowWhenDisabled
        self.action = action
    }

    public var body: some View {
        Button {
            guard isEnabled, !isLoading else { return }
            action()
        } label: {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                    if let loadingTitle = loadingTitle {
                        Text(loadingTitle)
                    }
                } else {
                    Text(title)
                    if let systemImage = systemImage {
                        Image(systemName: systemImage)
                            .font(.system(size: 15, weight: .semibold))
                    }
                }
            }
        }
        // Shared CTA style: same size, type, fill and press feedback everywhere.
        .buttonStyle(.primaryCTA)
        .disabled(!isEnabled)
        // Busy keeps the brand fill (not the disabled grey) but ignores taps.
        .allowsHitTesting(!isLoading)
        .animation(.easeOut(duration: 0.2), value: isEnabled)
    }
}

// MARK: - 3. Convenient Typealiases

public typealias LiquidEmeraldButton = LiquidPrimaryButton
public typealias LiquidMintButton = LiquidSecondaryButton
public typealias LiquidCircularButton = LiquidFABButton
public typealias LiquidBackButton = LiquidGlassBackButton
public typealias LiquidCloseButton = LiquidGlassCloseButton
