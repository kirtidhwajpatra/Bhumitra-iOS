import Foundation

public final class ParcelRepository: ParcelRepositoryProtocol {
    private let arcgisClient: ArcGISClient
    private var cachedParcels: [Parcel] = []
    private var lastQueryBounds: GeoBounds?
    
    public init(arcgisClient: ArcGISClient = ArcGISClient.shared) {
        self.arcgisClient = arcgisClient
    }
    
    public func fetchParcels() async throws -> [Parcel] {
        // Return cached parcels if available, otherwise fetch for a default wide area
        if !cachedParcels.isEmpty { return cachedParcels }
        
        let defaultBounds = GeoBounds(
            northEast: Coordinate(latitude: 21.65, longitude: 85.60),
            southWest: Coordinate(latitude: 21.60, longitude: 85.55)
        )
        return try await fetchParcels(in: defaultBounds)
    }
    
    public func fetchParcels(in bounds: GeoBounds) async throws -> [Parcel] {
        // Simple throttling/debounce check: if the new bounds are very close to last, skip
        if let last = lastQueryBounds {
            let latDiff = abs(last.northEast.latitude - bounds.northEast.latitude)
            let lonDiff = abs(last.northEast.longitude - bounds.northEast.longitude)
            if latDiff < 0.001 && lonDiff < 0.001 {
                return cachedParcels
            }
        }
        
        let parcels = try await arcgisClient.fetchParcels(in: bounds)
        
        // Merge with cache to prevent flickering
        var newCache = cachedParcels
        for p in parcels {
            if !newCache.contains(where: { $0.id == p.id }) {
                newCache.append(p)
            }
        }
        
        // Limit cache size to prevent memory issues
        if newCache.count > 1000 {
            newCache.removeFirst(newCache.count - 1000)
        }
        
        self.cachedParcels = newCache
        self.lastQueryBounds = bounds
        return newCache
    }
    
    public func searchParcel(plotNumber: String) async throws -> Parcel? {
        // For search, we still look in the local cache or we could implement a global search query to ArcGIS
        return cachedParcels.first { $0.metadata.plotNumber == plotNumber }
    }
}
