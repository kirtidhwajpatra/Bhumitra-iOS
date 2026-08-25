import SwiftUI
import StoreKit

// ============================================================
// MARK: - BHUMITRA SUBSCRIPTION VIEW (PRO & QUICK TABS)
// ============================================================

/// Full-screen subscription and plot-pack paywall with swipeable tabs between
/// Bhumitra Pro (Monthly Unlimited) and Bhumitra Quick (10 Plot Pack), featuring
/// full Light & Dark mode adaptation and Google Sans typography.
public struct SubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    
    @State private var selectedTab: Int = 0 // 0: Pro, 1: Quick
    @State private var isPurchasing: Bool = false
    @State private var errorMessage: String? = nil
    @State private var successMessage: String? = nil
    @State private var visibleFeatureIndices: Set<Int> = []
    
    // Feature item model
    private struct FeatureRowItem: Identifiable {
        let id = UUID()
        let icon: String
        let iconColor: Color
        let title: String
        let description: String
    }
    
    // Plan 1: Bhumitra Pro (Monthly Unlimited) Features
    private let proFeatures: [FeatureRowItem] = [
        FeatureRowItem(
            icon: "bolt.fill",
            iconColor: Color(red: 255/255, green: 215/255, blue: 0/255), // Vibrant Gold
            title: "Priority RoR & Plot Access",
            description: "Instant access to official Odisha land records, tenant details, and khata search without limits."
        ),
        FeatureRowItem(
            icon: "flame.fill",
            iconColor: Color(red: 255/255, green: 140/255, blue: 0/255), // Radiant Orange
            title: "High-Res Cadastral Overlays",
            description: "High-resolution satellite imagery paired with live vector parcel boundaries and Kissam classifications."
        ),
        FeatureRowItem(
            icon: "hare.fill",
            iconColor: Color(red: 255/255, green: 75/255, blue: 110/255), // Coral Rose
            title: "Instant PDF Exports & AJA Shield",
            description: "Export official verified Khatiyan summaries and instantly detect Government (AJA/Gochar) vs Private land."
        )
    ]
    
    // Plan 2: Bhumitra Quick (10 Plot Pack) Features
    private let quickFeatures: [FeatureRowItem] = [
        FeatureRowItem(
            icon: "bolt.fill",
            iconColor: Color(red: 255/255, green: 215/255, blue: 0/255), // Vibrant Gold
            title: "10 Plot Searches & RoR Access",
            description: "Instant access to official Odisha land records, tenant details, and khata search for any 10 plots."
        ),
        FeatureRowItem(
            icon: "flame.fill",
            iconColor: Color(red: 255/255, green: 140/255, blue: 0/255), // Radiant Orange
            title: "Full Cadastral Layer Access",
            description: "High-resolution satellite view with live vector parcel boundaries and area for all 10 plots."
        ),
        FeatureRowItem(
            icon: "hare.fill",
            iconColor: Color(red: 255/255, green: 75/255, blue: 110/255), // Coral Rose
            title: "Instant PDF Downloads",
            description: "Download authenticated Khatiyan summary reports with one-time pass validity anytime."
        )
    ]
    
    public init() {}
    
    // MARK: - Dynamic Theme Colors
    
    private var bgCanvas: Color {
        colorScheme == .dark ? Color.black : Color(white: 0.98)
    }
    
    private var primaryTextColor: Color {
        colorScheme == .dark ? Color.white : Color(red: 0.08, green: 0.08, blue: 0.10)
    }
    
    private var secondaryTextColor: Color {
        colorScheme == .dark ? Color(white: 0.65) : Color(white: 0.42)
    }
    
    private var legalTextColor: Color {
        colorScheme == .dark ? Color(white: 0.45) : Color(white: 0.52)
    }
    
    private var legalDotColor: Color {
        colorScheme == .dark ? Color(white: 0.30) : Color(white: 0.72)
    }
    
    public var body: some View {
        ZStack {
            // 1. Adaptive Canvas Background (Pure Black in Dark Mode, Pure Crisp Light in Light Mode)
            bgCanvas
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 2. Top Header: Segment Tab Switcher + Cancel Button
                HStack(alignment: .center) {
                    // Page Dots Indicator for Pro vs Quick
                    HStack(spacing: 6) {
                        ForEach(0..<2) { idx in
                            Capsule()
                                .fill(selectedTab == idx ? Color.accentColor : secondaryTextColor.opacity(0.30))
                                .frame(width: selectedTab == idx ? 18 : 6, height: 6)
                                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: selectedTab)
                        }
                    }
                    .padding(.leading, 24)
                    
                    Spacer()
                    
                    // Top-Right Cancel Button matching KhatianDetailView (.buttonStyle(.glass))
                    Button {
                        Theme.haptic(.light)
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16.5, weight: .bold))
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.glass)
                    .accessibilityLabel("Close")
                    .padding(.trailing, 20)
                }
                .padding(.top, 14)
                
                // 3. Swipeable Plan Pager (Bhumitra Pro <-> Bhumitra Quick)
                TabView(selection: $selectedTab) {
                    // TAB 0: Bhumitra Pro (Monthly Unlimited)
                    planContentView(
                        headline: "Bhumitra Pro",
                        badge: "MONTHLY UNLIMITED",
                        features: proFeatures
                    )
                    .tag(0)
                    
                    // TAB 1: Bhumitra Quick (10 Plot Pack)
                    planContentView(
                        headline: "Bhumitra Quick",
                        badge: "10 PLOT PACK",
                        features: quickFeatures
                    )
                    .tag(1)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.25), value: selectedTab)
                
                // 4. Status Messages
                if let error = errorMessage {
                    Text(error)
                        .font(.googleSans(size: 12, weight: .semibold))
                        .foregroundColor(.red)
                        .padding(.horizontal, 30)
                        .padding(.bottom, 8)
                        .multilineTextAlignment(.center)
                }
                
                if let success = successMessage {
                    Text(success)
                        .font(.googleSans(size: 12, weight: .semibold))
                        .foregroundColor(Theme.neonGreen)
                        .padding(.horizontal, 30)
                        .padding(.bottom, 8)
                        .multilineTextAlignment(.center)
                }
                
                // 5. Bottom Pricing Disclosure & Plot Card Matched CTA Button (.buttonStyle(.glassProminent))
                VStack(spacing: 14) {
                    // Pricing Disclosure Text
                    Text(disclosureText)
                        .font(.googleSans(size: 13, weight: .regular))
                        .foregroundColor(secondaryTextColor)
                        .animation(.easeInOut(duration: 0.2), value: selectedTab)
                    
                    // Full-Width Primary CTA matching CadastralPlotCardView (.glassProminent + .tint)
                    Button {
                        handlePurchase()
                    } label: {
                        HStack(spacing: 8) {
                            if isPurchasing || subscriptionManager.isLoading {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(0.85)
                            } else {
                                Text(ctaTitle)
                                    .font(Theme.Typography.button)
                                    .lineLimit(1)
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(Color.accentColor)
                    .disabled(isPurchasing || subscriptionManager.isLoading)
                    .opacity((isPurchasing || subscriptionManager.isLoading) ? 0.65 : 1.0)
                    .padding(.horizontal, 24)
                    
                    // Restore & Legal Links
                    HStack(spacing: 8) {
                        Button("Restore purchases") {
                            handleRestore()
                        }
                        .font(.googleSans(size: 11, weight: .medium))
                        .foregroundColor(legalTextColor)
                        
                        Text("•")
                            .font(.googleSans(size: 11, weight: .regular))
                            .foregroundColor(legalDotColor)
                        
                        Link("Terms of Service", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                            .font(.googleSans(size: 11, weight: .medium))
                            .foregroundColor(legalTextColor)
                        
                        Text("•")
                            .font(.googleSans(size: 11, weight: .regular))
                            .foregroundColor(legalDotColor)
                        
                        Link("Privacy Policy", destination: URL(string: "https://kirtidhwajpatra.github.io/Bhumitra_PrivacyPolicy/")!)
                            .font(.googleSans(size: 11, weight: .medium))
                            .foregroundColor(legalTextColor)
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 24)
                }
            }
        }
        .onAppear {
            animateFeaturesSequentially()
        }
        .onChange(of: selectedTab) {
            Theme.haptic(.light)
            animateFeaturesSequentially()
        }
        .task {
            if subscriptionManager.products.isEmpty {
                await subscriptionManager.loadProducts()
            }
        }
    }
    
    // MARK: - Plan Page View Builder
    
    private func planContentView(headline: String, badge: String, features: [FeatureRowItem]) -> some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 34) {
                // Headline & Sub-Badge
                VStack(spacing: 6) {
                    Text(headline)
                        .font(.googleSans(size: 32, weight: .bold))
                        .foregroundColor(primaryTextColor)
                        .multilineTextAlignment(.center)
                    
                    Text(badge)
                        .font(.googleSans(size: 10, weight: .bold))
                        .tracking(1.0)
                        .foregroundColor(Color.accentColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3.5)
                        .background(Color.accentColor.opacity(0.12))
                        .clipShape(Capsule())
                }
                
                // Feature Rows with Staggered Slide & Fade Animation
                VStack(alignment: .leading, spacing: 26) {
                    ForEach(Array(features.enumerated()), id: \.element.id) { index, item in
                        HStack(alignment: .top, spacing: 18) {
                            Image(systemName: item.icon)
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(item.iconColor)
                                .frame(width: 28, alignment: .center)
                            
                            VStack(alignment: .leading, spacing: 5) {
                                Text(item.title)
                                    .font(.googleSans(size: 17, weight: .bold))
                                    .foregroundColor(primaryTextColor)
                                
                                Text(item.description)
                                    .font(.googleSans(size: 14.5, weight: .regular))
                                    .foregroundColor(secondaryTextColor)
                                    .lineSpacing(3)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .opacity(visibleFeatureIndices.contains(index) ? 1.0 : 0.0)
                        .offset(y: visibleFeatureIndices.contains(index) ? 0 : 14)
                    }
                }
                .padding(.horizontal, 32)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Price Computations
    
    private var proDisplayPrice: String {
        subscriptionManager.monthlyProduct?.displayPrice ?? "₹499"
    }
    
    private var quickDisplayPrice: String {
        subscriptionManager.tenPlotsProduct?.displayPrice ?? "₹99"
    }
    
    private var disclosureText: String {
        if selectedTab == 0 {
            return "Auto-renews for \(proDisplayPrice)/month until canceled"
        } else {
            return "One-time purchase of \(quickDisplayPrice) • No recurring charge"
        }
    }
    
    private var ctaTitle: String {
        if selectedTab == 0 {
            return "Subscribe"
        } else {
            return "Unlock 10 Plots for \(quickDisplayPrice)"
        }
    }
    
    // MARK: - Staggered Feature Entry Animation
    
    private func animateFeaturesSequentially() {
        visibleFeatureIndices.removeAll()
        for index in 0..<3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08 + Double(index) * 0.12) {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.80)) {
                    _ = visibleFeatureIndices.insert(index)
                }
            }
        }
    }
    
    // ============================================================
    // MARK: - ACTIONS
    // ============================================================
    
    private func handlePurchase() {
        hapticFeedback(.medium)
        isPurchasing = true
        errorMessage = nil
        successMessage = nil
        
        let targetTier: ProductTier = selectedTab == 0 ? .monthly : .tenPlots
        
        Task {
            let result = await subscriptionManager.purchaseTier(targetTier)
            await MainActor.run {
                isPurchasing = false
                switch result {
                case .success:
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    successMessage = selectedTab == 0 ? "Congratulations! Bhumitra Pro unlocked." : "Congratulations! 10 Plot Pack unlocked."
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        dismiss()
                    }
                case .failure(let error):
                    if (error as NSError).code != 0 {
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
