//
//  ParcelVerification.swift
//  MyBhoomi
//
//  Defines authoritative cross-verification between Cadastral GIS Parcels
//  and official Odisha Bhulekh Record of Rights (RoR).
//

import Foundation

public enum ParcelVerificationStatus: String, Codable, Equatable {
    case verified = "VERIFIED"
    case mismatch = "MISMATCH"
    case insufficientData = "INSUFFICIENT_DATA"
    case sourceUnavailable = "SOURCE_UNAVAILABLE"
}

public struct ParcelVerificationResult: Codable, Equatable {
    public let status: ParcelVerificationStatus
    public let districtMatch: Bool
    public let tahasilMatch: Bool
    public let villageMatch: Bool
    public let plotMatch: Bool
    public let areaComparisonNotes: String?
    public let reasons: [String]
    
    public var isVerified: Bool {
        return status == .verified
    }
    
    public init(
        status: ParcelVerificationStatus,
        districtMatch: Bool = true,
        tahasilMatch: Bool = true,
        villageMatch: Bool = true,
        plotMatch: Bool = true,
        areaComparisonNotes: String? = nil,
        reasons: [String] = []
    ) {
        self.status = status
        self.districtMatch = districtMatch
        self.tahasilMatch = tahasilMatch
        self.villageMatch = villageMatch
        self.plotMatch = plotMatch
        self.areaComparisonNotes = areaComparisonNotes
        self.reasons = reasons
    }
}
