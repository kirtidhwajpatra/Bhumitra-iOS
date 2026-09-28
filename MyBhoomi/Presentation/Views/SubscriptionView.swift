//
//  SubscriptionView.swift
//  MyBhoomi
//
//  Figma Pixel-Perfect Implementation of SubscriptionScreen (Node ID: 772:591)
//

import SwiftUI
import StoreKit

// MARK: - Paywall Tokens
//
// Everything resolves through Theme / SheetChrome, so the paywall shares the
// plot sheet's and location picker's single background, hairlines and type,
// and adapts to light and dark automatically.
private enum PaywallTokens {
    static let cornerRadius: CGFloat = 16
    static let background = SheetChrome.background
    static let textPrimary = Theme.Color.bhumitraPrimaryText
    static let textSecondary = Theme.Color.bhumitraSecondaryText
    static let textTertiary = Theme.Color.bhumitraTertiaryText
    static let accent = Theme.Color.bhumitraPrimary
    static let border = Theme.Color.bhumitraBorder
}

public struct SubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    
    @State private var selectedTier: ProductTier
    @State private var isPurchasing: Bool = false
    @State private var showPurchaseCelebration: Bool = false
    @State private var purchasedTier: ProductTier = .tenPlots
    @State private var errorMessage: String? = nil
    @State private var successMessage: String? = nil
    @State private var showErrorAlert: Bool = false
    @State private var alertErrorMessage: String = ""
    @State private var activatedCredits: Int = 0
    @State private var authoritativeBalance: Int = 0
    // Dedicated failure screen state (replaces the OK-only "Purchase Notice" alert)
    @State private var showPurchaseFailure: Bool = false
    @State private var failureReason: String = ""
    @State private var failureCharged: Bool = false
    @State private var failureRetryable: Bool = true
    @State private var showSupport: Bool = false
    var trigger: AnalyticsPaywallTrigger = .manualOpen
    
    public init(trigger: AnalyticsPaywallTrigger = .manualOpen, initialTier: ProductTier? = nil) {
        self.trigger = trigger
        let defaultTier: ProductTier = initialTier ?? .fiftyPlots
        self._selectedTier = State(initialValue: defaultTier)
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    header
                        .padding(.horizontal, SheetChrome.inset)
                        .padding(.top, 60)
                        .padding(.bottom, 24)

                    VStack(spacing: 12) {
                        planCardView(
                            tier: .tenPlots,
                            title: "Quick",
                            summary: "10 plot searches",
                            badgeText: nil,
                            defaultPrice: "99",
                            priceSuffix: nil,
                            features: [
                                "+10 Plots Search",
                                "Detailed property report"
                            ]
                        )

                        planCardView(
                            tier: .fiftyPlots,
                            title: "Smart",
                            summary: "50 plot searches",
                            badgeText: "Best value",
                            defaultPrice: "299",
                            priceSuffix: nil,
                            features: [
                                "+50 Plots Search",
                                "Detailed property report",
                                "Priority RoR & Khata retrieval"
                            ]
                        )

                        planCardView(
                            tier: .monthly,
                            title: "Unlimited+",
                            summary: "Unlimited searches, billed monthly",
                            badgeText: nil,
                            defaultPrice: "799",
                            priceSuffix: "/mo",
                            features: [
                                "Unlimited Plots Search",
                                "Detailed property report",
                                "All High-Res Cadastral Maps",
                                "Unlimited Official PDF Downloads"
                            ]
                        )
                    }
                    .padding(.horizontal, SheetChrome.inset)
                    .padding(.bottom, 24)
                }
                .frame(maxWidth: .infinity)
            }

            // Pinned footer: status, CTA, legal — on the same background.
            bottomStickySection
        }
        .background(PaywallTokens.background.ignoresSafeArea())
        .overlay(alignment: .topTrailing) {
            topFixedCloseBar
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
            await subscriptionManager.processUnfinishedTransactions()
        }
        .alert(isPresented: $showErrorAlert) {
            Alert(
                title: Text("Purchase Notice"),
                message: Text(alertErrorMessage.isEmpty ? (errorMessage ?? "Unable to complete purchase at this time. Please try again.") : alertErrorMessage),
                dismissButton: .default(Text("OK"), action: {
                    errorMessage = nil
                    alertErrorMessage = ""
                })
            )
        }
        .fullScreenCover(isPresented: $showPurchaseCelebration) {
            PurchaseSuccessModalView(
                tier: purchasedTier,
                creditsGranted: activatedCredits,
                authoritativeBalance: authoritativeBalance,
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
        .fullScreenCover(isPresented: $showPurchaseFailure) {
            PurchaseFailureView(
                reason: failureReason,
                charged: failureCharged,
                retryable: failureRetryable,
                onRetry: {
                    showPurchaseFailure = false
                    // A charged-but-unactivated failure should sync the existing
                    // transaction; an uncharged failure should re-attempt the buy.
                    if failureCharged {
                        handlePendingSync()
                    } else {
                        handlePurchase()
                    }
                },
                onRestore: {
                    showPurchaseFailure = false
                    handleRestore()
                },
                onContactSupport: {
                    showPurchaseFailure = false
                    showSupport = true
                },
                onDismiss: {
                    showPurchaseFailure = false
                }
            )
        }
        .fullScreenCover(isPresented: $showSupport) {
            SupportContactView()
        }
    }

    /// Central place to route a `PurchaseOutcome` into the paywall's UI state so
    /// every terminal case is handled exactly once and the CTA never gets stuck.
    private func present(outcome: PurchaseOutcome) {
        switch outcome {
        case .granted(let tier, let credits, let balance):
            purchasedTier = tier
            activatedCredits = credits
            authoritativeBalance = balance
            showPurchaseCelebration = true
        case .alreadyOwned(_, let balance):
            // This transaction was ALREADY credited on a prior attempt (a leftover
            // unfinished/duplicate transaction reconciled during preflight). The
            // user did not just complete a fresh purchase, so we must NOT show the
            // celebratory success screen (that was the "confirmation with no Apple
            // sheet and no new credits" bug). Quietly reconcile the balance instead.
            authoritativeBalance = balance
            successMessage = "Your balance is up to date (\(balance) plot \(balance == 1 ? "search" : "searches"))."
        case .pendingActivation:
            // The manager has set isSyncPending; the sticky pending card + auto
            // retry handle this. Nothing else to show.
            break
        case .cancelled:
            // User dismissed Apple's sheet. Stay on the paywall silently.
            break
        case .awaitingApproval:
            // Ask-to-Buy etc. The pending card communicates this.
            break
        case .failed(let reason, let retryable, let charged):
            failureReason = reason
            failureCharged = charged
            failureRetryable = retryable
            showPurchaseFailure = true
        }
    }
    
    // MARK: - 1. Pinned Close Button
    private var topFixedCloseBar: some View {
        SheetIconButton("xmark", accessibilityLabel: "Close") { dismiss() }
            .padding(.trailing, SheetChrome.inset)
            .padding(.top, 16)
    }
    
    // MARK: - 2. Header (title + current balance)
    private var balanceLine: String {
        if subscriptionManager.isUnlimited { return "You're on Unlimited+." }
        let n = subscriptionManager.remainingPlotCredits
        return "You have \(n) plot \(n == 1 ? "search" : "searches") left."
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Get more plot searches")
                .font(.stackSansHeadline(size: 26, weight: .bold))
                .foregroundColor(PaywallTokens.textPrimary)
            Text("Each search opens the official land record for one plot.")
                .font(.system(size: 14))
                .foregroundColor(PaywallTokens.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(balanceLine)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(PaywallTokens.textPrimary)
                .padding(.horizontal, 10)
                .frame(height: 26)
                .background(Capsule().fill(SheetChrome.controlFill))
                .padding(.top, 8)
        }
    }
    
    // MARK: - 3. Pinned Footer (status + CTA + legal)
    private func statusCard<Content: View>(tint: Color, @ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(tint.opacity(0.10))
            )
            .padding(.horizontal, SheetChrome.inset)
    }

    private var bottomStickySection: some View {
        VStack(spacing: 12) {
            // Activating: Apple confirmed payment, synchronizing with backend
            if subscriptionManager.isActivating {
                statusCard(tint: PaywallTokens.accent) {
                    HStack(spacing: 10) {
                        ProgressView()
                            .controlSize(.small)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Payment received — activating…")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(PaywallTokens.textPrimary)
                            Text("Apple confirmed payment. You won't be charged again.")
                                .font(.system(size: 12))
                                .foregroundColor(PaywallTokens.textSecondary)
                        }
                    }
                }
            } else if subscriptionManager.isSyncPending {
                // Pending sync: Apple transaction exists in the unfinished queue
                statusCard(tint: Theme.Color.bhumitraWarning) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "clock.badge.checkmark")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(Theme.Color.bhumitraWarning)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Payment received — activation pending")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(PaywallTokens.textPrimary)
                                Text("Your payment is safe. We're still syncing your plot searches. You won't be charged again.")
                                    .font(.system(size: 12))
                                    .foregroundColor(PaywallTokens.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        Button {
                            Theme.haptic(.medium)
                            Task {
                                let syncResult = await subscriptionManager.retryPendingSyncDetailed()
                                await MainActor.run {
                                    switch syncResult {
                                    case .activated(let credits, let balance):
                                        activatedCredits = credits
                                        authoritativeBalance = balance
                                        purchasedTier = selectedTier
                                        showPurchaseCelebration = true
                                    case .alreadyProcessed(let balance):
                                        authoritativeBalance = balance
                                    case .noPendingPurchase:
                                        alertErrorMessage = "No pending purchase was found to activate."
                                        showErrorAlert = true
                                    case .activationPending(let message):
                                        alertErrorMessage = message
                                        showErrorAlert = true
                                    case .failed(let message):
                                        alertErrorMessage = message.isEmpty ? "Activation failed. Please try again." : message
                                        showErrorAlert = true
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                if subscriptionManager.isActivating {
                                    ProgressView().controlSize(.mini)
                                    Text("Syncing plot searches…")
                                } else {
                                    Image(systemName: "arrow.clockwise")
                                    Text("Sync now")
                                }
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Theme.Color.bhumitraWarning)
                            .padding(.horizontal, 14)
                            .frame(height: 32)
                            .background(Capsule().stroke(Theme.Color.bhumitraWarning.opacity(0.5), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .disabled(subscriptionManager.isActivating)
                    }
                }
            } else if let error = errorMessage, !showErrorAlert {
                Label(error, systemImage: "exclamationmark.circle")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Theme.Color.bhumitraError)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, SheetChrome.inset)
            } else if let success = successMessage {
                Text(success)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Theme.Color.bhumitraSuccess)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, SheetChrome.inset)
            }
            
            subscribeButton
                .padding(.horizontal, SheetChrome.inset)
            
            legalFooter
                .padding(.horizontal, SheetChrome.inset)
                .padding(.bottom, 4)
        }
        .padding(.top, 12)
        .background(
            PaywallTokens.background
                .overlay(alignment: .top) { SheetHairline() }
                .ignoresSafeArea(edges: .bottom)
        )
    }
    
    // MARK: - 4. Plan Row (radio + name + summary + price; features when selected)
    private func planCardView(
        tier: ProductTier,
        title: String,
        summary: String,
        badgeText: String?,
        defaultPrice: String,
        priceSuffix: String?,
        features: [String]
    ) -> some View {
        let isSelected = (selectedTier == tier)
        let priceData = cleanPriceComponents(for: tier, fallback: defaultPrice)
        
        return Button {
            selectTier(tier)
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 14) {
                    // Radio indicator
                    ZStack {
                        Circle()
                            .stroke(isSelected ? PaywallTokens.accent : PaywallTokens.border, lineWidth: 1.5)
                        if isSelected {
                            Circle().fill(PaywallTokens.accent).padding(5)
                        }
                    }
                    .frame(width: 22, height: 22)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 8) {
                            Text(title)
                                .font(.stackSansHeadline(size: 17, weight: .semibold))
                                .foregroundColor(PaywallTokens.textPrimary)
                            if let badge = badgeText {
                                Text(badge)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(PaywallTokens.accent)
                                    .padding(.horizontal, 8)
                                    .frame(height: 20)
                                    .background(Capsule().fill(Theme.Color.bhumitraTint))
                            }
                        }
                        Text(summary)
                            .font(.system(size: 13))
                            .foregroundColor(PaywallTokens.textSecondary)
                    }

                    Spacer(minLength: 8)

                    HStack(alignment: .firstTextBaseline, spacing: 1) {
                        Text(priceData.currency)
                            .font(.system(size: 14, weight: .medium))
                        Text(priceData.amount)
                            .font(.stackSansHeadline(size: 22, weight: .semibold))
                            .monospacedDigit()
                        if let priceSuffix {
                            Text(priceSuffix)
                                .font(.system(size: 13))
                                .foregroundColor(PaywallTokens.textSecondary)
                        }
                    }
                    .foregroundColor(PaywallTokens.textPrimary)
                }

                if isSelected {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(features, id: \.self) { feature in
                            HStack(spacing: 10) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(PaywallTokens.accent)
                                    .frame(width: 22)
                                Text(feature)
                                    .font(.system(size: 14))
                                    .foregroundColor(PaywallTokens.textPrimary)
                            }
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: PaywallTokens.cornerRadius, style: .continuous)
                    .fill(isSelected ? Theme.Color.bhumitraTint.opacity(0.5) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: PaywallTokens.cornerRadius, style: .continuous)
                    .stroke(isSelected ? PaywallTokens.accent : PaywallTokens.border, lineWidth: isSelected ? 1.5 : 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: PaywallTokens.cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
    
    private var isSelectedProductAvailable: Bool {
        switch selectedTier {
        case .tenPlots: return subscriptionManager.tenPlotsProduct != nil
        case .fiftyPlots: return subscriptionManager.fiftyPlotsProduct != nil
        case .twoHundredPlots: return subscriptionManager.twoHundredPlotsProduct != nil
        case .monthly: return subscriptionManager.monthlyProduct != nil
        }
    }
    
    // MARK: - 5. Action CTA (Context-appropriate: "Get 10 Searches", "Get 50 Searches", "Start Unlimited")
    private var actionButtonTitle: String {
        if !isSelectedProductAvailable && subscriptionManager.isLoading {
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
        Button(action: {
            print("[PAYMENT][UI_TAP]\nGet 50 Searches tapped")
            print("[PAYMENT][UI_STATE]\nselectedTier = \(selectedTier.rawValue)")
            print("[PAYMENT][UI_STATE]\nisPurchasing = \(isPurchasing)")
            print("[PAYMENT][UI_STATE]\nisSyncPending = \(subscriptionManager.isSyncPending)")
            print("[PAYMENT][UI_STATE]\nisLoading = \(subscriptionManager.isLoading)")
            print("[PAYMENT][UI_STATE]\nisActivating = \(subscriptionManager.isActivating)")
            print("[PAYMENT][UI_STATE]\nisSelectedProductAvailable = \(isSelectedProductAvailable)")
            
            // The primary CTA ALWAYS starts a fresh purchase of the selected plan.
            // A leftover "pending sync" flag (which can be restored stale from a
            // previous session) must never hijack the button into a sync-only path
            // that never opens Apple's payment sheet. Explicit activation of a
            // genuinely pending purchase is still available via the "Try Again /
            // Sync Now" button inside the pending card, and happens automatically
            // via auto-retry + foreground reconciliation.
            handlePurchase()
        }) {
            HStack(spacing: 8) {
                // Only the user's OWN purchase-in-progress drives the spinner here.
                // Background reconciliation (isActivating from Transaction.unfinished)
                // must not hijack the button label or the user can't tell it's tappable.
                if isPurchasing {
                    ProgressView()
                    Text("Processing…")
                } else if !isSelectedProductAvailable && subscriptionManager.isLoading {
                    ProgressView()
                } else {
                    // Primary CTA always reflects a fresh purchase of the selected
                    // plan ("Get N Searches" / "Start Unlimited"). Activation of any
                    // pending purchase lives in the pending card, not here.
                    Text(actionButtonTitle)
                }
            }
        }
        // Shared CTA style (same as "Search now" in the location picker).
        .buttonStyle(.primaryCTA)
        // While our own purchase is running keep the brand fill (busy, not
        // disabled) but swallow taps.
        .allowsHitTesting(!isPurchasing)
        // The buy button is disabled ONLY by the user's own in-progress purchase
        // (isPurchasing) or when the selected product genuinely isn't available.
        // It must NOT be disabled by background entitlement reconciliation
        // (subscriptionManager.isActivating), which can run for many seconds while
        // clearing leftover/unfinished transactions — that previously made the
        // button "do nothing" when tapped. (isPurchasing is handled by
        // allowsHitTesting above so the busy state keeps the brand fill.)
        .disabled(!subscriptionManager.isSyncPending && !isSelectedProductAvailable)
    }
    
    // MARK: - 6. Legal Disclaimer Footer
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
                .font(.system(size: 10.5))
                .foregroundColor(PaywallTokens.textTertiary)
                .multilineTextAlignment(.center)
                .lineSpacing(1.5)
                .fixedSize(horizontal: false, vertical: true)
            
            // App Store compliance links
            HStack(spacing: 14) {
                Button("Restore purchases") {
                    handleRestore()
                }
                Button("Terms of Service") {
                    if let url = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/") {
                        openURL(url)
                    }
                }
                Button("Privacy Policy") {
                    if let url = URL(string: "https://kirtidhwajpatra.github.io/Bhumitra_PrivacyPolicy/") {
                        openURL(url)
                    }
                }
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(PaywallTokens.textSecondary)
        }
    }
    
    // MARK: - Selection & Purchasing Logic
    
    private func selectTier(_ tier: ProductTier) {
        Theme.selectionHaptic()
        withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
            selectedTier = tier
        }
        let creditsCount = tier == .tenPlots ? 10 : (tier == .fiftyPlots ? 50 : (tier == .twoHundredPlots ? 200 : 0))
        let selectedProduct = subscriptionManager.product(for: tier)
        let priceVal: Double = selectedProduct.map { NSDecimalNumber(decimal: $0.price).doubleValue } ?? 0.0
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
        } else if trimmed.hasPrefix("INR") {
            let num = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            return ("₹", num.replacingOccurrences(of: ".00", with: ""))
        } else if trimmed.hasPrefix("Rs.") {
            let num = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            return ("₹", num.replacingOccurrences(of: ".00", with: ""))
        } else if trimmed.hasPrefix("Rs") {
            let num = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
            return ("₹", num.replacingOccurrences(of: ".00", with: ""))
        } else if trimmed.hasPrefix("$") {
            let num = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
            return ("$", num)
        }
        return ("₹", trimmed)
    }
    
    private func handlePendingSync() {
        print("[PAYMENT] Sync & Activate button tapped")
        errorMessage = nil
        successMessage = nil
        isPurchasing = true
        
        Task {
            let syncResult = await subscriptionManager.retryPendingSyncDetailed()
            await MainActor.run {
                isPurchasing = false
                switch syncResult {
                case .activated(let credits, let balance):
                    activatedCredits = credits
                    authoritativeBalance = balance
                    purchasedTier = selectedTier
                    showPurchaseCelebration = true
                case .alreadyProcessed(let balance):
                    // Already credited — show success with the true balance rather
                    // than leaving the user on the paywall wondering.
                    activatedCredits = 0
                    authoritativeBalance = balance
                    purchasedTier = selectedTier
                    showPurchaseCelebration = true
                case .noPendingPurchase:
                    // Nothing pending to activate: reconcile and show a gentle success
                    // so the CTA doesn't stay stuck on "Sync & Activate".
                    authoritativeBalance = subscriptionManager.authoritativeBalance
                    successMessage = "Your balance is up to date."
                case .activationPending(let message):
                    // Still pending — the sticky pending card + auto-retry cover this.
                    successMessage = message
                case .failed(let message):
                    // A charged-but-unactivated failure: payment is safe.
                    failureReason = message.isEmpty ? "We couldn't activate your purchase just yet." : message
                    failureCharged = true
                    failureRetryable = true
                    showPurchaseFailure = true
                }
            }
        }
    }
    
    private func handlePurchase() {
        let targetTier = selectedTier
        let selectedProduct = subscriptionManager.product(for: targetTier)
        let productLoaded = selectedProduct != nil
        
        print("[PAYMENT][PRODUCT]\nproductId = \(targetTier.rawValue)")
        print("[PAYMENT][PRODUCT]\nproductLoaded = \(productLoaded)")
        if let p = selectedProduct {
            print("[PAYMENT][PRODUCT]\nid = \(p.id)")
            print("[PAYMENT][PRODUCT]\ndisplayName = \(p.displayName)")
            print("[PAYMENT][PRODUCT]\ndisplayPrice = \(p.displayPrice)")
            print("[PAYMENT][PRODUCT]\ntype = \(p.type)")
        } else {
            print("[PAYMENT][PURCHASE_BLOCKED]\nreason = Product '\(targetTier.rawValue)' is nil or not loaded from StoreKit")
            alertErrorMessage = "Product unavailable from App Store. Please check internet connection."
            showErrorAlert = true
            return
        }
        
        print("[PAYMENT][PURCHASE_START]\nStarting StoreKit purchase")
        print("[PAYMENT] Purchase state before starting: isPurchasing = \(isPurchasing), isLoading = \(subscriptionManager.isLoading)")
        errorMessage = nil
        successMessage = nil
        isPurchasing = true
        
        let productType = targetTier == .monthly ? "subscription" : "consumable"
        let price: Double = selectedProduct.map { NSDecimalNumber(decimal: $0.price).doubleValue } ?? (targetTier == .tenPlots ? 99.0 : (targetTier == .fiftyPlots ? 199.0 : 799.0))
        
        AnalyticsService.shared.log(.purchaseStarted(
            productID: targetTier.rawValue,
            productType: productType,
            price: price,
            trigger: trigger
        ))
        
        Task {
            // Use the explicit outcome API so the UI never decodes NSError codes
            // and every path resolves to a single terminal state.
            let outcome = await subscriptionManager.purchaseTierOutcome(targetTier)

            await MainActor.run {
                self.isPurchasing = false
                print("[PAYMENT] isPurchasing reset. Outcome delivered to UI: \(outcome)")
                present(outcome: outcome)
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
