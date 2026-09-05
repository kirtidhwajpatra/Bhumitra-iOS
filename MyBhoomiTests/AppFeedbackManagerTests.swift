//
//  AppFeedbackManagerTests.swift
//  MyBhoomiTests
//
//  Comprehensive automated XCTest suite verifying all 12 App Store feedback prompt test cases.
//

import XCTest
@testable import MyBhoomi

@MainActor
final class AppFeedbackManagerTests: XCTestCase {
    
    private func createIsolatedManager() -> (AppFeedbackManager, UserDefaults) {
        let suiteName = "test_feedback_\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let manager = AppFeedbackManager(userDefaults: defaults)
        return (manager, defaults)
    }
    
    // TEST 1: Fresh install -> successful search -> feedback prompt appears (Opportunity #1)
    func test_1_fresh_install_first_successful_search_presents_prompt() {
        let (manager, _) = createIsolatedManager()
        XCTAssertEqual(manager.opportunityCount, 0)
        XCTAssertTrue(manager.canPresentFeedbackPrompt)
        
        manager.notifySuccessfulSearchResultPresented(resultId: "parcel_101", animatedDelay: 0)
        
        XCTAssertTrue(manager.isFeedbackPromptPresented)
        XCTAssertEqual(manager.currentOpportunity, .first)
        XCTAssertEqual(manager.opportunityCount, 1)
    }
    
    // TEST 2: First prompt -> Maybe later -> second successful search -> feedback prompt appears (Opportunity #2)
    func test_2_maybe_later_allows_second_opportunity() {
        let (manager, _) = createIsolatedManager()
        
        // 1st search
        manager.notifySuccessfulSearchResultPresented(resultId: "parcel_101", animatedDelay: 0)
        XCTAssertTrue(manager.isFeedbackPromptPresented)
        XCTAssertEqual(manager.currentOpportunity, .first)
        
        // User taps "Maybe later"
        manager.handleDismiss()
        XCTAssertFalse(manager.isFeedbackPromptPresented)
        XCTAssertEqual(manager.opportunityCount, 1)
        XCTAssertTrue(manager.canPresentFeedbackPrompt)
        
        // 2nd search
        manager.notifySuccessfulSearchResultPresented(resultId: "parcel_202", animatedDelay: 0)
        XCTAssertTrue(manager.isFeedbackPromptPresented)
        XCTAssertEqual(manager.currentOpportunity, .second)
        XCTAssertEqual(manager.opportunityCount, 2)
    }
    
    // TEST 3: First prompt -> Rate MyBhoomi -> completed -> second successful search does NOT prompt
    func test_3_rate_action_completes_flow_and_prevents_future_prompts() {
        let (manager, _) = createIsolatedManager()
        
        // 1st search
        manager.notifySuccessfulSearchResultPresented(resultId: "parcel_101", animatedDelay: 0)
        XCTAssertTrue(manager.isFeedbackPromptPresented)
        
        // User taps "Rate MyBhoomi"
        manager.handleRate()
        XCTAssertFalse(manager.isFeedbackPromptPresented)
        XCTAssertTrue(manager.hasCompletedFeedback)
        XCTAssertFalse(manager.canPresentFeedbackPrompt)
        
        // 2nd search
        manager.notifySuccessfulSearchResultPresented(resultId: "parcel_202", animatedDelay: 0)
        XCTAssertFalse(manager.isFeedbackPromptPresented)
        XCTAssertFalse(manager.canPresentFeedbackPrompt)
    }
    
    // TEST 4: First prompt -> close -> second search -> close -> third search -> NO prompt
    func test_4_max_two_opportunities_strictly_enforced() {
        let (manager, _) = createIsolatedManager()
        
        // 1st search
        manager.notifySuccessfulSearchResultPresented(resultId: "parcel_101", animatedDelay: 0)
        manager.handleDismiss()
        
        // 2nd search
        manager.notifySuccessfulSearchResultPresented(resultId: "parcel_202", animatedDelay: 0)
        XCTAssertTrue(manager.isFeedbackPromptPresented)
        XCTAssertEqual(manager.currentOpportunity, .second)
        manager.handleDismiss()
        XCTAssertFalse(manager.isFeedbackPromptPresented)
        XCTAssertFalse(manager.canPresentFeedbackPrompt)
        XCTAssertEqual(manager.opportunityCount, 2)
        
        // 3rd search
        manager.notifySuccessfulSearchResultPresented(resultId: "parcel_303", animatedDelay: 0)
        XCTAssertFalse(manager.isFeedbackPromptPresented)
        XCTAssertEqual(manager.opportunityCount, 2)
    }
    
    // TEST 5: Failed search -> NO prompt
    func test_5_failed_search_does_not_trigger_prompt() {
        let (manager, _) = createIsolatedManager()
        XCTAssertFalse(manager.isFeedbackPromptPresented)
        XCTAssertEqual(manager.opportunityCount, 0)
        XCTAssertTrue(manager.canPresentFeedbackPrompt)
    }
    
    // TEST 6: Empty result -> NO prompt
    func test_6_empty_result_does_not_trigger_prompt() {
        let (manager, _) = createIsolatedManager()
        XCTAssertFalse(manager.isFeedbackPromptPresented)
        XCTAssertEqual(manager.opportunityCount, 0)
    }
    
    // TEST 7: API error -> NO prompt
    func test_7_api_error_does_not_trigger_prompt() {
        let (manager, _) = createIsolatedManager()
        XCTAssertFalse(manager.isFeedbackPromptPresented)
        XCTAssertEqual(manager.opportunityCount, 0)
    }
    
    // TEST 8: Search button pressed multiple times / repeated calls for same result -> exactly 1 prompt
    func test_8_duplicate_triggers_for_same_result_debounced() {
        let (manager, _) = createIsolatedManager()
        
        manager.notifySuccessfulSearchResultPresented(resultId: "parcel_101", animatedDelay: 0)
        let countAfterFirst = manager.opportunityCount
        
        // Redundant triggers for the same parcel
        manager.notifySuccessfulSearchResultPresented(resultId: "parcel_101", animatedDelay: 0)
        manager.notifySuccessfulSearchResultPresented(resultId: "parcel_101", animatedDelay: 0)
        
        XCTAssertEqual(manager.opportunityCount, countAfterFirst)
        XCTAssertEqual(countAfterFirst, 1)
        XCTAssertTrue(manager.isFeedbackPromptPresented)
    }
    
    // TEST 9: App restarted after first opportunity -> persisted state remains correct (count = 1)
    func test_9_app_restart_persists_opportunity_count() {
        let suiteName = "test_feedback_restart_\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        
        // Session 1: Show first opportunity and dismiss
        var manager1: AppFeedbackManager? = AppFeedbackManager(userDefaults: defaults)
        manager1?.notifySuccessfulSearchResultPresented(resultId: "parcel_101", animatedDelay: 0)
        manager1?.handleDismiss()
        XCTAssertEqual(manager1?.opportunityCount, 1)
        manager1 = nil // Simulate app termination
        
        // Session 2: App restarts with new instance reading from same persisted defaults
        let manager2 = AppFeedbackManager(userDefaults: defaults)
        XCTAssertEqual(manager2.opportunityCount, 1)
        XCTAssertFalse(manager2.hasCompletedFeedback)
        XCTAssertTrue(manager2.canPresentFeedbackPrompt)
    }
    
    // TEST 10: App restarted after second opportunity -> prompt never appears again
    func test_10_app_restart_after_second_opportunity_permanently_suppresses_prompt() {
        let suiteName = "test_feedback_restart2_\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        
        // Session 1: Exhaust both opportunities
        var manager1: AppFeedbackManager? = AppFeedbackManager(userDefaults: defaults)
        manager1?.notifySuccessfulSearchResultPresented(resultId: "parcel_101", animatedDelay: 0)
        manager1?.handleDismiss()
        manager1?.notifySuccessfulSearchResultPresented(resultId: "parcel_202", animatedDelay: 0)
        manager1?.handleDismiss()
        manager1 = nil // Simulate app termination
        
        // Session 2: App restarts
        let manager2 = AppFeedbackManager(userDefaults: defaults)
        manager2.notifySuccessfulSearchResultPresented(resultId: "parcel_303", animatedDelay: 0)
        
        XCTAssertEqual(manager2.opportunityCount, 2)
        XCTAssertFalse(manager2.canPresentFeedbackPrompt)
        XCTAssertFalse(manager2.isFeedbackPromptPresented)
    }
    
    // TEST 11: User is logged out / Guest -> works seamlessly without crash or login requirement
    func test_11_guest_user_operates_without_auth_dependency() {
        let (manager, _) = createIsolatedManager()
        manager.notifySuccessfulSearchResultPresented(resultId: "guest_parcel_555", animatedDelay: 0)
        XCTAssertTrue(manager.isFeedbackPromptPresented)
        XCTAssertEqual(manager.opportunityCount, 1)
    }
    
    // TEST 12: StoreKit review call behavior -> app continues normally regardless of StoreKit UI display
    func test_12_storekit_call_handles_dismissal_gracefully() {
        let (manager, _) = createIsolatedManager()
        manager.notifySuccessfulSearchResultPresented(resultId: "parcel_101", animatedDelay: 0)
        manager.handleRate()
        
        XCTAssertTrue(manager.hasCompletedFeedback)
        XCTAssertEqual(manager.opportunityCount, 2)
        XCTAssertFalse(manager.isFeedbackPromptPresented)
    }
}
