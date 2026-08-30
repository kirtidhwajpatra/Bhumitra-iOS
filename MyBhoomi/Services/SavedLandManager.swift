import SwiftUI
import Combine

// ============================================================
// MARK: - ON-DEVICE SAVED LAND MANAGER
// ============================================================

/// High-performance, offline-first on-device store for saved land records.
/// Provides zero-latency reading, reactive state updates, and liquid toast triggers.
@MainActor
public final class SavedLandManager: ObservableObject {
    public static let shared = SavedLandManager()
    
    // MARK: - Published State
    @Published public private(set) var savedRecords: [SavedLandRecord] = []
    
    // Toast Notification State
    @Published public var toastTitle: String? = nil
    @Published public var toastSubtitle: String? = nil
    @Published public var isToastVisible: Bool = false
    
    private var toastDismissTask: _Concurrency.Task<Void, Never>? = nil
    private let storageFileName = "bhumitra_saved_lands.json"
    
    private init() {
        loadFromDisk()
    }
    
    // MARK: - Public Queries
    
    public func isSaved(districtID: String, tahasilID: String, villageID: String, plotNumber: String) -> Bool {
        let key = "\(districtID)_\(tahasilID)_\(villageID)_\(plotNumber)"
        return savedRecords.contains { $0.id == key }
    }
    
    public func isSaved(result: OfficialSearchResult) -> Bool {
        isSaved(
            districtID: result.districtID,
            tahasilID: result.tahasilID,
            villageID: result.villageID,
            plotNumber: result.plotNumber
        )
    }
    
    // MARK: - Toggle & Save Actions
    
    @discardableResult
    public func toggleSave(result: OfficialSearchResult) -> Bool {
        let key = "\(result.districtID)_\(result.tahasilID)_\(result.villageID)_\(result.plotNumber)"
        if let index = savedRecords.firstIndex(where: { $0.id == key }) {
            let removed = savedRecords.remove(at: index)
            saveToDisk()
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            showToast(
                title: "Removed from Saved Lands",
                subtitle: "Plot \(removed.plotNumber) • \(removed.villageName)"
            )
            return false
        } else {
            let newRecord = SavedLandRecord(result: result)
            savedRecords.insert(newRecord, at: 0)
            saveToDisk()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            showToast(
                title: "Saved Plot \(newRecord.plotNumber) • \(newRecord.villageName)",
                subtitle: "Offline record available in Profile & Settings"
            )
            return true
        }
    }
    
    public func remove(recordID: String) {
        if let index = savedRecords.firstIndex(where: { $0.id == recordID }) {
            let removed = savedRecords.remove(at: index)
            saveToDisk()
            Theme.haptic(.medium)
            showToast(
                title: "Removed from Saved Lands",
                subtitle: "Plot \(removed.plotNumber) • \(removed.villageName)"
            )
        }
    }
    
    public func remove(at offsets: IndexSet) {
        savedRecords.remove(atOffsets: offsets)
        saveToDisk()
        Theme.haptic(.medium)
    }
    
    // MARK: - Aggregations & Metrics
    
    public var totalSavedCount: Int {
        savedRecords.count
    }
    
    public var totalAreaAcresSummary: String {
        let total = savedRecords.compactMap { $0.parsedAcres }.reduce(0, +)
        if total <= 0 {
            return "\(savedRecords.count) Plots"
        }
        return String(format: "%.2f Ac across %d plots", total, savedRecords.count)
    }
    
    // MARK: - Toast Banner Dispatch
    
    public func showToast(title: String, subtitle: String) {
        toastDismissTask?.cancel()
        
        withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
            self.toastTitle = title
            self.toastSubtitle = subtitle
            self.isToastVisible = true
        }
        
        toastDismissTask = _Concurrency.Task {
            try? await _Concurrency.Task.sleep(nanoseconds: 3_200_000_000) // 3.2s
            guard !_Concurrency.Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    self.isToastVisible = false
                }
            }
        }
    }
    
    public func dismissToast() {
        toastDismissTask?.cancel()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            self.isToastVisible = false
        }
    }
    
    // MARK: - Disk Persistence
    
    private var fileURL: URL? {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let dir = appSupport.appendingPathComponent("Bhumitra", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent(storageFileName)
    }
    
    private func saveToDisk() {
        guard let url = fileURL else { return }
        do {
            let data = try JSONEncoder().encode(savedRecords)
            try data.write(to: url, options: [.atomicWrite])
            // Secondary fallback in UserDefaults for absolute reliability
            UserDefaults.standard.set(data, forKey: "bhumitra_saved_lands_cache")
        } catch {
            #if DEBUG
            print("[SavedLandManager] Failed to persist records: \(error)")
            #endif
        }
    }
    
    private func loadFromDisk() {
        if let url = fileURL, let data = try? Data(contentsOf: url) {
            if let decoded = try? JSONDecoder().decode([SavedLandRecord].self, from: data) {
                self.savedRecords = decoded
                return
            }
        }
        
        // Secondary fallback load
        if let fallbackData = UserDefaults.standard.data(forKey: "bhumitra_saved_lands_cache"),
           let decoded = try? JSONDecoder().decode([SavedLandRecord].self, from: fallbackData) {
            self.savedRecords = decoded
        }
    }
}
