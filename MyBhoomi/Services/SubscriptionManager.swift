import Foundation
import Combine
import StoreKit

public enum ProductTier: String, CaseIterable, Identifiable {
    case tenPlots = "bhumitra_pack_10plots"
    case fiftyPlots = "bhumitra_pack_50plots"
    case lifetime = "bhumitra_premium_lifetime"
    case monthly = "bhumitra_premium_monthly"
    case yearly = "bhumitra_premium_yearly"
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .tenPlots: return "10 Plots Search"
        case .fiftyPlots: return "50 Plots Search"
        case .lifetime: return "Unlimited Plot Search"
        case .monthly: return "Monthly Unlimited"
        case .yearly: return "Yearly Pass"
        }
    }
    
    public var badge: String? {
        switch self {
        case .tenPlots: return "Quick ✦"
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
        // 1. Start background transaction listener immediately on app launch
        transactionListenerTask = listenForTransactions()
        
        // 2. Load products and verify existing entitlements with Apple
        Task {
            await loadProducts()
            await updateSubscriptionStatus()
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
        let product: Product?
        switch tier {
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
