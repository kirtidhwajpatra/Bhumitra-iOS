//
//  CreditNotificationBannerView.swift
//  MyBhoomi
//
//  Adaptive banner providing low-credit warnings (<= 2 credits) and zero-credit exhaustion callout.
//

import SwiftUI

public struct CreditNotificationBannerView: View {
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    public var onUpgradeTapped: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("dismissed_low_credit_level") private var dismissedCreditLevel: Int = -999
    
    public init(onUpgradeTapped: @escaping () -> Void) {
        self.onUpgradeTapped = onUpgradeTapped
    }
    
    private var isVisible: Bool {
        if subscriptionManager.isUnlimited || subscriptionManager.isPremium {
            return false
        }
        let credits = subscriptionManager.remainingPlotCredits
        if credits > 2 {
            return false
        }
        if credits == 0 {
            return true // Zero-credit exhaustion banner is always visible when at 0
        }
        // At 1 or 2 credits, show unless the user dismissed this exact credit level
        return dismissedCreditLevel != credits
    }
    
    public var body: some View {
        if isVisible {
            let credits = subscriptionManager.remainingPlotCredits
            HStack(spacing: 12) {
                // Plot Search / Flame Icon
                ZStack {
                    Circle()
                        .fill(Color(hex: "#7600FF").opacity(0.15))
                        .frame(width: 36, height: 36)
                    
                    if credits == 0 {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(hex: "#7600FF"))
                    } else {
                        FlameIconView(width: 14, height: 19)
                    }
                }
                
                // Message Text
                VStack(alignment: .leading, spacing: 2) {
                    if credits == 0 {
                        Text("No Searches Left")
                            .font(.stackSansHeadline(size: 14, weight: .bold))
                            .foregroundColor(colorScheme == .dark ? .white : Color(hex: "#1A1A1A"))
                        Text("You've used all your plot searches")
                            .font(.stackSansHeadline(size: 12, weight: .regular))
                            .foregroundColor(colorScheme == .dark ? Color(hex: "#A0AEC0") : Color(hex: "#666666"))
                    } else {
                        let title = credits == 1 ? "1 Plot Search Left" : "2 Plot Searches Left"
                        Text(title)
                            .font(.stackSansHeadline(size: 14, weight: .bold))
                            .foregroundColor(colorScheme == .dark ? .white : Color(hex: "#1A1A1A"))
                        Text("Upgrade for unlimited land exploration")
                            .font(.stackSansHeadline(size: 12, weight: .regular))
                            .foregroundColor(colorScheme == .dark ? Color(hex: "#A0AEC0") : Color(hex: "#666666"))
                    }
                }
                
                Spacer()
                
                // CTA Button
                Button(action: onUpgradeTapped) {
                    Text(credits == 0 ? "Unlock" : "Upgrade")
                        .font(.stackSansHeadline(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color(hex: "#7600FF"))
                        )
                }
                
                // Dismiss Button (only for low credit warnings 1 & 2, not for 0)
                if credits > 0 {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            dismissedCreditLevel = credits
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(colorScheme == .dark ? Color(hex: "#718096") : Color(hex: "#A0AEC0"))
                            .padding(6)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(colorScheme == .dark ? Color(hex: "#1F1B2E").opacity(0.92) : Color.white.opacity(0.95))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color(hex: "#7600FF").opacity(colorScheme == .dark ? 0.35 : 0.2), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.08), radius: 8, x: 0, y: 3)
            .transition(.asymmetric(
                insertion: .move(edge: .top).combined(with: .opacity),
                removal: .move(edge: .top).combined(with: .opacity)
            ))
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: credits)
        }
    }
}
