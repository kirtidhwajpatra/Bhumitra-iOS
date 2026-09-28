import SwiftUI
import UIKit

/// Central Design System for MyBhoomi iOS.
/// Standardized with the Google Sans typography family across all UI elements.
public enum Theme {
    // MARK: - Semantic Colors (Dynamic Light & Dark Mode)
    public enum Color {
        public static func dynamic(light: UIColor, dark: UIColor) -> SwiftUI.Color {
            SwiftUI.Color(UIColor { trait in
                trait.userInterfaceStyle == .dark ? dark : light
            })
        }
        
        public static func dynamic(light: SwiftUI.Color, dark: SwiftUI.Color) -> SwiftUI.Color {
            SwiftUI.Color(UIColor { trait in
                trait.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
            })
        }
        
        /// Brand Colors
        public static let bhumitraPrimary = dynamic(
            light: UIColor(red: 118/255, green: 0/255, blue: 255/255, alpha: 1.0),
            dark: UIColor(red: 142/255, green: 50/255, blue: 255/255, alpha: 1.0)
        )
        public static let bhumitraPrimaryPressed = dynamic(
            light: UIColor(red: 95/255, green: 0/255, blue: 204/255, alpha: 1.0),
            dark: UIColor(red: 118/255, green: 0/255, blue: 255/255, alpha: 1.0)
        )
        public static let bhumitraTint = dynamic(
            light: UIColor(red: 118/255, green: 0/255, blue: 255/255, alpha: 0.10),
            dark: UIColor(red: 142/255, green: 50/255, blue: 255/255, alpha: 0.18)
        )
        public static let bhumitraSelection = dynamic(
            light: UIColor(red: 118/255, green: 0/255, blue: 255/255, alpha: 0.12),
            dark: UIColor(red: 142/255, green: 50/255, blue: 255/255, alpha: 0.22)
        )
        public static let bhumitraDisabled = dynamic(
            light: UIColor(white: 0.0, alpha: 0.28),
            dark: UIColor(white: 1.0, alpha: 0.28)
        )
        public static let bhumitraOverlay = dynamic(
            light: UIColor(white: 0.0, alpha: 0.35),
            dark: UIColor(white: 0.0, alpha: 0.60)
        )
        
        /// Dynamic Canvas & Background
        public static let bhumitraBackground = dynamic(
            light: UIColor(red: 247/255, green: 248/255, blue: 250/255, alpha: 1.0),
            dark: UIColor(red: 13/255, green: 15/255, blue: 18/255, alpha: 1.0)
        )
        public static let canvasTop = dynamic(
            light: UIColor(red: 0.94, green: 0.97, blue: 1.0, alpha: 1.0),
            dark: UIColor(red: 0.05, green: 0.07, blue: 0.10, alpha: 1.0)
        )
        public static let canvasBottom = dynamic(
            light: UIColor(red: 0.98, green: 0.99, blue: 1.0, alpha: 1.0),
            dark: UIColor(red: 0.08, green: 0.10, blue: 0.14, alpha: 1.0)
        )
        
        /// Dynamic Surfaces
        public static let bhumitraSurface = dynamic(
            light: UIColor.white,
            dark: UIColor(red: 23/255, green: 26/255, blue: 33/255, alpha: 1.0)
        )
        public static let bhumitraSurfaceSecondary = dynamic(
            light: UIColor(red: 242/255, green: 244/255, blue: 247/255, alpha: 1.0),
            dark: UIColor(red: 32/255, green: 36/255, blue: 45/255, alpha: 1.0)
        )
        public static let bhumitraElevatedSurface = dynamic(
            light: UIColor(white: 1.0, alpha: 0.98),
            dark: UIColor(red: 38/255, green: 43/255, blue: 54/255, alpha: 0.98)
        )
        public static let bhumitraMapSurface = dynamic(
            light: UIColor(white: 1.0, alpha: 0.92),
            dark: UIColor(red: 23/255, green: 26/255, blue: 33/255, alpha: 0.90)
        )
        
        /// Dynamic Typography Tokens
        public static let bhumitraPrimaryText = dynamic(
            light: UIColor(red: 17/255, green: 20/255, blue: 24/255, alpha: 1.0),
            dark: UIColor(red: 246/255, green: 247/255, blue: 249/255, alpha: 1.0)
        )
        public static let bhumitraSecondaryText = dynamic(
            light: UIColor(red: 90/255, green: 96/255, blue: 106/255, alpha: 1.0),
            dark: UIColor(red: 154/255, green: 161/255, blue: 173/255, alpha: 1.0)
        )
        public static let bhumitraTertiaryText = dynamic(
            light: UIColor(red: 138/255, green: 144/255, blue: 156/255, alpha: 1.0),
            dark: UIColor(red: 115/255, green: 122/255, blue: 133/255, alpha: 1.0)
        )
        public static let bhumitraDisabledText = dynamic(
            light: UIColor(red: 180/255, green: 184/255, blue: 192/255, alpha: 1.0),
            dark: UIColor(red: 88/255, green: 93/255, blue: 104/255, alpha: 1.0)
        )
        
        /// Dynamic Dividers & Borders
        public static let bhumitraDivider = dynamic(
            light: UIColor(red: 226/255, green: 230/255, blue: 235/255, alpha: 1.0),
            dark: UIColor(red: 45/255, green: 50/255, blue: 62/255, alpha: 1.0)
        )
        public static let bhumitraBorder = dynamic(
            light: UIColor(white: 0.0, alpha: 0.09),
            dark: UIColor(white: 1.0, alpha: 0.14)
        )
        
        /// Canonical light/dark pairs for card surfaces (replaces inline isDarkMode ternaries)
        public static let bhumitraCardFill = dynamic(
            light: UIColor.white,
            dark: UIColor(red: 22/255, green: 22/255, blue: 32/255, alpha: 1.0) // #161620
        )
        public static let bhumitraCardFillElevated = dynamic(
            light: UIColor.white,
            dark: UIColor(red: 26/255, green: 26/255, blue: 36/255, alpha: 1.0) // #1A1A24
        )
        public static let bhumitraCardStroke = dynamic(
            light: UIColor(red: 229/255, green: 231/255, blue: 235/255, alpha: 1.0), // #E5E7EB
            dark: UIColor(white: 1.0, alpha: 0.12)
        )
        public static let bhumitraTextStrong = dynamic(
            light: UIColor(red: 17/255, green: 17/255, blue: 17/255, alpha: 1.0), // #111111
            dark: UIColor.white
        )
        public static let bhumitraTextMuted = dynamic(
            light: UIColor(red: 102/255, green: 102/255, blue: 102/255, alpha: 1.0), // #666666
            dark: UIColor(white: 1.0, alpha: 0.68)
        )
        
        /// Semantic Status Indicators & Tinted Surfaces
        public static let bhumitraSuccess = dynamic(
            light: UIColor(red: 22/255, green: 163/255, blue: 74/255, alpha: 1.0),
            dark: UIColor(red: 34/255, green: 197/255, blue: 94/255, alpha: 1.0)
        )
        public static let bhumitraSuccessSurface = dynamic(
            light: UIColor(red: 240/255, green: 253/255, blue: 244/255, alpha: 1.0),
            dark: UIColor(red: 20/255, green: 45/255, blue: 30/255, alpha: 0.60)
        )
        public static let bhumitraWarning = dynamic(
            light: UIColor(red: 217/255, green: 119/255, blue: 6/255, alpha: 1.0),
            dark: UIColor(red: 245/255, green: 158/255, blue: 11/255, alpha: 1.0)
        )
        public static let bhumitraWarningSurface = dynamic(
            light: UIColor(red: 255/255, green: 251/255, blue: 235/255, alpha: 1.0),
            dark: UIColor(red: 50/255, green: 38/255, blue: 15/255, alpha: 0.60)
        )
        public static let bhumitraError = dynamic(
            light: UIColor(red: 220/255, green: 38/255, blue: 38/255, alpha: 1.0),
            dark: UIColor(red: 239/255, green: 68/255, blue: 68/255, alpha: 1.0)
        )
        public static let bhumitraErrorSurface = dynamic(
            light: UIColor(red: 254/255, green: 242/255, blue: 242/255, alpha: 1.0),
            dark: UIColor(red: 50/255, green: 20/255, blue: 20/255, alpha: 0.60)
        )
        public static let bhumitraInfo = dynamic(
            light: UIColor(red: 37/255, green: 99/255, blue: 235/255, alpha: 1.0),
            dark: UIColor(red: 59/255, green: 130/255, blue: 246/255, alpha: 1.0)
        )
        public static let bhumitraInfoSurface = dynamic(
            light: UIColor(red: 239/255, green: 246/255, blue: 255/255, alpha: 1.0),
            dark: UIColor(red: 20/255, green: 35/255, blue: 60/255, alpha: 0.60)
        )
        
        // MARK: - Backwards-Compatible Semantic Aliases
        public static let primary = bhumitraPrimary
        public static let primaryLight = bhumitraTint
        public static let primaryPressed = bhumitraPrimaryPressed
        public static let primaryDisabled = bhumitraDisabled
        public static let mint = SwiftUI.Color(red: 27/255, green: 184/255, blue: 148/255)
        public static let indigo = SwiftUI.Color(red: 85/255, green: 89/255, blue: 214/255)
        public static let purple = bhumitraPrimary
        
        public static let background = bhumitraBackground
        public static let surface = bhumitraSurface
        public static let secondarySurface = bhumitraSurfaceSecondary
        public static let surfaceElevated = bhumitraElevatedSurface
        
        public static let primaryText = bhumitraPrimaryText
        public static let secondaryText = bhumitraSecondaryText
        public static let tertiaryText = bhumitraTertiaryText
        public static let disabledText = bhumitraDisabledText
        
        public static let separator = bhumitraDivider
        public static let border = bhumitraBorder
        
        public static let success = bhumitraSuccess
        public static let warning = bhumitraWarning
        public static let error = bhumitraError
        public static let info = bhumitraInfo
    }
    
    // MARK: - Legacy Color Aliases (Backwards Compatibility)
    public static let myBhoomiBlue = Color.primary
    public static let primary = Color.primary
    public static let accent = SwiftUI.Color(red: 100/255, green: 50/255, blue: 240/255)
    public static let surface = Color.surface
    public static let card = Color.surface
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
    
    // MARK: - Control Heights (Single source of truth for touch targets)
    public enum ButtonHeight {
        /// Standard height for primary CTA buttons app-wide (location picker,
        /// search, subscription, success modals, etc.).
        public static let cta: CGFloat = 52
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
        guard NSClassFromString("XCTestCase") == nil else { return }
        if UserDefaults.standard.object(forKey: "app_haptics_enabled") != nil && !UserDefaults.standard.bool(forKey: "app_haptics_enabled") {
            return
        }
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
    
    public static func selectionHaptic() {
        guard NSClassFromString("XCTestCase") == nil else { return }
        if UserDefaults.standard.object(forKey: "app_haptics_enabled") != nil && !UserDefaults.standard.bool(forKey: "app_haptics_enabled") {
            return
        }
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }
    
    public static func notificationHaptic(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard NSClassFromString("XCTestCase") == nil else { return }
        if UserDefaults.standard.object(forKey: "app_haptics_enabled") != nil && !UserDefaults.standard.bool(forKey: "app_haptics_enabled") {
            return
        }
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
    /// True when the string contains Odia script codepoints (U+0B00–U+0B7F),
    /// which the Google Sans family does not cover (renders as tofu).
    public static func containsOdiaScript(_ text: String) -> Bool {
        text.unicodeScalars.contains { $0.value >= 0x0B00 && $0.value <= 0x0B7F }
    }
    
    /// Google Sans for Latin text; system font when the text contains Odia
    /// glyphs so both scripts render correctly with a single font choice.
    public static func appText(_ text: String, size: CGFloat, weight: Font.Weight = .regular) -> Font {
        if containsOdiaScript(text) {
            return .system(size: size, weight: weight)
        }
        return .googleSans(size: size, weight: weight)
    }
    
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

// MARK: - Color Convenience Extensions

extension Color {
    public static let bhumitraPrimary = Theme.Color.bhumitraPrimary
    public static let bhumitraPrimaryPressed = Theme.Color.bhumitraPrimaryPressed
    public static let bhumitraTint = Theme.Color.bhumitraTint
    public static let bhumitraSelection = Theme.Color.bhumitraSelection
    public static let bhumitraDisabled = Theme.Color.bhumitraDisabled
    public static let bhumitraOverlay = Theme.Color.bhumitraOverlay
    
    public static let bhumitraBackground = Theme.Color.bhumitraBackground
    public static let bhumitraSurface = Theme.Color.bhumitraSurface
    public static let bhumitraSurfaceSecondary = Theme.Color.bhumitraSurfaceSecondary
    public static let bhumitraElevatedSurface = Theme.Color.bhumitraElevatedSurface
    public static let bhumitraMapSurface = Theme.Color.bhumitraMapSurface
    
    public static let bhumitraPrimaryText = Theme.Color.bhumitraPrimaryText
    public static let bhumitraSecondaryText = Theme.Color.bhumitraSecondaryText
    public static let bhumitraTertiaryText = Theme.Color.bhumitraTertiaryText
    public static let bhumitraDisabledText = Theme.Color.bhumitraDisabledText
    
    public static let bhumitraDivider = Theme.Color.bhumitraDivider
    public static let bhumitraBorder = Theme.Color.bhumitraBorder
    
    public static let bhumitraSuccess = Theme.Color.bhumitraSuccess
    public static let bhumitraSuccessSurface = Theme.Color.bhumitraSuccessSurface
    public static let bhumitraWarning = Theme.Color.bhumitraWarning
    public static let bhumitraWarningSurface = Theme.Color.bhumitraWarningSurface
    public static let bhumitraError = Theme.Color.bhumitraError
    public static let bhumitraErrorSurface = Theme.Color.bhumitraErrorSurface
    public static let bhumitraInfo = Theme.Color.bhumitraInfo
    public static let bhumitraInfoSurface = Theme.Color.bhumitraInfoSurface
}
