import Foundation
import CryptoKit

// MARK: - PDF Document Metadata

public struct PDFDocumentMetadata: Codable, Equatable {
    public let documentIdentity: String
    public let sha256: String
    public let fileSize: Int64
    public let retrievedAt: Date
    public let district: String
    public let tahasil: String
    public let village: String
    public let plot: String
    public let khata: String?
    
    public var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: retrievedAt)
    }
}

// MARK: - PDF Download State

public enum PDFDownloadState: Equatable {
    case idle
    case downloading
    case validating
    case ready(url: URL, isOfflineSaved: Bool, metadata: PDFDocumentMetadata)
    case failed(message: String)
    
    public static func == (lhs: PDFDownloadState, rhs: PDFDownloadState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.downloading, .downloading), (.validating, .validating):
            return true
        case (.ready(let u1, let off1, let m1), .ready(let u2, let off2, let m2)):
            return u1 == u2 && off1 == off2 && m1 == m2
        case (.failed(let m1), .failed(let m2)):
            return m1 == m2
        default:
            return false
        }
    }
}

// MARK: - Production-Grade PDF Document Manager

public actor PDFDocumentManager {
    public static let shared = PDFDocumentManager()
    
    private let fileManager = FileManager.default
    private var baseDirectory: URL {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let rorDir = docs.appendingPathComponent("RoR", isDirectory: true)
        if !fileManager.fileExists(atPath: rorDir.path) {
            try? fileManager.createDirectory(at: rorDir, withIntermediateDirectories: true)
        }
        return rorDir
    }
    
    private init() {}
    
    // MARK: - Canonical Document Identity
    
    public nonisolated func computeDocumentIdentity(
        district: String,
        tahasil: String,
        village: String,
        plot: String,
        khata: String? = nil,
        vId: String? = nil
    ) -> String {
        let d = district.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let t = tahasil.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let v = village.trimmingCharacters(in: .whitespacesAndNewlines)
        let p = plot.trimmingCharacters(in: .whitespacesAndNewlines)
        let k = khata?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let vid = vId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        
        let raw = "\(d):\(t):\(v):\(p):\(k):\(vid)"
        let digest = SHA256.hash(data: Data(raw.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
    
    // MARK: - Local Cache Lookup
    
    public func getCachedDocument(
        district: String,
        tahasil: String,
        village: String,
        plot: String,
        khata: String? = nil,
        vId: String? = nil
    ) -> (url: URL, metadata: PDFDocumentMetadata)? {
        let docID = computeDocumentIdentity(district: district, tahasil: tahasil, village: village, plot: plot, khata: khata, vId: vId)
        let pdfURL = baseDirectory.appendingPathComponent("\(docID).pdf")
        let metaURL = baseDirectory.appendingPathComponent("\(docID).json")
        
        guard fileManager.fileExists(atPath: pdfURL.path),
              fileManager.fileExists(atPath: metaURL.path),
              let metaData = try? Data(contentsOf: metaURL),
              let metadata = try? JSONDecoder().decode(PDFDocumentMetadata.self, from: metaData),
              let pdfData = try? Data(contentsOf: pdfURL) else {
            return nil
        }
        
        // Validate magic bytes (%PDF-)
        guard pdfData.count >= 10,
              pdfData.starts(with: [0x25, 0x50, 0x44, 0x46, 0x2D]) else {
            // Corrupted cache entry - purge safely
            try? fileManager.removeItem(at: pdfURL)
            try? fileManager.removeItem(at: metaURL)
            return nil
        }
        
        // Validate SHA-256 integrity
        let computedDigest = SHA256.hash(data: pdfData)
        let computedHex = computedDigest.map { String(format: "%02x", $0) }.joined()
        
        guard computedHex == metadata.sha256 else {
            // Checksum mismatch - purge corrupted cache entry
            try? fileManager.removeItem(at: pdfURL)
            try? fileManager.removeItem(at: metaURL)
            return nil
        }
        
        return (pdfURL, metadata)
    }
    
    // MARK: - Atomic Validation & Saving
    
    public func validateAndStore(
        tempURL: URL,
        district: String,
        tahasil: String,
        village: String,
        plot: String,
        khata: String? = nil,
        vId: String? = nil,
        expectedSHA256: String? = nil
    ) throws -> (url: URL, metadata: PDFDocumentMetadata) {
        guard let data = try? Data(contentsOf: tempURL) else {
            throw RoRError.pdfFailed("Unable to read downloaded document.")
        }
        
        // 1. Magic Bytes Validation (%PDF-)
        guard data.count >= 10,
              data.starts(with: [0x25, 0x50, 0x44, 0x46, 0x2D]) else {
            // Check if HTML error or JSON error returned with 200
            let prefixStr = String(data: data.prefix(100), encoding: .utf8)?.lowercased() ?? ""
            if prefixStr.contains("<html") || prefixStr.contains("<!doctype") {
                throw RoRError.pdfFailed("Upstream server returned a web page instead of a PDF.")
            } else if prefixStr.starts(with: "{") {
                throw RoRError.pdfFailed("Upstream server returned an error JSON payload.")
            } else {
                throw RoRError.pdfFailed("Downloaded file is not a valid PDF document.")
            }
        }
        
        // 2. Compute SHA-256
        let digest = SHA256.hash(data: data)
        let sha256Hex = digest.map { String(format: "%02x", $0) }.joined()
        
        if let expected = expectedSHA256, !expected.isEmpty && expected != sha256Hex {
            throw RoRError.pdfFailed("Document integrity check failed (SHA-256 mismatch).")
        }
        
        // 3. Prepare Canonical Final Paths
        let docID = computeDocumentIdentity(district: district, tahasil: tahasil, village: village, plot: plot, khata: khata, vId: vId)
        let finalPDFURL = baseDirectory.appendingPathComponent("\(docID).pdf")
        let finalMetaURL = baseDirectory.appendingPathComponent("\(docID).json")
        
        // 4. Atomic Replace / Move
        try? fileManager.removeItem(at: finalPDFURL)
        try fileManager.moveItem(at: tempURL, to: finalPDFURL)
        
        let metadata = PDFDocumentMetadata(
            documentIdentity: docID,
            sha256: sha256Hex,
            fileSize: Int64(data.count),
            retrievedAt: Date(),
            district: district,
            tahasil: tahasil,
            village: village,
            plot: plot,
            khata: khata
        )
        
        if let metaJSON = try? JSONEncoder().encode(metadata) {
            try? metaJSON.write(to: finalMetaURL, options: .atomic)
        }
        
        return (finalPDFURL, metadata)
    }
    
    // MARK: - Eviction & Cache Management
    
    public func clearAllCachedDocuments() {
        try? fileManager.removeItem(at: baseDirectory)
    }
}
