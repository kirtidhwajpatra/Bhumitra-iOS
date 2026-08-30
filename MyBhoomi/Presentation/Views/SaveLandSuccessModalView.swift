import SwiftUI

// ============================================================
// MARK: - SAVE LAND SUCCESS MODAL (PIXEL-PERFECT VECTOR ILLUSTRATION)
// ============================================================

/// Pixel-perfect modal displaying the celebratory animated bookmark illustration and subtle rotating sparkles
/// when a parcel is saved on-device.
public struct SaveLandSuccessModalView: View {
    public let plotNumber: String
    public let villageName: String?
    public let onDismiss: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
    // Animation States
    @State private var circleScale: CGFloat = 0.2
    @State private var bookmarkDropOffset: CGFloat = -14
    @State private var bookmarkOpacity: Double = 0.0
    @State private var sparklesScale: CGFloat = 0.0
    @State private var sparklesOpacity: Double = 0.0
    @State private var textOffset: CGFloat = 18
    @State private var textOpacity: Double = 0.0
    
    // Subtle continuous rotation for stars (no positional movement)
    @State private var starRotationAngle: Double = 0.0
    
    public init(
        plotNumber: String,
        villageName: String? = nil,
        onDismiss: @escaping () -> Void
    ) {
        self.plotNumber = plotNumber
        self.villageName = villageName
        self.onDismiss = onDismiss
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
    
    // ── VECTOR ILLUSTRATION COLOR SYSTEM ──
    
    /// Top/Main Vibrant Electric Violet Circle (#6D10FF)
    private var topCircleColor: Color {
        Color(red: 109/255, green: 16/255, blue: 255/255)
    }
    
    /// Bottom Rim / Darker Depth Violet Circle (#4600C7)
    private var bottomRimCircleColor: Color {
        Color(red: 70/255, green: 0/255, blue: 199/255)
    }
    
    /// Solid Vector Shadow behind White Bookmark Ribbon (#36008E)
    private var ribbonSolidShadowColor: Color {
        Color(red: 54/255, green: 0/255, blue: 142/255)
    }
    
    /// Pastel Mint Sparkle Color (#9AE2C1)
    private var mintSparkleColor: Color {
        Color(red: 154/255, green: 226/255, blue: 193/255)
    }
    
    /// Pastel Lilac Bar Color (#C7A7FB)
    private var lilacBarColor: Color {
        Color(red: 199/255, green: 167/255, blue: 251/255)
    }
    
    /// Sage Forest Green Dot Color (#4EA882)
    private var sageDotColor: Color {
        Color(red: 78/255, green: 168/255, blue: 130/255)
    }
    
    /// Soft Gray Dot Color (#C8CDD3)
    private var softGrayDotColor: Color {
        Color(red: 200/255, green: 205/255, blue: 211/255)
    }
    
    /// Pastel Golden Yellow Star Color (#FCE197)
    private var goldenStarColor: Color {
        Color(red: 252/255, green: 225/255, blue: 151/255)
    }
    
    public var body: some View {
        ZStack {
            // Flat Clean Background (No Blurred Shadows)
            pageBackground
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    dismissModal()
                }
            
            VStack(spacing: 0) {
                // Top Dismiss Button (Flat Circle with Clean Hairline)
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
                
                // ── CENTER HERO VECTOR ANIMATION ──
                ZStack {
                    // Confetti Elements & Stars (Fixed position, only subtle slow rotation)
                    ZStack {
                        // 1. Top-Left Mint 4-Point Star
                        SparkleStarShape()
                            .fill(mintSparkleColor)
                            .frame(width: 15, height: 15)
                            .offset(x: -78, y: -45)
                            .rotationEffect(.degrees(starRotationAngle))
                        
                        // 2. Mid-Left Pastel Lilac Confetti Bar
                        RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                            .fill(lilacBarColor)
                            .frame(width: 15, height: 6.5)
                            .rotationEffect(.degrees(-15 + (starRotationAngle * 0.2)))
                            .offset(x: -80, y: 15)
                        
                        // 3. Top-Right Sage Forest Green Dot
                        Circle()
                            .fill(sageDotColor)
                            .frame(width: 9, height: 9)
                            .offset(x: 18, y: -88)
                        
                        // 4. Top-Right Soft Gray Dot
                        Circle()
                            .fill(softGrayDotColor)
                            .frame(width: 5.5, height: 5.5)
                            .offset(x: 30, y: -68)
                        
                        // 5. Mid-Right Pastel Golden Peach Star
                        SparkleStarShape()
                            .fill(goldenStarColor)
                            .frame(width: 15, height: 15)
                            .offset(x: 80, y: 2)
                            .rotationEffect(.degrees(-starRotationAngle * 1.2))
                    }
                    .scaleEffect(sparklesScale)
                    .opacity(sparklesOpacity)
                    
                    // ── 2-TONE DEPTH CIRCLE (Bottom Rim + Top Vibrant Circle) ──
                    ZStack {
                        // Layer A: Darker Violet Rim Base (Slightly Offset Downwards for Depth)
                        Circle()
                            .fill(bottomRimCircleColor)
                            .frame(width: 114, height: 114)
                            .offset(y: 4.5)
                        
                        // Layer B: Main Vibrant Electric Purple Circle
                        Circle()
                            .fill(topCircleColor)
                            .frame(width: 114, height: 114)
                        
                        // ── BOOKMARK RIBBON (Solid Shadow + Crisp White Face) ──
                        ZStack {
                            // Solid Dark Purple Vector Shadow (Offset Downwards)
                            BookmarkRibbonShape()
                                .fill(ribbonSolidShadowColor)
                                .frame(width: 30, height: 44)
                                .offset(y: bookmarkDropOffset + 4.0)
                                .opacity(bookmarkOpacity)
                            
                            // Pure White Bookmark Face
                            BookmarkRibbonShape()
                                .fill(Color.white)
                                .frame(width: 30, height: 44)
                                .offset(y: bookmarkDropOffset)
                                .opacity(bookmarkOpacity)
                        }
                    }
                    .scaleEffect(circleScale)
                }
                .frame(height: 200)
                
                Spacer()
                    .frame(height: 55)
                
                // ── HEADLINE & SUBTITLE ──
                VStack(spacing: 10) {
                    Text("Plot \(plotNumber) saved!")
                        .font(.system(size: 29, weight: .bold, design: .rounded))
                        .foregroundColor(primaryText)
                        .multilineTextAlignment(.center)
                    
                    Text("has successfully added to saved list.")
                        .font(.system(size: 16, weight: .regular, design: .rounded))
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
        
        // 2. Central 2-Tone Circle Elastic Spring Pop
        withAnimation(.spring(response: 0.44, dampingFraction: 0.64, blendDuration: 0.1)) {
            circleScale = 1.0
        }
        
        // 3. Bookmark Ribbon and Solid Shadow Drop Into Place
        withAnimation(.spring(response: 0.38, dampingFraction: 0.72).delay(0.06)) {
            bookmarkDropOffset = 0
            bookmarkOpacity = 1.0
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
        
        // 6. Very Slow, Subtle Continuous Rotation for Sparkles (No Positional Movement)
        withAnimation(.easeInOut(duration: 6.0).repeatForever(autoreverses: true).delay(0.4)) {
            starRotationAngle = 22.0
        }
        
        // 7. Auto-dismiss after 3.5 seconds if not manually closed
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
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

/// Clean 4-pointed sparkle star shape matching the design illustration.
public struct SparkleStarShape: Shape {
    public init() {}
    
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let cx = rect.midX
        let cy = rect.midY
        let rx = rect.width / 2
        let ry = rect.height / 2
        let concavity: CGFloat = 0.26
        
        path.move(to: CGPoint(x: cx, y: cy - ry))
        path.addQuadCurve(
            to: CGPoint(x: cx + rx, y: cy),
            control: CGPoint(x: cx + rx * concavity, y: cy - ry * concavity)
        )
        path.addQuadCurve(
            to: CGPoint(x: cx, y: cy + ry),
            control: CGPoint(x: cx + rx * concavity, y: cy + ry * concavity)
        )
        path.addQuadCurve(
            to: CGPoint(x: cx - rx, y: cy),
            control: CGPoint(x: cx - rx * concavity, y: cy + ry * concavity)
        )
        path.addQuadCurve(
            to: CGPoint(x: cx, y: cy - ry),
            control: CGPoint(x: cx - rx * concavity, y: cy - ry * concavity)
        )
        path.closeSubpath()
        return path
    }
}

/// Custom vector ribbon shape matching the white bookmark inside the purple circle.
public struct BookmarkRibbonShape: Shape {
    public init() {}
    
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let cornerRadius: CGFloat = 3.5
        let notchDepth: CGFloat = h * 0.28
        
        path.move(to: CGPoint(x: rect.minX + cornerRadius, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - cornerRadius, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + cornerRadius),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cornerRadius))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - cornerRadius * 0.8, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        // Triangular bottom notch
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY - notchDepth))
        path.addLine(to: CGPoint(x: rect.minX + cornerRadius * 0.8, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - cornerRadius),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + cornerRadius))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + cornerRadius, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )
        path.closeSubpath()
        return path
    }
}

#Preview {
    SaveLandSuccessModalView(
        plotNumber: "450",
        villageName: "Balianta",
        onDismiss: {}
    )
}
