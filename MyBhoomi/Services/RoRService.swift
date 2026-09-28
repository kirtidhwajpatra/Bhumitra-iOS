import Foundation

// MARK: - RoR Networking Service

public enum RoRError: LocalizedError, Equatable, Sendable {
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
    
    public var errorDescription: String? {
        switch self {
        case .missingMetadata(let field):
            return "Missing parcel field: \(field). Cannot look up owner details."
        case .notFound(let msg):
            return msg.isEmpty ? "No official RoR record was found for this land identity." : msg
        case .identityMismatch(let msg):
            return msg.isEmpty ? "We could not safely verify that this official record matches this exact parcel." : msg
        case .temporarilyUnavailable(let msg):
            return msg.isEmpty ? "The official land lookup service is temporarily unavailable. Please try again." : msg
        case .timeout(let msg):
            return msg.isEmpty ? "Official land records service took too long to respond. Please try again." : msg
        case .pdfFailed(let msg):
            return msg.isEmpty ? "Ownership record found, but the PDF could not be downloaded." : msg
        case .networkError(let msg):
            return "Network connection issue: \(msg)"
        case .serverError(let code, let message):
            if code >= 500 {
                return "The land records lookup service is temporarily unavailable. Please try again later."
            }
            return "Server error (\(code)): \(message)"
        case .decodingError(let msg):
            return "Data parsing error: \(msg)"
        case .noOwnersFound:
            return "No owner data found for this plot in official records."
        case .usageLimitExceeded(let message):
            return message
        }
    }
    
    public var isRetryable: Bool {
        switch self {
        case .temporarilyUnavailable, .timeout, .pdfFailed, .networkError:
            return true
        case .serverError(let code, _):
            return code >= 500
        case .notFound, .identityMismatch, .missingMetadata, .decodingError, .noOwnersFound, .usageLimitExceeded:
            return false
        }
    }
    
    public static func == (lhs: RoRError, rhs: RoRError) -> Bool {
        return lhs.localizedDescription == rhs.localizedDescription
    }
}

public struct LastRoRDiagnosticInfo: Sendable {
    public let requestURL: String
    public let httpStatus: Int
    public let requestID: String
    public let rawJSONString: String
    public let timestamp: Date
    public let backendDurationMs: Int?
    public let upstreamDurationMs: Int?
    
    public init(
        requestURL: String,
        httpStatus: Int,
        requestID: String,
        rawJSONString: String,
        timestamp: Date,
        backendDurationMs: Int? = nil,
        upstreamDurationMs: Int? = nil
    ) {
        self.requestURL = requestURL
        self.httpStatus = httpStatus
        self.requestID = requestID
        self.rawJSONString = rawJSONString
        self.timestamp = timestamp
        self.backendDurationMs = backendDurationMs
        self.upstreamDurationMs = upstreamDurationMs
    }
}

actor RoRService {
    
    // MARK: - Configuration
    nonisolated public var baseURL: String {
        APIConfiguration.shared.baseURL
    }
    
    static let shared = RoRService()
    private init() {}
    
    private var rorCache: [String: RoRResponse] = [:]
    private var inFlightTasks: [String: Task<RoRResponse, Error>] = [:]
    
    @MainActor public var lastDiagnosticInfo: LastRoRDiagnosticInfo? = nil
    
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 55 // 55s client timeout for live portal responses
        config.timeoutIntervalForResource = 65
        return URLSession(configuration: config)
    }()
    
    // MARK: - Public API
    
    public func checkBackendVersion() async {
        let urlString = "\(baseURL)/version"
        #if DEBUG
        print("[API] Base URL: \(baseURL)")
        print("[API] Version endpoint: \(urlString)")
        #endif
        guard let url = URL(string: urlString) else { return }
        do {
            let (data, response) = try await session.data(from: url)
            if let http = response as? HTTPURLResponse, http.statusCode == 200,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                #if DEBUG
                print("[API] Backend version: \(json["phase"] ?? "unknown")")
                #endif
            }
        } catch {}
    }
    
    func fetchOwnerDetails(for parcel: Parcel) async throws -> RoRResponse {
        let (district, tahasil, village, plot, bId, vId) = try prepareParams(for: parcel)
        return try await fetch(district: district, tahasil: tahasil, village: village, plot: plot, bId: bId, vId: vId)
    }
    
    func downloadROR(for parcel: Parcel, khataNumber: String? = nil) async throws -> (url: URL, metadata: PDFDocumentMetadata, isOfflineSaved: Bool) {
        let (district, tahasil, village, plot, bId, vId) = try prepareParams(for: parcel)
        return try await downloadROR(district: district, tahasil: tahasil, village: village, plot: plot, khataNumber: khataNumber, bId: bId, vId: vId)
    }
    
    func downloadOfficialDocument(documentID: String) async throws -> (url: URL, metadata: PDFDocumentMetadata, isOfflineSaved: Bool) {
        let cleanDocID = documentID.trimmingCharacters(in: .whitespacesAndNewlines)
        let encodedDocID = cleanDocID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? cleanDocID
        guard let url = URL(string: "\(baseURL)/ror/official-document/\(encodedDocID)") else {
            throw RoRError.networkError("Invalid official document URL")
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
            if httpResponse.statusCode == 404 {
                throw RoRError.notFound("Official RoR document not found or expired.")
            }
            throw RoRError.pdfFailed("Failed to download official document.")
        }

        let parts = cleanDocID.components(separatedBy: ":")
        let plot = parts.count >= 4 ? parts[3] : "RoR"
        let village = parts.count >= 3 ? parts[2] : "Village"
        let tahasil = parts.count >= 2 ? parts[1] : "Tahasil"
        let district = parts.first ?? "District"

        let stored = try await PDFDocumentManager.shared.validateAndStore(
            tempURL: tempURL,
            district: district,
            tahasil: tahasil,
            village: village,
            plot: plot,
            khata: nil,
            vId: nil,
            expectedSHA256: nil
        )

        return (stored.url, stored.metadata, false)
    }

    func downloadROR(district: String, tahasil: String, village: String, plot: String, khataNumber: String? = nil, bId: String? = nil, vId: String? = nil, documentID: String? = nil) async throws -> (url: URL, metadata: PDFDocumentMetadata, isOfflineSaved: Bool) {
        if let docID = documentID, !docID.isEmpty {
            if let result = try? await downloadOfficialDocument(documentID: docID) {
                return result
            }
        }

        var components = URLComponents(string: "\(baseURL)/ror/pdf")!
        var queryItems = [
            URLQueryItem(name: "district", value: district),
            URLQueryItem(name: "tahasil", value: tahasil),
            URLQueryItem(name: "village", value: village),
            URLQueryItem(name: "plot", value: plot),
        ]
        if let khata = khataNumber?.trimmingCharacters(in: .whitespacesAndNewlines), !khata.isEmpty { queryItems.append(URLQueryItem(name: "khata", value: khata)) }
        if let bId = bId?.trimmingCharacters(in: .whitespacesAndNewlines), !bId.isEmpty { queryItems.append(URLQueryItem(name: "b_id", value: bId)) }
        if let vId = vId?.trimmingCharacters(in: .whitespacesAndNewlines), !vId.isEmpty { queryItems.append(URLQueryItem(name: "v_id", value: vId)) }

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
        
        var rawDistrict = identity.districtName
        var rawTahasil = identity.tahasilName
        let rawVillage = identity.villageName
        let rawPlot = identity.plotNumber
        
        let villID = identity.villageID ?? ""
        if (rawDistrict.isEmpty || rawDistrict == "Odisha" || rawDistrict == "N/A") && villID.count >= 2 {
            let prefix = String(villID.prefix(2))
            if let mapped = MapViewModel.districtNameForGISPrefix(prefix) {
                rawDistrict = mapped
            }
        }
        if rawTahasil.isEmpty || rawTahasil == "N/A" {
            if villID.count >= 4 {
                let distP = String(villID.prefix(2))
                let tahP = String(villID.dropFirst(2).prefix(2))
                if let mapped = MapViewModel.tahasilNameForGISCodes(districtCode: distP, tahasilCode: tahP) {
                    rawTahasil = mapped
                }
            }
            if rawTahasil.isEmpty || rawTahasil == "N/A" {
                if !rawDistrict.isEmpty && rawDistrict != "Odisha" && rawDistrict != "N/A" {
                    rawTahasil = "\(rawDistrict) Sadar"
                }
            }
        }
        
        let district = cleanName(rawDistrict)
        let tahasil = cleanName(rawTahasil)
        let village = cleanName(rawVillage)
        let plot = rawPlot.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !district.isEmpty, district != "N/A", district != "Odisha",
              !tahasil.isEmpty, tahasil != "N/A",
              !village.isEmpty, village != "N/A", village != "Village",
              !plot.isEmpty, plot != "N/A" else {
            if district.isEmpty || district == "N/A" || district == "Odisha" {
                throw RoRError.missingMetadata("District")
            }
            if tahasil.isEmpty || tahasil == "N/A" {
                throw RoRError.missingMetadata("Tahasil")
            }
            if village.isEmpty || village == "N/A" || village == "Village" {
                throw RoRError.missingMetadata("Village")
            }
            throw RoRError.missingMetadata("Plot Number")
        }
        
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
        
        if let cached = rorCache[cacheKey], cached.plot == plot, cached.verification?.status == .verified, !cached.isPreview, !cached.isLocked {
            print("[RoR CACHE HIT] Instant lookup for \(cacheKey)")
            let isGovt = cached.isGovernmentLand
            AnalyticsService.shared.log(.landSearchSucceeded(
                searchMethod: .mapTap,
                districtID: district,
                tehsilID: bId ?? tahasil,
                resultStatus: isGovt ? .verifiedGovernment : .verifiedPrivate,
                latencyMs: 0,
                cacheHit: true,
                isGovernmentLand: isGovt
            ))
            return cached
        }
        
        if let inFlight = inFlightTasks[cacheKey] {
            print("[RoR DEDUPLICATION] Joining active in-flight request for \(cacheKey)")
            return try await inFlight.value
        }
        
        let task = Task<RoRResponse, Error> {
            try await self.performNetworkFetch(
                district: district,
                tahasil: tahasil,
                village: village,
                plot: plot,
                bId: bId,
                vId: vId,
                cacheKey: cacheKey
            )
        }
        
        inFlightTasks[cacheKey] = task
        
        do {
            let result = try await task.value
            inFlightTasks.removeValue(forKey: cacheKey)
            return result
        } catch {
            inFlightTasks.removeValue(forKey: cacheKey)
            throw error
        }
    }
    
    private func performNetworkFetch(district: String, tahasil: String, village: String, plot: String, bId: String?, vId: String?, cacheKey: String) async throws -> RoRResponse {
        AnalyticsService.shared.log(.landSearchStarted(
            searchMethod: .mapTap,
            districtID: district,
            tehsilID: bId ?? tahasil
        ))
        
        var components = URLComponents(string: "\(baseURL)/ror")!
        var queryItems = [
            URLQueryItem(name: "district", value: district),
            URLQueryItem(name: "tahasil", value: tahasil),
            URLQueryItem(name: "village", value: village),
            URLQueryItem(name: "plot", value: plot),
        ]
        
        if let bId = bId?.trimmingCharacters(in: .whitespacesAndNewlines), !bId.isEmpty {
            queryItems.append(URLQueryItem(name: "b_id", value: bId))
        }
        if let vId = vId?.trimmingCharacters(in: .whitespacesAndNewlines), !vId.isEmpty {
            queryItems.append(URLQueryItem(name: "v_id", value: vId))
        }
        
        let isZeroCredits = await MainActor.run {
            !SubscriptionManager.shared.isUnlimited && SubscriptionManager.shared.remainingPlotCredits <= 0
        }
        if isZeroCredits {
            queryItems.append(URLQueryItem(name: "preview", value: "true"))
        }
        
        components.queryItems = queryItems
        
        guard let url = components.url else {
            AnalyticsService.shared.log(.landSearchFailed(
                searchMethod: .mapTap,
                districtID: district,
                latencyMs: 0,
                errorCategory: .configuration
            ))
            throw RoRError.networkError("Invalid URL configuration")
        }
        
        let clientReqId = UUID().uuidString.prefix(8)
        let startTime = CFAbsoluteTimeGetCurrent()
        
        AnalyticsService.shared.log(.landSearchSubmitted(
            searchMethod: .mapTap,
            districtID: district,
            tehsilID: bId ?? tahasil
        ))
        
        print("""
        [RoR iOS] request started
        [RoR iOS] URL: \(url.absoluteString)
        [RoR iOS] request ID: \(clientReqId)
        """)

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(String(clientReqId), forHTTPHeaderField: "X-Client-Request-ID")
        if let token = await MainActor.run(body: { AuthManager.shared.bearerToken }) {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            let elapsed = CFAbsoluteTimeGetCurrent() - startTime
            let latencyMs = Int(elapsed * 1000)
            let isTimeout = (error as? URLError)?.code == .timedOut
            
            print("""
            [RoR iOS] HTTP status: 0 (Client Network Error)
            [RoR iOS] error type: \(isTimeout ? "ROR_TIMEOUT" : "NETWORK_ERROR (\(error.localizedDescription))")
            [RoR iOS] elapsed time: \(String(format: "%.2f", elapsed))s
            """)
            
            await MainActor.run {
                self.lastDiagnosticInfo = LastRoRDiagnosticInfo(
                    requestURL: url.absoluteString,
                    httpStatus: 0,
                    requestID: String(clientReqId),
                    rawJSONString: "Network Error: \(error.localizedDescription)",
                    timestamp: Date()
                )
            }
            
            AnalyticsService.shared.log(.landSearchFailed(
                searchMethod: .mapTap,
                districtID: district,
                latencyMs: latencyMs,
                errorCategory: isTimeout ? .timeout : .network
            ))
            
            if isTimeout {
                throw RoRError.timeout("Land records service is responding slowly. Please try again.")
            }
            throw RoRError.networkError(error.localizedDescription)
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            let elapsed = CFAbsoluteTimeGetCurrent() - startTime
            AnalyticsService.shared.log(.landSearchFailed(
                searchMethod: .mapTap,
                districtID: district,
                latencyMs: Int(elapsed * 1000),
                errorCategory: .backendError
            ))
            print("[RoR iOS] error type: SERVER_ERROR (Invalid server response)")
            throw RoRError.networkError("Invalid server response")
        }
        
        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        let latencyMs = Int(elapsed * 1000)
        let backendMs = httpResponse.value(forHTTPHeaderField: "X-Backend-Duration-Ms").flatMap { Int($0) }
        let upstreamMs = httpResponse.value(forHTTPHeaderField: "X-Upstream-Duration-Ms").flatMap { Int($0) }
        let cacheHitStr = httpResponse.value(forHTTPHeaderField: "X-Cache-Hit")
        
        print("""
        [RoR iOS] HTTP status: \(httpResponse.statusCode)
        [RoR iOS] backend: \(backendMs != nil ? "\(backendMs!)ms" : "N/A"), upstream: \(upstreamMs != nil ? "\(upstreamMs!)ms" : "N/A"), cache: \(cacheHitStr ?? "false")
        [RoR iOS] response bytes: \(data.count)
        [RoR iOS] elapsed time: \(String(format: "%.2f", elapsed))s
        """)
        
        let rawString = String(data: data, encoding: .utf8) ?? "<non-utf8 data: \(data.count) bytes>"
        let reqId = httpResponse.value(forHTTPHeaderField: "X-Request-ID") ?? String(clientReqId)
        await MainActor.run {
            self.lastDiagnosticInfo = LastRoRDiagnosticInfo(
                requestURL: url.absoluteString,
                httpStatus: httpResponse.statusCode,
                requestID: reqId,
                rawJSONString: rawString,
                timestamp: Date(),
                backendDurationMs: backendMs,
                upstreamDurationMs: upstreamMs
            )
        }
        
        guard (200..<300).contains(httpResponse.statusCode) else {
            let errorCat: AnalyticsErrorCategory = {
                switch httpResponse.statusCode {
                case 404: return .upstreamError
                case 403: return .invalidToken
                case 502, 503, 504: return .upstreamError
                default: return .backendError
                }
            }()
            
            AnalyticsService.shared.log(.landSearchFailed(
                searchMethod: .mapTap,
                districtID: district,
                latencyMs: latencyMs,
                errorCategory: errorCat
            ))
            
            // Check for structured RoRErrorPayload
            if let errorPayload = try? JSONDecoder().decode([String: RoRErrorPayload].self, from: data),
               let detail = errorPayload["detail"], let code = detail.code {
                print("[RoR iOS] error type: \(code) - \(detail.message ?? "")")
                switch code {
                case "USAGE_LIMIT_EXCEEDED":
                    throw RoRError.usageLimitExceeded(detail.message ?? "Monthly usage limit reached.")
                case "ROR_NOT_FOUND":
                    throw RoRError.notFound(detail.message ?? "No official record found for this land parcel.")
                case "BHULEKH_CATALOG_NOT_FOUND":
                    // Village/tahasil identity exists on the map but is not yet mapped in
                    // the verified government catalog. This is NOT a network failure and
                    // must not render as one (previously fell through to serverError →
                    // .networkProblem, telling users they were offline).
                    throw RoRError.missingMetadata(detail.message ?? "This village is not yet verified in the official government catalog.")
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
                    print("[RoR iOS] error type: HTTP_\(httpResponse.statusCode) - \(detailStr)")
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
            
            print("[RoR iOS] error type: HTTP_\(httpResponse.statusCode)")
            if httpResponse.statusCode == 404 {
                throw RoRError.notFound("No official land record was found for this plot.")
            }
            if httpResponse.statusCode == 503 {
                throw RoRError.temporarilyUnavailable("Official land records service is temporarily unavailable.")
            }
            if httpResponse.statusCode == 504 {
                throw RoRError.timeout("Land records service timed out.")
            }
            throw RoRError.serverError(httpResponse.statusCode, "Server error (\(httpResponse.statusCode))")
        }
        
        do {
            let decoder = JSONDecoder()
            let decoded = try decoder.decode(RoRResponse.self, from: data)
            print("[RoR iOS] decode success: status=\(decoded.verification?.status.rawValue ?? "unknown") plot=\(decoded.plot) khata=\(decoded.khataNumber ?? "nil")")
            
            // Response Identity Validation: Ensure returned plot strictly matches requested plot
            let cleanRequestedPlot = plot.trimmingCharacters(in: .whitespacesAndNewlines)
            let cleanDecodedPlot = decoded.plot.trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleanRequestedPlot.isEmpty && !cleanDecodedPlot.isEmpty && cleanRequestedPlot != cleanDecodedPlot {
                print("[RoR iOS] Identity Mismatch: requested plot '\(cleanRequestedPlot)' != returned plot '\(cleanDecodedPlot)'")
                throw RoRError.identityMismatch("Returned record plot (\(cleanDecodedPlot)) does not match requested parcel plot (\(cleanRequestedPlot)).")
            }
            
            if let verifStatus = decoded.verification?.status {
                if verifStatus == .mismatch {
                    throw RoRError.identityMismatch(decoded.verification?.details ?? "Record could not be verified for this exact parcel.")
                } else if verifStatus != .verified {
                    throw RoRError.notFound(decoded.verification?.details ?? "Official RoR record could not be verified for this plot.")
                }
            } else if !decoded.success {
                throw RoRError.notFound("No official land record was found for this plot.")
            }
            
            let isGovt = decoded.isGovernmentLand
            let resultStatus: AnalyticsSearchResultStatus = isGovt ? .verifiedGovernment : .verifiedPrivate
            
            AnalyticsService.shared.log(.landSearchSucceeded(
                searchMethod: .mapTap,
                districtID: district,
                tehsilID: bId ?? tahasil,
                resultStatus: resultStatus,
                latencyMs: latencyMs,
                cacheHit: false,
                isGovernmentLand: isGovt
            ))
            
            // Store in cache strictly and exclusively for this verified plot
            // Never cache a masked zero-credit preview: after a purchase the
            // next fetch must hit the server for the full record.
            if decoded.verification?.status == .verified, !decoded.isPreview, !decoded.isLocked {
                rorCache[cacheKey] = decoded
            }
            
            // Record credit audit item for verified search
            await MainActor.run {
                if !SubscriptionManager.shared.isUnlimited && !SubscriptionManager.shared.isPremium && !isZeroCredits {
                    #if DEBUG
                    if TestCreditManager.shared.testCredits > 0 {
                        _ = SubscriptionManager.shared.consumePlotSearchCredit(
                            plot: decoded.plot,
                            village: decoded.village,
                            district: decoded.district
                        )
                    } else {
                        CreditTransactionManager.shared.recordCreditSpent(
                            amount: 1,
                            title: "Plot #\(decoded.plot) RoR Verification",
                            category: .rorInspection,
                            details: "\(decoded.village), \(decoded.district)",
                            balanceAfter: max(0, SubscriptionManager.shared.remainingPlotCredits - 1)
                        )
                    }
                    #else
                    CreditTransactionManager.shared.recordCreditSpent(
                        amount: 1,
                        title: "Plot #\(decoded.plot) RoR Verification",
                        category: .rorInspection,
                        details: "\(decoded.village), \(decoded.district)",
                        balanceAfter: max(0, SubscriptionManager.shared.remainingPlotCredits - 1)
                    )
                    #endif
                }
            }
            
            // Reconcile server credit balance upon successful search
            _Concurrency.Task {
                await SubscriptionManager.shared.fetchServerCreditBalance()
            }
            
            return decoded
        } catch let rorError as RoRError {
            throw rorError
        } catch {
            print("[RoR iOS] decode failure: \(error.localizedDescription)")
            AnalyticsService.shared.log(.landSearchFailed(
                searchMethod: .mapTap,
                districtID: district,
                latencyMs: latencyMs,
                errorCategory: .parseError
            ))
            throw RoRError.decodingError(error.localizedDescription)
        }
    }
    
    // MARK: - Location Hierarchy API
    
    func fetchDistricts() async throws -> [BhulekhDistrict] {
        guard let url = URL(string: "\(baseURL)/districts") else {
            print("[Districts][RoRService] URL: <INVALID_URL> for baseURL: \(baseURL)")
            throw RoRError.networkError("Invalid URL configuration")
        }
        print("[Districts][RoRService] URL: \(url.absoluteString)")
        do {
            let (data, response) = try await session.data(from: url)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            print("[Districts][RoRService] HTTP status: \(statusCode)")
            print("[Districts][RoRService] response bytes: \(data.count)")
            let bodyStr = String(data: data, encoding: .utf8) ?? "<non-utf8>"
            let snippet = bodyStr.count > 300 ? String(bodyStr.prefix(300)) + "... (truncated)" : bodyStr
            print("[Districts][RoRService] response body: \(snippet)")
            
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw RoRError.serverError(statusCode, "Failed to load district hierarchy (HTTP \(statusCode))")
            }
            let decoded = try JSONDecoder().decode([BhulekhDistrict].self, from: data)
            print("[Districts][RoRService] decoding result: SUCCESS")
            print("[Districts][RoRService] district count: \(decoded.count)")
            return decoded
        } catch {
            print("[Districts][RoRService] Request FAILED with error: \(error)")
            throw error
        }
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
