import Foundation

public struct GeoJSONParser {
    public static func parse(_ data: Data) throws -> GeoJSONFeatureCollection {
        return try JSONDecoder().decode(GeoJSONFeatureCollection.self, from: data)
    }
}
