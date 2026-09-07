//
//  SubscriptionView.swift
//  MyBhoomi
//
//  Figma Pixel-Perfect Implementation of SubscriptionScreen (Node ID: 772:591)
//

import SwiftUI
import StoreKit

// MARK: - Subscription Design Tokens (Direct from Figma 772:591)
private enum FigmaSubscriptionTokens {
    // Canvas dimensions: 428 x 874
    static let canvasWidth: CGFloat = 428
    static let canvasHeight: CGFloat = 874
    
    // Background Gradient (149 deg)
    static var bgStart: Color {
        Theme.Color.dynamic(light: Color(hex: "#FDFCFF"), dark: Color(hex: "#0F1117"))
    }
    static var bgEnd: Color {
        Theme.Color.dynamic(light: Color(hex: "#E7D5FD"), dark: Color(hex: "#1A0B2E"))
    }
    
    // Brand & Accent Colors
    static let primaryPurple = Color(hex: "#7600FF")
    static let cardBorderPurple = Color(hex: "#7A1BFF")
    static let specialOfferStart = Color(hex: "#6E07FF")
    static let specialOfferEnd = Color(hex: "#8034EA")
    static let selectedYellow = Color(hex: "#FFEC64")
    static let bestValueYellowEnd = Color(hex: "#FFE100")
    
    // Neutral & Card Fills
    static var white: Color {
        Theme.Color.dynamic(light: Color(hex: "#FFFFFF"), dark: Color(hex: "#1C1D24"))
    }
    static var cardCream: Color {
        Theme.Color.dynamic(light: Color(hex: "#FFFCF6"), dark: Color(hex: "#221E2A"))
    }
    static var cardBorderLight: Color {
        Theme.Color.dynamic(light: Color(hex: "#FBFBFB"), dark: Color.white.opacity(0.12))
    }
    static var closeBorder: Color {
        Theme.Color.dynamic(light: Color(hex: "#E3E3E3"), dark: Color.white.opacity(0.18))
    }
    static var closeIcon: Color {
        Theme.Color.dynamic(light: Color(hex: "#747474"), dark: Color(hex: "#A0A0A0"))
    }
    
    // Text Palette
    static var textBlack: Color {
        Theme.Color.dynamic(light: Color(hex: "#000000"), dark: Color(hex: "#FFFFFF"))
    }
    static var textSubtitle: Color {
        Theme.Color.dynamic(light: Color(hex: "#2F2F2F"), dark: Color(hex: "#E0E0E6"))
    }
    static var textDarkGray: Color {
        Theme.Color.dynamic(light: Color(hex: "#525252"), dark: Color(hex: "#B0B0B8"))
    }
    static var textFeatures: Color {
        Theme.Color.dynamic(light: Color(hex: "#616161"), dark: Color(hex: "#CCCCCC"))
    }
    static var textCurrency: Color {
        Theme.Color.dynamic(light: Color(hex: "#525252"), dark: Color(hex: "#A0A0AA"))
    }
}

public struct SubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    
    @State private var selectedTier: ProductTier
    @State private var isPurchasing: Bool = false
    @State private var showPurchaseCelebration: Bool = false
    @State private var purchasedTier: ProductTier = .tenPlots
    @State private var errorMessage: String? = nil
    @State private var successMessage: String? = nil
    var trigger: AnalyticsPaywallTrigger = .manualOpen
    
    public init(trigger: AnalyticsPaywallTrigger = .manualOpen, initialTier: ProductTier? = nil) {
        self.trigger = trigger
        let defaultTier: ProductTier = initialTier ?? (SubscriptionManager.shared.remainingPlotCredits <= 0 ? .monthly : .tenPlots)
        self._selectedTier = State(initialValue: defaultTier)
    }
    
    public var body: some View {
        ZStack(alignment: .bottom) {
            // 1. Full Screen Canvas Background Gradient (Figma #781:2175)
            LinearGradient(
                stops: [
                    .init(color: FigmaSubscriptionTokens.bgStart, location: 0.0),
                    .init(color: FigmaSubscriptionTokens.bgEnd, location: 1.0)
                ],
                startPoint: UnitPoint(x: 0.20, y: 0.0),
                endPoint: UnitPoint(x: 0.80, y: 1.0)
            )
            .ignoresSafeArea()
            
            // 2. Main Scrollable Content
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    // Top Dismiss Button Row
                    topCloseBar
                        .padding(.top, 12)
                        .padding(.bottom, 2)
                    
                    // Header Branding & Title (Logo + overlaid "pro" + 2-line Subtitle)
                    topBrandingHeader
                        .padding(.bottom, 16)
                    
                    // Plan Cards Stack (Accordion with spacious horizontal padding)
                    VStack(spacing: 14) {
                        // Card 1: Essential (Special Offer)
                        planCardView(
                            tier: .tenPlots,
                            title: "Essential",
                            badgeText: nil,
                            specialOfferHeader: "SPECIAL OFFER",
                            defaultPrice: "99",
                            priceSuffix: nil,
                            features: [
                                "+10 Plots Search",
                                "Detailed property report"
                            ]
                        )
                        
                        // Card 2: Silver (Best Value)
                        planCardView(
                            tier: .fiftyPlots,
                            title: "Silver",
                            badgeText: "Best value",
                            specialOfferHeader: nil,
                            defaultPrice: "299",
                            priceSuffix: nil,
                            features: [
                                "+50 Plots Search",
                                "Detailed property report",
                                "Priority RoR retrieval"
                            ]
                        )
                        
                        // Card 3: Unlimited Plus
                        planCardView(
                            tier: .monthly,
                            title: "Unlimited Plus",
                            badgeText: nil,
                            specialOfferHeader: nil,
                            defaultPrice: "799",
                            priceSuffix: "/m",
                            features: [
                                "Unlimited Plots Search",
                                "Detailed property report",
                                "All High-Res Cadastral Maps",
                                "Unlimited Official PDF Downloads"
                            ]
                        )
                    }
                    .padding(.horizontal, 24)
                    
                    // Bottom Spacer so content is not covered by the fixed footer
                    Spacer().frame(height: 190)
                }
                .frame(maxWidth: .infinity)
            }
            
            // 3. Fixed / Sticky Bottom Section (Stable Subscribe Button + Legal Copy)
            VStack(spacing: 12) {
                // Error / Success Messages
                if let error = errorMessage {
                    Text(error)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
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
                
                // Outlined Subscribe Button (Stays in place when cards expand/shrink)
                subscribeButton
                    .padding(.horizontal, 28)
                    .padding(.bottom, 4)
                
                // Legal Disclaimer & Action Links
                legalFooter
                    .padding(.horizontal, 24)
                    .padding(.bottom, 6)
            }
            .padding(.top, 14)
            .background(
                LinearGradient(
                    colors: [
                        FigmaSubscriptionTokens.bgEnd.opacity(0.0),
                        FigmaSubscriptionTokens.bgEnd.opacity(0.95),
                        FigmaSubscriptionTokens.bgEnd
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea(edges: .bottom)
            )
        }
        .onAppear {
            let bucket = AnalyticsCreditBucket.bucket(
                for: subscriptionManager.remainingPlotCredits,
                isUnlimited: subscriptionManager.isUnlimited
            )
            AnalyticsService.shared.log(.paywallViewed(
                trigger: trigger,
                remainingCreditBucket: bucket
            ))
        }
        .task {
            await subscriptionManager.loadProducts()
        }
        .fullScreenCover(isPresented: $showPurchaseCelebration) {
            PurchaseSuccessModalView(
                tier: purchasedTier,
                onDismiss: {
                    showPurchaseCelebration = false
                    dismiss()
                },
                onSearchPlot: {
                    showPurchaseCelebration = false
                    dismiss()
                    AppNavigationManager.shared.navigate(to: .map)
                }
            )
        }
    }
    
    // MARK: - 1. Top Close Bar (Figma #772:625, #772:626)
    private var topCloseBar: some View {
        HStack {
            Spacer()
            Button {
                dismiss()
            } label: {
                ZStack {
                    Circle()
                        .stroke(FigmaSubscriptionTokens.closeBorder, lineWidth: 3.0)
                        .background(Circle().fill(Color.white.opacity(0.20)))
                        .frame(width: 44, height: 44)
                    
                    SubscriptionCloseIcon(
                        color: FigmaSubscriptionTokens.closeIcon,
                        lineWidth: 2.42,
                        size: 16
                    )
                }
            }
            .buttonStyle(.plain)
            .padding(.trailing, 20)
        }
    }
    
    // MARK: - 2. Branding Header (Logo + "pro" overlaid at Top-Right + 2-line Subtitle)
    private var topBrandingHeader: some View {
        VStack(spacing: 2) {
            // Pro Logo with "pro" badge overlaid on top-right
            ZStack(alignment: .topTrailing) {
                Group {
                    if let img = UIImage(named: "SubscriptionProLogo") ?? UIImage(named: "subscription_pro_logo") {
                        Image(uiImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } else {
                        Image("SubscriptionProLogo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    }
                }
                .frame(width: 58, height: 86)
                
                Text("pro")
                    .font(.stackSansHeadline(size: 18.5, weight: .medium))
                    .foregroundColor(FigmaSubscriptionTokens.textBlack)
                    .tracking(-0.9)
                    .offset(x: 18, y: 6)
            }
            .frame(width: 82, height: 86)
            
            // 2-line Subheader with medium weight, tight line height, and zero extra gap
            Text("Choose your best\nrequirement")
                .font(.stackSansHeadline(size: 20.5, weight: .medium))
                .foregroundColor(FigmaSubscriptionTokens.textSubtitle)
                .multilineTextAlignment(.center)
                .lineSpacing(-3)
        }
    }
    
    // MARK: - 3. Unified Interactive Accordion Plan Card Component
    private func planCardView(
        tier: ProductTier,
        title: String,
        badgeText: String?,
        specialOfferHeader: String?,
        defaultPrice: String,
        priceSuffix: String?,
        features: [String]
    ) -> some View {
        let isSelected = (selectedTier == tier)
        let priceData = cleanPriceComponents(for: tier, fallback: defaultPrice)
        
        return Button {
            selectTier(tier)
        } label: {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 0) {
                    // Top Rectangular "SPECIAL OFFER" Gradient Banner
                    if isSelected && specialOfferHeader != nil {
                        ZStack {
                            LinearGradient(
                                stops: [
                                    .init(color: FigmaSubscriptionTokens.specialOfferStart, location: 0.0),
                                    .init(color: FigmaSubscriptionTokens.specialOfferEnd, location: 1.0)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            .frame(height: 28.1)
                            
                            Text(specialOfferHeader ?? "SPECIAL OFFER")
                                .font(.stackSansHeadline(size: 16, weight: .medium))
                                .foregroundColor(FigmaSubscriptionTokens.white)
                                .tracking(0.5)
                        }
                    }
                    
                    // Card Body
                    VStack(alignment: .leading, spacing: isSelected ? 14 : 0) {
                        // Title, Badges & Price Row
                        HStack(alignment: .center) {
                            // Title & Optional Badge
                            HStack(spacing: 8) {
                                Text(title)
                                    .font(.stackSansHeadline(size: 19.02, weight: .medium))
                                    .foregroundColor(FigmaSubscriptionTokens.textBlack)
                                
                                if let badge = badgeText {
                                    // Prominent Enlarged "Best value" Badge
                                    HStack(spacing: 5) {
                                        if let img = UIImage(named: "SubscriptionBestValueIcon") ?? UIImage(named: "best_value_icon") {
                                            Image(uiImage: img)
                                                .resizable()
                                                .aspectRatio(contentMode: .fit)
                                                .frame(width: 20, height: 18)
                                        }
                                        
                                        Text(badge)
                                            .font(.stackSansHeadline(size: 14.59, weight: .medium))
                                            .foregroundColor(FigmaSubscriptionTokens.textBlack)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(
                                        LinearGradient(
                                            stops: [
                                                .init(color: Color(hex: "#FFFFFF"), location: 0.0),
                                                .init(color: FigmaSubscriptionTokens.bestValueYellowEnd, location: 1.0)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .cornerRadius(4)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(Color.white, lineWidth: 1.8)
                                    )
                                }
                            }
                            
                            Spacer()
                            
                            // Pricing Row (Clean Active Price: Full size ₹ and amount)
                            HStack(alignment: .firstTextBaseline, spacing: 2) {
                                Text(priceData.currency)
                                    .font(.stackSansHeadline(size: isSelected ? 24 : 20, weight: .regular))
                                    .foregroundColor(FigmaSubscriptionTokens.textDarkGray)
                                
                                Text(priceData.amount)
                                    .font(.stackSansHeadline(size: isSelected ? 24 : 20, weight: .regular))
                                    .foregroundColor(FigmaSubscriptionTokens.textDarkGray)
                                
                                if let suffix = priceSuffix {
                                    Text(suffix)
                                        .font(.stackSansHeadline(size: isSelected ? 20 : 18, weight: .regular))
                                        .foregroundColor(FigmaSubscriptionTokens.textDarkGray)
                                }
                            }
                        }
                        
                        // Expanded Features Checklist (Accordion: only shown when Selected)
                        if isSelected {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(features, id: \.self) { feature in
                                    HStack(spacing: 12) {
                                        SubscriptionCheckmarkIcon(
                                            strokeColor: FigmaSubscriptionTokens.textFeatures,
                                            lineWidth: 1.82,
                                            size: CGSize(width: 10.38, height: 9.96)
                                        )
                                        Text(feature)
                                            .font(.stackSansHeadline(size: 17, weight: .light))
                                            .foregroundColor(FigmaSubscriptionTokens.textFeatures)
                                    }
                                }
                            }
                            .padding(.top, 4)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, isSelected ? (specialOfferHeader != nil ? 16 : 20) : 22)
                    .padding(.bottom, isSelected ? 20 : 22)
                }
                .background(isSelected ? FigmaSubscriptionTokens.white : FigmaSubscriptionTokens.cardCream)
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(
                            isSelected ? FigmaSubscriptionTokens.cardBorderPurple : FigmaSubscriptionTokens.cardBorderLight,
                            lineWidth: isSelected ? 2 : 0.98
                        )
                )
                
                // Top-Right Checkmark Badge (Shown on Selected Card)
                if isSelected {
                    SubscriptionSelectedBadge(size: 23.92)
                        .offset(x: 6, y: -6)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .buttonStyle(.plain)
    }
    
    private var isSelectedProductAvailable: Bool {
        switch selectedTier {
        case .tenPlots: return subscriptionManager.tenPlotsProduct != nil
        case .fiftyPlots: return subscriptionManager.fiftyPlotsProduct != nil
        case .twoHundredPlots: return subscriptionManager.twoHundredPlotsProduct != nil
        case .monthly: return subscriptionManager.monthlyProduct != nil
        }
    }
    
    // MARK: - 4. Action CTA (Context-appropriate: "Get 10 Searches", "Get 50 Searches", "Start Unlimited")
    private var actionButtonTitle: String {
        if subscriptionManager.isLoading {
            return "Connecting to App Store..."
        }
        if !isSelectedProductAvailable {
            return "Plan Unavailable from App Store"
        }
        switch selectedTier {
        case .tenPlots:
            return "Get 10 Searches"
        case .fiftyPlots:
            return "Get 50 Searches"
        case .twoHundredPlots:
            return "Get 200 Searches"
        case .monthly:
            return "Start Unlimited"
        }
    }
    
    private var subscribeButton: some View {
        Button(action: handlePurchase) {
            HStack(spacing: 8) {
                if isPurchasing || subscriptionManager.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: FigmaSubscriptionTokens.primaryPurple))
                } else {
                    Text(actionButtonTitle)
                        .font(.stackSansHeadline(size: isSelectedProductAvailable ? 19.3 : 15.0, weight: .medium))
                        .foregroundColor(isSelectedProductAvailable ? FigmaSubscriptionTokens.primaryPurple : Color.gray)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 55.55)
            .background(Color.white.opacity(isSelectedProductAvailable ? 0.12 : 0.05))
            .cornerRadius(36.42)
            .overlay(
                RoundedRectangle(cornerRadius: 36.42)
                    .stroke(isSelectedProductAvailable ? Color.white : Color.gray.opacity(0.3), lineWidth: 3.64)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .disabled(isPurchasing || subscriptionManager.isLoading || !isSelectedProductAvailable)
    }
    
    // MARK: - 5. Legal Disclaimer Footer
    private var legalFooterText: String {
        switch selectedTier {
        case .monthly:
            return "Features can change at any time. Payments will be charged to your App Store account. Your subscription will auto-renew at your selected interval until you cancel in App Store settings. Cancel anytime. By tapping “Start Unlimited”, you agree to the Bhumitra + Land Simplified Terms and the auto-renewal."
        case .tenPlots, .fiftyPlots, .twoHundredPlots:
            return "Features can change at any time. Payments will be charged to your App Store account as a one-time purchase. Search credits do not expire. By tapping “\(actionButtonTitle)”, you agree to the Bhumitra + Land Simplified Terms."
        }
    }
    
    private var legalFooter: some View {
        VStack(spacing: 8) {
            Text(legalFooterText)
                .font(.system(size: 8, weight: .regular, design: .rounded))
                .foregroundColor(FigmaSubscriptionTokens.textBlack)
                .multilineTextAlignment(.center)
                .lineSpacing(2.0)
            
            // App Store Compliance Legal Action Links
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
            .foregroundColor(FigmaSubscriptionTokens.textDarkGray)
        }
    }
    
    // MARK: - Selection & Purchasing Logic
    
    private func selectTier(_ tier: ProductTier) {
        Theme.selectionHaptic()
        withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
            selectedTier = tier
        }
        let creditsCount = tier == .tenPlots ? 10 : (tier == .fiftyPlots ? 50 : 0)
        let priceVal: Double = tier == .tenPlots ? 99.0 : (tier == .fiftyPlots ? 299.0 : 799.0)
        AnalyticsService.shared.log(.productSelected(
            productID: tier.rawValue,
            productType: tier == .monthly ? "subscription" : "consumable",
            credits: creditsCount,
            price: priceVal
        ))
    }
    
    /// Parses display price cleanly so no duplicate currency symbol is rendered
    private func cleanPriceComponents(for tier: ProductTier, fallback: String) -> (currency: String, amount: String) {
        let rawPrice: String
        switch tier {
        case .tenPlots:
            rawPrice = subscriptionManager.tenPlotsProduct?.displayPrice ?? fallback
        case .fiftyPlots:
            rawPrice = subscriptionManager.fiftyPlotsProduct?.displayPrice ?? fallback
        case .twoHundredPlots:
            rawPrice = subscriptionManager.twoHundredPlotsProduct?.displayPrice ?? fallback
        case .monthly:
            rawPrice = subscriptionManager.monthlyProduct?.displayPrice ?? fallback
        }
        
        let trimmed = rawPrice.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("₹") {
            let num = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
            return ("₹", num.replacingOccurrences(of: ".00", with: ""))
        } else if trimmed.hasPrefix("$") {
            let num = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
            return ("$", num)
        }
        return ("₹", trimmed)
    }
    
    private func handlePurchase() {
        errorMessage = nil
        successMessage = nil
        isPurchasing = true
        
        let targetTier = selectedTier
        let productType = targetTier == .monthly ? "subscription" : "consumable"
        let price = targetTier == .tenPlots ? 99.0 : (targetTier == .fiftyPlots ? 299.0 : 799.0)
        
        AnalyticsService.shared.log(.purchaseStarted(
            productID: targetTier.rawValue,
            productType: productType,
            price: price,
            trigger: trigger
        ))
        
        Task {
            let result = await subscriptionManager.purchaseTier(targetTier)
            
            await MainActor.run {
                isPurchasing = false
                switch result {
                case .success:
                    purchasedTier = targetTier
                    showPurchaseCelebration = true
                case .failure(let error):
                    if (error as NSError).code != 0 {
                        errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }
    
    private func handleRestore() {
        errorMessage = nil
        successMessage = nil
        
        Task {
            do {
                _ = try await subscriptionManager.restorePurchases()
                await MainActor.run {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    successMessage = "Purchases restored successfully."
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Restore failed: \(error.localizedDescription)"
                }
            }
        }
    }
}
