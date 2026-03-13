import CoreLocation

public extension Coordinate {
    var clLocation: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }
    
    /// Converts Web Mercator (EPSG:3857) meters to WGS84 (EPSG:4326) degrees
    static func fromWebMercator(x: Double, y: Double) -> Coordinate {
        let lon = (x / 20037508.34) * 180.0
        var lat = (y / 20037508.34) * 180.0
        lat = 180.0 / .pi * (2.0 * atan(exp(lat * .pi / 180.0)) - .pi / 2.0)
        return Coordinate(latitude: lat, longitude: lon)
    }
}
