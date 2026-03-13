import Foundation

public struct AppConfig {
    public static let defaultLatitude = 21.6289
    public static let defaultLongitude = 85.5817
    
    public static var pmtilesPath: String {
        // Use the smaller, optimized Keonjhar-only file
        if let bundlePath = Bundle.main.path(forResource: "Keonjhar_Cadastrals", ofType: "pmtiles") {
            return bundlePath
        }
        // Fallback for development (using bundle-relative path empty if not found)
        return ""
    }
}
