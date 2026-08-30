import SwiftUI
import StoreKit

// ============================================================
// MARK: - BHUMITRA SUBSCRIPTION PAYWALL (PIXEL-PERFECT ACCORDION WITH WATER DROPLET TACTILITY)
// ============================================================

public struct SubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    
    @State private var selectedTier: ProductTier = .fiftyPlots // Default: Good enough (Best Value + Special Offer)
    @State private var isPurchasing: Bool = false
    @State private var showPurchaseCelebration: Bool = false
    @State private var purchasedTier: ProductTier = .fiftyPlots
    @State private var errorMessage: String? = nil
    @State private var successMessage: String? = nil
    
    public init() {}
    
    // MARK: - Pixel-Matched Color Palette
    
    private var primaryTextColor: Color {
        colorScheme == .dark ? .white : Color(red: 17/255, green: 24/255, blue: 39/255)
    }
    
    private var secondaryTextColor: Color {
        colorScheme == .dark ? Color(white: 0.65) : Color(red: 185/255, green: 190/255, blue: 198/255)
    }
    
    private var unselectedCardBg: Color {
        colorScheme == .dark ? Color(red: 26/255, green: 26/255, blue: 30/255) : Color(red: 254/255, green: 253/255, blue: 250/255)
    }
    
    private var selectedCardBg: Color {
        colorScheme == .dark ? Color(red: 24/255, green: 24/255, blue: 28/255) : Color.white
    }
    
    /// Vivid Electric Purple/Violet accent (#7412FA)
    private var electricPurple: Color {
        Color(red: 116/255, green: 18/255, blue: 250/255)
    }
    
    /// Neon Chartreuse / Lime-Yellow Checkmark Circle (#DCE816)
    private var neonLimeBadge: Color {
        Color(red: 220/255, green: 232/255, blue: 22/255)
    }
    
    /// Bright Golden-Yellow Badge for "BEST VALUE" (#FEE232)
    private var bestValueYellow: Color {
        Color(red: 254/255, green: 226/255, blue: 50/255)
    }
    
    // MARK: - Subscription Plans Data (Special Offer strip ONLY on Good Enough)
    
    private var plans: [SubscriptionPlan] {
        [
            SubscriptionPlan(
                tier: .tenPlots,
                title: "Quick",
                badgeText: nil,
                specialOfferHeader: nil, // No top rectangular banner
                originalPrice: "399",
                discountedPrice: dynamicPriceFor(tier: .tenPlots, fallback: "99"),
                priceSuffix: nil,
                features: [
                    "+10 Plots Search",
                    "Detailed property report"
                ]
            ),
            SubscriptionPlan(
                tier: .fiftyPlots,
                title: "Smart",
                badgeText: "BEST VALUE",
                specialOfferHeader: "SPECIAL OFFER", // ONLY Smart has SPECIAL OFFER top strip
                originalPrice: "599",
                discountedPrice: dynamicPriceFor(tier: .fiftyPlots, fallback: "299"),
                priceSuffix: nil,
                features: [
                    "+50 Plots Search",
                    "Detailed property report",
                    "Priority RoR & Khata retrieval"
                ]
            ),
            SubscriptionPlan(
                tier: .monthly,
                title: "Unlimited+",
                badgeText: nil,
                specialOfferHeader: nil, // No top rectangular banner
                originalPrice: "1,499",
                discountedPrice: dynamicPriceFor(tier: .monthly, fallback: "799"),
                priceSuffix: "/mo",
                features: [
                    "Unlimited Plots Search",
                    "Detailed property report",
                    "All High-Res Cadastral Maps",
                    "Unlimited Official PDF Downloads"
                ]
            )
        ]
    }
    
    // MARK: - Main Body
    
    public var body: some View {
        ZStack {
            // Ambient Soft Lavender/Purple Glow Top Gradient
            LinearGradient(
                stops: [
                    .init(
                        color: colorScheme == .dark
                            ? Color(red: 38/255, green: 20/255, blue: 56/255)
                            : Color(red: 228/255, green: 215/255, blue: 254/255),
                        location: 0.0
                    ),
                    .init(
                        color: colorScheme == .dark
                            ? Color(red: 14/255, green: 14/255, blue: 16/255)
                            : Color(red: 247/255, green: 246/255, blue: 249/255),
                        location: 0.36
                    ),
                    .init(
                        color: colorScheme == .dark
                            ? Color(red: 14/255, green: 14/255, blue: 16/255)
                            : Color(red: 245/255, green: 245/255, blue: 247/255),
                        location: 1.0
                    )
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top Dismiss Button (Subtle Glass Circle)
                HStack {
                    Spacer()
                    Button {
                        Theme.haptic(.light)
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(colorScheme == .dark ? .white : Color(red: 60/255, green: 60/255, blue: 65/255))
                            .frame(width: 36, height: 36)
                            .glassEffect(
                                .regular.interactive(),
                                in: .circle
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 20)
                    .padding(.top, 8)
                }
                
                // Scrollable Content
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 12) {
                        // Branding Logo: "LAND Simplified"
                        Image("LandSimplifiedLogo")
                            .resizable()
                            .renderingMode(.template)
                            .aspectRatio(contentMode: .fit)
                            .foregroundColor(primaryTextColor)
                            .frame(width: 155, height: 60)
                            .padding(.top, 0)
                        
                        // Main Title
                        Text("Choose your best\nrequirement")
                            .font(.system(size: 27, weight: .regular, design: .rounded))
                            .foregroundColor(primaryTextColor)
                            .multilineTextAlignment(.center)
                            .lineSpacing(-2)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 14)
                        
                        // 3 Interactive Subscription Cards with Liquid Droplet Elasticity
                        VStack(spacing: 14) {
                            ForEach(plans) { plan in
                                let isSelected = (selectedTier == plan.tier)
                                subscriptionCardView(plan: plan)
                                    .padding(.horizontal, isSelected ? 0 : 4)
                                    .scaleEffect(
                                        x: isSelected ? 1.015 : 0.992,
                                        y: 1.0
                                    )
                                    .animation(.spring(response: 0.42, dampingFraction: 0.70, blendDuration: 0.1), value: selectedTier)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 14)
                    }
                }
                
                // Bottom Fixed Checkout & Legal Section
                bottomCheckoutSection
            }
        }
    }
    
    // MARK: - Subscription Card Component
    
    private func subscriptionCardView(plan: SubscriptionPlan) -> some View {
        let isSelected = (selectedTier == plan.tier)
        
        return Button {
            Theme.haptic(.medium)
            withAnimation(.spring(response: 0.42, dampingFraction: 0.70, blendDuration: 0.1)) {
                selectedTier = plan.tier
            }
        } label: {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 0) {
                    // Top Banner ("SPECIAL OFFER") - Only on Good enough when Selected
                    if isSelected, let bannerTitle = plan.specialOfferHeader {
                        Text(bannerTitle)
                            .font(.system(size: 14.5, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(electricPurple)
                    }
                    
                    // Card Body Content
                    VStack(alignment: .leading, spacing: 14) {
                        // Header Row: Title & Badges (Left) | Price (Right)
                        HStack(alignment: .center) {
                            // Title & Best Value Badge
                            HStack(spacing: 8) {
                                Text(plan.title)
                                    .font(.system(size: 21, weight: .regular, design: .rounded))
                                    .foregroundColor(primaryTextColor)
                                
                                if let badge = plan.badgeText {
                                    Text(badge)
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                        .foregroundColor(Color(red: 25/255, green: 20/255, blue: 10/255))
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 4)
                                        .background(
                                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                                .fill(bestValueYellow)
                                        )
                                }
                            }
                            
                            Spacer()
                            
                            // Price Display (Regular weight, Top-aligned Rupee Symbol)
                            HStack(alignment: .top, spacing: 8) {
                                if isSelected {
                                    // Original Strikethrough Price (Light Gray)
                                    HStack(alignment: .top, spacing: 1) {
                                        Text("₹")
                                            .font(.system(size: 13.5, weight: .regular, design: .rounded))
                                            .foregroundColor(secondaryTextColor)
                                            .offset(y: 2)
                                        
                                        Text(plan.originalPrice)
                                            .font(.system(size: 25, weight: .regular, design: .rounded))
                                            .strikethrough()
                                            .foregroundColor(secondaryTextColor)
                                    }
                                }
                                
                                // Current Discounted Price
                                HStack(alignment: .top, spacing: 1) {
                                    Text("₹")
                                        .font(.system(size: 13.5, weight: .regular, design: .rounded))
                                        .foregroundColor(primaryTextColor)
                                        .offset(y: 2)
                                    
                                    Text(plan.discountedPrice)
                                        .font(.system(size: 25, weight: .regular, design: .rounded))
                                        .foregroundColor(primaryTextColor)
                                    
                                    if let suffix = plan.priceSuffix {
                                        Text(suffix)
                                            .font(.system(size: 22, weight: .regular, design: .rounded))
                                            .foregroundColor(primaryTextColor)
                                            .offset(y: 1)
                                    }
                                }
                            }
                        }
                        
                        // Expanded Features List with Violet Checkmarks
                        if isSelected {
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(plan.features, id: \.self) { feature in
                                    HStack(spacing: 10) {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(electricPurple)
                                        
                                        Text(feature)
                                            .font(.system(size: 15.5, weight: .regular, design: .rounded))
                                            .foregroundColor(primaryTextColor)
                                    }
                                }
                            }
                            .padding(.top, 4)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, isSelected ? (plan.specialOfferHeader != nil ? 16 : 22) : 22)
                    .padding(.bottom, isSelected ? 22 : 22)
                }
                .background(isSelected ? selectedCardBg : unselectedCardBg)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(
                            isSelected ? electricPurple : Color.clear,
                            lineWidth: 2.0
                        )
                )
                
                // Top-Right Checkmark Badge (Neon Lime Circle with Dark Icon)
                if isSelected {
                    ZStack {
                        Circle()
                            .fill(neonLimeBadge)
                            .frame(width: 26, height: 26)
                        
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color(red: 25/255, green: 25/255, blue: 30/255))
                    }
                    .offset(x: 3, y: -3)
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .buttonStyle(LiquidDropletCardButtonStyle())
    }
    
    // MARK: - Bottom Checkout Section
    
    private var bottomCheckoutSection: some View {
        VStack(spacing: 12) {
            // Main Pay Button (Vivid Electric Purple Capsule)
            Button(action: handlePurchase) {
                HStack(spacing: 8) {
                    if isPurchasing || subscriptionManager.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Pay")
                            .font(.system(size: 19, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(electricPurple, in: Capsule())
                .clipShape(Capsule())
            }
            .buttonStyle(TactileGlassButtonStyle())
            .disabled(isPurchasing || subscriptionManager.isLoading)
            .padding(.horizontal, 24)
            .padding(.top, 8)
            
            // Error / Success Toasts
            if let error = errorMessage {
                Text(error)
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            } else if let success = successMessage {
                Text(success)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.green)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            
            // Authentic Bhumitra & Land Simplified Terms Copy
            Text("Plot search credits and features are credited immediately upon purchase. Subscriptions renew automatically at your chosen billing interval until cancelled in App Store Account Settings. Consumable plot search packs do not expire. By tapping Pay, you agree to the Bhumitra + Land Simplified Terms.")
                .font(.system(size: 8, weight: .regular, design: .rounded))
                .foregroundColor(Color(red: 100/255, green: 100/255, blue: 108/255))
                .multilineTextAlignment(.center)
                .lineSpacing(1.4)
                .padding(.horizontal, 30)
            
            // Legal Links (Restore, Terms, Privacy)
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
            .font(.system(size: 9.5, weight: .regular, design: .rounded))
            .foregroundColor(Color(red: 130/255, green: 130/255, blue: 138/255))
            .padding(.horizontal, 24)
            .padding(.bottom, 6)
        }
        .padding(.top, 4)
        .frame(maxWidth: .infinity)
        .fullScreenCover(isPresented: $showPurchaseCelebration) {
            PurchaseSuccessModalView(
                tier: purchasedTier,
                onDismiss: {
                    showPurchaseCelebration = false
                    dismiss()
                }
            )
        }
    }
    
    // MARK: - Price Helpers
    
    private func dynamicPriceFor(tier: ProductTier, fallback: String) -> String {
        switch tier {
        case .tenPlots:
            if let p = subscriptionManager.tenPlotsProduct {
                return sanitizePrice(p.displayPrice)
            }
        case .fiftyPlots:
            if let p = subscriptionManager.fiftyPlotsProduct {
                return sanitizePrice(p.displayPrice)
            }
        case .monthly, .lifetime:
            if let p = subscriptionManager.monthlyProduct ?? subscriptionManager.lifetimeProduct {
                return sanitizePrice(p.displayPrice)
            }
        default:
            break
        }
        return sanitizePrice(fallback)
    }
    
    private func sanitizePrice(_ raw: String) -> String {
        var cleaned = raw
            .replacingOccurrences(of: "₹", with: "")
            .trimmingCharacters(in: .whitespaces)
        if cleaned.hasSuffix(".00") {
            cleaned = String(cleaned.dropLast(3))
        } else if cleaned.hasSuffix(".0") {
            cleaned = String(cleaned.dropLast(2))
        }
        return cleaned
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
                    purchasedTier = selectedTier
                    showPurchaseCelebration = true
                case .failure(let error):
                    let nsError = error as NSError
                    if nsError.code != SKError.paymentCancelled.rawValue && nsError.code != 0 {
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
                    purchasedTier = selectedTier
                    showPurchaseCelebration = true
                } else {
                    errorMessage = "No active subscription found to restore."
                }
            }
        }
    }
}

// MARK: - Liquid Droplet Card Button Style (Tactile Gel / Droplet Reaction)

public struct LiquidDropletCardButtonStyle: ButtonStyle {
    public init() {}
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(
                configuration.isPressed
                    ? CGSize(width: 1.018, height: 0.965) // Droplet expands horizontally and squishes slightly vertically under fingertip
                    : CGSize(width: 1.0, height: 1.0)
            )
            .animation(.spring(response: 0.26, dampingFraction: 0.62), value: configuration.isPressed)
    }
}

// MARK: - Helper Model for Subscription Plans

struct SubscriptionPlan: Identifiable {
    var id: String { tier.rawValue }
    let tier: ProductTier
    let title: String
    let badgeText: String?
    let specialOfferHeader: String?
    let originalPrice: String
    let discountedPrice: String
    let priceSuffix: String?
    let features: [String]
}

#Preview {
    SubscriptionView()
}
