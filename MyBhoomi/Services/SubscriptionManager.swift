import Foundation
import Combine
import StoreKit

public enum ProductTier: String, CaseIterable, Identifiable {
    case free = "bhumitra_free_tier"
    case tenPlots = "bhumitra_pack_10plots"
    case fiftyPlots = "bhumitra_pack_50plots"
    case lifetime = "bhumitra_premium_lifetime"
    case monthly = "bhumitra_premium_monthly"
    case yearly = "bhumitra_premium_yearly"
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .free: return "5 Plots Search"
        case .tenPlots: return "+10 Plots Search"
        case .fiftyPlots: return "+50 Plots Search"
        case .lifetime: return "Unlimited Plot Search"
        case .monthly: return "Monthly Unlimited"
        case .yearly: return "Yearly Pass"
        }
    }
    
    public var badge: String? {
        switch self {
        case .free: return "Free"
        case .tenPlots: return "Quick ⚡"
        case .fiftyPlots: return "Good Enough 📦"
        case .lifetime: return "Deep Research 👍"
        case .monthly: return "UNLIMITED ACCESS"
        case .yearly: return "SAVE 37%"
        }
    }
}

@MainActor
public final class SubscriptionManager: ObservableObject {
    public static let shared = SubscriptionManager()
    
    // Published states for UI
    @Published public var isPremium: Bool = false
    @Published public var activeTier: ProductTier? = nil
    
    // Plot Search Credits & Quota Management (Persisted securely via Keychain & Server)
    @Published public var remainingPlotCredits: Int = 5
    @Published public var isUnlimited: Bool = false
    
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
    @Published public var lifetimeProduct: Product? = nil
    @Published public var monthlyProduct: Product? = nil
    @Published public var yearlyProduct: Product? = nil
    
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String? = nil
    @Published public var activeTransactions: [Transaction] = []
    
    // Product identifiers defined in App Store Connect / StoreKit configuration
    public static let tenPlotsProductID = ProductTier.tenPlots.rawValue
    public static let fiftyPlotsProductID = ProductTier.fiftyPlots.rawValue
    public static let lifetimeProductID = ProductTier.lifetime.rawValue
    public static let monthlyProductID = ProductTier.monthly.rawValue
    public static let yearlyProductID = ProductTier.yearly.rawValue
    
    public let productIDs: Set<String> = [
        tenPlotsProductID,
        fiftyPlotsProductID,
        lifetimeProductID,
        monthlyProductID,
        yearlyProductID
    ]
    
    private var transactionListenerTask: Task<Void, Never>? = nil
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        // 1. Recover credit and unlimited state from secure Keychain
        loadInitialCreditState()
        
        // 2. Start background transaction listener immediately on app launch
        transactionListenerTask = listenForTransactions()
        
        // 3. Load products and verify existing entitlements with Apple
        Task {
            await loadProducts()
            await updateSubscriptionStatus()
        }
    }
    
    // MARK: - Persistent Credit Loading
    
    private func loadInitialCreditState() {
        let isDeviceInit = (KeychainHelper.shared.readString(key: keychainDeviceInitKey) == "true")
        if !isDeviceInit {
            // Brand new first-time install: grant initial 5 Free starter credits
            KeychainHelper.shared.save(key: keychainDeviceInitKey, string: "true")
            KeychainHelper.shared.save(key: keychainDeviceCreditsKey, string: "5")
            KeychainHelper.shared.save(key: keychainDeviceUnlimitedKey, string: "false")
            self.remainingPlotCredits = 5
            self.isUnlimited = false
            print("DEBUG: 🎁 Initialized 5 Free starter plot credits for new install.")
        } else {
            // Existing device / Reinstalled app: restore EXACT remaining credits from Keychain
            let savedCredits = Int(KeychainHelper.shared.readString(key: keychainDeviceCreditsKey) ?? "0") ?? 0
            let savedUnlimited = (KeychainHelper.shared.readString(key: keychainDeviceUnlimitedKey) == "true")
            self.remainingPlotCredits = savedCredits
            self.isUnlimited = savedUnlimited
            print("DEBUG: 🔒 Restored persistent device credits from Keychain: \(savedCredits), unlimited: \(savedUnlimited)")
        }
    }
    
    public func handleUserSignIn(userId: String) {
        let isUserInit = (KeychainHelper.shared.readString(key: userInitKey(for: userId)) == "true")
        if !isUserInit {
            // First time this Apple Account has signed in: initialize account with current device balance
            KeychainHelper.shared.save(key: userInitKey(for: userId), string: "true")
            KeychainHelper.shared.save(key: userCreditsKey(for: userId), string: "\(self.remainingPlotCredits)")
            KeychainHelper.shared.save(key: userUnlimitedKey(for: userId), string: self.isUnlimited ? "true" : "false")
            print("DEBUG: 👤 Initialized user credit profile for '\(userId)': \(self.remainingPlotCredits) credits")
        } else {
            // Existing user account: restore saved user credits
            let savedUserCredits = Int(KeychainHelper.shared.readString(key: userCreditsKey(for: userId)) ?? "0") ?? 0
            let savedUserUnlimited = (KeychainHelper.shared.readString(key: userUnlimitedKey(for: userId)) == "true")
            self.remainingPlotCredits = savedUserCredits
            self.isUnlimited = savedUserUnlimited || self.isPremium
            
            // Mirror to device Keychain
            KeychainHelper.shared.save(key: keychainDeviceCreditsKey, string: "\(self.remainingPlotCredits)")
            KeychainHelper.shared.save(key: keychainDeviceUnlimitedKey, string: self.isUnlimited ? "true" : "false")
            print("DEBUG: 👤 Restored user credits for '\(userId)': \(savedUserCredits), unlimited: \(self.isUnlimited)")
        }
        
        // Reconcile asynchronously with Bhumitra Backend Server
        Task {
            await syncCreditsWithServer(userId: userId, action: "sync")
        }
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
    
    public func addCredits(amount: Int) {
        remainingPlotCredits += amount
        persistCurrentCredits()
        print("DEBUG: 💳 Added \(amount) plot search credits. Total: \(remainingPlotCredits)")
        
        if let user = AuthManager.shared.currentUser {
            Task { await syncCreditsWithServer(userId: user.id, action: "add", amount: amount) }
        }
    }
    
    public func setUnlimited(_ unlimited: Bool) {
        isUnlimited = unlimited
        persistCurrentCredits()
        print("DEBUG: ♾️ Set Unlimited Plot Searches: \(unlimited)")
        
        if let user = AuthManager.shared.currentUser {
            Task { await syncCreditsWithServer(userId: user.id, action: "set_unlimited") }
        }
    }
    
    @discardableResult
    public func consumePlotSearchCredit() -> Bool {
        if isUnlimited || isPremium {
            return true
        }
        if remainingPlotCredits > 0 {
            remainingPlotCredits -= 1
            persistCurrentCredits()
            print("DEBUG: 📉 Consumed 1 plot credit. Remaining: \(remainingPlotCredits)")
            
            if let user = AuthManager.shared.currentUser {
                Task { await syncCreditsWithServer(userId: user.id, action: "consume", amount: 1) }
            }
            return true
        }
        return false
    }
    
    /// Syncs credit balance with Bhumitra Backend Server
    public func syncCreditsWithServer(userId: String, action: String = "sync", amount: Int? = nil) async {
        guard let url = URL(string: "\(APIConfiguration.shared.baseURL)/subscription/credits/sync") else { return }
        let bearerToken = await MainActor.run { AuthManager.shared.bearerToken }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = bearerToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.timeoutInterval = 8
        
        var payload: [String: Any] = [
            "user_id": userId,
            "remaining_credits": self.remainingPlotCredits,
            "is_unlimited": self.isUnlimited || self.isPremium,
            "action": action
        ]
        if let amt = amount {
            payload["amount"] = amt
        }
        
        guard let httpBody = try? JSONSerialization.data(withJSONObject: payload) else { return }
        request.httpBody = httpBody
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpRes = response as? HTTPURLResponse, (200...299).contains(httpRes.statusCode) {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let serverCredits = json["remaining_credits"] as? Int {
                        if serverCredits != self.remainingPlotCredits {
                            self.remainingPlotCredits = serverCredits
                            self.persistCurrentCredits()
                            print("DEBUG: 🌐 Reconciled local credits with server balance: \(serverCredits)")
                        }
                    }
                    if let serverUnlimited = json["is_unlimited"] as? Bool {
                        if serverUnlimited != self.isUnlimited {
                            self.isUnlimited = serverUnlimited
                            self.persistCurrentCredits()
                        }
                    }
                }
            }
        } catch {
            print("DEBUG: 🌐 Credits synced locally (server offline fallback): \(error.localizedDescription)")
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
        
        do {
            let fetchedProducts = try await Product.products(for: productIDs)
            
            // Sort products by tier
            self.products = fetchedProducts
            self.tenPlotsProduct = fetchedProducts.first(where: { $0.id == Self.tenPlotsProductID })
            self.fiftyPlotsProduct = fetchedProducts.first(where: { $0.id == Self.fiftyPlotsProductID })
            self.lifetimeProduct = fetchedProducts.first(where: { $0.id == Self.lifetimeProductID })
            self.monthlyProduct = fetchedProducts.first(where: { $0.id == Self.monthlyProductID })
            self.yearlyProduct = fetchedProducts.first(where: { $0.id == Self.yearlyProductID })
            
            self.isLoading = false
            print("DEBUG: 🛒 StoreKit 2 loaded \(fetchedProducts.count) products from Apple.")
            for p in fetchedProducts {
                print("DEBUG:    📦 Product: \(p.id) | Display Price: \(p.displayPrice)")
            }
        } catch {
            self.isLoading = false
            self.errorMessage = "Failed to load pricing: \(error.localizedDescription)"
            print("DEBUG: ❌ Failed to fetch products from App Store: \(error)")
        }
    }
    
    // MARK: - Purchase Flow
    
    /// Purchases a specific StoreKit 2 product (Monthly, Yearly, or Lifetime)
    public func purchase(_ product: Product) async -> Result<Transaction, Error> {
        return await executePurchase(product: product)
    }
    
    /// Purchases by tier
    public func purchaseTier(_ tier: ProductTier) async -> Result<Transaction, Error> {
        if tier == .free {
            // Free tier is already activated by default
            return .failure(NSError(domain: "SubscriptionManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "You are already on the Free starter plan."]))
        }
        
        let product: Product?
        switch tier {
        case .free: product = nil
        case .tenPlots: product = tenPlotsProduct
        case .fiftyPlots: product = fiftyPlotsProduct
        case .lifetime: product = lifetimeProduct
        case .monthly: product = monthlyProduct
        case .yearly: product = yearlyProduct
        }
        
        guard let validProduct = product else {
            await loadProducts()
            let refreshed = products.first(where: { $0.id == tier.rawValue })
            guard let finalProduct = refreshed else {
                let error = NSError(domain: "StoreKitManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "Selected plan is unavailable from App Store."])
                return .failure(error)
            }
            return await executePurchase(product: finalProduct)
        }
        
        return await executePurchase(product: validProduct)
    }
    
    private func executePurchase(product: Product) async -> Result<Transaction, Error> {
        isLoading = true
        errorMessage = nil
        
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
                // Cryptographically verify Apple's JWS signed transaction
                let transaction = try checkVerified(verificationResult)
                
                // Always finish the transaction with Apple once processed
                await transaction.finish()
                
                // Apply purchased credit pack or unlimited access
                if product.id == Self.tenPlotsProductID {
                    self.addCredits(amount: 10)
                } else if product.id == Self.fiftyPlotsProductID {
                    self.addCredits(amount: 50)
                } else if product.id == Self.lifetimeProductID || product.id == Self.monthlyProductID || product.id == Self.yearlyProductID {
                    self.setUnlimited(true)
                }
                
                // Update verified entitlements directly from StoreKit
                await updateSubscriptionStatus()
                
                // Sync with Bhumitra backend with appAccountToken
                let token = transaction.appAccountToken?.uuidString
                await syncTransactionWithBackend(
                    jwsRepresentation: verificationResult.jwsRepresentation,
                    originalTransactionId: String(transaction.originalID),
                    appAccountToken: token
                )
                
                self.isLoading = false
                print("DEBUG: 💎 Successfully purchased and verified \(transaction.productID)")
                return .success(transaction)
                
            case .userCancelled:
                self.isLoading = false
                let error = NSError(domain: "StoreKitManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "Purchase was cancelled."])
                return .failure(error)
                
            case .pending:
                self.isLoading = false
                let error = NSError(domain: "StoreKitManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Purchase is pending authorization (e.g. Ask to Buy)."])
                return .failure(error)
                
            @unknown default:
                self.isLoading = false
                let error = NSError(domain: "StoreKitManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown purchase response from Apple."])
                return .failure(error)
            }
        } catch {
            self.isLoading = false
            self.errorMessage = error.localizedDescription
            print("DEBUG: ❌ Purchase failed with error: \(error)")
            return .failure(error)
        }
    }
    
    // MARK: - Restore Purchases
    
    /// Syncs with the App Store to restore previously purchased active subscriptions or lifetime purchases
    public func restorePurchases() async -> Result<Bool, Error> {
        isLoading = true
        errorMessage = nil
        
        do {
            try await AppStore.sync()
            await updateSubscriptionStatus()
            
            self.isLoading = false
            if isPremium {
                print("DEBUG: 🔄 Active subscription restored successfully. Active Tier: \(String(describing: activeTier))")
                return .success(true)
            } else {
                let error = NSError(domain: "StoreKitManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "No active purchases found for your Apple ID."])
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
    
    /// Verifies live user entitlements directly from Apple's Transaction.currentEntitlements
    public func updateSubscriptionStatus() async {
        var purchasedTransactions: [Transaction] = []
        var hasActiveEntitlement = false
        var currentActiveTier: ProductTier? = nil
        
        for await verificationResult in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(verificationResult)
                
                // Check if transaction matches one of our active products and is NOT revoked
                if productIDs.contains(transaction.productID) && transaction.revocationDate == nil {
                    // Check expiration for auto-renewable subscriptions
                    if let expirationDate = transaction.expirationDate {
                        if expirationDate > Date() {
                            purchasedTransactions.append(transaction)
                            hasActiveEntitlement = true
                            if transaction.productID == Self.yearlyProductID {
                                currentActiveTier = .yearly
                            } else if transaction.productID == Self.monthlyProductID {
                                currentActiveTier = .monthly
                            }
                        }
                    } else {
                        // Non-expiring entitlement (Lifetime)
                        purchasedTransactions.append(transaction)
                        hasActiveEntitlement = true
                        currentActiveTier = .lifetime
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
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }
    
    /// Listens for real-time transactions from Apple (renewals, family sharing, off-device purchases)
    private func listenForTransactions() -> Task<Void, Never> {
        return Task.detached {
            for await verificationResult in Transaction.updates {
                do {
                    let transaction = try await self.checkVerified(verificationResult)
                    
                    // Always finish the transaction with Apple
                    await transaction.finish()
                    
                    // Re-evaluate entitlement status on main actor
                    await self.updateSubscriptionStatus()
                    
                    // Sync renewed/updated transaction with Bhumitra Backend
                    let token = transaction.appAccountToken?.uuidString
                    await self.syncTransactionWithBackend(
                        jwsRepresentation: verificationResult.jwsRepresentation,
                        originalTransactionId: String(transaction.originalID),
                        appAccountToken: token
                    )
                    
                    print("DEBUG: 🔔 Received transaction update from Apple for: \(transaction.productID)")
                } catch {
                    print("DEBUG: ❌ Transaction update verification failed: \(error)")
                }
            }
        }
    }
    
    // MARK: - Backend Server Sync
    
    /// Syncs verified Apple JWS transaction with Bhumitra Backend for server-authoritative entitlements
    public func syncTransactionWithBackend(jwsRepresentation: String, originalTransactionId: String, appAccountToken: String? = nil) async {
        let (user, bearerToken) = await MainActor.run {
            (AuthManager.shared.currentUser, AuthManager.shared.bearerToken)
        }
        guard let userId = user?.id else { return }
        
        let endpoint = "\(APIConfiguration.shared.baseURL)/subscription/verify"
        guard let url = URL(string: endpoint) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = bearerToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.timeoutInterval = 10
        
        let token = appAccountToken ?? user?.appAccountToken
        
        var payload: [String: Any] = [
            "user_id": userId,
            "signed_transaction_jws": jwsRepresentation,
            "original_transaction_id": originalTransactionId
        ]
        
        if let token = token {
            payload["app_account_token"] = token
        }
        
        guard let httpBody = try? JSONSerialization.data(withJSONObject: payload) else { return }
        request.httpBody = httpBody
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                print("DEBUG: 🌐 Server successfully linked Apple Transaction with appAccountToken: \(token ?? "N/A")")
            }
        } catch {
            print("DEBUG: ⚠️ Backend subscription sync skipped/failed: \(error.localizedDescription)")
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
        return getOwnershipPreviewCount() < 5
    }
    
    public func incrementOwnershipViewCount() {
        guard let user = AuthManager.shared.currentUser else { return }
        if !isPremium {
            DatabaseManager.shared.incrementUsage(for: user.id, month: currentMonthString)
        }
    }
}
