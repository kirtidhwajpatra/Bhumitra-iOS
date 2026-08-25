//
//  APIConfiguration.swift
//  MyBhoomi
//
//  Centralized Production & Development API Endpoint Configuration
//

import Foundation

public final class APIConfiguration {
    public static let shared = APIConfiguration()
    
    /// Production API URL (Direct Render Backend)
    public static let defaultProductionURL = "https://mybhoomi-backend-prod.onrender.com/api/v1"
    
    /// Development Fallback Tunnel URL for Physical Devices in DEBUG mode
    public static let defaultLocalDevelopmentURL = "https://clerk-employer-enrollment-jeffrey.trycloudflare.com/api/v1"
    
    public static let customBaseKey = "bhumitra_custom_api_base"
    
    private init() {
        #if !DEBUG
        // In Release builds: aggressively purge any legacy or stale development overrides
        UserDefaults.standard.removeObject(forKey: Self.customBaseKey)
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
        
        // 2. Check environment variable override
        if let customBase = ProcessInfo.processInfo.environment["MYBHOOMI_API_BASE"], !customBase.isEmpty {
            let clean = customBase.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            print("[APIConfig] Environment: DEBUG (Env Override) | Base URL: \(clean)")
            return clean
        }
        
        #if targetEnvironment(simulator)
        // Simulator connects directly to localhost with zero latency
        let devURL = "http://127.0.0.1:8000/api/v1"
        print("[APIConfig] Environment: DEBUG (Simulator) | Base URL: \(devURL)")
        return devURL
        #else
        // Physical iPhone in Debug defaults to live public HTTPS tunnel:
        let devURL = Self.defaultLocalDevelopmentURL
        print("[APIConfig] Environment: DEBUG (Physical Device) | Base URL: \(devURL)")
        return devURL
        #endif
        
        #else
        // In Release builds: strictly and exclusively production Render backend
        let prodURL = Self.defaultProductionURL
        print("[APIConfig] Environment: RELEASE | Base URL: \(prodURL)")
        return prodURL
        #endif
    }
    
    #if DEBUG
    public func setCustomDebugBaseURL(_ urlString: String?) {
        if let url = urlString, !url.isEmpty {
            UserDefaults.standard.set(url, forKey: Self.customBaseKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.customBaseKey)
        }
    }
    #endif
}
