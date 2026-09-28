//
//  BenchmarkValuationService.swift
//  MyBhoomi
//
//  Networking and Caching Service for Odisha IGR Benchmark Valuation
//

import Foundation

public enum BenchmarkValuationError: LocalizedError, Equatable {
    case invalidURL
    case networkError(String)
    case serverError(Int, String)
    case decodingError(String)
    case unavailable(String)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid benchmark valuation request URL."
        case .networkError(let msg):
            return "Network connection issue: \(msg)"
        case .serverError(let code, let msg):
            return "Server error (\(code)): \(msg)"
        case .decodingError(let msg):
            return "Failed to parse benchmark valuation: \(msg)"
        case .unavailable(let msg):
            return msg.isEmpty ? "Benchmark value unavailable for this plot." : msg
        }
    }
}

public actor BenchmarkValuationService {
    public static let shared = BenchmarkValuationService()

    private var cache: [String: BenchmarkValuation] = [:]

    public var baseURL: String {
        APIConfiguration.shared.baseURL
    }

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 20
        return URLSession(configuration: config)
    }()

    private init() {}

    // MARK: - Public API

    public func getCachedValuation(
        district: String,
        tahasil: String,
        village: String,
        plot: String,
        selectedRegoffID: Int? = nil,
        selectedVillageID: Int? = nil
    ) -> BenchmarkValuation? {
        let key = cacheKey(district: district, tahasil: tahasil, village: village, plot: plot, selectedRegoffID: selectedRegoffID, selectedVillageID: selectedVillageID)
        return cache[key]
    }

    public func fetchValuation(
        for parcel: Parcel,
        actualArea: Double? = nil,
        actualAreaUnit: String? = "Decimal",
        selectedRegoffID: Int? = nil,
        selectedVillageID: Int? = nil,
        candidateToken: String? = nil
    ) async throws -> BenchmarkValuation {
        let identity = parcel.identity
        let rawPlot = identity.plotNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        let rawDist = identity.districtName.trimmingCharacters(in: .whitespacesAndNewlines)
        let rawTahasil = identity.tahasilName.trimmingCharacters(in: .whitespacesAndNewlines)
        let rawVillage = identity.villageName.trimmingCharacters(in: .whitespacesAndNewlines)

        let areaToUse = actualArea ?? (parcel.metadata.estimatedAreaAcre != nil ? (parcel.metadata.estimatedAreaAcre! * 100.0) : nil)
        let unitToUse = actualAreaUnit ?? "Decimal"

        return try await fetchValuation(
            district: rawDist,
            tahasil: rawTahasil,
            village: rawVillage,
            plot: rawPlot,
            actualArea: areaToUse,
            actualAreaUnit: unitToUse,
            bId: identity.tahasilID,
            vId: identity.villageID,
            selectedRegoffID: selectedRegoffID,
            selectedVillageID: selectedVillageID,
            candidateToken: candidateToken
        )
    }

    public func fetchValuation(
        district: String,
        tahasil: String,
        village: String,
        plot: String,
        actualArea: Double? = nil,
        actualAreaUnit: String? = "Decimal",
        bId: String? = nil,
        vId: String? = nil,
        selectedRegoffID: Int? = nil,
        selectedVillageID: Int? = nil,
        candidateToken: String? = nil,
        forceRefresh: Bool = false
    ) async throws -> BenchmarkValuation {
        let key = cacheKey(district: district, tahasil: tahasil, village: village, plot: plot, selectedRegoffID: selectedRegoffID, selectedVillageID: selectedVillageID)
        if !forceRefresh, let cached = cache[key] {
            return cached
        }

        var components = URLComponents(string: "\(baseURL)/ror/benchmark-valuation")
        guard components != nil else {
            throw BenchmarkValuationError.invalidURL
        }

        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "district", value: district),
            URLQueryItem(name: "tahasil", value: tahasil),
            URLQueryItem(name: "village", value: village),
            URLQueryItem(name: "plot", value: plot),
        ]

        if forceRefresh {
            queryItems.append(URLQueryItem(name: "force_refresh", value: "true"))
        }

        if let area = actualArea, area > 0 {
            queryItems.append(URLQueryItem(name: "actual_area", value: String(format: "%.4f", area)))
            if let unit = actualAreaUnit, !unit.isEmpty {
                queryItems.append(URLQueryItem(name: "actual_area_unit", value: unit))
            }
        }

        if let b = bId, !b.isEmpty {
            queryItems.append(URLQueryItem(name: "b_id", value: b))
        }
        if let v = vId, !v.isEmpty {
            queryItems.append(URLQueryItem(name: "v_id", value: v))
        }

        if let ro = selectedRegoffID {
            queryItems.append(URLQueryItem(name: "selected_regoff_id", value: String(ro)))
        }
        if let vi = selectedVillageID {
            queryItems.append(URLQueryItem(name: "selected_village_id", value: String(vi)))
        }
        if let ct = candidateToken, !ct.isEmpty {
            queryItems.append(URLQueryItem(name: "candidate_token", value: ct))
        }

        components?.queryItems = queryItems

        guard let url = components?.url else {
            throw BenchmarkValuationError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = await MainActor.run(body: { AuthManager.shared.bearerToken }) {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw BenchmarkValuationError.networkError(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BenchmarkValuationError.networkError("Invalid HTTP response")
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw BenchmarkValuationError.serverError(httpResponse.statusCode, "Failed to retrieve benchmark valuation.")
        }

        do {
            let decoder = JSONDecoder()
            let valuation = try decoder.decode(BenchmarkValuation.self, from: data)
            cache[key] = valuation
            return valuation
        } catch {
            throw BenchmarkValuationError.decodingError(error.localizedDescription)
        }
    }

    private func cacheKey(
        district: String,
        tahasil: String,
        village: String,
        plot: String,
        selectedRegoffID: Int? = nil,
        selectedVillageID: Int? = nil
    ) -> String {
        let d = district.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let t = tahasil.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let v = village.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let p = plot.trimmingCharacters(in: .whitespacesAndNewlines)
        if let ro = selectedRegoffID, let vi = selectedVillageID {
            return "\(d):\(t):\(v):\(p):\(ro):\(vi)"
        }
        return "\(d):\(t):\(v):\(p)"
    }
}
