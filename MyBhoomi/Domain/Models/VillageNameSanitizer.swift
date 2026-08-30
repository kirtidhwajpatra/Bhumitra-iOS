import Foundation

// ============================================================
// MARK: - VILLAGE NAME SANITIZER
// ============================================================

/// Intelligently cleanses raw GIS, AutoCAD, and Bhulekh village names by stripping
/// CAD artifacts (.dwg, -DWG), trailing layer numbers, numeric sheet codes, hyphens, and underscores.
public enum VillageNameSanitizer {
    
    /// Sanitizes a raw village name string into a clean, human-readable name.
    /// Examples:
    /// - "KHANDAGIRI-21-04-01-DWG" -> "Khandagiri"
    /// - "PATIA_123_DWG" -> "Patia"
    /// - "BHUBANESWAR-01-23" -> "Bhubaneswar"
    /// - "01-KHURDA - 02" -> "Khurda"
    /// - "Puri - 02.DWG" -> "Puri"
    /// - "BALIANTA (04)" -> "Balianta"
    /// - "BARANG_SASAN_01.dwg" -> "Barang Sasan"
    public static func sanitize(_ rawName: String) -> String {
        var text = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return text }
        
        // 1. Strip file extensions (.dwg, .dxf, .shp, .geojson, etc.)
        let fileExtensions = [".dwg", ".dxf", ".shp", ".geojson", ".json", ".kml", ".kmz", ".dwf", ".tif", ".tiff"]
        for ext in fileExtensions {
            if let range = text.range(of: ext, options: .caseInsensitive) {
                text.removeSubrange(range)
            }
        }
        
        // 2. Strip bracketed or parenthetical DWG/CAD tags
        text = text.replacingOccurrences(of: "(?i)\\s*\\(\\s*dwg\\s*\\)", with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: "(?i)\\s*\\[\\s*dwg\\s*\\]", with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: "(?i)[-_\\s]+dwg\\b", with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: "(?i)\\bdwg[-_\\s]+", with: "", options: .regularExpression)
        
        // 3. Strip parenthetical numbers, sheet codes, or part identifiers like "(01)", "(123)", "(Sheet 1)", "(Part 2)"
        text = text.replacingOccurrences(of: "\\s*\\([0-9a-zA-Z\\s_.-]+\\)", with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: "\\s*\\[[0-9a-zA-Z\\s_.-]+\\]", with: "", options: .regularExpression)
        
        // 4. Repeatedly strip trailing numeric layers/sheet codes like "-21-04-01", "_01", " - 002", ".01"
        while let match = text.range(of: "[-_/.#\\s]+[0-9]+[a-zA-Z]?$", options: .regularExpression) {
            text.removeSubrange(match)
        }
        
        // 5. Repeatedly strip leading numeric prefixes like "01-", "123_", "04 - "
        while let match = text.range(of: "^[0-9]+[-_/.#\\s]+", options: .regularExpression) {
            text.removeSubrange(match)
        }
        
        // 6. Replace remaining underscores and dashes surrounded by spaces or words with clean spaces
        text = text.replacingOccurrences(of: "_", with: " ")
        text = text.replacingOccurrences(of: "\\s*-\\s*", with: " ", options: .regularExpression)
        
        // 7. Strip trailing/leading punctuation
        text = text.trimmingCharacters(in: CharacterSet(charactersIn: "-_./:#@* \t\n\r"))
        
        // 8. Collapse multiple whitespace sequences into a single space
        text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 9. Fallback if stripping emptied the string (e.g. if the original was purely "01")
        if text.isEmpty {
            return rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // 10. Format casing: If ALL CAPS or all lowercase, format to Title Case
        if text == text.uppercased() || text == text.lowercased() {
            text = text.capitalized
        }
        
        return text
    }
}
