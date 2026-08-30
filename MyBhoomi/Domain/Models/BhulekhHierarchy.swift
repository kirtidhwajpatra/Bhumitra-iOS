import Foundation

public struct BhulekhDistrict: Codable, Identifiable, Hashable {
    public let id: String
    public let officialName: String
    
    public init(id: String, officialName: String) {
        self.id = id
        self.officialName = officialName
    }
    
    public enum CodingKeys: String, CodingKey {
        case id
        case officialName = "official_name"
    }
}

public struct BhulekhTahasil: Codable, Identifiable, Hashable {
    public let id: String
    public let districtID: String
    public let officialName: String
    
    public init(id: String, districtID: String, officialName: String) {
        self.id = id
        self.districtID = districtID
        self.officialName = officialName
    }
    
    public enum CodingKeys: String, CodingKey {
        case id
        case districtID = "district_id"
        case officialName = "official_name"
    }
}

public struct BhulekhVillage: Codable, Identifiable, Hashable {
    public let id: String
    public let tahasilID: String
    public let districtID: String
    public let officialName: String
    
    public var cleanName: String {
        VillageNameSanitizer.sanitize(officialName)
    }
    
    public init(id: String, tahasilID: String, districtID: String, officialName: String) {
        self.id = id
        self.tahasilID = tahasilID
        self.districtID = districtID
        self.officialName = VillageNameSanitizer.sanitize(officialName)
    }
    
    public enum CodingKeys: String, CodingKey {
        case id
        case tahasilID = "tahasil_id"
        case districtID = "district_id"
        case officialName = "official_name"
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.tahasilID = try container.decode(String.self, forKey: .tahasilID)
        self.districtID = try container.decode(String.self, forKey: .districtID)
        let raw = try container.decode(String.self, forKey: .officialName)
        self.officialName = VillageNameSanitizer.sanitize(raw)
    }
}

public struct BhulekhRICircle: Codable, Identifiable, Hashable {
    public let id: String
    public let tahasilID: String
    public let districtID: String
    public let villageID: String?
    public let officialName: String
    
    public init(id: String, tahasilID: String, districtID: String, villageID: String? = nil, officialName: String) {
        self.id = id
        self.tahasilID = tahasilID
        self.districtID = districtID
        self.villageID = villageID
        self.officialName = officialName
    }
    
    public enum CodingKeys: String, CodingKey {
        case id
        case tahasilID = "tahasil_id"
        case districtID = "district_id"
        case villageID = "village_id"
        case officialName = "official_name"
    }
}

public struct BhulekhPlot: Codable, Identifiable, Hashable {
    public var id: String { "\(villageID):\(plotNumber)" }
    public let plotNumber: String
    public let plotID: String?
    public let villageID: String
    public let tahasilID: String
    public let districtID: String
    
    public init(plotNumber: String, plotID: String? = nil, villageID: String, tahasilID: String, districtID: String) {
        self.plotNumber = plotNumber
        self.plotID = plotID
        self.villageID = villageID
        self.tahasilID = tahasilID
        self.districtID = districtID
    }
    
    public enum CodingKeys: String, CodingKey {
        case plotNumber = "plot_number"
        case plotID = "plot_id"
        case villageID = "village_id"
        case tahasilID = "tahasil_id"
        case districtID = "district_id"
    }
}
