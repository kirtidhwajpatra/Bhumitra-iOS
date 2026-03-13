import Foundation

public final class ParcelRepository: ParcelRepositoryProtocol {
    private let arcgisClient: ArcGISClient
    private let odishaClient: Odisha4kGeoClient
    private var cachedParcels: [Parcel] = []
    private var lastQueryBounds: GeoBounds?
    
    public init(
        arcgisClient: ArcGISClient = ArcGISClient.shared,
        odishaClient: Odisha4kGeoClient = Odisha4kGeoClient.shared
    ) {
        self.arcgisClient = arcgisClient
        self.odishaClient = odishaClient
    }
    
    public func fetchParcels() async throws -> [Parcel] {
        // Return cached parcels if available
        if !cachedParcels.isEmpty { return cachedParcels }
        return []
    }
    
    public func fetchParcels(in bounds: GeoBounds) async throws -> [Parcel] {
        // Keep ArcGIS for discovery while panning
        if let last = lastQueryBounds {
            let latDiff = abs(last.northEast.latitude - bounds.northEast.latitude)
            let lonDiff = abs(last.northEast.longitude - bounds.northEast.longitude)
            if latDiff < 0.001 && lonDiff < 0.001 {
                return cachedParcels
            }
        }
        
        // We use ArcGIS for the BBOX queries as it's more efficient for spatial discovery
        let parcels = try await arcgisClient.fetchParcels(in: bounds)
        
        // Merge with cache
        mergeWithCache(parcels)
        self.lastQueryBounds = bounds
        return cachedParcels
    }

    public func fetchParcels(district: String, block: String, village: String) async throws -> [Parcel] {
        let params = Odisha4kGeoClient.CadastralParams(district: district, block: block, villageCode: village)
        
        // Fetch Parcels
        let parcels = try await odishaClient.fetchParcels(params: params)
        
        // Optionally fetch auxiliary layers (Roads, Rivers)
        let roads = try? await odishaClient.fetchRoads(params: params)
        let rivers = try? await odishaClient.fetchRivers(params: params)
        
        let allFeatures = parcels + (roads ?? []) + (rivers ?? [])
        
        // For village fetching, we might want to clear old cache to focus on this village
        self.cachedParcels = allFeatures
        return allFeatures
    }
    
    public func searchParcel(plotNumber: String) async throws -> Parcel? {
        return cachedParcels.first { $0.metadata.plotNumber == plotNumber }
    }
    
    private func mergeWithCache(_ newParcels: [Parcel]) {
        var existingIds = Set(cachedParcels.map { $0.id })
        for p in newParcels {
            if !existingIds.contains(p.id) {
                cachedParcels.append(p)
                existingIds.insert(p.id)
            }
        }
        
        if cachedParcels.count > 2000 {
            cachedParcels.removeFirst(cachedParcels.count - 2000)
        }
    }
}
