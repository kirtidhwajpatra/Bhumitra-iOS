//
//  LocationSearchService.swift
//  MyBhoomi
//
//  Shared Production Location Search & Spatial Resolution Client Service.
//  Acts as the single authoritative source of truth for location searching
//  across HomeScreen and MapScreen.
//

import Foundation
import Combine

@MainActor
public final class LocationSearchService: ObservableObject {
    public static let shared = LocationSearchService()
    
    @Published public var isSearching: Bool = false
    @Published public var searchResults: [LocationSearchResult] = []
    @Published public var lastSearchError: String? = nil
    
    private let urlSession: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    
    // Concurrency & Debounce Protection (MainActor isolated)
    private var searchTask: Task<Void, Never>? = nil
    private var currentSearchSequence: UInt64 = 0
    
    // In-memory query cache for rapid repetition / backspacing (bounded)
    private var queryCache: [String: [LocationSearchResult]] = [:]
    private var queryCacheOrder: [String] = []
    private let queryCacheLimit = 200

    /// Supplies a "near" point (user location or the map area in view) so the
    /// backend ranks the user's own village first among same-named villages.
    public var proximityProvider: (@MainActor () -> Coordinate?)? = nil

    /// Proximity bucketed to ~10 km so small map pans reuse cached results.
    private func proximityBucket() -> (key: String, value: String?) {
        guard let c = proximityProvider?(),
              c.latitude.isFinite, c.longitude.isFinite else { return ("-", nil) }
        let lat = (c.latitude * 10).rounded() / 10
        let lng = (c.longitude * 10).rounded() / 10
        let value = String(format: "%.1f,%.1f", lat, lng)
        return (value, value)
    }

    private func cacheResults(_ results: [LocationSearchResult], forKey key: String) {
        if queryCache[key] == nil { queryCacheOrder.append(key) }
        queryCache[key] = results
        if queryCacheOrder.count > queryCacheLimit {
            let evicted = queryCacheOrder.removeFirst()
            queryCache.removeValue(forKey: evicted)
        }
    }
    
    private init(session: URLSession = .shared) {
        self.urlSession = session
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
    }
    
    private var baseURL: String {
        #if DEBUG
        // Debug-only: send just search/resolve to a local backend (set in the Xcode
        // scheme) while sign-in, credits, payments, parcels and RoR stay on the
        // normal server. Never compiled into Release builds.
        if let searchBase = ProcessInfo.processInfo.environment["MYBHOOMI_SEARCH_API_BASE"], !searchBase.isEmpty {
            return searchBase.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }
        #endif
        return APIConfiguration.shared.baseURL
    }
    
    // MARK: - Search API (Debounced 350ms, Sequence-Safe)
    
    public func search(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Cancel any pending search task immediately
        searchTask?.cancel()
        
        guard !trimmed.isEmpty else {
            currentSearchSequence &+= 1
            publish(isSearching: false, results: [], error: nil)
            return
        }
        
        // Increment sequence counter to invalidate any running in-flight network response
        currentSearchSequence &+= 1
        let sequence = currentSearchSequence
        
        // Check cache first for immediate zero-latency display
        let proximity = proximityBucket()
        let cacheKey = "\(trimmed.lowercased())|\(proximity.key)"
        if let cached = queryCache[cacheKey] {
            publish(isSearching: false, results: cached, error: nil)
            return
        }
        
        if !isSearching { self.isSearching = true }
        let perfStartTime = CFAbsoluteTimeGetCurrent()
        #if DEBUG
        debugLog("[PERF] SEARCH QUERY START '\(trimmed)' (sequence: \(sequence))")
        #endif
        
        searchTask = Task { [weak self] in
            guard let self = self else { return }
            
            // 250ms Debounce Delay (snappy, network-conserving)
            do {
                try await Task.sleep(nanoseconds: 250_000_000)
            } catch {
                #if DEBUG
                debugLog("[LocationSearchService] ⏹️ Debounce cancelled for '\(trimmed)'")
                #endif
                return // Cancelled during debounce
            }
            
            // Check if cancelled or superseded
            if Task.isCancelled || self.currentSearchSequence != sequence {
                return
            }
            
            // Perform network search
            do {
                let results = try await self.performSearchNetworkRequest(query: trimmed, near: proximity.value)
                
                // Guard sequence again after network call completes
                guard self.currentSearchSequence == sequence && !Task.isCancelled else { return }
                
                // Cache valid response
                self.cacheResults(results, forKey: cacheKey)
                
                self.publish(isSearching: false, results: results, error: nil)
                #if DEBUG
                let elapsedMs = Int((CFAbsoluteTimeGetCurrent() - perfStartTime) * 1000)
                debugLog("[PERF] SEARCH '\(trimmed)': \(elapsedMs)ms, \(results.count) results")
                #endif
            } catch {
                guard self.currentSearchSequence == sequence && !Task.isCancelled else { return }
                #if DEBUG
                let elapsedMs = Int((CFAbsoluteTimeGetCurrent() - perfStartTime) * 1000)
                debugLog("[PERF] SEARCH FAILED '\(trimmed)': \(elapsedMs)ms - \(error.localizedDescription)")
                #endif
                self.publish(isSearching: false, results: self.searchResults, error: error.localizedDescription)
            }
        }
    }
    
    public func clearSearch() {
        searchTask?.cancel()
        currentSearchSequence &+= 1
        publish(isSearching: false, results: [], error: nil)
    }
    
    /// Writes published state only when it differs. @Published emits on every
    /// assignment (even same value), and each emission re-renders observers.
    private func publish(isSearching: Bool, results: [LocationSearchResult], error: String?) {
        if self.isSearching != isSearching { self.isSearching = isSearching }
        if self.searchResults != results { self.searchResults = results }
        if self.lastSearchError != error { self.lastSearchError = error }
    }
    
    // MARK: - Direct Network Search Execution
    
    public func performSearchNetworkRequest(query: String, limit: Int = 10, near: String? = nil) async throws -> [LocationSearchResult] {
        let currentBase = baseURL
        var components = URLComponents(string: "\(currentBase)/location/search")
        var items = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        if let near { items.append(URLQueryItem(name: "near", value: near)) }
        components?.queryItems = items
        // URLComponents leaves "+" unescaped; the server would read it as a space.
        // (Read into a local first: reading and writing `components` in one
        // statement is an overlapping access error.)
        let encodedQuery = components?.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        components?.percentEncodedQuery = encodedQuery
        guard let url = components?.url else {
            #if DEBUG
            debugLog("[LocationSearchService] ❌ Bad URL from base: \(currentBase) for query: '\(query)'")
            #endif
            throw URLError(.badURL)
        }
        
        #if DEBUG
        debugLog("[LocationSearchService] 📡 [HTTP REQ] Base: \(currentBase) | URL: \(url.absoluteString)")
        #endif
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 8.0
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            let (data, response) = try await urlSession.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                #if DEBUG
                debugLog("[LocationSearchService] ❌ [HTTP RES] Invalid non-HTTP response for \(url.absoluteString)")
                #endif
                throw URLError(.badServerResponse)
            }
            
            #if DEBUG
            debugLog("[LocationSearchService] 📡 [HTTP RES] Status: \(httpResponse.statusCode) | URL: \(url.absoluteString)")
            #endif
            
            if httpResponse.statusCode == 200 {
                let searchEnvelope = try decoder.decode(LocationSearchResponse.self, from: data)
                #if DEBUG
                debugLog("[LocationSearchService] ✅ [HTTP SUCCESS] Decoded \(searchEnvelope.results.count) results (total: \(searchEnvelope.totalResults)), first: '\(searchEnvelope.results.first?.title ?? "none")'")
                #endif
                return searchEnvelope.results
            } else if httpResponse.statusCode == 422 {
                #if DEBUG
                debugLog("[LocationSearchService] ⚠️ [HTTP 422] Validation error for query '\(query)'")
                #endif
                return []
            } else {
                #if DEBUG
                let bodyString = String(data: data, encoding: .utf8) ?? "<binary>"
                debugLog("[LocationSearchService] ❌ [HTTP ERROR] Status: \(httpResponse.statusCode), body: \(bodyString)")
                #endif
                throw URLError(.init(rawValue: httpResponse.statusCode))
            }
        } catch {
            #if DEBUG
            debugLog("[LocationSearchService] 💥 [NET FAILED] Base: \(currentBase) | URL: \(url.absoluteString) | Error: \(error.localizedDescription)")
            #endif
            throw error
        }
    }
    
    // MARK: - Spatial Resolution API (POST /api/v1/location/resolve)
    
    public func resolveCoordinate(
        latitude: Double,
        longitude: Double,
        candidateVillageIds: [String]? = nil
    ) async throws -> LocationResolutionResponse {
        let currentBase = baseURL
        guard let url = URL(string: "\(currentBase)/location/resolve") else {
            #if DEBUG
            debugLog("[LocationSearchService] ❌ Bad URL from base: \(currentBase) for /location/resolve")
            #endif
            throw URLError(.badURL)
        }
        
        #if DEBUG
        debugLog("[LocationSearchService] 📡 [RESOLVE REQ] Base: \(currentBase) | URL: \(url.absoluteString) | Coord: (\(latitude), \(longitude))")
        #endif
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 15.0
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let resolveReq = LocationResolveRequest(
            latitude: latitude,
            longitude: longitude,
            candidateVillageIds: candidateVillageIds
        )
        request.httpBody = try encoder.encode(resolveReq)
        
        do {
            let (data, response) = try await urlSession.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                #if DEBUG
                debugLog("[LocationSearchService] ❌ [RESOLVE RES] Invalid non-HTTP response")
                #endif
                throw URLError(.badServerResponse)
            }
            
            #if DEBUG
            debugLog("[LocationSearchService] 📡 [RESOLVE RES] Status: \(httpResponse.statusCode)")
            #endif
            
            if httpResponse.statusCode == 200 {
                let decoded = try decoder.decode(LocationResolutionResponse.self, from: data)
                #if DEBUG
                debugLog("[LocationSearchService] ✅ [RESOLVE SUCCESS] Status: \(decoded.status.rawValue), Village: \(decoded.revenueVillage ?? "nil"), Tahasil: \(decoded.tahasil ?? "nil")")
                #endif
                return decoded
            } else {
                if let decoded = try? decoder.decode(LocationResolutionResponse.self, from: data) {
                    #if DEBUG
                    debugLog("[LocationSearchService] ⚠️ [RESOLVE NON-200] Status: \(decoded.status.rawValue), Reason: \(decoded.resolutionReason ?? "nil")")
                    #endif
                    return decoded
                }
                #if DEBUG
                let bodyString = String(data: data, encoding: .utf8) ?? "<binary>"
                debugLog("[LocationSearchService] ❌ [RESOLVE ERROR] Status: \(httpResponse.statusCode), body: \(bodyString)")
                #endif
                throw URLError(.init(rawValue: httpResponse.statusCode))
            }
        } catch {
            #if DEBUG
            debugLog("[LocationSearchService] 💥 [RESOLVE NET FAILED] Base: \(currentBase) | Error: \(error.localizedDescription)")
            #endif
            throw error
        }
    }
}
