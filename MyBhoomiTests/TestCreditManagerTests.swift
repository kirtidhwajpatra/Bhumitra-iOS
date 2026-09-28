//
//  TestCreditManagerTests.swift
//  MyBhoomiTests
//
//  Unit tests for TestCreditManager (DEBUG-only sandbox).
//

#if DEBUG
import XCTest
@testable import MyBhoomi

@MainActor
final class TestCreditManagerTests: XCTestCase {
    
    override func setUp() async throws {
        // Reset shared manager and subscription state before each test
        TestCreditManager.shared.resetCredits()
        SubscriptionManager.shared.resetTestUserCredits(to: 0)
    }
    
    override func tearDown() async throws {
        TestCreditManager.shared.resetCredits()
        SubscriptionManager.shared.resetTestUserCredits(to: 0)
    }
    
    // 1. Initial Balance is 0
    func test_initial_balance_is_zero() {
        TestCreditManager.shared.resetCredits()
        XCTAssertEqual(TestCreditManager.shared.testCredits, 0)
    }
    
    // 2. Add 10 Credits
    func test_add_10_credits() {
        TestCreditManager.shared.resetCredits()
        TestCreditManager.shared.addCredits(10)
        XCTAssertEqual(TestCreditManager.shared.testCredits, 10)
    }
    
    // 3. Add 50 Credits
    func test_add_50_credits() {
        TestCreditManager.shared.resetCredits()
        TestCreditManager.shared.addCredits(50)
        XCTAssertEqual(TestCreditManager.shared.testCredits, 50)
    }
    
    // 4. Consume 1 Credit
    func test_consume_1_credit() {
        TestCreditManager.shared.resetCredits()
        TestCreditManager.shared.addCredits(10)
        let success = TestCreditManager.shared.consumeCredits(1)
        XCTAssertTrue(success)
        XCTAssertEqual(TestCreditManager.shared.testCredits, 9)
    }
    
    // 5. Consume Multiple Credits
    func test_consume_multiple_credits() {
        TestCreditManager.shared.resetCredits()
        TestCreditManager.shared.addCredits(50)
        let success = TestCreditManager.shared.consumeCredits(5)
        XCTAssertTrue(success)
        XCTAssertEqual(TestCreditManager.shared.testCredits, 45)
    }
    
    // 6. Cannot Consume When Zero
    func test_cannot_consume_when_zero() {
        TestCreditManager.shared.resetCredits()
        XCTAssertEqual(TestCreditManager.shared.testCredits, 0)
        let success = TestCreditManager.shared.consumeCredits(1)
        XCTAssertFalse(success)
        XCTAssertEqual(TestCreditManager.shared.testCredits, 0)
    }
    
    // 7. Reset Credits
    func test_reset_credits() {
        TestCreditManager.shared.addCredits(50)
        XCTAssertEqual(TestCreditManager.shared.testCredits, 50)
        TestCreditManager.shared.resetCredits()
        XCTAssertEqual(TestCreditManager.shared.testCredits, 0)
    }
    
    // 8. Persistence across instances
    func test_persistence_across_instances() {
        TestCreditManager.shared.resetCredits()
        TestCreditManager.shared.addCredits(25)
        XCTAssertEqual(TestCreditManager.shared.testCredits, 25)
        
        let stored = UserDefaults.standard.integer(forKey: "bhumitra_debug_test_credits_v1")
        XCTAssertEqual(stored, 25)
        
        // Reload from persisted storage
        TestCreditManager.shared.reloadFromDisk()
        XCTAssertEqual(TestCreditManager.shared.testCredits, 25)
    }
    
    // 9. Balance Cannot Become Negative
    func test_balance_cannot_become_negative() {
        TestCreditManager.shared.resetCredits()
        TestCreditManager.shared.addCredits(5)
        let failAttempt = TestCreditManager.shared.consumeCredits(10)
        XCTAssertFalse(failAttempt)
        XCTAssertEqual(TestCreditManager.shared.testCredits, 5)
        
        // Add invalid negative amount does nothing
        TestCreditManager.shared.addCredits(-5)
        XCTAssertEqual(TestCreditManager.shared.testCredits, 5)
        
        // Consume 0 or negative does nothing
        let zeroAttempt = TestCreditManager.shared.consumeCredits(0)
        XCTAssertFalse(zeroAttempt)
        XCTAssertEqual(TestCreditManager.shared.testCredits, 5)
    }
    
    // 10. Integration with SubscriptionManager
    func test_subscription_manager_integration() {
        let sm = SubscriptionManager.shared
        sm.resetTestUserCredits(to: 0)
        XCTAssertEqual(sm.remainingPlotCredits, 0)
        XCTAssertFalse(sm.canPerformPlotSearch)
        
        // Add test credits via shared TestCreditManager
        TestCreditManager.shared.addCredits(10)
        XCTAssertEqual(TestCreditManager.shared.testCredits, 10)
        XCTAssertEqual(sm.remainingPlotCredits, 10)
        XCTAssertTrue(sm.canPerformPlotSearch)
        
        // Consume via SubscriptionManager.consumePlotSearchCredit
        let consumed = sm.consumePlotSearchCredit(plot: "123", village: "TestVillage", district: "TestDistrict")
        XCTAssertTrue(consumed)
        XCTAssertEqual(TestCreditManager.shared.testCredits, 9)
        XCTAssertEqual(sm.remainingPlotCredits, 9)
        
        // Reset via TestCreditManager
        TestCreditManager.shared.resetCredits()
        XCTAssertEqual(TestCreditManager.shared.testCredits, 0)
        XCTAssertEqual(sm.remainingPlotCredits, 0)
        XCTAssertFalse(sm.canPerformPlotSearch)
    }
}
#endif
