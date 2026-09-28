import Foundation
import CoreLocation

// ============================================================
// MARK: - GIS EXPLORER NAVIGATION LEVEL
// ============================================================

public enum GISNavigationLevel: Equatable {
    case odisha
    case district(CadastralDistrict, bbox: [Double]?)
    case subdivision(CadastralBlock)
    case village(CadastralVillage)
    
    public var title: String {
        switch self {
        case .odisha:
            return "Odisha"
        case .district(let d, _):
            return d.name
        case .subdivision(let b):
            return b.name
        case .village(let v):
            return v.name
        }
    }
    
    public static func == (lhs: GISNavigationLevel, rhs: GISNavigationLevel) -> Bool {
        switch (lhs, rhs) {
        case (.odisha, .odisha):
            return true
        case (.district(let d1, _), .district(let d2, _)):
            return d1.id == d2.id
        case (.subdivision(let b1), .subdivision(let b2)):
            return b1.id == b2.id
        case (.village(let v1), .village(let v2)):
            return v1.id == v2.id
        default:
            return false
        }
    }
}

// ============================================================
// MARK: - GIS BREADCRUMB ITEM
// ============================================================

public struct GISBreadcrumbItem: Identifiable, Equatable {
    public let id: String
    public let title: String
    public let level: GISNavigationLevel
    public let isCurrent: Bool
    
    public init(id: String = UUID().uuidString, title: String, level: GISNavigationLevel, isCurrent: Bool) {
        self.id = id
        self.title = title
        self.level = level
        self.isCurrent = isCurrent
    }
}

// ============================================================
// MARK: - GIS DISTRICT FEATURE (METADATA)
// ============================================================

public struct GISDistrictFeature: Identifiable, Codable, Equatable {
    public let id: String
    public let name: String
    public let code2Digit: String
    public let bhulekhID: String?
    public let centerLat: Double
    public let centerLng: Double
    public let bbox: [Double]
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case code2Digit = "code_2digit"
        case bhulekhID = "bhulekh_id"
        case centerLat = "center_lat"
        case centerLng = "center_lng"
        case bbox
    }
    
    public var centerCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: centerLat, longitude: centerLng)
    }
}

// ============================================================
// MARK: - GIS TAHASIL FEATURE (METADATA)
// ============================================================

public struct GISTahasilFeature: Identifiable, Codable, Equatable {
    public let id: String
    public let name: String
    public let nameOdia: String?
    public let bhulekhTahasilID: String?
    public let districtID: String
    public let centerLat: Double
    public let centerLng: Double
    public let bbox: [Double]
    public let isVisualizationBoundary: Bool?
    public let classification: String?
    
    enum CodingKeys: String, CodingKey {
        case id = "tahasil_id"
        case name = "tahasil_name"
        case nameOdia = "tahasil_name_odia"
        case bhulekhTahasilID = "bhulekh_tahasil_id"
        case districtID = "district_id"
        case center
        case bbox
        case isVisualizationBoundary = "is_visualization_boundary"
        case classification
    }
    
    public init(
        id: String,
        name: String,
        nameOdia: String? = nil,
        bhulekhTahasilID: String? = nil,
        districtID: String,
        centerLat: Double,
        centerLng: Double,
        bbox: [Double],
        isVisualizationBoundary: Bool? = true,
        classification: String? = "Census/Survey-derived administrative visualization boundary"
    ) {
        self.id = id
        self.name = name
        self.nameOdia = nameOdia
        self.bhulekhTahasilID = bhulekhTahasilID
        self.districtID = districtID
        self.centerLat = centerLat
        self.centerLng = centerLng
        self.bbox = bbox
        self.isVisualizationBoundary = isVisualizationBoundary
        self.classification = classification
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.nameOdia = try container.decodeIfPresent(String.self, forKey: .nameOdia)
        self.bhulekhTahasilID = try container.decodeIfPresent(String.self, forKey: .bhulekhTahasilID)
        self.districtID = try container.decode(String.self, forKey: .districtID)
        self.bbox = try container.decodeIfPresent([Double].self, forKey: .bbox) ?? []
        self.isVisualizationBoundary = try container.decodeIfPresent(Bool.self, forKey: .isVisualizationBoundary)
        self.classification = try container.decodeIfPresent(String.self, forKey: .classification)
        
        let center = try container.decodeIfPresent([Double].self, forKey: .center) ?? []
        if center.count >= 2 {
            self.centerLng = center[0]
            self.centerLat = center[1]
        } else {
            self.centerLat = 0
            self.centerLng = 0
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(nameOdia, forKey: .nameOdia)
        try container.encodeIfPresent(bhulekhTahasilID, forKey: .bhulekhTahasilID)
        try container.encode(districtID, forKey: .districtID)
        try container.encode([centerLng, centerLat], forKey: .center)
        try container.encode(bbox, forKey: .bbox)
        try container.encodeIfPresent(isVisualizationBoundary, forKey: .isVisualizationBoundary)
        try container.encodeIfPresent(classification, forKey: .classification)
    }
    
    public var centerCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: centerLat, longitude: centerLng)
    }
}

// ============================================================
// MARK: - GIS NAVIGATION STATE
// ============================================================

public enum GISNavigationState: Equatable {
    case idle
    case loading(String)
    case loaded
    case error(String)
}

// ============================================================
// MARK: - GIS COORDINATE BOUNDS
// ============================================================

public struct GISCoordinateBounds: Equatable {
    public let sw: CLLocationCoordinate2D
    public let ne: CLLocationCoordinate2D
    
    public init(sw: CLLocationCoordinate2D, ne: CLLocationCoordinate2D) {
        self.sw = sw
        self.ne = ne
    }
    
    public static func == (lhs: GISCoordinateBounds, rhs: GISCoordinateBounds) -> Bool {
        lhs.sw.latitude == rhs.sw.latitude &&
        lhs.sw.longitude == rhs.sw.longitude &&
        lhs.ne.latitude == rhs.ne.latitude &&
        lhs.ne.longitude == rhs.ne.longitude
    }
}

