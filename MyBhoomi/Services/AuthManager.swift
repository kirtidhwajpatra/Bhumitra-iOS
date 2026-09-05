import Foundation
import Combine
import AuthenticationServices

@MainActor
public final class AuthManager: ObservableObject {
    public static let shared = AuthManager()
    
    @Published public var currentUser: User? = nil
    @Published public var isAuthenticated: Bool = false
    @Published public var selectedState: String? = "Odisha"
    @Published public var selectedStateCode: String? = "OD"
    
    private let keychainAppleUserIdKey = "apple_user_id"
    private let keychainIdentityTokenKey = "apple_identity_token"
    private let keychainGoogleUserIdKey = "google_user_id"
    private let keychainGoogleIdTokenKey = "google_id_token"
    private let keychainAccessTokenKey = "bhumitra_access_token"
    private let userDefaultsStateKey = "Bhumitra_SelectedState"
    private let userDefaultsStateCodeKey = "Bhumitra_SelectedStateCode"
    
    private let backendBaseURL: String = {
        #if DEBUG
        return "http://localhost:8000"
        #else
        return "https://api.bhumitra.in"
        #endif
    }()
    
    public enum AuthProvider: String {
        case apple = "Apple"
        case google = "Google"
        case guest = "Guest"
    }
    
    /// Returns the currently active authentication provider
    public var currentAuthProvider: AuthProvider {
        guard isAuthenticated, let user = currentUser else {
            return .guest
        }
        if user.id.hasPrefix("google_") || (KeychainHelper.shared.readString(key: keychainGoogleUserIdKey) != nil && !KeychainHelper.shared.readString(key: keychainGoogleUserIdKey)!.isEmpty) {
            return .google
        }
        if (KeychainHelper.shared.readString(key: keychainAppleUserIdKey) != nil && !KeychainHelper.shared.readString(key: keychainAppleUserIdKey)!.isEmpty) || !user.id.isEmpty {
            return .apple
        }
        return .guest
    }
    
    /// Current authenticated Bhumitra session Bearer token from Keychain
    public var bearerToken: String? {
        KeychainHelper.shared.readString(key: keychainAccessTokenKey)
    }
    
    private init() {
        self.selectedState = UserDefaults.standard.string(forKey: userDefaultsStateKey) ?? "Odisha"
        self.selectedStateCode = UserDefaults.standard.string(forKey: userDefaultsStateCodeKey) ?? "OD"
        loadSession()
    }
    
    // MARK: - Session Management
    
    /// Loads any existing user session from secure Keychain and verifies credential status
    public func loadSession() {
        // 1. Check Google Session
        if let savedGoogleUserId = KeychainHelper.shared.readString(key: keychainGoogleUserIdKey), !savedGoogleUserId.isEmpty {
            let accountTokenKey = "apple_app_account_token_\(savedGoogleUserId)"
            let appAccountToken = KeychainHelper.shared.readString(key: accountTokenKey) ?? UUID().uuidString
            KeychainHelper.shared.save(key: accountTokenKey, string: appAccountToken)
            
            let users = DatabaseManager.shared.loadUsers()
            if let existingUser = users.first(where: { $0.id == savedGoogleUserId }) {
                self.currentUser = existingUser
                self.isAuthenticated = true
                if let userState = existingUser.selectedState {
                    self.selectedState = userState
                }
            } else {
                let restoredUser = User(
                    id: savedGoogleUserId,
                    appAccountToken: appAccountToken,
                    name: "Google User",
                    email: "",
                    mobile: nil,
                    selectedState: self.selectedState,
                    isPremium: false,
                    createdAt: ISO8601DateFormatter().string(from: Date())
                )
                DatabaseManager.shared.saveUser(restoredUser)
                self.currentUser = restoredUser
                self.isAuthenticated = true
            }
            UserDefaults.standard.set(true, forKey: "has_authenticated_session")
            UserDefaults.standard.set(savedGoogleUserId, forKey: "last_authenticated_user_id")
            SubscriptionManager.shared.handleUserSignIn(userId: savedGoogleUserId)
            AnalyticsService.shared.setAccountType(SubscriptionManager.shared.isPremium ? .premium : .authenticated)
            AnalyticsService.shared.setAuthProvider(.google)
            return
        }
        
        // 2. Check Apple Session
        if let savedAppleUserId = KeychainHelper.shared.readString(key: keychainAppleUserIdKey), !savedAppleUserId.isEmpty {
            let accountTokenKey = "apple_app_account_token_\(savedAppleUserId)"
            let appAccountToken = KeychainHelper.shared.readString(key: accountTokenKey) ?? UUID().uuidString
            KeychainHelper.shared.save(key: accountTokenKey, string: appAccountToken)
            
            // Load local user record matching the permanent Apple User ID
            let users = DatabaseManager.shared.loadUsers()
            if let existingUser = users.first(where: { $0.id == savedAppleUserId }) {
                self.currentUser = existingUser
                self.isAuthenticated = true
                if let userState = existingUser.selectedState {
                    self.selectedState = userState
                }
            } else {
                // Reconstruct user profile from persistent Keychain data (handles reinstall)
                let restoredUser = User(
                    id: savedAppleUserId,
                    appAccountToken: appAccountToken,
                    name: "Apple User",
                    email: "",
                    mobile: nil,
                    selectedState: self.selectedState,
                    isPremium: false,
                    createdAt: ISO8601DateFormatter().string(from: Date())
                )
                DatabaseManager.shared.saveUser(restoredUser)
                self.currentUser = restoredUser
                self.isAuthenticated = true
            }
            UserDefaults.standard.set(true, forKey: "has_authenticated_session")
            UserDefaults.standard.set(savedAppleUserId, forKey: "last_authenticated_user_id")
            
            // Notify SubscriptionManager to restore user credits
            SubscriptionManager.shared.handleUserSignIn(userId: savedAppleUserId)
            
            // Verify with Apple that credential has not been explicitly revoked in iOS Settings
            checkAppleCredentialState(for: savedAppleUserId)
            return
        }
        
        // 3. Fallback: Check persistent auth flag and database
        if UserDefaults.standard.bool(forKey: "has_authenticated_session") {
            let users = DatabaseManager.shared.loadUsers()
            let lastUserId = UserDefaults.standard.string(forKey: "last_authenticated_user_id")
            if let user = users.first(where: { $0.id == lastUserId }) ?? users.first {
                self.currentUser = user
                self.isAuthenticated = true
                SubscriptionManager.shared.handleUserSignIn(userId: user.id)
                return
            }
        }
        
        self.currentUser = nil
        self.isAuthenticated = false
    }
    
    /// Verifies the credential state with Apple's authentication servers
    public func checkAppleCredentialState(for userId: String) {
        let provider = ASAuthorizationAppleIDProvider()
        provider.getCredentialState(forUserID: userId) { [weak self] state, error in
            Task { @MainActor in
                guard let self = self else { return }
                switch state {
                case .authorized:
                    print("DEBUG: 🍏 Apple ID credential verified and active for user: \(userId)")
                case .revoked:
                    // Only sign out if explicitly revoked in iOS Settings
                    print("DEBUG: ⚠️ Apple ID credential revoked. Signing out.")
                    self.signOut()
                case .notFound, .transferred:
                    // Do NOT sign out on notFound during regular launch / offline / testing
                    print("DEBUG: ℹ️ Apple ID credential state: \(state.rawValue)")
                @unknown default:
                    break
                }
            }
        }
    }
    
    // MARK: - Sign in with Apple Handler
    
    /// Processes the ASAuthorization callback from the native Sign in with Apple flow
    public func handleAppleAuthorization(authorization: ASAuthorization) async -> Result<User, Error> {
        guard let appleCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            let error = NSError(domain: "AuthManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid Apple authorization credential."])
            return .failure(error)
        }
        
        let appleUserId = appleCredential.user
        guard !appleUserId.isEmpty else {
            let error = NSError(domain: "AuthManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "Apple User ID is missing."])
            return .failure(error)
        }
        
        // Save permanent Apple User ID in Keychain
        KeychainHelper.shared.save(key: keychainAppleUserIdKey, string: appleUserId)
        
        var identityTokenString: String? = nil
        if let identityTokenData = appleCredential.identityToken,
           let tokenStr = String(data: identityTokenData, encoding: .utf8) {
            identityTokenString = tokenStr
            KeychainHelper.shared.save(key: keychainIdentityTokenKey, string: tokenStr)
        }
        
        // Format Full Name (Apple only shares fullName on the FIRST sign-in)
        var name = "Apple User"
        if let fullName = appleCredential.fullName {
            let components = [fullName.givenName, fullName.familyName].compactMap { $0 }.filter { !$0.isEmpty }
            if !components.isEmpty {
                name = components.joined(separator: " ")
            }
        }
        
        let email = appleCredential.email ?? ""
        
        // Account token UUID
        let accountTokenKey = "apple_app_account_token_\(appleUserId)"
        let appAccountToken = KeychainHelper.shared.readString(key: accountTokenKey) ?? UUID().uuidString
        KeychainHelper.shared.save(key: accountTokenKey, string: appAccountToken)
        
        // Check if user already exists in database
        var users = DatabaseManager.shared.loadUsers()
        var user: User
        
        let isNewUser = !users.contains(where: { $0.id == appleUserId })
        if let index = users.firstIndex(where: { $0.id == appleUserId }) {
            user = users[index]
            if !name.isEmpty && name != "Apple User" && user.name == "Apple User" {
                user.name = name
            }
            if !email.isEmpty && user.email.isEmpty {
                user.email = email
            }
            if user.appAccountToken.isEmpty {
                user.appAccountToken = appAccountToken
            }
            users[index] = user
            DatabaseManager.shared.saveUsers(users)
        } else {
            // Create brand new user with Apple stable user ID and appAccountToken UUID
            let formatter = ISO8601DateFormatter()
            user = User(
                id: appleUserId,
                appAccountToken: appAccountToken,
                name: name,
                email: email,
                mobile: nil,
                selectedState: self.selectedState,
                isPremium: false,
                createdAt: formatter.string(from: Date())
            )
            DatabaseManager.shared.saveUser(user)
        }
        
        // Exchange Apple identityToken with Bhumitra Backend for JWT session token
        if let idToken = identityTokenString {
            await exchangeAppleIdentityTokenWithBackend(
                identityToken: idToken,
                appAccountToken: appAccountToken,
                fullName: name,
                email: email
            )
        }
        
        UserDefaults.standard.set(true, forKey: "has_authenticated_session")
        UserDefaults.standard.set(user.id, forKey: "last_authenticated_user_id")
        
        self.currentUser = user
        self.isAuthenticated = true
        
        // Restore/sync user search credits with SubscriptionManager
        SubscriptionManager.shared.handleUserSignIn(userId: user.id)
        
        // Product Analytics Logging
        AnalyticsService.shared.setAccountType(SubscriptionManager.shared.isPremium ? .premium : .authenticated)
        AnalyticsService.shared.setAuthProvider(.apple)
        AnalyticsService.shared.log(.loginCompleted(provider: .apple, isNewUser: isNewUser))
        
        print("DEBUG: 👤 Loaded user: \(user.id) with appAccountToken UUID: \(user.appAccountToken)")
        return .success(user)
    }
    
    // MARK: - Backend Token Exchange
    
    private func exchangeAppleIdentityTokenWithBackend(
        identityToken: String,
        appAccountToken: String,
        fullName: String,
        email: String
    ) async {
        guard let url = URL(string: "\(APIConfiguration.shared.baseURL)/auth/apple") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "identity_token": identityToken,
            "app_account_token": appAccountToken,
            "full_name": fullName,
            "email": email
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpRes = response as? HTTPURLResponse, (200...299).contains(httpRes.statusCode) {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let accessToken = json["access_token"] as? String {
                    KeychainHelper.shared.save(key: keychainAccessTokenKey, string: accessToken)
                    print("DEBUG: 🔐 Obtained & persisted Bhumitra JWT session token in Keychain.")
                }
            } else {
                print("DEBUG: ⚠️ Backend token exchange returned status: \((response as? HTTPURLResponse)?.statusCode ?? 0)")
            }
        } catch {
            print("DEBUG: ⚠️ Error exchanging token with backend: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Sign in with Google Handler
    
    public func handleGoogleProfile(_ profile: GoogleUserProfile) async -> Result<User, Error> {
        let googleUserId = profile.id
        guard !googleUserId.isEmpty else {
            return .failure(NSError(domain: "AuthManager", code: -10, userInfo: [NSLocalizedDescriptionKey: "Invalid Google User ID."]))
        }
        
        // Save Google User ID in Keychain
        KeychainHelper.shared.save(key: keychainGoogleUserIdKey, string: googleUserId)
        if !profile.idToken.isEmpty {
            KeychainHelper.shared.save(key: keychainGoogleIdTokenKey, string: profile.idToken)
        }
        
        let accountTokenKey = "apple_app_account_token_\(googleUserId)"
        let appAccountToken = KeychainHelper.shared.readString(key: accountTokenKey) ?? UUID().uuidString
        KeychainHelper.shared.save(key: accountTokenKey, string: appAccountToken)
        
        var users = DatabaseManager.shared.loadUsers()
        var user: User
        
        let isNewUser = !users.contains(where: { $0.id == googleUserId })
        if let index = users.firstIndex(where: { $0.id == googleUserId }) {
            user = users[index]
            if !profile.name.isEmpty { user.name = profile.name }
            if !profile.email.isEmpty { user.email = profile.email }
            user.appAccountToken = appAccountToken
            users[index] = user
            DatabaseManager.shared.saveUsers(users)
        } else {
            let formatter = ISO8601DateFormatter()
            user = User(
                id: googleUserId,
                appAccountToken: appAccountToken,
                name: profile.name.isEmpty ? "Google User" : profile.name,
                email: profile.email,
                mobile: nil,
                selectedState: self.selectedState,
                isPremium: false,
                createdAt: formatter.string(from: Date())
            )
            DatabaseManager.shared.saveUser(user)
        }
        
        // Exchange Google ID Token with backend
        if !profile.idToken.isEmpty {
            await exchangeGoogleIdTokenWithBackend(
                idToken: profile.idToken,
                appAccountToken: appAccountToken,
                fullName: profile.name,
                email: profile.email
            )
        }
        
        UserDefaults.standard.set(true, forKey: "has_authenticated_session")
        UserDefaults.standard.set(user.id, forKey: "last_authenticated_user_id")
        
        self.currentUser = user
        self.isAuthenticated = true
        
        SubscriptionManager.shared.handleUserSignIn(userId: user.id)
        
        // Product Analytics Logging
        AnalyticsService.shared.setAccountType(SubscriptionManager.shared.isPremium ? .premium : .authenticated)
        AnalyticsService.shared.setAuthProvider(.google)
        AnalyticsService.shared.log(.loginCompleted(provider: .google, isNewUser: isNewUser))
        
        print("DEBUG: 👤 Loaded Google user: \(user.id)")
        return .success(user)
    }
    
    private func exchangeGoogleIdTokenWithBackend(
        idToken: String,
        appAccountToken: String,
        fullName: String,
        email: String
    ) async {
        guard let url = URL(string: "\(APIConfiguration.shared.baseURL)/auth/google") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "id_token": idToken,
            "app_account_token": appAccountToken,
            "full_name": fullName,
            "email": email
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpRes = response as? HTTPURLResponse, (200...299).contains(httpRes.statusCode) {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let accessToken = json["access_token"] as? String {
                    KeychainHelper.shared.save(key: keychainAccessTokenKey, string: accessToken)
                    print("DEBUG: 🔐 Obtained & persisted Bhumitra Google JWT session token.")
                }
            }
        } catch {
            print("DEBUG: ⚠️ Google token exchange error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Optional Phone Number Linking
    
    /// Attaches or updates an optional phone number for the user profile
    public func updatePhoneNumber(_ phone: String) {
        guard var user = currentUser else { return }
        user.mobile = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        DatabaseManager.shared.saveUser(user)
        self.currentUser = user
    }
    
    // MARK: - State Selection
    
    public func selectState(name: String, code: String) {
        self.selectedState = name
        self.selectedStateCode = code
        UserDefaults.standard.set(name, forKey: userDefaultsStateKey)
        UserDefaults.standard.set(code, forKey: userDefaultsStateCodeKey)
        
        if var user = currentUser {
            user.selectedState = name
            DatabaseManager.shared.saveUser(user)
            self.currentUser = user
        }
        
        NotificationCenter.default.post(name: NSNotification.Name("BhumitraStateChanged"), object: nil)
    }
    
    // MARK: - Sign Out
    
    public func signOut() {
        let previousProvider: AnalyticsAuthProvider = {
            if KeychainHelper.shared.readString(key: keychainGoogleUserIdKey) != nil {
                return .google
            } else if KeychainHelper.shared.readString(key: keychainAppleUserIdKey) != nil {
                return .apple
            } else {
                return .guest
            }
        }()
        
        KeychainHelper.shared.delete(key: keychainAppleUserIdKey)
        KeychainHelper.shared.delete(key: keychainIdentityTokenKey)
        KeychainHelper.shared.delete(key: keychainGoogleUserIdKey)
        KeychainHelper.shared.delete(key: keychainGoogleIdTokenKey)
        KeychainHelper.shared.delete(key: keychainAccessTokenKey)
        UserDefaults.standard.set(false, forKey: "has_authenticated_session")
        UserDefaults.standard.removeObject(forKey: "last_authenticated_user_id")
        self.currentUser = nil
        self.isAuthenticated = false
        
        SubscriptionManager.shared.handleUserSignOut()
        
        AnalyticsService.shared.setAccountType(.guest)
        AnalyticsService.shared.setAuthProvider(.none)
        AnalyticsService.shared.log(.logoutCompleted(previousProvider: previousProvider))
    }
    
    // MARK: - Delete Account (App Store Guideline 5.1.1(v) Compliance)
    
    public func deleteAccount() {
        if let user = currentUser {
            DatabaseManager.shared.deleteUser(user.id)
            let accountTokenKey = "apple_app_account_token_\(user.id)"
            KeychainHelper.shared.delete(key: accountTokenKey)
            KeychainHelper.shared.delete(key: "user_plot_credits_\(user.id)")
        }
        KeychainHelper.shared.delete(key: keychainAppleUserIdKey)
        KeychainHelper.shared.delete(key: keychainIdentityTokenKey)
        KeychainHelper.shared.delete(key: keychainGoogleUserIdKey)
        KeychainHelper.shared.delete(key: keychainGoogleIdTokenKey)
        KeychainHelper.shared.delete(key: keychainAccessTokenKey)
        UserDefaults.standard.set(false, forKey: "has_authenticated_session")
        UserDefaults.standard.removeObject(forKey: "last_authenticated_user_id")
        self.currentUser = nil
        self.isAuthenticated = false
        
        SubscriptionManager.shared.handleUserSignOut()
        
        AnalyticsService.shared.resetAnalyticsIdentity()
        AnalyticsService.shared.setAccountType(.guest)
        AnalyticsService.shared.setAuthProvider(.none)
        
        NotificationCenter.default.post(name: NSNotification.Name("BhumitraAccountDeleted"), object: nil)
    }
    
    public func refreshUser() {
        guard let user = currentUser else { return }
        let users = DatabaseManager.shared.loadUsers()
        if let freshUser = users.first(where: { $0.id == user.id }) {
            self.currentUser = freshUser
        }
    }
}
