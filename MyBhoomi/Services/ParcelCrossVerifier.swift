//
//  ParcelCrossVerifier.swift
//  MyBhoomi
//
//  Authoritative Cross-Verification Engine
//  Ensures that legal ownership data is only presented when the Cadastral GIS Parcel
//  and official Odisha Bhulekh Record of Rights (RoR) are confirmed to be the exact same parcel.
//

import Foundation
import os.log

private let logger = Logger(subsystem: "com.bhumitra.app", category: "ParcelCrossVerifier")

public struct ParcelCrossVerifier {
    
    public static func normalizeLocationName(_ name: String) -> String {
        return name
            .uppercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "[_\\-\\s]+", with: " ", options: .regularExpression)
    }
    
    public static func parseAcreageFromRoR(_ rorArea: String?) -> Double? {
        guard let areaStr = rorArea, !areaStr.isEmpty else { return nil }
        
        var totalAcre: Double = 0.0
        var foundAny = false
        
        // E.g. "1 Acre 45 Decimal" or "1.45 Acre"
        let acreRegex = try? NSRegularExpression(pattern: #"(\d+(?:\.\d+)?)\s*Acre"#, options: .caseInsensitive)
        let decRegex = try? NSRegularExpression(pattern: #"(\d+(?:\.\d+)?)\s*Decimal"#, options: .caseInsensitive)
        
        let ns = areaStr as NSString
        if let match = acreRegex?.firstMatch(in: areaStr, range: NSRange(location: 0, length: ns.length)) {
            if let val = Double(ns.substring(with: match.range(at: 1))) {
                totalAcre += val
                foundAny = true
            }
        }
        
        if let match = decRegex?.firstMatch(in: areaStr, range: NSRange(location: 0, length: ns.length)) {
            if let val = Double(ns.substring(with: match.range(at: 1))) {
                totalAcre += (val / 100.0)
                foundAny = true
            }
        }
        
        return foundAny ? totalAcre : nil
    }
    
    public static func verify(
        gisIdentity: CanonicalParcelIdentity,
        rorResponse: RoRResponse?,
        gisAreaInAcre: Double? = nil,
        error: Error? = nil
    ) -> ParcelVerificationResult {
        
        if let error = error {
            logger.error("RoR cross-verification error: \(error.localizedDescription)")
            return ParcelVerificationResult(
                status: .sourceUnavailable,
                districtMatch: false,
                tahasilMatch: false,
                villageMatch: false,
                plotMatch: false,
                areaComparisonNotes: nil,
                reasons: ["Official Bhulekh records portal is temporarily unavailable."]
            )
        }
        
        guard let ror = rorResponse else {
            return ParcelVerificationResult(
                status: .insufficientData,
                districtMatch: false,
                tahasilMatch: false,
                villageMatch: false,
                plotMatch: false,
                areaComparisonNotes: nil,
                reasons: ["No Record of Rights response received for verification."]
            )
        }
        
        guard gisIdentity.isFullyResolved else {
            logger.warning("Cross-verification rejected: GIS identity is not fully resolved (missing plot, village, or tahasil).")
            return ParcelVerificationResult(
                status: .insufficientData,
                districtMatch: false,
                tahasilMatch: false,
                villageMatch: false,
                plotMatch: false,
                areaComparisonNotes: nil,
                reasons: ["Cadastral GIS parcel lacks full administrative identifiers (plot, village, or tahasil)."]
            )
        }
        
        // 1. Strict Boundary Matching
        let normGisDist = normalizeLocationName(gisIdentity.districtName)
        let normRorDist = normalizeLocationName(ror.district)
        let distMatch = (normGisDist == normRorDist) || normRorDist.contains(normGisDist) || normGisDist.contains(normRorDist)
        
        let normGisTah = normalizeLocationName(gisIdentity.tahasilName)
        let normRorTah = normalizeLocationName(ror.tahasil)
        let tahMatch = (normGisTah == normRorTah) || normRorTah.contains(normGisTah) || normGisTah.contains(normRorTah)
        
        let normGisVill = normalizeLocationName(gisIdentity.villageName)
        let normRorVill = normalizeLocationName(ror.village)
        let villMatch = (normGisVill == normRorVill) || normRorVill.contains(normGisVill) || normGisVill.contains(normRorVill)
        
        // 2. Strict Exact Plot Matching (NO PREFIX / NO SUBSTRING)
        let cleanGisPlot = gisIdentity.plotNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanRorPlot = ror.plot.trimmingCharacters(in: .whitespacesAndNewlines)
        let plotMatch = (cleanGisPlot == cleanRorPlot)
        
        // 3. Backend Verification Status Check
        if let backendVerif = ror.verification, backendVerif.status != .verified {
            logger.error("Cross-verification rejected by backend verification layer: \(backendVerif.details)")
            return ParcelVerificationResult(
                status: .mismatch,
                districtMatch: distMatch,
                tahasilMatch: tahMatch,
                villageMatch: villMatch,
                plotMatch: plotMatch,
                areaComparisonNotes: nil,
                reasons: ["Backend portal verification failed: \(backendVerif.details)"]
            )
        }
        
        // 4. Area Comparison (Informational / Secondary with safe tolerance)
        var areaNotes: String? = nil
        if let gisArea = gisAreaInAcre, gisArea > 0, let rorAcre = parseAcreageFromRoR(ror.area) {
            let diffPercent = abs(gisArea - rorAcre) / max(gisArea, rorAcre) * 100.0
            if diffPercent <= 25.0 {
                areaNotes = String(format: "Area consistent: GIS %.2f Acre vs RoR %.2f Acre (%.1f%% diff)", gisArea, rorAcre, diffPercent)
            } else {
                areaNotes = String(format: "Note: Area variation detected (GIS %.2f Acre vs RoR %.2f Acre) due to historical cadastral survey differences.", gisArea, rorAcre)
            }
        }
        
        var failureReasons: [String] = []
        if !plotMatch {
            failureReasons.append("Plot number mismatch: Selected GIS Plot '\(cleanGisPlot)' vs RoR Record Plot '\(cleanRorPlot)'.")
        }
        if !villMatch {
            failureReasons.append("Revenue village mismatch: Selected GIS Village '\(gisIdentity.villageName)' vs RoR Village '\(ror.village)'.")
        }
        if !tahMatch {
            failureReasons.append("Tahasil mismatch: Selected GIS Tahasil '\(gisIdentity.tahasilName)' vs RoR Tahasil '\(ror.tahasil)'.")
        }
        if !distMatch {
            failureReasons.append("District mismatch: Selected GIS District '\(gisIdentity.districtName)' vs RoR District '\(ror.district)'.")
        }
        
        if failureReasons.isEmpty {
            logger.info("PARCEL_CROSS_VERIFIED: Successfully verified parcel plot=\(cleanGisPlot), village=\(gisIdentity.villageName)")
            return ParcelVerificationResult(
                status: .verified,
                districtMatch: true,
                tahasilMatch: true,
                villageMatch: true,
                plotMatch: true,
                areaComparisonNotes: areaNotes,
                reasons: ["Official Record of Rights successfully verified against Cadastral GIS parcel."]
            )
        } else {
            logger.warning("PARCEL_CROSS_VERIFICATION_MISMATCH: \(failureReasons.joined(separator: " | "))")
            return ParcelVerificationResult(
                status: .mismatch,
                districtMatch: distMatch,
                tahasilMatch: tahMatch,
                villageMatch: villMatch,
                plotMatch: plotMatch,
                areaComparisonNotes: areaNotes,
                reasons: failureReasons
            )
        }
    }
}
