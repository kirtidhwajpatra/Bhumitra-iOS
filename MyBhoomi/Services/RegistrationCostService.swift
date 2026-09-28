//
//  RegistrationCostService.swift
//  MyBhoomi
//
//  Networking and Caching Service for Odisha IGR Registration & Stamp Duty Estimation.
//

import Foundation

public enum RegistrationCostError: LocalizedError, Equatable {
    case invalidURL
    case networkError(String)
    case serverError(Int, String)
    case decodingError(String)
    case unavailable(String)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid registration estimate request URL."
        case .networkError(let msg):
            return "Network connection issue: \(msg)"
        case .serverError(let code, let msg):
            return "Server error (\(code)): \(msg)"
        case .decodingError(let msg):
            return "Failed to parse registration charges: \(msg)"
        case .unavailable(let msg):
            return msg.isEmpty ? "Registration estimate unavailable for this plot." : msg
        }
    }
}

public actor RegistrationCostService {
    public static let shared = RegistrationCostService()

    private var cache: [String: RegistrationCostEstimate] = [:]

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

    public func getCachedEstimate(
        district: String,
        tahasil: String,
        village: String,
        plot: String,
        area: Decimal,
        unit: String,
        deedId: Int,
        buyerCategory: BuyerCategoryOption,
        selectedRegoffID: Int? = nil,
        selectedVillageID: Int? = nil
    ) -> RegistrationCostEstimate? {
        let key = cacheKey(
            district: district,
            tahasil: tahasil,
            village: village,
            plot: plot,
            area: area,
            unit: unit,
            deedId: deedId,
            buyerCategory: buyerCategory,
            selectedRegoffID: selectedRegoffID,
            selectedVillageID: selectedVillageID
        )
        return cache[key]
    }

    public func fetchEstimate(
        for parcel: Parcel,
        area: Decimal? = nil,
        unit: String? = "Decimal",
        deedType: String = "SALE IMMOVABLE",
        deedId: Int = 1,
        buyerCategory: BuyerCategoryOption = .standard,
        selectedRegoffID: Int? = nil,
        selectedVillageID: Int? = nil,
        candidateToken: String? = nil,
        forceRefresh: Bool = false
    ) async throws -> RegistrationCostEstimate {
        let identity = parcel.identity
        let rawPlot = identity.plotNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        let rawDist = identity.districtName.trimmingCharacters(in: .whitespacesAndNewlines)
        let rawTahasil = identity.tahasilName.trimmingCharacters(in: .whitespacesAndNewlines)
        let rawVillage = identity.villageName.trimmingCharacters(in: .whitespacesAndNewlines)

        let areaToUse: Decimal
        if let explicitArea = area, explicitArea > 0 {
            areaToUse = explicitArea
        } else if let estAcre = parcel.metadata.estimatedAreaAcre, estAcre > 0 {
            areaToUse = Decimal(estAcre) * 100
        } else {
            areaToUse = 1.0
        }
        let unitToUse = unit ?? "Decimal"

        return try await fetchEstimate(
            district: rawDist,
            tahasil: rawTahasil,
            village: rawVillage,
            plot: rawPlot,
            area: areaToUse,
            unit: unitToUse,
            deedType: deedType,
            deedId: deedId,
            buyerCategory: buyerCategory,
            bId: identity.tahasilID,
            vId: identity.villageID,
            selectedRegoffID: selectedRegoffID,
            selectedVillageID: selectedVillageID,
            candidateToken: candidateToken,
            forceRefresh: forceRefresh
        )
    }

    public func fetchEstimate(
        district: String,
        tahasil: String,
        village: String,
        plot: String,
        area: Decimal,
        unit: String = "Decimal",
        deedType: String = "SALE IMMOVABLE",
        deedId: Int = 1,
        buyerCategory: BuyerCategoryOption = .standard,
        bId: String? = nil,
        vId: String? = nil,
        selectedRegoffID: Int? = nil,
        selectedVillageID: Int? = nil,
        candidateToken: String? = nil,
        forceRefresh: Bool = false
    ) async throws -> RegistrationCostEstimate {
        let key = cacheKey(
            district: district,
            tahasil: tahasil,
            village: village,
            plot: plot,
            area: area,
            unit: unit,
            deedId: deedId,
            buyerCategory: buyerCategory,
            selectedRegoffID: selectedRegoffID,
            selectedVillageID: selectedVillageID
        )

        if !forceRefresh, let cached = cache[key] {
            return cached
        }

        guard let url = URL(string: "\(baseURL)/ror/registration-estimate") else {
            throw RegistrationCostError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let token = await MainActor.run(body: { AuthManager.shared.bearerToken }) {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let areaDouble = NSDecimalNumber(decimal: area).doubleValue
        var payload: [String: Any] = [
            "district": district,
            "tahasil": tahasil,
            "village": village,
            "plot": plot,
            "area": areaDouble,
            "unit": unit,
            "deed_type": deedType,
            "deed_id": deedId,
            "buyer_category": buyerCategory.rawValue,
            "force_refresh": forceRefresh
        ]

        if let b = bId, !b.isEmpty { payload["b_id"] = b }
        if let v = vId, !v.isEmpty { payload["v_id"] = v }
        if let ro = selectedRegoffID { payload["selected_regoff_id"] = ro }
        if let vi = selectedVillageID { payload["selected_village_id"] = vi }
        if let ct = candidateToken, !ct.isEmpty { payload["candidate_token"] = ct }

        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw RegistrationCostError.networkError(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw RegistrationCostError.networkError("Invalid HTTP response")
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw RegistrationCostError.serverError(httpResponse.statusCode, "Failed to retrieve registration charges.")
        }

        do {
            let decoder = JSONDecoder()
            let estimate = try decoder.decode(RegistrationCostEstimate.self, from: data)
            cache[key] = estimate
            return estimate
        } catch {
            throw RegistrationCostError.decodingError(error.localizedDescription)
        }
    }

    private func cacheKey(
        district: String,
        tahasil: String,
        village: String,
        plot: String,
        area: Decimal,
        unit: String,
        deedId: Int,
        buyerCategory: BuyerCategoryOption,
        selectedRegoffID: Int? = nil,
        selectedVillageID: Int? = nil
    ) -> String {
        let d = district.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let t = tahasil.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let v = village.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let p = plot.trimmingCharacters(in: .whitespacesAndNewlines)
        let a = NSDecimalNumber(decimal: area).stringValue
        let u = unit.lowercased()
        let did = String(deedId)
        let b = buyerCategory.rawValue.lowercased()

        if let ro = selectedRegoffID, let vi = selectedVillageID {
            return "\(d):\(t):\(v):\(p):\(a):\(u):\(did):\(b):\(ro):\(vi)"
        }
        return "\(d):\(t):\(v):\(p):\(a):\(u):\(did):\(b)"
    }
}
