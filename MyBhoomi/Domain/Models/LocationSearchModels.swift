//
//  LocationSearchModels.swift
//  MyBhoomi
//
//  Shared Client Models for Bhumitra Location Search & Spatial Resolution APIs.
//  Strictly mirrors the production /api/v1/location/search and /api/v1/location/resolve contract.
//

import Foundation

/// Intent types classified by the authoritative backend search service.
public enum SearchResultType: String, Codable, Equatable, Hashable {
    case revenueVillage = "REVENUE_VILLAGE"
    case landmark = "LANDMARK"
    case locality = "LOCALITY"
    case compoundPlot = "COMPOUND_PLOT"
    case plotOnly = "PLOT_ONLY"
    case coordinate = "COORDINATE"
    case pinCode = "PIN_CODE"
    case broadCity = "BROAD_CITY"
    case broadDistrict = "BROAD_DISTRICT"
    /// Any type a newer backend may add. Decoding never fails on it, so one
    /// unfamiliar result can't wipe out the whole suggestion list.
    case unknown = "UNKNOWN"

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = SearchResultType(rawValue: raw) ?? .unknown
    }
    
    public var iconName: String {
        switch self {
        case .revenueVillage: return "map.fill"
        case .landmark: return "building.columns.fill"
        case .locality: return "mappin.and.ellipse"
        case .compoundPlot: return "scope"
        case .plotOnly: return "number.square.fill"
        case .coordinate: return "location.fill"
        case .pinCode: return "envelope.fill"
        case .broadCity: return "building.2.fill"
        case .broadDistrict: return "globe.asia.australia.fill"
        case .unknown: return "mappin"
        }
    }
    
    public var recommendedZoomLevel: Double {
        switch self {
        case .coordinate: return 17.0
        case .compoundPlot: return 17.5
        case .plotOnly: return 16.0
        case .revenueVillage: return 16.0
        case .landmark: return 16.5
        case .locality: return 15.0
        case .pinCode: return 15.5
        case .broadCity: return 12.0
        case .broadDistrict: return 9.5
        case .unknown: return 15.0
        }
    }
    
    public var isBroadAdministrative: Bool {
        return self == .broadCity || self == .broadDistrict
    }
}

public typealias LocationSearchResultType = SearchResultType

/// Official spatial resolution status returned by /api/v1/location/resolve.
public enum ResolutionStatus: String, Codable, Equatable {
    case exact = "EXACT"
    case ambiguous = "AMBIGUOUS"
    case unresolved = "UNRESOLVED"
    case outsideOdisha = "OUTSIDE_ODISHA"
    case noCadastralCoverage = "NO_CADASTRAL_COVERAGE"
    case parcelSourceTemporarilyUnavailable = "PARCEL_SOURCE_TEMPORARILY_UNAVAILABLE"
}

/// Normalized location suggestion model returned by /api/v1/location/search.
public struct LocationSearchResult: Identifiable, Codable, Equatable, Hashable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let type: SearchResultType
    public let latitude: Double?
    public let longitude: Double?
    public let boundingBox: [Double]?
    public let source: String?
    public let parsedPlotNumber: String?
    
    // Administrative identifiers when available
    public let district: String?
    public let districtId: String?
    public let tahasil: String?
    public let tahasilId: String?
    public let revenueVillage: String?
    public let revenueVillageId: String?

    // Full village identity (catalog villages). Lets a tap open the village
    // directly with the same identity the District → Tahasil → Village picker builds.
    public let villageNameOdia: String?
    public let bhulekhMouzaId: String?
    /// 4K GEO district id (e.g. "224" for Keonjhar), as used by the map picker.
    public let gisDistrictId: String?
    /// 4K GEO block code DDTT (e.g. "0704"), sent to RoR as `b_id`.
    public let gisBlockId: String?
    /// True when `revenueVillageId` can load cadastral parcels directly.
    public let directLoad: Bool
    
    public init(
        id: String,
        title: String,
        subtitle: String,
        type: SearchResultType,
        latitude: Double? = nil,
        longitude: Double? = nil,
        boundingBox: [Double]? = nil,
        source: String? = nil,
        parsedPlotNumber: String? = nil,
        district: String? = nil,
        districtId: String? = nil,
        tahasil: String? = nil,
        tahasilId: String? = nil,
        revenueVillage: String? = nil,
        revenueVillageId: String? = nil,
        villageNameOdia: String? = nil,
        bhulekhMouzaId: String? = nil,
        gisDistrictId: String? = nil,
        gisBlockId: String? = nil,
        directLoad: Bool = false
    ) {
        self.villageNameOdia = villageNameOdia
        self.bhulekhMouzaId = bhulekhMouzaId
        self.gisDistrictId = gisDistrictId
        self.gisBlockId = gisBlockId
        self.directLoad = directLoad
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.type = type
        self.latitude = latitude
        self.longitude = longitude
        self.boundingBox = boundingBox
        self.source = source
        self.parsedPlotNumber = parsedPlotNumber
        self.district = district
        self.districtId = districtId
        self.tahasil = tahasil
        self.tahasilId = tahasilId
        self.revenueVillage = revenueVillage
        self.revenueVillageId = revenueVillageId
    }
    
    public enum CodingKeys: String, CodingKey {
        case id, title, subtitle, type, latitude, longitude, source
        case boundingBox
        case parsedPlotNumber
        case district
        case districtId
        case tahasil
        case tahasilId
        case revenueVillage
        case revenueVillageId
        case villageNameOdia
        case bhulekhMouzaId
        case gisDistrictId
        case gisBlockId
        case directLoad
        case extraMetadata
    }

    private enum ExtraMetaKeys: String, CodingKey {
        case district_id, district_name
        case tahasil_id, tahasil_name
        case mouza_id, mouza_name, mouza_name_odia
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.title = try container.decode(String.self, forKey: .title)
        self.subtitle = try container.decode(String.self, forKey: .subtitle)
        self.type = try container.decode(SearchResultType.self, forKey: .type)
        self.latitude = try container.decodeIfPresent(Double.self, forKey: .latitude)
        self.longitude = try container.decodeIfPresent(Double.self, forKey: .longitude)
        self.boundingBox = try container.decodeIfPresent([Double].self, forKey: .boundingBox)
        self.source = try container.decodeIfPresent(String.self, forKey: .source)
        self.parsedPlotNumber = try container.decodeIfPresent(String.self, forKey: .parsedPlotNumber)

        var dName = try container.decodeIfPresent(String.self, forKey: .district)
        var dId = try container.decodeIfPresent(String.self, forKey: .districtId)
        var tName = try container.decodeIfPresent(String.self, forKey: .tahasil)
        var tId = try container.decodeIfPresent(String.self, forKey: .tahasilId)
        var rvName = try container.decodeIfPresent(String.self, forKey: .revenueVillage)
        var rvId = try container.decodeIfPresent(String.self, forKey: .revenueVillageId)

        if let metaContainer = try? container.nestedContainer(keyedBy: ExtraMetaKeys.self, forKey: .extraMetadata) {
            if dId == nil { dId = try? metaContainer.decodeIfPresent(String.self, forKey: .district_id) }
            if dName == nil { dName = try? metaContainer.decodeIfPresent(String.self, forKey: .district_name) }
            if tId == nil { tId = try? metaContainer.decodeIfPresent(String.self, forKey: .tahasil_id) }
            if tName == nil { tName = try? metaContainer.decodeIfPresent(String.self, forKey: .tahasil_name) }
            if rvId == nil {
                if let mid = try? metaContainer.decodeIfPresent(String.self, forKey: .mouza_id),
                   let curDid = dId, let curTid = tId,
                   let dInt = Int(curDid), let tInt = Int(curTid), let mInt = Int(mid) {
                    rvId = String(format: "%02d%02d%03d", dInt, tInt, mInt)
                }
            }
            if rvName == nil {
                rvName = try? metaContainer.decodeIfPresent(String.self, forKey: .mouza_name)
            }
        }

        self.district = dName
        self.districtId = dId
        self.tahasil = tName
        self.tahasilId = tId
        self.revenueVillage = rvName
        self.revenueVillageId = rvId
        self.villageNameOdia = try container.decodeIfPresent(String.self, forKey: .villageNameOdia)
        self.bhulekhMouzaId = try container.decodeIfPresent(String.self, forKey: .bhulekhMouzaId)
        self.gisDistrictId = try container.decodeIfPresent(String.self, forKey: .gisDistrictId)
        self.gisBlockId = try container.decodeIfPresent(String.self, forKey: .gisBlockId)
        self.directLoad = (try? container.decodeIfPresent(Bool.self, forKey: .directLoad)) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(subtitle, forKey: .subtitle)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(latitude, forKey: .latitude)
        try container.encodeIfPresent(longitude, forKey: .longitude)
        try container.encodeIfPresent(boundingBox, forKey: .boundingBox)
        try container.encodeIfPresent(source, forKey: .source)
        try container.encodeIfPresent(parsedPlotNumber, forKey: .parsedPlotNumber)
        try container.encodeIfPresent(district, forKey: .district)
        try container.encodeIfPresent(districtId, forKey: .districtId)
        try container.encodeIfPresent(tahasil, forKey: .tahasil)
        try container.encodeIfPresent(tahasilId, forKey: .tahasilId)
        try container.encodeIfPresent(revenueVillage, forKey: .revenueVillage)
        try container.encodeIfPresent(revenueVillageId, forKey: .revenueVillageId)
        try container.encodeIfPresent(villageNameOdia, forKey: .villageNameOdia)
        try container.encodeIfPresent(bhulekhMouzaId, forKey: .bhulekhMouzaId)
        try container.encodeIfPresent(gisDistrictId, forKey: .gisDistrictId)
        try container.encodeIfPresent(gisBlockId, forKey: .gisBlockId)
        try container.encode(directLoad, forKey: .directLoad)
    }
}

// MARK: - Village identity helpers

extension LocationSearchResult {
    /// The village this result opens directly, with the same identity the
    /// manual District → Tahasil → Village picker produces. Nil when the result
    /// isn't a direct-loadable catalog village (landmarks, localities, etc.).
    public var directCadastralVillage: CadastralVillage? {
        guard type == .revenueVillage || type == .compoundPlot,
              let villageId = revenueVillageId, villageId.count == 7,
              villageId.allSatisfy(\.isNumber) else { return nil }

        // Newer backends mark direct-loadable villages explicitly. Older ones (and
        // recents saved by them) don't send the flag, but any catalog village with
        // a 7-digit DDTTVVV code is the same id the map loads plots with.
        let isCatalogVillage = directLoad
            || source == "BHUMITRA_CANONICAL_CATALOG"
            || id.hasPrefix("bhumitra:village:")
            || id.hasPrefix("bhumitra:compound:")
        guard isCatalogVillage else { return nil }

        let districtCode = String(villageId.prefix(2))
        let blockId = (gisBlockId?.isEmpty == false ? gisBlockId : nil) ?? String(villageId.prefix(4))
        // Only trust the backend district name when it's the corrected one (sent
        // alongside gisDistrictId); older catalogs mislabel districts 21–26.
        let districtName = (gisDistrictId != nil ? district : nil)
            ?? MapViewModel.districtNameForGISPrefix(districtCode)
            ?? district
        return CadastralVillage(
            id: villageId,
            name: villageDisplayName,
            gpID: nil,
            blockID: blockId,
            districtID: gisDistrictId ?? Self.fourKGeoDistrictId[districtCode],
            blockName: tahasil ?? MapViewModel.tahasilNameForGISCodes(districtCode: districtCode, tahasilCode: String(villageId.dropFirst(2).prefix(2))),
            districtName: districtName
        )
    }

    /// 2-digit district code (first digits of the village code) → 4K GEO
    /// district id, as used by the manual picker. Mirrors the backend's
    /// ODISHA_DISTRICT_CODE_MAP.
    static let fourKGeoDistrictId: [String: String] = [
        "01": "218", "02": "162", "03": "306", "04": "107", "05": "104",
        "06": "52", "07": "224", "08": "120", "09": "282", "10": "278",
        "11": "60", "12": "47", "13": "72", "14": "161", "15": "171",
        "16": "178", "17": "202", "18": "73", "19": "200", "20": "234",
        "21": "130", "22": "111", "23": "238", "24": "133", "25": "116",
        "26": "300", "27": "22", "28": "177", "29": "150", "30": "51"
    ]

    /// English village name without the Odia suffix, e.g. "Tampo".
    public var villageDisplayName: String {
        if let name = revenueVillage, !name.isEmpty { return name }
        // Legacy/recents: "Tampo (ତମ୍ପୋ)" → "Tampo"; "Plot 5 in Tampo (…)" → "Tampo"
        var base = title
        if let r = base.range(of: " in ") { base = String(base[r.upperBound...]) }
        if let p = base.firstIndex(of: "(") { base = String(base[..<p]) }
        return base.trimmingCharacters(in: .whitespaces)
    }

    /// "Keonjhar Sadar Tahasil · Keonjhar" for villages; subtitle otherwise.
    public var administrativeLine: String {
        guard let t = tahasil, !t.isEmpty, let d = district, !d.isEmpty,
              type == .revenueVillage || type == .compoundPlot else { return subtitle }
        return "\(t) Tahasil · \(d)"
    }
}

/// Search API response envelope.
public struct LocationSearchResponse: Codable {
    public let query: String
    public let intent: String?
    public let totalResults: Int?
    public let executionTimeMs: Double?
    public let results: [LocationSearchResult]

    public var total: Int {
        totalResults ?? results.count
    }

    public init(
        query: String,
        intent: String? = nil,
        total: Int? = nil,
        executionTimeMs: Double? = nil,
        results: [LocationSearchResult]
    ) {
        self.query = query
        self.intent = intent
        self.totalResults = total
        self.executionTimeMs = executionTimeMs
        self.results = results
    }

    public enum CodingKeys: String, CodingKey {
        case query, intent, executionTimeMs, results
        case totalResults
        case total
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.query = try container.decode(String.self, forKey: .query)
        self.intent = try container.decodeIfPresent(String.self, forKey: .intent)
        self.executionTimeMs = try container.decodeIfPresent(Double.self, forKey: .executionTimeMs)
        self.results = try container.decode([LocationSearchResult].self, forKey: .results)

        if let tr = try container.decodeIfPresent(Int.self, forKey: .totalResults) {
            self.totalResults = tr
        } else if let t = try container.decodeIfPresent(Int.self, forKey: .total) {
            self.totalResults = t
        } else {
            self.totalResults = self.results.count
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(query, forKey: .query)
        try container.encodeIfPresent(intent, forKey: .intent)
        try container.encodeIfPresent(totalResults, forKey: .totalResults)
        try container.encodeIfPresent(totalResults, forKey: .total)
        try container.encodeIfPresent(executionTimeMs, forKey: .executionTimeMs)
        try container.encode(results, forKey: .results)
    }
}

/// Disambiguation candidate when resolution returns AMBIGUOUS.
public struct LocationResolutionCandidate: Identifiable, Codable, Equatable, Hashable {
    public var id: String { villageId }
    public let villageId: String
    public let villageName: String
    public let tahasilName: String?
    public let districtName: String?
    public let bhulekhMouzaId: String?
    
    public init(
        villageId: String,
        villageName: String,
        tahasilName: String? = nil,
        districtName: String? = nil,
        bhulekhMouzaId: String? = nil
    ) {
        self.villageId = villageId
        self.villageName = villageName
        self.tahasilName = tahasilName
        self.districtName = districtName
        self.bhulekhMouzaId = bhulekhMouzaId
    }
    
    public enum CodingKeys: String, CodingKey {
        case villageId = "village_id"
        case villageName = "village_name"
        case tahasilName = "tahasil_name"
        case districtName = "district_name"
        case bhulekhMouzaId = "bhulekh_mouza_id"
    }
}

/// Official resolution response envelope from /api/v1/location/resolve.
public struct LocationResolutionResponse: Codable, Equatable {
    public let status: ResolutionStatus
    public let district: String?
    public let districtId: String?
    public let tahasil: String?
    public let tahasilId: String?
    public let revenueVillage: String?
    public let revenueVillageId: String?
    public let bhulekhMouzaId: String?
    public let plotNumber: String?
    public let latitude: Double?
    public let longitude: Double?
    public let resolutionReason: String?
    public let candidates: [LocationResolutionCandidate]?
    public let executionTimeMs: Double?
    
    public init(
        status: ResolutionStatus,
        district: String? = nil,
        districtId: String? = nil,
        tahasil: String? = nil,
        tahasilId: String? = nil,
        revenueVillage: String? = nil,
        revenueVillageId: String? = nil,
        bhulekhMouzaId: String? = nil,
        plotNumber: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        resolutionReason: String? = nil,
        candidates: [LocationResolutionCandidate]? = nil,
        executionTimeMs: Double? = nil
    ) {
        self.status = status
        self.district = district
        self.districtId = districtId
        self.tahasil = tahasil
        self.tahasilId = tahasilId
        self.revenueVillage = revenueVillage
        self.revenueVillageId = revenueVillageId
        self.bhulekhMouzaId = bhulekhMouzaId
        self.plotNumber = plotNumber
        self.latitude = latitude
        self.longitude = longitude
        self.resolutionReason = resolutionReason
        self.candidates = candidates
        self.executionTimeMs = executionTimeMs
    }
    
    public enum CodingKeys: String, CodingKey {
        case status
        case district
        case districtId = "district_id"
        case tahasil
        case tahasilId = "tahasil_id"
        case revenueVillage = "revenue_village"
        case revenueVillageId = "revenue_village_id"
        case bhulekhMouzaId = "bhulekh_mouza_id"
        case plotNumber = "plot_number"
        case latitude, longitude
        case resolutionReason = "resolution_reason"
        case candidates
        case executionTimeMs
    }
}

/// Request payload for POST /api/v1/location/resolve.
public struct LocationResolveRequest: Codable {
    public let latitude: Double
    public let longitude: Double
    public let candidateVillageIds: [String]?
    
    public init(latitude: Double, longitude: Double, candidateVillageIds: [String]? = nil) {
        self.latitude = latitude
        self.longitude = longitude
        self.candidateVillageIds = candidateVillageIds
    }
    
    public enum CodingKeys: String, CodingKey {
        case latitude, longitude
        case candidateVillageIds = "candidate_village_ids"
    }
}
