import Foundation

/// `nonisolated` keeps this stateless repository off the MainActor (and off the
/// isolated-deinit teardown path that crashes under default MainActor isolation).
/// It is owned exclusively by `MapViewModel`, so access stays serialized.
public nonisolated final class ParcelRepository: ParcelRepositoryProtocol {
    private let geoJSONService: GeoJSONService
    private var cachedParcels: [Parcel] = []
    
    public init(geoJSONService: GeoJSONService = GeoJSONService()) {
        self.geoJSONService = geoJSONService
    }
    
    public func fetchParcels() async throws -> [Parcel] {
        return cachedParcels
    }
    
    public func fetchParcels(in bounds: GeoBounds) async throws -> [Parcel] {
        // For static data, we just filter the local set
        let all = try await fetchParcels()
        return all.filter { parcel in
            parcel.boundary.contains { coord in
                coord.latitude <= bounds.northEast.latitude &&
                coord.latitude >= bounds.southWest.latitude &&
                coord.longitude <= bounds.northEast.longitude &&
                coord.longitude >= bounds.southWest.longitude
            }
        }
    }
    
    public func searchParcel(plotNumber: String) async throws -> Parcel? {
        let all = try await fetchParcels()
        return all.first { $0.metadata.plotNumber == plotNumber }
    }
    
    public func fetchParcels(district: String, block: String, village: String) async throws -> [Parcel] {
        // Static data source currently doesn't store district/block/village mapping per parcel
        // Returning full set for now to maintain protocol conformance
        return try await fetchParcels()
    }
}
