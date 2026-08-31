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
}
