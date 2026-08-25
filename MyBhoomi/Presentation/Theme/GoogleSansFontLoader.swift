import Foundation
import CoreText
import UIKit

/// Automatic dynamic registrar for Google Sans font family.
public enum GoogleSansFontLoader {
    private static var isRegistered = false
    
    public static func registerFonts() {
        guard !isRegistered else { return }
        isRegistered = true
        
        let fontNames = [
            "GoogleSans-Regular",
            "GoogleSans-Medium",
            "GoogleSans-SemiBold",
            "GoogleSans-Bold",
            "GoogleSans-Italic",
            "GoogleSans-MediumItalic",
            "GoogleSans-SemiBoldItalic",
            "GoogleSans-BoldItalic"
        ]
        
        DispatchQueue.global(qos: .userInitiated).async {
            for name in fontNames {
                if let url = Bundle.main.url(forResource: name, withExtension: "ttf") {
                    CTFontManagerRegisterFontURLs([url as CFURL] as CFArray, .process, true) { _, _ in true }
                } else if let resourceURL = Bundle.main.resourceURL?.appendingPathComponent("Fonts/\(name).ttf"),
                          FileManager.default.fileExists(atPath: resourceURL.path) {
                    CTFontManagerRegisterFontURLs([resourceURL as CFURL] as CFArray, .process, true) { _, _ in true }
                }
            }
        }
    }
}
