import SwiftUI
import StoreKit

// ============================================================
// MARK: - BHUMITRA SUBSCRIPTION PAYWALL (3-TIER REQUIREMENT CARDS)
// ============================================================

public struct SubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    
    @State private var selectedTier: ProductTier = .lifetime // Default: Deep Research / Unlimited
    @State private var isPurchasing: Bool = false
    @State private var errorMessage: String? = nil
    @State private var successMessage: String? = nil
    
    public init() {}
    
    // MARK: - Dynamic Theme Palette
    
    private var bgCanvas: Color {
        colorScheme == .dark ? Color(red: 16/255, green: 16/255, blue: 18/255) : Color(red: 241/255, green: 241/255, blue: 241/255)
    }
    
    private var primaryTextColor: Color {
        colorScheme == .dark ? Color.white : Color(red: 18/255, green: 18/255, blue: 20/255)
    }
    
    private var tagTextColor: Color {
        colorScheme == .dark ? Color(white: 0.72) : Color(red: 70/255, green: 70/255, blue: 75/255)
    }
    
    private var priceTextColor: Color {
        colorScheme == .dark ? Color(white: 0.82) : Color(red: 50/255, green: 50/255, blue: 55/255)
    }
    
    private var currencyTextColor: Color {
        colorScheme == .dark ? Color(white: 0.65) : Color(red: 70/255, green: 70/255, blue: 75/255)
    }
    
    private var badgeBgColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.06)
    }
    
    private var badgeTextColor: Color {
        colorScheme == .dark ? Color(white: 0.88) : Color(red: 75/255, green: 75/255, blue: 80/255)
    }
    
    private var dismissIconColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.85) : Color.black.opacity(0.65)
    }
    
    private var payButtonBg: Color {
        colorScheme == .dark ? Color.white : Color.black
    }
    
    private var payButtonText: Color {
        colorScheme == .dark ? Color.black : Color.white
    }
    
    private var footerLinkColor: Color {
        colorScheme == .dark ? Color(white: 0.55) : Color(red: 120/255, green: 120/255, blue: 125/255)
    }
    
    public var body: some View {
        ZStack {
            // Adaptive Canvas Background (Deep obsidian in Dark mode, Crisp neutral in Light mode)
            bgCanvas
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top Header Bar with Liquid Glass Dismiss Button
                HStack {
                    Spacer()
                    Button(action: {
                        Theme.haptic(.light)
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(dismissIconColor)
                            .frame(width: 48, height: 48)
                            .glassEffect(
                                .regular.interactive(),
                                in: .circle
                            )
                    }
                    .padding(.trailing, 20)
                    .padding(.top, 10)
                }
                
                Spacer(minLength: 14)
                
                // Centered Main Title (Clean Regular Weight, Theme Reactive)
                Text("Choose your best\nrequirement")
                    .font(.system(size: 28, weight: .regular, design: .default))
                    .foregroundColor(primaryTextColor)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 24)
                
                Spacer(minLength: 18)
                
                // 3 Native Liquid Glass Requirement Cards (Unclipped Tactile Bounce)
                VStack(spacing: 14) {
                    // TIER 1: Quick (10 Plots Search)
                    tierCardView(
                        tier: .tenPlots,
                        tagText: "Quick ⚡",
                        title: "10 Plots Search",
                        price: priceFor(tier: .tenPlots, fallback: "99"),
                        badgeText: nil
                    )
                    
                    // TIER 2: Good Enough (50 Plots Search)
                    tierCardView(
                        tier: .fiftyPlots,
                        tagText: "Good Enough 📦",
                        title: "50 Plots Search",
                        price: priceFor(tier: .fiftyPlots, fallback: "299"),
                        badgeText: "60% Saving"
                    )
                    
                    // TIER 3: Deep Research (Unlimited Plot Search)
                    tierCardView(
                        tier: .lifetime,
                        tagText: "Deep Research 👍",
                        title: "Unlimited Plot Search",
                        price: priceFor(tier: .lifetime, fallback: "1999"),
                        badgeText: "No interruption"
                    )
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 4)
                
                Spacer(minLength: 24)
                
                // Bottom Checkout Button & Legal Footer
                VStack(spacing: 12) {
                    // Adaptive Capsule Pay Button (White in Dark mode, Black in Light mode)
                    Button(action: handlePurchase) {
                        HStack(spacing: 8) {
                            if isPurchasing || subscriptionManager.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: payButtonText))
                            } else {
                                Text("Pay")
                                    .font(.system(size: 19, weight: .semibold))
                                    .foregroundColor(payButtonText)
                            }
                        }
                        .frame(width: 290, height: 54)
                        .background(payButtonBg, in: Capsule())
                        .clipShape(Capsule())
                        .shadow(color: (colorScheme == .dark ? Color.white : Color.black).opacity(0.16), radius: 10, x: 0, y: 5)
                    }
                    .buttonStyle(TactileGlassButtonStyle())
                    .disabled(isPurchasing || subscriptionManager.isLoading)
                    
                    // Error/Success Message
                    if let error = errorMessage {
                        Text(error)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    } else if let success = successMessage {
                        Text(success)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.green)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    
                    // Footer Links
                    HStack(spacing: 8) {
                        Button("Restore purchases") {
                            handleRestore()
                        }
                        
                        Text("•")
                        
                        Button("Terms of Service") {
                            if let url = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/") {
                                openURL(url)
                            }
                        }
                        
                        Text("•")
                        
                        Button("Privacy Policy") {
                            if let url = URL(string: "https://kirtidhwajpatra.github.io/Bhumitra_PrivacyPolicy/") {
                                openURL(url)
                            }
                        }
                    }
                    .font(.system(size: 10.5, weight: .regular))
                    .foregroundColor(footerLinkColor)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 14)
                }
            }
        }
    }
    
    // MARK: - Tier Card Builder
    
    private func tierCardView(
        tier: ProductTier,
        tagText: String,
        title: String,
        price: String,
        badgeText: String?
    ) -> some View {
        let isSelected = (selectedTier == tier)
        let shape = RoundedRectangle(cornerRadius: 26, style: .continuous)
        
        return VStack(alignment: .leading, spacing: 12) {
            // Top Tag & Accessory Row
            HStack(alignment: .center) {
                Text(tagText)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(tagTextColor)
                
                Spacer()
                
                if let badgeText = badgeText {
                    Text(badgeText)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(badgeTextColor)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3.5)
                        .background(badgeBgColor)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(colorScheme == .dark ? Color.white : Color.black)
                        .frame(width: 22, height: 22)
                        .background(colorScheme == .dark ? Color.white.opacity(0.18) : Color.black.opacity(0.07))
                        .clipShape(Circle())
                }
            }
            
            // Main Title (Emphasized) & Price Row (Secondary)
            HStack(alignment: .lastTextBaseline) {
                Text(title)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(primaryTextColor)
                
                Spacer()
                
                HStack(alignment: .top, spacing: 1.5) {
                    Text("₹")
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundColor(currencyTextColor)
                        .offset(y: 2)
                    
                    Text(price)
                        .font(.system(size: 23, weight: .regular, design: .default))
                        .foregroundColor(priceTextColor)
                }
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 17)
        .glassEffect(
            .regular.interactive(),
            in: shape
        )
        .overlay {
            shape.stroke(
                isSelected ? (colorScheme == .dark ? Color.white.opacity(0.90) : Color.black.opacity(0.88)) : (colorScheme == .dark ? Color.white.opacity(0.12) : Color.white.opacity(0.60)),
                lineWidth: isSelected ? 1.5 : 1.0
            )
        }
        .contentShape(shape)
        .shadow(color: Color.black.opacity(isSelected ? (colorScheme == .dark ? 0.28 : 0.09) : 0.03), radius: isSelected ? 14 : 6, x: 0, y: isSelected ? 6 : 2)
        .scaleEffect(isSelected ? 1.03 : 0.975)
        .opacity(isSelected ? 1.0 : (colorScheme == .dark ? 0.82 : 0.92))
        .onTapGesture {
            Theme.haptic(.medium)
            withAnimation(.spring(response: 0.34, dampingFraction: 0.68)) {
                selectedTier = tier
            }
        }
    }
    
    // MARK: - Price Helpers
    
    private var currentPriceNumber: String {
        switch selectedTier {
        case .tenPlots: return priceFor(tier: .tenPlots, fallback: "99")
        case .fiftyPlots: return priceFor(tier: .fiftyPlots, fallback: "299")
        case .lifetime: return priceFor(tier: .lifetime, fallback: "1999")
        case .monthly: return "99"
        case .yearly: return "799"
        }
    }
    
    private func priceFor(tier: ProductTier, fallback: String) -> String {
        switch tier {
        case .tenPlots:
            if let p = subscriptionManager.tenPlotsProduct {
                return p.displayPrice.replacingOccurrences(of: "₹", with: "").trimmingCharacters(in: .whitespaces)
            }
        case .fiftyPlots:
            if let p = subscriptionManager.fiftyPlotsProduct {
                return p.displayPrice.replacingOccurrences(of: "₹", with: "").trimmingCharacters(in: .whitespaces)
            }
        case .lifetime:
            if let p = subscriptionManager.lifetimeProduct {
                return p.displayPrice.replacingOccurrences(of: "₹", with: "").trimmingCharacters(in: .whitespaces)
            }
        default:
            break
        }
        return fallback
    }
    
    // MARK: - Actions
    
    private func handlePurchase() {
        Theme.haptic(.medium)
        isPurchasing = true
        errorMessage = nil
        successMessage = nil
        
        Task {
            let result = await subscriptionManager.purchaseTier(selectedTier)
            await MainActor.run {
                isPurchasing = false
                switch result {
                case .success:
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    successMessage = "Thank you! Your access is now activated."
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        dismiss()
                    }
                case .failure(let error):
                    if (error as NSError).code != SKError.paymentCancelled.rawValue {
                        Theme.haptic(.medium)
                        errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }
    
    private func handleRestore() {
        Theme.haptic(.light)
        isPurchasing = true
        errorMessage = nil
        successMessage = nil
        
        Task {
            await subscriptionManager.restorePurchases()
            await MainActor.run {
                isPurchasing = false
                if subscriptionManager.isPremium {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    successMessage = "Purchases restored successfully."
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        dismiss()
                    }
                } else {
                    errorMessage = "No active subscription found to restore."
                }
            }
        }
    }
}

#Preview {
    SubscriptionView()
}
