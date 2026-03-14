import Foundation

public final class GeoJSONService {
    public init() {}
    
    public func loadParcels(fromFileName name: String) async throws -> [Parcel] {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json") else { return [] }
        let data = try Data(contentsOf: url)
        let collection = try JSONDecoder().decode(GeoJSONFeatureCollection.self, from: data)
        return try mapToDomain(collection: collection)
    }
    
    private func mapToDomain(collection: GeoJSONFeatureCollection) throws -> [Parcel] {
        return collection.features.compactMap { feature in
            guard let geometry = feature.geometry else { return nil }
            
            let coords: [Coordinate]
            switch geometry {
            case .polygon(let rings):
                guard let firstRing = rings.first else { return nil }
                coords = firstRing.compactMap { point -> Coordinate? in
                    guard point.count >= 2 else { return nil }
                    return Coordinate(latitude: point[1], longitude: point[0])
                }
            case .multiPolygon(let multipolys):
                guard let firstPoly = multipolys.first?.first else { return nil }
                coords = firstPoly.compactMap { point -> Coordinate? in
                    guard point.count >= 2 else { return nil }
                    return Coordinate(latitude: point[1], longitude: point[0])
                }
            }
            
            let properties = feature.properties ?? [:]
            let metadata = ParcelMetadata(
                plotNumber: properties["plot_number"]?.stringValue ?? "N/A",
                area: properties["area"]?.doubleValue ?? 0.0,
                areaUnit: properties["area_unit"]?.stringValue ?? "sqm",
                ownerName: properties["owner"]?.stringValue,
                landUseType: properties["land_use"]?.stringValue
            )
            return Parcel(id: properties["id"]?.stringValue ?? UUID().uuidString, boundary: coords, metadata: metadata)
        }
    }
}
