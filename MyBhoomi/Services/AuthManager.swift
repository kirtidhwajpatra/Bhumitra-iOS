import Foundation
import Combine
import AuthenticationServices
import UIKit

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
    private let keychainDeviceIdKey = "bhumitra_device_id"
    private let keychainDeviceTokenKey = "bhumitra_device_token"
    private let userDefaultsStateKey = "Bhumitra_SelectedState"
    private let userDefaultsStateCodeKey = "Bhumitra_SelectedStateCode"
    
    public var deviceId: String {
        if let existing = KeychainHelper.shared.readString(key: keychainDeviceIdKey), !existing.isEmpty {
            return existing
        }
        let newId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        KeychainHelper.shared.save(key: keychainDeviceIdKey, string: newId)
        return newId
    }
    
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
    
    /// Current authenticated Bhumitra session Bearer token from Keychain (user or device fallback)
    public var bearerToken: String? {
        if let userToken = KeychainHelper.shared.readString(key: keychainAccessTokenKey), !userToken.isEmpty {
            return userToken
        }
        return KeychainHelper.shared.readString(key: keychainDeviceTokenKey)
    }
    
    private init() {
        self.selectedState = UserDefaults.standard.string(forKey: userDefaultsStateKey) ?? "Odisha"
        self.selectedStateCode = UserDefaults.standard.string(forKey: userDefaultsStateCodeKey) ?? "OD"
        loadSession()
        Task {
            await ensureDeviceSession()
            await refreshUserSessionIfNeeded()
        }
        NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification,
                                               object: nil, queue: .main) { _ in
            _Concurrency.Task { @MainActor in await AuthManager.shared.refreshUserSessionIfNeeded() }
        }
    }
    
    public func ensureDeviceSession(force: Bool = false) async {
        if !force, let token = bearerToken, !token.isEmpty { return }
        
        if force {
            // Only the anonymous device token is replaced. A signed-in user's
            // session token is never discarded here (see handleUnauthorizedSession).
            KeychainHelper.shared.delete(key: keychainDeviceTokenKey)
        }
        // A signed-in user already has a session; nothing to register.
        if !force, let userToken = KeychainHelper.shared.readString(key: keychainAccessTokenKey), !userToken.isEmpty { return }
        
        let currentDeviceId = self.deviceId
        guard let url = URL(string: "\(APIConfiguration.shared.baseURL)/auth/device") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10
        
        let accountTokenKey = "apple_app_account_token_device"
        let appAccountToken = KeychainHelper.shared.readString(key: accountTokenKey) ?? User.deterministicUUID(for: "dev_\(currentDeviceId)").uuidString.lowercased()
        KeychainHelper.shared.save(key: accountTokenKey, string: appAccountToken)
        
        let body: [String: Any] = [
            "device_id": currentDeviceId,
            "app_account_token": appAccountToken
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpRes = response as? HTTPURLResponse, (200...299).contains(httpRes.statusCode) {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let accessToken = json["access_token"] as? String {
                    KeychainHelper.shared.save(key: keychainDeviceTokenKey, string: accessToken)
                    debugLog("DEBUG: 📱 Registered guest device session token with backend: dev_\(currentDeviceId.prefix(8))")
                }
            } else {
                debugLog("DEBUG: ⚠️ Failed to register device session: HTTP \((response as? HTTPURLResponse)?.statusCode ?? -1)")
            }
        } catch {
            debugLog("DEBUG: ⚠️ Could not register device session: \(error.localizedDescription)")
        }
    }
    
    /// Handles a 401 from the backend.
    /// - Guest: registers a fresh device session. Returns true (safe to retry).
    /// - Signed-in user: the account session expired or was revoked. The user
    ///   is signed out and sent back to the sign-in screen instead of silently
    ///   continuing as the anonymous device (which would put purchases and
    ///   searches on the wrong account). Returns false (do not retry).
    @discardableResult
    public func handleUnauthorizedSession() async -> Bool {
        let hadUserSession = (KeychainHelper.shared.readString(key: keychainAccessTokenKey)?.isEmpty == false)
        if hadUserSession && isAuthenticated {
            debugLog("DEBUG: 🔒 401 for signed-in user: session expired, signing out.")
            expireUserSession()
            return false
        }
        debugLog("DEBUG: 🔄 401 for guest: re-registering device session.")
        KeychainHelper.shared.delete(key: keychainAccessTokenKey)
        await ensureDeviceSession(force: true)
        return true
    }

    /// Set when the account session expired; the sign-in screen explains why.
    @Published public var sessionExpiredNotice: Bool = false

    private func expireUserSession() {
        signOut()
        // Show the launch sign-in screen again (not the guest map).
        UserDefaults.standard.set(false, forKey: OnboardingState.guestChosenKey)
        sessionExpiredNotice = true
        _Concurrency.Task { await self.ensureDeviceSession(force: true) }
    }

    /// Sliding session: exchanges a still-valid account token for a fresh one
    /// when it is more than 3 days old, so active users are never logged out by
    /// the 30-day token lifetime.
    public func refreshUserSessionIfNeeded() async {
        guard isAuthenticated,
              let token = KeychainHelper.shared.readString(key: keychainAccessTokenKey), !token.isEmpty else { return }
        if let issuedAt = Self.jwtIssuedAt(token), Date().timeIntervalSince(issuedAt) < 3 * 86400 { return }
        guard let url = URL(string: "\(APIConfiguration.shared.baseURL)/auth/refresh") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse else { return }  // offline: try next launch
        if (200...299).contains(http.statusCode),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let fresh = json["access_token"] as? String, !fresh.isEmpty {
            KeychainHelper.shared.save(key: keychainAccessTokenKey, string: fresh)
        } else if http.statusCode == 401 {
            await handleUnauthorizedSession()
        }
    }

    static func jwtIssuedAt(_ token: String) -> Date? {
        let parts = token.split(separator: ".")
        guard parts.count == 3 else { return nil }
        var b64 = String(parts[1]).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while b64.count % 4 != 0 { b64 += "=" }
        guard let data = Data(base64Encoded: b64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let iat = json["iat"] as? Double else { return nil }
        return Date(timeIntervalSince1970: iat)
    }
    
    // MARK: - Session Management
    
    #if DEBUG
    public func signInTestUser() {
        let testUser = User(
            id: "debug_tester_id",
            appAccountToken: UUID().uuidString,
            name: "Tester",
            email: "tester@bhumitra.com",
            mobile: nil,
            selectedState: "Odisha",
            isPremium: true,
            createdAt: ISO8601DateFormatter().string(from: Date())
        )
        DatabaseManager.shared.saveUser(testUser)
        self.currentUser = testUser
        self.isAuthenticated = true
        UserDefaults.standard.set(true, forKey: "has_authenticated_session")
        UserDefaults.standard.set(testUser.id, forKey: "last_authenticated_user_id")
        UserDefaults.standard.set(true, forKey: "mybhoomi_has_completed_feedback_flow")
        SubscriptionManager.shared.handleUserSignIn(userId: testUser.id)
    }
    #endif
    
    /// Loads any existing user session from secure Keychain and verifies credential status
    public func loadSession() {
        #if DEBUG
        if CommandLine.arguments.contains("-debugAuth") {
            signInTestUser()
            return
        }
        #endif
        // 1. Check Google Session
        if let savedGoogleUserId = KeychainHelper.shared.readString(key: keychainGoogleUserIdKey), !savedGoogleUserId.isEmpty {
            let accountTokenKey = "apple_app_account_token_\(savedGoogleUserId)"
            let appAccountToken = KeychainHelper.shared.readString(key: accountTokenKey) ?? User.deterministicUUID(for: savedGoogleUserId).uuidString.lowercased()
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
            let appAccountToken = KeychainHelper.shared.readString(key: accountTokenKey) ?? User.deterministicUUID(for: savedAppleUserId).uuidString.lowercased()
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
                    debugLog("DEBUG: 🍏 Apple ID credential verified and active for user: \(userId)")
                case .revoked:
                    // Only sign out if explicitly revoked in iOS Settings
                    debugLog("DEBUG: ⚠️ Apple ID credential revoked. Signing out.")
                    self.signOut()
                case .notFound, .transferred:
                    // Do NOT sign out on notFound during regular launch / offline / testing
                    debugLog("DEBUG: ℹ️ Apple ID credential state: \(state.rawValue)")
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
        let appAccountToken = KeychainHelper.shared.readString(key: accountTokenKey) ?? User.deterministicUUID(for: appleUserId).uuidString.lowercased()
        KeychainHelper.shared.save(key: accountTokenKey, string: appAccountToken)
        
        // Exchange Apple identityToken with Bhumitra Backend for JWT session token
        var canonicalUserId = appleUserId
        var finalName = name
        var finalEmail = email
        
        if let idToken = identityTokenString {
            let backendRes = await exchangeAppleIdentityTokenWithBackend(
                identityToken: idToken,
                appAccountToken: appAccountToken,
                fullName: name,
                email: email
            )
            if let canonId = backendRes.canonicalUserId, !canonId.isEmpty {
                canonicalUserId = canonId
            }
            if let sName = backendRes.userName, !sName.isEmpty && sName != "Apple User" {
                finalName = sName
            }
            if let sEmail = backendRes.userEmail, !sEmail.isEmpty {
                finalEmail = sEmail
            }
        }
        
        // Check if user already exists in database
        var users = DatabaseManager.shared.loadUsers()
        var user: User
        
        let isNewUser = !users.contains(where: { $0.id == canonicalUserId })
        if let index = users.firstIndex(where: { $0.id == canonicalUserId }) {
            user = users[index]
            if !finalName.isEmpty && finalName != "Apple User" && (user.name == "Apple User" || user.name.isEmpty) {
                user.name = finalName
            }
            if !finalEmail.isEmpty && user.email.isEmpty {
                user.email = finalEmail
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
                id: canonicalUserId,
                appAccountToken: appAccountToken,
                name: finalName,
                email: finalEmail,
                mobile: nil,
                selectedState: self.selectedState,
                isPremium: false,
                createdAt: formatter.string(from: Date())
            )
            DatabaseManager.shared.saveUser(user)
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
        
        debugLog("DEBUG: 👤 Loaded user: \(user.id) with appAccountToken UUID: \(user.appAccountToken)")
        return .success(user)
    }
    
    // MARK: - Backend Token Exchange
    
    private func exchangeAppleIdentityTokenWithBackend(
        identityToken: String,
        appAccountToken: String,
        fullName: String,
        email: String
    ) async -> (accessToken: String?, canonicalUserId: String?, userName: String?, userEmail: String?) {
        guard let url = URL(string: "\(APIConfiguration.shared.baseURL)/auth/apple") else { return (nil, nil, nil, nil) }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "identity_token": identityToken,
            "app_account_token": appAccountToken,
            "full_name": fullName,
            "email": email,
            "device_id": self.deviceId
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpRes = response as? HTTPURLResponse, (200...299).contains(httpRes.statusCode) {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let accessToken = json["access_token"] as? String {
                    KeychainHelper.shared.save(key: keychainAccessTokenKey, string: accessToken)
                    debugLog("DEBUG: 🔐 Obtained & persisted Bhumitra JWT session token in Keychain.")
                    
                    var canonicalId: String? = nil
                    var serverName: String? = nil
                    var serverEmail: String? = nil
                    if let userObj = json["user"] as? [String: Any] {
                        canonicalId = userObj["id"] as? String
                        serverName = userObj["name"] as? String
                        serverEmail = userObj["email"] as? String
                    }
                    return (accessToken, canonicalId, serverName, serverEmail)
                }
            } else {
                debugLog("DEBUG: ⚠️ Backend token exchange returned status: \((response as? HTTPURLResponse)?.statusCode ?? 0)")
            }
        } catch {
            debugLog("DEBUG: ⚠️ Error exchanging token with backend: \(error.localizedDescription)")
        }
        return (nil, nil, nil, nil)
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
        let appAccountToken = KeychainHelper.shared.readString(key: accountTokenKey) ?? User.deterministicUUID(for: googleUserId).uuidString.lowercased()
        KeychainHelper.shared.save(key: accountTokenKey, string: appAccountToken)
        
        // Exchange Google ID Token with backend
        var canonicalUserId = googleUserId
        var finalName = profile.name.isEmpty ? "Google User" : profile.name
        var finalEmail = profile.email
        
        if !profile.idToken.isEmpty {
            let backendRes = await exchangeGoogleIdTokenWithBackend(
                idToken: profile.idToken,
                appAccountToken: appAccountToken,
                fullName: profile.name,
                email: profile.email
            )
            if let canonId = backendRes.canonicalUserId, !canonId.isEmpty {
                canonicalUserId = canonId
            }
            if let sName = backendRes.userName, !sName.isEmpty && sName != "Google User" {
                finalName = sName
            }
            if let sEmail = backendRes.userEmail, !sEmail.isEmpty {
                finalEmail = sEmail
            }
        }
        
        var users = DatabaseManager.shared.loadUsers()
        var user: User
        
        let isNewUser = !users.contains(where: { $0.id == canonicalUserId })
        if let index = users.firstIndex(where: { $0.id == canonicalUserId }) {
            user = users[index]
            if !finalName.isEmpty { user.name = finalName }
            if !finalEmail.isEmpty { user.email = finalEmail }
            user.appAccountToken = appAccountToken
            users[index] = user
            DatabaseManager.shared.saveUsers(users)
        } else {
            let formatter = ISO8601DateFormatter()
            user = User(
                id: canonicalUserId,
                appAccountToken: appAccountToken,
                name: finalName,
                email: finalEmail,
                mobile: nil,
                selectedState: self.selectedState,
                isPremium: false,
                createdAt: formatter.string(from: Date())
            )
            DatabaseManager.shared.saveUser(user)
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
        
        debugLog("DEBUG: 👤 Loaded Google user: \(user.id)")
        return .success(user)
    }
    
    private func exchangeGoogleIdTokenWithBackend(
        idToken: String,
        appAccountToken: String,
        fullName: String,
        email: String
    ) async -> (accessToken: String?, canonicalUserId: String?, userName: String?, userEmail: String?) {
        guard let url = URL(string: "\(APIConfiguration.shared.baseURL)/auth/google") else { return (nil, nil, nil, nil) }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "id_token": idToken,
            "app_account_token": appAccountToken,
            "full_name": fullName,
            "email": email,
            "device_id": self.deviceId
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpRes = response as? HTTPURLResponse, (200...299).contains(httpRes.statusCode) {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let accessToken = json["access_token"] as? String {
                    KeychainHelper.shared.save(key: keychainAccessTokenKey, string: accessToken)
                    debugLog("DEBUG: 🔐 Obtained & persisted Bhumitra Google JWT session token.")
                    
                    var canonicalId: String? = nil
                    var serverName: String? = nil
                    var serverEmail: String? = nil
                    if let userObj = json["user"] as? [String: Any] {
                        canonicalId = userObj["id"] as? String
                        serverName = userObj["name"] as? String
                        serverEmail = userObj["email"] as? String
                    }
                    return (accessToken, canonicalId, serverName, serverEmail)
                }
            }
        } catch {
            debugLog("DEBUG: ⚠️ Google token exchange error: \(error.localizedDescription)")
        }
        return (nil, nil, nil, nil)
    }
    
    // MARK: - Explicit Account Linking
    
    /// Explicitly links an Apple identity to the currently authenticated account
    public func linkAppleAccount(identityToken: String, appAccountToken: String) async -> Result<[String], Error> {
        guard let token = bearerToken else {
            return .failure(NSError(domain: "AuthManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "Must be signed in to link an account."]))
        }
        guard let url = URL(string: "\(APIConfiguration.shared.baseURL)/auth/link/apple") else {
            return .failure(NSError(domain: "AuthManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL."]))
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let body: [String: Any] = [
            "identity_token": identityToken,
            "app_account_token": appAccountToken
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpRes = response as? HTTPURLResponse else {
                return .failure(NSError(domain: "AuthManager", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid server response."]))
            }
            if httpRes.statusCode == 200 {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let providers = json["linked_providers"] as? [String] {
                    return .success(providers)
                }
                return .success([])
            } else if httpRes.statusCode == 409 {
                return .failure(NSError(domain: "AuthManager", code: 409, userInfo: [NSLocalizedDescriptionKey: "This Apple account is already linked to another Bhumitra account."]))
            } else {
                return .failure(NSError(domain: "AuthManager", code: httpRes.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to link Apple account (HTTP \(httpRes.statusCode))."]))
            }
        } catch {
            return .failure(error)
        }
    }
    
    /// Explicitly links a Google identity to the currently authenticated account
    public func linkGoogleAccount(idToken: String, appAccountToken: String) async -> Result<[String], Error> {
        guard let token = bearerToken else {
            return .failure(NSError(domain: "AuthManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "Must be signed in to link an account."]))
        }
        guard let url = URL(string: "\(APIConfiguration.shared.baseURL)/auth/link/google") else {
            return .failure(NSError(domain: "AuthManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL."]))
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let body: [String: Any] = [
            "id_token": idToken,
            "app_account_token": appAccountToken
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpRes = response as? HTTPURLResponse else {
                return .failure(NSError(domain: "AuthManager", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid server response."]))
            }
            if httpRes.statusCode == 200 {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let providers = json["linked_providers"] as? [String] {
                    return .success(providers)
                }
                return .success([])
            } else if httpRes.statusCode == 409 {
                return .failure(NSError(domain: "AuthManager", code: 409, userInfo: [NSLocalizedDescriptionKey: "This Google account is already linked to another Bhumitra account."]))
            } else {
                return .failure(NSError(domain: "AuthManager", code: httpRes.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to link Google account (HTTP \(httpRes.statusCode))."]))
            }
        } catch {
            return .failure(error)
        }
    }
    
    /// Fetches all linked auth providers for the currently authenticated account
    public func fetchLinkedProviders() async -> Result<[String], Error> {
        guard let token = bearerToken else {
            return .failure(NSError(domain: "AuthManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "Must be signed in."]))
        }
        guard let url = URL(string: "\(APIConfiguration.shared.baseURL)/auth/identities") else {
            return .failure(NSError(domain: "AuthManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL."]))
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200 {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let providers = json["linked_providers"] as? [String] {
                    return .success(providers)
                }
            }
            return .failure(NSError(domain: "AuthManager", code: (response as? HTTPURLResponse)?.statusCode ?? 500, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch linked identities."]))
        } catch {
            return .failure(error)
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
    
    public func deleteAccount() async throws {
        // Never report success after only wiping this device: without a session
        // token the server-side account would survive.
        let storedToken = KeychainHelper.shared.readString(key: keychainAccessTokenKey)
        if isAuthenticated && (storedToken ?? "").isEmpty {
            throw NSError(domain: "BhumitraAuth", code: 401, userInfo: [
                NSLocalizedDescriptionKey: "Your session has ended. Sign out, sign in again, then delete your account."
            ])
        }
        // 1. If we have an active backend session token, request backend deletion first
        if let token = storedToken, !token.isEmpty {
            guard let url = URL(string: "\(APIConfiguration.shared.baseURL)/auth/me") else {
                throw URLError(.badURL)
            }
            // Sign in with Apple accounts: get a fresh authorization code so the
            // server can revoke the Apple tokens (Guideline 5.1.1(v)). If the user
            // cancels the Apple sheet, deletion is cancelled too.
            var appleCode: String? = nil
            if currentAuthProvider == .apple {
                appleCode = try await AppleReauthorizer().authorizationCode()
            }
            var request = URLRequest(url: url)
            request.httpMethod = "DELETE"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            if let appleCode {
                request.httpBody = try? JSONSerialization.data(withJSONObject: ["apple_authorization_code": appleCode])
            }
            request.timeoutInterval = 20.0
            
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                // If 200 OK or 404 Not Found (already deleted), proceed with local wipe.
                // Otherwise throw an error so the user is alerted and local state isn't orphaned.
                guard httpResponse.statusCode == 200 || httpResponse.statusCode == 404 else {
                    let errorMessage = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["detail"] as? String 
                        ?? "Server failed to delete account (HTTP \(httpResponse.statusCode))"
                    throw NSError(domain: "BhumitraAuth", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
                }
            }
        }
        
        // 2. Clear local storage and state
        clearLocalAccountData()
    }
    
    public func clearLocalAccountData() {
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

// MARK: - Apple re-authorization (account deletion)

/// Asks Sign in with Apple for a fresh authorization code. Used only before
/// account deletion so the backend can revoke the user's Apple tokens.
@MainActor
final class AppleReauthorizer: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private var continuation: CheckedContinuation<String?, Error>?
    private var strongSelf: AppleReauthorizer?

    /// Returns the code, nil if Apple gave none, or throws if the user cancels.
    func authorizationCode() async throws -> String? {
        try await withCheckedThrowingContinuation { cont in
            continuation = cont
            strongSelf = self
            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = []
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    private func finish(_ result: Result<String?, Error>) {
        continuation?.resume(with: result)
        continuation = nil
        strongSelf = nil
    }

    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene
            return scene?.windows.first(where: { $0.isKeyWindow }) ?? scene?.windows.first ?? UIWindow()
        }
    }

    nonisolated func authorizationController(controller: ASAuthorizationController,
                                             didCompleteWithAuthorization authorization: ASAuthorization) {
        let code = (authorization.credential as? ASAuthorizationAppleIDCredential)?
            .authorizationCode.flatMap { String(data: $0, encoding: .utf8) }
        MainActor.assumeIsolated { finish(.success(code)) }
    }

    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        let cancelled = (error as NSError).code == ASAuthorizationError.canceled.rawValue
        let wrapped: Error = cancelled
            ? NSError(domain: "BhumitraAuth", code: -999, userInfo: [NSLocalizedDescriptionKey: "Account deletion was cancelled."])
            : error
        MainActor.assumeIsolated { finish(.failure(wrapped)) }
    }
}
