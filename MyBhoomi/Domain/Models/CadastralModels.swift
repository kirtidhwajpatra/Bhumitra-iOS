import Foundation
import CoreLocation

// MARK: - Official Administrative Hierarchy Models

public struct CadastralDistrict: Codable, Identifiable, Equatable, Hashable {
    public let id: String
    public let name: String
    
    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

public struct CadastralBlock: Codable, Identifiable, Equatable, Hashable {
    public let id: String
    public let name: String
    public let districtID: String
    
    public enum CodingKeys: String, CodingKey {
        case id, name
        case districtID = "district_id"
    }
    
    public init(id: String, name: String, districtID: String) {
        self.id = id
        self.name = name
        self.districtID = districtID
    }
}

public struct CadastralGP: Codable, Identifiable, Equatable, Hashable {
    public let id: String
    public let name: String
    public let blockID: String
    
    public enum CodingKeys: String, CodingKey {
        case id, name
        case blockID = "block_id"
    }
    
    public init(id: String, name: String, blockID: String) {
        self.id = id
        self.name = name
        self.blockID = blockID
    }
}

public struct CadastralVillage: Codable, Identifiable, Equatable, Hashable {
    public let id: String
    public let name: String
    public let gpID: String?
    public let blockID: String
    public let districtID: String?
    public var blockName: String?
    public var districtName: String?
    
    public enum CodingKeys: String, CodingKey {
        case id, name
        case gpID = "gp_id"
        case blockID = "block_id"
        case districtID = "district_id"
        case blockName = "block_name"
        case districtName = "district_name"
    }
    
    public init(
        id: String,
        name: String,
        gpID: String? = nil,
        blockID: String,
        districtID: String? = nil,
        blockName: String? = nil,
        districtName: String? = nil
    ) {
        self.id = id
        self.name = name
        self.gpID = gpID
        self.blockID = blockID
        self.districtID = districtID
        self.blockName = blockName
        self.districtName = districtName
    }
}

// MARK: - Extent Model

public struct CadastralExtent: Codable, Equatable {
    public let minLng: Double
    public let minLat: Double
    public let maxLng: Double
    public let maxLat: Double
    public let centerLng: Double
    public let centerLat: Double
    
    public enum CodingKeys: String, CodingKey {
        case minLng = "min_lng"
        case minLat = "min_lat"
        case maxLng = "max_lng"
        case maxLat = "max_lat"
        case centerLng = "center_lng"
        case centerLat = "center_lat"
    }
    
    public var centerCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: centerLat, longitude: centerLng)
    }
}

// MARK: - Canonical Cadastral Parcel Model

public struct CadastralParcel: Codable, Identifiable, Equatable, Sendable {
    public var id: String { sourceFeatureID ?? "\(villageID)_\(plotNumber)" }
    public let source: String
    public let sourceFeatureID: String?
    public let districtID: String
    public let districtName: String?
    public let blockID: String
    public let blockName: String?
    public let gpID: String?
    public let villageID: String
    public let villageName: String?
    
    /// Exact verbatim plot number string (e.g. "1182", "12/1", "12A")
    public let plotNumber: String
    
    public let centroid: [Double]
    public let geometryType: String
    public let boundary: [Coordinate]
    public let retrievedAt: String
    
    public enum CodingKeys: String, CodingKey {
        case source
        case sourceFeatureID = "source_feature_id"
        case districtID = "district_id"
        case districtName = "district_name"
        case blockID = "block_id"
        case blockName = "block_name"
        case gpID = "gp_id"
        case villageID = "village_id"
        case villageName = "village_name"
        case plotNumber = "plot_number"
        case centroid
        case retrievedAt = "retrieved_at"
        case geometry
    }
    
    public nonisolated init(
        source: String = "ODISHA_4K_GEO",
        sourceFeatureID: String? = nil,
        districtID: String,
        districtName: String? = nil,
        blockID: String,
        blockName: String? = nil,
        gpID: String? = nil,
        villageID: String,
        villageName: String? = nil,
        plotNumber: String,
        centroid: [Double],
        geometryType: String,
        boundary: [Coordinate],
        retrievedAt: String = ISO8601DateFormatter().string(from: Date())
    ) {
        self.source = source
        self.sourceFeatureID = sourceFeatureID
        self.districtID = districtID
        self.districtName = districtName
        self.blockID = blockID
        self.blockName = blockName
        self.gpID = gpID
        self.villageID = villageID
        self.villageName = villageName
        self.plotNumber = plotNumber
        self.centroid = centroid
        self.geometryType = geometryType
        self.boundary = boundary
        self.retrievedAt = retrievedAt
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.source = try container.decodeIfPresent(String.self, forKey: .source) ?? "ODISHA_4K_GEO"
        self.sourceFeatureID = try container.decodeIfPresent(String.self, forKey: .sourceFeatureID)
        self.districtID = try container.decodeIfPresent(String.self, forKey: .districtID) ?? "07"
        self.districtName = try container.decodeIfPresent(String.self, forKey: .districtName)
        self.blockID = try container.decodeIfPresent(String.self, forKey: .blockID) ?? "0704"
        self.blockName = try container.decodeIfPresent(String.self, forKey: .blockName)
        self.gpID = try container.decodeIfPresent(String.self, forKey: .gpID)
        self.villageID = try container.decode(String.self, forKey: .villageID)
        self.villageName = try container.decodeIfPresent(String.self, forKey: .villageName)
        self.plotNumber = try container.decode(String.self, forKey: .plotNumber)
        self.centroid = try container.decodeIfPresent([Double].self, forKey: .centroid) ?? [0.0, 0.0]
        self.retrievedAt = try container.decodeIfPresent(String.self, forKey: .retrievedAt) ?? ""
        
        // Parse geometry object
        if let geomDict = try? container.decode([String: AnyCodable].self, forKey: .geometry) {
            self.geometryType = geomDict["type"]?.value as? String ?? "Polygon"
            
            // Extract coordinates
            var extractedCoords: [Coordinate] = []
            if let coordsArray = geomDict["coordinates"]?.value as? [[[Double]]] {
                // Polygon: [[[lng, lat], ...]]
                if let outerRing = coordsArray.first {
                    extractedCoords = outerRing.map { Coordinate(latitude: $0[1], longitude: $0[0]) }
                }
            } else if let multiCoords = geomDict["coordinates"]?.value as? [[[[Double]]]] {
                // MultiPolygon: [[[[lng, lat], ...]]]
                if let firstPoly = multiCoords.first, let outerRing = firstPoly.first {
                    extractedCoords = outerRing.map { Coordinate(latitude: $0[1], longitude: $0[0]) }
                }
            }
            self.boundary = extractedCoords
        } else {
            self.geometryType = "Polygon"
            self.boundary = []
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(source, forKey: .source)
        try container.encodeIfPresent(sourceFeatureID, forKey: .sourceFeatureID)
        try container.encode(districtID, forKey: .districtID)
        try container.encodeIfPresent(districtName, forKey: .districtName)
        try container.encode(blockID, forKey: .blockID)
        try container.encodeIfPresent(blockName, forKey: .blockName)
        try container.encodeIfPresent(gpID, forKey: .gpID)
        try container.encode(villageID, forKey: .villageID)
        try container.encodeIfPresent(villageName, forKey: .villageName)
        try container.encode(plotNumber, forKey: .plotNumber)
        try container.encode(centroid, forKey: .centroid)
        try container.encode(retrievedAt, forKey: .retrievedAt)
    }
    
    public var centroidCoordinate: CLLocationCoordinate2D {
        if centroid.count >= 2 {
            return CLLocationCoordinate2D(latitude: centroid[1], longitude: centroid[0])
        } else if let first = boundary.first {
            return CLLocationCoordinate2D(latitude: first.latitude, longitude: first.longitude)
        }
        return CLLocationCoordinate2D(latitude: 21.636, longitude: 85.656)
    }
}

// MARK: - Helper AnyCodable for Dynamic JSON
public struct AnyCodable: Codable {
    public let value: Any
    
    public init(_ value: Any) {
        self.value = value
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let boolVal = try? container.decode(Bool.self) {
            value = boolVal
        } else if let intVal = try? container.decode(Int.self) {
            value = intVal
        } else if let doubleVal = try? container.decode(Double.self) {
            value = doubleVal
        } else if let stringVal = try? container.decode(String.self) {
            value = stringVal
        } else if let arrayVal = try? container.decode([AnyCodable].self) {
            value = arrayVal.map { $0.value }
        } else if let dictVal = try? container.decode([String: AnyCodable].self) {
            value = dictVal.mapValues { $0.value }
        } else {
            value = ()
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let boolVal = value as? Bool {
            try container.encode(boolVal)
        } else if let intVal = value as? Int {
            try container.encode(intVal)
        } else if let doubleVal = value as? Double {
            try container.encode(doubleVal)
        } else if let stringVal = value as? String {
            try container.encode(stringVal)
        }
    }
}
