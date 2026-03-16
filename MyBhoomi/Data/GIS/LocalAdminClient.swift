import Foundation

public final class LocalAdminClient {
    public static let shared = LocalAdminClient()
    
    private let baseURL = "http://10.251.209.242:3000"
    
    private init() {}
    
    public struct LocationInfo: Codable, Equatable {
        public let district: String
        public let tehsil: String
        public let panchayat: String
        public let village: String
        public let village_code: String
    }
    
    public func fetchLocationInfo(latitude: Double, longitude: Double) async throws -> LocationInfo? {
        var components = URLComponents(string: "\(baseURL)/location-info")!
        components.queryItems = [
            URLQueryItem(name: "lat", value: "\(latitude)"),
            URLQueryItem(name: "lng", value: "\(longitude)")
        ]
        
        guard let url = components.url else { return nil }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else { return nil }
        
        if httpResponse.statusCode == 404 {
            return nil
        }
        
        if httpResponse.statusCode != 200 {
            throw NSError(domain: "LocalAdminClient", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server error"])
        }
        
        return try JSONDecoder().decode(LocationInfo.self, from: data)
    }
}
