import Foundation
import CoreLocation
import Combine
import MapLibre

public final class CadastralRepository: ObservableObject {
    public static let shared = CadastralRepository()
    
    private let apiClient: CadastralAPIClient
    
    // In-Memory Session Cache: villageID -> ParsedVillageCadastralData
    private var villageCache: [String: ParsedVillageCadastralData] = [:]
    private var extentsCache: [String: CadastralExtent] = [:]
    
    public init(apiClient: CadastralAPIClient = .shared) {
        self.apiClient = apiClient
    }
    
    // MARK: - Hierarchy
    
    public func getDistricts() async throws -> [CadastralDistrict] {
        try await apiClient.fetchDistricts()
    }
    
    public func getBlocks(districtID: String) async throws -> [CadastralBlock] {
        try await apiClient.fetchBlocks(districtID: districtID)
    }
    
    public func getGPs(blockID: String) async throws -> [CadastralGP] {
        try await apiClient.fetchGPs(blockID: blockID)
    }
    
    public func getVillages(blockID: String, gpID: String? = nil) async throws -> [CadastralVillage] {
        try await apiClient.fetchVillages(blockID: blockID, gpID: gpID)
    }
    
    public func getVillageExtent(village: CadastralVillage) async throws -> CadastralExtent {
        if let cached = extentsCache[village.id] {
            return cached
        }
        let extent = try await apiClient.fetchVillageExtent(villageID: village.id, gpID: village.gpID)
        extentsCache[village.id] = extent
        return extent
    }
    
    // MARK: - Village Parcels
    
    public func loadVillageParcels(village: CadastralVillage) async throws -> ParsedVillageCadastralData {
        if let cached = villageCache[village.id] {
            return cached
        }
        
        let rawData = try await apiClient.fetchVillageParcelsRawGeoJSON(
            villageID: village.id,
            districtName: village.districtID,
            blockName: village.blockID,
            gpName: village.gpID,
            villageName: village.name
        )
        
        // Parse off the main thread
        let parsed = await _Concurrency.Task.detached(priority: .userInitiated) {
            GeoJSONFeatureParser.parse(data: rawData, village: village)
        }.value
        
        villageCache[village.id] = parsed
        return parsed
    }
    
    public func getParcelByPlot(village: CadastralVillage, plotNumber: String) -> CadastralParcel? {
        guard let cached = villageCache[village.id] else { return nil }
        let cleanPlot = plotNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        return cached.parcels.first(where: { $0.plotNumber == cleanPlot })
    }
    
    public func identifyParcel(at coordinate: CLLocationCoordinate2D, in village: CadastralVillage) -> CadastralParcel? {
        guard let cached = villageCache[village.id] else { return nil }
        
        for parcel in cached.parcels {
            if parcel.boundary.count >= 3 && pointInPolygon(coord: coordinate, polygon: parcel.boundary) {
                return parcel
            }
        }
        return nil
    }
    
    private func pointInPolygon(coord: CLLocationCoordinate2D, polygon: [Coordinate]) -> Bool {
        guard polygon.count >= 3 else { return false }
        var inside = false
        var j = polygon.count - 1
        
        for i in 0..<polygon.count {
            let pi = polygon[i]
            let pj = polygon[j]
            
            if (pi.latitude > coord.latitude) != (pj.latitude > coord.latitude) &&
                (coord.longitude < (pj.longitude - pi.longitude) * (coord.latitude - pi.latitude) / (pj.latitude - pi.latitude) + pi.longitude) {
                inside = !inside
            }
            j = i
        }
        return inside
    }
}
