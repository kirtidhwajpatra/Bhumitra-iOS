import Foundation

public struct AppConfig {
    public static let defaultLatitude = 21.6289
    public static let defaultLongitude = 85.5817
    
    public static var pmtilesPath: String {
        // Full production Odisha map hosted on Google Cloud Storage
        return "https://storage.googleapis.com/mybhoomi-maps-prod-1/odisha.pmtiles"
    }
}
