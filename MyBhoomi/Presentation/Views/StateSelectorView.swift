import SwiftUI

public struct StateDetails: Identifiable, Codable, Equatable {
    public let id: String // State Code (e.g. "MH")
    public let name: String
    public let latitude: Double
    public let longitude: Double
    public let latDelta: Double
    public let lonDelta: Double
    public let color: Color
    
    enum CodingKeys: String, CodingKey {
        case id, name, latitude, longitude, latDelta, lonDelta
    }
    
    public init(id: String, name: String, latitude: Double, longitude: Double, latDelta: Double = 3.0, lonDelta: Double = 3.0, color: Color) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.latDelta = latDelta
        self.lonDelta = lonDelta
        self.color = color
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.latitude = try container.decode(Double.self, forKey: .latitude)
        self.longitude = try container.decode(Double.self, forKey: .longitude)
        self.latDelta = try container.decode(Double.self, forKey: .latDelta)
        self.lonDelta = try container.decode(Double.self, forKey: .lonDelta)
        // Recover a default color based on ID
        self.color = StateDetails.colorForState(id: id)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(latitude, forKey: .latitude)
        try container.encode(longitude, forKey: .longitude)
        try container.encode(latDelta, forKey: .latDelta)
        try container.encode(lonDelta, forKey: .lonDelta)
    }
    
    private static func colorForState(id: String) -> Color {
        let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .indigo, .teal, .red]
        let hash = abs(id.hashValue)
        return colors[hash % colors.count]
    }
    
    public static let allStates: [StateDetails] = [
        StateDetails(id: "MH", name: "Maharashtra", latitude: 19.7515, longitude: 75.7139, color: .orange),
        StateDetails(id: "OD", name: "Odisha", latitude: 21.6289, longitude: 85.5817, color: .purple), // Centered on Keonjhar region
        StateDetails(id: "KA", name: "Karnataka", latitude: 15.3173, longitude: 75.7139, color: .blue),
        StateDetails(id: "DL", name: "Delhi", latitude: 28.7041, longitude: 77.1025, color: .red),
        StateDetails(id: "TN", name: "Tamil Nadu", latitude: 11.1271, longitude: 78.6569, color: .indigo),
        StateDetails(id: "UP", name: "Uttar Pradesh", latitude: 26.8467, longitude: 80.9462, color: .green),
        StateDetails(id: "WB", name: "West Bengal", latitude: 22.9868, longitude: 87.8550, color: .teal),
        StateDetails(id: "GJ", name: "Gujarat", latitude: 22.2587, longitude: 71.1924, color: .pink),
        StateDetails(id: "RJ", name: "Rajasthan", latitude: 27.0238, longitude: 74.2179, color: .indigo),
        StateDetails(id: "KL", name: "Kerala", latitude: 10.8505, longitude: 76.2711, color: .teal),
        StateDetails(id: "AP", name: "Andhra Pradesh", latitude: 15.9129, longitude: 79.7400, color: .blue),
        StateDetails(id: "TG", name: "Telangana", latitude: 18.1124, longitude: 79.0193, color: .orange),
        StateDetails(id: "MP", name: "Madhya Pradesh", latitude: 22.9734, longitude: 78.6569, color: .purple),
        StateDetails(id: "BR", name: "Bihar", latitude: 25.0961, longitude: 85.3131, color: .red),
        StateDetails(id: "PB", name: "Punjab", latitude: 31.1471, longitude: 75.3412, color: .green),
        StateDetails(id: "HR", name: "Haryana", latitude: 29.0588, longitude: 76.0856, color: .orange),
        StateDetails(id: "JK", name: "Jammu & Kashmir", latitude: 33.7780, longitude: 76.5762, color: .blue),
        StateDetails(id: "LA", name: "Ladakh", latitude: 34.1526, longitude: 77.5770, color: .purple),
        StateDetails(id: "HP", name: "Himachal Pradesh", latitude: 31.1048, longitude: 77.1734, color: .pink),
        StateDetails(id: "UK", name: "Uttarakhand", latitude: 30.0668, longitude: 79.0193, color: .green),
        StateDetails(id: "JH", name: "Jharkhand", latitude: 23.6913, longitude: 85.2722, color: .orange),
        StateDetails(id: "CG", name: "Chhattisgarh", latitude: 21.2787, longitude: 81.8661, color: .teal),
        StateDetails(id: "AS", name: "Assam", latitude: 26.2006, longitude: 92.9376, color: .green),
        StateDetails(id: "AR", name: "Arunachal Pradesh", latitude: 28.2180, longitude: 94.7278, color: .pink),
        StateDetails(id: "NL", name: "Nagaland", latitude: 26.1584, longitude: 94.5624, color: .purple),
        StateDetails(id: "MN", name: "Manipur", latitude: 24.6637, longitude: 93.9063, color: .blue),
        StateDetails(id: "MZ", name: "Mizoram", latitude: 23.1645, longitude: 92.9376, color: .red),
        StateDetails(id: "TR", name: "Tripura", latitude: 23.9408, longitude: 91.9882, color: .orange),
        StateDetails(id: "ML", name: "Meghalaya", latitude: 25.4670, longitude: 91.3662, color: .indigo),
        StateDetails(id: "SK", name: "Sikkim", latitude: 27.5330, longitude: 88.5122, color: .pink),
        StateDetails(id: "GA", name: "Goa", latitude: 15.2993, longitude: 74.1240, color: .blue),
        StateDetails(id: "PY", name: "Puducherry", latitude: 11.9416, longitude: 79.8083, color: .teal),
        StateDetails(id: "CH", name: "Chandigarh", latitude: 30.7333, longitude: 76.7794, color: .green),
        StateDetails(id: "DN", name: "Dadra & Nagar Haveli", latitude: 20.1809, longitude: 73.0169, color: .orange),
        StateDetails(id: "LD", name: "Lakshadweep", latitude: 10.5667, longitude: 72.6417, color: .blue),
        StateDetails(id: "AN", name: "Andaman & Nicobar", latitude: 11.7401, longitude: 92.6586, color: .purple)
    ]
}

