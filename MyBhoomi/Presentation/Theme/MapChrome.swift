//  MapChrome.swift
//  MyBhoomi
//
//  Single source of truth for the floating controls drawn over the map
//  (location selector, account capsule, map controls). Every control shares
//  one height, one glass material, one shadow and one press behaviour so the
//  map chrome reads as a single, calm system instead of mixed widgets.

import SwiftUI

public enum MapChrome {
    /// Height of every floating control. 44pt is the HIG minimum hit target.
    public static let controlHeight: CGFloat = 44
    /// Glyph size for SF Symbols inside map controls.
    public static let iconSize: CGFloat = 16
    /// Gap between neighbouring floating controls.
    public static let spacing: CGFloat = 8
    /// Hairline divider inside grouped capsules.
    public static let dividerColor = Theme.Color.bhumitraBorder
}

/// Uniform glass surface + restrained shadow for map chrome.
private struct MapChromeSurface<S: Shape>: ViewModifier {
    let shape: S
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .glassEffect(
                .regular.tint(Theme.Color.bhumitraMapSurface).interactive(),
                in: shape
            )
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.30 : 0.10),
                radius: 6,
                x: 0,
                y: 2
            )
    }
}

extension View {
    /// Applies the shared map-chrome glass surface in the given shape.
    public func mapChromeSurface<S: Shape>(in shape: S) -> some View {
        modifier(MapChromeSurface(shape: shape))
    }
}

/// Quiet press feedback: a slight dim and scale, no rubber-band stretch.
public struct MapChromePressStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.6 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Hairline vertical divider used between segments of a grouped capsule.
public struct MapChromeDivider: View {
    public enum Axis { case vertical, horizontal }
    public let axis: Axis

    public init(_ axis: Axis = .vertical) {
        self.axis = axis
    }

    public var body: some View {
        Rectangle()
            .fill(MapChrome.dividerColor)
            .frame(
                width: axis == .vertical ? 1 : 22,
                height: axis == .vertical ? 22 : 1
            )
    }
}
