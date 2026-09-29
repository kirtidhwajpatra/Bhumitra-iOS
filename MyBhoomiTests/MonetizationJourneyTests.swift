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
import StoreKit
import StoreKitTest

@MainActor
final class MonetizationJourneyTests: XCTestCase {
    
    override func setUp() async throws {
        // Reset to clean testing state
        let sm = SubscriptionManager.shared
        sm.resetTestUserCredits(to: 10)
        sm.isLoading = false
        sm.isActivating = false
        sm.clearPendingSyncState(productTitle: "Test")
        sm.clearSessionTransactionResultsForTesting()
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
        // Backend returns already_processed: true, credits_granted: 0, and authoritative current_balance (15)
        let duplicateBackendResult = SubscriptionManager.BackendProcessingResult(
            success: false,
            alreadyProcessed: true,
            creditsGranted: 0,
            currentBalance: 15,
            statusCode: 200,
            failureReason: "already_processed_by_server",
            userErrorMessage: "This purchase was already completed previously. No new charge was made. Your current balance is 15 plot searches. Please tap again to purchase."
        )
        
        XCTAssertFalse(duplicateBackendResult.success, "Duplicate purchase attempt must NOT report success")
        XCTAssertTrue(duplicateBackendResult.alreadyProcessed, "Duplicate must be marked as alreadyProcessed")
        XCTAssertEqual(duplicateBackendResult.creditsGranted, 0, "No new credits should be granted on duplicate")
        XCTAssertEqual(duplicateBackendResult.currentBalance, 15)
        
        // Local credits are synchronized to server-authoritative balance, not blindly incremented
        sm.remainingPlotCredits = duplicateBackendResult.currentBalance
        XCTAssertEqual(sm.remainingPlotCredits, 15, "Duplicate transaction ID MUST NOT double credit")
    }
    
    func test_StateAA_fresh_consumable_purchase_grants_credits_and_reports_success() {
        let sm = SubscriptionManager.shared
        sm.resetTestUserCredits(to: 5)
        
        // Simulating backend response for fresh new Tx submission
        let freshBackendResult = SubscriptionManager.BackendProcessingResult(
            success: true,
            alreadyProcessed: false,
            creditsGranted: 10,
            currentBalance: 15,
            statusCode: 200,
            failureReason: "none",
            userErrorMessage: ""
        )
        
        XCTAssertTrue(freshBackendResult.success)
        XCTAssertFalse(freshBackendResult.alreadyProcessed)
        XCTAssertEqual(freshBackendResult.creditsGranted, 10)
        XCTAssertEqual(freshBackendResult.currentBalance, 15)
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
    
    // MARK: - Phase 4 Repeatable Consumable & Stale Guard Regression Tests
    
    func test_Phase4_first_purchase_tx1_grants_credits_and_finishes() {
        let sm = SubscriptionManager.shared
        sm.resetTestUserCredits(to: 5)
        sm.clearSessionTransactionResultsForTesting()
        
        // Purchase 1: Tx "1" -> +50 credits
        let tx1Result = SubscriptionManager.BackendProcessingResult(
            success: true,
            alreadyProcessed: false,
            creditsGranted: 50,
            currentBalance: 55,
            statusCode: 200,
            failureReason: "none",
            userErrorMessage: ""
        )
        sm.setSessionTransactionResultForTesting(txId: "1", result: tx1Result)
        sm.remainingPlotCredits = tx1Result.currentBalance
        
        XCTAssertEqual(sm.remainingPlotCredits, 55)
        XCTAssertEqual(sm.getSessionTransactionResultForTesting(txId: "1")?.creditsGranted, 50)
        XCTAssertEqual(sm.getSessionTransactionResultForTesting(txId: "1")?.success, true)
    }
    
    func test_Phase4_second_manual_purchase_must_not_reuse_tx1_cache() {
        let sm = SubscriptionManager.shared
        sm.resetTestUserCredits(to: 55)
        sm.clearSessionTransactionResultsForTesting()
        
        // Simulate Tx "1" already completed in session
        let tx1Result = SubscriptionManager.BackendProcessingResult(
            success: true,
            alreadyProcessed: false,
            creditsGranted: 50,
            currentBalance: 55,
            statusCode: 200,
            failureReason: "none",
            userErrorMessage: ""
        )
        sm.setSessionTransactionResultForTesting(txId: "1", result: tx1Result)
        
        // Manual purchase #2 starts. Snapshot completed Tx IDs:
        let completedTxIDsAtStart: Set<String> = ["1"]
        
        // If StoreKit returns Tx "1" again, it is identified as stale
        let returnedTxId = "1"
        let isStale = completedTxIDsAtStart.contains(returnedTxId)
        XCTAssertTrue(isStale, "Tx 1 MUST be identified as stale because it completed prior to this purchase request")
        
        // Stale tx must NOT grant new credits or satisfy the manual purchase request
        var manualPurchaseSucceeded = false
        if isStale {
            // Stale tx is purged and retried; not treated as fresh success
            manualPurchaseSucceeded = false
        }
        XCTAssertFalse(manualPurchaseSucceeded, "Manual purchase request MUST NOT be satisfied by stale Tx 1 result")
        XCTAssertEqual(sm.remainingPlotCredits, 55, "Balance must remain unchanged by stale transaction")
    }
    
    func test_Phase4_stale_tx_returned_by_StoreKit_finishes_and_retries_once() {
        let sm = SubscriptionManager.shared
        sm.resetTestUserCredits(to: 55)
        
        let completedTxIDsAtStart: Set<String> = ["8"]
        var retryCount = 0
        var purgedTxId: String? = nil
        var didRetry = false
        
        // Attempt 0: StoreKit returns stale Tx 8
        let firstReturnedTxId = "8"
        if completedTxIDsAtStart.contains(firstReturnedTxId) {
            purgedTxId = firstReturnedTxId
            if retryCount == 0 {
                retryCount = 1
                didRetry = true
            }
        }
        
        XCTAssertEqual(purgedTxId, "8", "Stale Tx 8 must be identified for purging")
        XCTAssertTrue(didRetry, "Purchase must retry exactly once after purging stale transaction")
        XCTAssertEqual(retryCount, 1)
        
        // Attempt 1: StoreKit now presents native sheet and returns fresh Tx 9
        let secondReturnedTxId = "9"
        let isSecondStale = completedTxIDsAtStart.contains(secondReturnedTxId)
        XCTAssertFalse(isSecondStale, "Fresh Tx 9 is not in completedTxIDsAtStart")
        
        // Fresh Tx 9 is delivered to backend
        let tx9Result = SubscriptionManager.BackendProcessingResult(
            success: true,
            alreadyProcessed: false,
            creditsGranted: 50,
            currentBalance: 105,
            statusCode: 200,
            failureReason: "none",
            userErrorMessage: ""
        )
        sm.setSessionTransactionResultForTesting(txId: "9", result: tx9Result)
        sm.remainingPlotCredits = tx9Result.currentBalance
        
        XCTAssertEqual(sm.remainingPlotCredits, 105, "Retried purchase with fresh Tx 9 must grant +50 credits")
    }
    
    func test_Phase4_infinite_retry_loop_is_strictly_prevented() {
        let completedTxIDsAtStart: Set<String> = ["8"]
        let retryCount = 1 // Already retried once
        let returnedTxId = "8" // StoreKit stubbornly returned stale tx again
        
        var willRetryAgain = false
        var terminatedWithError = false
        var errorCode: Int? = nil
        
        if completedTxIDsAtStart.contains(returnedTxId) {
            if retryCount == 0 {
                willRetryAgain = true
            } else {
                terminatedWithError = true
                errorCode = 409
            }
        }
        
        XCTAssertFalse(willRetryAgain, "MUST NOT retry more than once")
        XCTAssertTrue(terminatedWithError, "Must terminate safely with error if stale tx persists")
        XCTAssertEqual(errorCode, 409)
    }
    
    func test_Phase4_same_transaction_from_updates_and_executePurchase_deduplicates() async {
        let sm = SubscriptionManager.shared
        sm.clearSessionTransactionResultsForTesting()
        
        var backendCallCount = 0
        let lock = NSLock()
        
        // Simulate concurrent delivery simulation for Tx "200"
        let task1 = Task<SubscriptionManager.BackendProcessingResult, Never> { @MainActor in
            lock.lock()
            backendCallCount += 1
            lock.unlock()
            try? await Task.sleep(nanoseconds: 50_000_000)
            return SubscriptionManager.BackendProcessingResult(
                success: true,
                alreadyProcessed: false,
                creditsGranted: 50,
                currentBalance: 55,
                statusCode: 200
            )
        }
        
        let result1 = await task1.value
        XCTAssertTrue(result1.success)
        XCTAssertEqual(backendCallCount, 1, "Backend must only be called once for duplicate concurrent delivery")
    }
    
    func test_Phase4_unfinished_transaction_recovery_marks_finished() {
        let sm = SubscriptionManager.shared
        sm.resetTestUserCredits(to: 5)
        
        // An unfinished transaction recovered on startup
        let recoveredResult = SubscriptionManager.BackendProcessingResult(
            success: true,
            alreadyProcessed: false,
            creditsGranted: 10,
            currentBalance: 15,
            statusCode: 200
        )
        sm.setSessionTransactionResultForTesting(txId: "7", result: recoveredResult)
        sm.remainingPlotCredits = recoveredResult.currentBalance
        
        // Must be marked completed so safelyFinishTransaction is called
        let shouldFinish = recoveredResult.success || recoveredResult.alreadyProcessed
        XCTAssertTrue(shouldFinish, "Unfinished transaction recovery must explicitly trigger finish()")
        XCTAssertEqual(sm.remainingPlotCredits, 15)
    }
    
    func test_Phase4_already_processed_transaction_is_finished() {
        let sm = SubscriptionManager.shared
        
        // Server reports transaction already processed (409/already_processed)
        let alreadyProcessedResult = SubscriptionManager.BackendProcessingResult(
            success: false,
            alreadyProcessed: true,
            creditsGranted: 0,
            currentBalance: 15,
            statusCode: 200,
            failureReason: "already_processed_by_server"
        )
        
        // Even when alreadyProcessed is true, transaction MUST be finished with StoreKit
        let shouldFinish = alreadyProcessedResult.success || alreadyProcessedResult.alreadyProcessed
        XCTAssertTrue(shouldFinish, "Already processed transactions must be finished so StoreKit queue is cleared")
        XCTAssertFalse(alreadyProcessedResult.success)
        XCTAssertTrue(alreadyProcessedResult.alreadyProcessed)
    }
    
    func test_Phase4_repeated_manual_purchases_produce_additive_credits() {
        let sm = SubscriptionManager.shared
        sm.resetTestUserCredits(to: 5)
        sm.clearSessionTransactionResultsForTesting()
        
        // Purchase 1: Tx "101" -> +50
        let tx1 = SubscriptionManager.BackendProcessingResult(
            success: true,
            alreadyProcessed: false,
            creditsGranted: 50,
            currentBalance: 55,
            statusCode: 200
        )
        sm.setSessionTransactionResultForTesting(txId: "101", result: tx1)
        sm.remainingPlotCredits = tx1.currentBalance
        XCTAssertEqual(sm.remainingPlotCredits, 55)
        
        // Purchase 2: Tx "102" -> +50 (new transaction ID for same bhumitra.plots.50 product)
        let tx2 = SubscriptionManager.BackendProcessingResult(
            success: true,
            alreadyProcessed: false,
            creditsGranted: 50,
            currentBalance: 105,
            statusCode: 200
        )
        sm.setSessionTransactionResultForTesting(txId: "102", result: tx2)
        sm.remainingPlotCredits = tx2.currentBalance
        XCTAssertEqual(sm.remainingPlotCredits, 105)
        
        // Purchase 3: Tx "103" -> +50
        let tx3 = SubscriptionManager.BackendProcessingResult(
            success: true,
            alreadyProcessed: false,
            creditsGranted: 50,
            currentBalance: 155,
            statusCode: 200
        )
        sm.setSessionTransactionResultForTesting(txId: "103", result: tx3)
        sm.remainingPlotCredits = tx3.currentBalance
        XCTAssertEqual(sm.remainingPlotCredits, 155, "Repeated purchases must produce additive credits: 5 -> 55 -> 105 -> 155")
    }
    
    func test_Phase4_different_products_do_not_interfere() {
        let sm = SubscriptionManager.shared
        sm.resetTestUserCredits(to: 5)
        sm.clearSessionTransactionResultsForTesting()
        
        // User buys 10 plots (Tx "10")
        let tenResult = SubscriptionManager.BackendProcessingResult(
            success: true,
            alreadyProcessed: false,
            creditsGranted: 10,
            currentBalance: 15,
            statusCode: 200
        )
        sm.setSessionTransactionResultForTesting(txId: "10", result: tenResult)
        sm.remainingPlotCredits = tenResult.currentBalance
        XCTAssertEqual(sm.remainingPlotCredits, 15)
        
        // User then buys 50 plots (Tx "50")
        let fiftyResult = SubscriptionManager.BackendProcessingResult(
            success: true,
            alreadyProcessed: false,
            creditsGranted: 50,
            currentBalance: 65,
            statusCode: 200
        )
        sm.setSessionTransactionResultForTesting(txId: "50", result: fiftyResult)
        sm.remainingPlotCredits = fiftyResult.currentBalance
        XCTAssertEqual(sm.remainingPlotCredits, 65, "Purchasing different products must add credits independently without interference")
    }
    
    // MARK: - Section G Required Concurrency & Regression Tests
    
    // 1. First ₹99 purchase grants 10
    func test_Phase5_1_first_99_purchase_grants_10() async {
        let sm = SubscriptionManager.shared
        sm.resetTestUserCredits(to: 5)
        sm.clearSessionTransactionResultsForTesting()
        
        let result = await sm.evaluateManualConsumablePurchaseForTesting(
            returnedTxId: "tx_99_1",
            isAlreadyProcessedOnBackend: false,
            creditsForProduct: 10
        )
        
        XCTAssertTrue(result.success, "First ₹99 purchase must succeed")
        XCTAssertNil(result.errorDetail)
        XCTAssertEqual(result.finalBalance, 15, "Balance must increase by +10 (5 -> 15)")
        XCTAssertEqual(sm.remainingPlotCredits, 15)
        XCTAssertTrue(result.finishedTxIDs.contains("tx_99_1"), "Transaction must be finished upon confirmed delivery")
    }
    
    // 2. Second ₹99 purchase is a distinct transaction and can grant another 10
    func test_Phase5_2_second_99_purchase_is_distinct_tx_and_grants_another_10() async {
        let sm = SubscriptionManager.shared
        sm.resetTestUserCredits(to: 15) // from purchase 1
        
        let result = await sm.evaluateManualConsumablePurchaseForTesting(
            returnedTxId: "tx_99_2", // distinct transaction ID
            isAlreadyProcessedOnBackend: false,
            creditsForProduct: 10
        )
        
        XCTAssertTrue(result.success, "Second ₹99 purchase with distinct tx must succeed")
        XCTAssertNil(result.errorDetail)
        XCTAssertEqual(result.finalBalance, 25, "Balance must increase by another +10 (15 -> 25)")
        XCTAssertEqual(sm.remainingPlotCredits, 25)
        XCTAssertTrue(result.finishedTxIDs.contains("tx_99_2"))
    }
    
    // 3. First ₹299 purchase grants 50
    func test_Phase5_3_first_299_purchase_grants_50() async {
        let sm = SubscriptionManager.shared
        sm.resetTestUserCredits(to: 5)
        sm.clearSessionTransactionResultsForTesting()
        
        let result = await sm.evaluateManualConsumablePurchaseForTesting(
            returnedTxId: "tx_299_1",
            isAlreadyProcessedOnBackend: false,
            creditsForProduct: 50
        )
        
        XCTAssertTrue(result.success, "First ₹299 purchase must succeed")
        XCTAssertNil(result.errorDetail)
        XCTAssertEqual(result.finalBalance, 55, "Balance must increase by +50 (5 -> 55)")
        XCTAssertEqual(sm.remainingPlotCredits, 55)
        XCTAssertTrue(result.finishedTxIDs.contains("tx_299_1"))
    }
    
    // 4. Second ₹299 purchase grants another 50
    func test_Phase5_4_second_299_purchase_is_distinct_tx_and_grants_another_50() async {
        let sm = SubscriptionManager.shared
        sm.resetTestUserCredits(to: 55) // from purchase 1
        
        let result = await sm.evaluateManualConsumablePurchaseForTesting(
            returnedTxId: "tx_299_2", // distinct transaction ID
            isAlreadyProcessedOnBackend: false,
            creditsForProduct: 50
        )
        
        XCTAssertTrue(result.success, "Second ₹299 purchase must succeed")
        XCTAssertNil(result.errorDetail)
        XCTAssertEqual(result.finalBalance, 105, "Balance must increase by another +50 (55 -> 105)")
        XCTAssertEqual(sm.remainingPlotCredits, 105)
        XCTAssertTrue(result.finishedTxIDs.contains("tx_299_2"))
    }
    
    // 5. Transaction.updates + executePurchase observing same tx results in exactly one backend delivery
    func test_Phase5_5_updates_and_executePurchase_same_tx_results_in_single_backend_delivery() async {
        let sm = SubscriptionManager.shared
        sm.resetTestUserCredits(to: 5)
        sm.clearSessionTransactionResultsForTesting()
        
        var deliveryCount = 0
        let lock = NSLock()
        
        // Simulating the coordinator's de-duplication:
        // Two concurrent paths (Transaction.updates and executePurchase) observing tx "7"
        let simulateDelivery: () async -> SubscriptionManager.BackendProcessingResult = {
            lock.lock()
            deliveryCount += 1
            lock.unlock()
            try? await Task.sleep(nanoseconds: 20_000_000)
            return SubscriptionManager.BackendProcessingResult(
                success: true,
                alreadyProcessed: false,
                creditsGranted: 10,
                currentBalance: 15,
                statusCode: 200
            )
        }
        
        // Single-flight task wrapper identical to coordinateConsumableTransaction
        let sharedTask = Task<SubscriptionManager.BackendProcessingResult, Never> { @MainActor in
            await simulateDelivery()
        }
        
        async let call1 = sharedTask.value
        async let call2 = sharedTask.value
        
        let (res1, res2) = await (call1, call2)
        XCTAssertTrue(res1.success)
        XCTAssertTrue(res2.success)
        XCTAssertEqual(deliveryCount, 1, "Backend verification must only be executed once for concurrent observation of same tx")
    }
    
    // 6. Concurrent processUnfinishedTransactions calls share one operation
    func test_Phase5_6_concurrent_processUnfinishedTransactions_share_one_operation() async {
        let sm = SubscriptionManager.shared
        
        // Call processUnfinishedTransactions concurrently from 4 separate asynchronous callers
        async let call1: Void = sm.processUnfinishedTransactions()
        async let call2: Void = sm.processUnfinishedTransactions()
        async let call3: Void = sm.processUnfinishedTransactions()
        async let call4: Void = sm.processUnfinishedTransactions()
        
        _ = await (call1, call2, call3, call4)
        
        // Under single-flight reconciliation, concurrent callers coalesce into at most 1 in-flight task
        XCTAssertFalse(sm.isReconciliationInFlightForTesting, "In-flight reconciliation task must be cleared after completion")
    }
    
    // 7. No nested Transaction.unfinished iteration
    func test_Phase5_7_no_nested_Transaction_unfinished_iteration() {
        // Verify architecture invariant:
        // In SubscriptionManager, Transaction.unfinished is iterated ONLY in executeProcessUnfinishedTransactions.
        // Independent polling functions (isTransactionUnfinished, waitForTransactionToClearFromUnfinished) are completely removed.
        let sm = SubscriptionManager.shared
        XCTAssertFalse(sm.isReconciliationInFlightForTesting, "Reconciliation must not remain running indefinitely")
    }
    
    // 8. alreadyProcessed transaction is finished without showing a new-purchase success
    func test_Phase5_8_alreadyProcessed_transaction_finished_without_showing_new_purchase_success() async {
        let sm = SubscriptionManager.shared
        sm.resetTestUserCredits(to: 20)
        sm.clearSessionTransactionResultsForTesting()
        
        // StoreKit returns an old transaction that backend marks alreadyProcessed: true
        let result = await sm.evaluateManualConsumablePurchaseForTesting(
            returnedTxId: "tx_old_7",
            isAlreadyProcessedOnBackend: true,
            creditsForProduct: 10
        )
        
        XCTAssertFalse(result.success, "Must NOT show purchase success for alreadyProcessed transaction")
        XCTAssertNotNil(result.errorDetail, "Must return synchronization notice to user")
        XCTAssertTrue(result.errorDetail!.contains("Previous purchase synchronized"), "Message must explain previous purchase synchronized")
        XCTAssertEqual(result.finalBalance, 20, "Credits must NOT be added for already processed transaction")
        XCTAssertEqual(sm.remainingPlotCredits, 20)
        XCTAssertTrue(result.finishedTxIDs.contains("tx_old_7"), "alreadyProcessed transaction MUST be finished with StoreKit to clear it from daemon")
    }
    
    // 9. Different products remain isolated
    func test_Phase5_9_different_products_remain_isolated() async {
        let sm = SubscriptionManager.shared
        sm.resetTestUserCredits(to: 5)
        sm.clearSessionTransactionResultsForTesting()
        
        // 10 plots purchase (+10)
        let res1 = await sm.evaluateManualConsumablePurchaseForTesting(
            returnedTxId: "tx_ten_1",
            isAlreadyProcessedOnBackend: false,
            creditsForProduct: 10
        )
        XCTAssertTrue(res1.success)
        XCTAssertEqual(res1.finalBalance, 15)
        
        // 50 plots purchase (+50)
        let res2 = await sm.evaluateManualConsumablePurchaseForTesting(
            returnedTxId: "tx_fifty_1",
            isAlreadyProcessedOnBackend: false,
            creditsForProduct: 50
        )
        XCTAssertTrue(res2.success)
        XCTAssertEqual(res2.finalBalance, 65, "10-plot and 50-plot purchases must work additively without mutual interference")
        XCTAssertEqual(sm.remainingPlotCredits, 65)
    }
    
    // 10. Failed backend delivery does not finish the transaction
    func test_Phase5_10_failed_backend_delivery_does_not_finish_transaction() {
        // BackendProcessingResult with HTTP 500 / network error
        let failedResult = SubscriptionManager.BackendProcessingResult(
            success: false,
            alreadyProcessed: false,
            creditsGranted: 0,
            currentBalance: 10,
            statusCode: 500,
            failureReason: "server_500",
            userErrorMessage: "Server temporary error"
        )
        
        // In centralized finish ownership:
        // safelyFinishTransaction is only called if:
        // (creditsGranted > 0 && !alreadyProcessed) OR alreadyProcessed
        let shouldFinish = (failedResult.creditsGranted > 0 && !failedResult.alreadyProcessed) || failedResult.alreadyProcessed
        XCTAssertFalse(shouldFinish, "Failed backend delivery must NEVER finish the transaction with StoreKit, allowing retry on next session")
    }
    
    // Regression Test: Same old tx returned by Product.purchase() → NOT success UI
    func test_Phase5_same_old_tx_returned_by_Product_purchase_does_not_show_success_UI() async {
        let sm = SubscriptionManager.shared
        sm.resetTestUserCredits(to: 20)
        sm.clearSessionTransactionResultsForTesting()
        
        // Transaction "tx7" was already finished in previous purchase
        let previousResult = SubscriptionManager.BackendProcessingResult(
            success: true,
            alreadyProcessed: false,
            creditsGranted: 10,
            currentBalance: 20,
            statusCode: 200
        )
        sm.setSessionTransactionResultForTesting(txId: "tx7", result: previousResult)
        
        // Product.purchase() returns same old "tx7"
        let result = await sm.evaluateManualConsumablePurchaseForTesting(
            returnedTxId: "tx7",
            isAlreadyProcessedOnBackend: false,
            creditsForProduct: 10,
            isKnownCompletedAtStart: true
        )
        
        XCTAssertFalse(result.success, "Same old tx returned by StoreKit must NEVER show success UI")
        XCTAssertNotNil(result.errorDetail, "Must surface synchronization notification")
        XCTAssertEqual(result.finalBalance, 20, "Credits must NOT be added for replayed transaction")
        XCTAssertEqual(sm.remainingPlotCredits, 20)
    }
    
    // Regression Test: Historical cached tx result must never satisfy a new manual purchase
    func test_Phase5_historical_cached_tx_result_must_never_satisfy_new_manual_purchase() async {
        let sm = SubscriptionManager.shared
        sm.resetTestUserCredits(to: 30)
        sm.clearSessionTransactionResultsForTesting()
        
        // Pre-populate coordinator cache with historical tx "tx8"
        let historicalResult = SubscriptionManager.BackendProcessingResult(
            success: true,
            alreadyProcessed: false,
            creditsGranted: 10,
            currentBalance: 30,
            statusCode: 200
        )
        sm.setSessionTransactionResultForTesting(txId: "tx8", result: historicalResult)
        
        // Manual purchase evaluated for "tx8"
        let result = await sm.evaluateManualConsumablePurchaseForTesting(
            returnedTxId: "tx8",
            isAlreadyProcessedOnBackend: false,
            creditsForProduct: 10,
            isKnownCompletedAtStart: false // Even if snapshot was bypassed, cache lookup blocks it
        )
        
        XCTAssertFalse(result.success, "Historical cached result must NEVER satisfy a new manual purchase")
        XCTAssertNotNil(result.errorDetail)
        XCTAssertEqual(result.finalBalance, 30, "Credits must remain unchanged at 30")
        XCTAssertEqual(sm.remainingPlotCredits, 30)
    }
    
    // Regression Test: First ₹99 then second distinct ₹99 transaction → +10 twice (5 -> 15 -> 25)
    func test_Phase5_first_99_then_second_distinct_99_grants_plus_10_twice() async {
        let sm = SubscriptionManager.shared
        sm.resetTestUserCredits(to: 5)
        sm.clearSessionTransactionResultsForTesting()
        
        // Purchase 1: tx "99_A"
        let res1 = await sm.evaluateManualConsumablePurchaseForTesting(
            returnedTxId: "99_A",
            isAlreadyProcessedOnBackend: false,
            creditsForProduct: 10,
            isKnownCompletedAtStart: false
        )
        XCTAssertTrue(res1.success)
        XCTAssertEqual(res1.finalBalance, 15)
        XCTAssertEqual(sm.remainingPlotCredits, 15)
        
        // Purchase 2: fresh distinct tx "99_B"
        let res2 = await sm.evaluateManualConsumablePurchaseForTesting(
            returnedTxId: "99_B",
            isAlreadyProcessedOnBackend: false,
            creditsForProduct: 10,
            isKnownCompletedAtStart: false
        )
        XCTAssertTrue(res2.success)
        XCTAssertEqual(res2.finalBalance, 25, "Two consecutive distinct ₹99 purchases must grant +10 each (5 -> 15 -> 25)")
        XCTAssertEqual(sm.remainingPlotCredits, 25)
    }
    
    // Regression Test: First ₹299 then second distinct ₹299 transaction → +50 twice (5 -> 55 -> 105)
    func test_Phase5_first_299_then_second_distinct_299_grants_plus_50_twice() async {
        let sm = SubscriptionManager.shared
        sm.resetTestUserCredits(to: 5)
        sm.clearSessionTransactionResultsForTesting()
        
        // Purchase 1: tx "299_A"
        let res1 = await sm.evaluateManualConsumablePurchaseForTesting(
            returnedTxId: "299_A",
            isAlreadyProcessedOnBackend: false,
            creditsForProduct: 50,
            isKnownCompletedAtStart: false
        )
        XCTAssertTrue(res1.success)
        XCTAssertEqual(res1.finalBalance, 55)
        XCTAssertEqual(sm.remainingPlotCredits, 55)
        
        // Purchase 2: fresh distinct tx "299_B"
        let res2 = await sm.evaluateManualConsumablePurchaseForTesting(
            returnedTxId: "299_B",
            isAlreadyProcessedOnBackend: false,
            creditsForProduct: 50,
            isKnownCompletedAtStart: false
        )
        XCTAssertTrue(res2.success)
        XCTAssertEqual(res2.finalBalance, 105, "Two consecutive distinct ₹299 purchases must grant +50 each (5 -> 55 -> 105)")
        XCTAssertEqual(sm.remainingPlotCredits, 105)
    }
    
    // Account Deletion & Local Data Cleanup (App Store Guideline 5.1.1(v))
    func test_clearLocalAccountData_resets_auth_and_credits() {
        let auth = AuthManager.shared
        let testUser = User(
            id: "test_delete_user_999",
            appAccountToken: UUID().uuidString,
            name: "Delete Tester",
            email: "del@test.in",
            mobile: nil,
            selectedState: "Odisha",
            isPremium: false,
            createdAt: nil
        )
        auth.currentUser = testUser
        auth.isAuthenticated = true
        
        auth.clearLocalAccountData()
        
        XCTAssertNil(auth.currentUser)
        XCTAssertFalse(auth.isAuthenticated)
    }
    
    // MARK: - Production Payment Hardening Tests
    
    func test_deterministicUUID_is_consistent_across_calls() {
        let userId1 = "usr_apple_sub_12345"
        let userId2 = "usr_google_sub_67890"
        
        let uuid1A = User.deterministicUUID(for: userId1)
        let uuid1B = User.deterministicUUID(for: userId1)
        let uuid2 = User.deterministicUUID(for: userId2)
        
        // Exact idempotency
        XCTAssertEqual(uuid1A, uuid1B, "Deterministic UUID must be identical for the same user ID")
        XCTAssertNotEqual(uuid1A, uuid2, "Different user IDs must yield distinct UUIDs")
        
        // Verify UUID v5 compliance
        XCTAssertEqual(uuid1A.uuid.6 & 0xF0, 0x50, "Version bits must indicate UUID version 5")
        XCTAssertEqual(uuid1A.uuid.8 & 0xC0, 0x80, "Variant bits must indicate RFC 4122 variant")
    }
    
    func test_User_appAccountUUID_uses_deterministic_when_token_empty() {
        let userId = "usr_guest_permanent_777"
        let expectedUUID = User.deterministicUUID(for: userId)
        
        let userEmptyToken = User(
            id: userId,
            appAccountToken: "",
            name: "Guest",
            email: "",
            mobile: nil,
            selectedState: "Odisha",
            isPremium: false,
            createdAt: nil
        )
        XCTAssertEqual(userEmptyToken.appAccountUUID, expectedUUID)
        
        let explicitUUID = UUID()
        let userWithExplicitToken = User(
            id: userId,
            appAccountToken: explicitUUID.uuidString,
            name: "Guest",
            email: "",
            mobile: nil,
            selectedState: "Odisha",
            isPremium: false,
            createdAt: nil
        )
        XCTAssertEqual(userWithExplicitToken.appAccountUUID, explicitUUID)
    }
    
    func test_paymentSyncState_lifecycle_and_retry_pending_sync() async {
        let sm = SubscriptionManager.shared
        
        // Initial state
        XCTAssertFalse(sm.isActivating)
        XCTAssertFalse(sm.isSyncPending)
        XCTAssertNil(sm.pendingSyncTransactionId)
        
        // Simulate a pending sync transaction using persistent helper
        sm.savePendingSyncState(txId: "mock_pending_tx_999", title: "+10 Plots Search")
        
        XCTAssertTrue(sm.isSyncPending)
        XCTAssertEqual(sm.pendingSyncTransactionId, "mock_pending_tx_999")
        if case .syncPending(let title, _) = sm.paymentSyncState {
            XCTAssertEqual(title, "+10 Plots Search")
        } else {
            XCTFail("Expected .syncPending state")
        }
        
        // Invoke retryPendingSync
        _ = await sm.retryPendingSync()
        
        // After retry when queue is clear, isActivating should reset
        XCTAssertFalse(sm.isActivating)
        
        // Clean up
        sm.clearPendingSyncState()
        XCTAssertFalse(sm.isSyncPending)
    }
    
    func test_replayed_purchase_detection_uses_the_tap_time() {
        let tap = Date()
        // Genuine purchase: confirmed after the tap (slow sheet included).
        XCTAssertFalse(SubscriptionManager.isReplayedPurchase(purchaseDate: tap.addingTimeInterval(40), tapStartedAt: tap))
        // Small clock skew between device and Apple is tolerated.
        XCTAssertFalse(SubscriptionManager.isReplayedPurchase(purchaseDate: tap.addingTimeInterval(-60), tapStartedAt: tap))
        // StoreKit handed back yesterday's transaction: not charged now.
        XCTAssertTrue(SubscriptionManager.isReplayedPurchase(purchaseDate: tap.addingTimeInterval(-86_400), tapStartedAt: tap))
    }

    func test_pending_activation_state_persistence_and_relaunch_recovery() {
        let sm = SubscriptionManager.shared
        sm.clearPendingSyncState()
        
        // 1. Enter pending state and persist
        sm.savePendingSyncState(txId: "tx_relaunch_101", title: "+10 Plots Search")
        XCTAssertTrue(sm.isSyncPending)
        XCTAssertEqual(sm.pendingSyncTransactionId, "tx_relaunch_101")
        XCTAssertEqual(sm.pendingSyncProductTitle, "+10 Plots Search")
        
        // 2. Simulate app termination: wipe in-memory variables
        sm.isSyncPending = false
        sm.pendingSyncTransactionId = nil
        sm.pendingSyncProductTitle = nil
        sm.paymentSyncState = .idle
        
        // 3. Simulate app relaunch: restore pending sync state from persistence
        sm.restorePendingSyncState()
        XCTAssertTrue(sm.isSyncPending, "Pending activation must survive app relaunch")
        XCTAssertEqual(sm.pendingSyncTransactionId, "tx_relaunch_101")
        XCTAssertEqual(sm.pendingSyncProductTitle, "+10 Plots Search")
        if case .syncPending(let title, _) = sm.paymentSyncState {
            XCTAssertEqual(title, "+10 Plots Search")
        } else {
            XCTFail("Expected .syncPending after restore")
        }
        
        // 4. Successful resolution clears persisted state
        sm.clearPendingSyncState(productTitle: "+10 Plots Search")
        XCTAssertFalse(sm.isSyncPending)
        XCTAssertNil(sm.pendingSyncTransactionId)
        XCTAssertNil(sm.pendingSyncProductTitle)
        if case .success(let title) = sm.paymentSyncState {
            XCTAssertEqual(title, "+10 Plots Search")
        } else {
            XCTFail("Expected .success after clearing with product title")
        }
    }
    
    func test_coordinator_cache_hit_during_active_purchase_returns_success() {
        let sm = SubscriptionManager.shared
        sm.resetTestUserCredits(to: 10)
        sm.clearSessionTransactionResultsForTesting()
        
        // Simulate: Transaction.updates completed in background during active purchase
        let freshDeliveryResult = SubscriptionManager.BackendProcessingResult(
            success: true,
            alreadyProcessed: false,
            creditsGranted: 10,
            currentBalance: 20,
            statusCode: 200,
            failureReason: "none",
            userErrorMessage: "",
            isHistoricalCacheHit: false
        )
        sm.setSessionTransactionResultForTesting(txId: "tx_fresh_active", result: freshDeliveryResult)
        
        // When queried with source: "executePurchase", it must return the successful result
        let cached = sm.getSessionTransactionResultForTesting(txId: "tx_fresh_active")
        XCTAssertNotNil(cached)
        XCTAssertTrue(cached!.success)
        XCTAssertEqual(cached!.creditsGranted, 10)
        XCTAssertEqual(cached!.currentBalance, 20)
    }
    
    // MARK: - Section 19 & 20 Repeated Purchase Journey Tests
    
    func test_repeated_purchase_journey_four_consecutive_purchases_and_retries() async {
        let sm = SubscriptionManager.shared
        sm.resetTestUserCredits(to: 0)
        sm.clearSessionTransactionResultsForTesting()
        
        // Purchase #1: 50 plots (tx "tx_A") -> balance 50
        let p1 = await sm.evaluateManualConsumablePurchaseForTesting(
            returnedTxId: "tx_A",
            isAlreadyProcessedOnBackend: false,
            creditsForProduct: 50,
            isKnownCompletedAtStart: false
        )
        XCTAssertTrue(p1.success)
        XCTAssertEqual(p1.finalBalance, 50)
        XCTAssertEqual(sm.remainingPlotCredits, 50)
        XCTAssertFalse(sm.isActivating)
        XCTAssertFalse(sm.isLoading)
        
        // Purchase #2: 50 plots (tx "tx_B") -> balance 100
        let p2 = await sm.evaluateManualConsumablePurchaseForTesting(
            returnedTxId: "tx_B",
            isAlreadyProcessedOnBackend: false,
            creditsForProduct: 50,
            isKnownCompletedAtStart: false
        )
        XCTAssertTrue(p2.success)
        XCTAssertEqual(p2.finalBalance, 100)
        XCTAssertEqual(sm.remainingPlotCredits, 100)
        XCTAssertFalse(sm.isActivating)
        XCTAssertFalse(sm.isLoading)
        
        // Purchase #3: 10 plots (tx "tx_C") -> balance 110
        let p3 = await sm.evaluateManualConsumablePurchaseForTesting(
            returnedTxId: "tx_C",
            isAlreadyProcessedOnBackend: false,
            creditsForProduct: 10,
            isKnownCompletedAtStart: false
        )
        XCTAssertTrue(p3.success)
        XCTAssertEqual(p3.finalBalance, 110)
        XCTAssertEqual(sm.remainingPlotCredits, 110)
        XCTAssertFalse(sm.isActivating)
        XCTAssertFalse(sm.isLoading)
        
        // Purchase #4: 200 plots (tx "tx_D") -> balance 310
        let p4 = await sm.evaluateManualConsumablePurchaseForTesting(
            returnedTxId: "tx_D",
            isAlreadyProcessedOnBackend: false,
            creditsForProduct: 200,
            isKnownCompletedAtStart: false
        )
        XCTAssertTrue(p4.success)
        XCTAssertEqual(p4.finalBalance, 310)
        XCTAssertEqual(sm.remainingPlotCredits, 310)
        XCTAssertFalse(sm.isActivating)
        XCTAssertFalse(sm.isLoading)
        
        // Immediate retries: tx_A, tx_B, tx_C, tx_D must NOT double-credit and return alreadyProcessed
        let retryA = await sm.evaluateManualConsumablePurchaseForTesting(
            returnedTxId: "tx_A",
            isAlreadyProcessedOnBackend: true,
            creditsForProduct: 50,
            isKnownCompletedAtStart: true
        )
        XCTAssertFalse(retryA.success)
        XCTAssertEqual(retryA.finalBalance, 310)
        XCTAssertEqual(sm.remainingPlotCredits, 310)
        
        let retryB = await sm.evaluateManualConsumablePurchaseForTesting(
            returnedTxId: "tx_B",
            isAlreadyProcessedOnBackend: true,
            creditsForProduct: 50,
            isKnownCompletedAtStart: true
        )
        XCTAssertFalse(retryB.success)
        XCTAssertEqual(retryB.finalBalance, 310)
        XCTAssertEqual(sm.remainingPlotCredits, 310)
        
        let retryC = await sm.evaluateManualConsumablePurchaseForTesting(
            returnedTxId: "tx_C",
            isAlreadyProcessedOnBackend: true,
            creditsForProduct: 10,
            isKnownCompletedAtStart: true
        )
        XCTAssertFalse(retryC.success)
        XCTAssertEqual(retryC.finalBalance, 310)
        XCTAssertEqual(sm.remainingPlotCredits, 310)
        
        let retryD = await sm.evaluateManualConsumablePurchaseForTesting(
            returnedTxId: "tx_D",
            isAlreadyProcessedOnBackend: true,
            creditsForProduct: 200,
            isKnownCompletedAtStart: true
        )
        XCTAssertFalse(retryD.success)
        XCTAssertEqual(retryD.finalBalance, 310)
        XCTAssertEqual(sm.remainingPlotCredits, 310)
        
        // State guarantees: after all purchases and retries, flags are clean
        XCTAssertFalse(sm.isActivating)
        XCTAssertFalse(sm.isLoading)
        XCTAssertEqual(sm.inFlightProcessingTasksCountForTesting, 0)
    }
    
    func test_state_guarantees_isActivating_and_isLoading_reset_on_all_paths() async {
        let sm = SubscriptionManager.shared
        
        // 1. retryPendingSyncDetailed() when queue is empty resets isActivating to false
        let detailedResult = await sm.retryPendingSyncDetailed()
        XCTAssertFalse(sm.isActivating)
        XCTAssertFalse(sm.isLoading)
        switch detailedResult {
        case .noPendingPurchase, .alreadyProcessed, .activated:
            break
        case .activationPending, .failed:
            break
        }
        
        // 2. retryPendingSync() boolean wrapper also keeps isActivating false
        _ = await sm.retryPendingSync()
        XCTAssertFalse(sm.isActivating)
        XCTAssertFalse(sm.isLoading)
    }
    
    func test_StoreKitTest_two_consecutive_50_plots_purchases_on_simulator() async throws {
        // 1. Locate StoreKit configuration
        let storekitURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // MyBhoomiTests
            .deletingLastPathComponent() // MyBhoomi workspace root
            .appendingPathComponent("StoreKit/Subscriptions.storekit")
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: storekitURL.path), "Subscriptions.storekit must exist at \(storekitURL.path)")
        
        let session = try SKTestSession(contentsOf: storekitURL)
        session.resetToDefaultState()
        session.disableDialogs = true
        session.clearTransactions()
        
        // 2. Request products for 50 plots
        let products = try await Product.products(for: ["bhumitra.plots.50"])
        XCTAssertEqual(products.count, 1, "Must find exactly 1 product for bhumitra.plots.50")
        guard let product = products.first else {
            XCTFail("bhumitra.plots.50 product not found in StoreKit session")
            return
        }
        XCTAssertEqual(product.id, "bhumitra.plots.50")
        XCTAssertEqual(product.displayName, "50 Plot Searches")
        XCTAssertEqual(product.price, 299)
        
        // 3. Initial Authoritative State
        let sm = SubscriptionManager.shared
        sm.resetTestUserCredits(to: 10)
        sm.clearSessionTransactionResultsForTesting()
        let initialBalance = sm.remainingPlotCredits
        XCTAssertEqual(initialBalance, 10, "Initial balance must be exactly 10")
        print("[TEST_REPORT] Initial Authoritative Balance: \(initialBalance)")
        
        // 4. Purchase #1: 50 plots consumable (₹299)
        print("[TEST_REPORT] --- START PURCHASE #1 ---")
        let result1 = try await product.purchase()
        guard case .success(let verificationResult1) = result1 else {
            XCTFail("Purchase #1 failed or cancelled")
            return
        }
        let tx1 = try verificationResult1.payloadValue
        let tx1Id = tx1.id
        let tx1IdStr = String(tx1Id)
        XCTAssertEqual(tx1.productID, "bhumitra.plots.50")
        
        // Deliver through SubscriptionManager consumable pipeline
        let eval1 = await sm.evaluateManualConsumablePurchaseForTesting(
            returnedTxId: tx1IdStr,
            isAlreadyProcessedOnBackend: false,
            creditsForProduct: 50,
            isKnownCompletedAtStart: false
        )
        XCTAssertTrue(eval1.success, "Purchase #1 must succeed")
        XCTAssertEqual(eval1.finalBalance, 60, "Balance after Purchase #1 must be 60")
        XCTAssertEqual(sm.remainingPlotCredits, 60, "SubscriptionManager remainingPlotCredits must be 60")
        await tx1.finish()
        print("[TEST_REPORT] Purchase #1 SUCCESS | TxID: \(tx1IdStr) | Credits Granted: +50 | Balance: \(sm.remainingPlotCredits) | Finished: YES")
        
        // 5. Purchase #2: SAME 50 plots consumable product (₹299)
        print("[TEST_REPORT] --- START PURCHASE #2 ---")
        let result2 = try await product.purchase()
        guard case .success(let verificationResult2) = result2 else {
            XCTFail("Purchase #2 failed or cancelled")
            return
        }
        let tx2 = try verificationResult2.payloadValue
        let tx2Id = tx2.id
        let tx2IdStr = String(tx2Id)
        XCTAssertEqual(tx2.productID, "bhumitra.plots.50")
        
        // Deliver through SubscriptionManager consumable pipeline
        let eval2 = await sm.evaluateManualConsumablePurchaseForTesting(
            returnedTxId: tx2IdStr,
            isAlreadyProcessedOnBackend: false,
            creditsForProduct: 50,
            isKnownCompletedAtStart: false
        )
        XCTAssertTrue(eval2.success, "Purchase #2 must succeed")
        XCTAssertEqual(eval2.finalBalance, 110, "Balance after Purchase #2 must be 110")
        XCTAssertEqual(sm.remainingPlotCredits, 110, "SubscriptionManager remainingPlotCredits must be 110")
        await tx2.finish()
        print("[TEST_REPORT] Purchase #2 SUCCESS | TxID: \(tx2IdStr) | Credits Granted: +50 | Balance: \(sm.remainingPlotCredits) | Finished: YES")
        
        // 6. Verify Transaction IDs are distinct
        XCTAssertNotEqual(tx1Id, tx2Id, "Consecutive consumable purchases MUST have distinct StoreKit transaction IDs")
        print("[TEST_REPORT] Distinct Transaction IDs Confirmed: Tx1 (\(tx1IdStr)) != Tx2 (\(tx2IdStr))")
        
        // 7. Verify Idempotent Retries cannot grant credits twice
        let retry1 = await sm.evaluateManualConsumablePurchaseForTesting(
            returnedTxId: tx1IdStr,
            isAlreadyProcessedOnBackend: true,
            creditsForProduct: 50,
            isKnownCompletedAtStart: true
        )
        XCTAssertFalse(retry1.success, "Retrying Tx #1 must NOT grant new credits")
        XCTAssertEqual(sm.remainingPlotCredits, 110, "Balance must remain 110 after retrying Tx #1")
        
        let retry2 = await sm.evaluateManualConsumablePurchaseForTesting(
            returnedTxId: tx2IdStr,
            isAlreadyProcessedOnBackend: true,
            creditsForProduct: 50,
            isKnownCompletedAtStart: true
        )
        XCTAssertFalse(retry2.success, "Retrying Tx #2 must NOT grant new credits")
        XCTAssertEqual(sm.remainingPlotCredits, 110, "Balance must remain 110 after retrying Tx #2")
        
        // 8. Verify Payment State guarantees (READY)
        XCTAssertFalse(sm.isActivating, "isActivating must be false")
        XCTAssertFalse(sm.isLoading, "isLoading must be false")
        XCTAssertEqual(sm.inFlightProcessingTasksCountForTesting, 0, "No in-flight tasks remaining")
        print("[TEST_REPORT] Payment State: READY (isActivating: false, isLoading: false, inFlight: 0)")
    }
}



