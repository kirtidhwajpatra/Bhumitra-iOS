import Foundation

// MARK: - RoR Networking Service

enum RoRError: LocalizedError {
    case missingMetadata(String)
    case networkError(Error)
    case serverError(Int, String)
    case decodingError(Error)
    case noOwnersFound
    case usageLimitExceeded(String)
    
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
            if code >= 500 {
                return "The Bhulekh lookup service is temporarily unavailable. Please try again later."
            }
            return "Server error (\(code)): \(message)"
        case .decodingError(let e):
            return "Data parsing error: \(e.localizedDescription)"
        case .noOwnersFound:
            return "No owner data found for this plot on Bhulekh."
        case .usageLimitExceeded(let message):
            return message
        }
    }
}

actor RoRService {
    
    // MARK: - Configuration
    // Defaults to the production backend so DEBUG builds also show real Bhulekh data.
    // For local backend development, set MYBHOOMI_API_BASE in the Xcode scheme's
    // environment variables (e.g. http://127.0.0.1:8000/api/v1).
    nonisolated public var baseURL: String {
        APIConfiguration.shared.baseURL
    }
    
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
        
        let safePlot = plot.components(separatedBy: CharacterSet.alphanumerics.inverted).joined()
        let safeVillage = village.components(separatedBy: CharacterSet.alphanumerics.inverted).joined()
        let fileName = "ROR_\(safePlot)_\(safeVillage).pdf"
        let destinationURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

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

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        if let token = await MainActor.run(body: { AuthManager.shared.bearerToken }) {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (tempURL, response) = try await session.download(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw RoRError.networkError(URLError(.badServerResponse))
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 403 {
                throw RoRError.usageLimitExceeded("You have reached your free monthly PDF download limit. Please upgrade to Bhumitra Premium.")
            }
            throw RoRError.serverError(httpResponse.statusCode, "Failed to download PDF")
        }

        // Remove existing file if any
        try? FileManager.default.removeItem(at: destinationURL)
        try FileManager.default.moveItem(at: tempURL, to: destinationURL)

        return destinationURL
    }
    
    private func prepareParams(for parcel: Parcel) throws -> (district: String, tahasil: String, village: String, plot: String, bId: String?, vId: String?) {
        let identity = parcel.identity
        
        guard identity.isFullyResolved else {
            if identity.districtName.isEmpty || identity.districtName == "N/A" {
                throw RoRError.missingMetadata("District")
            }
            if identity.tahasilName.isEmpty || identity.tahasilName == "N/A" {
                throw RoRError.missingMetadata("Tahasil")
            }
            if identity.villageName.isEmpty || identity.villageName == "N/A" {
                throw RoRError.missingMetadata("Village")
            }
            throw RoRError.missingMetadata("Plot Number")
        }
        
        let district = cleanName(identity.districtName)
        let tahasil = cleanName(identity.tahasilName)
        let village = cleanName(identity.villageName)
        let plot = identity.plotNumber
        let bId = identity.tahasilID
        let vId = identity.villageID
        
        return (district, tahasil, village, plot, bId, vId)
    }
    
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
        
        // Remove short alphanumeric prefixes before underscore (e.g., Un24_Collegechhak -> Collegechhak)
        if let match = cleaned.range(of: "^[A-Za-z0-9]{1,5}_", options: .regularExpression) {
            cleaned.removeSubrange(match)
        }
        
        // Remove trailing numbers preceded by underscore (e.g. Village_123 -> Village)
        if let match = cleaned.range(of: "_\\d+$", options: .regularExpression) {
            cleaned.removeSubrange(match)
        }
        
        // Replace remaining underscores with spaces (e.g. Cuttack_Sadar -> Cuttack Sadar)
        cleaned = cleaned.replacingOccurrences(of: "_", with: " ")
        
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
        if let token = await MainActor.run(body: { AuthManager.shared.bearerToken }) {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
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
            // Check for structured usage quota / rate limit errors
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let detailObj = json["detail"] as? [String: Any],
                   let errorType = detailObj["error"] as? String, errorType == "usage_limit_exceeded" {
                    let msg = detailObj["message"] as? String ?? "You have reached your free monthly RoR lookup limit."
                    throw RoRError.usageLimitExceeded(msg)
                }
                if let detailStr = json["detail"] as? String {
                    throw RoRError.serverError(httpResponse.statusCode, detailStr)
                }
            }
            throw RoRError.serverError(httpResponse.statusCode, "Server error (\(httpResponse.statusCode))")
        }
        
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(RoRResponse.self, from: data)
        } catch {
            throw RoRError.decodingError(error)
        }
    }
}
