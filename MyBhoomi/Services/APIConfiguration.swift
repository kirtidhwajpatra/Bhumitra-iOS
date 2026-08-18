//
//  APIConfiguration.swift
//  MyBhoomi
//
//  Centralized Production & Development API Endpoint Configuration
//

import Foundation

public final class APIConfiguration {
    public static let shared = APIConfiguration()
    
    public static let defaultProductionURL = "https://mybhoomi-ror-prod-667798363712.asia-south1.run.app/api/v1"
    public static let customBaseKey = "bhumitra_custom_api_base"
    
    private init() {}
    
    /// Primary API Base URL
    public var baseURL: String {
        #if DEBUG
        // 1. Check user-configured override in debug mode (e.g. from debug panel or settings)
        if let userCustom = UserDefaults.standard.string(forKey: Self.customBaseKey), !userCustom.isEmpty {
            return userCustom.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }
        
        // 2. Check environment variable override
        if let customBase = ProcessInfo.processInfo.environment["MYBHOOMI_API_BASE"], !customBase.isEmpty {
            return customBase.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }
        
        // 3. Physical iPhone vs Simulator in DEBUG:
        // On physical devices, localhost fails. Default to live HTTPS Cloud Run backend
        // while allowing LAN IP overrides.
        #if targetEnvironment(simulator)
        return "http://localhost:8000/api/v1"
        #else
        return Self.defaultProductionURL
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
