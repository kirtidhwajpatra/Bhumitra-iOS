import Foundation
import Combine

public final class SubscriptionManager: ObservableObject {
    public static let shared = SubscriptionManager()
    
    @Published public var isPremium: Bool = false
    
    public let planPrice: String = "₹399 / Month"
    public let productID = "bhumitra_premium_monthly"
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        // Observe AuthManager user change to sync isPremium status
        AuthManager.shared.$currentUser
            .receive(on: RunLoop.main)
            .sink { [weak self] user in
                self?.isPremium = user?.isPremium ?? false
            }
            .store(in: &cancellables)
    }
    
    public func purchaseSubscription() async -> Result<Bool, Error> {
        guard let user = AuthManager.shared.currentUser else {
            return .failure(NSError(domain: "SubscriptionManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "User must be logged in to purchase."]))
        }
        
        // Simulate networking delay
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let startDate = Date()
        let expiryDate = Calendar.current.date(byAdding: .month, value: 1, to: startDate)!
        
        let record = SubscriptionRecord(
            userId: user.id,
            plan: "monthly",
            amount: 399,
            status: "active",
            startDate: formatter.string(from: startDate),
            expiryDate: formatter.string(from: expiryDate)
        )
        
        DatabaseManager.shared.saveSubscription(record)
        
        await MainActor.run {
            AuthManager.shared.refreshUser()
            self.isPremium = true
        }
        
        return .success(true)
    }
    
    public func restorePurchases() async -> Result<Bool, Error> {
        guard let user = AuthManager.shared.currentUser else {
            return .failure(NSError(domain: "SubscriptionManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "User must be logged in to restore."]))
        }
        
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Find existing subscription records
        let subs = DatabaseManager.shared.loadSubscriptions()
        if let sub = subs.first(where: { $0.userId == user.id }) {
            // Restore it
            var restored = sub
            restored.status = "active"
            DatabaseManager.shared.saveSubscription(restored)
            
            await MainActor.run {
                AuthManager.shared.refreshUser()
                self.isPremium = true
            }
            return .success(true)
        }
        
        return .failure(NSError(domain: "SubscriptionManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "No previous purchase found to restore."]))
    }
    
    // MARK: - Usage Limit Management
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
    
    // Simulated method for testing billing expiry
    public func simulateSubscriptionExpiry() {
        guard let user = AuthManager.shared.currentUser else { return }
        let subs = DatabaseManager.shared.loadSubscriptions()
        if let sub = subs.first(where: { $0.userId == user.id }) {
            var expired = sub
            expired.status = "expired"
            DatabaseManager.shared.saveSubscription(expired)
            
            AuthManager.shared.refreshUser()
            self.isPremium = false
        }
    }
}
