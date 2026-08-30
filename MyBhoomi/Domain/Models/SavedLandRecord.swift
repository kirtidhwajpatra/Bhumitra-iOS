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
    
    public init(
        result: OfficialSearchResult,
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
