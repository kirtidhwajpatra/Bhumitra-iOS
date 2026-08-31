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

    public init(
        status: RoRVerificationStatus,
        requestedDistrict: String = "",
        requestedTahasil: String = "",
        requestedVillage: String = "",
        requestedPlot: String = "",
        returnedDistrict: String? = nil,
        returnedTahasil: String? = nil,
        returnedVillage: String? = nil,
        returnedPlot: String? = nil,
        locationMatch: Bool = true,
        plotMatch: Bool = true,
        details: String = ""
    ) {
        self.status = status
        self.requestedDistrict = requestedDistrict
        self.requestedTahasil = requestedTahasil
        self.requestedVillage = requestedVillage
        self.requestedPlot = requestedPlot
        self.returnedDistrict = returnedDistrict
        self.returnedTahasil = returnedTahasil
        self.returnedVillage = returnedVillage
        self.returnedPlot = returnedPlot
        self.locationMatch = locationMatch
        self.plotMatch = plotMatch
        self.details = details
    }

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

public struct AssociatedPlot: Codable, Identifiable, Equatable {
    public var id: String { plotNumber }
    public let plotNumber: String
    public let area: String?
    public let landType: String?
    public let rentCess: String?
    public let remarks: String?

    public init(plotNumber: String, area: String? = nil, landType: String? = nil, rentCess: String? = nil, remarks: String? = nil) {
        self.plotNumber = plotNumber
        self.area = area
        self.landType = landType
        self.rentCess = rentCess
        self.remarks = remarks
    }

    public enum CodingKeys: String, CodingKey {
        case plotNumber = "plot_number"
        case area
        case landType = "land_type"
        case rentCess = "rent_cess"
        case remarks
    }
}

public struct OfficialRoRDocument: Codable, Equatable {
    public let available: Bool
    public let documentID: String
    public let format: String
    public let source: String
    public let isReady: Bool
    
    public enum CodingKeys: String, CodingKey {
        case available
        case documentID = "document_id"
        case format
        case source
        case isReady = "ready"
    }
    
    public init(
        available: Bool = true,
        documentID: String,
        format: String = "pdf",
        source: String = "odisha_bhulekh",
        isReady: Bool = true
    ) {
        self.available = available
        self.documentID = documentID
        self.format = format
        self.source = source
        self.isReady = isReady
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
    public let plots: [AssociatedPlot]
    public let rawFields: [String: String]?
    public let verification: RoRVerification?
    public let officialDocument: OfficialRoRDocument?
    public let source: String
    public let cached: Bool
    
    public enum CodingKeys: String, CodingKey {
        case success, plot, village, district, tahasil, area, owners, plots, source, cached, verification
        case khataNumber = "khata_number"
        case landType = "land_type"
        case rawFields = "raw_fields"
        case officialDocument = "official_document"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.success = try c.decode(Bool.self, forKey: .success)
        self.plot = try c.decode(String.self, forKey: .plot)
        self.village = try c.decode(String.self, forKey: .village)
        self.district = try c.decode(String.self, forKey: .district)
        self.tahasil = try c.decode(String.self, forKey: .tahasil)
        self.khataNumber = try c.decodeIfPresent(String.self, forKey: .khataNumber)
        self.area = try c.decodeIfPresent(String.self, forKey: .area)
        self.landType = try c.decodeIfPresent(String.self, forKey: .landType)
        self.owners = try c.decodeIfPresent([OwnerEntry].self, forKey: .owners) ?? []
        self.plots = try c.decodeIfPresent([AssociatedPlot].self, forKey: .plots) ?? []
        self.rawFields = try c.decodeIfPresent([String: String].self, forKey: .rawFields)
        self.verification = try c.decodeIfPresent(RoRVerification.self, forKey: .verification)
        self.officialDocument = try c.decodeIfPresent(OfficialRoRDocument.self, forKey: .officialDocument)
        self.source = try c.decodeIfPresent(String.self, forKey: .source) ?? "bhulekh.ori.nic.in"
        self.cached = try c.decodeIfPresent(Bool.self, forKey: .cached) ?? false
    }
    
    public init(
        success: Bool = true,
        plot: String,
        village: String,
        district: String,
        tahasil: String,
        khataNumber: String? = nil,
        area: String? = nil,
        landType: String? = nil,
        owners: [OwnerEntry] = [],
        plots: [AssociatedPlot] = [],
        rawFields: [String: String]? = nil,
        verification: RoRVerification? = nil,
        officialDocument: OfficialRoRDocument? = nil,
        source: String = "bhulekh.ori.nic.in",
        cached: Bool = false
    ) {
        self.success = success
        self.plot = plot
        self.village = village
        self.district = district
        self.tahasil = tahasil
        self.khataNumber = khataNumber
        self.area = area
        self.landType = landType
        self.owners = owners
        self.plots = plots
        self.rawFields = rawFields
        self.verification = verification
        self.officialDocument = officialDocument
        self.source = source
        self.cached = cached
    }
    
    public var isGovernmentLand: Bool {
        let ownersText = owners.map { $0.name.lowercased() }.joined(separator: " ")
        let landTypeText = (landType ?? "").lowercased()
        let tenureText = (rawFields?["tenure"] ?? "").lowercased()
        return ownersText.contains("sarkar") || ownersText.contains("government") || ownersText.contains("odisha") || tenureText.contains("rakhit") || tenureText.contains("sarbasadharana") || landTypeText.contains("sarbasadharana")
    }
    
    public static func == (lhs: RoRResponse, rhs: RoRResponse) -> Bool {
        return lhs.plot == rhs.plot &&
               lhs.village == rhs.village &&
               lhs.district == rhs.district &&
               lhs.tahasil == rhs.tahasil &&
               lhs.khataNumber == rhs.khataNumber &&
               lhs.owners.count == rhs.owners.count &&
               lhs.plots.count == rhs.plots.count &&
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

// MARK: - Structured Error Taxonomy

public enum RoRErrorCode: String, Codable {
    case rorNotFound = "ROR_NOT_FOUND"
    case rorIdentityMismatch = "ROR_IDENTITY_MISMATCH"
    case bhulekhTemporaryUnavailable = "BHULEKH_TEMPORARY_UNAVAILABLE"
    case bhulekhTimeout = "BHULEKH_TIMEOUT"
    case bhulekhRateLimited = "BHULEKH_RATE_LIMITED"
    case bhulekhAuthSessionFailed = "BHULEKH_AUTH_SESSION_FAILED"
    case bhulekhParseFailed = "BHULEKH_PARSE_FAILED"
    case pdfGenerationFailed = "PDF_GENERATION_FAILED"
    case pdfDownloadFailed = "PDF_DOWNLOAD_FAILED"
    case networkError = "NETWORK_ERROR"
    case serverError = "SERVER_ERROR"
    case usageLimitExceeded = "USAGE_LIMIT_EXCEEDED"
}

public struct RoRErrorPayload: Codable {
    public let code: String?
    public let message: String?
    public let retryable: Bool?
    public let details: String?
}

