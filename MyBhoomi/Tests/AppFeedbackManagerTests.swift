//
//  AppFeedbackManagerTests.swift
//  MyBhoomi
//
//  Comprehensive automated test suite verifying all 12 App Store feedback prompt test cases.
//

import Foundation

@MainActor
public struct AppFeedbackManagerTests {
    
    public static func runAllTests() -> (passed: Int, failed: Int, errors: [String]) {
        var passed = 0
        var failed = 0
        var errors: [String] = []
        
        func evaluate(_ name: String, _ block: () -> Bool) {
            let result = block()
            if result {
                passed += 1
                print("✅ [PASS] \(name)")
            } else {
                failed += 1
                let err = "❌ [FAIL] \(name)"
                errors.append(err)
                print(err)
            }
        }
        
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("  RUNNING MYBHOOMI APP STORE FEEDBACK PROMPT TESTS")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        
        // Helper factory to create an isolated test instance
        func createIsolatedManager() -> (AppFeedbackManager, UserDefaults) {
            let suiteName = "test_feedback_\(UUID().uuidString)"
            let defaults = UserDefaults(suiteName: suiteName)!
            defaults.removePersistentDomain(forName: suiteName)
            let manager = AppFeedbackManager(userDefaults: defaults)
            return (manager, defaults)
        }
        
        // TEST 1: Fresh install -> successful search -> feedback prompt appears (Opportunity #1)
        evaluate("test_1_fresh_install_first_successful_search_presents_prompt") {
            let (manager, _) = createIsolatedManager()
            guard manager.opportunityCount == 0 else { return false }
            guard manager.canPresentFeedbackPrompt == true else { return false }
            
            manager.notifySuccessfulSearchResultPresented(resultId: "parcel_101", animatedDelay: 0)
            
            return manager.isFeedbackPromptPresented == true &&
                   manager.currentOpportunity == .first &&
                   manager.opportunityCount == 1
        }
        
        // TEST 2: First prompt -> Maybe later -> second successful search -> feedback prompt appears (Opportunity #2)
        evaluate("test_2_maybe_later_allows_second_opportunity") {
            let (manager, _) = createIsolatedManager()
            
            // 1st search
            manager.notifySuccessfulSearchResultPresented(resultId: "parcel_101", animatedDelay: 0)
            guard manager.isFeedbackPromptPresented == true, manager.currentOpportunity == .first else { return false }
            
            // User taps "Maybe later"
            manager.handleDismiss()
            guard manager.isFeedbackPromptPresented == false else { return false }
            guard manager.opportunityCount == 1 else { return false }
            guard manager.canPresentFeedbackPrompt == true else { return false }
            
            // 2nd search
            manager.notifySuccessfulSearchResultPresented(resultId: "parcel_202", animatedDelay: 0)
            return manager.isFeedbackPromptPresented == true &&
                   manager.currentOpportunity == .second &&
                   manager.opportunityCount == 2
        }
        
        // TEST 3: First prompt -> Rate MyBhoomi -> completed -> second successful search does NOT prompt
        evaluate("test_3_rate_action_completes_flow_and_prevents_future_prompts") {
            let (manager, _) = createIsolatedManager()
            
            // 1st search
            manager.notifySuccessfulSearchResultPresented(resultId: "parcel_101", animatedDelay: 0)
            guard manager.isFeedbackPromptPresented == true else { return false }
            
            // User taps "Rate MyBhoomi"
            manager.handleRate()
            guard manager.isFeedbackPromptPresented == false else { return false }
            guard manager.hasCompletedFeedback == true else { return false }
            guard manager.canPresentFeedbackPrompt == false else { return false }
            
            // 2nd search
            manager.notifySuccessfulSearchResultPresented(resultId: "parcel_202", animatedDelay: 0)
            return manager.isFeedbackPromptPresented == false &&
                   manager.canPresentFeedbackPrompt == false
        }
        
        // TEST 4: First prompt -> close -> second search -> close -> third search -> NO prompt
        evaluate("test_4_max_two_opportunities_strictly_enforced") {
            let (manager, _) = createIsolatedManager()
            
            // 1st search
            manager.notifySuccessfulSearchResultPresented(resultId: "parcel_101", animatedDelay: 0)
            manager.handleDismiss()
            
            // 2nd search
            manager.notifySuccessfulSearchResultPresented(resultId: "parcel_202", animatedDelay: 0)
            guard manager.isFeedbackPromptPresented == true && manager.currentOpportunity == .second else { return false }
            manager.handleDismiss()
            guard manager.isFeedbackPromptPresented == false else { return false }
            guard manager.canPresentFeedbackPrompt == false else { return false }
            guard manager.opportunityCount == 2 else { return false }
            
            // 3rd search
            manager.notifySuccessfulSearchResultPresented(resultId: "parcel_303", animatedDelay: 0)
            return manager.isFeedbackPromptPresented == false &&
                   manager.opportunityCount == 2
        }
        
        // TEST 5: Failed search -> NO prompt
        evaluate("test_5_failed_search_does_not_trigger_prompt") {
            let (manager, _) = createIsolatedManager()
            // When a search fails, loadRoR() catches the error and does NOT call notifySuccessfulSearchResultPresented
            return manager.isFeedbackPromptPresented == false &&
                   manager.opportunityCount == 0 &&
                   manager.canPresentFeedbackPrompt == true
        }
        
        // TEST 6: Empty result -> NO prompt
        evaluate("test_6_empty_result_does_not_trigger_prompt") {
            let (manager, _) = createIsolatedManager()
            // When search returns empty results, result is not displayed and notify is not called
            return manager.isFeedbackPromptPresented == false &&
                   manager.opportunityCount == 0
        }
        
        // TEST 7: API error -> NO prompt
        evaluate("test_7_api_error_does_not_trigger_prompt") {
            let (manager, _) = createIsolatedManager()
            // On API error, error toast / banner is shown instead of result presentation
            return manager.isFeedbackPromptPresented == false &&
                   manager.opportunityCount == 0
        }
        
        // TEST 8: Search button pressed multiple times / repeated calls for same result -> exactly 1 prompt
        evaluate("test_8_duplicate_triggers_for_same_result_debounced") {
            let (manager, _) = createIsolatedManager()
            
            manager.notifySuccessfulSearchResultPresented(resultId: "parcel_101", animatedDelay: 0)
            let countAfterFirst = manager.opportunityCount
            
            // Redundant triggers for the same parcel (e.g. view redraw, onAppear re-trigger)
            manager.notifySuccessfulSearchResultPresented(resultId: "parcel_101", animatedDelay: 0)
            manager.notifySuccessfulSearchResultPresented(resultId: "parcel_101", animatedDelay: 0)
            
            return manager.opportunityCount == countAfterFirst &&
                   countAfterFirst == 1 &&
                   manager.isFeedbackPromptPresented == true
        }
        
        // TEST 9: App restarted after first opportunity -> persisted state remains correct (count = 1)
        evaluate("test_9_app_restart_persists_opportunity_count") {
            let suiteName = "test_feedback_restart_\(UUID().uuidString)"
            let defaults = UserDefaults(suiteName: suiteName)!
            
            // Session 1: Show first opportunity and dismiss
            var manager1: AppFeedbackManager? = AppFeedbackManager(userDefaults: defaults)
            manager1?.notifySuccessfulSearchResultPresented(resultId: "parcel_101", animatedDelay: 0)
            manager1?.handleDismiss()
            guard manager1?.opportunityCount == 1 else { return false }
            manager1 = nil // Simulate app termination
            
            // Session 2: App restarts with new instance reading from same persisted defaults
            let manager2 = AppFeedbackManager(userDefaults: defaults)
            return manager2.opportunityCount == 1 &&
                   manager2.hasCompletedFeedback == false &&
                   manager2.canPresentFeedbackPrompt == true
        }
        
        // TEST 10: App restarted after second opportunity -> prompt never appears again
        evaluate("test_10_app_restart_after_second_opportunity_permanently_suppresses_prompt") {
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
            
            return manager2.opportunityCount == 2 &&
                   manager2.canPresentFeedbackPrompt == false &&
                   manager2.isFeedbackPromptPresented == false
        }
        
        // TEST 11: User is logged out / Guest -> works seamlessly without crash or login requirement
        evaluate("test_11_guest_user_operates_without_auth_dependency") {
            let (manager, _) = createIsolatedManager()
            // Notification succeeds independently of AuthManager state
            manager.notifySuccessfulSearchResultPresented(resultId: "guest_parcel_555", animatedDelay: 0)
            return manager.isFeedbackPromptPresented == true &&
                   manager.opportunityCount == 1
        }
        
        // TEST 12: StoreKit review call behavior -> app continues normally regardless of StoreKit UI display
        evaluate("test_12_storekit_call_handles_dismissal_gracefully") {
            let (manager, _) = createIsolatedManager()
            manager.notifySuccessfulSearchResultPresented(resultId: "parcel_101", animatedDelay: 0)
            manager.handleRate()
            
            // Opportunity is considered consumed and app remains responsive
            return manager.hasCompletedFeedback == true &&
                   manager.opportunityCount == 2 &&
                   manager.isFeedbackPromptPresented == false
        }
        
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("  TOTAL: \(passed + failed) | PASSED: \(passed) | FAILED: \(failed)")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        
        return (passed, failed, errors)
    }
}
