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
    public let isPreview: Bool
    public let isLocked: Bool
    public let previewMessage: String?
    
    public enum CodingKeys: String, CodingKey {
        case success, plot, village, district, tahasil, area, owners, plots, source, cached, verification
        case khataNumber = "khata_number"
        case landType = "land_type"
        case rawFields = "raw_fields"
        case officialDocument = "official_document"
        case isPreview = "is_preview"
        case isLocked = "is_locked"
        case previewMessage = "preview_message"
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
        self.isPreview = try c.decodeIfPresent(Bool.self, forKey: .isPreview) ?? false
        self.isLocked = try c.decodeIfPresent(Bool.self, forKey: .isLocked) ?? false
        self.previewMessage = try c.decodeIfPresent(String.self, forKey: .previewMessage)
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
        cached: Bool = false,
        isPreview: Bool = false,
        isLocked: Bool = false,
        previewMessage: String? = nil
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
        self.isPreview = isPreview
        self.isLocked = isLocked
        self.previewMessage = previewMessage
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
    public let relation: String?
    public let relationName: String?
    public let caste: String?
    public let residence: String?
    public let share: String?
    public let khataNumber: String?
    public let ownershipDetails: String?

    public init(
        id: UUID = UUID(),
        name: String,
        relation: String? = nil,
        relationName: String? = nil,
        caste: String? = nil,
        residence: String? = nil,
        share: String? = nil,
        khataNumber: String? = nil,
        ownershipDetails: String? = nil
    ) {
        self.id = id
        self.name = name
        self.relation = relation
        self.relationName = relationName
        self.caste = caste
        self.residence = residence
        self.share = share
        self.khataNumber = khataNumber
        self.ownershipDetails = ownershipDetails
    }

    public enum CodingKeys: String, CodingKey {
        case name, share, relation, caste, residence
        case relationName = "relation_name"
        case khataNumber = "khata_number"
        case ownershipDetails = "ownership_details"
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.name = try container.decode(String.self, forKey: .name)
        self.relation = try container.decodeIfPresent(String.self, forKey: .relation)
        self.relationName = try container.decodeIfPresent(String.self, forKey: .relationName)
        self.caste = try container.decodeIfPresent(String.self, forKey: .caste)
        self.residence = try container.decodeIfPresent(String.self, forKey: .residence)
        self.share = try container.decodeIfPresent(String.self, forKey: .share)
        self.khataNumber = try container.decodeIfPresent(String.self, forKey: .khataNumber)
        self.ownershipDetails = try container.decodeIfPresent(String.self, forKey: .ownershipDetails)
    }
}

// MARK: - Owner String Decomposition Helper
public enum OwnerParserHelper {
    public struct ParsedOwner {
        public let primaryName: String
        public let relationType: String?
        public let relationName: String?
        public let caste: String?
        public let residence: String?
    }
    
    /// Decomposes an official owner record string (e.g. "ଫୁଲମଣୀ ଜେନା ସ୍ୱା: ହାଡୁ ଜେନା", "ଉଜ୍ଵଳ ଚନ୍ଦ୍ର ସାହୁ ପି:ହରିହର ସାହୁ ଜା: ତେଲି ବା: ନିଜଗାଁ",
    /// "Ramesh Sahu S/O Suresh Sahu") into authentic components without inventing any data.
    public static func parse(rawName: String) -> ParsedOwner {
        let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return ParsedOwner(primaryName: rawName, relationType: nil, relationName: nil, caste: nil, residence: nil)
        }
        
        // 1. Check for Odia delimiters: ପି: (Father), ସ୍ୱା: / ସ୍ଵା: (Husband), ମା: (Mother), ଜା: (Caste), ବା: (Residence)
        if trimmed.contains("ପି:") || trimmed.contains("ସ୍ୱା:") || trimmed.contains("ସ୍ଵା:") || trimmed.contains("ମା:") || trimmed.contains("ଜା:") || trimmed.contains("ବା:") {
            var primary = trimmed
            var relType: String? = nil
            var relName: String? = nil
            var caste: String? = nil
            var residence: String? = nil
            
            // Extract residence if present
            if let rRange = primary.range(of: "ବା:") {
                let after = String(primary[rRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                residence = after.isEmpty ? nil : after
                primary = String(primary[..<rRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            
            // Extract caste if present
            if let cRange = primary.range(of: "ଜା:") {
                let after = String(primary[cRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                caste = after.isEmpty ? nil : after
                primary = String(primary[..<cRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            
            // Extract relation if present
            let relPrefixes: [(String, String)] = [
                ("ସ୍ୱା:", "Husband"),
                ("ସ୍ଵା:", "Husband"),
                ("ପି:", "Father"),
                ("ମା:", "Mother")
            ]
            for (prefix, label) in relPrefixes {
                if let range = primary.range(of: prefix) {
                    let after = String(primary[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                    relName = after.isEmpty ? nil : after
                    relType = label
                    primary = String(primary[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                    break
                }
            }
            
            return ParsedOwner(
                primaryName: primary.isEmpty ? trimmed : primary,
                relationType: relType,
                relationName: relName,
                caste: caste,
                residence: residence
            )
        }
        
        // 2. Check for English prefixes: S/O, D/O, W/O, C/O, Father:, Husband:
        let engPrefixes: [(String, String)] = [
            (" S/O ", "Father"),
            (" S/O. ", "Father"),
            (" D/O ", "Father"),
            (" D/O. ", "Father"),
            (" W/O ", "Husband"),
            (" W/O. ", "Husband"),
            (" C/O ", "Guardian"),
            (" FATHER: ", "Father"),
            (" HUSBAND: ", "Husband")
        ]
        
        let upper = trimmed.uppercased()
        for (prefix, label) in engPrefixes {
            if let range = upper.range(of: prefix) {
                let origIndex = trimmed.index(trimmed.startIndex, offsetBy: upper.distance(from: upper.startIndex, to: range.lowerBound))
                let afterIndex = trimmed.index(trimmed.startIndex, offsetBy: upper.distance(from: upper.startIndex, to: range.upperBound))
                let primary = String(trimmed[..<origIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
                let rel = String(trimmed[afterIndex...]).trimmingCharacters(in: .whitespacesAndNewlines)
                return ParsedOwner(
                    primaryName: primary.isEmpty ? trimmed : primary,
                    relationType: label,
                    relationName: rel.isEmpty ? nil : rel,
                    caste: nil,
                    residence: nil
                )
            }
        }
        
        return ParsedOwner(primaryName: trimmed, relationType: nil, relationName: nil, caste: nil, residence: nil)
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

// MARK: - Odisha Land Revenue Area Formatter
public enum OdishaAreaFormatter {
    public static func formatToDecimalString(_ rawArea: String?) -> String {
        guard let raw = rawArea?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty, raw != "N/A", raw != "-" else {
            return "-"
        }
        
        let lower = raw.lowercased()
        
        // 1. Pattern: "X Acre Y Decimal" (e.g. "0 Acre 9900 Decimal", "1 Acre 20 Decimal", "0 Acre 0300")
        let regex = try? NSRegularExpression(pattern: #"(\d+(?:\.\d+)?)\s*(?:acre|ac)\s*(\d+(?:\.\d+)?)\s*(?:decimal|dec|d\.?)?"#, options: .caseInsensitive)
        if let match = regex?.firstMatch(in: raw, range: NSRange(raw.startIndex..., in: raw)) {
            if let rAcre = Range(match.range(at: 1), in: raw),
               let rDec = Range(match.range(at: 2), in: raw) {
                let acreVal = Double(raw[rAcre]) ?? 0
                var decVal = Double(raw[rDec]) ?? 0
                
                // If decVal is formatted in 4-digit revenue fixed-point format (e.g. 9900 = 99 dec, 0300/300 = 3 dec, 3100 = 31 dec)
                if decVal >= 100 && decVal.truncatingRemainder(dividingBy: 10) == 0 {
                    decVal = decVal / 100.0
                }
                
                let totalDecimals = (acreVal * 100.0) + decVal
                return formatDecimalNumber(totalDecimals)
            }
        }
        
        // Check if already explicitly formatted like "2.68 D." or "20 D."
        if lower.contains("d.") || lower.contains("dec") {
            let numOnly = raw.replacingOccurrences(of: #"[^\d\.]"#, with: "", options: .regularExpression)
            if let d = Double(numOnly) {
                return formatDecimalNumber(d)
            }
            return raw.replacingOccurrences(of: " D.", with: "")
                      .replacingOccurrences(of: "D.", with: "")
                      .replacingOccurrences(of: " Decimal", with: "")
                      .replacingOccurrences(of: " Dec", with: "")
                      .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // 2. Pattern: Plain numeric string or float (e.g. "0.0268", "2.68", "120")
        let cleanNum = raw.replacingOccurrences(of: "Ac", with: "")
                          .replacingOccurrences(of: "ac", with: "")
                          .replacingOccurrences(of: "Acre", with: "")
                          .replacingOccurrences(of: "acre", with: "")
                          .trimmingCharacters(in: .whitespacesAndNewlines)
        
        if let num = Double(cleanNum) {
            let dec = num * 100.0
            return formatDecimalNumber(dec)
        }
        
        return raw.replacingOccurrences(of: " D.", with: "")
                  .replacingOccurrences(of: "D.", with: "")
                  .replacingOccurrences(of: " Decimal", with: "")
                  .replacingOccurrences(of: " Dec", with: "")
                  .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Directly formats a numeric acre value into an authoritative Odisha Decimal string (decimal = acre * 100)
    public static func formatAcreToDecimalString(_ acre: Double?) -> String {
        guard let acre = acre, acre > 0 else { return "-" }
        let decimal = acre * 100.0
        return formatDecimalNumber(decimal)
    }
    
    public static func formatDecimalNumber(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(value))"
        } else {
            return String(format: "%.2f", value)
        }
    }
    
    /// Calculates approximate land area in acres from geographic polygon boundary coordinates
    public static func calculateAcre(from boundary: [Coordinate]) -> Double? {
        guard boundary.count >= 3 else { return nil }
        let rad = Double.pi / 180.0
        let earthRadiusMeters = 6378137.0
        var total: Double = 0.0
        for i in 0..<boundary.count {
            let p1 = boundary[i]
            let p2 = boundary[(i + 1) % boundary.count]
            let lat1 = p1.latitude * rad
            let lat2 = p2.latitude * rad
            let lon1 = p1.longitude * rad
            let lon2 = p2.longitude * rad
            total += (lon2 - lon1) * (2.0 + sin(lat1) + sin(lat2))
        }
        let areaSqMeters = abs(total * earthRadiusMeters * earthRadiusMeters / 2.0)
        let acre = areaSqMeters / 4046.8564224
        guard acre > 0.0001 && acre < 100000 else { return nil }
        return acre
    }
}

// MARK: - RoR Error Taxonomy State
public enum RoRErrorState: Equatable, Sendable {
    case loading(isSlow: Bool)
    case slow
    case unavailable
    case temporaryBusy
    case notFound
    case identityUnresolved
    case identityMismatch
    case networkProblem
    case malformedResponse
    case quotaExceeded

    public var title: String {
        switch self {
        case .loading(let isSlow):
            return isSlow ? "Still checking the official record…" : "Checking official record…"
        case .slow:
            return "Official record is taking longer than expected."
        case .unavailable:
            return "The official land-record service is temporarily unavailable."
        case .temporaryBusy:
            return "Land record service is temporarily busy."
        case .notFound:
            return "No official record found for this plot."
        case .identityUnresolved:
            return "Government location mapping could not be confirmed."
        case .identityMismatch:
            return "Official record could not be safely matched to this plot."
        case .networkProblem:
            return "Couldn't connect to the official record service."
        case .malformedResponse:
            return "Unexpected official record response format."
        case .quotaExceeded:
            return "Search limit reached"
        }
    }
    
    public var subtitle: String? {
        switch self {
        case .loading(let isSlow):
            return isSlow ? "The government land-record service is taking a little longer." : nil
        case .temporaryBusy:
            return "Another official search is running. Tap retry to check again."
        case .malformedResponse:
            return "Received unexpected data from the portal. Tap retry to re-verify."
        case .identityUnresolved:
            return "This village may not yet be mapped in the official catalog. Try manual search."
        case .quotaExceeded:
            return "You have used all available plot searches. Get more searches to continue."
        default:
            return nil
        }
    }

    public var iconName: String {
        switch self {
        case .loading(let isSlow):
            return isSlow ? "clock.arrow.circlepath" : "magnifyingglass"
        case .slow:
            return "clock.badge.exclamationmark"
        case .unavailable:
            return "exclamationmark.triangle.fill"
        case .temporaryBusy:
            return "hourglass"
        case .notFound:
            return "doc.text.magnifyingglass"
        case .identityUnresolved:
            return "mappin.slash"
        case .identityMismatch:
            return "shield.slash.fill"
        case .networkProblem:
            return "wifi.slash"
        case .malformedResponse:
            return "exclamationmark.triangle"
        case .quotaExceeded:
            return "sparkles"
        }
    }

    public var isRetryable: Bool {
        switch self {
        case .loading, .quotaExceeded:
            return false
        case .slow, .unavailable, .temporaryBusy, .networkProblem, .malformedResponse:
            return true
        case .notFound, .identityUnresolved, .identityMismatch:
            return false
        }
    }

    public static func from(error: Error) -> RoRErrorState {
        if let rorError = error as? RoRError {
            switch rorError {
            case .notFound, .noOwnersFound:
                return .notFound
            case .temporarilyUnavailable:
                return .unavailable
            case .timeout:
                return .slow
            case .identityMismatch:
                return .identityMismatch
            case .missingMetadata:
                return .identityUnresolved
            case .networkError:
                return .networkProblem
            case .serverError(let code, let msg):
                if code == 503 || msg.lowercased().contains("busy") || msg.lowercased().contains("queue") {
                    return .temporaryBusy
                }
                return code >= 500 ? .unavailable : .networkProblem
            case .decodingError:
                return .malformedResponse
            case .pdfFailed:
                return .slow
            case .usageLimitExceeded:
                return .quotaExceeded
            }
        }
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            if nsError.code == NSURLErrorTimedOut {
                return .slow
            }
            return .networkProblem
        }
        return .networkProblem
    }
}
