import SwiftUI
import StoreKit

public struct SubscriptionView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    
    @State private var isPurchasing = false
    @State private var errorMessage: String? = nil
    @State private var successMessage: String? = nil
    
    let benefits = [
        "Unlimited ownership record access (ROR)",
        "Download & share official cadastral PDFs",
        "Cadastral overlay with high-res satellite imagery",
        "Search all districts, tahsils & villages",
        "Future GIS analytics & premium features included"
    ]
    
    public init() {}
    
    public var body: some View {
        ZStack {
            // Elegant Dark Modern Gradient Background
            LinearGradient(
                colors: [Color(red: 18/255, green: 12/255, blue: 38/255), Color(red: 35/255, green: 22/255, blue: 75/255)],
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
                    VStack(spacing: 28) {
                        // Branding Section
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Theme.neonPurple.opacity(0.18))
                                    .frame(width: 84, height: 84)
                                
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 38))
                                    .foregroundColor(Theme.neonPurple)
                                    .shadow(color: Theme.neonPurple.opacity(0.6), radius: 12)
                            }
                            
                            Text("Upgrade to Premium")
                                .font(.system(size: 28, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                            
                            Text("Unlock unlimited land records, verified cadastral maps, and official reports")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 36)
                        }
                        
                        // Benefits List
                        VStack(alignment: .leading, spacing: 16) {
                            ForEach(benefits, id: \.self) { benefit in
                                HStack(alignment: .top, spacing: 14) {
                                    Image(systemName: "checkmark.seal.fill")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(Theme.neonGreen)
                                    
                                    Text(benefit)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.9))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .padding(22)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(20)
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.08), lineWidth: 1))
                        .padding(.horizontal, 20)
                        
                        // Live StoreKit Pricing Card
                        VStack(spacing: 8) {
                            Text("MONTHLY SUBSCRIPTION")
                                .font(.system(size: 11, weight: .black))
                                .foregroundColor(Theme.neonPurple)
                                .tracking(1.5)
                            
                            HStack(alignment: .bottom, spacing: 4) {
                                if let product = subscriptionManager.monthlyProduct {
                                    Text(product.displayPrice)
                                        .font(.system(size: 40, weight: .black, design: .rounded))
                                        .foregroundColor(.white)
                                } else if subscriptionManager.isLoading {
                                    ProgressView()
                                        .tint(.white)
                                        .frame(height: 48)
                                } else {
                                    Text("₹399")
                                        .font(.system(size: 40, weight: .black, design: .rounded))
                                        .foregroundColor(.white)
                                }
                                
                                Text("/ month")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.6))
                                    .padding(.bottom, 6)
                            }
                            
                            Text("Auto-renews monthly. Cancel anytime in App Store settings.")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .padding(.vertical, 22)
                        .frame(maxWidth: .infinity)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(20)
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.neonPurple.opacity(0.35), lineWidth: 1.5))
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
                                        Text("Subscribe Now")
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
                                Text("Continue with Free Tier")
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
                            Text("Payment will be charged to your Apple ID account at confirmation of purchase. Subscription automatically renews unless cancelled at least 24 hours before the end of the current period. Your account will be charged for renewal within 24 hours prior to the end of the current period. You can manage or cancel your subscriptions in your App Store account settings after purchase.")
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.35))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 16)
                            
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
                        .padding(.top, 10)
                        .padding(.bottom, 32)
                        .padding(.horizontal, 20)
                    }
                }
            }
        }
        .task {
            // Load StoreKit products when sheet opens
            if subscriptionManager.monthlyProduct == nil {
                await subscriptionManager.loadProducts()
            }
        }
    }
    
    // MARK: - Actions
    
    private func handlePurchase() {
        hapticFeedback(.medium)
        isPurchasing = true
        errorMessage = nil
        successMessage = nil
        
        Task {
            let result = await subscriptionManager.purchaseSubscription()
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
                    successMessage = "Subscription restored successfully."
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
