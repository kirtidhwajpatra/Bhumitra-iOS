import Foundation
import CoreLocation

public final class LocalAdminClient {
    public static let shared = LocalAdminClient()
    
    // In production, configure your app to use this Cloud Run deployment
    // private let baseURL = "http://10.251.209.242:3000" // Local fallback
    nonisolated public let baseURL = "https://odisha-admin-service-prod-758542001999.asia-south1.run.app"
    
    private init() {}
    
    public struct LocationInfo: Codable, Equatable {
        public let district: String
        public let tehsil: String
        public let panchayat: String
        public let village: String
        public let village_code: String
    }
    
    public func fetchLocationInfo(latitude: Double, longitude: Double) async throws -> LocationInfo? {
        // Step 1: Attempt to fetch from our live deployed Cloud Run Node.js App
        if let components = URLComponents(string: "\(baseURL)/location-info") {
            var urlComponents = components
            urlComponents.queryItems = [
                URLQueryItem(name: "lat", value: "\(latitude)"),
                URLQueryItem(name: "lng", value: "\(longitude)")
            ]
            
            if let url = urlComponents.url {
                do {
                    var request = URLRequest(url: url)
                    request.timeoutInterval = 3.0 // Fail fast (3s) so the user doesn't wait
                    let (data, response) = try await URLSession.shared.data(for: request)
                    
                    if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                        if let info = try? JSONDecoder().decode(LocationInfo.self, from: data) {
                            return info
                        }
                    }
                } catch {
                    print("DEBUG: ⚠️ Cloud Run backend failed or timed out. Falling back to Apple Maps.")
                }
            }
        }
        
        // Step 2: Native ZERO-DOWNTIME fallback using Apple's integrated database 
        // Highly approved by Apple Reviewers and requires no backend database.
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: latitude, longitude: longitude)
        
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            guard let placemark = placemarks.first else { return nil }
            
            return LocationInfo(
                district: placemark.subAdministrativeArea ?? placemark.administrativeArea ?? "Unknown District",
                tehsil: placemark.locality ?? placemark.subAdministrativeArea ?? "Unknown Tehsil",
                panchayat: placemark.subLocality ?? "Unknown Panchayat",
                village: placemark.name ?? placemark.subLocality ?? "Unknown Village",
                village_code: placemark.postalCode ?? "N/A"
            )
        } catch {
            print("DEBUG: ❌ Apple Native Geocoder also failed.")
            return nil
        }
    }
}
