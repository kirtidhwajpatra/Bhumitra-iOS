import Foundation

public struct AppConfig {
    public static let defaultLatitude = 21.6289
    public static let defaultLongitude = 85.5817
    
    public static var pmtilesPath: String {
        // 1. Try to find the local full dataset in the Simulator's host Downloads folder
        #if targetEnvironment(simulator)
        let homeDir = NSHomeDirectory()
        let components = homeDir.components(separatedBy: "/")
        if components.count > 3 && components[1] == "Users" {
            let username = components[2]
            let downloadsPath = "/Users/\(username)/Downloads/Odisha4kgeo_OD_Cadastrals-part0000.pmtiles"
            if FileManager.default.fileExists(atPath: downloadsPath) {
                print("DEBUG: 🗺️ Using full Odisha PMTiles from Downloads folder: \(downloadsPath)")
                return downloadsPath
            }
        }
        #endif
        
        // 2. Try to find the bundled Keonjhar dataset
        if let bundlePath = Bundle.main.path(forResource: "Keonjhar_Cadastrals", ofType: "pmtiles") {
            if FileManager.default.fileExists(atPath: bundlePath) {
                print("DEBUG: 🗺️ Using bundled Keonjhar PMTiles: \(bundlePath)")
                return bundlePath
            }
        }
        
        // 3. Fallback to production URL (which requires active GCS billing)
        print("DEBUG: 🗺️ Falling back to remote GCS PMTiles (requires active billing)")
        return "https://storage.googleapis.com/mybhoomi-maps-prod-1/odisha.pmtiles"
    }
}
