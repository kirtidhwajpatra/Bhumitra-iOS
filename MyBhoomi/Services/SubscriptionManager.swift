import Foundation
import Combine
import StoreKit
import UIKit

public enum PaymentSyncState: Equatable {
    case idle
    case purchasing
    case activating(productTitle: String)
    case syncPending(productTitle: String, message: String)
    case success(productTitle: String)
    case failed(message: String)
}

public enum PendingSyncResult: Equatable, Sendable {
    case activated(creditsGranted: Int, currentBalance: Int)
    case alreadyProcessed(currentBalance: Int)
    case noPendingPurchase
    case activationPending(message: String)
    case failed(message: String)
}

/// Explicit, exhaustive result of a purchase attempt, surfaced to the UI.
///
/// This replaces the previous `Result<Transaction, Error>` + magic-NSError-code
/// (1001/1002/409) signalling, which conflated "already credited" and "stale"
/// into a `.failure` carrying a "Tap again to purchase" message — the root cause
/// of the "second payment does nothing" experience. Every purchase now resolves
/// to exactly one terminal case, so the paywall can never dead-end.
public enum PurchaseOutcome: Equatable, Sendable {
    /// A brand-new purchase was verified and credits/entitlement were granted.
    case granted(tier: ProductTier, creditsGranted: Int, balance: Int)
    /// Apple confirmed the transaction but the server had already credited it
    /// (duplicate delivery, replay, or a repeat sync). The authoritative balance
    /// has been reconciled and is included. This is a SUCCESS from the user's
    /// point of view — they were not charged again and their balance is correct.
    case alreadyOwned(tier: ProductTier, balance: Int)
    /// Apple took the payment but the server could not be reached yet. The
    /// transaction is safe in Apple's queue and will auto-activate. Show a
    /// reassuring pending state, never an error.
    case pendingActivation(tier: ProductTier, message: String)
    /// The user dismissed Apple's payment sheet. No charge occurred.
    case cancelled
    /// Apple has the payment pending external authorization (e.g. Ask to Buy).
    case awaitingApproval(tier: ProductTier)
    /// The attempt genuinely failed. `charged` distinguishes "you were not
    /// charged" (pre-payment failure) from "your payment is safe" (post-payment).
    case failed(reason: String, retryable: Bool, charged: Bool)

    public var isSuccess: Bool {
        switch self {
        case .granted, .alreadyOwned: return true
        default: return false
        }
    }
}

/// Result of submitting a subscription transaction to the backend.
public enum SubscriptionSyncResult: Equatable, Sendable {
    /// Backend verified and linked the subscription. Finish the transaction.
    case verified
    /// Backend permanently rejected this transaction for this account/device
    /// (e.g. HTTP 403 — it belongs to another account or is otherwise
    /// unverifiable). Retrying will NEVER succeed, so the transaction must be
    /// finished and cleared to stop it replaying on every launch/foreground.
    case permanentlyRejected
    /// A transient failure (network, 5xx, timeout). Leave the transaction
    /// unfinished so it can be retried later.
    case transientFailure
}

public enum ProductTier: String, CaseIterable, Identifiable {
    case tenPlots = "bhumitra.plots.10"
    case fiftyPlots = "bhumitra.plots.50"
    case twoHundredPlots = "bhumitra.plots.200"
    case monthly = "bhumitra.unlimited.monthly"
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .tenPlots: return "+10 Plots Search"
        case .fiftyPlots: return "+50 Plots Search"
        case .twoHundredPlots: return "+200 Plots Search"
        case .monthly: return "Monthly Unlimited"
        }
    }
    
    public var displayName: String {
        switch self {
        case .tenPlots: return "+10 Plots Search"
        case .fiftyPlots: return "+50 Plots Search"
        case .twoHundredPlots: return "+200 Plots Search"
        case .monthly: return "Unlimited Plus"
        }
    }
    
    public var displayPrice: String {
        switch self {
        case .tenPlots: return "₹99"
        case .fiftyPlots: return "₹299"
        case .twoHundredPlots: return "₹999"
        case .monthly: return "₹799"
        }
    }
    
    public var badge: String? {
        switch self {
        case .tenPlots: return "Quick ⚡"
        case .fiftyPlots: return "Good Enough 📦"
        case .twoHundredPlots: return "Best Value 🚀"
        case .monthly: return "UNLIMITED ACCESS"
        }
    }
}

@MainActor
public final class SubscriptionManager: ObservableObject {
    public static let shared = SubscriptionManager()
    
    /// Default Free starter allowance (granted once on initial install)
    public static let defaultFreeStarterCredits: Int = 5
    
    // Published states for UI
    @Published public var isPremium: Bool = false
    @Published public var activeTier: ProductTier? = nil
    
    // Plot Search Credits & Quota Management (Server Authoritative, Cached via Keychain)
    @Published public var remainingPlotCredits: Int = defaultFreeStarterCredits
    @Published public var isUnlimited: Bool = false
    @Published public var isLoadingCredits: Bool = false
    
    #if DEBUG
    /// Backing store for real credits while in DEBUG mode so test credits don't pollute server/keychain credits
    public var realPlotCredits: Int = defaultFreeStarterCredits
    
    public func recalculateCreditsFromTestManager() {
        self.remainingPlotCredits = self.realPlotCredits + TestCreditManager.shared.testCredits
    }
    #endif
    
    /// The true authoritative credit balance from the server/backend, strictly isolated from debug test credits.
    public var authoritativeBalance: Int {
        #if DEBUG
        return self.realPlotCredits
        #else
        return self.remainingPlotCredits
        #endif
    }
    
    // Persistent Keychain Keys (Survives app uninstalls & reinstalls)
    private let keychainDeviceCreditsKey = "bhumitra_keychain_device_credits_v2"
    private let keychainDeviceInitKey = "bhumitra_keychain_device_init_v2"
    private let keychainDeviceUnlimitedKey = "bhumitra_keychain_device_unlimited_v2"
    
    private func userCreditsKey(for userId: String) -> String { "bhumitra_keychain_user_credits_\(userId)" }
    private func userInitKey(for userId: String) -> String { "bhumitra_keychain_user_init_\(userId)" }
    private func userUnlimitedKey(for userId: String) -> String { "bhumitra_keychain_user_unlimited_\(userId)" }
    
    // Dynamic products loaded from Apple StoreKit 2
    @Published public var products: [Product] = []
    @Published public var tenPlotsProduct: Product? = nil
    @Published public var fiftyPlotsProduct: Product? = nil
    @Published public var twoHundredPlotsProduct: Product? = nil
    @Published public var monthlyProduct: Product? = nil
    
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String? = nil
    @Published public var activeTransactions: [Transaction] = []
    
    // Hardened Payment & Entitlement Sync States
    @Published public var paymentSyncState: PaymentSyncState = .idle
    @Published public var isActivating: Bool = false
    @Published public var isSyncPending: Bool = false
    @Published public var pendingSyncTransactionId: String? = nil
    @Published public var pendingSyncProductTitle: String? = nil
    
    /// Ask to Buy / payment authorisation pending: NOT charged yet.
    @Published public var isAwaitingApproval: Bool = false
    /// Fires when a purchase that was waiting for approval is later granted
    /// through Transaction.updates, so the paywall can show the confirmation.
    @Published public var approvedPurchaseGrant: ApprovedPurchaseGrant? = nil

    public struct ApprovedPurchaseGrant: Equatable {
        public let id = UUID()
        public let tier: ProductTier
        public let creditsGranted: Int
        public let balance: Int
    }

    // Last verified credit grant result from server
    @Published public var lastGrantedCredits: Int = 0
    @Published public var lastAuthoritativeBalance: Int = 0

    /// The explicit outcome of the most recent purchase attempt. Set by
    /// `executePurchase` and read by `purchaseTierOutcome` so the UI gets an
    /// exhaustive, unambiguous result instead of decoding magic NSError codes.
    public private(set) var lastPurchaseOutcome: PurchaseOutcome = .cancelled
    
    public func product(for tier: ProductTier) -> Product? {
        switch tier {
        case .tenPlots: return tenPlotsProduct
        case .fiftyPlots: return fiftyPlotsProduct
        case .twoHundredPlots: return twoHundredPlotsProduct
        case .monthly: return monthlyProduct
        }
    }
    
    // Product identifiers defined in App Store Connect
    public static let tenPlotsProductID = ProductTier.tenPlots.rawValue
    public static let fiftyPlotsProductID = ProductTier.fiftyPlots.rawValue
    public static let twoHundredPlotsProductID = ProductTier.twoHundredPlots.rawValue
    public static let monthlyProductID = ProductTier.monthly.rawValue
    
    public static let consumableProductIDs: Set<String> = [
        tenPlotsProductID,
        fiftyPlotsProductID,
        twoHundredPlotsProductID
    ]
    
    public static let subscriptionProductIDs: Set<String> = [
        monthlyProductID
    ]
    
    public let productIDs: Set<String> = [
        tenPlotsProductID,
        fiftyPlotsProductID,
        twoHundredPlotsProductID,
        monthlyProductID
    ]
    
    public func creditsForProductID(_ id: String) -> Int {
        switch id {
        case Self.tenPlotsProductID: return 10
        case Self.fiftyPlotsProductID: return 50
        case Self.twoHundredPlotsProductID: return 200
        default: return 0
        }
    }
    
    private var transactionListenerTask: Task<Void, Never>? = nil
    private var cancellables = Set<AnyCancellable>()
    
    // Transaction coordinator: concurrency locking & result caching
    private var inFlightProcessingTasks: [String: Task<BackendProcessingResult, Never>] = [:]
    private var sessionTransactionResults: [String: BackendProcessingResult] = [:]

    /// Transaction IDs for which the backend delivered a POSITIVE new credit grant
    /// during this app session (creditsGranted > 0 && !already_processed), recorded
    /// by whichever path first reached the backend (Transaction.updates listener OR
    /// executePurchase). This is the single source of truth for "did the purchase the
    /// user just made actually add credits", independent of which concurrent path won
    /// the race. executePurchase reads this to decide .granted vs .alreadyOwned so a
    /// genuine fresh purchase is never misreported as "balance up to date".
    private var grantedTxIDsThisSession: [String: (creditsGranted: Int, balance: Int)] = [:]
    
    // Reconciliation single-flight tracking
    private var inFlightReconciliationTask: Task<Void, Never>? = nil
    private var activeUnfinishedTransactionIDs: Set<String> = []
    private var lastUpdatesTransactionID: String = "none"
    
    // Persistent Storage Keys for Pending Sync State (Survives app restarts & crashes)
    private let persistentPendingSyncTxIdKey = "bhumitra_pending_sync_tx_id_v1"
    private let persistentPendingSyncTitleKey = "bhumitra_pending_sync_title_v1"
    private var autoRetryTask: Task<Void, Never>? = nil
    
    public func savePendingSyncState(txId: String, title: String) {
        self.isSyncPending = true
        self.pendingSyncTransactionId = txId
        self.pendingSyncProductTitle = title
        let msg = "Payment received — Apple has confirmed your payment. We're activating your plot searches. You won't be charged again."
        self.paymentSyncState = .syncPending(productTitle: title, message: msg)
        UserDefaults.standard.set(txId, forKey: persistentPendingSyncTxIdKey)
        UserDefaults.standard.set(title, forKey: persistentPendingSyncTitleKey)
        debugLog("[PAYMENT][PENDING_STATE_PERSISTED] txId: \(txId), title: \(title)")
        scheduleAutoRetryIfNeeded()
    }
    
    public func clearPendingSyncState(productTitle: String? = nil) {
        self.isSyncPending = false
        self.pendingSyncTransactionId = nil
        self.pendingSyncProductTitle = nil
        self.autoRetryTask?.cancel()
        self.autoRetryTask = nil
        UserDefaults.standard.removeObject(forKey: persistentPendingSyncTxIdKey)
        UserDefaults.standard.removeObject(forKey: persistentPendingSyncTitleKey)
        if let title = productTitle {
            self.paymentSyncState = .success(productTitle: title)
        } else {
            self.paymentSyncState = .idle
        }
        debugLog("[PAYMENT][PENDING_STATE_CLEARED]")
    }
    
    public func restorePendingSyncState() {
        guard let savedTxId = UserDefaults.standard.string(forKey: persistentPendingSyncTxIdKey), !savedTxId.isEmpty else {
            return
        }
        let savedTitle = UserDefaults.standard.string(forKey: persistentPendingSyncTitleKey) ?? "Plot Searches"
        // Do NOT eagerly trust the persisted flag — it can be left over from a
        // previous session whose transaction was since finished/cleared (e.g. a
        // 403 subscription we now flush). If we blindly set isSyncPending=true, the
        // paywall gets stuck in "sync" mode and the buy button stops opening the
        // Apple sheet. Verify the referenced transaction is STILL unfinished in
        // Apple's queue before restoring pending state; otherwise clear it.
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            var stillUnfinished = false
            for await verificationResult in Transaction.unfinished {
                let txId: UInt64
                switch verificationResult {
                case .verified(let t): txId = t.id
                case .unverified(let t, _): txId = t.id
                }
                if String(txId) == savedTxId {
                    stillUnfinished = true
                    break
                }
            }
            if stillUnfinished {
                self.isSyncPending = true
                self.pendingSyncTransactionId = savedTxId
                self.pendingSyncProductTitle = savedTitle
                let msg = "Payment received — Apple has confirmed your payment. We're activating your plot searches. You won't be charged again."
                self.paymentSyncState = .syncPending(productTitle: savedTitle, message: msg)
                debugLog("[PAYMENT][PENDING_STATE_RESTORED] txId: \(savedTxId), title: \(savedTitle)")
                self.scheduleAutoRetryIfNeeded()
            } else {
                // Stale persisted pending state — the transaction is gone. Clear it
                // so the paywall behaves normally.
                debugLog("[PAYMENT][PENDING_STATE_STALE_CLEARED] persisted txId \(savedTxId) is no longer unfinished; clearing.")
                self.clearPendingSyncState()
            }
        }
    }
    
    public func scheduleAutoRetryIfNeeded() {
        guard isSyncPending, autoRetryTask == nil else { return }
        autoRetryTask = Task { @MainActor [weak self] in
            // Extended exponential-style backoff: covers up to ~4.5 minutes total
            // Handles server cold-start (Cloud Run spin-up ~10-15s), transient outages
            let delays: [UInt64] = [5, 15, 30, 60, 120, 180]
            for delaySec in delays {
                try? await Task.sleep(nanoseconds: delaySec * 1_000_000_000)
                guard let self = self, self.isSyncPending else { break }
                debugLog("[PAYMENT][AUTO_RETRY_ACTIVATION] Attempting automatic sync after \(delaySec)s...")
                let resolved = await self.retryPendingSync()
                if resolved {
                    debugLog("[PAYMENT][AUTO_RETRY_ACTIVATION] Automatic sync succeeded!")
                    break
                }
            }
            self?.autoRetryTask = nil
        }
    }
    
    #if DEBUG
    public var reconciliationCallCountForTesting: Int = 0
    public var isReconciliationInFlightForTesting: Bool {
        return inFlightReconciliationTask != nil
    }
    public var inFlightProcessingTasksCountForTesting: Int {
        return inFlightProcessingTasks.count
    }
    
    public func setSessionTransactionResultForTesting(txId: String, result: BackendProcessingResult) {
        self.sessionTransactionResults[txId] = result
    }
    public func getSessionTransactionResultForTesting(txId: String) -> BackendProcessingResult? {
        return self.sessionTransactionResults[txId]
    }
    public func clearSessionTransactionResultsForTesting() {
        self.sessionTransactionResults.removeAll()
    }
    
    /// Simulates the exact manual purchase decision pipeline executed in executePurchase()
    /// without relying on Apple's StoreKit UI modal presentation.
    public func evaluateManualConsumablePurchaseForTesting(
        returnedTxId: String,
        isAlreadyProcessedOnBackend: Bool,
        creditsForProduct: Int,
        isKnownCompletedAtStart: Bool = false
    ) async -> (success: Bool, finishedTxIDs: [String], finalBalance: Int, errorDetail: String?) {
        self.isLoading = false
        self.isActivating = false
        defer {
            self.isLoading = false
            self.isActivating = false
        }
        var finishedTxIDs: [String] = []
        
        // 1. Layer 1: Known completed transaction at start of manual purchase
        if isKnownCompletedAtStart || sessionTransactionResults[returnedTxId] != nil {
            finishedTxIDs.append(returnedTxId)
            return (false, finishedTxIDs, self.remainingPlotCredits, "Previous purchase synchronized. Your balance is \(self.remainingPlotCredits) plot searches. Please tap again.")
        }
        
        // 2. Layer 2: Backend reports already processed
        if isAlreadyProcessedOnBackend {
            finishedTxIDs.append(returnedTxId)
            let result = BackendProcessingResult(
                success: false,
                alreadyProcessed: true,
                creditsGranted: 0,
                currentBalance: self.remainingPlotCredits,
                statusCode: 200,
                failureReason: "already_processed_by_server",
                userErrorMessage: "This purchase was already credited."
            )
            self.sessionTransactionResults[returnedTxId] = result
            return (false, finishedTxIDs, self.remainingPlotCredits, "Previous purchase synchronized. Your balance is \(self.remainingPlotCredits) plot searches. Please tap again.")
        }
        
        // 3. Fresh new transaction: deliver and grant credits
        finishedTxIDs.append(returnedTxId)
        #if DEBUG
        self.realPlotCredits += creditsForProduct
        self.recalculateCreditsFromTestManager()
        #else
        self.remainingPlotCredits += creditsForProduct
        #endif
        self.persistCurrentCredits()
        CreditTransactionManager.shared.recordCreditAdded(
            amount: creditsForProduct,
            title: "+\(creditsForProduct) Plot Searches",
            category: .purchase,
            details: "Apple In-App Purchase",
            balanceAfter: self.remainingPlotCredits
        )
        let result = BackendProcessingResult(
            success: true,
            alreadyProcessed: false,
            creditsGranted: creditsForProduct,
            currentBalance: self.remainingPlotCredits,
            statusCode: 200
        )
        self.sessionTransactionResults[returnedTxId] = result
        return (true, finishedTxIDs, self.remainingPlotCredits, nil)
    }
    #endif
    
    private init() {
        // 1. Recover cached credit and unlimited state from secure Keychain
        loadInitialCreditState()
        restorePendingSyncState()
        
        // 2. Start background transaction listener immediately on app launch
        transactionListenerTask = listenForTransactions()
        
        // 3. Register for app foreground transitions to reconcile entitlements
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.reconcileOnForeground()
                }
            }
            .store(in: &cancellables)
        
        // 4. Load products, verify existing entitlements, and fetch server-authoritative balance
        Task {
            await loadProducts()
            await updateSubscriptionStatus()
            await fetchServerCreditBalance()
            await fetchServerSubscriptionStatus()
            await processUnfinishedTransactions()
        }
    }
    
    // MARK: - Persistent Credit Loading
    
    private func loadInitialCreditState() {
        let isDeviceInit = (KeychainHelper.shared.readString(key: keychainDeviceInitKey) == "true")
        if !isDeviceInit {
            // Brand new first-time install: grant initial Free starter credits
            KeychainHelper.shared.save(key: keychainDeviceInitKey, string: "true")
            KeychainHelper.shared.save(key: keychainDeviceCreditsKey, string: "\(Self.defaultFreeStarterCredits)")
            KeychainHelper.shared.save(key: keychainDeviceUnlimitedKey, string: "false")
            self.remainingPlotCredits = Self.defaultFreeStarterCredits
            self.isUnlimited = false
            debugLog("DEBUG: 🎁 Initialized \(Self.defaultFreeStarterCredits) Free starter plot credits for new install.")
        } else {
            // Check if there is an authenticated user with cached credits (using UserDefaults to avoid circular singleton initialization)
            if let lastUserId = UserDefaults.standard.string(forKey: "last_authenticated_user_id"), !lastUserId.isEmpty,
               let savedUserCreditsStr = KeychainHelper.shared.readString(key: userCreditsKey(for: lastUserId)),
               let userCredits = Int(savedUserCreditsStr) {
                let savedUnlimited = (KeychainHelper.shared.readString(key: userUnlimitedKey(for: lastUserId)) == "true")
                self.remainingPlotCredits = userCredits
                self.isUnlimited = savedUnlimited
                debugLog("DEBUG: 🔒 Restored cached user credits from Keychain: \(userCredits), unlimited: \(savedUnlimited)")
            } else {
                // Existing device: restore cached remaining credits from Keychain
                let savedCredits = Int(KeychainHelper.shared.readString(key: keychainDeviceCreditsKey) ?? "\(Self.defaultFreeStarterCredits)") ?? Self.defaultFreeStarterCredits
                let savedUnlimited = (KeychainHelper.shared.readString(key: keychainDeviceUnlimitedKey) == "true")
                self.remainingPlotCredits = savedCredits
                self.isUnlimited = savedUnlimited
                debugLog("DEBUG: 🔒 Restored cached device credits from Keychain: \(savedCredits), unlimited: \(savedUnlimited)")
            }
        }
        #if DEBUG
        self.realPlotCredits = self.remainingPlotCredits
        self.recalculateCreditsFromTestManager()
        #endif
    }
    
    public func handleUserSignIn(userId: String) {
        self.isLoadingCredits = true
        // Restore user-specific cached credits from Keychain immediately so credits are never lost or zeroed out
        let userCreditKey = userCreditsKey(for: userId)
        if let savedUserCredits = KeychainHelper.shared.readString(key: userCreditKey),
           let cached = Int(savedUserCredits) {
            self.remainingPlotCredits = cached
            let savedUnlimited = (KeychainHelper.shared.readString(key: userUnlimitedKey(for: userId)) == "true")
            self.isUnlimited = savedUnlimited
            debugLog("DEBUG: 🔒 Restored cached user credits from Keychain for \(userId): \(cached), unlimited: \(savedUnlimited)")
        } else {
            // Fall back to device Keychain credits
            let deviceCredits = Int(KeychainHelper.shared.readString(key: keychainDeviceCreditsKey) ?? "\(Self.defaultFreeStarterCredits)") ?? Self.defaultFreeStarterCredits
            let deviceUnlimited = (KeychainHelper.shared.readString(key: keychainDeviceUnlimitedKey) == "true")
            self.remainingPlotCredits = deviceCredits
            self.isUnlimited = deviceUnlimited
            debugLog("DEBUG: 🔒 Fallback to device credits from Keychain for \(userId): \(deviceCredits), unlimited: \(deviceUnlimited)")
        }
        #if DEBUG
        self.realPlotCredits = self.remainingPlotCredits
        self.recalculateCreditsFromTestManager()
        #endif
        
        // Merge anything bought while signed out into this account FIRST, so the
        // balance is right and old guest purchases are recognised as ours (not
        // "belongs to another account") when the unfinished queue is replayed.
        Task {
            await claimGuestWallet()
            await fetchServerCreditBalance()
            await fetchServerSubscriptionStatus()
            await processUnfinishedTransactions()
        }
    }

    /// Moves the device's guest wallet (credits, packs, Unlimited+) into the
    /// signed-in account. Idempotent and cheap; runs on sign-in and launch.
    public func claimGuestWallet() async {
        // A different account may own purchases this device rejected before.
        let accountId = AuthManager.shared.currentUser?.id ?? "guest"
        if UserDefaults.standard.string(forKey: "bhumitra_settled_owner_v1") != accountId {
            clearSettledRejected()
            UserDefaults.standard.set(accountId, forKey: "bhumitra_settled_owner_v1")
        }
        guard AuthManager.shared.isAuthenticated,
              let accountToken = KeychainHelper.shared.readString(key: "bhumitra_access_token"), !accountToken.isEmpty,
              let guestToken = await AuthManager.shared.guestSessionTokenForWalletMerge(),
              guestToken != accountToken,
              let url = URL(string: "\(APIConfiguration.shared.baseURL)/wallet/merge-guest") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accountToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 12
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["guest_token": guestToken])
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse else { return }
        if (200...299).contains(http.statusCode),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let moved = json["credits_moved"] as? Int ?? 0
            debugLog("[PAYMENT][WALLET_MERGE] moved credits=\(moved) purchases=\(json["purchases_moved"] ?? 0) subs=\(json["subscriptions_moved"] ?? 0)")
            if moved > 0 {
                CreditTransactionManager.shared.recordCreditAdded(
                    amount: moved, title: "Searches from this device",
                    category: .purchase, details: "Bought before you signed in",
                    balanceAfter: json["current_balance"] as? Int ?? remainingPlotCredits)
            }
        } else {
            debugLog("[PAYMENT][WALLET_MERGE] skipped: HTTP \(http.statusCode)")
        }
    }
    
    public func handleUserSignOut() {
        // Clear memory state so next user does not inherit prior user's balance
        self.isPremium = false
        self.isUnlimited = false
        self.activeTier = nil
        self.remainingPlotCredits = 0
        self.isLoadingCredits = false
        debugLog("DEBUG: 🚪 Cleaned up SubscriptionManager state for signed-out user.")
    }
    
    #if DEBUG
    /// Explicit testing reset: resets active testing device/account usage to 0 (all credits available)
    public func resetTestUserCredits(to amount: Int = defaultFreeStarterCredits) {
        self.isLoading = false
        self.isActivating = false
        self.remainingPlotCredits = amount
        #if DEBUG
        self.realPlotCredits = amount
        TestCreditManager.shared.resetCredits()
        #endif
        self.isUnlimited = false
        self.isPremium = false
        self.activeTier = nil
        KeychainHelper.shared.save(key: keychainDeviceCreditsKey, string: "\(amount)")
        KeychainHelper.shared.save(key: keychainDeviceInitKey, string: "true")
        KeychainHelper.shared.save(key: keychainDeviceUnlimitedKey, string: "false")
        if let user = AuthManager.shared.currentUser {
            KeychainHelper.shared.save(key: userCreditsKey(for: user.id), string: "\(amount)")
            KeychainHelper.shared.save(key: userInitKey(for: user.id), string: "true")
            KeychainHelper.shared.save(key: userUnlimitedKey(for: user.id), string: "false")
            DatabaseManager.shared.resetUsage(for: user.id, month: currentMonthString)
        }
        debugLog("DEBUG: 🔄 Reset test account usage to 0 with \(amount) available plot search credits.")
    }
    #endif
    
    private func persistCurrentCredits() {
        #if DEBUG
        let creditsToPersist = realPlotCredits
        #else
        let creditsToPersist = remainingPlotCredits
        #endif
        
        // 1. Save to Device Keychain
        KeychainHelper.shared.save(key: keychainDeviceCreditsKey, string: "\(creditsToPersist)")
        KeychainHelper.shared.save(key: keychainDeviceUnlimitedKey, string: isUnlimited ? "true" : "false")
        
        // 2. Save to User Keychain if signed in
        if let user = AuthManager.shared.currentUser {
            KeychainHelper.shared.save(key: userCreditsKey(for: user.id), string: "\(creditsToPersist)")
            KeychainHelper.shared.save(key: userUnlimitedKey(for: user.id), string: isUnlimited ? "true" : "false")
        }
    }
    
    // MARK: - Quota & Credit Operations
    
    public var canPerformPlotSearch: Bool {
        isUnlimited || isPremium || remainingPlotCredits > 0
    }
    
    public func setUnlimited(_ unlimited: Bool) {
        isUnlimited = unlimited
        persistCurrentCredits()
        debugLog("DEBUG: ♾️ Set Unlimited Plot Searches: \(unlimited)")
    }
    
    @discardableResult
    public func consumePlotSearchCredit(
        plot: String? = nil,
        village: String? = nil,
        district: String? = nil
    ) -> Bool {
        #if DEBUG
        if TestCreditManager.shared.testCredits > 0 {
            let success = TestCreditManager.shared.consumeCredits(1)
            if success {
                recalculateCreditsFromTestManager()
                debugLog("DEBUG: 📉 Consumed 1 TEST plot credit. Remaining test: \(TestCreditManager.shared.testCredits), total: \(remainingPlotCredits)")
                
                let locationParts = [village, district].compactMap { $0 }.filter { !$0.isEmpty }
                let locationStr = locationParts.isEmpty ? nil : locationParts.joined(separator: ", ")
                let titleStr: String = {
                    if let p = plot, !p.isEmpty {
                        return "Plot #\(p) Cadastral Search (Test Credit)"
                    }
                    return "Cadastral Plot Search (Test Credit)"
                }()
                
                CreditTransactionManager.shared.recordCreditSpent(
                    amount: 1,
                    title: titleStr,
                    category: .plotSearch,
                    details: locationStr,
                    balanceAfter: remainingPlotCredits
                )
                
                let bucket = AnalyticsCreditBucket.bucket(for: remainingPlotCredits, isUnlimited: false)
                AnalyticsService.shared.log(.plotCreditConsumed(
                    remainingCreditBucket: bucket,
                    isUnlimited: false
                ))
                if remainingPlotCredits <= 3 && remainingPlotCredits > 0 {
                    AnalyticsService.shared.log(.creditsLowWarningShown(remainingCreditBucket: bucket))
                } else if remainingPlotCredits == 0 {
                    AnalyticsService.shared.log(.creditsExhausted(triggerSource: "search_deduction"))
                }
                return true
            }
        }
        #endif
        
        if isUnlimited || isPremium {
            AnalyticsService.shared.log(.plotCreditConsumed(
                remainingCreditBucket: "50+",
                isUnlimited: true
            ))
            return true
        }
        
        if remainingPlotCredits > 0 {
            remainingPlotCredits -= 1
            #if DEBUG
            realPlotCredits = max(0, realPlotCredits - 1)
            #endif
            persistCurrentCredits()
            debugLog("DEBUG: 📉 Consumed 1 plot credit. Remaining: \(remainingPlotCredits)")
            
            let locationParts = [village, district].compactMap { $0 }.filter { !$0.isEmpty }
            let locationStr = locationParts.isEmpty ? nil : locationParts.joined(separator: ", ")
            let titleStr: String = {
                if let p = plot, !p.isEmpty {
                    return "Plot #\(p) Cadastral Search"
                }
                return "Cadastral Plot Search"
            }()
            
            CreditTransactionManager.shared.recordCreditSpent(
                amount: 1,
                title: titleStr,
                category: .plotSearch,
                details: locationStr,
                balanceAfter: remainingPlotCredits
            )
            
            let bucket = AnalyticsCreditBucket.bucket(for: remainingPlotCredits, isUnlimited: false)
            AnalyticsService.shared.log(.plotCreditConsumed(
                remainingCreditBucket: bucket,
                isUnlimited: false
            ))
            if remainingPlotCredits <= 3 && remainingPlotCredits > 0 {
                AnalyticsService.shared.log(.creditsLowWarningShown(remainingCreditBucket: bucket))
            } else if remainingPlotCredits == 0 {
                AnalyticsService.shared.log(.creditsExhausted(triggerSource: "search_deduction"))
            }
            return true
        } else {
            AnalyticsService.shared.log(.creditsExhausted(triggerSource: "search_blocked"))
            return false
        }
    }
    
    deinit {
        transactionListenerTask?.cancel()
    }
    
    // MARK: - Product Fetching
    
    /// Loads all tiered products directly from Apple StoreKit 2 servers (Zero hardcoded prices)
    public func loadProducts() async {
        isLoading = true
        errorMessage = nil
        
        let bundleID = Bundle.main.bundleIdentifier ?? "N/A"
        let storefrontCode = await Storefront.current?.countryCode ?? "N/A"
        let storefrontID = await Storefront.current?.id ?? "N/A"
        let requestedList = productIDs.sorted()
        
        debugLog("[STOREKIT DIAGNOSTIC] ==================================================")
        debugLog("[STOREKIT DIAGNOSTIC] 📱 Bundle ID: \(bundleID)")
        debugLog("[STOREKIT DIAGNOSTIC] 🌍 Storefront: \(storefrontCode) (ID: \(storefrontID))")
        debugLog("[STOREKIT DIAGNOSTIC] 📋 Requested Product IDs (\(requestedList.count)): \(requestedList)")
        
        // 1. Primary Batch Request
        do {
            let fetchedProducts = try await Product.products(for: productIDs)
            debugLog("[STOREKIT DIAGNOSTIC] 📦 Returned Product Count: \(fetchedProducts.count)")
            
            for p in fetchedProducts {
                debugLog("[STOREKIT DIAGNOSTIC]   👉 Product ID: \(p.id)")
                debugLog("[STOREKIT DIAGNOSTIC]      Type: \(p.type)")
                debugLog("[STOREKIT DIAGNOSTIC]      Display Name: \(p.displayName)")
                debugLog("[STOREKIT DIAGNOSTIC]      Price: \(p.displayPrice)")
                debugLog("[STOREKIT DIAGNOSTIC]      Description: \(p.description)")
            }
            
            let fetchedIDs = Set(fetchedProducts.map { $0.id })
            let missingIDs = productIDs.subtracting(fetchedIDs)
            if !missingIDs.isEmpty {
                debugLog("[STOREKIT DIAGNOSTIC] ⚠️ Products NOT returned by Apple: \(missingIDs.sorted())")
            }
            
            if fetchedProducts.isEmpty {
                debugLog("[STOREKIT DIAGNOSTIC] ⚠️ StoreKit returned 0 products from Apple. Possible causes: Paid Applications Agreement pending in App Store Connect, missing in-app purchase metadata/pricing, or inactive Sandbox account.")
                self.errorMessage = "Products unavailable from App Store. Please check App Store Connect agreement status or Sandbox account."
            }
            
            // Sort products by tier
            self.products = fetchedProducts
            self.tenPlotsProduct = fetchedProducts.first(where: { $0.id == Self.tenPlotsProductID })
            self.fiftyPlotsProduct = fetchedProducts.first(where: { $0.id == Self.fiftyPlotsProductID })
            self.twoHundredPlotsProduct = fetchedProducts.first(where: { $0.id == Self.twoHundredPlotsProductID })
            self.monthlyProduct = fetchedProducts.first(where: { $0.id == Self.monthlyProductID })
            
        } catch {
            debugLog("[STOREKIT DIAGNOSTIC] ❌ StoreKit Request Error: \(error.localizedDescription) | Detail: \(error)")
            self.errorMessage = "App Store request failed: \(error.localizedDescription)"
        }
        
        self.isLoading = false
    }
    
    // MARK: - Purchase Flow
    
    /// Purchases a specific StoreKit 2 product
    public func purchase(_ product: Product) async -> Result<Transaction, Error> {
        return await executePurchase(product: product)
    }
    
    /// Purchases by tier
    public func purchaseTier(_ tier: ProductTier) async -> Result<Transaction, Error> {
        
        let targetID = tier.rawValue
        debugLog("[StoreKit-Diagnostic] 🛒 Purchase initiated for Tier: \(tier.rawValue) | Target Product ID: '\(targetID)'")
        
        let product: Product?
        switch tier {
        case .tenPlots: product = tenPlotsProduct
        case .fiftyPlots: product = fiftyPlotsProduct
        case .twoHundredPlots: product = twoHundredPlotsProduct
        case .monthly: product = monthlyProduct
        }
        
        debugLog("[StoreKit-Diagnostic] 📦 Cached Product object is \(product == nil ? "NIL (not returned by Apple StoreKit)" : "PRESENT ('\(product!.id)')")")
        
        guard let validProduct = product else {
            debugLog("[StoreKit-Diagnostic] 🔄 Attempting immediate re-fetch for products...")
            await loadProducts()
            let refreshed = products.first(where: { $0.id == targetID })
            guard let finalProduct = refreshed else {
                debugLog("[StoreKit-Diagnostic] ❌ Product '\(targetID)' was not returned by Apple StoreKit. (Available: \(products.map { $0.id }))")
                self.isLoading = false
                let message = "This plan is currently unavailable from the App Store. Please check your connection and try again."
                // Never reached Apple's payment sheet: no charge occurred.
                self.lastPurchaseOutcome = .failed(reason: message, retryable: true, charged: false)
                let error = NSError(
                    domain: "StoreKitManager",
                    code: 404,
                    userInfo: [NSLocalizedDescriptionKey: message]
                )
                return .failure(error)
            }
            return await executePurchase(product: finalProduct)
        }
        
        return await executePurchase(product: validProduct)
    }

    /// Preferred entry point for the paywall. Returns an exhaustive
    /// `PurchaseOutcome` so the UI never has to interpret NSError codes and can
    /// never dead-end into a "tap again" state. Internally reuses the existing
    /// verified/atomic purchase pipeline; `executePurchase` records the semantic
    /// outcome in `lastPurchaseOutcome`.
    public func purchaseTierOutcome(_ tier: ProductTier) async -> PurchaseOutcome {
        // Default to a safe terminal state so a thrown/early path is never
        // misread as a stale success.
        self.lastPurchaseOutcome = .failed(
            reason: "Unable to start the purchase. Please try again.",
            retryable: true,
            charged: false
        )
        _ = await purchaseTier(tier)
        return self.lastPurchaseOutcome
    }

    private func executePurchase(product: Product) async -> Result<Transaction, Error> {
        isLoading = true
        errorMessage = nil
        paymentSyncState = .purchasing
        isActivating = false
        isSyncPending = false
        
        defer {
            self.isLoading = false
            self.isActivating = false
        }
        
        let priceVal = NSDecimalNumber(decimal: product.price).doubleValue
        debugLog("[PAYMENT][PURCHASE_REQUESTED] productId: \(product.id)")
        
        // 1. Pre-purchase authentication guard
        // StoreKit 2 consumables can be purchased by both registered users and guest devices.
        var currentBearerToken = await MainActor.run { AuthManager.shared.bearerToken }
        if currentBearerToken == nil || currentBearerToken?.isEmpty == true {
            await AuthManager.shared.ensureDeviceSession(force: true)
            currentBearerToken = await MainActor.run { AuthManager.shared.bearerToken }
        }
        guard let token = currentBearerToken, !token.isEmpty else {
            self.isLoading = false
            debugLog("[PAYMENT][AUTH_MISSING] productId: \(product.id). Cannot purchase: session token is missing.")
            let message = "Unable to connect to Bhumitra services. Please check your internet connection and try again."
            // Pre-payment failure: no charge has occurred yet.
            self.lastPurchaseOutcome = .failed(reason: message, retryable: true, charged: false)
            self.paymentSyncState = .failed(message: message)
            let authError = NSError(
                domain: "StoreKitManager",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: message]
            )
            return .failure(authError)
        }
        
        // 2. Snapshot transaction IDs already delivered in this session BEFORE
        // calling Product.purchase(). A transaction returned by purchase() whose id
        // is in this set is a leftover/duplicate (not the fresh purchase the user
        // just made); a NEW id is a genuine fresh purchase.
        //
        // NOTE: We intentionally do NOT run processUnfinishedTransactions() here.
        // Reconciling leftover transactions inside a manual purchase caused the
        // flow to resolve off a stale transaction and show a "confirmation" screen
        // without Apple ever presenting the payment sheet (and with no new
        // credits). Leftover-transaction reconciliation happens on app launch and
        // on foreground (init + reconcileOnForeground); a manual tap must go
        // straight to Apple's payment sheet.
        let completedTxIDsAtStart = Set(sessionTransactionResults.keys)
        
        do {
            // Configure purchase with user's or device's permanent appAccountToken UUID
            var options: Set<Product.PurchaseOption> = []
            var optionsDesc = "none"
            if let user = AuthManager.shared.currentUser {
                let accountUUID = user.appAccountUUID
                options.insert(.appAccountToken(accountUUID))
                optionsDesc = "appAccountToken(\(accountUUID.uuidString))"
                debugLog("DEBUG: 🔗 Associating Apple Purchase with Bhumitra User '\(user.id)' via appAccountToken: \(accountUUID.uuidString)")
            } else {
                let accountTokenKey = "apple_app_account_token_device"
                let rawToken = KeychainHelper.shared.readString(key: accountTokenKey) ?? User.deterministicUUID(for: "dev_\(AuthManager.shared.deviceId)").uuidString.lowercased()
                if let devUUID = UUID(uuidString: rawToken) {
                    options.insert(.appAccountToken(devUUID))
                    optionsDesc = "appAccountToken(device:\(devUUID.uuidString))"
                    debugLog("DEBUG: 🔗 Associating Apple Purchase with Bhumitra Device via appAccountToken: \(devUUID.uuidString)")
                }
            }
            
            debugLog("[PAYMENT][MANUAL_PURCHASE_START]\nproductID=\(product.id)\npurchaseOptions=\(optionsDesc)")
            debugLog("[PAYMENT][PRODUCT_PURCHASE_ENTERED]")
            debugLog("[PAYMENT][STOREKIT]\nCalling product.purchase()")
            let result = try await product.purchase(options: options)
            
            switch result {
            case .success(let verificationResult):
                debugLog("[PAYMENT][STOREKIT_RESULT]\nsuccess")
                debugLog("[PAYMENT] StoreKit result received: success")
                debugLog("[PAYMENT][STOREKIT_TRANSACTION_RECEIVED] productId: \(product.id)")
                self.isActivating = true
                self.paymentSyncState = .activating(productTitle: product.displayName)
                
                let rawTxId: UInt64
                let rawOriginalTxId: UInt64
                let rawProductID: String
                let rawVerification: String
                let rawTxProductType: String
                
                switch verificationResult {
                case .verified(let t):
                    rawTxId = t.id
                    rawOriginalTxId = t.originalID
                    rawProductID = t.productID
                    rawVerification = "verified"
                    rawTxProductType = String(describing: t.productType)
                case .unverified(let t, let err):
                    rawTxId = t.id
                    rawOriginalTxId = t.originalID
                    rawProductID = t.productID
                    rawVerification = "unverified(\(err.localizedDescription))"
                    rawTxProductType = String(describing: t.productType)
                }
                
                debugLog("[PAYMENT][PRODUCT_PURCHASE_RESULT]\ntransactionID=\(rawTxId)\noriginalTransactionID=\(rawOriginalTxId)\nproductID=\(rawProductID)\nproductType=\(product.type)\ntransactionProductType=\(rawTxProductType)\nverification=\(rawVerification)\npurchaseResultCase=success")
                
                let classification: String
                if completedTxIDsAtStart.contains(String(rawTxId)) {
                    classification = "stale"
                } else if sessionTransactionResults[String(rawTxId)] != nil {
                    classification = "historical"
                } else {
                    classification = "fresh"
                }
                debugLog("[PAYMENT][MANUAL_PURCHASE_CLASSIFICATION]\nclassification=\(classification)")
                
                // 3. Cryptographically verify Apple's JWS signed transaction
                let transaction: Transaction
                do {
                    transaction = try checkVerified(verificationResult)
                    debugLog("[PAYMENT] Verification result: verified")
                    debugLog("[PAYMENT] Transaction ID = \(transaction.id), Original Transaction ID = \(transaction.originalID)")
                    debugLog("[PAYMENT][TRANSACTION_VERIFIED] productId: \(transaction.productID), txId: \(transaction.id)")
                } catch {
                    self.isLoading = false
                    self.isActivating = false
                    self.paymentSyncState = .failed(message: error.localizedDescription)
                    // Apple returned .success but the JWS failed local verification.
                    // The payment is real, so reassure rather than say "not charged".
                    self.lastPurchaseOutcome = .failed(
                        reason: "We couldn't verify this purchase with Apple. Your payment is safe — please try Restore or contact support.",
                        retryable: true,
                        charged: true
                    )
                    debugLog("[PAYMENT] Verification result: unverified (error: \(error.localizedDescription))")
                    debugLog("[PAYMENT] isPurchasing / isLoading reset: isLoading = false")
                    debugLog("[PAYMENT][STOREKIT_UNVERIFIED] productId: \(product.id), error: \(error.localizedDescription)")
                    return .failure(error)
                }
                
                let txIdStr = String(transaction.id)
                let resolvedTier = ProductTier(rawValue: transaction.productID) ?? ProductTier(rawValue: product.id) ?? .tenPlots
                guard transaction.productID == product.id else {
                    self.isLoading = false
                    self.isActivating = false
                    self.paymentSyncState = .failed(message: "Product ID mismatch")
                    self.lastPurchaseOutcome = .failed(
                        reason: "This purchase didn't match the selected product. Your payment is safe — please try Restore or contact support.",
                        retryable: false,
                        charged: true
                    )
                    debugLog("[PAYMENT] isPurchasing / isLoading reset: isLoading = false")
                    let mismatchErr = NSError(
                        domain: "StoreKitManager",
                        code: 400,
                        userInfo: [NSLocalizedDescriptionKey: "Transaction product ID mismatch. Expected \(product.id), got \(transaction.productID)"]
                    )
                    return .failure(mismatchErr)
                }
                
                // STUCK/REPLAYED TRANSACTION GUARD.
                //
                // If product.purchase() returned a transaction whose id was ALREADY
                // known before this tap (it was in the session cache from launch
                // reconciliation), StoreKit did NOT create a fresh purchase and did
                // NOT show the payment sheet — it replayed a stuck sandbox/App Store
                // transaction. Proceeding into the coordinator here produces a
                // misleading ".alreadyOwned / balance up to date (0)" that looks
                // like nothing happened. Instead, finish the stale transaction and
                // return an HONEST failure so the user knows the real situation.
                //
                // NOTE: A prior "stuck transaction" heuristic guard was removed here.
                // It tried to detect StoreKit replaying an old sandbox transaction by
                // timing/id, but it also blocked LEGITIMATE purchases (a real buy that
                // showed the Apple sheet and prompted for the password). The genuinely
                // stuck-sandbox case is an Apple account-state problem resolved by
                // switching sandbox testers — not something the app should infer with
                // heuristics. We now always route the verified transaction through the
                // authoritative backend below, which is the single source of truth for
                // granted / already-processed / cross-user-rejected.
                let jwsRepresentation = verificationResult.jwsRepresentation
                
                // 4. Check if product is Consumable vs Subscription
                if Self.consumableProductIDs.contains(transaction.productID) {
                    // "Fresh" = this transaction id was NOT already delivered before
                    // this tap. Only a fresh purchase may be reported as a new grant
                    // from a concurrent-delivery cache hit; a replayed/stale tx must
                    // resolve as alreadyProcessed (no phantom credits, no phantom
                    // success screen).
                    let isFreshUserPurchase = !completedTxIDsAtStart.contains(txIdStr)
                    // Send transaction through the centralized coordinator
                    let backendResult = await coordinateConsumableTransaction(
                        transaction: transaction,
                        jwsRepresentation: jwsRepresentation,
                        source: "executePurchase",
                        isFreshUserPurchase: isFreshUserPurchase
                    )
                    
                    let postAudit = await self.inspectTransactionState(for: product.id, txIdStr: txIdStr)
                    debugLog("[PAYMENT][TRANSACTION_STATE_AUDIT]\ntransactionID=\(txIdStr)\nactiveUnfinishedContains=\(postAudit.unfinished)\nsessionTransactionResultsContains=\(self.sessionTransactionResults[txIdStr] != nil)\nbackendProcessed=\(backendResult.alreadyProcessed || backendResult.success)\nlatestForProduct=\(postAudit.latest)\ncurrentEntitlementsContains=\(postAudit.currentEntitlement)\nlastUpdatesTransactionID=\(self.lastUpdatesTransactionID)")
                    
                    self.isLoading = false
                    debugLog("[PAYMENT] isPurchasing / isLoading reset: isLoading = false")
                    
                    // AUTHORITATIVE GRANT CHECK (race-proof):
                    // If the backend delivered a positive credit grant for THIS exact
                    // transaction id anywhere in this session — either via this
                    // executePurchase call, or via the concurrent Transaction.updates
                    // listener that won the race and cached the result before we entered
                    // the coordinator — then the user's purchase genuinely added credits
                    // and MUST be shown as .granted. This removes the dependency on the
                    // fragile isFreshUserPurchase/isHistoricalCacheHit timing that could
                    // misreport a real fresh purchase as "balance up to date".
                    let recordedGrant = self.grantedTxIDsThisSession[txIdStr]
                    let directGrant = backendResult.success
                        && !backendResult.alreadyProcessed
                        && backendResult.creditsGranted > 0
                        && !backendResult.isHistoricalCacheHit

                    if directGrant || recordedGrant != nil {
                        let creditsGranted = directGrant ? backendResult.creditsGranted : (recordedGrant?.creditsGranted ?? 0)
                        let balance = directGrant ? backendResult.currentBalance : (recordedGrant?.balance ?? backendResult.currentBalance)
                        self.isActivating = false
                        self.lastGrantedCredits = creditsGranted
                        self.lastAuthoritativeBalance = balance
                        self.clearPendingSyncState(productTitle: product.displayName)
                        self.lastPurchaseOutcome = .granted(
                            tier: resolvedTier,
                            creditsGranted: creditsGranted,
                            balance: balance
                        )
                        AnalyticsService.shared.log(.purchaseCompleted(
                            productID: transaction.productID,
                            productType: "consumable",
                            creditsGranted: creditsGranted,
                            price: priceVal
                        ))
                        return .success(transaction)
                    } else if backendResult.alreadyProcessed || backendResult.isHistoricalCacheHit {
                        // The server had already credited this exact transaction.
                        // This is a SUCCESS for the user, NOT a "tap again" error:
                        // reconcile the authoritative balance and report .alreadyOwned.
                        debugLog("[PAYMENT][ALREADY_PROCESSED_RETURNED] txId: \(txIdStr) reported alreadyProcessed by backend or coordinator cache. Finishing transaction silently.")
                        await safelyFinishTransaction(transaction, txIdStr: txIdStr, reason: "already_processed_cleanup")
                        await fetchServerCreditBalance()
                        self.clearPendingSyncState(productTitle: product.displayName)
                        self.lastAuthoritativeBalance = self.authoritativeBalance
                        self.lastPurchaseOutcome = .alreadyOwned(
                            tier: resolvedTier,
                            balance: self.authoritativeBalance
                        )
                        // Return .success so any legacy caller treats it as completed;
                        // the paywall reads lastPurchaseOutcome for the precise state.
                        return .success(transaction)
                    } else if let code = backendResult.statusCode, Self.isPermanentConsumableRejection(code) {
                        self.isActivating = false
                        self.clearPendingSyncState()
                        self.lastPurchaseOutcome = .failed(
                            reason: backendResult.userErrorMessage,
                            retryable: false,
                            charged: true
                        )
                        let rejected = NSError(domain: "StoreKitManager", code: code,
                                               userInfo: [NSLocalizedDescriptionKey: backendResult.userErrorMessage])
                        return .failure(rejected)
                    } else {
                        // Backend confirmation pending: transaction is safe in Apple's queue
                        self.isActivating = false
                        self.savePendingSyncState(txId: txIdStr, title: product.displayName)
                        let msg = "Payment received — Apple has confirmed your payment. We're activating your plot searches. You won't be charged again."
                        self.lastPurchaseOutcome = .pendingActivation(tier: resolvedTier, message: msg)
                        let pendingError = NSError(
                            domain: "StoreKitManager",
                            code: 1001,
                            userInfo: [NSLocalizedDescriptionKey: msg]
                        )
                        return .failure(pendingError)
                    }
                } else {
                    // Subscription Flow: Submit signed JWS to backend subscription verification endpoint.
                    // A fresh purchase always asks the server, even if an older chain of
                    // the same subscription was rejected for a different account.
                    unmarkSettledRejected("sub:\(transaction.originalID)")
                    let token = transaction.appAccountToken?.uuidString
                    let syncSuccess = await syncSubscriptionWithBackend(
                        jwsRepresentation: jwsRepresentation,
                        originalTransactionId: String(transaction.originalID),
                        appAccountToken: token
                    )
                    
                    if syncSuccess {
                        await updateSubscriptionStatus()
                        await fetchServerCreditBalance()
                        await safelyFinishTransaction(transaction, txIdStr: txIdStr, reason: "subscription_verified")
                        
                        self.isLoading = false
                        self.isActivating = false
                        self.clearPendingSyncState(productTitle: product.displayName)
                        self.lastPurchaseOutcome = .granted(
                            tier: .monthly,
                            creditsGranted: 0,
                            balance: self.authoritativeBalance
                        )
                        debugLog("[PAYMENT] isPurchasing / isLoading reset: isLoading = false")
                        AnalyticsService.shared.log(.purchaseCompleted(
                            productID: transaction.productID,
                            productType: "subscription",
                            creditsGranted: 0,
                            price: priceVal
                        ))
                        AnalyticsService.shared.setAccountType(.premium)
                        return .success(transaction)
                    } else {
                        self.isLoading = false
                        self.isActivating = false
                        self.savePendingSyncState(txId: txIdStr, title: product.displayName)
                        let msg = "Payment received — Apple has confirmed your payment. We're activating your subscription. You won't be charged again."
                        self.lastPurchaseOutcome = .pendingActivation(tier: .monthly, message: msg)
                        debugLog("[PAYMENT] isPurchasing / isLoading reset: isLoading = false")
                        let pendingError = NSError(
                            domain: "StoreKitManager",
                            code: 1001,
                            userInfo: [NSLocalizedDescriptionKey: msg]
                        )
                        return .failure(pendingError)
                    }
                }
                
            case .userCancelled:
                self.isLoading = false
                self.isActivating = false
                self.isSyncPending = false
                self.paymentSyncState = .idle
                debugLog("[PAYMENT][STOREKIT_RESULT]\nuserCancelled")
                debugLog("[PAYMENT] StoreKit result received: userCancelled")
                debugLog("[PAYMENT] isPurchasing / isLoading reset: isLoading = false")
                debugLog("[PAYMENT][PRODUCT_PURCHASE_RESULT]\ntransactionID=none\noriginalTransactionID=none\nproductID=\(product.id)\nproductType=\(product.type)\ntransactionProductType=none\nverification=none\npurchaseResultCase=userCancelled")
                debugLog("[PAYMENT][MANUAL_PURCHASE_CLASSIFICATION]\nclassification=unknown")
                debugLog("[PAYMENT][USER_CANCELLED] productId: \(product.id)")
                self.lastPurchaseOutcome = .cancelled
                AnalyticsService.shared.log(.purchaseCancelled(productID: product.id))
                let error = NSError(domain: "StoreKitManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "Purchase was cancelled."])
                return .failure(error)
                
            case .pending:
                self.isLoading = false
                self.isActivating = false
                // Waiting for Ask to Buy / bank approval. Nothing has been charged,
                // so this is not the "payment received, activating" state.
                self.isSyncPending = false
                self.isAwaitingApproval = true
                self.paymentSyncState = .syncPending(productTitle: product.displayName, message: "Purchase is pending authorization (e.g. Ask to Buy).")
                debugLog("[PAYMENT][STOREKIT_RESULT]\npending")
                debugLog("[PAYMENT] StoreKit result received: pending")
                debugLog("[PAYMENT] isPurchasing / isLoading reset: isLoading = false")
                debugLog("[PAYMENT][PRODUCT_PURCHASE_RESULT]\ntransactionID=none\noriginalTransactionID=none\nproductID=\(product.id)\nproductType=\(product.type)\ntransactionProductType=none\nverification=none\npurchaseResultCase=pending")
                debugLog("[PAYMENT][MANUAL_PURCHASE_CLASSIFICATION]\nclassification=pending")
                debugLog("[PAYMENT][PURCHASE_PENDING_AUTHORIZATION] productId: \(product.id)")
                self.lastPurchaseOutcome = .awaitingApproval(tier: ProductTier(rawValue: product.id) ?? .tenPlots)
                let error = NSError(domain: "StoreKitManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Purchase is pending authorization (e.g. Ask to Buy)."])
                return .failure(error)
                
            @unknown default:
                self.isLoading = false
                self.isActivating = false
                self.paymentSyncState = .failed(message: "Unknown response")
                debugLog("[PAYMENT][STOREKIT_RESULT]\nunknown")
                debugLog("[PAYMENT] StoreKit result received: unknown")
                debugLog("[PAYMENT] isPurchasing / isLoading reset: isLoading = false")
                debugLog("[PAYMENT][PRODUCT_PURCHASE_RESULT]\ntransactionID=none\noriginalTransactionID=none\nproductID=\(product.id)\nproductType=\(product.type)\ntransactionProductType=none\nverification=none\npurchaseResultCase=unknown")
                debugLog("[PAYMENT][MANUAL_PURCHASE_CLASSIFICATION]\nclassification=unknown")
                debugLog("[PAYMENT][UNKNOWN_RESPONSE] productId: \(product.id)")
                self.lastPurchaseOutcome = .failed(
                    reason: "The App Store returned an unexpected response. Please try again.",
                    retryable: true,
                    charged: false
                )
                AnalyticsService.shared.log(.purchaseFailed(productID: product.id, errorCategory: .unknown))
                let error = NSError(domain: "StoreKitManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown purchase response from Apple."])
                return .failure(error)
            }
        } catch {
            let nsError = error as NSError
            self.isLoading = false
            self.isActivating = false
            self.paymentSyncState = .failed(message: error.localizedDescription)
            debugLog("[PAYMENT] isPurchasing / isLoading reset: isLoading = false")
            self.errorMessage = error.localizedDescription
            // product.purchase() threw — the payment sheet failed before completing,
            // so no charge occurred.
            self.lastPurchaseOutcome = .failed(
                reason: error.localizedDescription,
                retryable: true,
                charged: false
            )
            debugLog("[PAYMENT][STOREKIT_RESULT]\nfailure")
            debugLog("[PAYMENT][PURCHASE_ERROR]\nerrorDomain=\(nsError.domain)\nerrorCode=\(nsError.code)\nlocalizedDescription=\(error.localizedDescription)\nunderlyingError=\(String(describing: nsError.userInfo[NSUnderlyingErrorKey]))\nstoreKitErrorType=\(type(of: error))")
            AnalyticsService.shared.log(.purchaseFailed(productID: product.id, errorCategory: .unknown))
            return .failure(error)
        }
    }
    
    // MARK: - Restore Purchases
    
    /// Syncs with the App Store to restore previously purchased active auto-renewable subscriptions
    public func restorePurchases() async -> Result<Bool, Error> {
        isLoading = true
        errorMessage = nil
        
        do {
            try await AppStore.sync()
            await updateSubscriptionStatus()
            await fetchServerCreditBalance()
            
            self.isLoading = false
            if isPremium {
                debugLog("DEBUG: 🔄 Active subscription restored successfully. Active Tier: \(String(describing: activeTier))")
                return .success(true)
            } else {
                let error = NSError(domain: "StoreKitManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "No active subscription found for your Apple ID."])
                return .failure(error)
            }
        } catch {
            self.isLoading = false
            self.errorMessage = error.localizedDescription
            debugLog("DEBUG: ❌ Restore failed: \(error)")
            return .failure(error)
        }
    }
    
    // MARK: - Entitlements & Verification
    
    /// Verifies live user subscription entitlements directly from Apple's Transaction.currentEntitlements
    public func updateSubscriptionStatus() async {
        var purchasedTransactions: [Transaction] = []
        var hasActiveEntitlement = false
        var currentActiveTier: ProductTier? = nil
        
        for await verificationResult in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(verificationResult)
                
                // Only evaluate subscriptions (consumables are excluded from currentEntitlements)
                if Self.subscriptionProductIDs.contains(transaction.productID) && transaction.revocationDate == nil {
                    if let expirationDate = transaction.expirationDate {
                        if expirationDate > Date() {
                            purchasedTransactions.append(transaction)
                            hasActiveEntitlement = true
                            currentActiveTier = .monthly
                        }
                    } else {
                        purchasedTransactions.append(transaction)
                        hasActiveEntitlement = true
                        currentActiveTier = .monthly
                    }
                }
            } catch {
                debugLog("DEBUG: ⚠️ Entitlement failed verification: \(error)")
            }
        }
        
        self.activeTransactions = purchasedTransactions
        self.isPremium = hasActiveEntitlement
        self.activeTier = currentActiveTier
        
        // Sync with local user profile
        if var user = AuthManager.shared.currentUser {
            if user.isPremium != hasActiveEntitlement {
                user.isPremium = hasActiveEntitlement
                DatabaseManager.shared.saveUser(user)
                AuthManager.shared.refreshUser()
            }
        }
        
        debugLog("DEBUG: 🛡️ Entitlement evaluated: isPremium=\(hasActiveEntitlement), activeTier=\(String(describing: currentActiveTier))")
    }
    
    /// Cryptographically validates the JWS signature provided by Apple
    nonisolated private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }
    
    /// Audits and logs transaction state across StoreKit queues and local caches without iterating Transaction.unfinished
    public func inspectTransactionState(for productID: String, txIdStr: String) async -> (unfinished: Bool, latest: String, currentEntitlement: Bool, historicalCache: Bool) {
        let isUnfinished = activeUnfinishedTransactionIDs.contains(txIdStr)
        
        var latestIdStr = "none"
        if let latestResult = await Transaction.latest(for: productID) {
            switch latestResult {
            case .verified(let t): latestIdStr = String(t.id)
            case .unverified(let t, _): latestIdStr = String(t.id)
            }
        }
        
        let isEntitled = activeTransactions.contains { String($0.id) == txIdStr }
        let isHistorical = sessionTransactionResults[txIdStr] != nil
        return (isUnfinished, latestIdStr, isEntitled, isHistorical)
    }
    
    /// Safely finishes a transaction with StoreKit 2.
    /// StoreKit 2's transaction.finish() is idempotent and safe to call on any verified transaction.
    public func safelyFinishTransaction(_ transaction: Transaction, txIdStr: String, reason: String) async {
        debugLog("[PAYMENT][TRANSACTION_FINISH_START]\ntransactionID=\(txIdStr)")
        debugLog("[PAYMENT] Transaction finish started: transaction_id = \(txIdStr), reason: \(reason)")
        await transaction.finish()
        activeUnfinishedTransactionIDs.remove(txIdStr)
        debugLog("[PAYMENT] Transaction finish completed: transaction_id = \(txIdStr)")
        debugLog("[PAYMENT][TRANSACTION_FINISHED] txId: \(txIdStr), reason: \(reason)")
        debugLog("[PAYMENT][TRANSACTION_FINISH_COMPLETED]\ntransactionID=\(txIdStr)")
        debugLog("[PAYMENT][TRANSACTION_FINISH]\ntransactionID=\(txIdStr)\nresult=\(reason)")
    }
    
    /// Reconciles entitlements and credits when app returns to foreground.
    public func reconcileOnForeground() async {
        debugLog("[PAYMENT][FOREGROUND_RECONCILIATION_STARTED]")
        await processUnfinishedTransactions()
        await updateSubscriptionStatus()
        await fetchServerCreditBalance()
        await fetchServerSubscriptionStatus()
        if isSyncPending, let pendingId = pendingSyncTransactionId, !activeUnfinishedTransactionIDs.contains(pendingId) {
            self.clearPendingSyncState(productTitle: self.pendingSyncProductTitle)
        }
        scheduleAutoRetryIfNeeded()
        debugLog("[PAYMENT][FOREGROUND_RECONCILIATION_COMPLETED]")
    }
    
    /// User-initiated or automatic retry for synchronizing transactions without re-purchasing.
    /// Returns a typed result indicating whether credits were activated, already processed, or if no purchase was found.
    public func retryPendingSyncDetailed() async -> PendingSyncResult {
        debugLog("[PAYMENT][RETRY_SYNC_REQUESTED]")
        self.isActivating = true
        defer {
            self.isActivating = false
        }
        
        // Make sure some session token exists. Never force here: forcing used to
        // delete a signed-in user's token, crediting the retried purchase to the
        // anonymous device account instead.
        await AuthManager.shared.ensureDeviceSession()
        
        var foundAnyPendingTransaction = false
        var anyActivated = false
        var anyAlreadyProcessed = false
        var grantedCreditsSum = 0
        var latestAuthoritativeBalance = self.authoritativeBalance
        var failureMessage: String? = nil
        var remainingTxCount = 0
        var syncedSubscriptionOriginals: Set<UInt64> = []
        // Anything bought while signed out belongs to this account now.
        await claimGuestWallet()
        
        for await verificationResult in Transaction.unfinished {
            foundAnyPendingTransaction = true
            do {
                let transaction = try checkVerified(verificationResult)
                let txIdStr = String(transaction.id)
                let jwsRepresentation = verificationResult.jwsRepresentation
                debugLog("[PAYMENT][RETRY_SYNC_TX_FOUND] txId: \(txIdStr), productId: \(transaction.productID)")
                
                if Self.consumableProductIDs.contains(transaction.productID) {
                    let backendResult = await self.coordinateConsumableTransaction(
                        transaction: transaction,
                        jwsRepresentation: jwsRepresentation,
                        source: "retryPendingSyncDetailed"
                    )
                    latestAuthoritativeBalance = backendResult.currentBalance
                    if backendResult.success && backendResult.creditsGranted > 0 {
                        anyActivated = true
                        grantedCreditsSum += backendResult.creditsGranted
                        self.lastGrantedCredits = backendResult.creditsGranted
                        self.lastAuthoritativeBalance = backendResult.currentBalance
                    } else if backendResult.alreadyProcessed || backendResult.isHistoricalCacheHit {
                        anyAlreadyProcessed = true
                        self.lastAuthoritativeBalance = backendResult.currentBalance
                    } else if backendResult.statusCode == 403
                                || (backendResult.statusCode.map(Self.isPermanentConsumableRejection) ?? false) {
                        // Final answer from the server (already finished by the
                        // delivery step): not something a retry can fix.
                        debugLog("[PAYMENT][RETRY_SYNC_PERMANENT] txId: \(txIdStr) HTTP \(backendResult.statusCode ?? 0)")
                        if failureMessage == nil, !backendResult.userErrorMessage.isEmpty { failureMessage = backendResult.userErrorMessage }
                    } else {
                        remainingTxCount += 1
                        failureMessage = backendResult.userErrorMessage.isEmpty ? "Server could not activate purchase. Please try again." : backendResult.userErrorMessage
                    }
                } else if Self.subscriptionProductIDs.contains(transaction.productID) {
                    // One server check per subscription; the server decides whose it
                    // is (it knows about guest wallets merged into this account).
                    guard !syncedSubscriptionOriginals.contains(transaction.originalID) else {
                        await safelyFinishTransaction(transaction, txIdStr: txIdStr, reason: "retry_sync_subscription_duplicate_renewal")
                        continue
                    }
                    let result = await syncSubscriptionWithBackendResult(
                        jwsRepresentation: jwsRepresentation,
                        originalTransactionId: String(transaction.originalID),
                        appAccountToken: transaction.appAccountToken?.uuidString
                    )
                    switch result {
                    case .verified:
                        syncedSubscriptionOriginals.insert(transaction.originalID)
                        await updateSubscriptionStatus()
                        await fetchServerCreditBalance()
                        await safelyFinishTransaction(transaction, txIdStr: txIdStr, reason: "retry_sync_subscription_success")
                        anyActivated = true
                        latestAuthoritativeBalance = self.authoritativeBalance
                    case .permanentlyRejected:
                        syncedSubscriptionOriginals.insert(transaction.originalID)
                        await safelyFinishTransaction(transaction, txIdStr: txIdStr, reason: "retry_sync_subscription_rejected")
                        failureMessage = failureMessage ?? "This subscription is linked to a different Bhumitra account. Sign in with that account to use it."
                    case .transientFailure:
                        remainingTxCount += 1
                        failureMessage = "Subscription verification failed with server."
                    }
                }
            } catch {
                debugLog("[PAYMENT][RETRY_SYNC_UNVERIFIED] Error: \(error.localizedDescription)")
                remainingTxCount += 1
                failureMessage = "Transaction could not be verified by Apple."
            }
        }
        
        await updateSubscriptionStatus()
        await fetchServerCreditBalance()
        self.isActivating = false
        
        if anyActivated {
            self.clearPendingSyncState(productTitle: self.pendingSyncProductTitle)
            return .activated(creditsGranted: grantedCreditsSum, currentBalance: latestAuthoritativeBalance)
        } else if !foundAnyPendingTransaction || (!anyActivated && remainingTxCount == 0) {
            // Queue is clean — any historical transactions were cleanly finished.
            // There is no current pending purchase to activate.
            self.clearPendingSyncState(productTitle: self.pendingSyncProductTitle)
            return .noPendingPurchase
        } else if let errorMsg = failureMessage, remainingTxCount > 0 {
            self.isSyncPending = true
            return .failed(message: errorMsg)
        } else {
            self.isSyncPending = true
            return .activationPending(message: "Payment received. We're activating your plot searches.")
        }
    }
    
    /// Backward-compatible boolean wrapper for retryPendingSyncDetailed.
    @discardableResult
    public func retryPendingSync() async -> Bool {
        let result = await retryPendingSyncDetailed()
        switch result {
        case .activated, .alreadyProcessed:
            return true
        default:
            return false
        }
    }
    
    /// Single-flight entry point for reconciling unfinished transactions from StoreKit.
    /// Multiple concurrent callers (e.g. app init, view appearance, user sign-in, purchase preflight)
    /// coalesce to await the single active reconciliation task.
    public func processUnfinishedTransactions() async {
        if let runningTask = inFlightReconciliationTask {
            debugLog("[PAYMENT][RECONCILIATION_IN_FLIGHT_JOIN] Awaiting existing reconciliation task")
            await runningTask.value
            return
        }
        
        let task = Task<Void, Never> { @MainActor in
            await self.executeProcessUnfinishedTransactions()
        }
        inFlightReconciliationTask = task
        defer {
            inFlightReconciliationTask = nil
        }
        await task.value
    }
    
    /// The SOLE location in the entire application where StoreKit 2's Transaction.unfinished is iterated.
    /// Iterates over Apple's Transaction.unfinished to reconcile any purchases that succeeded
    /// on device or while the app was backgrounded/offline, ensuring authoritative backend recording
    /// and finishing the transaction with Apple only after confirmed delivery.
    private func executeProcessUnfinishedTransactions() async {
        #if DEBUG
        reconciliationCallCountForTesting += 1
        #endif
        debugLog("[PAYMENT][UNFINISHED_CHECK_STARTED]")
        var count = 0
        var remainingUnfinishedIDs: Set<String> = []
        var subscriptionGroups: [UInt64: [(Transaction, String)]] = [:]
        for await verificationResult in Transaction.unfinished {
            count += 1
            do {
                let transaction = try checkVerified(verificationResult)
                let txIdStr = String(transaction.id)
                let jwsRepresentation = verificationResult.jwsRepresentation
                debugLog("[PAYMENT][STOREKIT_TRANSACTION_RECEIVED] txId: \(txIdStr), productId: \(transaction.productID), source: Transaction.unfinished")
                
                var finishedSuccessfully = false
                
                if Self.consumableProductIDs.contains(transaction.productID) {
                    let result = await self.coordinateConsumableTransaction(
                        transaction: transaction,
                        jwsRepresentation: jwsRepresentation,
                        source: "Transaction.unfinished"
                    )
                    if result.success || result.alreadyProcessed
                        || (result.statusCode.map(Self.isPermanentConsumableRejection) ?? false) {
                        finishedSuccessfully = true
                        if self.pendingSyncTransactionId == txIdStr || self.pendingSyncTransactionId == nil {
                            let resolvedTitle = self.pendingSyncProductTitle ?? ProductTier(rawValue: transaction.productID)?.displayName ?? "Plot Searches"
                            self.clearPendingSyncState(productTitle: resolvedTitle)
                        }
                    }
                } else if Self.subscriptionProductIDs.contains(transaction.productID) {
                    // Collected and handled once per subscription below: a sandbox
                    // month renews every 5 minutes, so one subscription can leave
                    // a dozen unfinished renewals. Verifying each separately
                    // flooded the server (12 calls in one second).
                    subscriptionGroups[transaction.originalID, default: []].append((transaction, jwsRepresentation))
                    finishedSuccessfully = true  // tracked by the group pass
                }
                
                if !finishedSuccessfully {
                    remainingUnfinishedIDs.insert(txIdStr)
                }
            } catch {
                debugLog("[PAYMENT][STOREKIT_UNVERIFIED] Transaction.unfinished verification error: \(error.localizedDescription)")
            }
        }

        for (originalID, group) in subscriptionGroups {
            guard let latest = group.max(by: { $0.0.purchaseDate < $1.0.purchaseDate }) else { continue }
            let syncResult = await syncSubscriptionWithBackendResult(
                jwsRepresentation: latest.1,
                originalTransactionId: String(originalID),
                appAccountToken: latest.0.appAccountToken?.uuidString
            )
            switch syncResult {
            case .verified, .permanentlyRejected:
                // Verified: the latest renewal covers every older one.
                // Permanently rejected: none of them can ever verify here.
                for (tx, _) in group {
                    await safelyFinishTransaction(tx, txIdStr: String(tx.id), reason: "unfinished_subscription_group_\(syncResult)")
                }
                if case .verified = syncResult {
                    await updateSubscriptionStatus()
                    await fetchServerCreditBalance()
                }
                let ids = Set(group.map { String($0.0.id) })
                if let pending = self.pendingSyncTransactionId, ids.contains(pending) {
                    if case .verified = syncResult { self.clearPendingSyncState(productTitle: self.pendingSyncProductTitle ?? "Unlimited Plus") }
                    else { self.clearPendingSyncState() }
                }
            case .transientFailure:
                for (tx, _) in group { remainingUnfinishedIDs.insert(String(tx.id)) }
            }
        }
        self.activeUnfinishedTransactionIDs = remainingUnfinishedIDs
        if remainingUnfinishedIDs.isEmpty && self.isSyncPending {
            self.clearPendingSyncState(productTitle: self.pendingSyncProductTitle)
        }
        debugLog("[PAYMENT][UNFINISHED_CHECK_COMPLETED] totalUnfinishedProcessed: \(count), remainingUnfinished: \(remainingUnfinishedIDs.count)")
    }
    
    /// Listens for real-time transactions from Apple (renewals, interrupted purchases, family sharing).
    /// This is the SOLE long-lived Transaction.updates listener in the application.
    private func listenForTransactions() -> Task<Void, Never> {
        return Task { @MainActor in
            for await verificationResult in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(verificationResult)
                    let txIdStr = String(transaction.id)
                    self.lastUpdatesTransactionID = txIdStr
                    let jwsRepresentation = verificationResult.jwsRepresentation
                    debugLog("[PAYMENT][STOREKIT_TRANSACTION_RECEIVED] txId: \(txIdStr), productId: \(transaction.productID), source: Transaction.updates")
                    
                    if Self.consumableProductIDs.contains(transaction.productID) {
                        let result = await self.coordinateConsumableTransaction(
                            transaction: transaction,
                            jwsRepresentation: jwsRepresentation,
                            source: "Transaction.updates"
                        )
                        if result.success || result.alreadyProcessed {
                            self.activeUnfinishedTransactionIDs.remove(txIdStr)
                            if self.pendingSyncTransactionId == txIdStr || self.pendingSyncTransactionId == nil {
                                let resolvedTitle = self.pendingSyncProductTitle ?? ProductTier(rawValue: transaction.productID)?.displayName ?? "Plot Searches"
                                self.clearPendingSyncState(productTitle: resolvedTitle)
                            }
                            if self.isAwaitingApproval {
                                self.isAwaitingApproval = false
                                if result.success && result.creditsGranted > 0 {
                                    self.approvedPurchaseGrant = ApprovedPurchaseGrant(
                                        tier: ProductTier(rawValue: transaction.productID) ?? .tenPlots,
                                        creditsGranted: result.creditsGranted,
                                        balance: result.currentBalance)
                                }
                            }
                        }
                    } else {
                        // Subscription background update
                        let token = transaction.appAccountToken?.uuidString
                        let syncResult = await self.syncSubscriptionWithBackendResult(
                            jwsRepresentation: jwsRepresentation,
                            originalTransactionId: String(transaction.originalID),
                            appAccountToken: token
                        )
                        switch syncResult {
                        case .verified:
                            await self.updateSubscriptionStatus()
                            await self.fetchServerCreditBalance()
                            await self.safelyFinishTransaction(transaction, txIdStr: txIdStr, reason: "subscription_updates")
                            self.activeUnfinishedTransactionIDs.remove(txIdStr)
                            if self.pendingSyncTransactionId == txIdStr || self.pendingSyncTransactionId == nil {
                                let resolvedTitle = self.pendingSyncProductTitle ?? "Unlimited Plus"
                                self.clearPendingSyncState(productTitle: resolvedTitle)
                            }
                        case .permanentlyRejected:
                            // Never verifiable for this account — finish so it stops replaying.
                            await self.safelyFinishTransaction(transaction, txIdStr: txIdStr, reason: "subscription_updates_permanently_rejected")
                            self.activeUnfinishedTransactionIDs.remove(txIdStr)
                            if self.pendingSyncTransactionId == txIdStr {
                                self.clearPendingSyncState()
                            }
                        case .transientFailure:
                            break // retry on a future update/foreground
                        }
                    }
                } catch {
                    debugLog("[PAYMENT][STOREKIT_UNVERIFIED] Transaction.updates error: \(error)")
                }
            }
        }
    }
    
    // MARK: - Backend Server Sync (Authoritative)
    
    public struct BackendProcessingResult {
        public let success: Bool
        public let alreadyProcessed: Bool
        public let creditsGranted: Int
        public let currentBalance: Int
        public let statusCode: Int?
        public let failureReason: String
        public let userErrorMessage: String
        public let isHistoricalCacheHit: Bool
        
        public init(
            success: Bool,
            alreadyProcessed: Bool = false,
            creditsGranted: Int = 0,
            currentBalance: Int = 0,
            statusCode: Int? = nil,
            failureReason: String = "",
            userErrorMessage: String = "",
            isHistoricalCacheHit: Bool = false
        ) {
            self.success = success
            self.alreadyProcessed = alreadyProcessed
            self.creditsGranted = creditsGranted
            self.currentBalance = currentBalance
            self.statusCode = statusCode
            self.failureReason = failureReason
            self.userErrorMessage = userErrorMessage
            self.isHistoricalCacheHit = isHistoricalCacheHit
        }
    }
    
    /// Centralized coordinator for consumable transactions:
    /// - De-duplicates in-flight requests (eliminates race between Transaction.updates and executePurchase)
    /// - Returns cached authoritative results for already verified transactions in this session
    /// - Atomically executes backend verification and credits delivery
    /// - Finishes StoreKit transactions safely upon backend confirmation
    public func coordinateConsumableTransaction(
        transaction: Transaction,
        jwsRepresentation: String,
        source: String,
        isFreshUserPurchase: Bool = false
    ) async -> BackendProcessingResult {
        let txIdStr = String(transaction.id)
        debugLog("[PAYMENT] Coordinator entered: coordinateConsumableTransaction() [source: \(source), txId: \(txIdStr), fresh: \(isFreshUserPurchase)]")
        
        let isCached = sessionTransactionResults[txIdStr] != nil
        let isInFlight = inFlightProcessingTasks[txIdStr] != nil
        debugLog("[PAYMENT] Coordinator existing/in-flight state: cached = \(isCached), inFlight = \(isInFlight)")
        
        // 1. Session cache: if already completed with backend in this session, return authoritative cached result.
        if let cached = sessionTransactionResults[txIdStr] {
            debugLog("[PAYMENT][COORDINATOR_CACHE_HIT] txId: \(txIdStr), source: \(source), historicalCreditsGranted: \(cached.creditsGranted), fresh: \(isFreshUserPurchase)")
            // Any transaction already in the session cache must be finished so the
            // StoreKit daemon clears it from the unfinished queue.
            await safelyFinishTransaction(transaction, txIdStr: txIdStr, reason: "coordinator_historical_cache_cleanup")
            
            // Return the cached success as THIS purchase's result ONLY when this is
            // the very purchase the user just initiated (isFreshUserPurchase == the
            // tx id was NOT known before this tap) AND the concurrent delivery for
            // the SAME purchase already succeeded via Transaction.updates.
            //
            // Previously this returned the cached success for ANY executePurchase
            // call, so a LATER tap that StoreKit satisfied by replaying an
            // already-completed consumable was falsely reported as a fresh grant —
            // showing the success screen with NO new credits and NO payment sheet.
            // A non-fresh (replayed/stale) transaction must be reported as
            // alreadyProcessed (0 new credits), never as a grant.
            if cached.success && cached.creditsGranted > 0 && source == "executePurchase" && isFreshUserPurchase {
                return cached
            }
            
            return BackendProcessingResult(
                success: false,
                alreadyProcessed: true,
                creditsGranted: 0,
                currentBalance: cached.currentBalance,
                statusCode: 200,
                failureReason: "historical_cache_hit",
                userErrorMessage: "Previous purchase synchronized.",
                isHistoricalCacheHit: true
            )
        }
        
        // 1b. Already given a final "no" by the server: finish again, skip the call.
        //     Never applies to the purchase the user just made (a new id).
        if !isFreshUserPurchase, isSettledRejected(txIdStr) {
            await safelyFinishTransaction(transaction, txIdStr: txIdStr, reason: "settled_rejected_replay")
            return BackendProcessingResult(success: false, alreadyProcessed: false, creditsGranted: 0,
                                           currentBalance: self.remainingPlotCredits, statusCode: 409,
                                           failureReason: "settled_rejected_replay", userErrorMessage: "")
        }

        // 2. In-flight task coordination: if another path (e.g. Transaction.updates vs executePurchase) is already delivering, await it
        if let runningTask = inFlightProcessingTasks[txIdStr] {
            debugLog("[PAYMENT][WAITING_IN_FLIGHT] txId: \(txIdStr), source: \(source)")
            return await runningTask.value
        }
        
        // 3. Initiate single delivery task
        let deliveryTask = Task<BackendProcessingResult, Never> { @MainActor in
            return await self.executeBackendConsumableDelivery(
                jwsRepresentation: jwsRepresentation,
                transaction: transaction,
                source: source
            )
        }
        
        inFlightProcessingTasks[txIdStr] = deliveryTask
        defer {
            inFlightProcessingTasks.removeValue(forKey: txIdStr)
            debugLog("[PAYMENT] Coordinator cleanup: inFlightProcessingTasks removal completed [txId: \(txIdStr)]")
        }
        let result = await deliveryTask.value
        return result
    }
    
    private func executeBackendConsumableDelivery(
        jwsRepresentation: String,
        transaction: Transaction,
        source: String
    ) async -> BackendProcessingResult {
        let txIdStr = String(transaction.id)
        let productId = transaction.productID
        
        let endpoint = "\(APIConfiguration.shared.baseURL)/subscription/credits/purchase"
        debugLog("[PAYMENT] Backend delivery started: URL = \(endpoint), transaction_id = \(txIdStr)")
        guard let url = URL(string: endpoint) else {
            debugLog("[PAYMENT][BACKEND_FAILURE] txId: \(txIdStr), error: invalid_endpoint_url")
            return BackendProcessingResult(
                success: false,
                alreadyProcessed: false,
                creditsGranted: 0,
                currentBalance: self.remainingPlotCredits,
                statusCode: nil,
                failureReason: "invalid_endpoint_url",
                userErrorMessage: "Unable to connect to server. Your purchase will automatically sync."
            )
        }
        
        var bearerToken = await MainActor.run { AuthManager.shared.bearerToken }
        if bearerToken == nil || bearerToken?.isEmpty == true {
            await AuthManager.shared.ensureDeviceSession(force: true)
            bearerToken = await MainActor.run { AuthManager.shared.bearerToken }
        }
        guard let token = bearerToken, !token.isEmpty else {
            debugLog("[PAYMENT][AUTH_MISSING] txId: \(txIdStr), productId: \(productId). Cannot process consumable purchase without session token.")
            return BackendProcessingResult(
                success: false,
                alreadyProcessed: false,
                creditsGranted: 0,
                currentBalance: self.remainingPlotCredits,
                statusCode: 401,
                failureReason: "auth_token_missing",
                userErrorMessage: "Unable to connect to server. Your purchase is safe and will automatically activate once connected."
            )
        }
        
        debugLog("[PAYMENT][BACKEND_DELIVERY_STARTED] productId: \(productId), txId: \(txIdStr), source: \(source)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15
        
        let payload: [String: Any] = [
            "signed_transaction_jws": jwsRepresentation
        ]
        
        guard let httpBody = try? JSONSerialization.data(withJSONObject: payload) else {
            debugLog("[PAYMENT][BACKEND_FAILURE] txId: \(txIdStr), error: serialization_failed")
            return BackendProcessingResult(
                success: false,
                alreadyProcessed: false,
                creditsGranted: 0,
                currentBalance: self.remainingPlotCredits,
                statusCode: nil,
                failureReason: "serialization_failed",
                userErrorMessage: "Unable to serialize purchase data."
            )
        }
        request.httpBody = httpBody
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                debugLog("[PAYMENT] Backend HTTP status = -1, response payload classification = non_http_response")
                debugLog("[PAYMENT][BACKEND_FAILURE] txId: \(txIdStr), error: non_http_response")
                return BackendProcessingResult(
                    success: false,
                    alreadyProcessed: false,
                    creditsGranted: 0,
                    currentBalance: self.remainingPlotCredits,
                    statusCode: nil,
                    failureReason: "non_http_response",
                    userErrorMessage: "Payment received, but server response was invalid. We will retry automatically."
                )
            }
            
            if (200...299).contains(httpResponse.statusCode) {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let currentBalance = json["current_balance"] as? Int {
                    
                    let creditsGranted = json["credits_granted"] as? Int ?? 0
                    let alreadyProcessed = json["already_processed"] as? Bool ?? false
                    let payloadClass = alreadyProcessed ? "already_processed" : "new_credit_grant"
                    debugLog("[PAYMENT] Backend HTTP status = \(httpResponse.statusCode), response payload classification = \(payloadClass)")
                    debugLog("[PAYMENT] creditsGranted = \(creditsGranted), authoritative balance refresh result = \(currentBalance)")
                    debugLog("[PAYMENT][BACKEND_DELIVERY]\ntransactionID=\(txIdStr)\ncreditsGranted=\(creditsGranted)\nalreadyProcessed=\(alreadyProcessed)\ncurrentBalance=\(currentBalance)")
                    
                    // Update authoritative local credit state
                    #if DEBUG
                    self.realPlotCredits = currentBalance
                    self.recalculateCreditsFromTestManager()
                    #else
                    self.remainingPlotCredits = currentBalance
                    #endif
                    self.persistCurrentCredits()
                    
                    let procResult: BackendProcessingResult
                    if creditsGranted > 0 && !alreadyProcessed {
                        debugLog("[PAYMENT][NEW_CREDIT_GRANT] productId: \(productId), txId: \(txIdStr), creditsGranted: \(creditsGranted), authoritativeBalance: \(currentBalance)")
                        CreditTransactionManager.shared.recordCreditAdded(
                            amount: creditsGranted,
                            title: ProductTier(rawValue: productId)?.title ?? "+\(creditsGranted) Plot Searches",
                            category: .purchase,
                            details: "Apple In-App Purchase",
                            balanceAfter: currentBalance
                        )
                        await safelyFinishTransaction(transaction, txIdStr: txIdStr, reason: "new_credit_grant")
                        // Record the authoritative positive grant for this txId so that
                        // whichever path (executePurchase) later resolves the user-facing
                        // outcome reports .granted — even if the concurrent
                        // Transaction.updates listener was the one that reached the
                        // backend first and cached the result.
                        self.grantedTxIDsThisSession[txIdStr] = (creditsGranted: creditsGranted, balance: currentBalance)
                        procResult = BackendProcessingResult(
                            success: true,
                            alreadyProcessed: false,
                            creditsGranted: creditsGranted,
                            currentBalance: currentBalance,
                            statusCode: httpResponse.statusCode,
                            failureReason: "none",
                            userErrorMessage: ""
                        )
                    } else {
                        debugLog("[PAYMENT][ALREADY_PROCESSED] productId: \(productId), txId: \(txIdStr), authoritativeBalance: \(currentBalance)")
                        await safelyFinishTransaction(transaction, txIdStr: txIdStr, reason: "already_processed_cleanup")
                        procResult = BackendProcessingResult(
                            success: false,
                            alreadyProcessed: true,
                            creditsGranted: 0,
                            currentBalance: currentBalance,
                            statusCode: httpResponse.statusCode,
                            failureReason: "already_processed_by_server",
                            userErrorMessage: ""
                        )
                    }
                    self.sessionTransactionResults[txIdStr] = procResult
                    return procResult
                } else {
                    debugLog("[PAYMENT] Backend HTTP status = \(httpResponse.statusCode), response payload classification = invalid_json_payload")
                    debugLog("[PAYMENT][BACKEND_FAILURE] txId: \(txIdStr), error: invalid_json_payload")
                    return BackendProcessingResult(
                        success: false,
                        alreadyProcessed: false,
                        creditsGranted: 0,
                        currentBalance: self.remainingPlotCredits,
                        statusCode: httpResponse.statusCode,
                        failureReason: "invalid_json_payload",
                        userErrorMessage: "Payment received, but unable to parse balance."
                    )
                }
            } else if httpResponse.statusCode == 401 {
                debugLog("[PAYMENT] Backend HTTP status = 401 Unauthorized. Session token expired or rejected. Refreshing session and retrying once...")
                // A signed-in user's expired session must NOT be retried as the
                // anonymous device: the purchase would be credited to the wrong
                // account. It stays unfinished until they sign in again.
                if await AuthManager.shared.handleUnauthorizedSession(),
                   let freshToken = AuthManager.shared.bearerToken, !freshToken.isEmpty {
                    var retryRequest = URLRequest(url: url)
                    retryRequest.httpMethod = "POST"
                    retryRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    retryRequest.setValue("Bearer \(freshToken)", forHTTPHeaderField: "Authorization")
                    retryRequest.timeoutInterval = 15
                    retryRequest.httpBody = httpBody
                    
                    if let (retryData, retryResponse) = try? await URLSession.shared.data(for: retryRequest),
                       let retryHttp = retryResponse as? HTTPURLResponse,
                       (200...299).contains(retryHttp.statusCode),
                       let json = try? JSONSerialization.jsonObject(with: retryData) as? [String: Any],
                       let currentBalance = json["current_balance"] as? Int {
                        let creditsGranted = json["credits_granted"] as? Int ?? 0
                        let alreadyProcessed = json["already_processed"] as? Bool ?? false
                        debugLog("[PAYMENT] 401 auto-recovery succeeded! creditsGranted=\(creditsGranted), balance=\(currentBalance)")
                        
                        #if DEBUG
                        self.realPlotCredits = currentBalance
                        self.recalculateCreditsFromTestManager()
                        #else
                        self.remainingPlotCredits = currentBalance
                        #endif
                        self.persistCurrentCredits()
                        
                        let procResult: BackendProcessingResult
                        if creditsGranted > 0 && !alreadyProcessed {
                            CreditTransactionManager.shared.recordCreditAdded(
                                amount: creditsGranted,
                                title: ProductTier(rawValue: productId)?.title ?? "+\(creditsGranted) Plot Searches",
                                category: .purchase,
                                details: "Apple In-App Purchase",
                                balanceAfter: currentBalance
                            )
                            await safelyFinishTransaction(transaction, txIdStr: txIdStr, reason: "new_credit_grant_401_recovery")
                            procResult = BackendProcessingResult(
                                success: true,
                                alreadyProcessed: false,
                                creditsGranted: creditsGranted,
                                currentBalance: currentBalance,
                                statusCode: retryHttp.statusCode,
                                failureReason: "none",
                                userErrorMessage: ""
                            )
                        } else {
                            await safelyFinishTransaction(transaction, txIdStr: txIdStr, reason: "already_processed_cleanup_401_recovery")
                            procResult = BackendProcessingResult(
                                success: false,
                                alreadyProcessed: true,
                                creditsGranted: 0,
                                currentBalance: currentBalance,
                                statusCode: retryHttp.statusCode,
                                failureReason: "already_processed_by_server",
                                userErrorMessage: ""
                            )
                        }
                        self.sessionTransactionResults[txIdStr] = procResult
                        return procResult
                    }
                }
                
                debugLog("[PAYMENT][BACKEND_FAILURE] txId: \(txIdStr), statusCode: 401, error: unauthorized_after_retry")
                return BackendProcessingResult(
                    success: false,
                    alreadyProcessed: false,
                    creditsGranted: 0,
                    currentBalance: self.remainingPlotCredits,
                    statusCode: 401,
                    failureReason: "http_401_unauthorized",
                    userErrorMessage: "Session verification pending. Your purchase is safe and will automatically activate."
                )
            } else {
                var errDetail = "HTTP \(httpResponse.statusCode)"
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let detail = json["detail"] as? String {
                    errDetail = detail
                }
                debugLog("[PAYMENT] Backend HTTP status = \(httpResponse.statusCode), response payload classification = http_error (\(errDetail))")
                debugLog("[PAYMENT][BACKEND_FAILURE] txId: \(txIdStr), statusCode: \(httpResponse.statusCode), detail: \(errDetail)")
                if Self.isPermanentConsumableRejection(httpResponse.statusCode) {
                    // 409: this purchase is already linked to another Bhumitra account.
                    // 422: not a product we sell. Neither can ever succeed, so finish
                    // the transaction instead of replaying it (and showing
                    // "activation pending") on every launch forever.
                    await safelyFinishTransaction(transaction, txIdStr: txIdStr, reason: "permanent_rejection_\(httpResponse.statusCode)")
                    markSettledRejected(txIdStr)
                    let message = httpResponse.statusCode == 409
                        ? "This purchase is linked to a different Bhumitra account. Sign in with that account, or contact support and we'll sort it out."
                        : "This purchase couldn't be applied to your account. Please contact support; your payment is safe."
                    return BackendProcessingResult(
                        success: false,
                        alreadyProcessed: false,
                        creditsGranted: 0,
                        currentBalance: self.remainingPlotCredits,
                        statusCode: httpResponse.statusCode,
                        failureReason: "permanent_rejection_\(httpResponse.statusCode)",
                        userErrorMessage: message
                    )
                }
                return BackendProcessingResult(
                    success: false,
                    alreadyProcessed: false,
                    creditsGranted: 0,
                    currentBalance: self.remainingPlotCredits,
                    statusCode: httpResponse.statusCode,
                    failureReason: "http_\(httpResponse.statusCode)_\(errDetail)",
                    userErrorMessage: "Payment received, but server error occurred (HTTP \(httpResponse.statusCode)). We will retry automatically."
                )
            }
        } catch {
            debugLog("[PAYMENT] Backend HTTP status = -1, response payload classification = network_error (\(error.localizedDescription))")
            debugLog("[PAYMENT][BACKEND_FAILURE] txId: \(txIdStr), networkError: \(error.localizedDescription)")
            return BackendProcessingResult(
                success: false,
                alreadyProcessed: false,
                creditsGranted: 0,
                currentBalance: self.remainingPlotCredits,
                statusCode: nil,
                failureReason: "network_error_\(error.localizedDescription)",
                userErrorMessage: "Payment received, but network connection failed. We will retry automatically."
            )
        }
    }
    
    // MARK: Settled transactions
    // Transactions the server gave a final "no" for (belongs to another account,
    // invalid). finish() is called on them, but StoreKit (notably the sandbox
    // with long renewal chains) can keep re-delivering them on every launch.
    // Remember them so they're finished again locally without re-asking the
    // server each time. Capped; the server stays the source of truth.
    private static let settledKey = "bhumitra_settled_rejected_tx_v1"
    private static let settledCap = 500

    func isSettledRejected(_ txId: String) -> Bool {
        (UserDefaults.standard.stringArray(forKey: Self.settledKey) ?? []).contains(txId)
    }

    func markSettledRejected(_ txId: String) {
        var ids = UserDefaults.standard.stringArray(forKey: Self.settledKey) ?? []
        guard !ids.contains(txId) else { return }
        ids.append(txId)
        if ids.count > Self.settledCap { ids.removeFirst(ids.count - Self.settledCap) }
        UserDefaults.standard.set(ids, forKey: Self.settledKey)
    }

    func unmarkSettledRejected(_ txId: String) {
        var ids = UserDefaults.standard.stringArray(forKey: Self.settledKey) ?? []
        ids.removeAll { $0 == txId }
        UserDefaults.standard.set(ids, forKey: Self.settledKey)
    }

    /// Account changes can make a previously foreign purchase ours again.
    func clearSettledRejected() {
        UserDefaults.standard.removeObject(forKey: Self.settledKey)
    }

    /// Backend answers for a consumable that can never be credited (see
    /// routers/subscriptions.py): 409 cross-account, 422 unknown product.
    nonisolated static func isPermanentConsumableRejection(_ statusCode: Int) -> Bool {
        statusCode == 409 || statusCode == 422
    }

    /// Fetches the server-authoritative plot credit balance for the authenticated user
    public func fetchServerCreditBalance() async {
        var bearerToken = await MainActor.run { AuthManager.shared.bearerToken }
        if bearerToken == nil || bearerToken?.isEmpty == true {
            await AuthManager.shared.ensureDeviceSession()
            bearerToken = await MainActor.run { AuthManager.shared.bearerToken }
        }
        
        // Section D Rule 5: An unauthenticated balance request must NOT be interpreted as "user has zero credits"
        guard let token = bearerToken, !token.isEmpty else {
            await MainActor.run { self.isLoadingCredits = false }
            return
        }
        
        let endpoint = "\(APIConfiguration.shared.baseURL)/subscription/credits"
        guard let url = URL(string: endpoint) else {
            await MainActor.run { self.isLoadingCredits = false }
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 8
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let serverCredits = json["credits"] as? Int {
                    let isUnlimitedServer = (json["is_unlimited"] as? Bool) ?? (serverCredits < 0)
                    await MainActor.run {
                        if isUnlimitedServer {
                            self.isUnlimited = true
                            self.isPremium = true
                            self.activeTier = .monthly
                        } else {
                            if !self.isPremium {
                                self.isUnlimited = false
                            }
                            // Section D Rule 7: Only a successful authenticated server response may replace displayed balance
                            #if DEBUG
                            self.realPlotCredits = serverCredits
                            self.recalculateCreditsFromTestManager()
                            #else
                            self.remainingPlotCredits = serverCredits
                            #endif
                        }
                        // Section D Rule 8: Persist the successfully fetched authoritative balance locally only as a cache
                        self.persistCurrentCredits()
                        self.isLoadingCredits = false
                        debugLog("[PAYMENT][AUTHORITATIVE_BALANCE_REFRESH] authoritativeBalance: \(serverCredits), isUnlimited: \(isUnlimitedServer)")
                        if self.isSyncPending && self.activeUnfinishedTransactionIDs.isEmpty {
                            debugLog("[PAYMENT] Server credit balance confirmed and unfinished queue is empty. Clearing pending sync state.")
                            self.clearPendingSyncState(productTitle: self.pendingSyncProductTitle)
                        }
                    }
                } else {
                    await MainActor.run { self.isLoadingCredits = false }
                }
            } else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                if statusCode == 401 {
                    debugLog("[PAYMENT] fetchServerCreditBalance returned 401 Unauthorized. Refreshing session...")
                    await AuthManager.shared.handleUnauthorizedSession()
                }
                // Section D Rule 5: Non-200 response must NOT overwrite cached balance with 0
                await MainActor.run { self.isLoadingCredits = false }
                debugLog("[PAYMENT][BACKEND_FAILURE] fetchServerCreditBalance failed with HTTP \(statusCode)")
            }
        } catch {
            // Section D Rule 5: Network failure must NOT overwrite cached balance with 0
            await MainActor.run { self.isLoadingCredits = false }
            debugLog("[PAYMENT][BACKEND_FAILURE] fetchServerCreditBalance network error: \(error.localizedDescription)")
        }
    }
    
    /// Backward-compatible boolean wrapper. `true` only when the backend verified.
    @discardableResult
    public func syncSubscriptionWithBackend(jwsRepresentation: String, originalTransactionId: String, appAccountToken: String? = nil) async -> Bool {
        let result = await syncSubscriptionWithBackendResult(
            jwsRepresentation: jwsRepresentation,
            originalTransactionId: originalTransactionId,
            appAccountToken: appAccountToken
        )
        return result == .verified
    }

    /// Submits a subscription transaction to the backend and classifies the
    /// outcome so callers can decide whether to finish (verified / permanently
    /// rejected) or keep the transaction for later retry (transient failure).
    public func syncSubscriptionWithBackendResult(jwsRepresentation: String, originalTransactionId: String, appAccountToken: String? = nil) async -> SubscriptionSyncResult {
        // One final "no" covers every renewal of the same subscription.
        let settledKey = "sub:\(originalTransactionId)"
        if isSettledRejected(settledKey) { return .permanentlyRejected }
        let result = await performSubscriptionSync(jwsRepresentation: jwsRepresentation,
                                                   originalTransactionId: originalTransactionId,
                                                   appAccountToken: appAccountToken)
        if result == .permanentlyRejected { markSettledRejected(settledKey) }
        return result
    }

    private func performSubscriptionSync(jwsRepresentation: String, originalTransactionId: String, appAccountToken: String? = nil) async -> SubscriptionSyncResult {
        var bearerToken = await MainActor.run { AuthManager.shared.bearerToken }
        if bearerToken == nil {
            await AuthManager.shared.ensureDeviceSession()
            bearerToken = await MainActor.run { AuthManager.shared.bearerToken }
        }
        
        let user = await MainActor.run { AuthManager.shared.currentUser }
        let userId = user?.id ?? "device_guest"
        
        let endpoint = "\(APIConfiguration.shared.baseURL)/subscription/verify"
        guard let url = URL(string: endpoint) else {
            debugLog("[PAYMENT][BACKEND_VERIFICATION_FAILED] error: invalid_endpoint_url")
            return .transientFailure
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = bearerToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.timeoutInterval = 15
        
        let token = appAccountToken ?? user?.appAccountToken
        
        var payload: [String: Any] = [
            "user_id": userId,
            "signed_transaction_jws": jwsRepresentation,
            "original_transaction_id": originalTransactionId
        ]
        
        if let token = token {
            payload["app_account_token"] = token
        }
        
        guard let httpBody = try? JSONSerialization.data(withJSONObject: payload) else {
            debugLog("[PAYMENT][BACKEND_VERIFICATION_FAILED] error: serialization_failed")
            return .transientFailure
        }
        request.httpBody = httpBody
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            if (200...299).contains(code) {
                debugLog("[PAYMENT][BACKEND_VERIFICATION_SUCCESS] 🌐 Server successfully verified and linked Apple Subscription.")
                return .verified
            } else if code == 401 {
                debugLog("[PAYMENT][BACKEND_VERIFICATION] 401 Unauthorized. Refreshing session and retrying once...")
                if await AuthManager.shared.handleUnauthorizedSession(),
                   let freshToken = AuthManager.shared.bearerToken, !freshToken.isEmpty {
                    var retryReq = request
                    retryReq.setValue("Bearer \(freshToken)", forHTTPHeaderField: "Authorization")
                    if let (_, retryRes) = try? await URLSession.shared.data(for: retryReq),
                       let retryHttp = retryRes as? HTTPURLResponse {
                        if (200...299).contains(retryHttp.statusCode) {
                            debugLog("[PAYMENT][BACKEND_VERIFICATION_SUCCESS] 🌐 Server verified subscription after 401 token refresh.")
                            return .verified
                        } else if retryHttp.statusCode == 403 {
                            debugLog("[PAYMENT][BACKEND_VERIFICATION_REJECTED] 403 after refresh — transaction belongs to another account. Will finish & clear.")
                            return .permanentlyRejected
                        }
                    }
                }
                // Couldn't refresh — treat as transient so we retry later rather
                // than discarding a possibly-valid transaction.
                return .transientFailure
            } else if code == 403 {
                // The backend will never accept this transaction for this
                // account/device (e.g. it was purchased under a different Apple
                // ID / test account). Retrying forever is what jams the queue and
                // blocks the buy button — finish & clear it instead.
                debugLog("[PAYMENT][BACKEND_VERIFICATION_REJECTED] ⚠️ 403 — subscription tx not valid for this account. Will finish & clear.")
                return .permanentlyRejected
            } else {
                debugLog("[PAYMENT][BACKEND_VERIFICATION_FAILED] ⚠️ Backend subscription verify failed with status: \(code)")
                return .transientFailure
            }
        } catch {
            debugLog("[PAYMENT][BACKEND_VERIFICATION_FAILED] ⚠️ Backend subscription sync skipped/failed: \(error.localizedDescription)")
            return .transientFailure
        }
    }
    
    /// Fetches server-authoritative live subscription status using authenticated Bearer token
    public func fetchServerSubscriptionStatus() async {
        let bearerToken = await MainActor.run { AuthManager.shared.bearerToken }
        guard let token = bearerToken else { return }
        
        let endpoint = "\(APIConfiguration.shared.baseURL)/subscription/status"
        guard let url = URL(string: endpoint) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let isPremiumServer = json["is_premium"] as? Bool {
                    await MainActor.run {
                        if isPremiumServer {
                            self.isPremium = true
                            self.isUnlimited = true
                            self.activeTier = .monthly
                            self.persistCurrentCredits()
                            debugLog("DEBUG: 🌐 Live Server Entitlement confirmed: isPremium=true")
                        } else {
                            // SERVER-AUTHORITATIVE: If server reports is_premium=false, revoke
                            // local premium state ONLY when Apple's StoreKit also does not see
                            // an active entitlement. This prevents a race where server hasn't
                            // processed the latest renewal yet.
                            let appleAlsoSaysNotPremium = !self.isPremium
                            if appleAlsoSaysNotPremium || self.activeTier == nil {
                                // Both sources agree: no active subscription
                                self.isPremium = false
                                self.isUnlimited = false
                                self.activeTier = nil
                                self.persistCurrentCredits()
                                debugLog("DEBUG: 🌐 Live Server Entitlement confirmed: isPremium=false — revoking local premium state.")
                            } else {
                                // Apple sees active entitlement but server doesn't yet.
                                // This is a normal race during renewal — keep Apple as source of truth.
                                debugLog("DEBUG: 🌐 Live Server Entitlement: isPremium=false from server but Apple entitlement still active — keeping premium state, server may not have processed renewal yet.")
                            }
                        }
                    }
                }
            } else if (response as? HTTPURLResponse)?.statusCode == 401 {
                debugLog("[PAYMENT] fetchServerSubscriptionStatus returned 401. Refreshing session.")
                await AuthManager.shared.handleUnauthorizedSession()
            }
        } catch {
            debugLog("DEBUG: ⚠️ Could not fetch live server status: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Usage Management
    
    private var currentMonthString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: Date())
    }
    
    public func getOwnershipPreviewCount() -> Int {
        guard let user = AuthManager.shared.currentUser else { return 0 }
        let usage = DatabaseManager.shared.getUsage(for: user.id, month: currentMonthString)
        return usage.ownershipPreviewCount
    }
    
    public func canViewOwnershipRecord() -> Bool {
        if isPremium { return true }
        return getOwnershipPreviewCount() < Self.defaultFreeStarterCredits
    }
    
    public func incrementOwnershipViewCount() {
        guard let user = AuthManager.shared.currentUser else { return }
        if !isPremium {
            DatabaseManager.shared.incrementUsage(for: user.id, month: currentMonthString)
        }
    }
}
