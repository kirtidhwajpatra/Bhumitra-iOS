//
//  APIConfiguration.swift
//  MyBhoomi
//
//  Centralized Production & Development API Endpoint Configuration
//

import Foundation

public final class APIConfiguration {
    public static let shared = APIConfiguration()
    
    public static let defaultProductionURL = "https://mybhoomi-backend-prod-758542001999.asia-south1.run.app/api/v1"
    public static let defaultLocalDevelopmentURL = "http://10.83.80.242:8000/api/v1"
    public static let customBaseKey = "bhumitra_custom_api_base"
    
    private init() {}
    
    /// Primary API Base URL
    public var baseURL: String {
        #if DEBUG
        // 1. Check user-configured override in debug mode
        if let userCustom = UserDefaults.standard.string(forKey: Self.customBaseKey), !userCustom.isEmpty {
            return userCustom.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }
        
        // 2. Check environment variable override
        if let customBase = ProcessInfo.processInfo.environment["MYBHOOMI_API_BASE"], !customBase.isEmpty {
            return customBase.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }
        
        // 3. Physical iPhone vs Simulator in DEBUG:
        #if targetEnvironment(simulator)
        return "http://localhost:8000/api/v1"
        #else
        // On physical iPhone in DEBUG, default to Mac's local network IP where backend runs
        return Self.defaultLocalDevelopmentURL
        #endif
        
        #else
        // In Release builds: strictly HTTPS production endpoint
        return Self.defaultProductionURL
        #endif
    }
    
    /// Stable Production API Domain
    public let productionDomain = "https://api.bhumitra.app/api/v1"
    
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
