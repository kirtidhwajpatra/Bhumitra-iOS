import SwiftUI
import UIKit

/// Central Design System for MyBhoomi iOS.
/// Provides semantic tokens for Color, Typography, Spacing, Corner Radius, Shadow, Animation, and Controls.
public enum Theme {
    // MARK: - Semantic Colors
    public enum Color {
        /// A saturated azure gives geographic controls a clear, contemporary focal point.
        public static let primary = SwiftUI.Color(red: 0/255, green: 113/255, blue: 227/255)
        public static let primaryLight = primary.opacity(0.10)
        public static let primaryPressed = SwiftUI.Color(red: 0/255, green: 88/255, blue: 190/255)
        public static let primaryDisabled = primary.opacity(0.40)
        public static let mint = SwiftUI.Color(red: 27/255, green: 184/255, blue: 148/255)
        public static let indigo = SwiftUI.Color(red: 85/255, green: 89/255, blue: 214/255)
        public static let canvasTop = SwiftUI.Color(red: 0.94, green: 0.97, blue: 1.0)
        public static let canvasBottom = SwiftUI.Color(red: 0.98, green: 0.99, blue: 1.0)
        
        /// Backgrounds & Surfaces
        public static let background = canvasBottom
        public static let surface = SwiftUI.Color.white
        public static let secondarySurface = SwiftUI.Color.black.opacity(0.04)
        public static let surfaceElevated = SwiftUI.Color.white.opacity(0.94)
        
        /// Text Hierarchy
        public static let primaryText = SwiftUI.Color(red: 0.07, green: 0.10, blue: 0.16)
        public static let secondaryText = SwiftUI.Color(red: 0.25, green: 0.30, blue: 0.38).opacity(0.80)
        public static let tertiaryText = SwiftUI.Color(red: 0.25, green: 0.30, blue: 0.38).opacity(0.52)
        
        /// Dividers & Borders
        public static let separator = SwiftUI.Color.black.opacity(0.06)
        public static let border = SwiftUI.Color.black.opacity(0.05)
        
        /// Semantic Status Indicators
        public static let success = SwiftUI.Color(red: 52/255, green: 199/255, blue: 89/255) // Apple Green
        public static let warning = SwiftUI.Color(red: 255/255, green: 149/255, blue: 0/255) // Apple Orange
        public static let error = SwiftUI.Color(red: 255/255, green: 59/255, blue: 48/255)   // Apple Red
    }
    
    // MARK: - Legacy Color Aliases (Backwards Compatibility)
    public static let myBhoomiBlue = Color.primary
    public static let primary = Color.primary
    public static let accent = SwiftUI.Color(red: 100/255, green: 50/255, blue: 240/255)
    public static let surface = Color.surface
    public static let card = SwiftUI.Color.white
    public static let emeraldGreen = Color.success
    public static let landGreen = Color.success
    public static let neonPurple = SwiftUI.Color(red: 191/255, green: 64/255, blue: 255/255)
    public static let neonGreen = SwiftUI.Color(red: 57/255, green: 255/255, blue: 20/255)
    public static let neonYellow = SwiftUI.Color(red: 255/255, green: 255/255, blue: 0/255)
    
    public static let brandGradient = LinearGradient(
        colors: [Color.primary, Color.primaryPressed],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // MARK: - Spacing Scale (8pt Grid)
    public enum Spacing {
        public static let xxs: CGFloat = 4
        public static let xs: CGFloat = 8
        public static let sm: CGFloat = 12
        public static let md: CGFloat = 16
        public static let lg: CGFloat = 20
        public static let xl: CGFloat = 24
        public static let xxl: CGFloat = 32
        public static let section: CGFloat = 40
    }
    
    // MARK: - Corner Radii
    public enum Radius {
        public static let small: CGFloat = 12
        public static let medium: CGFloat = 16
        public static let card: CGFloat = 22
        public static let large: CGFloat = 26
        public static let pill: CGFloat = 999
    }
    
    // MARK: - Legacy Geometry Aliases
    public static let cornerRadiusLarge: CGFloat = Radius.large
    public static let cornerRadiusMedium: CGFloat = Radius.medium
    public static let paddingStandard: CGFloat = Spacing.lg
    
    // MARK: - Semantic Typography (Paired Condensed Display & Standard Body System)
    public enum Typography {
        // --- Standard SF Pro Typography Tokens ---
        public static let displayCondensed = Font.system(size: 34, weight: .bold, design: .default)
        public static let largeTitleCondensed = Font.system(size: 28, weight: .bold, design: .default)
        public static let titleCondensed = Font.system(size: 22, weight: .bold, design: .default)
        public static let sectionTitleCondensed = Font.system(size: 18, weight: .bold, design: .default)
        public static let headlineCondensed = Font.system(size: 16, weight: .semibold, design: .default)
        public static let badgeCondensed = Font.system(size: 12, weight: .bold, design: .default)
        public static let pillLabelCondensed = Font.system(size: 11, weight: .bold, design: .default)
        public static let pillValueCondensed = Font.system(size: 15, weight: .bold, design: .default)
        
        // --- Standard Natural Reading & Action Tokens ---
        public static let button = Font.system(size: 15.5, weight: .semibold, design: .default)
        public static let buttonBold = Font.system(size: 16, weight: .bold, design: .default)
        public static let display = Font.system(size: 34, weight: .bold, design: .rounded)
        public static let largeTitle = Font.system(size: 30, weight: .bold, design: .rounded)
        public static let title = Font.system(size: 24, weight: .bold, design: .rounded)
        public static let sectionTitle = Font.system(size: 20, weight: .semibold, design: .rounded)
        public static let primaryBody = Font.system(size: 17, weight: .regular, design: .default)
        public static let primaryBodyBold = Font.system(size: 17, weight: .semibold, design: .default)
        public static let secondaryBody = Font.system(size: 15, weight: .regular, design: .default)
        public static let secondaryBodyMedium = Font.system(size: 15, weight: .medium, design: .default)
        public static let caption = Font.system(size: 13, weight: .regular, design: .default)
        public static let captionMedium = Font.system(size: 13, weight: .medium, design: .default)
        public static let subcaption = Font.system(size: 11, weight: .regular, design: .default)
    }
    
    // MARK: - Animation Presets
    public enum Animation {
        public static let micro = SwiftUI.Animation.easeOut(duration: 0.18)
        public static let standard = SwiftUI.Animation.easeOut(duration: 0.28)
        public static let spring = SwiftUI.Animation.spring(response: 0.38, dampingFraction: 0.82)
        public static let tactile = SwiftUI.Animation.spring(response: 0.24, dampingFraction: 0.72, blendDuration: 0)
        public static let emphasis = SwiftUI.Animation.spring(response: 0.42, dampingFraction: 0.78, blendDuration: 0.08)
    }
    
    // MARK: - Shadows
    public enum Shadow {
        public static let subtle = SwiftUI.Color.black.opacity(0.04)
        public static let card = SwiftUI.Color.black.opacity(0.06)
        public static let floating = SwiftUI.Color.black.opacity(0.12)
        public static let primaryGlow = Color.primary.opacity(0.35)
    }
    
    public static func shadowSoft(_ color: SwiftUI.Color = .black) -> some View {
        EmptyView().shadow(color: color.opacity(0.06), radius: 12, x: 0, y: 4)
    }
    
    // MARK: - Haptics
    public static func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
    
    public static func selectionHaptic() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }
    
    public static func notificationHaptic(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }
}

// MARK: - Global Helper Aliases
public func hapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
    Theme.haptic(style)
}

public let primaryPurple = Theme.primary

// MARK: - Standard Button Styles

public struct ScaledButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.965 : 1.0)
            .brightness(configuration.isPressed ? 0.02 : 0)
            .saturation(configuration.isPressed ? 1.06 : 1)
            .animation(reduceMotion ? .linear(duration: 0.01) : Theme.Animation.tactile, value: configuration.isPressed)
    }
}

public struct PrimaryPillButtonStyle: ButtonStyle {
    public let isEnabled: Bool
    public let isLoading: Bool
    
    public init(isEnabled: Bool = true, isLoading: Bool = false) {
        self.isEnabled = isEnabled
        self.isLoading = isLoading
    }
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Typography.primaryBodyBold)
            .foregroundColor(.white)
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.vertical, Theme.Spacing.sm)
            .background(
                Capsule()
                    .fill(isEnabled ? (configuration.isPressed ? Theme.Color.primaryPressed : Theme.Color.primary) : Theme.Color.primaryDisabled)
                    .shadow(color: isEnabled ? Theme.Shadow.primaryGlow : .clear, radius: 10, x: 0, y: 3)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(Theme.Animation.micro, value: configuration.isPressed)
    }
}
