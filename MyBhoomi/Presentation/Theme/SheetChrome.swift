//  SheetChrome.swift
//  MyBhoomi
//
//  Shared building blocks for full-height sheets and screens (plot sheet,
//  location picker, subscription). Same idea as MapChrome: one surface, one
//  hairline, one small icon-button style, so every screen reads as the same
//  product.

import SwiftUI

public enum SheetChrome {
    /// The single background every sheet/screen paints edge to edge.
    public static let background = Theme.Color.bhumitraSurface
    /// Fill for quiet controls and inset fields that sit ON the background.
    public static let controlFill = Theme.Color.bhumitraSurfaceSecondary
    /// Horizontal content inset shared by all sheets.
    public static let inset: CGFloat = 20
    /// Diameter of small circular icon buttons (close, back, share).
    public static let iconButtonSize: CGFloat = 36
    /// Height of inset search fields and list rows.
    public static let rowHeight: CGFloat = 48
}

/// Small circular icon button: close, back, share, reset.
public struct SheetIconButton: View {
    public let systemName: String
    public let accessibilityLabel: String
    public let action: () -> Void

    public init(_ systemName: String, accessibilityLabel: String, action: @escaping () -> Void) {
        self.systemName = systemName
        self.accessibilityLabel = accessibilityLabel
        self.action = action
    }

    public var body: some View {
        Button {
            Theme.haptic(.light)
            action()
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.Color.bhumitraPrimaryText)
                .frame(width: SheetChrome.iconButtonSize, height: SheetChrome.iconButtonSize)
                .background(Circle().fill(SheetChrome.controlFill))
                .contentShape(Circle())
        }
        .buttonStyle(MapChromePressStyle())
        .accessibilityLabel(accessibilityLabel)
    }
}

/// Full-width 1pt hairline, the only separator used between sections.
public struct SheetHairline: View {
    public init() {}

    public var body: some View {
        Rectangle()
            .fill(Theme.Color.bhumitraBorder)
            .frame(height: 1)
    }
}
