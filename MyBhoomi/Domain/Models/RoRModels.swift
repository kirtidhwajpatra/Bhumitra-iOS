import Foundation

// MARK: - RoR API Response Models

public enum RoRVerificationStatus: String, Codable {
    case verified = "VERIFIED"
    case mismatch = "MISMATCH"
    case insufficientData = "INSUFFICIENT_DATA"
    case sourceError = "SOURCE_ERROR"
}

public struct RoRVerification: Codable, Equatable {
    public let status: RoRVerificationStatus
    public let requestedDistrict: String
    public let requestedTahasil: String
    public let requestedVillage: String
    public let requestedPlot: String
    public let returnedDistrict: String?
    public let returnedTahasil: String?
    public let returnedVillage: String?
    public let returnedPlot: String?
    public let locationMatch: Bool
    public let plotMatch: Bool
    public let details: String

    public enum CodingKeys: String, CodingKey {
        case status, details
        case requestedDistrict = "requested_district"
        case requestedTahasil = "requested_tahasil"
        case requestedVillage = "requested_village"
        case requestedPlot = "requested_plot"
        case returnedDistrict = "returned_district"
        case returnedTahasil = "returned_tahasil"
        case returnedVillage = "returned_village"
        case returnedPlot = "returned_plot"
        case locationMatch = "location_match"
        case plotMatch = "plot_match"
    }
}

public struct RoRResponse: Codable, Equatable {
    public let success: Bool
    public let plot: String
    public let village: String
    public let district: String
    public let tahasil: String
    public let khataNumber: String?
    public let area: String?
    public let landType: String?
    public let owners: [OwnerEntry]
    public let rawFields: [String: String]?
    public let verification: RoRVerification?
    public let source: String
    public let cached: Bool
    
    public enum CodingKeys: String, CodingKey {
        case success, plot, village, district, tahasil, area, owners, source, cached, verification
        case khataNumber = "khata_number"
        case landType = "land_type"
        case rawFields = "raw_fields"
    }
    
    public static func == (lhs: RoRResponse, rhs: RoRResponse) -> Bool {
        return lhs.plot == rhs.plot &&
               lhs.village == rhs.village &&
               lhs.district == rhs.district &&
               lhs.tahasil == rhs.tahasil &&
               lhs.khataNumber == rhs.khataNumber &&
               lhs.owners.count == rhs.owners.count &&
               lhs.verification == rhs.verification
    }
}

public struct OwnerEntry: Codable, Identifiable, Equatable {
    public let id: UUID
    public let name: String
    public let share: String?
    public let khataNumber: String?

    public init(id: UUID = UUID(), name: String, share: String? = nil, khataNumber: String? = nil) {
        self.id = id
        self.name = name
        self.share = share
        self.khataNumber = khataNumber
    }

    public enum CodingKeys: String, CodingKey {
        case name, share
        case khataNumber = "khata_number"
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.name = try container.decode(String.self, forKey: .name)
        self.share = try container.decodeIfPresent(String.self, forKey: .share)
        self.khataNumber = try container.decodeIfPresent(String.self, forKey: .khataNumber)
    }
}
