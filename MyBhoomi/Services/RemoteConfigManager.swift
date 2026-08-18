import Foundation
import Combine

public struct RemoteAppConfig: Codable {
    public let minSupportedVersion: String
    public let latestVersion: String
    public let maintenanceMode: Bool
    public let maintenanceMessage: String?
    public let subscriptionEnabled: Bool
    public let premiumEnabled: Bool
    public let mapDataVersion: String
    public let features: RemoteFeaturesConfig
    public let paywall: RemotePaywallConfig
    
    enum CodingKeys: String, CodingKey {
        case minSupportedVersion = "min_supported_version"
        case latestVersion = "latest_version"
        case maintenanceMode = "maintenance_mode"
        case maintenanceMessage = "maintenance_message"
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

@MainActor
public final class RemoteConfigManager: ObservableObject {
    public static let shared = RemoteConfigManager()
    
    // Published configuration states for the entire app
    @Published public var minSupportedVersion: String = "1.0.0"
    @Published public var latestVersion: String = "1.0.0"
    @Published public var maintenanceMode: Bool = false
    @Published public var maintenanceMessage: String? = nil
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
    private let endpoint = "https://mybhoomi-ror-prod-667798363712.asia-south1.run.app/api/v1/app-config"
    
    private init() {
        // Load cached config for instant startup
        loadCachedConfig()
        
        // Refresh from backend asynchronously
        Task {
            await fetchRemoteConfig()
        }
    }
    
    /// Fetches live configuration from the Bhumitra backend
    public func fetchRemoteConfig() async {
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
            
            // Cache locally
            UserDefaults.standard.set(data, forKey: configCacheKey)
            self.lastFetchDate = Date()
            self.isLoading = false
            print("DEBUG: 🌐 Remote App Config refreshed successfully. Subscription Enabled: \(config.subscriptionEnabled)")
        } catch {
            self.isLoading = false
            print("DEBUG: ⚠️ Could not fetch remote config (using cached/default): \(error.localizedDescription)")
        }
    }
    
    private func applyConfig(_ config: RemoteAppConfig) {
        self.minSupportedVersion = config.minSupportedVersion
        self.latestVersion = config.latestVersion
        self.maintenanceMode = config.maintenanceMode
        self.maintenanceMessage = config.maintenanceMessage
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
        guard let data = UserDefaults.standard.data(forKey: configCacheKey) else { return }
        do {
            let decoder = JSONDecoder()
            let config = try decoder.decode(RemoteAppConfig.self, from: data)
            applyConfig(config)
            print("DEBUG: 📦 Loaded cached Remote App Config.")
        } catch {
            print("DEBUG: ⚠️ Error decoding cached remote config: \(error)")
        }
    }
    
    // MARK: - Version Enforcement
    
    /// Checks if current app version is below the minimum required version
    public var isUpdateRequired: Bool {
        guard let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else {
            return false
        }
        return currentVersion.compare(minSupportedVersion, options: .numeric) == .orderedAscending
    }
}
