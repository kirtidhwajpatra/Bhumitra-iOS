import SwiftUI

// ============================================================
// MARK: - APPLE-GRADE SKELETON SHIMMER EFFECT
// ============================================================

/// Liquid reflection / shimmer modifier for skeleton placeholder elements.
public struct SkeletonShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1.0
    @Environment(\.colorScheme) private var colorScheme
    
    public init() {}
    
    private var highlightColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.18)
            : Color.white.opacity(0.65)
    }
    
    public func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    let width = max(geo.size.width, 100)
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.0),
                            .init(color: highlightColor.opacity(0.3), location: 0.35),
                            .init(color: highlightColor, location: 0.5),
                            .init(color: highlightColor.opacity(0.3), location: 0.65),
                            .init(color: .clear, location: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .rotationEffect(.degrees(20))
                    .offset(x: phase * width * 2.2)
                }
            )
            .mask(content)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 1.65)
                    .repeatForever(autoreverses: false)
                ) {
                    phase = 1.0
                }
            }
    }
}

public extension View {
    /// Applies a continuous diagonal reflection / shimmer animation to any view or skeleton block.
    func skeletonShimmer() -> some View {
        self.modifier(SkeletonShimmerModifier())
    }
}

/// A standard rounded rectangular skeleton block with subtle background and serene reflection shimmer.
public struct SkeletonBlock: View {
    public var width: CGFloat? = nil
    public var height: CGFloat = 16
    public var cornerRadius: CGFloat = 6
    
    @Environment(\.colorScheme) private var colorScheme
    
    public init(width: CGFloat? = nil, height: CGFloat = 16, cornerRadius: CGFloat = 6) {
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
    }
    
    public var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                colorScheme == .dark
                    ? Color(red: 38/255, green: 40/255, blue: 48/255)
                    : Color(red: 232/255, green: 235/255, blue: 240/255)
            )
            .frame(width: width, height: height)
            .skeletonShimmer()
    }
}
