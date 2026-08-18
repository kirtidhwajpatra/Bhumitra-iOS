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
            let plotNo = properties["plot_number"]?.stringValue ?? properties["revenue_plot"]?.stringValue ?? "N/A"
            let dist = properties["district"]?.stringValue ?? properties["d_name"]?.stringValue ?? "Keonjhar"
            let tahasil = properties["tahasil"]?.stringValue ?? properties["b_name"]?.stringValue ?? "N/A"
            let village = properties["village"]?.stringValue ?? properties["v_name"]?.stringValue ?? "N/A"
            let pid = properties["id"]?.stringValue ?? properties["p_id"]?.stringValue
            let area = properties["area"]?.doubleValue ?? properties["area_in_acre"]?.doubleValue
            
            let identity = CanonicalParcelIdentity(
                parcelID: pid,
                plotNumber: plotNo,
                districtName: dist,
                tahasilName: tahasil,
                villageName: village
            )
            let metadata = ParcelMetadata(
                identity: identity,
                estimatedAreaAcre: area
            )
            return Parcel(boundary: coords, metadata: metadata)
        }
    }
}
