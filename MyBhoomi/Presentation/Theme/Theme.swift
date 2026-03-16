import SwiftUI

public enum Theme {
    // Colors
    public static let primary = Color(red: 90/255, green: 40/255, blue: 210/255) // Richer, more vibrant Purple
    public static let accent = Color(red: 100/255, green: 50/255, blue: 240/255) // Deep Electric Purple
    public static let surface = Color(white: 0.98)
    public static let card = Color.white
    public static let neonPurple = Color(red: 191/255, green: 64/255, blue: 255/255) // Brighter Neon Purple
    public static let neonGreen = Color(red: 57/255, green: 255/255, blue: 20/255) // High-contrast Neon Green
    public static let neonYellow = Color(red: 255/255, green: 255/255, blue: 0/255) // High-contrast Yellow
    
    // Gradients
    public static let brandGradient = LinearGradient(
        colors: [primary, accent],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // Geometry
    public static let cornerRadiusLarge: CGFloat = 28
    public static let cornerRadiusMedium: CGFloat = 18
    public static let paddingStandard: CGFloat = 20
    
    // Shadows
    public static func shadowSoft(_ color: Color = .black) -> some View {
        EmptyView().shadow(color: color.opacity(0.08), radius: 15, x: 0, y: 8)
    }
}

// Global helpers (deprecated, favor Theme.xyz)
public func hapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
    let generator = UIImpactFeedbackGenerator(style: style)
    generator.prepare()
    generator.impactOccurred()
}

public let primaryPurple = Theme.primary

public struct ScaledButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}
