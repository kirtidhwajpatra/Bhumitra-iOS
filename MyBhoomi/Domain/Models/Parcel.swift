//
//  Parcel.swift
//  MyBhoomi
//
//  Canonical Parcel Domain Model
//  Defines immutable, verified parcel identity separating GIS vector attributes
//  from authoritative Odisha Bhulekh Record of Rights (RoR) data.
//

import Foundation
import CoreLocation

public struct Coordinate: Codable, Equatable, Hashable {
    public let latitude: Double
    public let longitude: Double
    
    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

// MARK: - Canonical Parcel Identity

public struct CanonicalParcelIdentity: Codable, Equatable, Hashable {
    /// Unique GIS parcel identifier (e.g. p_id if present, or stable compound key)
    public let parcelID: String
    /// Cadastral revenue plot number (e.g. "1182", "45/1")
    public let plotNumber: String
    /// Standardized district name (e.g. "KEONJHAR")
    public let districtName: String
    /// District code/ID if available from GIS or mappings
    public let districtID: String?
    /// Tahasil / Block administrative name (e.g. "KEONJHAR SADAR")
    public let tahasilName: String
    /// GIS Block code / Tahasil ID if available (e.g. "0704")
    public let tahasilID: String?
    /// Revenue village name (e.g. "G KERI 271")
    public let villageName: String
    /// Revenue village census code if available (e.g. "0704179")
    public let villageID: String?
    /// Optional Gram Panchayat name
    public let panchayatName: String?
    /// True strictly when plotNumber, villageName, tahasilName, and districtName are all present and valid
    public let isFullyResolved: Bool
    
    public init(
        parcelID: String? = nil,
        plotNumber: String,
        districtName: String,
        districtID: String? = nil,
        tahasilName: String,
        tahasilID: String? = nil,
        villageName: String,
        villageID: String? = nil,
        panchayatName: String? = nil
    ) {
        let cleanPlot = plotNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanDistrict = districtName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanTahasil = tahasilName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanVillage = villageName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        self.plotNumber = cleanPlot
        self.districtName = cleanDistrict
        self.districtID = districtID?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.tahasilName = cleanTahasil
        self.tahasilID = tahasilID?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.villageName = cleanVillage
        self.villageID = villageID?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.panchayatName = panchayatName?.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let validPlot = !cleanPlot.isEmpty && cleanPlot != "N/A"
        let validDistrict = !cleanDistrict.isEmpty && cleanDistrict != "N/A"
        let validTahasil = !cleanTahasil.isEmpty && cleanTahasil != "N/A"
        let validVillage = !cleanVillage.isEmpty && cleanVillage != "N/A"
        
        self.isFullyResolved = validPlot && validDistrict && validTahasil && validVillage
        
        if let pid = parcelID?.trimmingCharacters(in: .whitespacesAndNewlines), !pid.isEmpty {
            self.parcelID = pid
        } else {
            // Compound immutable key: district:tahasil:village:plot
            let d = districtID ?? cleanDistrict
            let t = tahasilID ?? cleanTahasil
            let v = villageID ?? cleanVillage
            self.parcelID = "\(d):\(t):\(v):\(cleanPlot)"
        }
    }
}

// MARK: - Parcel Metadata (GIS Source Attributes Only)

public struct ParcelMetadata: Codable, Equatable {
    public let identity: CanonicalParcelIdentity
    /// Planar estimated area in acres calculated from satellite vector polygon
    public let estimatedAreaAcre: Double?
    /// Raw unparsed vector tile attributes dictionary
    public let additionalInfo: [String: String]?
    
    // Convenience forwarders
    public var plotNumber: String { identity.plotNumber }
    public var area: Double { estimatedAreaAcre ?? 0.0 }
    public var areaUnit: String { "acre" }
    
    public init(
        identity: CanonicalParcelIdentity,
        estimatedAreaAcre: Double? = nil,
        additionalInfo: [String: String]? = nil
    ) {
        self.identity = identity
        self.estimatedAreaAcre = estimatedAreaAcre
        self.additionalInfo = additionalInfo
    }
    
    // Legacy initializer for test compatibility
    public init(
        plotNumber: String,
        area: Double = 0.0,
        areaUnit: String = "acre",
        ownerName: String? = nil,
        landUseType: String? = nil,
        additionalInfo: [String: String]? = nil
    ) {
        let dist = additionalInfo?["d_name"] ?? additionalInfo?["District"] ?? "Keonjhar"
        let tahasil = additionalInfo?["b_name"] ?? additionalInfo?["Tahasil"] ?? "N/A"
        let village = additionalInfo?["v_name"] ?? additionalInfo?["Village"] ?? "N/A"
        let pid = additionalInfo?["p_id"]
        let bid = additionalInfo?["b_id"]
        let vid = additionalInfo?["v_id"]
        let pname = additionalInfo?["p_name"]
        
        self.identity = CanonicalParcelIdentity(
            parcelID: pid,
            plotNumber: plotNumber,
            districtName: dist,
            tahasilName: tahasil,
            tahasilID: bid,
            villageName: village,
            villageID: vid,
            panchayatName: pname
        )
        self.estimatedAreaAcre = area
        self.additionalInfo = additionalInfo
    }
}

// MARK: - Parcel Domain Entity

public struct Parcel: Identifiable, Equatable {
    public let id: String
    public let identity: CanonicalParcelIdentity
    public let boundary: [Coordinate]
    public let metadata: ParcelMetadata
    
    public var center: Coordinate {
        guard !boundary.isEmpty else { return Coordinate(latitude: 0, longitude: 0) }
        let totalLat = boundary.map { $0.latitude }.reduce(0, +)
        let totalLon = boundary.map { $0.longitude }.reduce(0, +)
        return Coordinate(
            latitude: totalLat / Double(boundary.count),
            longitude: totalLon / Double(boundary.count)
        )
    }
    
    public init(
        id: String? = nil,
        boundary: [Coordinate],
        metadata: ParcelMetadata
    ) {
        self.id = id ?? metadata.identity.parcelID
        self.identity = metadata.identity
        self.boundary = boundary
        self.metadata = metadata
    }
    
    public static func == (lhs: Parcel, rhs: Parcel) -> Bool {
        return lhs.id == rhs.id
    }
}
