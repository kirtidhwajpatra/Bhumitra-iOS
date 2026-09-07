//
//  PurchaseSuccessModalView.swift
//  MyBhoomi
//
//  Production-Ready Purchase Success View for Consumables & Subscriptions
//

import SwiftUI

// MARK: - Design Tokens
private enum PaymentSuccessTokens {
    static let primaryPurple = Color(hex: "#7600FF")
    static let canvasBgStart = Color(hex: "#6E07FF")
    static let canvasBgEnd = Color(hex: "#37106D")
    static let pillBg = Color.white.opacity(0.18)
    static let pillBorder = Color.white.opacity(0.35)
    static let closeBorder = Color.white.opacity(0.25)
    
    static let textTitle = Color(hex: "#FFFFFF")
    static let textSubtitle = Color(hex: "#E5D4FF")
    static let textMuted = Color(hex: "#CFA6FF")
}

public struct PurchaseSuccessModalView: View {
    public let tier: ProductTier
    public let onDismiss: () -> Void
    public var onSearchPlot: (() -> Void)? = nil
    
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    
    // Animation States
    @State private var appearAnimation: Bool = false
    @State private var floatingOffset: CGFloat = 0
    @State private var particlesScale: CGFloat = 0.8
    
    public init(
        tier: ProductTier,
        onDismiss: @escaping () -> Void,
        onSearchPlot: (() -> Void)? = nil
    ) {
        self.tier = tier
        self.onDismiss = onDismiss
        self.onSearchPlot = onSearchPlot
    }
    
    // MARK: - Tier-Specific Content
    private var headlineText: String {
        switch tier {
        case .tenPlots:
            return "10 Plot Searches Added!"
        case .fiftyPlots:
            return "50 Plot Searches Added!"
        case .twoHundredPlots:
            return "200 Plot Searches Added!"
        case .monthly:
            return "Unlimited is Active!"
        }
    }
    
    private var subtitleCopy: String {
        switch tier {
        case .tenPlots, .fiftyPlots, .twoHundredPlots:
            return "Your account has been credited. You're ready to search cadastral plots, inspect ownership records, and view land maps."
        case .monthly:
            return "You now have unlimited cadastral plot searches, high-resolution maps, and official land record PDF downloads."
        }
    }
    
    private var balanceBadgeText: String {
        if subscriptionManager.isUnlimited || tier == .monthly {
            return "♾️ Unlimited Plot Searches Active"
        } else {
            let balance = subscriptionManager.remainingPlotCredits
            return "Current Balance: \(balance) Plot \(balance == 1 ? "Search" : "Searches")"
        }
    }
    
    public var body: some View {
        ZStack {
            // 1. Responsive Background Gradient (Always fills entire screen safely)
            LinearGradient(
                stops: [
                    .init(color: PaymentSuccessTokens.canvasBgStart, location: 0.0),
                    .init(color: PaymentSuccessTokens.canvasBgEnd, location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // 2. Subtle Radial Glow (Centered & responsive)
            RadialGradient(
                gradient: Gradient(colors: [
                    Color(hex: "#9B51E0").opacity(0.35),
                    Color.clear
                ]),
                center: .center,
                startRadius: 20,
                endRadius: 260
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)
            
            // 3. Main Scrollable Container (Ensures SE / smaller iPhones fit without clipping)
            VStack(spacing: 0) {
                // Top Close Bar
                HStack {
                    Spacer()
                    Button {
                        Theme.haptic(.light)
                        onDismiss()
                    } label: {
                        ZStack {
                            Circle()
                                .stroke(PaymentSuccessTokens.closeBorder, lineWidth: 1.8)
                                .background(Circle().fill(Color.black.opacity(0.20)))
                                .frame(width: 40, height: 40)
                            
                            SubscriptionCloseIcon(
                                color: .white,
                                lineWidth: 2.2,
                                size: 14
                            )
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 20)
                    .padding(.top, 12)
                }
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        Spacer(minLength: 16)
                        
                        // Central Visual Trophy / Artwork
                        ZStack {
                            // Ground Shadow
                            Ellipse()
                                .fill(Color.black.opacity(0.35))
                                .frame(width: 140, height: 16)
                                .blur(radius: 8)
                                .offset(y: 100)
                            
                            // Floating Particle Background
                            if let particleImg = UIImage(named: "PaymentSuccessParticle") {
                                Image(uiImage: particleImg)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 80, height: 80)
                                    .offset(x: 75, y: -60)
                                    .scaleEffect(particlesScale)
                                    .opacity(appearAnimation ? 0.9 : 0.0)
                                
                                Image(uiImage: particleImg)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 65, height: 65)
                                    .offset(x: -80, y: 30)
                                    .scaleEffect(particlesScale)
                                    .opacity(appearAnimation ? 0.8 : 0.0)
                            }
                            
                            // Central Trophy / Gold Asset
                            if let trophyImg = UIImage(named: "PaymentSuccessTrophy") {
                                Image(uiImage: trophyImg)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxWidth: 160, maxHeight: 200)
                                    .offset(y: floatingOffset)
                                    .scaleEffect(appearAnimation ? 1.0 : 0.6)
                                    .opacity(appearAnimation ? 1.0 : 0.0)
                            } else {
                                // High-Quality Fallback Icon
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 100, weight: .bold))
                                    .foregroundColor(Color(hex: "#FFD700"))
                                    .shadow(color: Color.black.opacity(0.3), radius: 12, x: 0, y: 6)
                                    .offset(y: floatingOffset)
                                    .scaleEffect(appearAnimation ? 1.0 : 0.6)
                                    .opacity(appearAnimation ? 1.0 : 0.0)
                            }
                        }
                        .frame(height: 220)
                        .padding(.bottom, 12)
                        
                        // Congratulations Header
                        Text("Congratulations!")
                            .font(.stackSansHeadline(size: 30, weight: .bold))
                            .foregroundColor(PaymentSuccessTokens.textTitle)
                            .multilineTextAlignment(.center)
                            .padding(.bottom, 6)
                            .offset(y: appearAnimation ? 0 : 15)
                            .opacity(appearAnimation ? 1.0 : 0.0)
                        
                        // Tier Specific Title
                        Text(headlineText)
                            .font(.stackSansHeadline(size: 20, weight: .semibold))
                            .foregroundColor(Color(hex: "#FFE600"))
                            .multilineTextAlignment(.center)
                            .padding(.bottom, 12)
                            .offset(y: appearAnimation ? 0 : 15)
                            .opacity(appearAnimation ? 1.0 : 0.0)
                        
                        // Authoritative Balance Pill
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(Color(hex: "#FFE600"))
                            
                            Text(balanceBadgeText)
                                .font(.stackSansHeadline(size: 14.5, weight: .medium))
                                .foregroundColor(PaymentSuccessTokens.textTitle)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(PaymentSuccessTokens.pillBg)
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(PaymentSuccessTokens.pillBorder, lineWidth: 1)
                        )
                        .padding(.bottom, 16)
                        .offset(y: appearAnimation ? 0 : 15)
                        .opacity(appearAnimation ? 1.0 : 0.0)
                        
                        // Descriptive Body Copy
                        Text(subtitleCopy)
                            .font(.system(size: 14.5, weight: .regular, design: .rounded))
                            .foregroundColor(PaymentSuccessTokens.textSubtitle)
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                            .padding(.horizontal, 28)
                            .padding(.bottom, 28)
                            .offset(y: appearAnimation ? 0 : 15)
                            .opacity(appearAnimation ? 1.0 : 0.0)
                        
                        Spacer(minLength: 16)
                    }
                    .frame(maxWidth: .infinity)
                }
                
                // Bottom Fixed Action Area
                VStack(spacing: 12) {
                    // Primary CTA: "Search a Plot"
                    Button {
                        Theme.haptic(.medium)
                        if let searchAction = onSearchPlot {
                            searchAction()
                        } else {
                            onDismiss()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 16, weight: .bold))
                            
                            Text("Search a Plot")
                                .font(.stackSansHeadline(size: 18, weight: .bold))
                        }
                        .foregroundColor(PaymentSuccessTokens.primaryPurple)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Color.white)
                        .cornerRadius(27)
                        .shadow(color: Color.black.opacity(0.18), radius: 10, x: 0, y: 4)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 28)
                    
                    // Secondary CTA: "Done"
                    Button {
                        Theme.selectionHaptic()
                        onDismiss()
                    } label: {
                        Text("Done")
                            .font(.stackSansHeadline(size: 15.5, weight: .medium))
                            .foregroundColor(PaymentSuccessTokens.textSubtitle)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 8)
                }
                .padding(.top, 8)
                .background(
                    LinearGradient(
                        colors: [
                            PaymentSuccessTokens.canvasBgEnd.opacity(0.0),
                            PaymentSuccessTokens.canvasBgEnd.opacity(0.92),
                            PaymentSuccessTokens.canvasBgEnd
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea(edges: .bottom)
                )
            }
        }
        .onAppear {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation(.spring(response: 0.55, dampingFraction: 0.75)) {
                appearAnimation = true
                particlesScale = 1.0
            }
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                floatingOffset = -6
            }
        }
    }
}
