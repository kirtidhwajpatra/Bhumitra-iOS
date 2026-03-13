import Foundation

public struct GeoJSONFeatureCollection: Decodable {
    public let type: String
    public let features: [GeoJSONFeature]
}

public struct GeoJSONFeature: Decodable {
    public let type: String
    public let properties: [String: AnyJSONValue]?
    public let geometry: GeoJSONGeometry?
}

public struct GeoJSONGeometry: Decodable {
    public let type: String
    public let coordinates: [[[Double]]]
}

public enum AnyJSONValue: Decodable {
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
    
    public var stringValue: String? {
        if case .string(let s) = self { return s }
        if case .double(let d) = self { return "\(d)" }
        if case .int(let i) = self { return "\(i)" }
        return nil
    }
    
    public var doubleValue: Double? {
        if case .double(let d) = self { return d }
        if case .int(let i) = self { return Double(i) }
        return nil
    }
}
