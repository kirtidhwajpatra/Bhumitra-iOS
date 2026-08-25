import SwiftUI
import UIKit

/// Central Design System for MyBhoomi iOS.
/// Standardized with the Google Sans typography family across all UI elements.
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
        public static let success = SwiftUI.Color(red: 52/255, green: 199/255, blue: 89/255) // Emerald Green
        public static let warning = SwiftUI.Color(red: 255/255, green: 149/255, blue: 0/255) // Radiant Orange
        public static let error = SwiftUI.Color(red: 255/255, green: 59/255, blue: 48/255)   // Crimson Red
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
    
    // MARK: - Semantic Typography (Google Sans Unified System)
    public enum Typography {
        // --- Display & Heading Tokens ---
        public static let displayCondensed = Font.googleSans(size: 34, weight: .bold)
        public static let largeTitleCondensed = Font.googleSans(size: 28, weight: .bold)
        public static let titleCondensed = Font.googleSans(size: 22, weight: .bold)
        public static let sectionTitleCondensed = Font.googleSans(size: 18, weight: .bold)
        public static let headlineCondensed = Font.googleSans(size: 16, weight: .semibold)
        public static let badgeCondensed = Font.googleSans(size: 12, weight: .bold)
        public static let pillLabelCondensed = Font.googleSans(size: 11, weight: .bold)
        public static let pillValueCondensed = Font.googleSans(size: 15, weight: .bold)
        
        // --- Standard Reading & Action Tokens ---
        public static let button = Font.googleSans(size: 15.5, weight: .semibold)
        public static let buttonBold = Font.googleSans(size: 16, weight: .bold)
        public static let display = Font.googleSans(size: 34, weight: .bold)
        public static let largeTitle = Font.googleSans(size: 30, weight: .bold)
        public static let title = Font.googleSans(size: 24, weight: .bold)
        public static let sectionTitle = Font.googleSans(size: 20, weight: .semibold)
        public static let primaryBody = Font.googleSans(size: 17, weight: .regular)
        public static let primaryBodyBold = Font.googleSans(size: 17, weight: .semibold)
        public static let secondaryBody = Font.googleSans(size: 15, weight: .regular)
        public static let secondaryBodyMedium = Font.googleSans(size: 15, weight: .medium)
        public static let caption = Font.googleSans(size: 13, weight: .regular)
        public static let captionMedium = Font.googleSans(size: 13, weight: .medium)
        public static let subcaption = Font.googleSans(size: 11, weight: .regular)
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

// MARK: - Google Sans Font Extensions

public enum GoogleSansWeight {
    case regular
    case medium
    case semiBold
    case bold
    case italic
    case mediumItalic
    case semiBoldItalic
    case boldItalic
    
    public var fontName: String {
        switch self {
        case .regular: return "GoogleSans-Regular"
        case .medium: return "GoogleSans-Medium"
        case .semiBold: return "GoogleSans-SemiBold"
        case .bold: return "GoogleSans-Bold"
        case .italic: return "GoogleSans-Italic"
        case .mediumItalic: return "GoogleSans-MediumItalic"
        case .semiBoldItalic: return "GoogleSans-SemiBoldItalic"
        case .boldItalic: return "GoogleSans-BoldItalic"
        }
    }
}

extension Font {
    /// Returns a SwiftUI Font using the official Google Sans font family with dynamic fallback.
    public static func googleSans(size: CGFloat, weight: Font.Weight = .regular, italic: Bool = false) -> Font {
        let name: String
        switch (weight, italic) {
        case (.bold, false), (.heavy, false), (.black, false):
            name = "GoogleSans-Bold"
        case (.bold, true), (.heavy, true), (.black, true):
            name = "GoogleSans-BoldItalic"
        case (.semibold, false):
            name = "GoogleSans-SemiBold"
        case (.semibold, true):
            name = "GoogleSans-SemiBoldItalic"
        case (.medium, false):
            name = "GoogleSans-Medium"
        case (.medium, true):
            name = "GoogleSans-MediumItalic"
        case (_, true):
            name = "GoogleSans-Italic"
        default:
            name = "GoogleSans-Regular"
        }
        return Font.custom(name, size: size)
    }
    
    public static func googleSans(_ weight: GoogleSansWeight, size: CGFloat) -> Font {
        return Font.custom(weight.fontName, size: size)
    }
}

extension UIFont {
    /// Returns a UIKit UIFont using the official Google Sans font family with dynamic fallback.
    public static func googleSans(size: CGFloat, weight: UIFont.Weight = .regular, italic: Bool = false) -> UIFont {
        let name: String
        switch (weight, italic) {
        case (.bold, false), (.heavy, false), (.black, false):
            name = "GoogleSans-Bold"
        case (.bold, true), (.heavy, true), (.black, true):
            name = "GoogleSans-BoldItalic"
        case (.semibold, false):
            name = "GoogleSans-SemiBold"
        case (.semibold, true):
            name = "GoogleSans-SemiBoldItalic"
        case (.medium, false):
            name = "GoogleSans-Medium"
        case (.medium, true):
            name = "GoogleSans-MediumItalic"
        case (_, true):
            name = "GoogleSans-Italic"
        default:
            name = "GoogleSans-Regular"
        }
        return UIFont(name: name, size: size) ?? UIFont.systemFont(ofSize: size, weight: weight)
    }
}

// MARK: - View Extension for Google Sans

extension View {
    /// Convenience modifier to apply Google Sans font styling.
    public func googleSans(size: CGFloat, weight: Font.Weight = .regular, italic: Bool = false) -> some View {
        self.font(.googleSans(size: size, weight: weight, italic: italic))
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
