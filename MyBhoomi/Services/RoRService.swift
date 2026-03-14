import Foundation

// MARK: - RoR Networking Service

enum RoRError: LocalizedError {
    case missingMetadata(String)
    case networkError(Error)
    case serverError(Int, String)
    case decodingError(Error)
    case noOwnersFound
    
    var errorDescription: String? {
        switch self {
        case .missingMetadata(let field):
            return "Missing parcel field: \(field). Cannot look up owner details."
        case .networkError(let e):
            if (e as? URLError)?.code == .timedOut {
                return "Bhulekh service is responding slowly. Please try again in a moment."
            }
            return "Network error: \(e.localizedDescription)"
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message)"
        case .decodingError(let e):
            return "Data parsing error: \(e.localizedDescription)"
        case .noOwnersFound:
            return "No owner data found for this plot on Bhulekh."
        }
    }
}

actor RoRService {
    
    // MARK: - Configuration
    // In production, set this via your app config or environment variable
    // For local dev, backend runs at localhost:8000
    #if DEBUG
    // Use your machine's local IP to work on physical devices (ensure they are on the same Wi-Fi)
    private let baseURL = "http://127.0.0.1:8000/api/v1" 
    // private let baseURL = "http://localhost:8000/api/v1" // For simulator
    #else
    private let baseURL = "https://your-production-server.com/api/v1"
    #endif
    
    static let shared = RoRService()
    private init() {}
    
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 90 // Increased to 90s for exhaustive Bhulekh searches
        config.timeoutIntervalForResource = 120
        return URLSession(configuration: config)
    }()
    
    // MARK: - Public API
    
    func fetchOwnerDetails(for parcel: Parcel) async throws -> RoRResponse {
        let (district, tahasil, village, plot, bId, vId) = try prepareParams(for: parcel)
        return try await fetch(district: district, tahasil: tahasil, village: village, plot: plot, bId: bId, vId: vId)
    }
    
    func downloadROR(for parcel: Parcel) async throws -> URL {
        let (district, tahasil, village, plot, bId, vId) = try prepareParams(for: parcel)
        
        var components = URLComponents(string: "\(baseURL)/ror/pdf")!
        var queryItems = [
            URLQueryItem(name: "district", value: district),
            URLQueryItem(name: "tahasil", value: tahasil),
            URLQueryItem(name: "village", value: village),
            URLQueryItem(name: "plot", value: plot),
        ]
        if let bId = bId { queryItems.append(URLQueryItem(name: "b_id", value: bId)) }
        if let vId = vId { queryItems.append(URLQueryItem(name: "v_id", value: vId)) }
        
        components.queryItems = queryItems
        
        guard let url = components.url else {
            throw RoRError.networkError(URLError(.badURL))
        }
        
        let (tempURL, response) = try await session.download(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            throw RoRError.serverError((response as? HTTPURLResponse)?.statusCode ?? 500, "Failed to download PDF")
        }
        
        // Move to a more persistent temp location with .pdf extension
        let safePlot = plot.components(separatedBy: CharacterSet.alphanumerics.inverted).joined()
        let safeVillage = village.components(separatedBy: CharacterSet.alphanumerics.inverted).joined()
        let fileName = "ROR_\(safePlot)_\(safeVillage).pdf"
        let destinationURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        // Remove existing file if any
        try? FileManager.default.removeItem(at: destinationURL)
        try FileManager.default.moveItem(at: tempURL, to: destinationURL)
        
        return destinationURL
    }
    
    private func prepareParams(for parcel: Parcel) throws -> (district: String, tahasil: String, village: String, plot: String, bId: String?, vId: String?) {
        let info = parcel.metadata.additionalInfo ?? [:]
        
        let district = cleanName(info["District"] ?? info["d_name"] ?? info["d_namc"] ?? "")
        let tahasil = cleanName(info["Tahasil"] ?? info["t_name"] ?? info["t_namc"] ?? info["b_name"] ?? info["b_namc"] ?? "")
        let village = cleanName(info["Village"] ?? info["v_name"] ?? info["v_namc"] ?? "")
        
        guard !district.isEmpty, district != "N/A" else { throw RoRError.missingMetadata("District") }
        guard !tahasil.isEmpty, tahasil != "N/A" else { throw RoRError.missingMetadata("Tahasil") }
        guard !village.isEmpty, village != "N/A" else { throw RoRError.missingMetadata("Village") }
        
        let plot = parcel.metadata.plotNumber
        guard !plot.isEmpty, plot != "N/A" else { throw RoRError.missingMetadata("Plot Number") }
        
        let bId = info["b_id"]
        let vId = info["v_id"]
        
        return (district, tahasil, village, plot, bId, vId)
    }
    
    /// Cleans names by stripping technical GIS suffixes like _Mosaic, _WGS84, etc.
    private func cleanName(_ name: String) -> String {
        var cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove common GIS suffixes
        let patterns = [
            "_Mosaic", "_WGS84", "_UTM", "_Layer", "_Boundary", "_Polygon",
            "_mosaic", "_wgs84", "_utm", "_layer", "_boundary", "_polygon"
        ]
        
        for pattern in patterns {
            if cleaned.hasSuffix(pattern) {
                cleaned = String(cleaned.dropLast(pattern.count))
            }
        }
        
        // Remove trailing numbers preceded by underscore (e.g. Village_123)
        if let lastUnderscore = cleaned.lastIndex(of: "_") {
            let suffix = cleaned[cleaned.index(after: lastUnderscore)...]
            if suffix.allSatisfy({ $0.isNumber }) {
                cleaned = String(cleaned[..<lastUnderscore])
            }
        }
        
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Internal
    
    private func fetch(district: String, tahasil: String, village: String, plot: String, bId: String?, vId: String?) async throws -> RoRResponse {
        var components = URLComponents(string: "\(baseURL)/ror")!
        var queryItems = [
            URLQueryItem(name: "district", value: district),
            URLQueryItem(name: "tahasil", value: tahasil),
            URLQueryItem(name: "village", value: village),
            URLQueryItem(name: "plot", value: plot),
        ]
        
        if let bId = bId {
            queryItems.append(URLQueryItem(name: "b_id", value: bId))
        }
        if let vId = vId {
            queryItems.append(URLQueryItem(name: "v_id", value: vId))
        }
        
        components.queryItems = queryItems
        
        guard let url = components.url else {
            throw RoRError.networkError(URLError(.badURL))
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw RoRError.networkError(error)
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw RoRError.networkError(URLError(.badServerResponse))
        }
        
        guard (200..<300).contains(httpResponse.statusCode) else {
            // Try to extract error message from backend JSON
            let errorMessage = (try? JSONDecoder().decode([String: String].self, from: data))?["detail"] ?? "Unknown error"
            throw RoRError.serverError(httpResponse.statusCode, errorMessage)
        }
        
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(RoRResponse.self, from: data)
        } catch {
            throw RoRError.decodingError(error)
        }
    }
}
