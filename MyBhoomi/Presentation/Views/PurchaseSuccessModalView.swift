//
//  PurchaseSuccessModalView.swift
//  MyBhoomi
//
//  Figma Pixel-Perfect Implementation of PaymentSuccessful_Screen (Node ID: 804:2528)
//

import SwiftUI

// MARK: - Design Tokens (Figma Node 804:2528)
private enum FigmaPaymentSuccessTokens {
    static let canvasBg = Color(hex: "#7F31EC")
    static let radialCenter = Color(red: 70/255, green: 0/255, blue: 151/255, opacity: 0.8)
    static let radialEdge = Color(red: 118/255, green: 0/255, blue: 255/255, opacity: 0.0)
    static let shadowPurple = Color(hex: "#37106D")
    static let closeBorder = Color(hex: "#4D00A5")
    
    static let textTitle = Color(hex: "#FFFDFA")
    static let textSubtitle = Color(hex: "#CFA6FF")
}

public struct PurchaseSuccessModalView: View {
    public let tier: ProductTier
    public let onDismiss: () -> Void
    
    // Animation States
    @State private var appearAnimation: Bool = false
    @State private var floatingOffset: CGFloat = 0
    @State private var particlesScale: CGFloat = 0.8
    
    public init(
        tier: ProductTier,
        onDismiss: @escaping () -> Void
    ) {
        self.tier = tier
        self.onDismiss = onDismiss
    }
    
    private var creditsEarnedCopy: String {
        switch tier {
        case .tenPlots:
            return "You’ve earned \n10 plot search credit"
        case .fiftyPlots:
            return "You’ve earned \n50 plot search credit"
        case .twoHundredPlots:
            return "You’ve earned \n200 plot search credit"
        case .monthly:
            return "You’ve earned \nUnlimited plot search credit"
        }
    }
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 1. Solid Base Background (#7F31EC)
                FigmaPaymentSuccessTokens.canvasBg
                    .ignoresSafeArea()
                
                // 2. Large Radial Glow Gradient (Node #804:2531)
                RadialGradient(
                    gradient: Gradient(colors: [
                        FigmaPaymentSuccessTokens.radialCenter,
                        FigmaPaymentSuccessTokens.radialEdge
                    ]),
                    center: .center,
                    startRadius: 0,
                    endRadius: 420
                )
                .frame(width: 842.4, height: 842.4)
                .offset(y: -60)
                .allowsHitTesting(false)
                
                // 3. Main Center Composition (Trophy, Shadow, Particles, Typography)
                VStack(spacing: 0) {
                    // Top Close Button Row (Node #804:2533, #804:2534)
                    HStack {
                        Spacer()
                        Button {
                            onDismiss()
                        } label: {
                            ZStack {
                                Circle()
                                    .stroke(FigmaPaymentSuccessTokens.closeBorder, lineWidth: 3.0)
                                    .background(Circle().fill(Color.black.opacity(0.15)))
                                    .frame(width: 49.21, height: 49.21)
                                
                                SubscriptionCloseIcon(
                                    color: .white,
                                    lineWidth: 2.42,
                                    size: 16
                                )
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 24)
                        .padding(.top, 16)
                    }
                    
                    Spacer(minLength: 40)
                    
                    // Central Visual Stack: Particles + Trophy + Shadow
                    ZStack {
                        // Ground Shadow (#804:2532)
                        Ellipse()
                            .fill(FigmaPaymentSuccessTokens.shadowPurple)
                            .frame(width: 152.09, height: 9.36)
                            .blur(radius: 14.9)
                            .opacity(0.72)
                            .offset(y: 140)
                        
                        // Floating Particle 2 (Right, blurred)
                        Image("PaymentSuccessParticle")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 106.55, height: 112.07)
                            .blur(radius: 12)
                            .offset(x: 100, y: 80)
                            .scaleEffect(particlesScale)
                            .opacity(appearAnimation ? 0.9 : 0.0)
                        
                        // Floating Particle 3 (Left, blurred)
                        Image("PaymentSuccessParticle")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 70.47, height: 84.7)
                            .blur(radius: 10)
                            .offset(x: -110, y: -20)
                            .scaleEffect(particlesScale)
                            .opacity(appearAnimation ? 0.85 : 0.0)
                        
                        // Floating Particle 1 (Top Right, slightly blurred)
                        Image("PaymentSuccessParticle")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 54.56, height: 76.64)
                            .blur(radius: 4)
                            .offset(x: 70, y: -100)
                            .scaleEffect(particlesScale)
                            .opacity(appearAnimation ? 0.95 : 0.0)
                        
                        // Central 3D Trophy / Gold Illustration (#804:2539)
                        Image("PaymentSuccessTrophy")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 186.36, height: 279.55)
                            .offset(y: floatingOffset)
                            .scaleEffect(appearAnimation ? 1.0 : 0.4)
                            .opacity(appearAnimation ? 1.0 : 0.0)
                    }
                    .frame(height: 320)
                    
                    Spacer(minLength: 30)
                    
                    // Congratulations Title (#804:2540)
                    Text("Congratulations")
                        .font(.stackSansHeadline(size: 32, weight: .medium))
                        .foregroundColor(FigmaPaymentSuccessTokens.textTitle)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 12)
                        .offset(y: appearAnimation ? 0 : 20)
                        .opacity(appearAnimation ? 1.0 : 0.0)
                    
                    // Subtitle Copy (#804:2541)
                    Text(creditsEarnedCopy)
                        .font(.stackSansHeadline(size: 17.53, weight: .regular))
                        .foregroundColor(FigmaPaymentSuccessTokens.textSubtitle)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 32)
                        .offset(y: appearAnimation ? 0 : 20)
                        .opacity(appearAnimation ? 1.0 : 0.0)
                    
                    Spacer(minLength: 60)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onDismiss()
            }
        }
        .onAppear {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation(.spring(response: 0.6, dampingFraction: 0.72, blendDuration: 0.1)) {
                appearAnimation = true
                particlesScale = 1.0
            }
            // Gentle continuous floating animation
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                floatingOffset = -8
            }
        }
    }
}
