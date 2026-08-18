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
    
    /// Loads any existing user session from secure Keychain and verifies Apple ID credential status
    public func loadSession() {
        guard let savedAppleUserId = KeychainHelper.shared.readString(key: keychainAppleUserIdKey), !savedAppleUserId.isEmpty else {
            self.currentUser = nil
            self.isAuthenticated = false
            return
        }
        
        // Load local user record matching the permanent Apple User ID
        let users = DatabaseManager.shared.loadUsers()
        if let existingUser = users.first(where: { $0.id == savedAppleUserId }) {
            self.currentUser = existingUser
            self.isAuthenticated = true
            if let userState = existingUser.selectedState {
                self.selectedState = userState
            }
        }
        
        // Verify with Apple that the credential is still valid and not revoked
        checkAppleCredentialState(for: savedAppleUserId)
    }
    
    /// Verifies the credential state with Apple's authentication servers
    public func checkAppleCredentialState(for userId: String) {
        let provider = ASAuthorizationAppleIDProvider()
        provider.getCredentialState(forUserID: userId) { [weak self] state, error in
            Task { @MainActor in
                guard let self = self else { return }
                switch state {
                case .authorized:
                    // Apple ID credential is valid
                    print("DEBUG: 🍏 Apple ID credential verified and active for user: \(userId)")
                case .revoked, .notFound:
                    // The user revoked authorization in iOS Settings or Apple ID was changed
                    print("DEBUG: ⚠️ Apple ID credential revoked or not found. Signing out.")
                    self.signOut()
                case .transferred:
                    print("DEBUG: 🔄 Apple ID credential transferred.")
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
        
        self.currentUser = user
        self.isAuthenticated = true
        
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
        guard let url = URL(string: "\(backendBaseURL)/api/v1/auth/apple") else { return }
        
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
        KeychainHelper.shared.delete(key: keychainAppleUserIdKey)
        KeychainHelper.shared.delete(key: keychainIdentityTokenKey)
        KeychainHelper.shared.delete(key: keychainAccessTokenKey)
        self.currentUser = nil
        self.isAuthenticated = false
    }
    
    public func refreshUser() {
        guard let user = currentUser else { return }
        let users = DatabaseManager.shared.loadUsers()
        if let freshUser = users.first(where: { $0.id == user.id }) {
            self.currentUser = freshUser
        }
    }
}
