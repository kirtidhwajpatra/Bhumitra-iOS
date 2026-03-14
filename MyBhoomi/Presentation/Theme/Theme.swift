import SwiftUI

public enum Theme {
    public static let primaryPurple = Color(red: 107/255, green: 70/255, blue: 193/255)
    public static let accentLavender = Color(red: 240/255, green: 231/255, blue: 255/255)
    public static let deepPurple = Color(red: 76/255, green: 59/255, blue: 145/255)
}

public func hapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
    let generator = UIImpactFeedbackGenerator(style: style)
    generator.impactOccurred()
}

// Global accessibility if needed, but preferably use Theme.primaryPurple
public let primaryPurple = Theme.primaryPurple
public let accentLavender = Theme.accentLavender
public let deepPurple = Theme.deepPurple
