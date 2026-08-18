//
//  CadastralFeatureResolver.swift
//  MyBhoomi
//
//  Cadastral GIS Feature Extraction & Disambiguation Engine
//  Resolves exact cadastral parcels from MapLibre rendered vector tile features,
//  merges tile fragments, applies ray-casting point-in-polygon tests,
//  and eliminates plot number ambiguity.
//

import Foundation
import CoreLocation
import MapLibre

public struct CadastralFeatureCandidate: Equatable {
    public let identity: CanonicalParcelIdentity
    public let boundary: [Coordinate]
    public let estimatedAreaAcre: Double?
    public let rawAttributes: [String: String]
}

public enum CadastralResolutionResult: Equatable {
    /// Exactly one unambiguous cadastral parcel was verified at the tap coordinate
    case resolved(Parcel)
    /// Multiple distinct parcels overlapped at the tap point (e.g. tapped on a shared boundary at low zoom)
    case ambiguous(candidateCount: Int, message: String)
    /// No cadastral parcel feature exists at the tapped coordinate
    case noFeature
}

public final class CadastralFeatureResolver {
    
    // MARK: - Safe Typed Attribute Parsing
    
    public static func extractString(_ raw: Any?) -> String? {
        guard let val = raw else { return nil }
        
        if let num = val as? NSNumber {
            // Check if integer (e.g. 1182 vs 1182.5)
            if floor(num.doubleValue) == num.doubleValue && !num.doubleValue.isInfinite && !num.doubleValue.isNaN {
                return "\(num.int64Value)"
            } else {
                return "\(num.doubleValue)"
            }
        }
        
        if let str = val as? String {
            let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || trimmed == "<null>" || trimmed == "null" || trimmed == "N/A" {
                return nil
            }
            return trimmed
        }
        
        let s = "\(val)".trimmingCharacters(in: .whitespacesAndNewlines)
        return (s.isEmpty || s == "<null>" || s == "null" || s == "N/A") ? nil : s
    }
    
    public static func extractPlotNumber(_ raw: Any?) -> String? {
        guard let str = extractString(raw) else { return nil }
        // Clean plot number while preserving fractions (e.g. "1182/1", "1182/P")
        let cleaned = str.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.isEmpty || cleaned == "0" || cleaned == "N/A" {
            return nil
        }
        return cleaned
    }
    
    public static func extractDouble(_ raw: Any?) -> Double? {
        guard let val = raw else { return nil }
        if let num = val as? NSNumber {
            return num.doubleValue
        }
        if let str = val as? String {
            return Double(str.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return Double("\(val)")
    }
    
    // MARK: - Point-In-Polygon Ray Casting Test
    
    public static func isCoordinate(_ point: CLLocationCoordinate2D, insidePolygon vertices: [CLLocationCoordinate2D]) -> Bool {
        guard vertices.count >= 3 else { return false }
        var inside = false
        var j = vertices.count - 1
        for i in 0..<vertices.count {
            let vi = vertices[i]
            let vj = vertices[j]
            if ((vi.latitude > point.latitude) != (vj.latitude > point.latitude)) &&
                (point.longitude < (vj.longitude - vi.longitude) * (point.latitude - vi.latitude) / (vj.latitude - vi.latitude) + vi.longitude) {
                inside.toggle()
            }
            j = i
        }
        return inside
    }
    
    // MARK: - Feature Resolution
    
    public static func resolveTappedParcel(
        features: [MLNFeature],
        tapCoordinate: CLLocationCoordinate2D
    ) -> CadastralResolutionResult {
        guard !features.isEmpty else {
            return .noFeature
        }
        
        // 1. Parse all valid cadastral features
        var parsedCandidates: [CadastralFeatureCandidate] = []
        
        for feature in features {
            let attrs = feature.attributes
            guard let plotNo = extractPlotNumber(attrs["revenue_plot"]) else {
                continue
            }
            
            let pid = extractString(attrs["p_id"])
            let distName = extractString(attrs["District"]) ?? extractString(attrs["d_name"]) ?? extractString(attrs["d_namc"]) ?? "Keonjhar"
            let distId = extractString(attrs["d_id"])
            let tahasilName = extractString(attrs["Tahasil"]) ?? extractString(attrs["t_name"]) ?? extractString(attrs["t_namc"]) ?? extractString(attrs["b_name"]) ?? extractString(attrs["b_namc"]) ?? "N/A"
            let tahasilId = extractString(attrs["b_id"]) ?? extractString(attrs["t_id"])
            let villageName = extractString(attrs["Village"]) ?? extractString(attrs["v_name"]) ?? extractString(attrs["v_namc"]) ?? "N/A"
            let villageId = extractString(attrs["v_id"])
            let panchayatName = extractString(attrs["p_name"]) ?? extractString(attrs["p_namc"])
            
            let areaAcre = extractDouble(attrs["area_in_acre"])
            
            var allInfo: [String: String] = [:]
            for (k, v) in attrs {
                if let strVal = extractString(v) {
                    allInfo[k] = strVal
                }
            }
            
            let identity = CanonicalParcelIdentity(
                parcelID: pid,
                plotNumber: plotNo,
                districtName: distName,
                districtID: distId,
                tahasilName: tahasilName,
                tahasilID: tahasilId,
                villageName: villageName,
                villageID: villageId,
                panchayatName: panchayatName
            )
            
            let boundary = boundaryCoordinates(of: feature)
            
            parsedCandidates.append(
                CadastralFeatureCandidate(
                    identity: identity,
                    boundary: boundary,
                    estimatedAreaAcre: areaAcre,
                    rawAttributes: allInfo
                )
            )
        }
        
        guard !parsedCandidates.isEmpty else {
            return .noFeature
        }
        
        // 2. Group candidates by unique canonical parcelID (handles tile boundary fragmentation)
        var groupedByIdentity: [String: [CadastralFeatureCandidate]] = [:]
        for candidate in parsedCandidates {
            groupedByIdentity[candidate.identity.parcelID, default: []].append(candidate)
        }
        
        // 3. If all features belong to the EXACT same parcel identity (tile fragments):
        if groupedByIdentity.count == 1, let singleGroup = groupedByIdentity.values.first {
            let representative = singleGroup.max(by: { $0.boundary.count < $1.boundary.count }) ?? singleGroup[0]
            let metadata = ParcelMetadata(
                identity: representative.identity,
                estimatedAreaAcre: representative.estimatedAreaAcre,
                additionalInfo: representative.rawAttributes
            )
            let parcel = Parcel(
                id: representative.identity.parcelID,
                boundary: representative.boundary,
                metadata: metadata
            )
            return .resolved(parcel)
        }
        
        // 4. Multiple distinct parcel candidates detected at the tap point
        // Run Ray-Casting Point-In-Polygon tests to find which parcel strictly encloses the tap coordinate
        var enclosingCandidates: [CadastralFeatureCandidate] = []
        
        for (_, group) in groupedByIdentity {
            let representative = group.max(by: { $0.boundary.count < $1.boundary.count }) ?? group[0]
            let coords = representative.boundary.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
            
            if isCoordinate(tapCoordinate, insidePolygon: coords) {
                enclosingCandidates.append(representative)
            }
        }
        
        // If point-in-polygon resolved exactly 1 candidate:
        if enclosingCandidates.count == 1 {
            let winner = enclosingCandidates[0]
            let metadata = ParcelMetadata(
                identity: winner.identity,
                estimatedAreaAcre: winner.estimatedAreaAcre,
                additionalInfo: winner.rawAttributes
            )
            let parcel = Parcel(
                id: winner.identity.parcelID,
                boundary: winner.boundary,
                metadata: metadata
            )
            return .resolved(parcel)
        }
        
        // If still ambiguous (e.g. tap landed on shared boundary line between 2 parcels):
        let distinctCount = groupedByIdentity.count
        return .ambiguous(
            candidateCount: distinctCount,
            message: "Multiple parcels found at this tap point. Please zoom in to select the exact parcel."
        )
    }
    
    // MARK: - Geometry Extraction
    
    public static func boundaryCoordinates(of feature: MLNFeature) -> [Coordinate] {
        let polygon: MLNPolygon?
        if let poly = feature as? MLNPolygonFeature {
            polygon = poly
        } else if let multi = feature as? MLNMultiPolygonFeature {
            polygon = multi.polygons.max(by: { $0.pointCount < $1.pointCount })
        } else {
            polygon = nil
        }

        guard let polygon = polygon, polygon.pointCount >= 3 else { return [] }

        let count = Int(polygon.pointCount)
        var coords = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: count)
        polygon.getCoordinates(&coords, range: NSRange(location: 0, length: count))
        return coords
            .filter { CLLocationCoordinate2DIsValid($0) }
            .map { Coordinate(latitude: $0.latitude, longitude: $0.longitude) }
    }
}
