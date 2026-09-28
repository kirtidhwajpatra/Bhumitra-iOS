import Foundation
import CoreLocation

// ============================================================
// MARK: - GIS EXPLORER REPOSITORY
// ============================================================

public final class GISExplorerRepository {
    public static let shared = GISExplorerRepository()
    
    private let urlSession: URLSession
    private let cadastralRepo: CadastralRepository
    
    // In-Memory Caches
    private var cachedDistrictsGeoJSON: Data? = nil
    private var cachedDistrictsSummary: [GISDistrictFeature]? = nil
    private var cachedTahasilsGeoJSON: [String: Data] = [:]
    private var cachedSubdivisions: [String: [CadastralBlock]] = [:]
    private var cachedVillages: [String: [CadastralVillage]] = [:]
    
    private let lock = NSLock()
    
    public init(session: URLSession? = nil, cadastralRepo: CadastralRepository = .shared) {
        if let s = session {
            self.urlSession = s
        } else {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 20.0
            config.requestCachePolicy = .useProtocolCachePolicy
            self.urlSession = URLSession(configuration: config)
        }
        self.cadastralRepo = cadastralRepo
    }
    
    private var baseURL: String {
        APIConfiguration.shared.baseURL
    }
    
    // MARK: - Request Builders
    
    public func makeDistrictsGeoJSONRequest(forceRefresh: Bool = false) -> URLRequest? {
        guard let url = URL(string: "\(baseURL)/gis/navigation/districts-geojson") else {
            return nil
        }
        var request = URLRequest(url: url)
        request.cachePolicy = forceRefresh ? .reloadIgnoringLocalCacheData : .useProtocolCachePolicy
        return request
    }
    
    public func makeDistrictsSummaryRequest(forceRefresh: Bool = false) -> URLRequest? {
        guard let url = URL(string: "\(baseURL)/gis/navigation/districts") else {
            return nil
        }
        var request = URLRequest(url: url)
        request.cachePolicy = forceRefresh ? .reloadIgnoringLocalCacheData : .useProtocolCachePolicy
        return request
    }
    
    // MARK: - District Boundaries GeoJSON
    
    public func getDistrictsGeoJSON(forceRefresh: Bool = false) async throws -> Data {
        lock.lock()
        if !forceRefresh, let cached = cachedDistrictsGeoJSON {
            lock.unlock()
            return cached
        }
        lock.unlock()
        
        guard let request = makeDistrictsGeoJSONRequest(forceRefresh: forceRefresh) else {
            throw URLError(.badURL)
        }
        
        let (data, response) = try await urlSession.data(for: request)
        if let httpRes = response as? HTTPURLResponse, httpRes.statusCode >= 400 {
            throw URLError(.badServerResponse)
        }
        
        lock.lock()
        cachedDistrictsGeoJSON = data
        lock.unlock()
        return data
    }
    
    // MARK: - Tahasils Boundaries GeoJSON
    
    public func makeTahasilsGeoJSONRequest(districtID: String, forceRefresh: Bool = false) -> URLRequest? {
        guard let url = URL(string: "\(baseURL)/gis/navigation/districts/\(districtID)/tahasils-geojson") else {
            return nil
        }
        var request = URLRequest(url: url)
        request.cachePolicy = forceRefresh ? .reloadIgnoringLocalCacheData : .useProtocolCachePolicy
        return request
    }
    
    public func getTahasilsGeoJSON(districtID: String, forceRefresh: Bool = false) async throws -> Data {
        let cleanID = districtID.trimmingCharacters(in: .whitespacesAndNewlines)
        lock.lock()
        if !forceRefresh, let cached = cachedTahasilsGeoJSON[cleanID] {
            lock.unlock()
            return cached
        }
        lock.unlock()
        
        guard let request = makeTahasilsGeoJSONRequest(districtID: cleanID, forceRefresh: forceRefresh) else {
            throw URLError(.badURL)
        }
        
        let (data, response) = try await urlSession.data(for: request)
        if let httpRes = response as? HTTPURLResponse, httpRes.statusCode >= 400 {
            throw URLError(.badServerResponse)
        }
        
        lock.lock()
        cachedTahasilsGeoJSON[cleanID] = data
        lock.unlock()
        return data
    }
    
    // MARK: - District Summaries
    
    public func getDistricts(forceRefresh: Bool = false) async throws -> [GISDistrictFeature] {
        lock.lock()
        if !forceRefresh, let cached = cachedDistrictsSummary {
            lock.unlock()
            return cached
        }
        lock.unlock()
        
        guard let request = makeDistrictsSummaryRequest(forceRefresh: forceRefresh) else {
            throw URLError(.badURL)
        }
        
        do {
            let (data, response) = try await urlSession.data(for: request)
            if let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200 {
                let districts = try JSONDecoder().decode([GISDistrictFeature].self, from: data)
                lock.lock()
                cachedDistrictsSummary = districts
                lock.unlock()
                return districts
            }
        } catch {
            debugLog("[GISExplorerRepository] ⚠️ Backend districts summary failed: \(error). Falling back to CadastralRepository...")
        }
        
        // Fallback: Read existing CadastralDistrict list and map centroids
        let existingDistricts = try await cadastralRepo.getDistricts(state: "ODISHA")
        let fallback = existingDistricts.map { d in
            GISDistrictFeature(
                id: d.id,
                name: d.name,
                code2Digit: d.id,
                bhulekhID: nil,
                centerLat: AppConfig.defaultLatitude,
                centerLng: AppConfig.defaultLongitude,
                bbox: [81.0, 17.5, 87.5, 22.5]
            )
        }
        lock.lock()
        cachedDistrictsSummary = fallback
        lock.unlock()
        return fallback
    }
    
    // MARK: - In-Memory Cache Controls
    
    public func cacheDistricts(_ districts: [GISDistrictFeature]) {
        lock.lock()
        defer { lock.unlock() }
        cachedDistrictsSummary = districts
    }
    
    public func getCachedDistricts() -> [GISDistrictFeature]? {
        lock.lock()
        defer { lock.unlock() }
        return cachedDistrictsSummary
    }
    
    public func clearCachedDistricts() {
        lock.lock()
        defer { lock.unlock() }
        cachedDistrictsSummary = nil
    }
    
    public func restoreCachedDistricts(_ districts: [GISDistrictFeature]?) {
        lock.lock()
        defer { lock.unlock() }
        cachedDistrictsSummary = districts
    }
    
    // MARK: - Subdivisions (Tahasils / Blocks)
    
    public func getSubdivisions(districtID: String) async throws -> [CadastralBlock] {
        lock.lock()
        if let cached = cachedSubdivisions[districtID] {
            lock.unlock()
            return cached
        }
        lock.unlock()
        
        // Try dedicated navigation endpoint
        if let url = URL(string: "\(baseURL)/gis/navigation/districts/\(districtID)/subdivisions") {
            if let (data, response) = try? await urlSession.data(from: url),
               let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200,
               let blocks = try? JSONDecoder().decode([CadastralBlock].self, from: data), !blocks.isEmpty {
                lock.lock()
                cachedSubdivisions[districtID] = blocks
                lock.unlock()
                return blocks
            }
        }
        
        // Safe Fallback: Existing CadastralRepository
        let blocks = try await cadastralRepo.getBlocks(districtID: districtID, state: "ODISHA")
        lock.lock()
        cachedSubdivisions[districtID] = blocks
        lock.unlock()
        return blocks
    }
    
    // MARK: - Villages
    
    public func getVillages(subdivisionID: String) async throws -> [CadastralVillage] {
        lock.lock()
        if let cached = cachedVillages[subdivisionID] {
            lock.unlock()
            return cached
        }
        lock.unlock()
        
        // Try dedicated navigation endpoint
        if let url = URL(string: "\(baseURL)/gis/navigation/subdivisions/\(subdivisionID)/villages") {
            if let (data, response) = try? await urlSession.data(from: url),
               let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200,
               let vills = try? JSONDecoder().decode([CadastralVillage].self, from: data), !vills.isEmpty {
                lock.lock()
                cachedVillages[subdivisionID] = vills
                lock.unlock()
                return vills
            }
        }
        
        // Safe Fallback: Existing CadastralRepository
        let vills = try await cadastralRepo.getVillages(blockID: subdivisionID, gpID: nil, state: "ODISHA")
        lock.lock()
        cachedVillages[subdivisionID] = vills
        lock.unlock()
        return vills
    }
    
    // MARK: - Extent
    
    public func getVillageExtent(village: CadastralVillage) async throws -> CadastralExtent {
        try await cadastralRepo.getVillageExtent(village: village, state: "ODISHA")
    }
    
    // MARK: - Parcels
    
    public func loadVillageParcels(village: CadastralVillage) async throws -> (data: ParsedVillageCadastralData, isCacheHit: Bool) {
        try await cadastralRepo.loadVillageParcels(village: village, state: "ODISHA")
    }
}
