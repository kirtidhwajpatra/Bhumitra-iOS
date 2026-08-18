//
//  APIConfiguration.swift
//  MyBhoomi
//
//  Centralized Production API Endpoint & Network Configuration
//

import Foundation

public final class APIConfiguration {
    public static let shared = APIConfiguration()
    
    private init() {}
    
    /// Primary API Base URL (e.g. https://api.bhumitra.app/api/v1 or Cloud Run fallback)
    public var baseURL: String {
        if let customBase = ProcessInfo.processInfo.environment["MYBHOOMI_API_BASE"], !customBase.isEmpty {
            return customBase
        }
        #if DEBUG
        return "http://localhost:8000/api/v1"
        #else
        // Active verified Cloud Run endpoint (can be switched to https://api.bhumitra.app/api/v1 once DNS mapped)
        return "https://mybhoomi-ror-prod-667798363712.asia-south1.run.app/api/v1"
        #endif
    }
    
    /// Stable Production API Domain
    public let productionDomain = "https://api.bhumitra.app/api/v1"
}
