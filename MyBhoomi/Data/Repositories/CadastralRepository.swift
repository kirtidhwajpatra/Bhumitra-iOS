import Foundation
import CoreLocation
import Combine
import MapLibre

public final class CadastralRepository: ObservableObject {
    public static let shared = CadastralRepository()
    
    private let apiClient: CadastralAPIClient
    
    // Persistent Storage Key
    public static let cachedDistrictsKey = "bhumitra_cached_districts_v1"
    
    // In-Memory Hierarchy Caches
    public private(set) var cachedDistricts: [CadastralDistrict]? = nil
    private var blocksCache: [String: [CadastralBlock]] = [:]
    private var gpsCache: [String: [CadastralGP]] = [:]
    private var villagesHierarchyCache: [String: [CadastralVillage]] = [:]
    
    // In-Memory Session Parcel Caches
    private var villageCache: [String: ParsedVillageCadastralData] = [:]
    private var extentsCache: [String: CadastralExtent] = [:]
    
    // Single-Flight In-Flight Task Coalescing
    private var inFlightDistrictsTask: Task<[CadastralDistrict], Error>? = nil
    private var inFlightBlocksTasks: [String: Task<[CadastralBlock], Error>] = [:]
    private var inFlightGPsTasks: [String: Task<[CadastralGP], Error>] = [:]
    private var inFlightVillagesTasks: [String: Task<[CadastralVillage], Error>] = [:]
    
    private let lock = NSLock()
    
    public init(apiClient: CadastralAPIClient = .shared) {
        self.apiClient = apiClient
        
        // 1. Immediately hydrate cached districts from local storage
        if let data = UserDefaults.standard.data(forKey: Self.cachedDistrictsKey),
           let saved = try? JSONDecoder().decode([CadastralDistrict].self, from: data),
           !saved.isEmpty {
            self.cachedDistricts = saved
            print("[Districts] cache hit (restored \(saved.count) districts from local storage)")
        }
    }
    
    // MARK: - Hierarchy (Districts)
    
    public func getDistricts(forceRefresh: Bool = false) async throws -> [CadastralDistrict] {
        lock.lock()
        // 1. Return immediately from cache if available and not forcing network
        if !forceRefresh, let cached = cachedDistricts, !cached.isEmpty {
            print("[Districts] cache hit (count: \(cached.count))")
            
            // Dispatch background refresh if not already in flight
            if inFlightDistrictsTask == nil {
                inFlightDistrictsTask = Task.detached(priority: .utility) { [weak self] () -> [CadastralDistrict] in
                    guard let self = self else { return cached }
                    return try await self.refreshDistrictsFromNetwork()
                }
            }
            lock.unlock()
            return cached
        }
        
        // 2. Coalesce concurrent in-flight district requests
        if let existingTask = inFlightDistrictsTask {
            print("[Districts] coalescing onto existing in-flight request")
            lock.unlock()
            return try await existingTask.value
        }
        
        print("[Districts] cache miss")
        let task = Task.detached(priority: .userInitiated) { [weak self] () -> [CadastralDistrict] in
            guard let self = self else { return [] }
            return try await self.refreshDistrictsFromNetwork()
        }
        self.inFlightDistrictsTask = task
        lock.unlock()
        
        return try await task.value
    }
    
    private func refreshDistrictsFromNetwork() async throws -> [CadastralDistrict] {
        print("[Districts] network refresh started")
        do {
            let list = try await apiClient.fetchDistricts()
            
            lock.lock()
            self.cachedDistricts = list
            self.inFlightDistrictsTask = nil
            lock.unlock()
            
            // Persist to local storage
            if let data = try? JSONEncoder().encode(list) {
                UserDefaults.standard.set(data, forKey: Self.cachedDistrictsKey)
            }
            
            print("[Districts] network success")
            print("[Districts] displayed count: \(list.count)")
            return list
        } catch {
            print("[Districts] network failure: \(error.localizedDescription)")
            
            lock.lock()
            self.inFlightDistrictsTask = nil
            let fallback = self.cachedDistricts
            lock.unlock()
            
            // If we have cached districts, keep them and do not throw
            if let fallback = fallback, !fallback.isEmpty {
                print("[Districts] keeping cached list (\(fallback.count) districts) despite network failure")
                return fallback
            }
            
            throw error
        }
    }
    
    // MARK: - Hierarchy (Blocks)
    
    public func getBlocks(districtID: String) async throws -> [CadastralBlock] {
        lock.lock()
        if let cached = blocksCache[districtID], !cached.isEmpty {
            lock.unlock()
            return cached
        }
        if let existing = inFlightBlocksTasks[districtID] {
            lock.unlock()
            return try await existing.value
        }
        
        let task = Task.detached(priority: .userInitiated) { [weak self] () -> [CadastralBlock] in
            guard let self = self else { return [] }
            let list = try await self.apiClient.fetchBlocks(districtID: districtID)
            self.lock.lock()
            self.blocksCache[districtID] = list
            self.inFlightBlocksTasks[districtID] = nil
            self.lock.unlock()
            return list
        }
        inFlightBlocksTasks[districtID] = task
        lock.unlock()
        
        do {
            return try await task.value
        } catch {
            lock.lock()
            inFlightBlocksTasks[districtID] = nil
            lock.unlock()
            throw error
        }
    }
    
    // MARK: - Hierarchy (GPs)
    
    public func getGPs(blockID: String) async throws -> [CadastralGP] {
        lock.lock()
        if let cached = gpsCache[blockID], !cached.isEmpty {
            lock.unlock()
            return cached
        }
        if let existing = inFlightGPsTasks[blockID] {
            lock.unlock()
            return try await existing.value
        }
        
        let task = Task.detached(priority: .userInitiated) { [weak self] () -> [CadastralGP] in
            guard let self = self else { return [] }
            let list = try await self.apiClient.fetchGPs(blockID: blockID)
            self.lock.lock()
            self.gpsCache[blockID] = list
            self.inFlightGPsTasks[blockID] = nil
            self.lock.unlock()
            return list
        }
        inFlightGPsTasks[blockID] = task
        lock.unlock()
        
        do {
            return try await task.value
        } catch {
            lock.lock()
            inFlightGPsTasks[blockID] = nil
            lock.unlock()
            throw error
        }
    }
    
    // MARK: - Hierarchy (Villages)
    
    public func getVillages(blockID: String, gpID: String? = nil) async throws -> [CadastralVillage] {
        let key = "\(blockID)_\(gpID ?? "")"
        lock.lock()
        if let cached = villagesHierarchyCache[key], !cached.isEmpty {
            lock.unlock()
            return cached
        }
        if let existing = inFlightVillagesTasks[key] {
            lock.unlock()
            return try await existing.value
        }
        
        let task = Task.detached(priority: .userInitiated) { [weak self] () -> [CadastralVillage] in
            guard let self = self else { return [] }
            let list = try await self.apiClient.fetchVillages(blockID: blockID, gpID: gpID)
            self.lock.lock()
            self.villagesHierarchyCache[key] = list
            self.inFlightVillagesTasks[key] = nil
            self.lock.unlock()
            return list
        }
        inFlightVillagesTasks[key] = task
        lock.unlock()
        
        do {
            return try await task.value
        } catch {
            lock.lock()
            inFlightVillagesTasks[key] = nil
            lock.unlock()
            throw error
        }
    }
    
    public func getVillageExtent(village: CadastralVillage) async throws -> CadastralExtent {
        if let cached = extentsCache[village.id] {
            return cached
        }
        let extent = try await apiClient.fetchVillageExtent(villageID: village.id, gpID: village.gpID)
        extentsCache[village.id] = extent
        return extent
    }
    
    // MARK: - Village Parcels
    
    public func loadVillageParcels(village: CadastralVillage) async throws -> (data: ParsedVillageCadastralData, isCacheHit: Bool) {
        if let cached = villageCache[village.id] {
            return (cached, true)
        }
        
        let rawData = try await apiClient.fetchVillageParcelsRawGeoJSON(
            villageID: village.id,
            districtName: village.districtName,
            blockName: village.blockName,
            gpName: village.gpID,
            villageName: village.name
        )
        
        // Parse off the main thread
        let parsed = await _Concurrency.Task.detached(priority: .userInitiated) {
            GeoJSONFeatureParser.parse(data: rawData, village: village)
        }.value
        
        villageCache[village.id] = parsed
        return (parsed, false)
    }
    
    public func getParcelByPlot(village: CadastralVillage, plotNumber: String) -> CadastralParcel? {
        guard let cached = villageCache[village.id] else { return nil }
        let cleanPlot = plotNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        return cached.parcels.first(where: { $0.plotNumber == cleanPlot })
    }
    
    public func identifyParcel(at coordinate: CLLocationCoordinate2D, in village: CadastralVillage) -> CadastralParcel? {
        guard let cached = villageCache[village.id] else { return nil }
        
        for parcel in cached.parcels {
            if parcel.boundary.count >= 3 && pointInPolygon(coord: coordinate, polygon: parcel.boundary) {
                return parcel
            }
        }
        return nil
    }
    
    private func pointInPolygon(coord: CLLocationCoordinate2D, polygon: [Coordinate]) -> Bool {
        guard polygon.count >= 3 else { return false }
        var inside = false
        var j = polygon.count - 1
        
        for i in 0..<polygon.count {
            let pi = polygon[i]
            let pj = polygon[j]
            
            if (pi.latitude > coord.latitude) != (pj.latitude > coord.latitude) &&
                (coord.longitude < (pj.longitude - pi.longitude) * (coord.latitude - pi.latitude) / (pj.latitude - pi.latitude) + pi.longitude) {
                inside = !inside
            }
            j = i
        }
        return inside
    }
}
