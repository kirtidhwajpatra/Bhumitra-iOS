import SwiftUI
import StoreKit

public struct SubscriptionView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    
    @State private var selectedTier: ProductTier = .yearly
    @State private var isPurchasing = false
    @State private var errorMessage: String? = nil
    @State private var successMessage: String? = nil
    
    let benefits = [
        "Unlimited ownership record access (ROR)",
        "Download & share official cadastral PDFs",
        "Cadastral overlay with high-res satellite imagery",
        "Search all districts, tahsils & villages",
        "Future GIS analytics & tools included"
    ]
    
    public init() {}
    
    public var body: some View {
        ZStack {
            // Elegant Dark Purple Modern Gradient Background
            LinearGradient(
                colors: [Color(red: 16/255, green: 10/255, blue: 34/255), Color(red: 32/255, green: 18/255, blue: 68/255)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header Close Button
                HStack {
                    Spacer()
                    Button(action: {
                        hapticFeedback(.light)
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white.opacity(0.35))
                    }
                    .padding(.trailing, 20)
                    .padding(.top, 16)
                }
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Branding Section
                        VStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(Theme.neonPurple.opacity(0.2))
                                    .frame(width: 76, height: 76)
                                
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 34))
                                    .foregroundColor(Theme.neonPurple)
                                    .shadow(color: Theme.neonPurple.opacity(0.6), radius: 12)
                            }
                            
                            Text("Upgrade to Bhumitra Premium")
                                .font(.system(size: 24, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                            
                            Text("Unlock complete GIS tools, legal ROR ownership records, and official PDF downloads")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                        
                        // Benefits List
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(benefits, id: \.self) { benefit in
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: "checkmark.seal.fill")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(Theme.neonGreen)
                                    
                                    Text(benefit)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.9))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .padding(18)
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(18)
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.08), lineWidth: 1))
                        .padding(.horizontal, 20)
                        
                        // Tier Selection Cards
                        VStack(spacing: 12) {
                            tierCard(
                                tier: .yearly,
                                product: subscriptionManager.yearlyProduct,
                                subtitle: "Best value. Renews yearly.",
                                breakdownText: yearlyMonthlyBreakdown
                            )
                            
                            tierCard(
                                tier: .monthly,
                                product: subscriptionManager.monthlyProduct,
                                subtitle: "Renews monthly. Cancel anytime."
                            )
                            
                            tierCard(
                                tier: .lifetime,
                                product: subscriptionManager.lifetimeProduct,
                                subtitle: "One-time purchase. Lifetime access."
                            )
                        }
                        .padding(.horizontal, 20)
                        
                        // Status Messages
                        if let error = errorMessage {
                            Text(error)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.red)
                                .padding(.horizontal, 30)
                                .multilineTextAlignment(.center)
                        }
                        
                        if let success = successMessage {
                            Text(success)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Theme.neonGreen)
                                .padding(.horizontal, 30)
                                .multilineTextAlignment(.center)
                        }
                        
                        // CTA Buttons
                        VStack(spacing: 14) {
                            Button(action: handlePurchase) {
                                HStack {
                                    if isPurchasing || subscriptionManager.isLoading {
                                        ProgressView().tint(.white)
                                    } else {
                                        Text(ctaButtonTitle)
                                            .font(.system(size: 16, weight: .bold))
                                    }
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(
                                    LinearGradient(
                                        colors: [Theme.neonPurple, Color(red: 140/255, green: 30/255, blue: 230/255)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .cornerRadius(16)
                                .shadow(color: Theme.neonPurple.opacity(0.4), radius: 15, y: 5)
                            }
                            .disabled(isPurchasing || subscriptionManager.isLoading)
                            .padding(.horizontal, 20)
                            
                            Button(action: {
                                hapticFeedback(.light)
                                dismiss()
                            }) {
                                Text("Continue with Free Plan")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }
                        
                        // Restore Purchases & Legal Disclosures (App Store Guidelines Compliant)
                        VStack(spacing: 12) {
                            Button("Restore Purchases") {
                                handleRestore()
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                            
                            // Auto-Renewal Disclosure
                            if selectedTier != .lifetime {
                                Text("Payment will be charged to your Apple ID account at confirmation of purchase. Subscription automatically renews unless cancelled at least 24 hours before the end of the current period. Manage or cancel anytime in App Store Settings.")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.35))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 16)
                            }
                            
                            // Legal Links
                            HStack(spacing: 16) {
                                Link("Terms of Use (EULA)", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.white.opacity(0.4))
                                
                                Text("•")
                                    .font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.3))
                                
                                Link("Privacy Policy", destination: URL(string: "https://kirtidhwajpatra.github.io/privacy-policy")!)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.white.opacity(0.4))
                            }
                        }
                        .padding(.top, 6)
                        .padding(.bottom, 32)
                        .padding(.horizontal, 20)
                    }
                }
            }
        }
        .task {
            // Load StoreKit products when sheet opens
            if subscriptionManager.products.isEmpty {
                await subscriptionManager.loadProducts()
            }
        }
    }
    
    // MARK: - Subviews
    
    private func tierCard(
        tier: ProductTier,
        product: Product?,
        subtitle: String,
        breakdownText: String? = nil
    ) -> some View {
        let isSelected = selectedTier == tier
        
        return Button(action: {
            hapticFeedback(.light)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedTier = tier
            }
        }) {
            HStack(spacing: 14) {
                // Radio indicator
                ZStack {
                    Circle()
                        .stroke(isSelected ? Theme.neonPurple : Color.white.opacity(0.2), lineWidth: 2)
                        .frame(width: 22, height: 22)
                    
                    if isSelected {
                        Circle()
                            .fill(Theme.neonPurple)
                            .frame(width: 12, height: 12)
                    }
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(tier.title)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        if let badge = tier.badge {
                            Text(badge)
                                .font(.system(size: 9, weight: .black))
                                .foregroundColor(.black)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Theme.neonGreen)
                                .clipShape(Capsule())
                        }
                    }
                    
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.5))
                }
                
                Spacer()
                
                // Dynamic Price
                VStack(alignment: .trailing, spacing: 2) {
                    if let product = product {
                        Text(product.displayPrice)
                            .font(.system(size: 17, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                    } else if subscriptionManager.isLoading {
                        ProgressView().tint(.white).scaleEffect(0.7)
                    } else {
                        Text("--")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    
                    if let breakdown = breakdownText {
                        Text(breakdown)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Theme.neonGreen)
                    }
                }
            }
            .padding(16)
            .background(isSelected ? Color.white.opacity(0.09) : Color.white.opacity(0.03))
            .cornerRadius(18)
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(isSelected ? Theme.neonPurple : Color.white.opacity(0.08), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(ScaledButtonStyle())
    }
    
    private var yearlyMonthlyBreakdown: String? {
        guard let yearly = subscriptionManager.yearlyProduct else { return nil }
        // Compute approximate monthly breakdown from yearly price
        let price = yearly.price
        let monthlyEquiv = price / 12
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = yearly.priceFormatStyle.locale
        if let formatted = formatter.string(from: monthlyEquiv as NSDecimalNumber) {
            return "\(formatted)/mo"
        }
        return nil
    }
    
    private var ctaButtonTitle: String {
        switch selectedTier {
        case .monthly: return "Subscribe Monthly"
        case .yearly: return "Subscribe Yearly (Best Value)"
        case .lifetime: return "Unlock Lifetime Access"
        }
    }
    
    // MARK: - Actions
    
    private func handlePurchase() {
        hapticFeedback(.medium)
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
                    successMessage = "Congratulations! Premium features unlocked."
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        dismiss()
                    }
                case .failure(let error):
                    if (error as NSError).code != 0 { // Don't show error if user cancelled
                        hapticFeedback(.medium)
                        errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }
    
    private func handleRestore() {
        hapticFeedback(.medium)
        isPurchasing = true
        errorMessage = nil
        successMessage = nil
        
        Task {
            let result = await subscriptionManager.restorePurchases()
            await MainActor.run {
                isPurchasing = false
                switch result {
                case .success:
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    successMessage = "Purchases restored successfully."
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        dismiss()
                    }
                case .failure(let error):
                    hapticFeedback(.medium)
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
