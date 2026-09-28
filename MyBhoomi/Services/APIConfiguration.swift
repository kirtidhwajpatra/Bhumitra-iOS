//
//  APIConfiguration.swift
//  MyBhoomi
//
//  Centralized Production & Development API Endpoint Configuration
//

import Foundation

public final class APIConfiguration {
    public static let shared = APIConfiguration()
    
    /// Production API URL (Production AWS EC2 Backend over HTTPS)
    public static let finalProductionHTTPSURL = "https://api.prettyplot.in/api/v1"
    
    /// Production API URL
    public static let defaultProductionURL = "https://api.prettyplot.in/api/v1"
    
    /// Development Server URL for Local Development & Simulators
    public static let defaultLocalDevelopmentURL = "http://127.0.0.1:8000/api/v1"
    
    /// AWS Production Backend URL
    public static let awsTestingURL = "https://api.prettyplot.in/api/v1"
    
    public static let customBaseKey = "bhumitra_custom_api_base"
    public static let useAWSTestingKey = "bhumitra_use_aws_testing"
    
    private init() {
        #if !DEBUG
        // In Release builds: aggressively purge any legacy or stale development overrides
        UserDefaults.standard.removeObject(forKey: Self.customBaseKey)
        UserDefaults.standard.removeObject(forKey: Self.useAWSTestingKey)
        #endif
    }
    
    /// Primary API Base URL
    public var baseURL: String {
        #if DEBUG
        // 1. Check user-configured override in debug mode
        if let userCustom = UserDefaults.standard.string(forKey: Self.customBaseKey), !userCustom.isEmpty {
            let clean = userCustom.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            debugLog("[APIConfig] Environment: DEBUG (Custom Override) | Base URL: \(clean)")
            return clean
        }
        
        // 2. Check explicit AWS testing override in UserDefaults
        if UserDefaults.standard.bool(forKey: Self.useAWSTestingKey) {
            debugLog("[APIConfig] Environment: DEBUG (AWS Testing Override) | Base URL: \(Self.awsTestingURL)")
            return Self.awsTestingURL
        }
        
        // 3. Check environment variable overrides
        if let customBase = ProcessInfo.processInfo.environment["MYBHOOMI_API_BASE"], !customBase.isEmpty {
            let clean = customBase.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            debugLog("[APIConfig] Environment: DEBUG (Env Override) | Base URL: \(clean)")
            return clean
        }
        
        if ProcessInfo.processInfo.environment["USE_AWS_BACKEND"] == "1" || ProcessInfo.processInfo.environment["USE_AWS_BACKEND"] == "true" {
            debugLog("[APIConfig] Environment: DEBUG (USE_AWS_BACKEND Env) | Base URL: \(Self.awsTestingURL)")
            return Self.awsTestingURL
        }
        
        #if targetEnvironment(simulator)
        let devURL = Self.defaultLocalDevelopmentURL
        debugLog("[APIConfig] Environment: DEBUG (Simulator) | Base URL: \(devURL)")
        return devURL
        #else
        // Physical Device in DEBUG:
        if AppConfig.useProductionBackendOnDevice {
            debugLog("[APIConfig] Environment: DEBUG (Physical Device -> Production AWS) | Base URL: \(Self.defaultProductionURL)")
            return Self.defaultProductionURL
        }
        // Must NEVER connect to 127.0.0.1 (which resolves to the iPhone hardware itself).
        // Connects to the active local development server on the Mac via LAN IP.
        let devURL = "http://10.138.60.242:8000/api/v1"
        debugLog("[APIConfig] Environment: DEBUG (Physical Device) | Base URL: \(devURL)")
        return devURL
        #endif
        
        #else
        // In Release builds: strictly and exclusively production AWS backend
        let prodURL = Self.defaultProductionURL
        debugLog("[APIConfig] Environment: RELEASE | Base URL: \(prodURL)")
        return prodURL
        #endif
    }
    
    #if DEBUG
    public func setUseAWSTesting(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: Self.useAWSTestingKey)
        debugLog("[APIConfig] AWS Testing Override set to: \(enabled)")
    }
    
    public func switchToAWSBackend() {
        setUseAWSTesting(true)
    }
    
    public func switchToLocalDevelopment() {
        UserDefaults.standard.removeObject(forKey: Self.customBaseKey)
        UserDefaults.standard.removeObject(forKey: Self.useAWSTestingKey)
        debugLog("[APIConfig] Reset to default local development configuration")
    }
    
    public func setCustomDebugBaseURL(_ urlString: String?) {
        if let url = urlString, !url.isEmpty {
            UserDefaults.standard.set(url, forKey: Self.customBaseKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.customBaseKey)
        }
    }
    #endif
}
