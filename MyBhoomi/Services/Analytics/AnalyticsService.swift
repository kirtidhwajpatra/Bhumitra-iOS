import Foundation
import FirebaseCore
import FirebaseAnalytics
import FirebaseCrashlytics

public final class AnalyticsService {
    public static let shared = AnalyticsService()
    
    private let keychainAnalyticsUserIDKey = "bhumitra_analytics_user_id"
    private var isFirebaseInitialized: Bool = false
    
    private init() {
        configureFirebaseIfAvailable()
        setupAnalyticsIdentity()
    }
    
    // MARK: - Safe Firebase Initialization
    
    public func configureFirebaseIfAvailable() {
        guard FirebaseApp.app() == nil else {
            self.isFirebaseInitialized = true
            return
        }
        
        if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
           let _ = NSDictionary(contentsOfFile: path) {
            FirebaseApp.configure()
            self.isFirebaseInitialized = true
            #if DEBUG
            print("[AnalyticsService] 🚀 Firebase successfully initialized.")
            #endif
        } else {
            #if DEBUG
            print("[AnalyticsService] ⚠️ GoogleService-Info.plist not found in bundle. Running in safe passive mode.")
            #endif
        }
    }
    
    // MARK: - Pseudonymous Analytics User ID Lifecycle
    
    /// Retrieves or generates a persistent random pseudonymous user ID that survives
    /// app updates, guest sessions, Apple/Google logins, and logouts.
    public var analyticsUserID: String {
        if let existingID = KeychainHelper.shared.readString(key: keychainAnalyticsUserIDKey), !existingID.isEmpty {
            return existingID
        }
        
        let newID = "pp_" + UUID().uuidString.lowercased().replacingOccurrences(of: "-", with: "")
        KeychainHelper.shared.save(key: keychainAnalyticsUserIDKey, string: newID)
        return newID
    }
    
    private func setupAnalyticsIdentity() {
        let currentID = analyticsUserID
        if isFirebaseInitialized {
            Analytics.setUserID(currentID)
            Crashlytics.crashlytics().setUserID(currentID)
            
            // Set standard baseline technical keys
            let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.0.0"
            let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
            
            Crashlytics.crashlytics().setCustomValue(appVersion, forKey: "app_version")
            Crashlytics.crashlytics().setCustomValue(buildNumber, forKey: "build_number")
            Crashlytics.crashlytics().setCustomValue(APIConfiguration.shared.baseURL, forKey: "environment_base_url")
            
            setUserProperty(appVersion, forName: "app_version")
        }
    }
    
    /// Resets the analytics identity only during explicit user account deletion.
    public func resetAnalyticsIdentity() {
        KeychainHelper.shared.delete(key: keychainAnalyticsUserIDKey)
        if isFirebaseInitialized {
            Analytics.setUserID(nil)
            Crashlytics.crashlytics().setUserID("")
        }
        #if DEBUG
        print("[AnalyticsService] 🗑️ Purged analytics identity.")
        #endif
    }
    
    // MARK: - User Property Management
    
    public func setUserProperty(_ value: String?, forName name: String) {
        guard isFirebaseInitialized else { return }
        Analytics.setUserProperty(value, forName: name)
        #if DEBUG
        print("[AnalyticsService] 🏷️ User Property '\(name)': '\(value ?? "nil")'")
        #endif
    }
    
    public func setAccountType(_ type: AnalyticsAccountType) {
        setUserProperty(type.rawValue, forName: "account_type")
        if isFirebaseInitialized {
            Crashlytics.crashlytics().setCustomValue(type.rawValue, forKey: "account_type")
        }
    }
    
    public func setAuthProvider(_ provider: AnalyticsAuthProvider) {
        setUserProperty(provider.rawValue, forName: "auth_provider")
        if isFirebaseInitialized {
            Crashlytics.crashlytics().setCustomValue(provider.rawValue, forKey: "auth_provider")
        }
    }
    
    public func setPreferredLanguage(_ language: String) {
        setUserProperty(language, forName: "preferred_language")
    }
    
    // MARK: - Strongly Typed Event Logging
    
    public func log(_ event: AnalyticsEvent) {
        let name = event.name
        let params = event.parameters
        
        #if DEBUG
        print("[AnalyticsService] 📊 Event: '\(name)' | Parameters: \(params)")
        #endif
        
        guard isFirebaseInitialized else { return }
        
        // Log to Firebase Analytics
        Analytics.logEvent(name, parameters: params)
        
        // Attach subtle breadcrumb to Crashlytics for major user steps
        logBreadcrumb("Event: \(name)")
    }
    
    // MARK: - Crashlytics Technical Context & Non-Fatal Recording
    
    public func logBreadcrumb(_ message: String) {
        guard isFirebaseInitialized else { return }
        Crashlytics.crashlytics().log(message)
    }
    
    public func setCrashlyticsFlow(_ majorFlow: String) {
        guard isFirebaseInitialized else { return }
        Crashlytics.crashlytics().setCustomValue(majorFlow, forKey: "current_major_flow")
    }
    
    public func recordError(_ error: Error, context: [String: Any]? = nil) {
        #if DEBUG
        print("[AnalyticsService] 🚨 Recording Non-Fatal Error: \(error.localizedDescription) | Context: \(context ?? [:])")
        #endif
        
        guard isFirebaseInitialized else { return }
        
        if let context = context {
            for (key, val) in context {
                Crashlytics.crashlytics().setCustomValue("\(val)", forKey: key)
            }
        }
        
        Crashlytics.crashlytics().record(error: error)
    }
}
