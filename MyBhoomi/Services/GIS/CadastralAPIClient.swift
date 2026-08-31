import Foundation
import CoreLocation

public enum CadastralAPIError: LocalizedError {
    case invalidURL
    case serverUnavailable(String)
    case notFound(String)
    case decodingError(String)
    case biharGisDisabled(String)
    case mapTooLarge(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid GIS API endpoint URL."
        case .serverUnavailable(let msg):
            return "Cadastral map unavailable: \(msg)"
        case .notFound(let msg):
            return msg
        case .decodingError(let msg):
            return "Failed to decode cadastral data: \(msg)"
        case .biharGisDisabled(let msg):
            return msg
        case .mapTooLarge(let msg):
            return msg
        }
    }
}

public final class CadastralAPIClient {
    public static let shared = CadastralAPIClient()
    
    private let urlSession: URLSession
    
    public init(session: URLSession? = nil) {
        if let customSession = session {
            self.urlSession = customSession
        } else {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 25.0
            config.timeoutIntervalForResource = 30.0
            config.requestCachePolicy = .reloadIgnoringLocalCacheData
            self.urlSession = URLSession(configuration: config)
        }
    }
    
    private var baseURL: String {
        APIConfiguration.shared.baseURL
    }
    
    // MARK: - Hierarchy Endpoints
    
    public func fetchDistricts(state: String = "ODISHA") async throws -> [CadastralDistrict] {
        guard var components = URLComponents(string: "\(baseURL)/gis/districts") else {
            throw CadastralAPIError.invalidURL
        }
        components.queryItems = [URLQueryItem(name: "state", value: state)]
        guard let url = components.url else { throw CadastralAPIError.invalidURL }
        
        do {
            let (data, response) = try await urlSession.data(from: url)
            try validateResponse(response, data: data)
            return try JSONDecoder().decode([CadastralDistrict].self, from: data)
        } catch {
            print("[Districts] Request FAILED with error: \(error.localizedDescription)")
            throw error
        }
    }
    
    public func fetchBlocks(districtID: String, state: String = "ODISHA") async throws -> [CadastralBlock] {
        guard var components = URLComponents(string: "\(baseURL)/gis/blocks") else {
            throw CadastralAPIError.invalidURL
        }
        components.queryItems = [
            URLQueryItem(name: "district_id", value: districtID),
            URLQueryItem(name: "state", value: state)
        ]
        guard let url = components.url else { throw CadastralAPIError.invalidURL }
        
        let (data, response) = try await urlSession.data(from: url)
        try validateResponse(response, data: data)
        return try JSONDecoder().decode([CadastralBlock].self, from: data)
    }
    
    public func fetchGPs(blockID: String, state: String = "ODISHA") async throws -> [CadastralGP] {
        guard var components = URLComponents(string: "\(baseURL)/gis/gps") else {
            throw CadastralAPIError.invalidURL
        }
        components.queryItems = [
            URLQueryItem(name: "block_id", value: blockID),
            URLQueryItem(name: "state", value: state)
        ]
        guard let url = components.url else { throw CadastralAPIError.invalidURL }
        
        let (data, response) = try await urlSession.data(from: url)
        try validateResponse(response, data: data)
        return try JSONDecoder().decode([CadastralGP].self, from: data)
    }
    
    public func fetchVillages(blockID: String, gpID: String? = nil, state: String = "ODISHA") async throws -> [CadastralVillage] {
        guard var components = URLComponents(string: "\(baseURL)/gis/villages") else {
            throw CadastralAPIError.invalidURL
        }
        var items = [
            URLQueryItem(name: "block_id", value: blockID),
            URLQueryItem(name: "state", value: state)
        ]
        if let gp = gpID, !gp.isEmpty {
            items.append(URLQueryItem(name: "gp_id", value: gp))
        }
        components.queryItems = items
        guard let url = components.url else { throw CadastralAPIError.invalidURL }
        
        let (data, response) = try await urlSession.data(from: url)
        try validateResponse(response, data: data)
        return try JSONDecoder().decode([CadastralVillage].self, from: data)
    }
    
    // MARK: - Extent & Parcels
    
    public func fetchVillageExtent(villageID: String, gpID: String? = nil, state: String = "ODISHA") async throws -> CadastralExtent {
        guard var components = URLComponents(string: "\(baseURL)/gis/village/\(villageID)/extent") else {
            throw CadastralAPIError.invalidURL
        }
        var items = [URLQueryItem(name: "state", value: state)]
        if let gp = gpID, !gp.isEmpty {
            items.append(URLQueryItem(name: "gp_id", value: gp))
        }
        components.queryItems = items
        guard let url = components.url else { throw CadastralAPIError.invalidURL }
        
        let (data, response) = try await urlSession.data(from: url)
        try validateResponse(response, data: data)
        return try JSONDecoder().decode(CadastralExtent.self, from: data)
    }
    
    /// Returns the raw WGS84 GeoJSON bytes directly for fast MapLibre ShapeSource ingestion.
    public func fetchVillageParcelsRawGeoJSON(
        villageID: String,
        districtName: String? = nil,
        blockName: String? = nil,
        gpName: String? = nil,
        villageName: String? = nil,
        sheetNo: String? = nil,
        state: String = "ODISHA"
    ) async throws -> Data {
        guard var components = URLComponents(string: "\(baseURL)/gis/village/\(villageID)/parcels") else {
            throw CadastralAPIError.invalidURL
        }
        var items: [URLQueryItem] = [
            URLQueryItem(name: "state", value: state)
        ]
        if let d = districtName { items.append(URLQueryItem(name: "district_name", value: d)) }
        if let b = blockName { items.append(URLQueryItem(name: "block_name", value: b)) }
        if let g = gpName { items.append(URLQueryItem(name: "gp_name", value: g)) }
        if let v = villageName { items.append(URLQueryItem(name: "village_name", value: v)) }
        if let s = sheetNo { items.append(URLQueryItem(name: "sheet_no", value: s)) }
        components.queryItems = items
        
        guard let url = components.url else { throw CadastralAPIError.invalidURL }
        
        let (data, response) = try await urlSession.data(from: url)
        try validateResponse(response, data: data)
        return data
    }
    
    public func fetchParcelByPlot(
        villageID: String,
        plotNumber: String,
        districtName: String? = nil,
        blockName: String? = nil,
        gpName: String? = nil,
        villageName: String? = nil,
        sheetNo: String? = nil,
        state: String = "ODISHA"
    ) async throws -> CadastralParcel {
        guard let encodedPlot = plotNumber.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              var components = URLComponents(string: "\(baseURL)/gis/village/\(villageID)/plot/\(encodedPlot)") else {
            throw CadastralAPIError.invalidURL
        }
        var items: [URLQueryItem] = [
            URLQueryItem(name: "state", value: state)
        ]
        if let d = districtName { items.append(URLQueryItem(name: "district_name", value: d)) }
        if let b = blockName { items.append(URLQueryItem(name: "block_name", value: b)) }
        if let g = gpName { items.append(URLQueryItem(name: "gp_name", value: g)) }
        if let v = villageName { items.append(URLQueryItem(name: "village_name", value: v)) }
        if let s = sheetNo { items.append(URLQueryItem(name: "sheet_no", value: s)) }
        components.queryItems = items
        
        guard let url = components.url else { throw CadastralAPIError.invalidURL }
        
        let (data, response) = try await urlSession.data(from: url)
        try validateResponse(response, data: data)
        return try JSONDecoder().decode(CadastralParcel.self, from: data)
    }
    
    public func identifyParcel(
        lat: Double,
        lng: Double,
        villageID: String,
        districtName: String? = nil,
        blockName: String? = nil,
        gpName: String? = nil,
        villageName: String? = nil,
        sheetNo: String? = nil,
        state: String = "ODISHA"
    ) async throws -> CadastralParcel {
        guard var components = URLComponents(string: "\(baseURL)/gis/parcel/identify") else {
            throw CadastralAPIError.invalidURL
        }
        var items = [
            URLQueryItem(name: "lat", value: String(lat)),
            URLQueryItem(name: "lng", value: String(lng)),
            URLQueryItem(name: "village_id", value: villageID),
            URLQueryItem(name: "state", value: state)
        ]
        if let d = districtName { items.append(URLQueryItem(name: "district_name", value: d)) }
        if let b = blockName { items.append(URLQueryItem(name: "block_name", value: b)) }
        if let g = gpName { items.append(URLQueryItem(name: "gp_name", value: g)) }
        if let v = villageName { items.append(URLQueryItem(name: "village_name", value: v)) }
        if let s = sheetNo { items.append(URLQueryItem(name: "sheet_no", value: s)) }
        components.queryItems = items
        
        guard let url = components.url else { throw CadastralAPIError.invalidURL }
        
        let (data, response) = try await urlSession.data(from: url)
        try validateResponse(response, data: data)
        return try JSONDecoder().decode(CadastralParcel.self, from: data)
    }
    
    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else { return }
        
        if httpResponse.statusCode == 413 {
            let errorMsg = (try? JSONDecoder().decode([String: String].self, from: data)["message"]) ?? "Cadastral map is too large to display safely."
            throw CadastralAPIError.mapTooLarge(errorMsg)
        }
        
        if httpResponse.statusCode == 503 {
            if let detailDict = try? JSONDecoder().decode([String: String].self, from: data),
               let code = detailDict["error_code"], code == "BIHAR_GIS_DISABLED" {
                throw CadastralAPIError.biharGisDisabled(detailDict["message"] ?? "Bihar cadastral GIS is currently disabled.")
            }
        }
        
        if httpResponse.statusCode == 404 {
            let errorMsg = (try? JSONDecoder().decode([String: String].self, from: data)["detail"]) ?? "Resource not found."
            throw CadastralAPIError.notFound(errorMsg)
        }
        
        if httpResponse.statusCode >= 500 {
            let errorMsg = (try? JSONDecoder().decode([String: String].self, from: data)["message"]) ?? "Cadastral map server is currently unavailable."
            throw CadastralAPIError.serverUnavailable(errorMsg)
        }
    }
}
