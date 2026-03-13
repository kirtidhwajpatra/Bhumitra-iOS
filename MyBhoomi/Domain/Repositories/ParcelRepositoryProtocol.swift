import Foundation

public protocol ParcelRepositoryProtocol {
    func fetchParcels() async throws -> [Parcel]
    func fetchParcels(in bounds: GeoBounds) async throws -> [Parcel]
    func fetchParcels(district: String, block: String, village: String) async throws -> [Parcel]
    func searchParcel(plotNumber: String) async throws -> Parcel?
}

public struct GeoBounds {
    public let northEast: Coordinate
    public let southWest: Coordinate
    
    public init(northEast: Coordinate, southWest: Coordinate) {
        self.northEast = northEast
        self.southWest = southWest
    }
}

public struct OdishaVillage: Codable, Identifiable {
    public var id: String { code }
    public let district: String
    public let block: String
    public let name: String
    public let code: String
}
