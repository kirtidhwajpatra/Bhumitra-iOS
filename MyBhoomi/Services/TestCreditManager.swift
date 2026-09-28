//
//  TestCreditManager.swift
//  MyBhoomi
//
//  DEBUG-ONLY sandbox for manually granting and managing test credits
//  for repeated payment/credit-flow and plot-unlock testing.
//  Completely compiled out of Release builds.
//

#if DEBUG
import Foundation
import Combine

/// Singleton manager providing a DEBUG-only test credits sandbox.
/// Allows manual balance manipulation (+10, +50, reset) without touching StoreKit or backend servers.
@MainActor
public final class TestCreditManager: ObservableObject {
    public static let shared = TestCreditManager()
    
    private let userDefaults: UserDefaults
    private let testCreditsKey = "bhumitra_debug_test_credits_v1"
    
    @Published public private(set) var testCredits: Int = 0
    
    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        userDefaults.removeObject(forKey: testCreditsKey)
        self.testCredits = 0
    }
    
    /// Increments test credits by the specified amount and persists to local storage.
    public func addCredits(_ amount: Int) {
        guard amount > 0 else { return }
        testCredits += amount
        persist()
        SubscriptionManager.shared.recalculateCreditsFromTestManager()
        debugLog("[TEST_CREDITS] 💳 Added +\(amount) test credits. Current test balance: \(testCredits)")
    }
    
    /// Consumes the requested amount of test credits if available.
    /// Returns true if successfully consumed, false otherwise.
    @discardableResult
    public func consumeCredits(_ amount: Int = 1) -> Bool {
        guard amount > 0 else { return false }
        guard testCredits >= amount else {
            debugLog("[TEST_CREDITS] ⚠️ Insufficient test credits. Requested: \(amount), available: \(testCredits)")
            return false
        }
        testCredits -= amount
        persist()
        SubscriptionManager.shared.recalculateCreditsFromTestManager()
        debugLog("[TEST_CREDITS] 📉 Consumed \(amount) test credits. Remaining test balance: \(testCredits)")
        return true
    }
    
    /// Resets test credits back to zero.
    public func resetCredits() {
        testCredits = 0
        persist()
        SubscriptionManager.shared.recalculateCreditsFromTestManager()
        debugLog("[TEST_CREDITS] 🔄 Reset test credits to 0")
    }
    
    /// Reloads persisted balance from disk/UserDefaults (e.g. on app launch or test verification)
    public func reloadFromDisk() {
        self.testCredits = max(0, userDefaults.integer(forKey: testCreditsKey))
        SubscriptionManager.shared.recalculateCreditsFromTestManager()
    }
    
    /// Helper for tests or direct balance setting
    public func setCreditsForTesting(_ amount: Int) {
        testCredits = max(0, amount)
        persist()
        SubscriptionManager.shared.recalculateCreditsFromTestManager()
    }
    
    private func persist() {
        userDefaults.set(testCredits, forKey: testCreditsKey)
    }
}
#endif
