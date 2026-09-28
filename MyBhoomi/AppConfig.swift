import Foundation

public struct AppConfig {
    public static let defaultLatitude = 21.6289
    public static let defaultLongitude = 85.5817
    
    /// Official Default Focus Area (Keonjhar, Odisha)
    public static let defaultStateCode = "OD"
    public static let defaultDistrictID = "224" // Keonjhar
    
    /// Feature Flag: Bihar Cadastral GIS
    /// Strictly disabled across all environments and configurations.
    public static let biharGisFeatureEnabled: Bool = false
    
    /// Feature Flag: Map-Based Odisha GIS Explorer
    /// Enables the optional Apple Maps-style visual hierarchy navigation.
    public static var gisNavigationEnabled: Bool {
        #if DEBUG
        UserDefaults.standard.object(forKey: "gis_navigation_enabled") as? Bool ?? true
        #else
        UserDefaults.standard.object(forKey: "gis_navigation_enabled") as? Bool ?? false
        #endif
    }
    
    /// Feature Flag: Backend Environment on Physical Devices
    /// When set to true, physical devices in DEBUG connect directly to the HTTPS AWS production backend (https://api.prettyplot.in/api/v1).
    /// When false, physical devices connect to the local development Mac on the LAN.
    public static let useProductionBackendOnDevice: Bool = true
}
