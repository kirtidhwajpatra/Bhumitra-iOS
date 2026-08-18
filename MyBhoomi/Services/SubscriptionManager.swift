import Foundation
import Combine
import StoreKit

@MainActor
public final class SubscriptionManager: ObservableObject {
    public static let shared = SubscriptionManager()
    
    // Published states for UI
    @Published public var isPremium: Bool = false
    @Published public var monthlyProduct: Product? = nil
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String? = nil
    @Published public var activeTransactions: [Transaction] = []
    
    // Product identifiers defined in App Store Connect / StoreKit configuration
    public static let monthlyProductID = "bhumitra_premium_monthly"
    public let productIDs: Set<String> = [monthlyProductID]
    
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
    
    /// Loads subscription products directly from Apple StoreKit 2 servers
    public func loadProducts() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let products = try await Product.products(for: productIDs)
            self.monthlyProduct = products.first(where: { $0.id == Self.monthlyProductID })
            self.isLoading = false
            print("DEBUG: 🛒 StoreKit 2 loaded \(products.count) products from Apple.")
        } catch {
            self.isLoading = false
            self.errorMessage = "Failed to load subscription options: \(error.localizedDescription)"
            print("DEBUG: ❌ Failed to fetch products from App Store: \(error)")
        }
    }
    
    // MARK: - Purchase Flow
    
    /// Purchases the monthly subscription with Apple StoreKit 2
    public func purchaseSubscription() async -> Result<Transaction, Error> {
        guard let product = monthlyProduct else {
            // Try loading products once if not loaded yet
            await loadProducts()
            guard let refreshedProduct = monthlyProduct else {
                let error = NSError(domain: "StoreKitManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "Product unavailable from App Store. Please try again."])
                return .failure(error)
            }
            return await executePurchase(product: refreshedProduct)
        }
        
        return await executePurchase(product: product)
    }
    
    private func executePurchase(product: Product) async -> Result<Transaction, Error> {
        isLoading = true
        errorMessage = nil
        
        do {
            // Configure purchase with user account token if signed in with Apple
            var options: Set<Product.PurchaseOption> = []
            if let appleUserId = AuthManager.shared.currentUser?.id,
               let userUUID = UUID(uuidString: appleUserId) {
                options.insert(.appAccountToken(userUUID))
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
                
                // Sync with Bhumitra backend for server-authoritative tracking & ASSN V2 alignment
                await syncTransactionWithBackend(
                    jwsRepresentation: verificationResult.jwsRepresentation,
                    originalTransactionId: String(transaction.originalID)
                )
                
                self.isLoading = false
                print("DEBUG: 💎 Successfully purchased and verified subscription for product: \(transaction.productID)")
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
    
    /// Syncs with the App Store to restore previously purchased active subscriptions
    public func restorePurchases() async -> Result<Bool, Error> {
        isLoading = true
        errorMessage = nil
        
        do {
            // Force StoreKit 2 to sync receipt with Apple servers
            try await AppStore.sync()
            await updateSubscriptionStatus()
            
            self.isLoading = false
            if isPremium {
                print("DEBUG: 🔄 Active subscription restored successfully.")
                return .success(true)
            } else {
                let error = NSError(domain: "StoreKitManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "No active subscriptions found for your Apple ID."])
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
        
        // Transaction.currentEntitlements checks all active verified entitlements for the current Apple ID
        for await verificationResult in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(verificationResult)
                
                // Ensure transaction is for our monthly subscription and is NOT revoked
                if transaction.productID == Self.monthlyProductID && transaction.revocationDate == nil {
                    // Check expiration date for subscription
                    if let expirationDate = transaction.expirationDate {
                        if expirationDate > Date() {
                            purchasedTransactions.append(transaction)
                            hasActiveEntitlement = true
                        }
                    } else {
                        // Non-expiring entitlement
                        purchasedTransactions.append(transaction)
                        hasActiveEntitlement = true
                    }
                }
            } catch {
                print("DEBUG: ⚠️ Entitlement failed verification: \(error)")
            }
        }
        
        self.activeTransactions = purchasedTransactions
        self.isPremium = hasActiveEntitlement
        
        // Sync with local user profile
        if var user = AuthManager.shared.currentUser {
            if user.isPremium != hasActiveEntitlement {
                user.isPremium = hasActiveEntitlement
                DatabaseManager.shared.saveUser(user)
                AuthManager.shared.refreshUser()
            }
        }
        
        print("DEBUG: 🛡️ Entitlement status evaluated: isPremium = \(hasActiveEntitlement)")
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
                    await self.syncTransactionWithBackend(
                        jwsRepresentation: verificationResult.jwsRepresentation,
                        originalTransactionId: String(transaction.originalID)
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
    public func syncTransactionWithBackend(jwsRepresentation: String, originalTransactionId: String) async {
        guard let userId = AuthManager.shared.currentUser?.id else { return }
        
        let endpoint = "https://mybhoomi-ror-prod-667798363712.asia-south1.run.app/api/v1/subscription/verify"
        guard let url = URL(string: endpoint) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10
        
        let payload: [String: Any] = [
            "user_id": userId,
            "signed_transaction_jws": jwsRepresentation,
            "original_transaction_id": originalTransactionId
        ]
        
        guard let httpBody = try? JSONSerialization.data(withJSONObject: payload) else { return }
        request.httpBody = httpBody
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                print("DEBUG: 🌐 Server successfully verified and recorded Apple transaction.")
            }
        } catch {
            print("DEBUG: ⚠️ Backend subscription sync skipped/failed: \(error.localizedDescription)")
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
