import SwiftUI

// ============================================================
// MARK: - PURCHASE SUCCESS CELEBRATION MODAL (FLAME & SEARCH POWER)
// ============================================================

/// Pixel-perfect celebratory modal displayed when the user completes a purchase/subscription.
/// Features the animated flame vector, dynamic power count (10, 50, +), confetti sparkles, and pleasing haptics.
public struct PurchaseSuccessModalView: View {
    public let tier: ProductTier
    public let onDismiss: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
    // Animation States
    @State private var badgeScale: CGFloat = 0.2
    @State private var flameScale: CGFloat = 0.0
    @State private var flameFlicker: CGFloat = 1.0
    @State private var flameRotation: Double = 0.0
    @State private var sparklesScale: CGFloat = 0.0
    @State private var sparklesOpacity: Double = 0.0
    @State private var textOffset: CGFloat = 20
    @State private var textOpacity: Double = 0.0
    
    // Subtle continuous rotation for stars (no positional movement)
    @State private var starRotationAngle: Double = 0.0
    
    public init(
        tier: ProductTier,
        onDismiss: @escaping () -> Void
    ) {
        self.tier = tier
        self.onDismiss = onDismiss
    }
    
    // Dynamic Power Count & Label
    private var powerCountText: String {
        switch tier {
        case .tenPlots:
            return "10"
        case .fiftyPlots:
            return "50"
        case .twoHundredPlots:
            return "200"
        case .monthly:
            return "+"
        }
    }
    
    private var subtitleCopy: String {
        switch tier {
        case .tenPlots:
            return "You’ve acquired 10+ plot search power."
        case .fiftyPlots:
            return "You’ve acquired 50+ plot search power."
        case .twoHundredPlots:
            return "You’ve acquired 200+ plot search power."
        case .monthly:
            return "You’ve acquired Unlimited+ plot search power."
        }
    }
    
    // Theme Colors
    private var pageBackground: Color {
        colorScheme == .dark
            ? Color(red: 14/255, green: 14/255, blue: 17/255)
            : Color(red: 247/255, green: 247/255, blue: 248/255)
    }
    
    private var primaryText: Color {
        colorScheme == .dark ? .white : Color(red: 10/255, green: 12/255, blue: 16/255)
    }
    
    private var secondaryText: Color {
        colorScheme == .dark ? Color(white: 0.70) : Color(red: 20/255, green: 24/255, blue: 30/255)
    }
    
    // Confetti Palette
    private var shardGrayColor: Color {
        Color(red: 211/255, green: 214/255, blue: 218/255)
    }
    
    private var goldenStarColor: Color {
        Color(red: 252/255, green: 225/255, blue: 151/255)
    }
    
    private var pastelPeachColor: Color {
        Color(red: 247/255, green: 216/255, blue: 207/255)
    }
    
    private var coralDashColor: Color {
        Color(red: 252/255, green: 163/255, blue: 157/255)
    }
    
    private var softGrayDotColor: Color {
        Color(red: 216/255, green: 220/255, blue: 222/255)
    }
    
    public var body: some View {
        ZStack {
            // Clean Flat Background (No Blurred Shadows)
            pageBackground
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    dismissModal()
                }
            
            VStack(spacing: 0) {
                // Top Dismiss Button (Flat Circle with Hairline Border)
                HStack {
                    Spacer()
                    
                    Button {
                        Theme.haptic(.light)
                        dismissModal()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(colorScheme == .dark ? Color(white: 0.20) : Color.white)
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Circle()
                                        .stroke(colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.06), lineWidth: 1)
                                )
                            
                            Image(systemName: "xmark")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(colorScheme == .dark ? Color(white: 0.85) : Color(red: 120/255, green: 125/255, blue: 135/255))
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 24)
                    .padding(.top, 16)
                }
                
                Spacer()
                
                // ── CENTER HERO FLAME BADGE & CONFETTI ──
                ZStack {
                    // Confetti Particles & Sparkles
                    ZStack {
                        // 1. Top-Left Gray Shard
                        AngularShardShape()
                            .fill(shardGrayColor)
                            .frame(width: 14, height: 18)
                            .rotationEffect(.degrees(-35 + (starRotationAngle * 0.15)))
                            .offset(x: -110, y: -75)
                        
                        // 2. Top-Left Golden 4-Point Star
                        SparkleStarShape()
                            .fill(goldenStarColor)
                            .frame(width: 22, height: 22)
                            .offset(x: -62, y: -80)
                            .rotationEffect(.degrees(starRotationAngle))
                        
                        // 3. Mid-Left Pastel Peach Dot
                        Circle()
                            .fill(pastelPeachColor)
                            .frame(width: 12, height: 12)
                            .offset(x: -115, y: -25)
                        
                        // 4. Bottom-Left Soft Gray Dots
                        HStack(spacing: 5) {
                            Circle()
                                .fill(softGrayDotColor)
                                .frame(width: 4.5, height: 4.5)
                            Circle()
                                .fill(softGrayDotColor.opacity(0.6))
                                .frame(width: 3.5, height: 3.5)
                        }
                        .offset(x: -105, y: 48)
                        
                        // 5. Top-Right Gray Shard
                        AngularShardShape()
                            .fill(shardGrayColor)
                            .frame(width: 12, height: 16)
                            .rotationEffect(.degrees(25 - (starRotationAngle * 0.15)))
                            .offset(x: 38, y: -88)
                        
                        // 6. Top-Right Golden Star
                        SparkleStarShape()
                            .fill(goldenStarColor)
                            .frame(width: 10, height: 10)
                            .offset(x: 74, y: -90)
                            .rotationEffect(.degrees(-starRotationAngle * 1.2))
                        
                        // 7. Mid-Right Coral Dash
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(coralDashColor)
                            .frame(width: 9, height: 3)
                            .rotationEffect(.degrees(-40))
                            .offset(x: 78, y: -60)
                        
                        // 8. Far-Right Soft Gray Dots
                        Circle()
                            .fill(softGrayDotColor)
                            .frame(width: 4, height: 4)
                            .offset(x: 102, y: -25)
                    }
                    .scaleEffect(sparklesScale)
                    .opacity(sparklesOpacity)
                    
                    // Main White Circular Disc
                    ZStack {
                        Circle()
                            .fill(colorScheme == .dark ? Color(red: 26/255, green: 26/255, blue: 30/255) : Color.white)
                            .frame(width: 172, height: 172)
                            .overlay(
                                Circle()
                                    .stroke(
                                        colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.08),
                                        lineWidth: 1
                                    )
                            )
                        
                        // Flame Vector & Power Count
                        HStack(spacing: 8) {
                            // Animated Flame Vector
                            FlameVectorShape()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 168/255, green: 85/255, blue: 247/255), // Top: #A855F7
                                            Color(red: 106/255, green: 13/255, blue: 173/255)  // Bottom: #6A0DAD
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(width: 44, height: 64)
                                .scaleEffect(flameScale * flameFlicker)
                                .rotationEffect(.degrees(flameRotation))
                            
                            // Bold Number / Symbol
                            Text(powerCountText)
                                .font(.system(size: powerCountText == "+" ? 56 : 48, weight: .bold, design: .rounded))
                                .foregroundColor(primaryText)
                        }
                    }
                    .scaleEffect(badgeScale)
                }
                .frame(height: 220)
                
                Spacer()
                    .frame(height: 55)
                
                // ── HEADLINE & SUBTITLE ──
                VStack(spacing: 12) {
                    Text("Congratulations!")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(primaryText)
                        .multilineTextAlignment(.center)
                    
                    Text(subtitleCopy)
                        .font(.system(size: 16.5, weight: .regular, design: .rounded))
                        .foregroundColor(secondaryText)
                        .multilineTextAlignment(.center)
                }
                .offset(y: textOffset)
                .opacity(textOpacity)
                .padding(.horizontal, 32)
                
                Spacer()
                Spacer()
            }
        }
        .onAppear {
            startEntryAnimation()
        }
    }
    
    // MARK: - Animation Orchestration
    
    private func startEntryAnimation() {
        // 1. Pleasing Single Success Haptic
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        
        // 2. White Badge Elastic Spring Pop
        withAnimation(.spring(response: 0.44, dampingFraction: 0.65, blendDuration: 0.1)) {
            badgeScale = 1.0
        }
        
        // 3. Flame Ignite Pop Animation
        withAnimation(.spring(response: 0.40, dampingFraction: 0.60).delay(0.06)) {
            flameScale = 1.0
        }
        
        // 4. Sparkles Burst Outward
        withAnimation(.spring(response: 0.50, dampingFraction: 0.68).delay(0.10)) {
            sparklesScale = 1.0
            sparklesOpacity = 1.0
        }
        
        // 5. Text Slides and Fades In
        withAnimation(.spring(response: 0.40, dampingFraction: 0.84).delay(0.16)) {
            textOffset = 0
            textOpacity = 1.0
        }
        
        // 6. Subtle Continuous Flame Flicker & Micro-Sway
        withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true).delay(0.4)) {
            flameFlicker = 1.04
            flameRotation = 1.8
        }
        
        // 7. Very Slow Subtle Continuous Rotation for Sparkles
        withAnimation(.easeInOut(duration: 6.5).repeatForever(autoreverses: true).delay(0.4)) {
            starRotationAngle = 20.0
        }
        
        // 8. Auto-dismiss after 3.8 seconds if not manually closed
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.8) {
            dismissModal()
        }
    }
    
    private func dismissModal() {
        withAnimation(.spring(response: 0.30, dampingFraction: 0.85)) {
            onDismiss()
        }
    }
}

// ============================================================
// MARK: - VECTOR CUSTOM SHAPES
// ============================================================

/// Custom vector flame shape matching the authentic SVG flame icon with twin tongues and sharp licks.
public struct FlameVectorShape: Shape {
    public init() {}
    
    public func path(in rect: CGRect) -> Path {
        let sx = rect.width / 15.5684
        let sy = rect.height / 22.4258
        
        var path = Path()
        path.move(to: CGPoint(x: 13.7891 * sx, y: 10.5838 * sy))
        path.addCurve(
            to: CGPoint(x: 11.7754 * sx, y: 8.06724 * sy),
            control1: CGPoint(x: 13.1699 * sx, y: 9.70298 * sy),
            control2: CGPoint(x: 12.459 * sx, y: 8.86893 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 10.3379 * sx, y: 6.31646 * sy),
            control1: CGPoint(x: 11.2656 * sx, y: 7.47047 * sy),
            control2: CGPoint(x: 10.7695 * sx, y: 6.88807 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 9.07812 * sx, y: 4.10193 * sy),
            control1: CGPoint(x: 9.76758 * sx, y: 5.5651 * sy),
            control2: CGPoint(x: 9.31055 * sx, y: 4.83172 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 9.07812 * sx, y: 0.0 * sy),
            control1: CGPoint(x: 8.56641 * sx, y: 2.50933 * sy),
            control2: CGPoint(x: 8.91992 * sx, y: 0.722601 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 6.84375 * sx, y: 3.74961 * sy),
            control1: CGPoint(x: 7.99805 * sx, y: 0.744171 * sy),
            control2: CGPoint(x: 7.26172 * sx, y: 2.22532 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 6.45312 * sx, y: 7.27634 * sy),
            control1: CGPoint(x: 6.49414 * sx, y: 5.02944 * sy),
            control2: CGPoint(x: 6.36914 * sx, y: 6.34163 * sy)
        )
        path.addLine(to: CGPoint(x: 6.52344 * sx, y: 8.04208 * sy))
        path.addCurve(
            to: CGPoint(x: 6.59766 * sx, y: 10.7024 * sy),
            control1: CGPoint(x: 6.60547 * sx, y: 8.95162 * sy),
            control2: CGPoint(x: 6.67969 * sx, y: 9.92228 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 5.56836 * sx, y: 12.259 * sy),
            control1: CGPoint(x: 6.50781 * sx, y: 11.5616 * sy),
            control2: CGPoint(x: 6.22852 * sx, y: 12.1907 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 4.47266 * sx, y: 12.0757 * sy),
            control1: CGPoint(x: 5.14648 * sx, y: 12.3022 * sy),
            control2: CGPoint(x: 4.78711 * sx, y: 12.2303 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 3.29688 * sx, y: 10.9217 * sy),
            control1: CGPoint(x: 3.99023 * sx, y: 11.842 * sy),
            control2: CGPoint(x: 3.61719 * sx, y: 11.4142 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 2.64258 * sx, y: 9.75331 * sy),
            control1: CGPoint(x: 3.05664 * sx, y: 10.5514 * sy),
            control2: CGPoint(x: 2.8457 * sx, y: 10.1452 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 0.00195312 * sx, y: 15.02 * sy),
            control1: CGPoint(x: 1.06445 * sx, y: 11.0475 * sy),
            control2: CGPoint(x: 0.0527344 * sx, y: 12.9241 * sy)
        )
        path.addLine(to: CGPoint(x: 0.0 * sx, y: 15.2573 * sy))
        path.addCurve(
            to: CGPoint(x: 7.78516 * sx, y: 22.4258 * sy),
            control1: CGPoint(x: 0.0390625 * sx, y: 19.2226 * sy),
            control2: CGPoint(x: 3.50977 * sx, y: 22.4258 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 15.5684 * sx, y: 15.2825 * sy),
            control1: CGPoint(x: 12.0508 * sx, y: 22.4258 * sy),
            control2: CGPoint(x: 15.5137 * sx, y: 19.237 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 14.9238 * sx, y: 12.5251 * sy),
            control1: CGPoint(x: 15.5586 * sx, y: 14.3082 * sy),
            control2: CGPoint(x: 15.3145 * sx, y: 13.3915 * sy)
        )
        path.addLine(to: CGPoint(x: 14.8965 * sx, y: 12.4676 * sy))
        path.addCurve(
            to: CGPoint(x: 13.7891 * sx, y: 10.5838 * sy),
            control1: CGPoint(x: 14.5977 * sx, y: 11.8205 * sy),
            control2: CGPoint(x: 14.2109 * sx, y: 11.1841 * sy)
        )
        path.closeSubpath()
        return path
    }
}

/// Angular trapezoid shard particle matching the confetti in the illustration.
public struct AngularShardShape: Shape {
    public init() {}
    
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        path.move(to: CGPoint(x: rect.minX + w * 0.35, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + h * 0.25))
        path.addLine(to: CGPoint(x: rect.minX + w * 0.65, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - h * 0.15))
        path.closeSubpath()
        return path
    }
}

#Preview {
    PurchaseSuccessModalView(
        tier: .fiftyPlots,
        onDismiss: {}
    )
}
