import Foundation

public protocol StorageServiceProtocol {
    func saveParcels(_ parcels: [Parcel]) throws
    func loadParcels() throws -> [Parcel]
}

public final class LocalParcelStorage: StorageServiceProtocol {
    public init() {}
    public func saveParcels(_ parcels: [Parcel]) throws {}
    public func loadParcels() throws -> [Parcel] { return [] }
}
