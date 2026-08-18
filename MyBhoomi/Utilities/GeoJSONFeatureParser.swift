import Foundation
import CoreLocation
import MapLibre

public struct ParsedVillageCadastralData: @unchecked Sendable {
    public let shape: MLNShape?
    public let parcels: [CadastralParcel]
    public let totalCount: Int
}

public final class GeoJSONFeatureParser: Sendable {
    
    /// Decodes raw WGS84 GeoJSON data into MapLibre MLNShape and canonical CadastralParcel array.
    public static nonisolated func parse(data: Data, village: CadastralVillage) -> ParsedVillageCadastralData {
        // 1. Direct MapLibre Shape Parser (preserves all features, polygons, multipolygons, and properties for MapLibre rendering)
        let shape = try? MLNShape(data: data, encoding: String.Encoding.utf8.rawValue)
        
        // 2. Parse Canonical CadastralParcel models for local query/selection
        var parcels: [CadastralParcel] = []
        
        if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
           let features = json["features"] as? [[String: Any]] {
            
            for feat in features {
                guard let props = feat["properties"] as? [String: Any],
                      let geom = feat["geometry"] as? [String: Any],
                      let geomType = geom["type"] as? String else {
                    continue
                }
                
                // Extract verbatim plot number
                let plotStr = String(describing: props["revenue_plot"] ?? props["plot_number"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                guard !plotStr.isEmpty else { continue }
                
                // Extract boundary coordinates
                var boundaryCoords: [Coordinate] = []
                
                if geomType == "Polygon", let coordsArray = geom["coordinates"] as? [[[Double]]], let outer = coordsArray.first {
                    boundaryCoords = outer.map { Coordinate(latitude: $0[1], longitude: $0[0]) }
                } else if geomType == "MultiPolygon", let multiArray = geom["coordinates"] as? [[[[Double]]]], let firstPoly = multiArray.first, let outer = firstPoly.first {
                    boundaryCoords = outer.map { Coordinate(latitude: $0[1], longitude: $0[0]) }
                }
                
                // Centroid
                var centroid: [Double] = [0.0, 0.0]
                if let rawCentroid = props["centroid"] as? [Double], rawCentroid.count >= 2 {
                    centroid = rawCentroid
                } else if let first = boundaryCoords.first {
                    centroid = [first.longitude, first.latitude]
                }
                
                let sourceFeatureID = feat["id"] as? String ?? "\(village.id)_\(plotStr)"
                
                let parcel = CadastralParcel(
                    source: "ODISHA_4K_GEO",
                    sourceFeatureID: sourceFeatureID,
                    districtID: village.districtID ?? "07",
                    districtName: props["district_name"] as? String,
                    blockID: village.blockID,
                    blockName: props["block_name"] as? String,
                    gpID: village.gpID,
                    villageID: village.id,
                    villageName: village.name,
                    plotNumber: plotStr,
                    centroid: centroid,
                    geometryType: geomType,
                    boundary: boundaryCoords,
                    retrievedAt: ISO8601DateFormatter().string(from: Date())
                )
                parcels.append(parcel)
            }
        }
        
        return ParsedVillageCadastralData(
            shape: shape,
            parcels: parcels,
            totalCount: parcels.count
        )
    }
}
