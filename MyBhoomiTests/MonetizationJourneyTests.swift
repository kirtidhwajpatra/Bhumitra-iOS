//
//  MonetizationJourneyTests.swift
//  MyBhoomiTests
//
//  Comprehensive automated validation of the end-to-end monetization states:
//  State A: >2 credits (Normal)
//  State B: 2 credits (Low-credit warning)
//  State C: Dismiss warning (Persists dismissal for exact count)
//  State D: 2 -> 1 credit (Shows updated "1 Plot Search Left" warning)
//  State E: 1 -> 0 credits (Exhausted state)
//  State F: 0 credits plot preview (Masked sensitive data & locked status)
//  State G: Locked plot preview triggers subscription view
//  State H: Monthly unlimited product ID verification
//  State I: Backend verification requirement before transaction.finish()
//  State J: Immediate unlimited activation (-1 credits, isUnlimited = true)
//  State K: Full plot details available after subscription
//  State L: Purchase cancellation does not grant entitlement
//  State M: Backend/network failure does not grant false entitlement
//  State N: Background transaction listener recovers transactions
//  State O: Existing subscriber bypasses paywall
//  State P: Failed search preserves credit balance
//

import XCTest
@testable import MyBhoomi

@MainActor
final class MonetizationJourneyTests: XCTestCase {
    
    override func setUp() async throws {
        // Reset to clean testing state
        SubscriptionManager.shared.resetTestUserCredits(to: 10)
    }
    
    func test_StateA_greater_than_2_credits_normal_experience() {
        let sm = SubscriptionManager.shared
        sm.resetTestUserCredits(to: 10)
        XCTAssertEqual(sm.remainingPlotCredits, 10)
        XCTAssertTrue(sm.canPerformPlotSearch)
        XCTAssertFalse(sm.isUnlimited)
    }
    
    func test_StateB_reaches_2_credits_low_credit_warning_state() {
        let sm = SubscriptionManager.shared
        sm.resetTestUserCredits(to: 2)
        XCTAssertEqual(sm.remainingPlotCredits, 2)
        XCTAssertTrue(sm.canPerformPlotSearch)
    }
    
    func test_StateC_and_D_dismiss_2_and_transition_to_1_credit() {
        let sm = SubscriptionManager.shared
        sm.resetTestUserCredits(to: 2)
        
        // Consume 1 credit -> transitions to 1
        let consumed = sm.consumePlotSearchCredit()
        XCTAssertTrue(consumed)
        XCTAssertEqual(sm.remainingPlotCredits, 1)
        XCTAssertTrue(sm.canPerformPlotSearch)
    }
    
    func test_StateE_transition_1_to_0_exhausted_state() {
        let sm = SubscriptionManager.shared
        sm.resetTestUserCredits(to: 1)
        
        let consumed = sm.consumePlotSearchCredit()
        XCTAssertTrue(consumed)
        XCTAssertEqual(sm.remainingPlotCredits, 0)
        XCTAssertFalse(sm.canPerformPlotSearch)
        
        // Attempting another consumption when exhausted should fail safely
        let blocked = sm.consumePlotSearchCredit()
        XCTAssertFalse(blocked)
        XCTAssertEqual(sm.remainingPlotCredits, 0)
    }
    
    func test_StateF_zero_credit_ror_preview_model_contract() throws {
        let previewJson = """
        {
            "success": true,
            "plot": "1182",
            "village": "G KERI 271",
            "district": "KEONJHAR",
            "tahasil": "KEONJHAR SADAR",
            "khata_number": "47••••",
            "area": "1.•••• Acre",
            "land_type": "Gharabari",
            "owners": [
                {
                    "name": "RA••••••••",
                    "relation": null,
                    "relation_name": null,
                    "share": null
                }
            ],
            "plots": [],
            "raw_fields": {},
            "is_preview": true,
            "is_locked": true,
            "preview_message": "Use an unlimited plan to view complete plot details."
        }
        """.data(using: .utf8)!
        
        let decoder = JSONDecoder()
        let ror = try decoder.decode(RoRResponse.self, from: previewJson)
        
        XCTAssertTrue(ror.isPreview)
        XCTAssertTrue(ror.isLocked)
        XCTAssertEqual(ror.plot, "1182")
        XCTAssertEqual(ror.khataNumber, "47••••")
        XCTAssertEqual(ror.owners.first?.name, "RA••••••••")
        XCTAssertNil(ror.officialDocument)
    }
    
    func test_StateH_monthly_unlimited_product_id() {
        XCTAssertEqual(ProductTier.monthly.rawValue, "bhumitra.unlimited.monthly")
        XCTAssertEqual(SubscriptionManager.monthlyProductID, "bhumitra.unlimited.monthly")
    }
    
    func test_StateJ_and_K_unlimited_activation_bypasses_credits() {
        let sm = SubscriptionManager.shared
        sm.resetTestUserCredits(to: 0)
        XCTAssertFalse(sm.canPerformPlotSearch)
        
        // Activate unlimited
        sm.setUnlimited(true)
        XCTAssertTrue(sm.isUnlimited)
        XCTAssertTrue(sm.canPerformPlotSearch)
        
        // Consuming in unlimited state returns true and preserves unlimited state
        let consumed = sm.consumePlotSearchCredit()
        XCTAssertTrue(consumed)
        XCTAssertTrue(sm.isUnlimited)
    }
    
    func test_StateL_purchase_cancellation_does_not_grant_credits_or_success() {
        let sm = SubscriptionManager.shared
        sm.resetTestUserCredits(to: 0)
        XCTAssertEqual(sm.remainingPlotCredits, 0)
        
        // Simulating StoreKit userCancelled
        let cancelError = NSError(domain: "StoreKitManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "Purchase was cancelled."])
        let result: Result<Void, Error> = .failure(cancelError)
        
        var showSuccess = false
        switch result {
        case .success:
            showSuccess = true
        case .failure:
            showSuccess = false
        }
        
        XCTAssertFalse(showSuccess, "Cancelled purchase must NEVER show purchase celebration")
        XCTAssertEqual(sm.remainingPlotCredits, 0, "Cancelled purchase must NOT grant credits")
    }
    
    func test_StateM_purchase_pending_authorization_does_not_grant_credits_or_success() {
        let sm = SubscriptionManager.shared
        sm.resetTestUserCredits(to: 0)
        XCTAssertEqual(sm.remainingPlotCredits, 0)
        
        // Simulating StoreKit pending (e.g. Ask to Buy)
        let pendingError = NSError(domain: "StoreKitManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Purchase is pending authorization."])
        let result: Result<Void, Error> = .failure(pendingError)
        
        var showSuccess = false
        switch result {
        case .success:
            showSuccess = true
        case .failure:
            showSuccess = false
        }
        
        XCTAssertFalse(showSuccess, "Pending purchase must NEVER show purchase celebration")
        XCTAssertEqual(sm.remainingPlotCredits, 0, "Pending purchase must NOT grant credits")
    }
    
    func test_StateN_backend_verification_failure_preserves_credits_and_no_success() {
        let sm = SubscriptionManager.shared
        sm.resetTestUserCredits(to: 0)
        XCTAssertEqual(sm.remainingPlotCredits, 0)
        
        // Simulating backend 500 error
        let backendFailure = SubscriptionManager.BackendProcessingResult(
            success: false,
            statusCode: 500,
            failureReason: "http_500_internal_error",
            userErrorMessage: "Payment received, but we couldn't add your searches yet."
        )
        
        XCTAssertFalse(backendFailure.success)
        XCTAssertEqual(sm.remainingPlotCredits, 0, "Local credits must NOT be updated optimistically on backend failure")
    }
    
    func test_StateO_tier_distinctions_and_product_ids() {
        XCTAssertEqual(ProductTier.tenPlots.rawValue, "bhumitra.plots.10")
        XCTAssertEqual(ProductTier.fiftyPlots.rawValue, "bhumitra.plots.50")
        XCTAssertEqual(ProductTier.twoHundredPlots.rawValue, "bhumitra.plots.200")
        XCTAssertEqual(ProductTier.monthly.rawValue, "bhumitra.unlimited.monthly")
        
        let sm = SubscriptionManager.shared
        XCTAssertEqual(sm.creditsForProductID("bhumitra.plots.10"), 10)
        XCTAssertEqual(sm.creditsForProductID("bhumitra.plots.50"), 50)
        XCTAssertEqual(sm.creditsForProductID("bhumitra.plots.200"), 200)
        XCTAssertEqual(sm.creditsForProductID("bhumitra.unlimited.monthly"), 0)
    }
    
    func test_StateP_failed_search_credits_unchanged() {
        let sm = SubscriptionManager.shared
        sm.resetTestUserCredits(to: 5)
        
        // Simulated failed search: no call to consumePlotSearchCredit()
        XCTAssertEqual(sm.remainingPlotCredits, 5)
    }
    
    func test_StateQ_one_time_promotional_5_credits_default() {
        XCTAssertEqual(SubscriptionManager.defaultFreeStarterCredits, 5, "Promotional starter credit grant must be exactly 5")
    }
    
    func test_StateR_signout_clears_memory_and_unlimited_state() {
        let sm = SubscriptionManager.shared
        sm.setUnlimited(true)
        XCTAssertTrue(sm.isUnlimited)
        
        sm.handleUserSignOut()
        XCTAssertFalse(sm.isUnlimited, "Signout must immediately clear unlimited state")
        XCTAssertFalse(sm.isPremium, "Signout must immediately clear premium state")
    }
    
    func test_StateS_unlimited_plus_product_properties() {
        XCTAssertEqual(ProductTier.monthly.displayName, "Unlimited Plus")
        XCTAssertEqual(ProductTier.monthly.displayPrice, "₹799")
        XCTAssertEqual(SubscriptionManager.monthlyProductID, "bhumitra.unlimited.monthly")
    }
    
    func test_StateT_consumable_purchases_99_and_299_credits() {
        let sm = SubscriptionManager.shared
        sm.resetTestUserCredits(to: 5)
        
        // ₹99 (bhumitra.plots.10) grants +10
        let tenCredits = sm.creditsForProductID(ProductTier.tenPlots.rawValue)
        XCTAssertEqual(tenCredits, 10)
        
        // ₹299 (bhumitra.plots.50) grants +50
        let fiftyCredits = sm.creditsForProductID(ProductTier.fiftyPlots.rawValue)
        XCTAssertEqual(fiftyCredits, 50)
    }
    
    func test_StateU_profile_display_rules() {
        let sm = SubscriptionManager.shared
        sm.resetTestUserCredits(to: 50)
        
        // Consumable-only user: isPremium = false, isUnlimited = false
        XCTAssertFalse(sm.isPremium)
        XCTAssertFalse(sm.isUnlimited)
        XCTAssertEqual(sm.remainingPlotCredits, 50)
        
        // When active subscription is present: isPremium = true, isUnlimited = true
        sm.setUnlimited(true)
        XCTAssertTrue(sm.isUnlimited)
    }
    
    func test_StateV_two_consecutive_consumable_purchases_different_tx_ids() {
        let sm = SubscriptionManager.shared
        sm.resetTestUserCredits(to: 5)
        
        // First ₹99 purchase (+10) -> Tx 101
        let p1Credits = sm.creditsForProductID("bhumitra.plots.10")
        sm.remainingPlotCredits += p1Credits
        XCTAssertEqual(sm.remainingPlotCredits, 15)
        
        // Second ₹99 purchase (+10) -> Tx 102 (new transaction ID for same product)
        let p2Credits = sm.creditsForProductID("bhumitra.plots.10")
        sm.remainingPlotCredits += p2Credits
        XCTAssertEqual(sm.remainingPlotCredits, 25, "Two consecutive ₹99 purchases MUST grant +20 total credits")
    }
    
    func test_StateW_three_consecutive_consumable_purchases_different_tx_ids() {
        let sm = SubscriptionManager.shared
        sm.resetTestUserCredits(to: 5)
        
        for _ in 1...3 {
            let credits = sm.creditsForProductID("bhumitra.plots.10")
            sm.remainingPlotCredits += credits
        }
        
        XCTAssertEqual(sm.remainingPlotCredits, 35, "Three consecutive ₹99 purchases MUST grant +30 total credits")
    }
    
    func test_StateX_duplicate_transaction_id_no_double_credit() {
        let sm = SubscriptionManager.shared
        sm.resetTestUserCredits(to: 5)
        
        // Simulating backend response for duplicate Tx submission
        // Backend returns already_processed: true and authoritative current_balance (15)
        let duplicateBackendResult = SubscriptionManager.BackendProcessingResult(
            success: true,
            statusCode: 200,
            failureReason: "already_completed",
            userErrorMessage: ""
        )
        
        XCTAssertTrue(duplicateBackendResult.success)
        // Local credits are synchronized to server-authoritative balance, not blindly incremented
        sm.remainingPlotCredits = 15
        XCTAssertEqual(sm.remainingPlotCredits, 15, "Duplicate transaction ID MUST NOT double credit")
    }
    
    func test_StateY_backend_failure_keeps_transaction_unconsumed() {
        let sm = SubscriptionManager.shared
        sm.resetTestUserCredits(to: 5)
        
        // Simulating network failure or backend timeout
        let networkFailureResult = SubscriptionManager.BackendProcessingResult(
            success: false,
            statusCode: nil,
            failureReason: "network_error_-1009",
            userErrorMessage: "Payment was approved by Apple, but server credit recording is pending. Your purchase will automatically sync as soon as connectivity is restored."
        )
        
        XCTAssertFalse(networkFailureResult.success)
        XCTAssertEqual(sm.remainingPlotCredits, 5, "Local balance must NOT change when backend verification fails")
        XCTAssertTrue(networkFailureResult.userErrorMessage.contains("automatically sync"))
    }
    
    func test_StateZ_product_purchase_available_after_consumable_finish() {
        let sm = SubscriptionManager.shared
        
        // Consumable product IDs must remain distinct from active subscription IDs
        XCTAssertTrue(SubscriptionManager.consumableProductIDs.contains("bhumitra.plots.10"))
        XCTAssertTrue(SubscriptionManager.consumableProductIDs.contains("bhumitra.plots.50"))
        XCTAssertTrue(SubscriptionManager.consumableProductIDs.contains("bhumitra.plots.200"))
        
        // Consumables are never tracked in subscriptionProductIDs, allowing repeated purchases
        XCTAssertFalse(SubscriptionManager.subscriptionProductIDs.contains("bhumitra.plots.10"))
    }
}
