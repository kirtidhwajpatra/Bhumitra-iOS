import Foundation
import CoreLocation

/// Robust client for interacting with ArcGIS REST Services (BhuNaksha Odisha)
public final class ArcGISClient {
    public static let shared = ArcGISClient()
    
    // Primary Service: Land Bank Plots (Statewide Cadastral)
    private let plotServiceURL = "https://gis.investodisha.gov.in/arcgis/rest/services/Administrative/MapServer/0/query"
    
    private init() {}
    
    /// Fetches cadastral parcels intersecting the provided bounding box
    /// - Parameter bounds: The geographic bounds (viewport) to query
    /// - Returns: An array of Plot features parsed from ArcGIS JSON
    public func fetchParcels(in bounds: GeoBounds) async throws -> [Parcel] {
        // 1. Construct the Bounding Box string (xmin, ymin, xmax, ymax)
        // Note: ArcGIS typically expects lon/lat for Web Mercator or WGS84
        let bbox = "\(bounds.southWest.longitude),\(bounds.southWest.latitude),\(bounds.northEast.longitude),\(bounds.northEast.latitude)"
        
        var components = URLComponents(string: plotServiceURL)!
        components.queryItems = [
            URLQueryItem(name: "geometry", value: bbox),
            URLQueryItem(name: "geometryType", value: "esriGeometryEnvelope"),
            URLQueryItem(name: "spatialRel", value: "esriSpatialRelIntersects"),
            URLQueryItem(name: "outFields", value: "PLOT_NO,KHATA_NO,VILL_NAME,TAHA,DIST,AREA_AC"),
            URLQueryItem(name: "returnGeometry", value: "true"),
            URLQueryItem(name: "outSR", value: "4326"), // Ensure we get WGS84 Lat/Lon
            URLQueryItem(name: "f", value: "json")
        ]
        
        guard let url = components.url else {
            throw NSError(domain: "ArcGISClient", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL components"])
        }
        
        print("DEBUG: 📡 Fetching ArcGIS Plots -> \(url.absoluteString)")
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "ArcGISClient", code: 2, userInfo: [NSLocalizedDescriptionKey: "Server returned non-200 status"])
        }
        
        let arcgisResponse = try JSONDecoder().decode(ArcGISResponse.self, from: data)
        return try mapToDomain(response: arcgisResponse)
    }
    
    private func mapToDomain(response: ArcGISResponse) throws -> [Parcel] {
        return response.features.compactMap { feature in
            // Parse Rings (ArcGIS Polygons use 'rings' instead of GeoJSON 'coordinates')
            guard let rings = feature.geometry.rings, !rings.isEmpty else { return nil }
            
            // Map the first ring (outer boundary)
            let boundary = rings[0].compactMap { point -> Coordinate? in
                guard point.count >= 2 else { return nil }
                // ArcGIS returns [Lon, Lat]
                return Coordinate(latitude: point[1], longitude: point[0])
            }
            
            let attrs = feature.attributes
            let plotNo = attrs["PLOT_NO"] as? String ?? 
                        (attrs["PLOT_NO"] as? NSNumber)?.stringValue ?? "N/A"
            
            let village = attrs["VILL_NAME"] as? String ?? ""
            let area = attrs["AREA_AC"] as? Double ?? 0.0
            
            var allInfo: [String: String] = [:]
            for (key, value) in attrs {
                allInfo[key] = "\(value)"
            }
            
            return Parcel(
                id: (attrs["OBJECTID"] as? Int).map { "\($0)" } ?? UUID().uuidString,
                boundary: boundary,
                metadata: ParcelMetadata(
                    plotNumber: plotNo,
                    area: area,
                    areaUnit: "acre",
                    ownerName: nil,
                    landUseType: attrs["TAHA"] as? String,
                    additionalInfo: allInfo
                )
            )
        }
    }
}

// MARK: - Internal ArcGIS Models
private struct ArcGISResponse: Codable {
    let features: [ArcGISFeature]
}

private struct ArcGISFeature: Codable {
    let attributes: [String: JSONValue]
    let geometry: ArcGISGeometry
}

private struct ArcGISGeometry: Codable {
    let rings: [[[Double]]]?
}

// Helper to handle mixed types in attributes
private enum JSONValue: Codable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let x = try? container.decode(String.self) {
            self = .string(x)
        } else if let x = try? container.decode(Int.self) {
            self = .int(x)
        } else if let x = try? container.decode(Double.self) {
            self = .double(x)
        } else if let x = try? container.decode(Bool.self) {
            self = .bool(x)
        } else if container.decodeNil() {
            self = .null
        } else {
            throw DecodingError.typeMismatch(JSONValue.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unknown JSON value"))
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let x): try container.encode(x)
        case .int(let x): try container.encode(x)
        case .double(let x): try container.encode(x)
        case .bool(let x): try container.encode(x)
        case .null: try container.encodeNil()
        }
    }
}
