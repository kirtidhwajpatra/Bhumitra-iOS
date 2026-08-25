//
//  RemoteConfigManager.swift
//  MyBhoomi
//
//  Remote Application Configuration Manager
//  Loads, caches, and enforces dynamic feature flags, 3-tier version compliance,
//  maintenance mode, and remote paywall configurations.
//

import Foundation
import Combine

public struct RemoteAppConfig: Codable {
    public let configVersion: Int?
    public let serverTime: String?
    public let ttlSeconds: Int?
    public let minSupportedVersion: String
    public let recommendedVersion: String?
    public let latestVersion: String
    public let forceUpdate: Bool?
    public let appStoreId: String?
    public let appStoreURL: String?
    public let maintenanceMode: Bool
    public let maintenanceMessage: String?
    public let rorEnabled: Bool?
    public let gisEnabled: Bool?
    public let subscriptionEnabled: Bool
    public let premiumEnabled: Bool
    public let mapDataVersion: String
    public let features: RemoteFeaturesConfig
    public let paywall: RemotePaywallConfig
    
    enum CodingKeys: String, CodingKey {
        case configVersion = "config_version"
        case serverTime = "server_time"
        case ttlSeconds = "ttl_seconds"
        case minSupportedVersion = "min_supported_version"
        case recommendedVersion = "recommended_version"
        case latestVersion = "latest_version"
        case forceUpdate = "force_update"
        case appStoreId = "app_store_id"
        case appStoreURL = "app_store_url"
        case maintenanceMode = "maintenance_mode"
        case maintenanceMessage = "maintenance_message"
        case rorEnabled = "ror_enabled"
        case gisEnabled = "gis_enabled"
        case subscriptionEnabled = "subscription_enabled"
        case premiumEnabled = "premium_enabled"
        case mapDataVersion = "map_data_version"
        case features
        case paywall
    }
}

public struct RemoteFeaturesConfig: Codable {
    public let advancedSearch: Bool
    public let propertyHistory: Bool
    public let valuation: Bool
    public let pdfDownload: Bool
    public let satelliteView: Bool
    
    enum CodingKeys: String, CodingKey {
        case advancedSearch = "advanced_search"
        case propertyHistory = "property_history"
        case valuation
        case pdfDownload = "pdf_download"
        case satelliteView = "satellite_view"
    }
}

public struct RemotePaywallConfig: Codable {
    public let headline: String
    public let subheadline: String
    public let defaultTier: String
    public let availableTiers: [String]
    
    enum CodingKeys: String, CodingKey {
        case headline
        case subheadline
        case defaultTier = "default_tier"
        case availableTiers = "available_tiers"
    }
}

public enum AppVersionStatus: Equatable {
    case forceUpdateRequired(minVersion: String, currentVersion: String)
    case recommendedUpdateAvailable(recommendedVersion: String, currentVersion: String)
    case upToDate(currentVersion: String)
}

@MainActor
public final class RemoteConfigManager: ObservableObject {
    public static let shared = RemoteConfigManager()
    
    // Published configuration states for the entire app
    @Published public var configVersion: Int = 1
    @Published public var ttlSeconds: Int = 3600
    @Published public var minSupportedVersion: String = "1.0.0"
    @Published public var recommendedVersion: String = "1.0.0"
    @Published public var latestVersion: String = "1.0.0"
    @Published public var forceUpdate: Bool = false
    @Published public var appStoreURL: String = "https://apps.apple.com/app/bhumitra-odisha-land-records/id6742337788"
    @Published public var maintenanceMode: Bool = false
    @Published public var maintenanceMessage: String? = nil
    @Published public var isRoREnabled: Bool = true
    @Published public var isGISEnabled: Bool = true
    @Published public var subscriptionEnabled: Bool = true
    @Published public var premiumEnabled: Bool = true
    @Published public var mapDataVersion: String = "2026-08-18"
    
    // Feature flags
    @Published public var isAdvancedSearchEnabled: Bool = true
    @Published public var isPropertyHistoryEnabled: Bool = false
    @Published public var isValuationEnabled: Bool = false
    @Published public var isPDFDownloadEnabled: Bool = true
    @Published public var isSatelliteViewEnabled: Bool = true
    
    // Dynamic Paywall copy
    @Published public var paywallHeadline: String = "Upgrade to Bhumitra Premium"
    @Published public var paywallSubheadline: String = "Unlock complete GIS tools, legal ROR ownership records, and official PDF downloads"
    @Published public var defaultPaywallTier: String = "bhumitra_premium_yearly"
    
    @Published public var isLoading: Bool = false
    @Published public var lastFetchDate: Date? = nil
    
    private let configCacheKey = "bhumitra_remote_app_config_cache"
    private let configTimestampKey = "bhumitra_remote_app_config_timestamp"
    
    private var endpoint: String {
        "\(APIConfiguration.shared.baseURL)/app-config"
    }
    
    private init() {
        // 1. Load cached config for instant offline startup
        loadCachedConfig()
        
        // 2. Refresh from backend
        Task {
            await fetchRemoteConfig()
        }
    }
    
    /// Fetches live configuration from the Bhumitra backend
    public func fetchRemoteConfig(force: Bool = false) async {
        if !force && !isCacheExpired {
            print("DEBUG: 📦 Using fresh cached Remote App Config (TTL: \(ttlSeconds)s).")
            return
        }
        
        isLoading = true
        guard let url = URL(string: endpoint) else {
            isLoading = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 8
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                isLoading = false
                return
            }
            
            let decoder = JSONDecoder()
            let config = try decoder.decode(RemoteAppConfig.self, from: data)
            
            // Apply new configuration
            applyConfig(config)
            
            // Cache locally with timestamp
            UserDefaults.standard.set(data, forKey: configCacheKey)
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: configTimestampKey)
            self.lastFetchDate = Date()
            self.isLoading = false
            print("DEBUG: 🌐 Remote App Config v\(config.configVersion ?? 1) refreshed successfully. Maintenance: \(config.maintenanceMode)")
        } catch {
            self.isLoading = false
            print("DEBUG: ⚠️ Could not fetch remote config (using cached/default): \(error.localizedDescription)")
        }
    }
    
    private var isCacheExpired: Bool {
        guard let fetchDate = lastFetchDate else { return true }
        return Date().timeIntervalSince(fetchDate) > Double(ttlSeconds)
    }
    
    private func applyConfig(_ config: RemoteAppConfig) {
        self.configVersion = config.configVersion ?? 1
        self.ttlSeconds = config.ttlSeconds ?? 3600
        self.minSupportedVersion = config.minSupportedVersion
        self.recommendedVersion = config.recommendedVersion ?? config.minSupportedVersion
        self.latestVersion = config.latestVersion
        self.forceUpdate = config.forceUpdate ?? false
        if let url = config.appStoreURL, !url.isEmpty {
            self.appStoreURL = url
        }
        self.maintenanceMode = config.maintenanceMode
        self.maintenanceMessage = config.maintenanceMessage
        self.isRoREnabled = config.rorEnabled ?? true
        self.isGISEnabled = config.gisEnabled ?? true
        self.subscriptionEnabled = config.subscriptionEnabled
        self.premiumEnabled = config.premiumEnabled
        self.mapDataVersion = config.mapDataVersion
        
        // Feature Flags
        self.isAdvancedSearchEnabled = config.features.advancedSearch
        self.isPropertyHistoryEnabled = config.features.propertyHistory
        self.isValuationEnabled = config.features.valuation
        self.isPDFDownloadEnabled = config.features.pdfDownload
        self.isSatelliteViewEnabled = config.features.satelliteView
        
        // Paywall
        self.paywallHeadline = config.paywall.headline
        self.paywallSubheadline = config.paywall.subheadline
        self.defaultPaywallTier = config.paywall.defaultTier
    }
    
    private func loadCachedConfig() {
        if let timestamp = UserDefaults.standard.object(forKey: configTimestampKey) as? Double {
            self.lastFetchDate = Date(timeIntervalSince1970: timestamp)
        }
        
        guard let data = UserDefaults.standard.data(forKey: configCacheKey) else { return }
        do {
            let decoder = JSONDecoder()
            let config = try decoder.decode(RemoteAppConfig.self, from: data)
            applyConfig(config)
            print("DEBUG: 📦 Loaded cached Remote App Config v\(config.configVersion ?? 1).")
        } catch {
            print("DEBUG: ⚠️ Error decoding cached remote config: \(error)")
        }
    }
    
    // MARK: - Version Enforcement
    
    public var currentAppVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
    
    /// Tiered 3-state evaluation: Force Update -> Recommended Update -> Up To Date
    public var versionStatus: AppVersionStatus {
        if isUpdateRequired {
            return .forceUpdateRequired(minVersion: minSupportedVersion, currentVersion: currentAppVersion)
        } else if isRecommendedUpdateAvailable {
            return .recommendedUpdateAvailable(recommendedVersion: recommendedVersion, currentVersion: currentAppVersion)
        } else {
            return .upToDate(currentVersion: currentAppVersion)
        }
    }
    
    /// True if forceUpdate flag is active OR current app version is below minimum supported version (BLOCK)
    public var isUpdateRequired: Bool {
        return forceUpdate || isVersion(currentAppVersion, olderThan: minSupportedVersion)
    }
    
    /// True if app meets minimum version and forceUpdate is not active, but is below recommended version (OPTIONAL PROMPT)
    public var isRecommendedUpdateAvailable: Bool {
        return !isUpdateRequired && isVersion(currentAppVersion, olderThan: recommendedVersion)
    }
    
    private func isVersion(_ v1: String, olderThan v2: String) -> Bool {
        let v1Parts = v1.split(separator: ".").compactMap { Int($0) }
        let v2Parts = v2.split(separator: ".").compactMap { Int($0) }
        
        let maxCount = max(v1Parts.count, v2Parts.count)
        for i in 0..<maxCount {
            let p1 = i < v1Parts.count ? v1Parts[i] : 0
            let p2 = i < v2Parts.count ? v2Parts[i] : 0
            if p1 < p2 {
                return true
            } else if p1 > p2 {
                return false
            }
        }
        return false
    }
}
