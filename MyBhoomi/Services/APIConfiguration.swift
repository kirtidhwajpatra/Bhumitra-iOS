//
//  APIConfiguration.swift
//  MyBhoomi
//
//  Centralized Production & Development API Endpoint Configuration
//

import Foundation

public final class APIConfiguration {
    public static let shared = APIConfiguration()
    
    public static let defaultProductionURL = "https://captured-victory-painted-ranges.trycloudflare.com/api/v1"
    public static let defaultLocalDevelopmentURL = "https://captured-victory-painted-ranges.trycloudflare.com/api/v1"
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
        
        #if targetEnvironment(simulator)
        // Simulator connects directly to localhost with zero latency
        return "http://127.0.0.1:8000/api/v1"
        #else
        // Physical iPhone defaults to live public HTTPS tunnel:
        return Self.defaultLocalDevelopmentURL
        #endif
        
        #else
        // In Release builds: strictly HTTPS endpoint
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
