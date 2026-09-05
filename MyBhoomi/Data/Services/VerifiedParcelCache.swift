//
//  VerifiedParcelCache.swift
//  MyBhoomi
//
//  Thread-safe, persistent local cache for successfully resolved and verified land parcels.
//  Implements LRU eviction (max 10 items), canonical key isolation, and smart search suggestions.
//

import Foundation
import Combine
import CoreLocation

/// Persistent local cache service for verified land records.
/// Guarantees:
/// - Thread-safe access with MainActor published state
/// - Persistent JSON storage in Application Support / Documents directory
/// - Strict LRU eviction capped at `maxSize` (default: 10 items)
/// - Canonical key isolation: `districtID:tahasilID:villageID:plotNumber`
/// - Strict verification validation: NEVER stores 404/422/502/unverified records
@MainActor
public final class VerifiedParcelCache: ObservableObject {
    
    public static let shared = VerifiedParcelCache()
    
    public static let defaultMaxSize = 10
    public let maxSize: Int
    
    @Published public private(set) var recentParcels: [CachedVerifiedParcel] = []
    
    private let fileURL: URL
    private let queue = DispatchQueue(label: "com.bhumitra.verifiedParcelCache", qos: .userInitiated)
    
    public static let cacheVersion = 3
    public static let defaultCacheFilename = "bhumitra_verified_parcels_cache_v3.json"
    private static let legacyCacheFilenames = ["verified_parcels_cache.json", "bhumitra_verified_parcels_cache_v2.json"]
    
    public init(maxSize: Int = VerifiedParcelCache.defaultMaxSize, customFilename: String = VerifiedParcelCache.defaultCacheFilename) {
        self.maxSize = maxSize
        
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        // Ensure Application Support directory exists
        try? fileManager.createDirectory(at: appSupport, withIntermediateDirectories: true)
        self.fileURL = appSupport.appendingPathComponent(customFilename)
        
        // Invalidate and purge legacy unversioned/v2 cache files to prevent contaminated legacy results
        for legacyName in Self.legacyCacheFilenames {
            let legacyURL = appSupport.appendingPathComponent(legacyName)
            if fileManager.fileExists(atPath: legacyURL.path) {
                try? fileManager.removeItem(at: legacyURL)
                print("[VerifiedParcelCache] Purged legacy cache file: \(legacyURL.lastPathComponent)")
            }
        }
        
        loadFromDisk()
    }
    
    // MARK: - Public API
    
    /// Saves or updates a verified parcel in the cache.
    /// Only caches if the verification state is strictly verified.
    @discardableResult
    public func save(
        identity: CanonicalParcelIdentity,
        ror: RoRResponse,
        verification: ParcelVerificationResult,
        boundary: [Coordinate]? = nil
    ) -> Bool {
        // Enforce Safety Invariant: NEVER cache unverified / failed records
        guard verification.isVerified || (ror.verification?.status == .verified && verification.status == .verified) else {
            print("[VerifiedParcelCache] Rejected unverified parcel cache write for plot: \(identity.plotNumber)")
            return false
        }
        
        guard let cachedParcel = CachedVerifiedParcel(
            identity: identity,
            ror: ror,
            verification: verification,
            boundary: boundary
        ) else {
            print("[VerifiedParcelCache] Failed to construct CachedVerifiedParcel from identity and ror")
            return false
        }
        
        return save(cachedParcel)
    }
    
    /// Directly saves a `CachedVerifiedParcel` enforcing LRU constraints.
    @discardableResult
    public func save(_ parcel: CachedVerifiedParcel) -> Bool {
        // Enforce Single Source of Truth: NEVER store unverified / failed records
        guard parcel.resolutionStatus == .verified else {
            print("[VerifiedParcelCache] Rejected unverified parcel save for key: \(parcel.canonicalKey)")
            return false
        }
        
        // Remove existing entry with identical canonicalKey if present (deduplication)
        var updatedList = recentParcels.filter { $0.canonicalKey != parcel.canonicalKey }
        
        // Set lastAccessedAt to now and insert at the top (index 0)
        var newParcel = parcel
        newParcel.lastAccessedAt = Date()
        updatedList.insert(newParcel, at: 0)
        
        // Enforce LRU eviction cap: keep only the newest `maxSize` elements
        if updatedList.count > maxSize {
            updatedList = Array(updatedList.prefix(maxSize))
        }
        
        self.recentParcels = updatedList
        saveToDisk()
        print("[VerifiedParcelCache] Saved verified parcel: \(parcel.canonicalKey). Total cached: \(recentParcels.count)")
        return true
    }
    
    /// Retrieves a cached parcel by its canonical identity.
    /// Updates `lastAccessedAt` and moves the item to the top of the LRU stack on hit.
    public func get(identity: CanonicalParcelIdentity) -> CachedVerifiedParcel? {
        let distId = identity.districtID ?? ""
        let tahId = identity.tahasilID ?? ""
        let villId = identity.villageID ?? ""
        let plot = identity.plotNumber
        
        return get(districtID: distId, tahasilID: tahId, villageID: villId, plot: plot)
    }
    
    /// Retrieves a cached parcel by administrative coordinates and plot number.
    public func get(
        districtID: String,
        tahasilID: String,
        villageID: String,
        plot: String
    ) -> CachedVerifiedParcel? {
        guard !villageID.isEmpty, villageID != "N/A", !plot.isEmpty, plot != "N/A" else {
            return nil
        }
        let key = "\(districtID):\(tahasilID):\(villageID):\(plot)"
        return get(canonicalKey: key)
    }
    
    /// Retrieves a cached parcel by its canonical key.
    public func get(canonicalKey: String) -> CachedVerifiedParcel? {
        guard let index = recentParcels.firstIndex(where: { $0.canonicalKey == canonicalKey }) else {
            print("[VerifiedParcelCache] Cache miss for key: \(canonicalKey)")
            return nil
        }
        
        // Update last accessed time and move to top
        var item = recentParcels[index]
        item.lastAccessedAt = Date()
        recentParcels.remove(at: index)
        recentParcels.insert(item, at: 0)
        
        saveToDisk()
        print("[VerifiedParcelCache] Cache HIT for key: \(canonicalKey)")
        return item
    }
    
    /// Returns all recently verified parcels sorted by `lastAccessedAt` descending.
    public func getAllRecent() -> [CachedVerifiedParcel] {
        return recentParcels.sorted { $0.lastAccessedAt > $1.lastAccessedAt }
    }
    
    /// Updates the access time of an existing parcel without modifying other fields.
    public func touch(canonicalKey: String) {
        _ = get(canonicalKey: canonicalKey)
    }
    
    /// Removes a specific cached parcel by canonical key.
    public func delete(canonicalKey: String) {
        recentParcels.removeAll { $0.canonicalKey == canonicalKey }
        saveToDisk()
    }
    
    /// Clears the entire local parcel cache.
    public func clearHistory() {
        recentParcels.removeAll()
        saveToDisk()
        print("[VerifiedParcelCache] Cleared all local verified parcels.")
    }
    
    // MARK: - Smart Search Suggestions
    
    /// Returns ranked search suggestions matching the user's query across plot, village, khata, tahasil, or district.
    /// Ranking order:
    /// 1. Exact plot match
    /// 2. Exact village match
    /// 3. Exact Khata match
    /// 4. Village prefix match
    /// 5. Tahasil match
    /// 6. District match
    /// 7. Recent usage
    public func searchSuggestions(query: String) -> [CachedVerifiedParcel] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else {
            return getAllRecent()
        }
        
        var scoredItems: [(parcel: CachedVerifiedParcel, score: Int)] = []
        
        for parcel in recentParcels {
            let plot = parcel.plotNumber.lowercased()
            let village = parcel.villageName.lowercased()
            let khata = parcel.khataNumber.lowercased()
            let tahasil = parcel.tahasilName.lowercased()
            let district = parcel.districtName.lowercased()
            
            var score = 0
            
            if plot == trimmed {
                score += 1000 // 1. Exact plot match
            } else if plot.hasPrefix(trimmed) {
                score += 800
            } else if plot.contains(trimmed) {
                score += 600
            }
            
            if village == trimmed {
                score += 500 // 2. Exact village match
            } else if village.hasPrefix(trimmed) {
                score += 400 // 4. Village prefix match
            } else if village.contains(trimmed) {
                score += 300
            }
            
            if khata == trimmed {
                score += 350 // 3. Exact Khata match
            } else if khata.contains(trimmed) {
                score += 250
            }
            
            if tahasil == trimmed || tahasil.hasPrefix(trimmed) {
                score += 200 // 5. Tahasil match
            } else if tahasil.contains(trimmed) {
                score += 150
            }
            
            if district == trimmed || district.hasPrefix(trimmed) {
                score += 100 // 6. District match
            } else if district.contains(trimmed) {
                score += 80
            }
            
            if score > 0 {
                scoredItems.append((parcel, score))
            }
        }
        
        // Sort by score descending, then lastAccessedAt descending
        return scoredItems
            .sorted {
                if $0.score != $1.score {
                    return $0.score > $1.score
                }
                return $0.parcel.lastAccessedAt > $1.parcel.lastAccessedAt
            }
            .map { $0.parcel }
    }
    
    // MARK: - Disk Persistence
    
    private func saveToDisk() {
        let itemsToSave = self.recentParcels
        let destination = self.fileURL
        
        queue.async {
            do {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                let data = try encoder.encode(itemsToSave)
                try data.write(to: destination, options: [.atomicWrite])
            } catch {
                print("[VerifiedParcelCache] Error writing cache to disk: \(error.localizedDescription)")
            }
        }
    }
    
    private func loadFromDisk() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            self.recentParcels = []
            return
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let loaded = try decoder.decode([CachedVerifiedParcel].self, from: data)
            
            // Deduplicate and cap at maxSize on startup
            var unique: [CachedVerifiedParcel] = []
            var seenKeys = Set<String>()
            
            for item in loaded.sorted(by: { $0.lastAccessedAt > $1.lastAccessedAt }) {
                if !seenKeys.contains(item.canonicalKey) {
                    seenKeys.insert(item.canonicalKey)
                    unique.append(item)
                }
                if unique.count >= maxSize {
                    break
                }
            }
            
            self.recentParcels = unique
            print("[VerifiedParcelCache] Loaded \(self.recentParcels.count) verified parcels from disk.")
        } catch {
            print("[VerifiedParcelCache] Error reading cache from disk: \(error.localizedDescription)")
            self.recentParcels = []
        }
    }
}
