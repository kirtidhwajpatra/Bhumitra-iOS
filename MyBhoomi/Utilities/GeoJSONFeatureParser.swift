import Foundation
import CoreLocation
import MapLibre

public struct ParsedVillageCadastralData: @unchecked Sendable {
    public let shape: MLNShape?
    public let parcels: [CadastralParcel]
    public let totalCount: Int
}

public final class GeoJSONFeatureParser: Sendable {
    
    /// High-Contrast, Strong Purple / Violet / Indigo Choropleth Palette (matching the bold reference map)
    public static let shadePalette: [String] = [
        "#4F46E5", // Deep Royal Indigo
        "#7C3AED", // Electric Violet
        "#9333EA", // Rich Vibrant Purple
        "#6366F1", // Bold Iris
        "#8B5CF6", // Medium Amethyst
        "#A855F7", // Vivid Orchid
        "#581C87", // Deep Dark Purple
        "#818CF8", // Periwinkle Slate
        "#3730A3", // Dark Indigo
        "#A78BFA", // Bright Lavender Violet
    ]
    
    /// Deterministically computes a harmonious shade color for a given plot number.
    /// Uses a stride multiplier so adjacent sequential plots (e.g. 101, 102, 103) receive distinctly contrasting bold shades.
    public static func colorForPlot(_ plotString: String, index: Int = 0) -> String {
        let digits = plotString.filter { $0.isNumber }
        let plotNum = Int(digits) ?? (index + 1)
        let paletteIndex = abs((plotNum * 3 + (index + 1) * 7) % shadePalette.count)
        return shadePalette[paletteIndex]
    }
    
    /// Decodes raw WGS84 GeoJSON data into MapLibre MLNShape and canonical CadastralParcel array.
    public static nonisolated func parse(data: Data, village: CadastralVillage) -> ParsedVillageCadastralData {
        var shapeData = data
        var parcels: [CadastralParcel] = []
        
        if var json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
           var features = json["features"] as? [[String: Any]] {
            
            for i in 0..<features.count {
                var feat = features[i]
                guard var props = feat["properties"] as? [String: Any],
                      let geom = feat["geometry"] as? [String: Any],
                      let geomType = geom["type"] as? String else {
                    continue
                }
                
                // Extract verbatim plot number
                let plotStr = String(describing: props["revenue_plot"] ?? props["plot_number"] ?? "\(i + 1)").trimmingCharacters(in: .whitespacesAndNewlines)
                guard !plotStr.isEmpty else { continue }
                
                // Assign deterministic harmonious purple shade to each parcel
                let fillColor = colorForPlot(plotStr, index: i)
                props["fill_color"] = fillColor
                props["shade_index"] = i % shadePalette.count
                feat["properties"] = props
                features[i] = feat
                
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
                    districtID: village.districtID ?? "",
                    districtName: props["district_name"] as? String ?? village.districtName,
                    blockID: village.blockID,
                    blockName: props["block_name"] as? String ?? village.blockName,
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
            
            json["features"] = features
            if let modifiedData = try? JSONSerialization.data(withJSONObject: json, options: []) {
                shapeData = modifiedData
            }
        }
        
        // 1. Direct MapLibre Shape Parser with injected fill_color properties
        let shape = try? MLNShape(data: shapeData, encoding: String.Encoding.utf8.rawValue)
        
        return ParsedVillageCadastralData(
            shape: shape,
            parcels: parcels,
            totalCount: parcels.count
        )
    }
}
