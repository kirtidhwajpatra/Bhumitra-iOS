import Foundation

// ============================================================
// MARK: - SAVED LAND RECORD (ON-DEVICE PERSISTENCE MODEL)
// ============================================================

/// Represents an officially verified or searched land parcel saved securely on-device.
/// Contains complete RoR snapshot data for zero-latency offline viewing.
public struct SavedLandRecord: Codable, Identifiable, Hashable, Equatable {
    public let id: String
    public let districtID: String
    public let districtName: String
    public let tahasilID: String
    public let tahasilName: String
    public let villageID: String
    public let villageName: String
    public let plotNumber: String
    public let khatianNumber: String
    public let area: String?
    public let landType: String?
    public let tenure: String?
    public let owners: [String]
    public let associatedPlots: [String]
    public let savedAt: Date
    public var customTag: String?
    public let rawResponse: RoRResponse
    
    // Cadastral GIS Vector & Geographic Coordinates
    public var boundary: [Coordinate]?
    public var centerLatitude: Double?
    public var centerLongitude: Double?
    
    public init(
        result: OfficialSearchResult,
        boundary: [Coordinate]? = nil,
        customTag: String? = nil
    ) {
        let cleanVillage = VillageNameSanitizer.sanitize(result.villageName)
        let cleanDistrict = result.districtName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanTahasil = result.tahasilName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        self.id = "\(result.districtID)_\(result.tahasilID)_\(result.villageID)_\(result.plotNumber)"
        self.districtID = result.districtID
        self.districtName = cleanDistrict.isEmpty ? result.rawResponse.district : cleanDistrict
        self.tahasilID = result.tahasilID
        self.tahasilName = cleanTahasil.isEmpty ? result.rawResponse.tahasil : cleanTahasil
        self.villageID = result.villageID
        self.villageName = cleanVillage.isEmpty ? result.rawResponse.village : cleanVillage
        self.plotNumber = result.plotNumber
        self.khatianNumber = result.khatianNumber
        self.area = result.area ?? result.rawResponse.area
        self.landType = result.rawResponse.landType
        self.tenure = result.rawResponse.rawFields?["tenure"]
        self.owners = result.rawResponse.owners.map { $0.name }
        self.associatedPlots = result.associatedPlots
        self.savedAt = Date()
        self.customTag = customTag
        self.rawResponse = result.rawResponse
        
        if let b = boundary, !b.isEmpty {
            self.boundary = b
            let sumLat = b.map(\.latitude).reduce(0, +)
            let sumLon = b.map(\.longitude).reduce(0, +)
            self.centerLatitude = sumLat / Double(b.count)
            self.centerLongitude = sumLon / Double(b.count)
        } else {
            self.boundary = nil
            self.centerLatitude = nil
            self.centerLongitude = nil
        }
    }
    
    public enum CodingKeys: String, CodingKey {
        case id, districtID, districtName, tahasilID, tahasilName, villageID, villageName
        case plotNumber, khatianNumber, area, landType, tenure, owners, associatedPlots
        case savedAt, customTag, rawResponse, boundary, centerLatitude, centerLongitude
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.districtID = try container.decode(String.self, forKey: .districtID)
        self.districtName = try container.decode(String.self, forKey: .districtName)
        self.tahasilID = try container.decode(String.self, forKey: .tahasilID)
        self.tahasilName = try container.decode(String.self, forKey: .tahasilName)
        self.villageID = try container.decode(String.self, forKey: .villageID)
        self.villageName = try container.decode(String.self, forKey: .villageName)
        self.plotNumber = try container.decode(String.self, forKey: .plotNumber)
        self.khatianNumber = try container.decode(String.self, forKey: .khatianNumber)
        self.area = try container.decodeIfPresent(String.self, forKey: .area)
        self.landType = try container.decodeIfPresent(String.self, forKey: .landType)
        self.tenure = try container.decodeIfPresent(String.self, forKey: .tenure)
        self.owners = try container.decodeIfPresent([String].self, forKey: .owners) ?? []
        self.associatedPlots = try container.decodeIfPresent([String].self, forKey: .associatedPlots) ?? []
        self.savedAt = try container.decodeIfPresent(Date.self, forKey: .savedAt) ?? Date()
        self.customTag = try container.decodeIfPresent(String.self, forKey: .customTag)
        self.rawResponse = try container.decode(RoRResponse.self, forKey: .rawResponse)
        self.boundary = try container.decodeIfPresent([Coordinate].self, forKey: .boundary)
        self.centerLatitude = try container.decodeIfPresent(Double.self, forKey: .centerLatitude)
        self.centerLongitude = try container.decodeIfPresent(Double.self, forKey: .centerLongitude)
    }
    
    /// Converts the saved record back into an OfficialSearchResult for full detail rendering
    public var toSearchResult: OfficialSearchResult {
        OfficialSearchResult(
            districtID: districtID,
            districtName: districtName,
            tahasilID: tahasilID,
            tahasilName: tahasilName,
            villageID: villageID,
            villageName: villageName,
            plotNumber: plotNumber,
            khatianNumber: khatianNumber,
            area: area,
            ownersCount: owners.count,
            associatedPlots: associatedPlots,
            rawResponse: rawResponse
        )
    }
    
    /// Numerical area in acres if parseable (for aggregation stats)
    public var parsedAcres: Double? {
        guard let areaStr = area ?? rawResponse.area else { return nil }
        // Matches "0.45 Ac" or "1.20"
        let pattern = #"([0-9]+(?:\.[0-9]+)?)"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: []),
           let match = regex.firstMatch(in: areaStr, range: NSRange(areaStr.startIndex..., in: areaStr)),
           let range = Range(match.range(at: 1), in: areaStr) {
            return Double(areaStr[range])
        }
        return nil
    }
    
    // MARK: - Equatable & Hashable Conformance
    
    public static func == (lhs: SavedLandRecord, rhs: SavedLandRecord) -> Bool {
        lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
