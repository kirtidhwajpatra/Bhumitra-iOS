import Foundation

// MARK: - RoR Networking Service

enum RoRError: LocalizedError, Equatable {
    case missingMetadata(String)
    case notFound(String)
    case identityMismatch(String)
    case temporarilyUnavailable(String)
    case timeout(String)
    case pdfFailed(String)
    case networkError(String)
    case serverError(Int, String)
    case decodingError(String)
    case noOwnersFound
    case usageLimitExceeded(String)
    
    var errorDescription: String? {
        switch self {
        case .missingMetadata(let field):
            return "Missing parcel field: \(field). Cannot look up owner details."
        case .notFound(let msg):
            return msg.isEmpty ? "No official RoR record was found for this land identity." : msg
        case .identityMismatch(let msg):
            return msg.isEmpty ? "We could not safely verify that this official record matches this exact parcel." : msg
        case .temporarilyUnavailable(let msg):
            return msg.isEmpty ? "The official Bhulekh lookup service is temporarily unavailable. Please try again." : msg
        case .timeout(let msg):
            return msg.isEmpty ? "Official Bhulekh service took too long to respond. Please try again." : msg
        case .pdfFailed(let msg):
            return msg.isEmpty ? "Ownership record found, but the PDF could not be downloaded." : msg
        case .networkError(let msg):
            return "Network connection issue: \(msg)"
        case .serverError(let code, let message):
            if code >= 500 {
                return "The Bhulekh lookup service is temporarily unavailable. Please try again later."
            }
            return "Server error (\(code)): \(message)"
        case .decodingError(let msg):
            return "Data parsing error: \(msg)"
        case .noOwnersFound:
            return "No owner data found for this plot on Bhulekh."
        case .usageLimitExceeded(let message):
            return message
        }
    }
    
    var isRetryable: Bool {
        switch self {
        case .temporarilyUnavailable, .timeout, .pdfFailed, .networkError:
            return true
        case .serverError(let code, _):
            return code >= 500
        case .notFound, .identityMismatch, .missingMetadata, .decodingError, .noOwnersFound, .usageLimitExceeded:
            return false
        }
    }
    
    static func == (lhs: RoRError, rhs: RoRError) -> Bool {
        return lhs.localizedDescription == rhs.localizedDescription
    }
}

public struct LastRoRDiagnosticInfo: Sendable {
    public let requestURL: String
    public let httpStatus: Int
    public let requestID: String
    public let rawJSONString: String
    public let timestamp: Date
}

actor RoRService {
    
    // MARK: - Configuration
    nonisolated public var baseURL: String {
        APIConfiguration.shared.baseURL
    }
    
    static let shared = RoRService()
    private init() {}
    
    private var rorCache: [String: RoRResponse] = [:]
    
    @MainActor public var lastDiagnosticInfo: LastRoRDiagnosticInfo? = nil
    
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 90 // Increased to 90s for exhaustive Bhulekh searches
        config.timeoutIntervalForResource = 120
        return URLSession(configuration: config)
    }()
    
    // MARK: - Public API
    
    public func checkBackendVersion() async {
        let urlString = "\(baseURL)/version"
        print("[API] Base URL: \(baseURL)")
        print("[API] Version endpoint: \(urlString)")
        guard let url = URL(string: urlString) else { return }
        do {
            let (data, response) = try await session.data(from: url)
            if let http = response as? HTTPURLResponse, http.statusCode == 200,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                print("[API] Backend version: \(json["phase"] ?? "unknown")")
                print("[API] Git commit: \(json["git_commit"] ?? "unknown")")
                print("[API] Catalog version: \(json["catalog_version"] ?? "unknown")")
            } else {
                print("[API] Backend version check returned non-200 or invalid json")
            }
        } catch {
            print("[API] Failed to check backend version: \(error.localizedDescription)")
        }
    }
    
    func fetchOwnerDetails(for parcel: Parcel) async throws -> RoRResponse {
        await checkBackendVersion()
        print("""
        [RoR IDENTITY]
        plot: \(parcel.identity.plotNumber)
        district_id: \(parcel.identity.districtID ?? "nil")
        block_id: \(parcel.identity.tahasilID ?? "nil")
        village_id: \(parcel.identity.villageID ?? "nil")
        village_name: \(parcel.identity.villageName)
        source_feature_id: \(parcel.identity.parcelID)
        """)
        let (district, tahasil, village, plot, bId, vId) = try prepareParams(for: parcel)
        return try await fetch(district: district, tahasil: tahasil, village: village, plot: plot, bId: bId, vId: vId)
    }
    
    func downloadROR(for parcel: Parcel, khataNumber: String? = nil) async throws -> (url: URL, metadata: PDFDocumentMetadata, isOfflineSaved: Bool) {
        let (district, tahasil, village, plot, bId, vId) = try prepareParams(for: parcel)
        return try await downloadROR(district: district, tahasil: tahasil, village: village, plot: plot, khataNumber: khataNumber, bId: bId, vId: vId)
    }
    
    func downloadROR(district: String, tahasil: String, village: String, plot: String, khataNumber: String? = nil, bId: String? = nil, vId: String? = nil) async throws -> (url: URL, metadata: PDFDocumentMetadata, isOfflineSaved: Bool) {

        var components = URLComponents(string: "\(baseURL)/ror/pdf")!
        var queryItems = [
            URLQueryItem(name: "district", value: district),
            URLQueryItem(name: "tahasil", value: tahasil),
            URLQueryItem(name: "village", value: village),
            URLQueryItem(name: "plot", value: plot),
        ]
        if let khata = khataNumber { queryItems.append(URLQueryItem(name: "khata", value: khata)) }
        if let bId = bId { queryItems.append(URLQueryItem(name: "b_id", value: bId)) }
        if let vId = vId { queryItems.append(URLQueryItem(name: "v_id", value: vId)) }

        components.queryItems = queryItems

        guard let url = components.url else {
            throw RoRError.networkError("Invalid URL configuration")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        if let token = await MainActor.run(body: { AuthManager.shared.bearerToken }) {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (tempURL, response): (URL, URLResponse)
        do {
            (tempURL, response) = try await session.download(for: request)
        } catch {
            throw RoRError.networkError(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw RoRError.networkError("Bad server response")
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 403 {
                throw RoRError.usageLimitExceeded("You have reached your free monthly PDF download limit. Please upgrade to Bhumitra Premium.")
            }
            if httpResponse.statusCode == 404 {
                throw RoRError.notFound("No official RoR PDF found for this plot.")
            }
            if httpResponse.statusCode == 502 || httpResponse.statusCode == 500 {
                throw RoRError.pdfFailed("Official RoR record found, but the PDF could not be downloaded.")
            }
            throw RoRError.serverError(httpResponse.statusCode, "Failed to download PDF")
        }

        let expectedSHA256 = httpResponse.value(forHTTPHeaderField: "X-Bhumitra-Document-SHA256")

        let stored = try await PDFDocumentManager.shared.validateAndStore(
            tempURL: tempURL,
            district: district,
            tahasil: tahasil,
            village: village,
            plot: plot,
            khata: khataNumber,
            vId: vId,
            expectedSHA256: expectedSHA256
        )

        return (stored.url, stored.metadata, false)
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
        
        let district = identity.districtName.trimmingCharacters(in: .whitespacesAndNewlines)
        let tahasil = identity.tahasilName.trimmingCharacters(in: .whitespacesAndNewlines)
        let village = identity.villageName.trimmingCharacters(in: .whitespacesAndNewlines)
        let plot = identity.plotNumber.trimmingCharacters(in: .whitespacesAndNewlines)
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
    
    func fetch(district: String, tahasil: String, village: String, plot: String, bId: String?, vId: String?) async throws -> RoRResponse {
        let dKey = district.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let tKey = (bId ?? tahasil).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let vKey = (vId ?? village).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let pKey = plot.trimmingCharacters(in: .whitespacesAndNewlines)
        let cacheKey = "\(dKey):\(tKey):\(vKey):\(pKey)"
        
        if let cached = rorCache[cacheKey] {
            print("[RoR CACHE HIT] Instant lookup for \(cacheKey)")
            return cached
        }
        
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
            throw RoRError.networkError("Invalid URL configuration")
        }
        
        print("[RoR DEBUG] request URL: \(url.absoluteString), district: \(district), tahasil: \(tahasil), village: \(village), plot: \(plot), b_id: \(bId ?? "nil"), v_id: \(vId ?? "nil")")

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
            let reqId = "error"
            await MainActor.run {
                self.lastDiagnosticInfo = LastRoRDiagnosticInfo(
                    requestURL: url.absoluteString,
                    httpStatus: 0,
                    requestID: reqId,
                    rawJSONString: "Network Error: \(error.localizedDescription)",
                    timestamp: Date()
                )
            }
            if (error as? URLError)?.code == .timedOut {
                throw RoRError.timeout("Bhulekh service is responding slowly. Please try again.")
            }
            throw RoRError.networkError(error.localizedDescription)
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw RoRError.networkError("Invalid server response")
        }
        
        let rawString = String(data: data, encoding: .utf8) ?? "<non-utf8 data: \(data.count) bytes>"
        let reqId = httpResponse.value(forHTTPHeaderField: "X-Request-ID") ?? "none"
        await MainActor.run {
            self.lastDiagnosticInfo = LastRoRDiagnosticInfo(
                requestURL: url.absoluteString,
                httpStatus: httpResponse.statusCode,
                requestID: reqId,
                rawJSONString: rawString,
                timestamp: Date()
            )
        }
        
        print("[RoR DEBUG] response HTTP status: \(httpResponse.statusCode), body length: \(data.count)")
        
        guard (200..<300).contains(httpResponse.statusCode) else {
            // Check for structured RoRErrorPayload
            if let errorPayload = try? JSONDecoder().decode([String: RoRErrorPayload].self, from: data),
               let detail = errorPayload["detail"], let code = detail.code {
                switch code {
                case "USAGE_LIMIT_EXCEEDED":
                    throw RoRError.usageLimitExceeded(detail.message ?? "Monthly usage limit reached.")
                case "ROR_NOT_FOUND":
                    throw RoRError.notFound(detail.message ?? "No official record found for this land parcel.")
                case "ROR_IDENTITY_MISMATCH":
                    throw RoRError.identityMismatch(detail.message ?? "Record could not be verified for this exact parcel.")
                case "BHULEKH_TIMEOUT":
                    throw RoRError.timeout(detail.message ?? "Official service timed out.")
                case "BHULEKH_TEMPORARY_UNAVAILABLE":
                    throw RoRError.temporarilyUnavailable(detail.message ?? "Official service temporarily unavailable.")
                case "PDF_GENERATION_FAILED":
                    throw RoRError.pdfFailed(detail.message ?? "Failed to generate PDF.")
                default:
                    throw RoRError.serverError(httpResponse.statusCode, detail.message ?? "Server error (\(httpResponse.statusCode))")
                }
            }
            
            // Check for plain string detail JSON
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let detailStr = json["detail"] as? String {
                    if httpResponse.statusCode == 404 {
                        throw RoRError.notFound(detailStr)
                    }
                    if httpResponse.statusCode == 422 {
                        throw RoRError.identityMismatch(detailStr)
                    }
                    if httpResponse.statusCode == 503 {
                        throw RoRError.temporarilyUnavailable(detailStr)
                    }
                    if httpResponse.statusCode == 504 {
                        throw RoRError.timeout(detailStr)
                    }
                    throw RoRError.serverError(httpResponse.statusCode, detailStr)
                }
            }
            
            if httpResponse.statusCode == 404 {
                throw RoRError.notFound("No official RoR record was found for this plot.")
            }
            if httpResponse.statusCode == 503 {
                throw RoRError.temporarilyUnavailable("Official Bhulekh service is temporarily unavailable.")
            }
            if httpResponse.statusCode == 504 {
                throw RoRError.timeout("Bhulekh service timed out.")
            }
            throw RoRError.serverError(httpResponse.statusCode, "Server error (\(httpResponse.statusCode))")
        }
        
        do {
            let decoder = JSONDecoder()
            let decoded = try decoder.decode(RoRResponse.self, from: data)
            // Store in cache strictly and exclusively for this verified plot
            if decoded.verification?.status == .verified {
                rorCache[cacheKey] = decoded
            }
            
            return decoded
        } catch {
            throw RoRError.decodingError(error.localizedDescription)
        }
    }
    
    // MARK: - Location Hierarchy API
    
    func fetchDistricts() async throws -> [BhulekhDistrict] {
        guard let url = URL(string: "\(baseURL)/districts") else {
            throw RoRError.networkError("Invalid URL configuration")
        }
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw RoRError.serverError(500, "Failed to load district hierarchy")
        }
        return try JSONDecoder().decode([BhulekhDistrict].self, from: data)
    }
    
    func fetchTahasils(districtID: String) async throws -> [BhulekhTahasil] {
        var comps = URLComponents(string: "\(baseURL)/tahasils")!
        comps.queryItems = [URLQueryItem(name: "district_id", value: districtID)]
        guard let url = comps.url else { throw RoRError.networkError("Invalid URL configuration") }
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw RoRError.serverError(500, "Failed to load tahasil hierarchy")
        }
        return try JSONDecoder().decode([BhulekhTahasil].self, from: data)
    }
    
    func fetchVillages(districtID: String, tahasilID: String) async throws -> [BhulekhVillage] {
        var comps = URLComponents(string: "\(baseURL)/villages")!
        comps.queryItems = [
            URLQueryItem(name: "district_id", value: districtID),
            URLQueryItem(name: "tahasil_id", value: tahasilID)
        ]
        guard let url = comps.url else { throw RoRError.networkError("Invalid URL configuration") }
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw RoRError.serverError(500, "Failed to load village hierarchy")
        }
        return try JSONDecoder().decode([BhulekhVillage].self, from: data)
    }
    
    func fetchRICircles(districtID: String, tahasilID: String) async throws -> [BhulekhRICircle] {
        var comps = URLComponents(string: "\(baseURL)/ri-circles")!
        comps.queryItems = [
            URLQueryItem(name: "district_id", value: districtID),
            URLQueryItem(name: "tahasil_id", value: tahasilID)
        ]
        guard let url = comps.url else { throw RoRError.networkError("Invalid URL configuration") }
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw RoRError.serverError(500, "Failed to load RI Circle hierarchy")
        }
        return try JSONDecoder().decode([BhulekhRICircle].self, from: data)
    }
}
