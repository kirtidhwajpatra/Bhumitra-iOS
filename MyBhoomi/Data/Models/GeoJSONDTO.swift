import Foundation

public struct GeoJSONFeatureCollection: Codable {
    public let type: String?
    public let features: [GeoJSONFeature]
    
    public init(features: [GeoJSONFeature], type: String? = "FeatureCollection") {
        self.features = features
        self.type = type
    }
}

public struct GeoJSONFeature: Codable {
    public let type: String?
    public let properties: [String: AnyJSONValue]?
    public let geometry: GeoJSONGeometry?
    
    public init(properties: [String: AnyJSONValue]?, geometry: GeoJSONGeometry?, type: String? = "Feature") {
        self.properties = properties
        self.geometry = geometry
        self.type = type
    }
}

public enum GeoJSONGeometry: Codable {
    case polygon([[[Double]]])
    case multiPolygon([[[[Double]]]])
    
    enum CodingKeys: String, CodingKey {
        case type, coordinates
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        if type == "Polygon" {
            let coords = try container.decode([[[Double]]].self, forKey: .coordinates)
            self = .polygon(coords)
        } else if type == "MultiPolygon" {
            let coords = try container.decode([[[[Double]]]].self, forKey: .coordinates)
            self = .multiPolygon(coords)
        } else {
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unsupported geometry type: \(type)")
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .polygon(let coords):
            try container.encode("Polygon", forKey: .type)
            try container.encode(coords, forKey: .coordinates)
        case .multiPolygon(let coords):
            try container.encode("MultiPolygon", forKey: .type)
            try container.encode(coords, forKey: .coordinates)
        }
    }
}

public enum AnyJSONValue: Codable {
    case string(String)
    case double(Double)
    case int(Int)
    case bool(Bool)
    case dictionary([String: AnyJSONValue])
    case array([AnyJSONValue])
    case null
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode([String: AnyJSONValue].self) {
            self = .dictionary(value)
        } else if let value = try? container.decode([AnyJSONValue].self) {
            self = .array(value)
        } else {
            self = .null
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let s): try container.encode(s)
        case .double(let d): try container.encode(d)
        case .int(let i): try container.encode(i)
        case .bool(let b): try container.encode(b)
        case .dictionary(let d): try container.encode(d)
        case .array(let a): try container.encode(a)
        case .null: try container.encodeNil()
        }
    }
    
    public var stringValue: String? {
        switch self {
        case .string(let s): return s
        case .double(let d): return "\(d)"
        case .int(let i): return "\(i)"
        case .bool(let b): return "\(b)"
        default: return nil
        }
    }
    
    public var doubleValue: Double? {
        if case .double(let d) = self { return d }
        if case .int(let i) = self { return Double(i) }
        return nil
    }
}
