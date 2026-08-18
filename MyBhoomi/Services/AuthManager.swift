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
    private let userDefaultsStateKey = "Bhumitra_SelectedState"
    private let userDefaultsStateCodeKey = "Bhumitra_SelectedStateCode"
    
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
        
        // Save identity token if available
        if let identityTokenData = appleCredential.identityToken,
           let identityTokenString = String(data: identityTokenData, encoding: .utf8) {
            KeychainHelper.shared.save(key: keychainIdentityTokenKey, string: identityTokenString)
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
        
        // Check if user already exists in database
        var users = DatabaseManager.shared.loadUsers()
        var user: User
        
        let accountTokenKey = "apple_app_account_token_\(appleUserId)"
        let appAccountToken = KeychainHelper.shared.readString(key: accountTokenKey) ?? UUID().uuidString
        KeychainHelper.shared.save(key: accountTokenKey, string: appAccountToken)
        
        if let index = users.firstIndex(where: { $0.id == appleUserId }) {
            user = users[index]
            // Update name and email if newly provided on this sign-in
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
        
        self.currentUser = user
        self.isAuthenticated = true
        
        print("DEBUG: 👤 Loaded user: \(user.id) with appAccountToken UUID: \(user.appAccountToken)")
        return .success(user)
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
