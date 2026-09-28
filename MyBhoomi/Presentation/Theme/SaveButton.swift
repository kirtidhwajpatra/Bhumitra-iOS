//
//  SaveButton.swift
//  MyBhoomi
//
//  Generated from Figma "Frame 9448" (node 1487:1270).
//  A compact yellow pill "Save" button with a bookmark glyph and purple label.
//  Colors, typography, spacing, and press behavior are mapped to the app's Theme.
//

import SwiftUI

/// A compact pill-shaped "Save" button matching the Figma design (node 1487:1270).
///
/// Visual spec (from Figma):
/// - Background: `#FFFB1F` (yellow)
/// - Label color: `#6E07FF` (brand purple)
/// - Fully rounded pill (Capsule)
/// - Bookmark glyph + "Save" text, centered
///
/// Uses `ScaledButtonStyle` for the app's standard tactile press feedback.
public struct SaveButton: View {
    /// Title shown next to the bookmark glyph.
    public let title: String
    /// Whether the item is already saved (switches to a filled bookmark).
    public let isSaved: Bool
    /// Tap handler.
    public let action: () -> Void

    public init(
        title: String = "Save",
        isSaved: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.isSaved = isSaved
        self.action = action
    }

    // MARK: - Design Tokens (mapped from Figma)
    private let backgroundColor = Color(hex: "#FFFB1F")   // Figma fill #FFFB1F
    private let labelColor = Color(hex: "#6E07FF")        // Figma text #6E07FF

    public var body: some View {
        Button(action: {
            Theme.haptic(.light)
            action()
        }) {
            HStack(spacing: 2) { // Figma gap: 2px
                Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 17.4, height: 17.4) // Figma icon: 17.406 x 17.406

                Text(title)
                    .font(.stackSansHeadline(size: 13.7, weight: .regular)) // Figma "Stack Sans Headline" 13.686
                    .lineLimit(1)
            }
            .foregroundColor(labelColor)
            .padding(7.6) // Figma padding: 7.604
            .background(
                Capsule(style: .continuous)
                    .fill(backgroundColor)
            )
        }
        .buttonStyle(ScaledButtonStyle())
        .accessibilityLabel(isSaved ? "Saved" : "Save")
        .accessibilityAddTraits(isSaved ? [.isButton, .isSelected] : .isButton)
    }
}

#if DEBUG
struct SaveButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 24) {
            SaveButton(action: {})
            SaveButton(isSaved: true, action: {})
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif
