import Foundation
import CoreLocation
import Combine
import MapLibre

public final class CadastralRepository: ObservableObject {
    public static let shared = CadastralRepository()
    
    private let apiClient: CadastralAPIClient
    
    // In-Memory Hierarchy Caches (Strictly namespaced by state)
    private var districtsCache: [String: [CadastralDistrict]] = [:]
    private var blocksCache: [String: [CadastralBlock]] = [:]
    private var gpsCache: [String: [CadastralGP]] = [:]
    private var villagesHierarchyCache: [String: [CadastralVillage]] = [:]
    
    // In-Memory Session Parcel Caches
    private var villageCache: [String: ParsedVillageCadastralData] = [:]
    private var extentsCache: [String: CadastralExtent] = [:]
    
    // Single-Flight In-Flight Task Coalescing
    private var inFlightDistrictsTasks: [String: Task<[CadastralDistrict], Error>] = [:]
    private var inFlightBlocksTasks: [String: Task<[CadastralBlock], Error>] = [:]
    private var inFlightGPsTasks: [String: Task<[CadastralGP], Error>] = [:]
    private var inFlightVillagesTasks: [String: Task<[CadastralVillage], Error>] = [:]
    
    private let lock = NSLock()
    
    public init(apiClient: CadastralAPIClient = .shared) {
        self.apiClient = apiClient
    }
    
    // MARK: - Hierarchy (Districts)
    
    public func getDistricts(state: String = "ODISHA", forceRefresh: Bool = false) async throws -> [CadastralDistrict] {
        let normState = state.uppercased()
        lock.lock()
        if !forceRefresh, let cached = districtsCache[normState], !cached.isEmpty {
            lock.unlock()
            return cached
        }
        
        if let existingTask = inFlightDistrictsTasks[normState] {
            lock.unlock()
            return try await existingTask.value
        }
        
        let task = Task.detached(priority: .userInitiated) { [weak self] () -> [CadastralDistrict] in
            guard let self = self else { return [] }
            #if DEBUG
            print("[CadastralRepository] 📡 Request state=\(normState) endpoint=/gis/districts provider=\(normState)")
            #endif
            
            let list: [CadastralDistrict]
            do {
                let fetched = try await self.apiClient.fetchDistricts(state: normState)
                
                // STATE ISOLATION & LEAK DETECTION
                if normState == "BIHAR" {
                    let isOdishaLeak = fetched.contains { $0.id == "161" || $0.id == "224" || $0.name.caseInsensitiveCompare("Anugul") == .orderedSame || $0.name.caseInsensitiveCompare("Keonjhar") == .orderedSame }
                    if isOdishaLeak {
                        #if DEBUG
                        print("[CadastralRepository] 🚨 Remote backend returned Odisha districts for state=BIHAR. Using isolated Bihar provider.")
                        list = BiharDebugFixtures.debugDistricts
                        #else
                        throw CadastralAPIError.biharGisDisabled("Bihar cadastral GIS is not enabled on this server.")
                        #endif
                    } else {
                        list = fetched
                    }
                } else {
                    list = fetched
                }
            } catch {
                #if DEBUG
                if normState == "BIHAR" {
                    print("[CadastralRepository] ⚠️ Using DEBUG Bihar districts fallback: \(BiharDebugFixtures.debugDistricts.count) districts")
                    list = BiharDebugFixtures.debugDistricts
                } else {
                    throw error
                }
                #else
                throw error
                #endif
            }
            
            self.lock.lock()
            self.districtsCache[normState] = list
            self.inFlightDistrictsTasks[normState] = nil
            self.lock.unlock()
            return list
        }
        self.inFlightDistrictsTasks[normState] = task
        lock.unlock()
        
        do {
            return try await task.value
        } catch {
            lock.lock()
            self.inFlightDistrictsTasks[normState] = nil
            lock.unlock()
            throw error
        }
    }
    
    // MARK: - Hierarchy (Blocks / Circles)
    
    public func getBlocks(districtID: String, state: String = "ODISHA") async throws -> [CadastralBlock] {
        let normState = state.uppercased()
        let key = "\(normState)_\(districtID)"
        lock.lock()
        if let cached = blocksCache[key], !cached.isEmpty {
            lock.unlock()
            return cached
        }
        if let existing = inFlightBlocksTasks[key] {
            lock.unlock()
            return try await existing.value
        }
        
        let task = Task.detached(priority: .userInitiated) { [weak self] () -> [CadastralBlock] in
            guard let self = self else { return [] }
            #if DEBUG
            print("[CadastralRepository] 📡 Request state=\(normState) endpoint=/gis/blocks districtID=\(districtID) provider=\(normState)")
            #endif
            
            let list: [CadastralBlock]
            do {
                let fetched = try await self.apiClient.fetchBlocks(districtID: districtID, state: normState)
                if normState == "BIHAR" {
                    let isOdishaLeak = fetched.contains { !$0.id.hasPrefix("BR_") }
                    if isOdishaLeak {
                        #if DEBUG
                        list = BiharDebugFixtures.debugBlocks[districtID] ?? []
                        #else
                        throw CadastralAPIError.biharGisDisabled("Bihar blocks unavailable.")
                        #endif
                    } else {
                        list = fetched
                    }
                } else {
                    list = fetched
                }
            } catch {
                #if DEBUG
                if normState == "BIHAR" {
                    list = BiharDebugFixtures.debugBlocks[districtID] ?? []
                    print("[CadastralRepository] ⚠️ Using DEBUG Bihar blocks fallback for \(districtID): \(list.count) blocks")
                } else {
                    throw error
                }
                #else
                throw error
                #endif
            }
            
            self.lock.lock()
            self.blocksCache[key] = list
            self.inFlightBlocksTasks[key] = nil
            self.lock.unlock()
            return list
        }
        inFlightBlocksTasks[key] = task
        lock.unlock()
        
        do {
            return try await task.value
        } catch {
            lock.lock()
            inFlightBlocksTasks[key] = nil
            lock.unlock()
            throw error
        }
    }
    
    // MARK: - Hierarchy (GPs / Halkas)
    
    public func getGPs(blockID: String, state: String = "ODISHA") async throws -> [CadastralGP] {
        let normState = state.uppercased()
        let key = "\(normState)_\(blockID)"
        lock.lock()
        if let cached = gpsCache[key], !cached.isEmpty {
            lock.unlock()
            return cached
        }
        if let existing = inFlightGPsTasks[key] {
            lock.unlock()
            return try await existing.value
        }
        
        let task = Task.detached(priority: .userInitiated) { [weak self] () -> [CadastralGP] in
            guard let self = self else { return [] }
            #if DEBUG
            print("[CadastralRepository] 📡 Request state=\(normState) endpoint=/gis/gps blockID=\(blockID) provider=\(normState)")
            #endif
            
            let list: [CadastralGP]
            do {
                let fetched = try await self.apiClient.fetchGPs(blockID: blockID, state: normState)
                if normState == "BIHAR" {
                    let isOdishaLeak = fetched.contains { !$0.id.hasPrefix("BR_") }
                    if isOdishaLeak {
                        #if DEBUG
                        list = BiharDebugFixtures.debugGPs[blockID] ?? [CadastralGP(id: "\(blockID)_01", name: "Halka 01", blockID: blockID)]
                        #else
                        throw CadastralAPIError.biharGisDisabled("Bihar Halkas unavailable.")
                        #endif
                    } else {
                        list = fetched
                    }
                } else {
                    list = fetched
                }
            } catch {
                #if DEBUG
                if normState == "BIHAR" {
                    list = BiharDebugFixtures.debugGPs[blockID] ?? [CadastralGP(id: "\(blockID)_01", name: "Halka 01", blockID: blockID)]
                    print("[CadastralRepository] ⚠️ Using DEBUG Bihar GPs fallback for \(blockID): \(list.count) GPs")
                } else {
                    throw error
                }
                #else
                throw error
                #endif
            }
            
            self.lock.lock()
            self.gpsCache[key] = list
            self.inFlightGPsTasks[key] = nil
            self.lock.unlock()
            return list
        }
        inFlightGPsTasks[key] = task
        lock.unlock()
        
        do {
            return try await task.value
        } catch {
            lock.lock()
            inFlightGPsTasks[key] = nil
            lock.unlock()
            throw error
        }
    }
    
    // MARK: - Hierarchy (Villages / Mauzas)
    
    public func getVillages(blockID: String, gpID: String? = nil, state: String = "ODISHA") async throws -> [CadastralVillage] {
        let normState = state.uppercased()
        let key = "\(normState)_\(blockID)_\(gpID ?? "")"
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
            #if DEBUG
            print("[CadastralRepository] 📡 Request state=\(normState) endpoint=/gis/villages blockID=\(blockID) gpID=\(gpID ?? "none") provider=\(normState)")
            #endif
            
            let list: [CadastralVillage]
            do {
                let fetched = try await self.apiClient.fetchVillages(blockID: blockID, gpID: gpID, state: normState)
                if normState == "BIHAR" {
                    let isOdishaLeak = fetched.contains { !$0.id.hasPrefix("BR_") }
                    if isOdishaLeak {
                        #if DEBUG
                        list = BiharDebugFixtures.debugVillages[blockID] ?? []
                        #else
                        throw CadastralAPIError.biharGisDisabled("Bihar Mauzas unavailable.")
                        #endif
                    } else {
                        list = fetched
                    }
                } else {
                    list = fetched
                }
            } catch {
                #if DEBUG
                if normState == "BIHAR" {
                    list = BiharDebugFixtures.debugVillages[blockID] ?? []
                    print("[CadastralRepository] ⚠️ Using DEBUG Bihar villages fallback for \(blockID): \(list.count) villages")
                } else {
                    throw error
                }
                #else
                throw error
                #endif
            }
            
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
    
    public func getVillageExtent(village: CadastralVillage, state: String = "ODISHA") async throws -> CadastralExtent {
        let normState = state.uppercased()
        let key = "\(normState)_\(village.id)"
        if let cached = extentsCache[key] {
            return cached
        }
        
        #if DEBUG
        print("[CadastralRepository] 📡 Request state=\(normState) endpoint=/gis/village/\(village.id)/extent provider=\(normState)")
        #endif
        
        do {
            let extent = try await apiClient.fetchVillageExtent(villageID: village.id, gpID: village.gpID, state: normState)
            extentsCache[key] = extent
            return extent
        } catch {
            #if DEBUG
            if normState == "BIHAR" {
                let fallback = CadastralExtent(minLng: 85.1200, minLat: 25.5900, maxLng: 85.1320, maxLat: 25.6020, centerLng: 85.1260, centerLat: 25.5960)
                extentsCache[key] = fallback
                return fallback
            }
            #endif
            throw error
        }
    }
    
    // MARK: - Village Parcels
    
    public func loadVillageParcels(
        village: CadastralVillage,
        sheetNo: String? = nil,
        state: String = "ODISHA"
    ) async throws -> (data: ParsedVillageCadastralData, isCacheHit: Bool) {
        let normState = state.uppercased()
        let key = "\(normState)_\(village.id)_\(sheetNo ?? "all")"
        if let cached = villageCache[key] {
            return (cached, true)
        }
        
        #if DEBUG
        print("[CadastralRepository] 📡 Request state=\(normState) endpoint=/gis/village/\(village.id)/parcels provider=\(normState)")
        #endif
        
        let rawData: Data
        do {
            let fetched = try await apiClient.fetchVillageParcelsRawGeoJSON(
                villageID: village.id,
                districtName: village.districtName,
                blockName: village.blockName,
                gpName: village.gpID,
                villageName: village.name,
                sheetNo: sheetNo,
                state: normState
            )
            
            if normState == "BIHAR" {
                // Verify that raw GeoJSON is actually Bihar
                if let str = String(data: fetched, encoding: .utf8), str.contains("ODISHA_4K_GEO") {
                    #if DEBUG
                    print("[CadastralRepository] 🚨 Remote backend returned Odisha GeoJSON for Bihar query. Using isolated Begampur fixture.")
                    rawData = Data(BiharDebugFixtures.begampurSheet01GeoJSON.utf8)
                    #else
                    throw CadastralAPIError.biharGisDisabled("Bihar parcels unavailable.")
                    #endif
                } else {
                    rawData = fetched
                }
            } else {
                rawData = fetched
            }
        } catch {
            #if DEBUG
            if normState == "BIHAR" {
                print("[CadastralRepository] ⚠️ Using DEBUG Bihar GeoJSON fallback for \(village.name)")
                rawData = Data(BiharDebugFixtures.begampurSheet01GeoJSON.utf8)
            } else {
                throw error
            }
            #else
            throw error
            #endif
        }
        
        // Parse off the main thread
        let parsed = await _Concurrency.Task.detached(priority: .userInitiated) {
            GeoJSONFeatureParser.parse(data: rawData, village: village)
        }.value
        
        villageCache[key] = parsed
        return (parsed, false)
    }
    
    public func getParcelByPlot(village: CadastralVillage, plotNumber: String, sheetNo: String? = nil, state: String = "ODISHA") -> CadastralParcel? {
        let normState = state.uppercased()
        let key = "\(normState)_\(village.id)_\(sheetNo ?? "all")"
        guard let cached = villageCache[key] else { return nil }
        let cleanPlot = plotNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        return cached.parcels.first(where: { $0.plotNumber == cleanPlot })
    }
    
    public func identifyParcel(at coordinate: CLLocationCoordinate2D, in village: CadastralVillage, sheetNo: String? = nil, state: String = "ODISHA") -> CadastralParcel? {
        let normState = state.uppercased()
        let key = "\(normState)_\(village.id)_\(sheetNo ?? "all")"
        guard let cached = villageCache[key] else { return nil }
        
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
