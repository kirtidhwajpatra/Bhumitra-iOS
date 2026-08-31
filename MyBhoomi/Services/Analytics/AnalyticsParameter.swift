import Foundation

// MARK: - Controlled Error Categories

public enum AnalyticsErrorCategory: String {
    case cancelled = "cancelled"
    case network = "network"
    case providerError = "provider_error"
    case configuration = "configuration"
    case backendError = "backend_error"
    case invalidToken = "invalid_token"
    case timeout = "timeout"
    case upstreamError = "upstream_error"
    case parseError = "parse_error"
    case unknown = "unknown"
}

// MARK: - Land Search Method

public enum AnalyticsSearchMethod: String {
    case mapTap = "map_tap"
    case dropdownManual = "dropdown_manual"
    case uniqueID = "unique_id"
    case khataSearch = "khata_search"
}

// MARK: - Search Result Status

public enum AnalyticsSearchResultStatus: String {
    case verifiedPrivate = "verified_private"
    case verifiedGovernment = "verified_government"
    case notFound = "not_found"
    case error = "error"
}

// MARK: - Land Record Action

public enum AnalyticsRecordAction: String {
    case ownerDetails = "owner_details"
    case extent = "extent"
    case classification = "classification"
    case associatedPlots = "associated_plots"
    case officialRoR = "official_ror"
    case share = "share"
    case save = "save"
}

// MARK: - Paywall Triggers

public enum AnalyticsPaywallTrigger: String {
    case creditsExhausted = "credits_exhausted"
    case creditsLow = "credits_low"
    case manualOpen = "manual_open"
    case featureLocked = "feature_locked"
    case other = "other"
}

// MARK: - Auth Provider

public enum AnalyticsAuthProvider: String {
    case apple = "apple"
    case google = "google"
    case guest = "guest"
    case none = "none"
}

// MARK: - Account Type

public enum AnalyticsAccountType: String {
    case guest = "guest"
    case authenticated = "authenticated"
    case premium = "premium"
}

// MARK: - Credit Bucket Helper

public enum AnalyticsCreditBucket {
    public static func bucket(for count: Int, isUnlimited: Bool) -> String {
        if isUnlimited {
            return "50+"
        }
        switch count {
        case ...0:
            return "0"
        case 1...3:
            return "1-3"
        case 4...10:
            return "4-10"
        case 11...50:
            return "11-50"
        default:
            return "50+"
        }
    }
}
