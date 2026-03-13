import Foundation

// MARK: - RoR API Response Models

struct RoRResponse: Codable {
    let success: Bool
    let plot: String
    let village: String
    let district: String
    let tahasil: String
    let khataNumber: String?
    let area: String?
    let landType: String?
    let owners: [OwnerEntry]
    let rawFields: [String: String]?
    let source: String
    let cached: Bool
    
    enum CodingKeys: String, CodingKey {
        case success, plot, village, district, tahasil, area, owners, source, cached
        case khataNumber = "khata_number"
        case landType = "land_type"
        case rawFields = "raw_fields"
    }
}

struct OwnerEntry: Codable, Identifiable {
    var id: String { name }
    let name: String
    let share: String?
    let khataNumber: String?
    
    enum CodingKeys: String, CodingKey {
        case name, share
        case khataNumber = "khata_number"
    }
}
