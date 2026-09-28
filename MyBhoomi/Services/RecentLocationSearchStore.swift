//
//  RecentLocationSearchStore.swift
//  MyBhoomi
//
//  Lightweight, local-only store for up to 5 recently selected location searches.
//  Does not store parcel geometries, catalog data, or sensitive records.
//  Re-selecting an item always executes fresh spatial resolution.
//

import Foundation
import Combine

@MainActor
public final class RecentLocationSearchStore: ObservableObject {
    public static let shared = RecentLocationSearchStore()
    
    private let userDefaultsKey = "bhumitra_recent_location_searches_v1"
    private let maxRecents = 5
    
    @Published public private(set) var recents: [LocationSearchResult] = []
    
    private init() {
        loadRecents()
    }
    
    public func loadRecents() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else {
            self.recents = []
            return
        }
        do {
            let decoded = try JSONDecoder().decode([LocationSearchResult].self, from: data)
            self.recents = Array(decoded.prefix(maxRecents))
        } catch {
            self.recents = []
        }
    }
    
    public func addRecent(_ result: LocationSearchResult) {
        // Only store results with valid identity or coordinates
        guard !result.id.isEmpty else { return }
        
        var current = recents.filter { $0.id != result.id }
        current.insert(result, at: 0)
        
        let trimmed = Array(current.prefix(maxRecents))
        self.recents = trimmed
        saveRecents(trimmed)
    }
    
    public func removeRecent(id: String) {
        let updated = recents.filter { $0.id != id }
        self.recents = updated
        saveRecents(updated)
    }
    
    public func clearAll() {
        self.recents = []
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }
    
    private func saveRecents(_ list: [LocationSearchResult]) {
        do {
            let data = try JSONEncoder().encode(list)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        } catch {
            // Silently ignore persistence errors in constrained environments
        }
    }
}
