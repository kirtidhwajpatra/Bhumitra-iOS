import SwiftUI
import StoreKit

// ============================================================
// MARK: - BHUMITRA SUBSCRIPTION PAYWALL (3-TIER REQUIREMENT CARDS)
// ============================================================

public struct SubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    
    @State private var selectedTier: ProductTier = .lifetime // Default: Deep Research / Unlimited
    @State private var isPurchasing: Bool = false
    @State private var errorMessage: String? = nil
    @State private var successMessage: String? = nil
    
    public init() {}
    
    public var body: some View {
        ZStack {
            // Light neutral canvas background (#F1F1F1)
            Color(red: 241/255, green: 241/255, blue: 241/255)
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
                            .foregroundColor(Color.black.opacity(0.65))
                            .frame(width: 40, height: 40)
                            .glassEffect(
                                .regular.interactive(),
                                in: .circle
                            )
                    }
                    .padding(.trailing, 20)
                    .padding(.top, 10)
                }
                
                Spacer(minLength: 8)
                
                // Centered Main Title
                Text("Choose your best\nrequirement")
                    .font(.system(size: 28, weight: .bold, design: .default))
                    .foregroundColor(Color(red: 18/255, green: 18/255, blue: 20/255))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .padding(.horizontal, 24)
                
                Spacer(minLength: 24)
                
                // 3 Tiered Requirement Cards
                VStack(spacing: 16) {
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
                .padding(.horizontal, 24)
                
                Spacer(minLength: 28)
                
                // Bottom Checkout Button & Legal Footer
                VStack(spacing: 14) {
                    // Pay Button
                    Button(action: handlePurchase) {
                        HStack(spacing: 8) {
                            if isPurchasing || subscriptionManager.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Pay ₹\(currentPriceNumber)")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 58)
                        .background(Color.black)
                        .clipShape(Capsule())
                        .shadow(color: Color.black.opacity(0.20), radius: 12, x: 0, y: 6)
                    }
                    .buttonStyle(TactileGlassButtonStyle())
                    .disabled(isPurchasing || subscriptionManager.isLoading)
                    .padding(.horizontal, 24)
                    
                    // Error/Success Message
                    if let error = errorMessage {
                        Text(error)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    } else if let success = successMessage {
                        Text(success)
                            .font(.system(size: 12, weight: .semibold))
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
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundColor(Color(red: 110/255, green: 110/255, blue: 115/255))
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
        
        return Button(action: {
            Theme.haptic(.medium)
            withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                selectedTier = tier
            }
        }) {
            VStack(alignment: .leading, spacing: 14) {
                // Top Tag & Accessory Row
                HStack(alignment: .center) {
                    Text(tagText)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(red: 50/255, green: 50/255, blue: 55/255))
                    
                    Spacer()
                    
                    if let badgeText = badgeText {
                        Text(badgeText)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Color(red: 70/255, green: 70/255, blue: 75/255))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3.5)
                            .background(Color(red: 232/255, green: 234/255, blue: 238/255))
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.black)
                            .frame(width: 22, height: 22)
                            .background(Color(red: 235/255, green: 237/255, blue: 240/255))
                            .clipShape(Circle())
                    }
                }
                
                // Main Title & Price Row
                HStack(alignment: .lastTextBaseline) {
                    Text(title)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundColor(Color(red: 20/255, green: 20/255, blue: 22/255))
                    
                    Spacer()
                    
                    HStack(alignment: .top, spacing: 2) {
                        Text("₹")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(Color(red: 20/255, green: 20/255, blue: 22/255))
                            .offset(y: 2)
                        
                        Text(price)
                            .font(.system(size: 30, weight: .bold, design: .default))
                            .foregroundColor(Color(red: 20/255, green: 20/255, blue: 22/255))
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 18)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(isSelected ? Color.black : Color.black.opacity(0.04), lineWidth: isSelected ? 1.25 : 1)
            )
            .shadow(color: Color.black.opacity(isSelected ? 0.07 : 0.03), radius: isSelected ? 14 : 8, x: 0, y: isSelected ? 6 : 3)
        }
        .buttonStyle(PlainButtonStyle())
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
