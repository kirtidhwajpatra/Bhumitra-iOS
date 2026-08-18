import SwiftUI

struct SubscriptionView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var successMessage: String? = nil
    
    let benefits = [
        "Unlimited ownership record access",
        "Advanced property insights (history, valuation)",
        "Download & share official documents (PDFs)",
        "Future premium features included"
    ]
    
    var body: some View {
        ZStack {
            // Elegant Dark Purple Gradient Background
            LinearGradient(
                colors: [Color(red: 20/255, green: 10/255, blue: 45/255), Color(red: 40/255, green: 20/255, blue: 90/255)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Close Button Header
                HStack {
                    Spacer()
                    Button(action: {
                        hapticFeedback(.light)
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white.opacity(0.3))
                    }
                    .padding(.trailing, 20)
                    .padding(.top, 16)
                }
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 32) {
                        // Branding Section
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Theme.neonPurple.opacity(0.15))
                                    .frame(width: 80, height: 80)
                                
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 36))
                                    .foregroundColor(Theme.neonPurple)
                                    .shadow(color: Theme.neonPurple.opacity(0.5), radius: 8)
                            }
                            
                            Text("Upgrade to Premium")
                                .font(.system(size: 28, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                            
                            Text("Unlock complete GIS tools and unlimited property records")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                        
                        // Benefits List
                        VStack(alignment: .leading, spacing: 18) {
                            ForEach(benefits, id: \.self) { benefit in
                                HStack(alignment: .top, spacing: 14) {
                                    Image(systemName: "checkmark.seal.fill")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(Theme.neonGreen)
                                    
                                    Text(benefit)
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(.white.opacity(0.85))
                                }
                            }
                        }
                        .padding(24)
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(22)
                        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.white.opacity(0.08), lineWidth: 1))
                        .padding(.horizontal, 24)
                        
                        // Pricing Card
                        VStack(spacing: 8) {
                            Text("PREMIUM MONTHLY")
                                .font(.system(size: 11, weight: .black))
                                .foregroundColor(Theme.neonPurple)
                                .tracking(1.5)
                            
                            HStack(alignment: .bottom, spacing: 4) {
                                Text("₹399")
                                    .font(.system(size: 44, weight: .black, design: .rounded))
                                    .foregroundColor(.white)
                                
                                Text("/ month")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.5))
                                    .padding(.bottom, 8)
                            }
                            
                            Text("Auto-renews monthly. Cancel anytime.")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.4))
                        }
                        .padding(.vertical, 24)
                        .frame(maxWidth: .infinity)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(22)
                        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.neonPurple.opacity(0.3), lineWidth: 1.5))
                        .padding(.horizontal, 24)
                        
                        // CTA Buttons
                        VStack(spacing: 16) {
                            Button(action: handleUpgrade) {
                                HStack {
                                    if isLoading {
                                        ProgressView().tint(.white)
                                    } else {
                                        Text("Upgrade Now")
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
                            .disabled(isLoading)
                            .padding(.horizontal, 24)
                            
                            Button(action: {
                                hapticFeedback(.light)
                                dismiss()
                            }) {
                                Text("Continue with Free Plan")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }
                        
                        // Footer Restore Purchases
                        HStack(spacing: 20) {
                            Button("Restore Purchases") {
                                handleRestore()
                            }
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white.opacity(0.4))
                        }
                        .padding(.bottom, 32)
                        
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
                                .foregroundColor(.green)
                                .padding(.horizontal, 30)
                                .multilineTextAlignment(.center)
                        }
                    }
                }
            }
        }
    }
    
    private func handleUpgrade() {
        hapticFeedback(.medium)
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        Task {
            let result = await subscriptionManager.purchaseSubscription()
            await MainActor.run {
                isLoading = false
                switch result {
                case .success:
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    successMessage = "Congratulations! Premium features unlocked."
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
    
    private func handleRestore() {
        hapticFeedback(.medium)
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        Task {
            let result = await subscriptionManager.restorePurchases()
            await MainActor.run {
                isLoading = false
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
extension UIImpactFeedbackGenerator {
    func impactOccurredWithIntensity(_ intensity: CGFloat) {
        self.impactOccurred(intensity: intensity)
    }
}
extension UINotificationFeedbackGenerator {
    func notificationOccurredWithType(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        self.notificationOccurred(type)
    }
}
