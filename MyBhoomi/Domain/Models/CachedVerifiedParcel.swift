//
//  CachedVerifiedParcel.swift
//  MyBhoomi
//
//  Domain model for locally persisted verified land parcels and RoR records.
//  Implements strict classification taxonomy and fail-closed resolution gates.
//

import Foundation
import CoreLocation

/// Explicit taxonomy for statutory land holding classifications.
public enum LandClassificationStatus: String, Codable, Equatable, Hashable, Sendable {
    case verifiedPrivate = "VERIFIED_PRIVATE"
    case verifiedGovernment = "VERIFIED_GOVERNMENT"
    case verifiedOther = "VERIFIED_OTHER"
    case unverified = "UNVERIFIED"
}

/// Explicit taxonomy for parcel identity resolution status.
public enum ParcelResolutionStatus: String, Codable, Equatable, Hashable, Sendable {
    case verified = "VERIFIED"
    case unresolved = "UNRESOLVED"
    case identityMismatch = "IDENTITY_MISMATCH"
    case notFound = "NOT_FOUND"
    case upstreamError = "UPSTREAM_ERROR"
}

/// Represents a single owner entry stored in the local parcel cache.
public struct CachedOwnerEntry: Codable, Equatable, Hashable, Sendable {
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
    
    public init(from owner: OwnerEntry) {
        self.id = owner.id
        self.name = owner.name
        self.share = owner.share
        self.khataNumber = owner.khataNumber
    }
    
    public func toOwnerEntry() -> OwnerEntry {
        OwnerEntry(
            id: id,
            name: name,
            share: share,
            khataNumber: khataNumber
        )
    }
}

/// Represents a 2D coordinate stored in the local parcel cache.
public struct CachedCoordinate: Codable, Equatable, Hashable, Sendable {
    public let latitude: Double
    public let longitude: Double
    
    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

/// Full persistent representation of a verified land parcel and its official RoR record.
public struct CachedVerifiedParcel: Codable, Identifiable, Equatable, Hashable, Sendable {
    /// Canonical identity key: `districtID:tahasilID:villageID:plotNumber`
    public var id: String { canonicalKey }
    public let canonicalKey: String
    
    // Administrative & Cadastral Identity
    public let plotNumber: String
    public let villageName: String
    public let villageID: String
    public let tahasilName: String
    public let tahasilID: String
    public let districtName: String
    public let districtID: String
    public let khataNumber: String
    
    // Land Attributes & Strict Taxonomy
    public let area: String?
    public let landClassification: String?
    public let tenure: String?
    public let landClassificationStatus: LandClassificationStatus
    public let resolutionStatus: ParcelResolutionStatus
    
    // Ownership
    public let owners: [CachedOwnerEntry]
    public let landlord: String?
    
    // Complete Raw Responses for Lossless Restoration
    public let rawRoRResponse: RoRResponse
    public let verificationStatus: String
    public let verificationReasons: [String]
    
    // Optional Boundary Geometry
    public let boundaryCoordinates: [CachedCoordinate]?
    
    // Cache Timestamps
    public let verifiedAt: Date
    public var lastAccessedAt: Date
    
    public var isGovernmentLand: Bool {
        resolutionStatus == .verified && landClassificationStatus == .verifiedGovernment
    }
    
    public var isPrivateLand: Bool {
        resolutionStatus == .verified && landClassificationStatus == .verifiedPrivate
    }
    
    public init(
        canonicalKey: String,
        plotNumber: String,
        villageName: String,
        villageID: String,
        tahasilName: String,
        tahasilID: String,
        districtName: String,
        districtID: String,
        khataNumber: String,
        area: String?,
        landClassification: String?,
        tenure: String?,
        landClassificationStatus: LandClassificationStatus,
        resolutionStatus: ParcelResolutionStatus = .verified,
        owners: [CachedOwnerEntry],
        landlord: String?,
        rawRoRResponse: RoRResponse,
        verificationStatus: String,
        verificationReasons: [String] = [],
        boundaryCoordinates: [CachedCoordinate]? = nil,
        verifiedAt: Date = Date(),
        lastAccessedAt: Date = Date()
    ) {
        self.canonicalKey = canonicalKey
        self.plotNumber = plotNumber
        self.villageName = villageName
        self.villageID = villageID
        self.tahasilName = tahasilName
        self.tahasilID = tahasilID
        self.districtName = districtName
        self.districtID = districtID
        self.khataNumber = khataNumber
        self.area = area
        self.landClassification = landClassification
        self.tenure = tenure
        self.landClassificationStatus = landClassificationStatus
        self.resolutionStatus = resolutionStatus
        self.owners = owners
        self.landlord = landlord
        self.rawRoRResponse = rawRoRResponse
        self.verificationStatus = verificationStatus
        self.verificationReasons = verificationReasons
        self.boundaryCoordinates = boundaryCoordinates
        self.verifiedAt = verifiedAt
        self.lastAccessedAt = lastAccessedAt
    }
    
    /// Convenient constructor from live verified RoR response and canonical identity
    public init?(
        identity: CanonicalParcelIdentity,
        ror: RoRResponse,
        verification: ParcelVerificationResult,
        boundary: [Coordinate]? = nil
    ) {
        // Enforce safety invariant: ONLY cache if verified!
        guard verification.isVerified || (ror.verification?.status == .verified && verification.status == .verified) else {
            return nil
        }
        
        let distId = identity.districtID ?? ror.district
        let tahId = identity.tahasilID ?? ror.tahasil
        let villId = identity.villageID ?? ror.village
        let plot = ror.plot.isEmpty ? identity.plotNumber : ror.plot
        
        guard !distId.isEmpty, !tahId.isEmpty, !villId.isEmpty, !plot.isEmpty else {
            return nil
        }
        
        let key = "\(distId):\(tahId):\(villId):\(plot)"
        self.canonicalKey = key
        
        self.plotNumber = plot
        self.villageName = identity.villageName.isEmpty ? ror.village : identity.villageName
        self.villageID = identity.villageID ?? ""
        self.tahasilName = identity.tahasilName.isEmpty ? ror.tahasil : identity.tahasilName
        self.tahasilID = identity.tahasilID ?? ""
        self.districtName = identity.districtName.isEmpty ? ror.district : identity.districtName
        self.districtID = identity.districtID ?? ""
        self.khataNumber = ror.khataNumber ?? "N/A"
        
        self.area = ror.area
        self.landClassification = ror.landType
        self.tenure = ror.rawFields?["tenure"]
        
        // Strict Statutory Land Classification determination (Never inferred from missing data)
        self.landClassificationStatus = CachedVerifiedParcel.determineLandClassification(
            landType: ror.landType,
            tenure: ror.rawFields?["tenure"],
            owners: ror.owners
        )
        self.resolutionStatus = .verified
        
        self.owners = ror.owners.map { CachedOwnerEntry(from: $0) }
        self.landlord = ror.rawFields?["landlord"]
        
        self.rawRoRResponse = ror
        self.verificationStatus = "verified"
        self.verificationReasons = verification.reasons
        
        if let boundary = boundary {
            self.boundaryCoordinates = boundary.map { CachedCoordinate(latitude: $0.latitude, longitude: $0.longitude) }
        } else {
            self.boundaryCoordinates = nil
        }
        
        self.verifiedAt = Date()
        self.lastAccessedAt = Date()
    }
    
    /// Evaluates statutory government land vs private rayati land strictly from verified official records
    public static func determineLandClassification(
        landType: String?,
        tenure: String?,
        owners: [OwnerEntry] = []
    ) -> LandClassificationStatus {
        let lt = (landType ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let t = (tenure ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let combined = "\(lt) \(t)"
        
        // Explicit Statutory Government markers
        let govtMarkers = [
            "ସରକାରୀ ରକ୍ଷିତ", "ସରକାରୀ ଅନାବାଦୀ", "ଅବ୍ୟବହାର୍ଯ୍ୟ ସରକାରୀ", "ସର୍ବସାଧାରଣ",
            "ଗୋଚର", "ରାସ୍ତା", "ନାଳ", "ନଦୀ", "ଜଙ୍ଗଲ (ସରକାରୀ)", "ରେଳବାଇ",
            "rakhit", "anabadi", "sarbasadharan", "sarkari rakhit", "sarkari anabadi",
            "gochar", "rasta", "nala", "river", "railway", "government", "sarkar", "sarkari"
        ]
        for m in govtMarkers {
            if combined.contains(m) {
                return .verifiedGovernment
            }
        }
        
        // Explicit Private / Rayati markers
        let privateMarkers = [
            "ରୟତି", "ସ୍ଥିତିବାନ", "ଚାନ୍ଦିନା", "ଦେବୋତ୍ତର", "ଜଳାଶୟ", "ଘରବାରୀ", "ଖଲାବାରୀ",
            "ସାରଦ", "ପାଟ", "ବେଆଇନ ଦଖଲ", "rayati", "stitiban", "chandina", "gharabari"
        ]
        for m in privateMarkers {
            if combined.contains(m) {
                return .verifiedPrivate
            }
        }
        
        if !owners.isEmpty {
            return .verifiedPrivate
        }
        
        return .unverified
    }
    
    // MARK: - Transformation to Presentation Models
    
    /// Reconstructs the canonical `OfficialSearchResult` for instant UI presentation
    public func toOfficialSearchResult() -> OfficialSearchResult {
        OfficialSearchResult(
            districtID: districtID,
            districtName: districtName,
            tahasilID: tahasilID,
            tahasilName: tahasilName,
            villageID: villageID,
            villageName: villageName,
            plotNumber: plotNumber,
            khatianNumber: khataNumber,
            area: area,
            ownersCount: owners.count,
            associatedPlots: rawRoRResponse.plots.map { $0.plotNumber },
            rawResponse: rawRoRResponse
        )
    }
    
    /// Formatted relative or absolute verification date string
    public var formattedVerifiedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: verifiedAt)
    }
    
    /// Compact area representation (e.g. `0.09 Ac` or `1.40 Ac`)
    public var compactAreaDisplay: String {
        if let a = area, !a.isEmpty {
            return a
        }
        return "—"
    }
    
    public static func == (lhs: CachedVerifiedParcel, rhs: CachedVerifiedParcel) -> Bool {
        lhs.canonicalKey == rhs.canonicalKey
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(canonicalKey)
    }
}
