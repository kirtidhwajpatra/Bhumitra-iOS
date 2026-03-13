import Foundation
import CoreLocation

public struct Coordinate: Codable, Equatable {
    public let latitude: Double
    public let longitude: Double
    
    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

public struct ParcelMetadata: Codable, Equatable {
    public let plotNumber: String
    public let area: Double
    public let areaUnit: String
    public let ownerName: String?
    public let landUseType: String?
    public let additionalInfo: [String: String]?
    
    public init(plotNumber: String, 
                area: Double, 
                areaUnit: String = "sqm", 
                ownerName: String? = nil, 
                landUseType: String? = nil, 
                additionalInfo: [String: String]? = nil) {
        self.plotNumber = plotNumber
        self.area = area
        self.areaUnit = areaUnit
        self.ownerName = ownerName
        self.landUseType = landUseType
        self.additionalInfo = additionalInfo
    }
}

public struct Parcel: Identifiable, Equatable {
    public let id: String
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
    
    public init(id: String = UUID().uuidString, 
                boundary: [Coordinate], 
                metadata: ParcelMetadata) {
        self.id = id
        self.boundary = boundary
        self.metadata = metadata
    }
    
    public static func == (lhs: Parcel, rhs: Parcel) -> Bool {
        return lhs.id == rhs.id
    }
}
