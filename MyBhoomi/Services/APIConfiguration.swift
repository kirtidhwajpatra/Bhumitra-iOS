//
//  APIConfiguration.swift
//  MyBhoomi
//
//  Centralized Production & Development API Endpoint Configuration
//

import Foundation

public final class APIConfiguration {
    public static let shared = APIConfiguration()
    
    /// Production API URL (AWS EC2 Elastic IP Backend)
    public static let defaultProductionURL = "http://15.206.103.113/api/v1"
    
    /// Development Server URL for Physical Devices in DEBUG mode (Active AWS EC2 24/7 Cloud Backend)
    public static let defaultLocalDevelopmentURL = "http://15.206.103.113/api/v1"
    
    /// Explicit AWS Testing Backend URL for Physical Devices in DEBUG mode
    public static let awsTestingURL = "http://15.206.103.113/api/v1"
    
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
            print("[APIConfig] Environment: DEBUG (Custom Override) | Base URL: \(clean)")
            return clean
        }
        
        // 2. Check explicit AWS testing override in UserDefaults
        if UserDefaults.standard.bool(forKey: Self.useAWSTestingKey) {
            print("[APIConfig] Environment: DEBUG (AWS Testing Override) | Base URL: \(Self.awsTestingURL)")
            return Self.awsTestingURL
        }
        
        // 3. Check environment variable overrides
        if let customBase = ProcessInfo.processInfo.environment["MYBHOOMI_API_BASE"], !customBase.isEmpty {
            let clean = customBase.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            print("[APIConfig] Environment: DEBUG (Env Override) | Base URL: \(clean)")
            return clean
        }
        
        if ProcessInfo.processInfo.environment["USE_AWS_BACKEND"] == "1" || ProcessInfo.processInfo.environment["USE_AWS_BACKEND"] == "true" {
            print("[APIConfig] Environment: DEBUG (USE_AWS_BACKEND Env) | Base URL: \(Self.awsTestingURL)")
            return Self.awsTestingURL
        }
        
        #if targetEnvironment(simulator)
        let devURL = "http://127.0.0.1:8000/api/v1"
        print("[APIConfig] Environment: DEBUG (Simulator) | Base URL: \(devURL)")
        return devURL
        #else
        let devURL = Self.defaultLocalDevelopmentURL
        print("[APIConfig] Environment: DEBUG (Physical Device) | Base URL: \(devURL)")
        return devURL
        #endif
        
        #else
        // In Release builds: strictly and exclusively production AWS backend
        let prodURL = Self.defaultProductionURL
        print("[APIConfig] Environment: RELEASE | Base URL: \(prodURL)")
        return prodURL
        #endif
    }
    
    #if DEBUG
    public func setUseAWSTesting(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: Self.useAWSTestingKey)
        print("[APIConfig] AWS Testing Override set to: \(enabled)")
    }
    
    public func switchToAWSBackend() {
        setUseAWSTesting(true)
    }
    
    public func switchToLocalDevelopment() {
        UserDefaults.standard.removeObject(forKey: Self.customBaseKey)
        UserDefaults.standard.removeObject(forKey: Self.useAWSTestingKey)
        print("[APIConfig] Reset to default local development configuration")
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
