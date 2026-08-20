import Foundation
import Combine

/// Status states for official RoR PDF preparation and availability.
public enum OfficialPDFStatus: Equatable {
    case notStarted
    case preparing
    case ready(URL)
    case failed(String)
    
    public static func == (lhs: OfficialPDFStatus, rhs: OfficialPDFStatus) -> Bool {
        switch (lhs, rhs) {
        case (.notStarted, .notStarted):
            return true
        case (.preparing, .preparing):
            return true
        case (.ready(let u1), .ready(let u2)):
            return u1 == u2
        case (.failed(let m1), .failed(let m2)):
            return m1 == m2
        default:
            return false
        }
    }
}

/// Actor managing background prefetching, disk caching, and SingleFlight coalescing for official RoR PDFs.
public actor OfficialRoRPDFService {
    public static let shared = OfficialRoRPDFService()
    
    private var inFlightTasks: [String: Task<URL, Error>] = [:]
    
    private init() {}
    
    /// Computes canonical cache identity for a plot RoR document.
    public nonisolated func computeKey(
        district: String,
        tahasil: String,
        village: String,
        plot: String,
        khata: String? = nil,
        vId: String? = nil
    ) -> String {
        PDFDocumentManager.shared.computeDocumentIdentity(
            district: district,
            tahasil: tahasil,
            village: village,
            plot: plot,
            khata: khata,
            vId: vId
        )
    }
    
    /// Checks if the official PDF document is already cached locally on disk.
    public func getCachedURL(
        district: String,
        tahasil: String,
        village: String,
        plot: String,
        khata: String? = nil,
        vId: String? = nil
    ) async -> URL? {
        if let cached = await PDFDocumentManager.shared.getCachedDocument(
            district: district,
            tahasil: tahasil,
            village: village,
            plot: plot,
            khata: khata,
            vId: vId
        ) {
            return cached.url
        }
        return nil
    }
    
    /// Prefetches or downloads the official PDF with SingleFlight coalescing.
    @discardableResult
    public func fetchOrGetPDF(
        district: String,
        tahasil: String,
        village: String,
        plot: String,
        khataNumber: String? = nil,
        bId: String? = nil,
        vId: String? = nil
    ) async throws -> URL {
        let key = computeKey(district: district, tahasil: tahasil, village: village, plot: plot, khata: khataNumber, vId: vId)
        
        // 1. Instant cache return
        if let cached = await PDFDocumentManager.shared.getCachedDocument(
            district: district,
            tahasil: tahasil,
            village: village,
            plot: plot,
            khata: khataNumber,
            vId: vId
        ) {
            return cached.url
        }
        
        // 2. Attach to existing in-flight task if already prefetching
        if let existing = inFlightTasks[key] {
            return try await existing.value
        }
        
        // 3. Create new single-flight task
        let task = Task<URL, Error> {
            let (url, _, _) = try await RoRService.shared.downloadROR(
                district: district,
                tahasil: tahasil,
                village: village,
                plot: plot,
                khataNumber: khataNumber,
                bId: bId,
                vId: vId
            )
            return url
        }
        
        inFlightTasks[key] = task
        
        defer {
            inFlightTasks.removeValue(forKey: key)
        }
        
        return try await task.value
    }
}
