import Foundation
import Combine
import StoreKit

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
        case .fiftyPlots: return "₹399"
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
    
    // Transaction-level concurrency locking & deduplication sets
    private var inFlightProcessingTxIDs = Set<String>()
    private var completedProcessedTxIDs = Set<String>()
    
    private init() {
        // 1. Recover cached credit and unlimited state from secure Keychain
        loadInitialCreditState()
        
        // 2. Start background transaction listener immediately on app launch
        transactionListenerTask = listenForTransactions()
        
        // 3. Load products, verify existing entitlements, and fetch server-authoritative balance
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
            print("DEBUG: 🎁 Initialized \(Self.defaultFreeStarterCredits) Free starter plot credits for new install.")
        } else {
            // Existing device: restore cached remaining credits from Keychain
            let savedCredits = Int(KeychainHelper.shared.readString(key: keychainDeviceCreditsKey) ?? "\(Self.defaultFreeStarterCredits)") ?? Self.defaultFreeStarterCredits
            let savedUnlimited = (KeychainHelper.shared.readString(key: keychainDeviceUnlimitedKey) == "true")
            self.remainingPlotCredits = savedCredits
            self.isUnlimited = savedUnlimited
            print("DEBUG: 🔒 Restored cached device credits from Keychain: \(savedCredits), unlimited: \(savedUnlimited)")
        }
    }
    
    public func handleUserSignIn(userId: String) {
        self.isLoadingCredits = true
        // Clear memory state so stale prior values are never displayed
        self.remainingPlotCredits = 0
        self.isUnlimited = false
        
        // Fetch server-authoritative balance & subscription status immediately
        Task {
            await fetchServerCreditBalance()
            await fetchServerSubscriptionStatus()
            await processUnfinishedTransactions()
        }
    }
    
    public func handleUserSignOut() {
        // Clear memory state so next user does not inherit prior user's balance
        self.isPremium = false
        self.isUnlimited = false
        self.activeTier = nil
        self.remainingPlotCredits = 0
        self.isLoadingCredits = false
        print("DEBUG: 🚪 Cleaned up SubscriptionManager state for signed-out user.")
    }
    
    /// Explicit testing reset: resets active testing device/account usage to 0 (all credits available)
    public func resetTestUserCredits(to amount: Int = defaultFreeStarterCredits) {
        self.remainingPlotCredits = amount
        self.isUnlimited = false
        KeychainHelper.shared.save(key: keychainDeviceCreditsKey, string: "\(amount)")
        KeychainHelper.shared.save(key: keychainDeviceInitKey, string: "true")
        KeychainHelper.shared.save(key: keychainDeviceUnlimitedKey, string: "false")
        if let user = AuthManager.shared.currentUser {
            KeychainHelper.shared.save(key: userCreditsKey(for: user.id), string: "\(amount)")
            KeychainHelper.shared.save(key: userInitKey(for: user.id), string: "true")
            KeychainHelper.shared.save(key: userUnlimitedKey(for: user.id), string: "false")
            DatabaseManager.shared.resetUsage(for: user.id, month: currentMonthString)
        }
        print("DEBUG: 🔄 Reset test account usage to 0 with \(amount) available plot search credits.")
    }
    
    private func persistCurrentCredits() {
        // 1. Save to Device Keychain
        KeychainHelper.shared.save(key: keychainDeviceCreditsKey, string: "\(remainingPlotCredits)")
        KeychainHelper.shared.save(key: keychainDeviceUnlimitedKey, string: isUnlimited ? "true" : "false")
        
        // 2. Save to User Keychain if signed in
        if let user = AuthManager.shared.currentUser {
            KeychainHelper.shared.save(key: userCreditsKey(for: user.id), string: "\(remainingPlotCredits)")
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
        print("DEBUG: ♾️ Set Unlimited Plot Searches: \(unlimited)")
    }
    
    @discardableResult
    public func consumePlotSearchCredit() -> Bool {
        if isUnlimited || isPremium {
            AnalyticsService.shared.log(.plotCreditConsumed(
                remainingCreditBucket: "50+",
                isUnlimited: true
            ))
            return true
        }
        if remainingPlotCredits > 0 {
            remainingPlotCredits -= 1
            persistCurrentCredits()
            print("DEBUG: 📉 Consumed 1 plot credit. Remaining: \(remainingPlotCredits)")
            
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
        
        print("[STOREKIT DIAGNOSTIC] ==================================================")
        print("[STOREKIT DIAGNOSTIC] 📱 Bundle ID: \(bundleID)")
        print("[STOREKIT DIAGNOSTIC] 🌍 Storefront: \(storefrontCode) (ID: \(storefrontID))")
        print("[STOREKIT DIAGNOSTIC] 📋 Requested Product IDs (\(requestedList.count)): \(requestedList)")
        
        // 1. Primary Batch Request
        do {
            let fetchedProducts = try await Product.products(for: productIDs)
            print("[STOREKIT DIAGNOSTIC] 📦 Returned Product Count: \(fetchedProducts.count)")
            
            for p in fetchedProducts {
                print("[STOREKIT DIAGNOSTIC]   👉 Product ID: \(p.id)")
                print("[STOREKIT DIAGNOSTIC]      Type: \(p.type)")
                print("[STOREKIT DIAGNOSTIC]      Display Name: \(p.displayName)")
                print("[STOREKIT DIAGNOSTIC]      Price: \(p.displayPrice)")
                print("[STOREKIT DIAGNOSTIC]      Description: \(p.description)")
            }
            
            let fetchedIDs = Set(fetchedProducts.map { $0.id })
            let missingIDs = productIDs.subtracting(fetchedIDs)
            if !missingIDs.isEmpty {
                print("[STOREKIT DIAGNOSTIC] ⚠️ Products NOT returned by Apple: \(missingIDs.sorted())")
            }
            
            if fetchedProducts.isEmpty {
                print("[STOREKIT DIAGNOSTIC] ⚠️ StoreKit returned 0 products from Apple. Possible causes: Paid Applications Agreement pending in App Store Connect, missing in-app purchase metadata/pricing, or inactive Sandbox account.")
                self.errorMessage = "Products unavailable from App Store. Please check App Store Connect agreement status or Sandbox account."
            }
            
            // Sort products by tier
            self.products = fetchedProducts
            self.tenPlotsProduct = fetchedProducts.first(where: { $0.id == Self.tenPlotsProductID })
            self.fiftyPlotsProduct = fetchedProducts.first(where: { $0.id == Self.fiftyPlotsProductID })
            self.twoHundredPlotsProduct = fetchedProducts.first(where: { $0.id == Self.twoHundredPlotsProductID })
            self.monthlyProduct = fetchedProducts.first(where: { $0.id == Self.monthlyProductID })
            
        } catch {
            print("[STOREKIT DIAGNOSTIC] ❌ StoreKit Request Error: \(error.localizedDescription) | Detail: \(error)")
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
        print("[StoreKit-Diagnostic] 🛒 Purchase initiated for Tier: \(tier.rawValue) | Target Product ID: '\(targetID)'")
        
        let product: Product?
        switch tier {
        case .tenPlots: product = tenPlotsProduct
        case .fiftyPlots: product = fiftyPlotsProduct
        case .twoHundredPlots: product = twoHundredPlotsProduct
        case .monthly: product = monthlyProduct
        }
        
        print("[StoreKit-Diagnostic] 📦 Cached Product object is \(product == nil ? "NIL (not returned by Apple StoreKit)" : "PRESENT ('\(product!.id)')")")
        
        guard let validProduct = product else {
            print("[StoreKit-Diagnostic] 🔄 Attempting immediate re-fetch for products...")
            await loadProducts()
            let refreshed = products.first(where: { $0.id == targetID })
            guard let finalProduct = refreshed else {
                print("[StoreKit-Diagnostic] ❌ Product '\(targetID)' was not returned by Apple StoreKit. (Available: \(products.map { $0.id }))")
                self.isLoading = false
                let error = NSError(
                    domain: "StoreKitManager",
                    code: 404,
                    userInfo: [NSLocalizedDescriptionKey: "Product '\(targetID)' is currently unavailable from App Store. StoreKit returned 0 products for this ID."]
                )
                return .failure(error)
            }
            return await executePurchase(product: finalProduct)
        }
        
        return await executePurchase(product: validProduct)
    }
    
    private func executePurchase(product: Product) async -> Result<Transaction, Error> {
        isLoading = true
        errorMessage = nil
        
        let priceVal = NSDecimalNumber(decimal: product.price).doubleValue
        let prodType = Self.consumableProductIDs.contains(product.id) ? "consumable" : "subscription"
        
        print("[PAYMENT][PURCHASE_STARTED] productId: \(product.id)")
        
        do {
            // Configure purchase with user's permanent appAccountToken UUID
            var options: Set<Product.PurchaseOption> = []
            if let user = AuthManager.shared.currentUser {
                let accountUUID = user.appAccountUUID
                options.insert(.appAccountToken(accountUUID))
                print("DEBUG: 🔗 Associating Apple Purchase with Bhumitra User '\(user.id)' via appAccountToken: \(accountUUID.uuidString)")
            }
            
            let result = try await product.purchase(options: options)
            
            switch result {
            case .success(let verificationResult):
                // 1. Cryptographically verify Apple's JWS signed transaction
                let transaction = try checkVerified(verificationResult)
                let txIdStr = String(transaction.id)
                print("[PAYMENT][APPLE_APPROVED] txId: \(txIdStr), productId: \(transaction.productID)")
                
                let jwsRepresentation = verificationResult.jwsRepresentation
                
                // 2. Check if product is Consumable vs Subscription
                if Self.consumableProductIDs.contains(transaction.productID) {
                    // Consumable Flow: Submit signed JWS to backend credit purchase endpoint
                    let backendResult = await processConsumablePurchaseWithBackend(
                        jwsRepresentation: jwsRepresentation,
                        transactionId: txIdStr,
                        productId: transaction.productID,
                        source: "executePurchase"
                    )
                    
                    let creditsToAdd = self.creditsForProductID(transaction.productID)
                    
                    if backendResult.success {
                        // Authoritative backend sync confirmed -> FINISH TRANSACTION
                        await transaction.finish()
                        print("[PAYMENT][TRANSACTION_FINISHED] txId: \(txIdStr)")
                        self.isLoading = false
                        
                        AnalyticsService.shared.log(.purchaseCompleted(
                            productID: transaction.productID,
                            productType: "consumable",
                            creditsGranted: creditsToAdd,
                            price: priceVal
                        ))
                        
                        return .success(transaction)
                    } else {
                        // Backend confirmation failed (network/server error).
                        // DO NOT modify local credits. DO NOT finish the transaction.
                        self.isLoading = false
                        print("[PAYMENT][BACKEND_VERIFICATION_PENDING] txId: \(txIdStr), reason: \(backendResult.failureReason)")
                        let error = NSError(
                            domain: "StoreKitManager",
                            code: backendResult.statusCode ?? 500,
                            userInfo: [NSLocalizedDescriptionKey: backendResult.userErrorMessage]
                        )
                        return .failure(error)
                    }
                } else {
                    // Subscription Flow: Submit signed JWS to backend subscription verification endpoint
                    let token = transaction.appAccountToken?.uuidString
                    let syncSuccess = await syncSubscriptionWithBackend(
                        jwsRepresentation: jwsRepresentation,
                        originalTransactionId: String(transaction.originalID),
                        appAccountToken: token
                    )
                    
                    if syncSuccess {
                        // Authoritative backend sync confirmed -> update entitlements & finish transaction
                        await updateSubscriptionStatus()
                        await fetchServerCreditBalance()
                        
                        await transaction.finish()
                        print("[PAYMENT][TRANSACTION_FINISHED] txId: \(txIdStr)")
                        
                        self.isLoading = false
                        
                        AnalyticsService.shared.log(.purchaseCompleted(
                            productID: transaction.productID,
                            productType: "subscription",
                            creditsGranted: 0,
                            price: priceVal
                        ))
                        AnalyticsService.shared.setAccountType(.premium)
                        
                        print("DEBUG: 💎 Successfully purchased and verified subscription: \(transaction.productID)")
                        return .success(transaction)
                    } else {
                        self.isLoading = false
                        print("[PAYMENT][BACKEND_VERIFICATION_PENDING] txId: \(txIdStr), reason: subscription_sync_failed")
                        let error = NSError(
                            domain: "StoreKitManager",
                            code: 500,
                            userInfo: [NSLocalizedDescriptionKey: "Payment was approved by Apple, but subscription recording is pending. Your subscription will automatically sync as soon as connectivity is restored."]
                        )
                        return .failure(error)
                    }
                }
                
            case .userCancelled:
                self.isLoading = false
                print("[PAYMENT][USER_CANCELLED] productId: \(product.id)")
                AnalyticsService.shared.log(.purchaseCancelled(productID: product.id))
                let error = NSError(domain: "StoreKitManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "Purchase was cancelled."])
                return .failure(error)
                
            case .pending:
                self.isLoading = false
                print("[PAYMENT][PURCHASE_PENDING_AUTHORIZATION] productId: \(product.id)")
                let error = NSError(domain: "StoreKitManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Purchase is pending authorization (e.g. Ask to Buy)."])
                return .failure(error)
                
            @unknown default:
                self.isLoading = false
                print("[PAYMENT][UNKNOWN_RESPONSE] productId: \(product.id)")
                AnalyticsService.shared.log(.purchaseFailed(productID: product.id, errorCategory: .unknown))
                let error = NSError(domain: "StoreKitManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown purchase response from Apple."])
                return .failure(error)
            }
        } catch {
            self.isLoading = false
            self.errorMessage = error.localizedDescription
            print("[PAYMENT][PURCHASE_EXCEPTION] productId: \(product.id), error: \(error)")
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
                print("DEBUG: 🔄 Active subscription restored successfully. Active Tier: \(String(describing: activeTier))")
                return .success(true)
            } else {
                let error = NSError(domain: "StoreKitManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "No active subscription found for your Apple ID."])
                return .failure(error)
            }
        } catch {
            self.isLoading = false
            self.errorMessage = error.localizedDescription
            print("DEBUG: ❌ Restore failed: \(error)")
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
                print("DEBUG: ⚠️ Entitlement failed verification: \(error)")
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
        
        print("DEBUG: 🛡️ Entitlement evaluated: isPremium=\(hasActiveEntitlement), activeTier=\(String(describing: currentActiveTier))")
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
    
    /// Iterates over Apple's Transaction.unfinished to reconcile any purchases that succeeded
    /// on device or while the app was backgrounded/offline, ensuring authoritative backend recording
    /// and finishing the transaction with Apple only after confirmed delivery.
    public func processUnfinishedTransactions() async {
        print("[PAYMENT][UNFINISHED_CHECK_STARTED]")
        var count = 0
        for await verificationResult in Transaction.unfinished {
            count += 1
            do {
                let transaction = try checkVerified(verificationResult)
                let txIdStr = String(transaction.id)
                let jwsRepresentation = verificationResult.jwsRepresentation
                print("[PAYMENT][UNFINISHED_TX_FOUND] txId: \(txIdStr), productId: \(transaction.productID)")
                
                if Self.consumableProductIDs.contains(transaction.productID) {
                    let result = await processConsumablePurchaseWithBackend(
                        jwsRepresentation: jwsRepresentation,
                        transactionId: txIdStr,
                        productId: transaction.productID,
                        source: "Transaction.unfinished"
                    )
                    if result.success {
                        await transaction.finish()
                        print("[PAYMENT][TRANSACTION_FINISHED] txId: \(txIdStr), source: Transaction.unfinished")
                    } else {
                        print("[PAYMENT][BACKEND_VERIFICATION_PENDING] txId: \(txIdStr), source: Transaction.unfinished, reason: \(result.failureReason)")
                    }
                } else if Self.subscriptionProductIDs.contains(transaction.productID) {
                    let token = transaction.appAccountToken?.uuidString
                    let syncSuccess = await syncSubscriptionWithBackend(
                        jwsRepresentation: jwsRepresentation,
                        originalTransactionId: String(transaction.originalID),
                        appAccountToken: token
                    )
                    if syncSuccess {
                        await updateSubscriptionStatus()
                        await fetchServerCreditBalance()
                        await transaction.finish()
                        print("[PAYMENT][TRANSACTION_FINISHED] txId: \(txIdStr), source: Transaction.unfinished")
                    } else {
                        print("[PAYMENT][BACKEND_VERIFICATION_PENDING] txId: \(txIdStr), source: Transaction.unfinished, reason: subscription_sync_failed")
                    }
                }
            } catch {
                print("[PAYMENT][UNFINISHED_TX_VERIFICATION_FAILED] error: \(error.localizedDescription)")
            }
        }
        print("[PAYMENT][UNFINISHED_CHECK_COMPLETED] totalUnfinishedProcessed: \(count)")
    }
    
    /// Listens for real-time transactions from Apple (renewals, interrupted purchases, family sharing)
    private func listenForTransactions() -> Task<Void, Never> {
        return Task { @MainActor in
            for await verificationResult in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(verificationResult)
                    let txIdStr = String(transaction.id)
                    let jwsRepresentation = verificationResult.jwsRepresentation
                    
                    if Self.consumableProductIDs.contains(transaction.productID) {
                        // Consumable background update: sync with server first
                        let result = await self.processConsumablePurchaseWithBackend(
                            jwsRepresentation: jwsRepresentation,
                            transactionId: txIdStr,
                            productId: transaction.productID,
                            source: "Transaction.updates"
                        )
                        if result.success {
                            await transaction.finish()
                            print("[PAYMENT][TRANSACTION_FINISHED] txId: \(txIdStr), source: Transaction.updates")
                        } else {
                            print("[PAYMENT][BACKEND_VERIFICATION_PENDING] txId: \(txIdStr), source: Transaction.updates, reason: \(result.failureReason)")
                        }
                    } else {
                        // Subscription background update
                        let token = transaction.appAccountToken?.uuidString
                        let syncSuccess = await self.syncSubscriptionWithBackend(
                            jwsRepresentation: jwsRepresentation,
                            originalTransactionId: String(transaction.originalID),
                            appAccountToken: token
                        )
                        if syncSuccess {
                            await self.updateSubscriptionStatus()
                            await self.fetchServerCreditBalance()
                            await transaction.finish()
                            print("[PAYMENT][TRANSACTION_FINISHED] txId: \(txIdStr), source: Transaction.updates")
                        } else {
                            print("[PAYMENT][BACKEND_VERIFICATION_PENDING] txId: \(txIdStr), source: Transaction.updates, reason: subscription_sync_failed")
                        }
                    }
                } catch {
                    print("[PAYMENT][VERIFICATION_FAILED] error: \(error)")
                }
            }
        }
    }
    
    // MARK: - Backend Server Sync (Authoritative)
    
    public struct BackendProcessingResult {
        public let success: Bool
        public let statusCode: Int?
        public let failureReason: String
        public let userErrorMessage: String
    }

    /// Submits a verified StoreKit 2 consumable transaction JWS to the backend server.
    /// ONLY updates local credits and returns true when the backend returns HTTP 200 with an authoritative current_balance.
    /// In all other cases (network failure, pending, 500, invalid token), local credits are UNCHANGED and returns false.
    public func processConsumablePurchaseWithBackend(
        jwsRepresentation: String,
        transactionId: String,
        productId: String,
        source: String
    ) async -> BackendProcessingResult {
        // 1. Check if already completed in this session
        if completedProcessedTxIDs.contains(transactionId) {
            print("[PAYMENT][ALREADY_PROCESSED] txId: \(transactionId), source: \(source)")
            return BackendProcessingResult(success: true, statusCode: 200, failureReason: "already_completed", userErrorMessage: "")
        }
        
        // 2. Check if currently in-flight by another task (e.g. Transaction.updates vs executePurchase)
        if inFlightProcessingTxIDs.contains(transactionId) {
            print("[PAYMENT][WAITING_IN_FLIGHT] txId: \(transactionId), source: \(source)")
            while inFlightProcessingTxIDs.contains(transactionId) {
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            }
            let isDone = completedProcessedTxIDs.contains(transactionId)
            return BackendProcessingResult(
                success: isDone,
                statusCode: isDone ? 200 : nil,
                failureReason: isDone ? "already_completed" : "in_flight_timeout",
                userErrorMessage: isDone ? "" : "Payment processing timed out. Your purchase will automatically sync."
            )
        }
        
        inFlightProcessingTxIDs.insert(transactionId)
        defer {
            inFlightProcessingTxIDs.remove(transactionId)
        }
        
        print("[PAYMENT][BACKEND_VERIFICATION_STARTED] txId: \(transactionId), productId: \(productId), source: \(source)")
        
        let endpoint = "\(APIConfiguration.shared.baseURL)/subscription/credits/purchase"
        guard let url = URL(string: endpoint) else {
            print("[PAYMENT][BACKEND_VERIFICATION_FAILED] txId: \(transactionId), error: invalid_endpoint_url")
            return BackendProcessingResult(
                success: false,
                statusCode: nil,
                failureReason: "invalid_endpoint_url",
                userErrorMessage: "Unable to connect to server. Your purchase will automatically sync."
            )
        }
        
        let bearerToken = await MainActor.run { AuthManager.shared.bearerToken }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = bearerToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.timeoutInterval = 15
        
        let payload: [String: Any] = [
            "signed_transaction_jws": jwsRepresentation
        ]
        
        guard let httpBody = try? JSONSerialization.data(withJSONObject: payload) else {
            print("[PAYMENT][BACKEND_VERIFICATION_FAILED] txId: \(transactionId), error: serialization_failed")
            return BackendProcessingResult(
                success: false,
                statusCode: nil,
                failureReason: "serialization_failed",
                userErrorMessage: "Unable to serialize purchase data."
            )
        }
        request.httpBody = httpBody
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                print("[PAYMENT][BACKEND_VERIFICATION_FAILED] txId: \(transactionId), error: non_http_response")
                return BackendProcessingResult(
                    success: false,
                    statusCode: nil,
                    failureReason: "non_http_response",
                    userErrorMessage: "Payment received, but we couldn't add your searches yet. Your purchase is safe and we'll retry automatically."
                )
            }
            
            if (200...299).contains(httpResponse.statusCode) {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let currentBalance = json["current_balance"] as? Int {
                    
                    let oldBalance = self.remainingPlotCredits
                    self.completedProcessedTxIDs.insert(transactionId)
                    
                    // ONLY UPDATE LOCAL BALANCE HERE UPON CONFIRMED AUTHORITATIVE RESPONSE
                    self.remainingPlotCredits = currentBalance
                    self.persistCurrentCredits()
                    
                    print("[PAYMENT][BACKEND_VERIFICATION_SUCCESS] txId: \(transactionId), serverBalance: \(currentBalance)")
                    print("[PAYMENT][CREDITS_UPDATED] txId: \(transactionId), oldBalance: \(oldBalance), newBalance: \(currentBalance), source: backend_response")
                    return BackendProcessingResult(success: true, statusCode: httpResponse.statusCode, failureReason: "none", userErrorMessage: "")
                } else {
                    print("[PAYMENT][BACKEND_VERIFICATION_FAILED] txId: \(transactionId), error: invalid_json_payload")
                    return BackendProcessingResult(
                        success: false,
                        statusCode: httpResponse.statusCode,
                        failureReason: "invalid_json_payload",
                        userErrorMessage: "Payment received, but we couldn't parse the credit balance. Your purchase is safe and we'll retry automatically."
                    )
                }
            } else {
                // Parse backend error details if available (SAFE logging only)
                var errDetail = "HTTP \(httpResponse.statusCode)"
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let detail = json["detail"] as? String {
                    errDetail = detail
                }
                print("[PAYMENT][BACKEND_VERIFICATION_FAILED] txId: \(transactionId), statusCode: \(httpResponse.statusCode), errorDetail: \(errDetail)")
                
                let userMsg = "Payment received, but we couldn't add your searches yet. Your purchase is safe and we'll retry automatically."
                return BackendProcessingResult(
                    success: false,
                    statusCode: httpResponse.statusCode,
                    failureReason: "http_\(httpResponse.statusCode)_\(errDetail)",
                    userErrorMessage: userMsg
                )
            }
        } catch let urlErr as URLError {
            print("[PAYMENT][BACKEND_VERIFICATION_FAILED] txId: \(transactionId), networkError: \(urlErr.localizedDescription)")
            let isOffline = (urlErr.code == .notConnectedToInternet || urlErr.code == .networkConnectionLost || urlErr.code == .timedOut)
            let userMsg = isOffline
                ? "Payment was approved by Apple, but server credit recording is pending. Your purchase will automatically sync as soon as connectivity is restored."
                : "Payment received, but we couldn't add your searches yet. Your purchase is safe and we'll retry automatically."
            return BackendProcessingResult(
                success: false,
                statusCode: nil,
                failureReason: "network_error_\(urlErr.code.rawValue)",
                userErrorMessage: userMsg
            )
        } catch {
            print("[PAYMENT][BACKEND_VERIFICATION_FAILED] txId: \(transactionId), error: \(error.localizedDescription)")
            return BackendProcessingResult(
                success: false,
                statusCode: nil,
                failureReason: "exception_\(error.localizedDescription)",
                userErrorMessage: "Payment received, but we couldn't add your searches yet. Your purchase is safe and we'll retry automatically."
            )
        }
    }
    
    /// Fetches the server-authoritative plot credit balance for the authenticated user
    public func fetchServerCreditBalance() async {
        let bearerToken = await MainActor.run { AuthManager.shared.bearerToken }
        guard let token = bearerToken else { return }
        
        let endpoint = "\(APIConfiguration.shared.baseURL)/subscription/credits"
        guard let url = URL(string: endpoint) else { return }
        
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
                            if self.remainingPlotCredits != serverCredits {
                                self.remainingPlotCredits = serverCredits
                            }
                        }
                        self.persistCurrentCredits()
                        print("DEBUG: 🌐 Reconciled local credits with server authoritative balance: \(serverCredits) (unlimited=\(isUnlimitedServer))")
                    }
                }
            }
        } catch {
            print("DEBUG: ⚠️ Could not fetch server credits (offline fallback): \(error.localizedDescription)")
        }
    }
    
    /// Syncs verified Apple JWS subscription transaction with Bhumitra Backend for server-authoritative entitlements
    @discardableResult
    public func syncSubscriptionWithBackend(jwsRepresentation: String, originalTransactionId: String, appAccountToken: String? = nil) async -> Bool {
        var bearerToken = await MainActor.run { AuthManager.shared.bearerToken }
        if bearerToken == nil {
            await AuthManager.shared.ensureDeviceSession()
            bearerToken = await MainActor.run { AuthManager.shared.bearerToken }
        }
        
        let user = await MainActor.run { AuthManager.shared.currentUser }
        let userId = user?.id ?? "device_guest"
        
        let endpoint = "\(APIConfiguration.shared.baseURL)/subscription/verify"
        guard let url = URL(string: endpoint) else {
            print("[PAYMENT][BACKEND_VERIFICATION_FAILED] error: invalid_endpoint_url")
            return false
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
            print("[PAYMENT][BACKEND_VERIFICATION_FAILED] error: serialization_failed")
            return false
        }
        request.httpBody = httpBody
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) {
                print("[PAYMENT][BACKEND_VERIFICATION_SUCCESS] 🌐 Server successfully verified and linked Apple Subscription.")
                return true
            } else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? -1
                print("[PAYMENT][BACKEND_VERIFICATION_FAILED] ⚠️ Backend subscription verify failed with status: \(code)")
                return false
            }
        } catch {
            print("[PAYMENT][BACKEND_VERIFICATION_FAILED] ⚠️ Backend subscription sync skipped/failed: \(error.localizedDescription)")
            return false
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
                        }
                    }
                    print("DEBUG: 🌐 Live Server Entitlement confirmed: isPremium=\(isPremiumServer)")
                }
            }
        } catch {
            print("DEBUG: ⚠️ Could not fetch live server status: \(error.localizedDescription)")
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
