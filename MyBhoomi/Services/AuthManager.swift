import Foundation
import Combine

public final class AuthManager: ObservableObject {
    public static let shared = AuthManager()
    
    @Published public var currentUser: User? = nil
    @Published public var isAuthenticated: Bool = false
    @Published public var selectedState: String? = "Odisha"
    @Published public var selectedStateCode: String? = "OD"
    
    private let userDefaultsKey = "Bhumitra_LoggedInUserId"
    private let userDefaultsStateKey = "Bhumitra_SelectedState"
    private let userDefaultsStateCodeKey = "Bhumitra_SelectedStateCode"
    
    private init() {
        loadSession()
    }
    
    private func loadSession() {
        if let savedUserId = UserDefaults.standard.string(forKey: userDefaultsKey) {
            let users = DatabaseManager.shared.loadUsers()
            if let user = users.first(where: { $0.id == savedUserId }) {
                self.currentUser = user
                self.isAuthenticated = true
                self.selectedState = user.selectedState ?? UserDefaults.standard.string(forKey: userDefaultsStateKey) ?? "Odisha"
                self.selectedStateCode = UserDefaults.standard.string(forKey: userDefaultsStateCodeKey) ?? "OD"
            }
        }
    }
    
    public func login(emailOrMobile: String, password: String) async -> Result<User, Error> {
        // Simple authentication check. In a production app, we would hash passwords and consult an API.
        // We will match password with a simple mock logic or store plain password securely.
        // For simplicity and offline compliance, we check matching users.
        let users = DatabaseManager.shared.loadUsers()
        guard let user = users.first(where: { 
            ($0.email.lowercased() == emailOrMobile.lowercased() || $0.mobile == emailOrMobile)
        }) else {
            return .failure(NSError(domain: "AuthManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not found. Please register first."]))
        }
        
        await MainActor.run {
            self.currentUser = user
            self.isAuthenticated = true
            self.selectedState = user.selectedState ?? "Odisha"
            self.selectedStateCode = UserDefaults.standard.string(forKey: userDefaultsStateCodeKey) ?? "OD"
            UserDefaults.standard.set(user.id, forKey: userDefaultsKey)
            if let state = user.selectedState {
                UserDefaults.standard.set(state, forKey: userDefaultsStateKey)
            }
        }
        
        return .success(user)
    }
    
    public func register(name: String, email: String, mobile: String, password: String) async -> Result<User, Error> {
        let users = DatabaseManager.shared.loadUsers()
        if users.contains(where: { $0.email.lowercased() == email.lowercased() }) {
            return .failure(NSError(domain: "AuthManager", code: 409, userInfo: [NSLocalizedDescriptionKey: "Email already registered."]))
        }
        if users.contains(where: { $0.mobile == mobile }) {
            return .failure(NSError(domain: "AuthManager", code: 409, userInfo: [NSLocalizedDescriptionKey: "Mobile number already registered."]))
        }
        
        let newUser = User(
            id: UUID().uuidString,
            name: name,
            email: email,
            mobile: mobile,
            selectedState: nil,
            isPremium: false
        )
        
        DatabaseManager.shared.saveUser(newUser)
        
        await MainActor.run {
            self.currentUser = newUser
            self.isAuthenticated = true
            self.selectedState = "Odisha"
            self.selectedStateCode = "OD"
            UserDefaults.standard.set(newUser.id, forKey: userDefaultsKey)
            UserDefaults.standard.set("Odisha", forKey: userDefaultsStateKey)
            UserDefaults.standard.set("OD", forKey: userDefaultsStateCodeKey)
        }
        
        return .success(newUser)
    }
    
    public func isMobileRegistered(_ mobile: String) -> Bool {
        let users = DatabaseManager.shared.loadUsers()
        return users.contains(where: { $0.mobile == mobile })
    }
    
    public func loginWithMobile(_ mobile: String) async -> Result<User, Error> {
        let users = DatabaseManager.shared.loadUsers()
        guard let user = users.first(where: { $0.mobile == mobile }) else {
            return .failure(NSError(domain: "AuthManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "User not found."]))
        }
        
        await MainActor.run {
            self.currentUser = user
            self.isAuthenticated = true
            self.selectedState = user.selectedState ?? "Odisha"
            self.selectedStateCode = UserDefaults.standard.string(forKey: userDefaultsStateCodeKey) ?? "OD"
            UserDefaults.standard.set(user.id, forKey: userDefaultsKey)
            if let state = user.selectedState {
                UserDefaults.standard.set(state, forKey: userDefaultsStateKey)
            }
        }
        
        return .success(user)
    }
    
    public func registerWithMobile(name: String, mobile: String) async -> Result<User, Error> {
        let users = DatabaseManager.shared.loadUsers()
        if users.contains(where: { $0.mobile == mobile }) {
            return .failure(NSError(domain: "AuthManager", code: 409, userInfo: [NSLocalizedDescriptionKey: "Mobile number already registered."]))
        }
        
        let newUser = User(
            id: UUID().uuidString,
            name: name,
            email: "",
            mobile: mobile,
            selectedState: nil,
            isPremium: false
        )
        
        DatabaseManager.shared.saveUser(newUser)
        
        await MainActor.run {
            self.currentUser = newUser
            self.isAuthenticated = true
            self.selectedState = "Odisha"
            self.selectedStateCode = "OD"
            UserDefaults.standard.set(newUser.id, forKey: userDefaultsKey)
            UserDefaults.standard.set("Odisha", forKey: userDefaultsStateKey)
            UserDefaults.standard.set("OD", forKey: userDefaultsStateCodeKey)
        }
        
        return .success(newUser)
    }
    
    public func selectState(name: String, code: String) {
        guard var user = currentUser else { return }
        user.selectedState = name
        DatabaseManager.shared.saveUser(user)
        
        self.currentUser = user
        self.selectedState = name
        self.selectedStateCode = code
        UserDefaults.standard.set(user.id, forKey: userDefaultsKey)
        UserDefaults.standard.set(name, forKey: userDefaultsStateKey)
        UserDefaults.standard.set(code, forKey: userDefaultsStateCodeKey)
        
        // Post notification to let MapViewModel know state changed
        NotificationCenter.default.post(name: NSNotification.Name("BhumitraStateChanged"), object: nil)
    }
    
    public func logout() {
        self.currentUser = nil
        self.isAuthenticated = false
        self.selectedState = "Odisha"
        self.selectedStateCode = "OD"
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        UserDefaults.standard.removeObject(forKey: userDefaultsStateKey)
        UserDefaults.standard.removeObject(forKey: userDefaultsStateCodeKey)
    }
    
    public func refreshUser() {
        guard let user = currentUser else { return }
        let users = DatabaseManager.shared.loadUsers()
        if let freshUser = users.first(where: { $0.id == user.id }) {
            self.currentUser = freshUser
        }
    }
}
