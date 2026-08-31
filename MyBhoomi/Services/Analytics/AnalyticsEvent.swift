import Foundation

// MARK: - Strongly Typed Analytics Event Taxonomy (31 Events)

public enum AnalyticsEvent {
    // MARK: - Group A: Authentication & Onboarding (10 Events)
    case appOpened(appVersion: String, buildNumber: String, deviceModel: String, osVersion: String)
    case authScreenViewed(triggerSource: String)
    case loginStarted(provider: AnalyticsAuthProvider)
    case loginCompleted(provider: AnalyticsAuthProvider, isNewUser: Bool)
    case loginFailed(provider: AnalyticsAuthProvider, errorCategory: AnalyticsErrorCategory)
    case guestSessionStarted(triggerSource: String)
    case accountLinkStarted(provider: AnalyticsAuthProvider)
    case accountLinkCompleted(provider: AnalyticsAuthProvider)
    case logoutCompleted(previousProvider: AnalyticsAuthProvider)
    case accountDeleted(accountType: AnalyticsAccountType)
    case onboardingStarted(source: String)
    case onboardingCompleted(durationSeconds: Int)
    
    // MARK: - Group B: Land Search & Verification Funnel (6 Events)
    case landSearchStarted(searchMethod: AnalyticsSearchMethod, districtID: String, tehsilID: String)
    case landSearchSubmitted(searchMethod: AnalyticsSearchMethod, districtID: String, tehsilID: String)
    case landSearchSucceeded(
        searchMethod: AnalyticsSearchMethod,
        districtID: String,
        tehsilID: String,
        resultStatus: AnalyticsSearchResultStatus,
        latencyMs: Int,
        cacheHit: Bool,
        isGovernmentLand: Bool
    )
    case landSearchFailed(
        searchMethod: AnalyticsSearchMethod,
        districtID: String,
        latencyMs: Int,
        errorCategory: AnalyticsErrorCategory
    )
    case landSearchEmpty(searchMethod: AnalyticsSearchMethod, districtID: String, tehsilID: String)
    case landRecordSuccessfullyViewed(
        districtID: String,
        isGovernmentLand: Bool,
        ownerCount: Int,
        landClassification: String
    )
    
    // MARK: - Group C: Land Record & Detailed Interactions (2 Events)
    case landRecordViewed(
        districtID: String,
        isGovernmentLand: Bool,
        ownerCount: Int,
        landClassification: String
    )
    case landRecordAction(action: AnalyticsRecordAction, districtID: String)
    
    // MARK: - Group D: Land Passport & Digital Reports (4 Events)
    case landPassportViewed(districtID: String, isGovernmentLand: Bool, ownerCount: Int)
    case bhumitraReportViewed(districtID: String)
    case bhumitraReportSaved(districtID: String)
    case bhumitraReportShared(districtID: String)
    
    // MARK: - Group E: Official RoR PDF Document Service (3 Events)
    case officialRoRDownloadStarted(districtID: String, isPrefetched: Bool)
    case officialRoRDownloadCompleted(districtID: String, latencyMs: Int, fileSizeKB: Int)
    case officialRoRDownloadFailed(districtID: String, errorCategory: AnalyticsErrorCategory)
    
    // MARK: - Group F: Plot Credits & Quota Management (3 Events)
    case plotCreditConsumed(remainingCreditBucket: String, isUnlimited: Bool)
    case creditsLowWarningShown(remainingCreditBucket: String)
    case creditsExhausted(triggerSource: String)
    
    // MARK: - Group G: Monetization & StoreKit 2 Funnel (6 Events)
    case paywallViewed(trigger: AnalyticsPaywallTrigger, remainingCreditBucket: String)
    case productSelected(productID: String, productType: String, credits: Int, price: Double)
    case purchaseStarted(productID: String, productType: String, price: Double, trigger: AnalyticsPaywallTrigger)
    case purchaseCancelled(productID: String)
    case purchaseFailed(productID: String, errorCategory: AnalyticsErrorCategory)
    case purchaseCompleted(productID: String, productType: String, creditsGranted: Int, price: Double)
    
    // MARK: - Event Name Mapping
    public var name: String {
        switch self {
        case .appOpened: return "app_opened"
        case .authScreenViewed: return "auth_screen_viewed"
        case .loginStarted: return "login_started"
        case .loginCompleted: return "login_completed"
        case .loginFailed: return "login_failed"
        case .guestSessionStarted: return "guest_session_started"
        case .accountLinkStarted: return "account_link_started"
        case .accountLinkCompleted: return "account_link_completed"
        case .logoutCompleted: return "logout_completed"
        case .accountDeleted: return "account_deleted"
        case .onboardingStarted: return "onboarding_started"
        case .onboardingCompleted: return "onboarding_completed"
            
        case .landSearchStarted: return "land_search_started"
        case .landSearchSubmitted: return "land_search_submitted"
        case .landSearchSucceeded: return "land_search_succeeded"
        case .landSearchFailed: return "land_search_failed"
        case .landSearchEmpty: return "land_search_empty"
        case .landRecordSuccessfullyViewed: return "land_record_successfully_viewed"
            
        case .landRecordViewed: return "land_record_viewed"
        case .landRecordAction: return "land_record_action"
            
        case .landPassportViewed: return "land_passport_viewed"
        case .bhumitraReportViewed: return "bhumitra_report_viewed"
        case .bhumitraReportSaved: return "bhumitra_report_saved"
        case .bhumitraReportShared: return "bhumitra_report_shared"
            
        case .officialRoRDownloadStarted: return "official_ror_download_started"
        case .officialRoRDownloadCompleted: return "official_ror_download_completed"
        case .officialRoRDownloadFailed: return "official_ror_download_failed"
            
        case .plotCreditConsumed: return "plot_credit_consumed"
        case .creditsLowWarningShown: return "credits_low_warning_shown"
        case .creditsExhausted: return "credits_exhausted"
            
        case .paywallViewed: return "paywall_viewed"
        case .productSelected: return "product_selected"
        case .purchaseStarted: return "purchase_started"
        case .purchaseCancelled: return "purchase_cancelled"
        case .purchaseFailed: return "purchase_failed"
        case .purchaseCompleted: return "purchase_completed"
        }
    }
    
    // MARK: - Standardized Non-PII Parameter Serialization
    public var parameters: [String: Any] {
        switch self {
        case .appOpened(let appVersion, let buildNumber, let deviceModel, let osVersion):
            return [
                "app_version": appVersion,
                "build_number": buildNumber,
                "device_model": deviceModel,
                "os_version": osVersion
            ]
            
        case .onboardingStarted(let source):
            return ["source": source]
            
        case .onboardingCompleted(let durationSeconds):
            return ["duration_seconds": durationSeconds]
            
        case .accountDeleted(let accountType):
            return ["account_type": accountType.rawValue]
            
        case .authScreenViewed(let triggerSource):
            return ["trigger_source": triggerSource]
            
        case .loginStarted(let provider):
            return ["provider": provider.rawValue]
            
        case .loginCompleted(let provider, let isNewUser):
            return [
                "provider": provider.rawValue,
                "is_new_user": isNewUser ? 1 : 0
            ]
            
        case .loginFailed(let provider, let errorCategory):
            return [
                "provider": provider.rawValue,
                "error_category": errorCategory.rawValue
            ]
            
        case .guestSessionStarted(let triggerSource):
            return ["trigger_source": triggerSource]
            
        case .accountLinkStarted(let provider):
            return ["provider": provider.rawValue]
            
        case .accountLinkCompleted(let provider):
            return ["provider": provider.rawValue]
            
        case .logoutCompleted(let previousProvider):
            return ["previous_provider": previousProvider.rawValue]
            
        case .landSearchStarted(let searchMethod, let districtID, let tehsilID):
            return [
                "search_method": searchMethod.rawValue,
                "district_id": districtID,
                "tehsil_id": tehsilID
            ]
            
        case .landSearchSubmitted(let searchMethod, let districtID, let tehsilID):
            return [
                "search_method": searchMethod.rawValue,
                "district_id": districtID,
                "tehsil_id": tehsilID
            ]
            
        case .landSearchSucceeded(let searchMethod, let districtID, let tehsilID, let resultStatus, let latencyMs, let cacheHit, let isGovt):
            return [
                "search_method": searchMethod.rawValue,
                "district_id": districtID,
                "tehsil_id": tehsilID,
                "result_status": resultStatus.rawValue,
                "latency_ms": latencyMs,
                "cache_hit": cacheHit ? 1 : 0,
                "is_government_land": isGovt ? 1 : 0
            ]
            
        case .landSearchFailed(let searchMethod, let districtID, let latencyMs, let errorCategory):
            return [
                "search_method": searchMethod.rawValue,
                "district_id": districtID,
                "latency_ms": latencyMs,
                "error_category": errorCategory.rawValue
            ]
            
        case .landSearchEmpty(let searchMethod, let districtID, let tehsilID):
            return [
                "search_method": searchMethod.rawValue,
                "district_id": districtID,
                "tehsil_id": tehsilID
            ]
            
        case .landRecordSuccessfullyViewed(let districtID, let isGovt, let ownerCount, let classification):
            return [
                "district_id": districtID,
                "is_government_land": isGovt ? 1 : 0,
                "owner_count": ownerCount,
                "land_classification": classification
            ]
            
        case .landRecordViewed(let districtID, let isGovt, let ownerCount, let classification):
            return [
                "district_id": districtID,
                "is_government_land": isGovt ? 1 : 0,
                "owner_count": ownerCount,
                "land_classification": classification
            ]
            
        case .landRecordAction(let action, let districtID):
            return [
                "action": action.rawValue,
                "district_id": districtID
            ]
            
        case .landPassportViewed(let districtID, let isGovt, let ownerCount):
            return [
                "district_id": districtID,
                "is_government_land": isGovt ? 1 : 0,
                "owner_count": ownerCount
            ]
            
        case .bhumitraReportViewed(let districtID):
            return ["district_id": districtID]
            
        case .bhumitraReportSaved(let districtID):
            return ["district_id": districtID]
            
        case .bhumitraReportShared(let districtID):
            return ["district_id": districtID]
            
        case .officialRoRDownloadStarted(let districtID, let isPrefetched):
            return [
                "district_id": districtID,
                "is_prefetched": isPrefetched ? 1 : 0
            ]
            
        case .officialRoRDownloadCompleted(let districtID, let latencyMs, let fileSizeKB):
            return [
                "district_id": districtID,
                "latency_ms": latencyMs,
                "file_size_kb": fileSizeKB
            ]
            
        case .officialRoRDownloadFailed(let districtID, let errorCategory):
            return [
                "district_id": districtID,
                "error_category": errorCategory.rawValue
            ]
            
        case .plotCreditConsumed(let remainingCreditBucket, let isUnlimited):
            return [
                "remaining_credit_bucket": remainingCreditBucket,
                "is_unlimited": isUnlimited ? 1 : 0
            ]
            
        case .creditsLowWarningShown(let remainingCreditBucket):
            return ["remaining_credit_bucket": remainingCreditBucket]
            
        case .creditsExhausted(let triggerSource):
            return ["trigger_source": triggerSource]
            
        case .paywallViewed(let trigger, let remainingCreditBucket):
            return [
                "trigger": trigger.rawValue,
                "remaining_credit_bucket": remainingCreditBucket
            ]
            
        case .productSelected(let productID, let productType, let credits, let price):
            return [
                "product_id": productID,
                "product_type": productType,
                "credits": credits,
                "price": price
            ]
            
        case .purchaseStarted(let productID, let productType, let price, let trigger):
            return [
                "product_id": productID,
                "product_type": productType,
                "price": price,
                "trigger": trigger.rawValue
            ]
            
        case .purchaseCancelled(let productID):
            return ["product_id": productID]
            
        case .purchaseFailed(let productID, let errorCategory):
            return [
                "product_id": productID,
                "error_category": errorCategory.rawValue
            ]
            
        case .purchaseCompleted(let productID, let productType, let creditsGranted, let price):
            return [
                "product_id": productID,
                "product_type": productType,
                "credits_granted": creditsGranted,
                "price": price
            ]
        }
    }
}
