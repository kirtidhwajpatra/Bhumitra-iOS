import Foundation
import CoreLocation

/// Client for the Odisha4kGeo Cadastral API
/// Endpoint: https://odisha4kgeo.in/index.php/mapview/viewCadistrialResult
public final class Odisha4kGeoClient {
    public static let shared = Odisha4kGeoClient()
    
    private let baseURL = "https://odisha4kgeo.in/index.php/mapview"
    
    private init() {}
    
    /// Parameters for the Cadastral API
    public struct CadastralParams {
        public let district: String
        public let block: String
        public let villageCode: String
        public let sheetNo: String?
        public let field: String = "revenue_village_code"
        
        public init(district: String, block: String, villageCode: String, sheetNo: String? = nil) {
            self.district = district
            self.block = block
            self.villageCode = villageCode
            self.sheetNo = sheetNo
        }
    }
    
    /// Fetches cadastral parcels for a specific village
    public func fetchParcels(params: CadastralParams) async throws -> [Parcel] {
        var body = [
            "district": params.district,
            "block": params.block,
            "value": params.villageCode,
            "field": params.field
        ]
        if let sheet = params.sheetNo { body["sheetNo"] = sheet }
        
        let data = try await performPOST(endpoint: "viewCadistrialResult", body: body)
        
        let geoJSON = try JSONDecoder().decode(GeoJSONFeatureCollection.self, from: data)
        return mapToDomain(geoJSON: geoJSON, village: params.villageCode)
    }
    
    /// Fetches road overlays
    public func fetchRoads(params: CadastralParams) async throws -> [Parcel] {
        var body = [
            "district": params.district,
            "block": params.block,
            "value": params.villageCode,
            "field": params.field
        ]
        if let sheet = params.sheetNo { body["sheetNo"] = sheet }
        
        let data = try await performPOST(endpoint: "viewCadistrialRoad", body: body)
        let geoJSON = try JSONDecoder().decode(GeoJSONFeatureCollection.self, from: data)
        return mapToDomain(geoJSON: geoJSON, village: params.villageCode, type: "road")
    }
    
    /// Fetches river overlays
    public func fetchRivers(params: CadastralParams) async throws -> [Parcel] {
        var body = [
            "district": params.district,
            "block": params.block,
            "value": params.villageCode,
            "field": params.field
        ]
        if let sheet = params.sheetNo { body["sheetNo"] = sheet }
        
        let data = try await performPOST(endpoint: "viewCadistrialRiver", body: body)
        let geoJSON = try JSONDecoder().decode(GeoJSONFeatureCollection.self, from: data)
        return mapToDomain(geoJSON: geoJSON, village: params.villageCode, type: "river")
    }
    
    // MARK: - Internal Helper
    
    private func performPOST(endpoint: String, body: [String: String]) async throws -> Data {
        guard let url = URL(string: "\(baseURL)/\(endpoint)") else {
            throw NSError(domain: "Odisha4kGeoClient", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let bodyString = body.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }.joined(separator: "&")
        request.httpBody = bodyString.data(using: .utf8)
        
        print("DEBUG: 🚀 Odisha4kGeo POST -> \(endpoint) | Params: \(body)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "Odisha4kGeoClient", code: 2, userInfo: [NSLocalizedDescriptionKey: "Server error"])
        }
        
        return data
    }
    
    private func mapToDomain(geoJSON: GeoJSONFeatureCollection, village: String, type: String = "parcel") throws -> [Parcel] {
        return geoJSON.features.compactMap { feature in
            // Coordinates are in EPSG:3857 (Meters)
            let boundary: [Coordinate]
            
            switch feature.geometry {
            case .polygon(let rings):
                boundary = rings.first?.compactMap { point in
                    guard point.count >= 2 else { return nil }
                    return Coordinate.fromWebMercator(x: point[0], y: point[1])
                } ?? []
            case .multiPolygon(let multipolygon):
                boundary = multipolygon.first?.first?.compactMap { point in
                    guard point.count >= 2 else { return nil }
                    return Coordinate.fromWebMercator(x: point[0], y: point[1])
                } ?? []
            }
            
            if boundary.isEmpty { return nil }
            
            let plotNo = feature.properties["revenue_plot"] ?? "N/A"
            
            return Parcel(
                id: "\(type)_\(village)_\(plotNo)_\(UUID().uuidString.prefix(4))",
                boundary: boundary,
                metadata: ParcelMetadata(
                    plotNumber: plotNo,
                    area: 0, // Not provided directly in this API response usually
                    areaUnit: "acre",
                    ownerName: nil,
                    landUseType: type,
                    additionalInfo: feature.properties
                )
            )
        }
    }
}

// MARK: - GeoJSON Internal Models

private struct GeoJSONFeatureCollection: Codable {
    let features: [GeoJSONFeature]
}

private struct GeoJSONFeature: Codable {
    let properties: [String: String]
    let geometry: GeoJSONGeometry
}

private enum GeoJSONGeometry: Codable {
    case polygon([[[Double]]])
    case multiPolygon([[[[Double]]]])
    
    enum CodingKeys: String, CodingKey {
        case type, coordinates
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        if type == "Polygon" {
            let coords = try container.decode([[[Double]]].self, forKey: .coordinates)
            self = .polygon(coords)
        } else if type == "MultiPolygon" {
            let coords = try container.decode([[[[Double]]]].self, forKey: .coordinates)
            self = .multiPolygon(coords)
        } else {
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unsupported geometry type")
        }
    }
}
