import Foundation
import UIKit
import GoogleSignIn

// ============================================================
// MARK: - OFFICIAL GOOGLE SIGN-IN COORDINATOR
// ============================================================

public struct GoogleUserProfile: Codable {
    public let id: String
    public let email: String
    public let name: String
    public let picture: String?
    public let idToken: String
    
    public init(id: String, email: String, name: String, picture: String? = nil, idToken: String) {
        self.id = id
        self.email = email
        self.name = name
        self.picture = picture
        self.idToken = idToken
    }
}

@MainActor
public final class GoogleAuthCoordinator: NSObject {
    public static let shared = GoogleAuthCoordinator()
    
    public static let clientID = "758542001999-sngp52t5asu19bfbqk08c33qo27l2t73.apps.googleusercontent.com"
    
    private override init() {
        super.init()
    }
    
    /// Triggers the official Google Sign-In SDK flow
    public func signIn(presentingViewController: UIViewController? = nil) async -> Result<GoogleUserProfile, Error> {
        let presenter: UIViewController
        if let presentingViewController = presentingViewController {
            presenter = presentingViewController
        } else {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController ?? windowScene.windows.first?.rootViewController else {
                return .failure(NSError(domain: "GoogleSignIn", code: -1, userInfo: [NSLocalizedDescriptionKey: "No active presentation view controller found."]))
            }
            var topVC = rootVC
            while let presented = topVC.presentedViewController {
                topVC = presented
            }
            presenter = topVC
        }
        
        do {
            print("DEBUG: 🚀 Google Sign-In started")
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
            
            guard let idToken = result.user.idToken?.tokenString else {
                print("DEBUG: ⚠️ Google Sign-In missing ID token")
                return .failure(NSError(domain: "GoogleSignIn", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to obtain Google ID Token."]))
            }
            
            let user = result.user
            let email = user.profile?.email ?? ""
            let name = user.profile?.name ?? "Google User"
            let pictureURL = user.profile?.imageURL(withDimension: 128)?.absoluteString
            let sub = user.userID ?? (user.profile?.email ?? UUID().uuidString)
            
            print("DEBUG: ✅ Google Sign-In succeeded for user: \(name)")
            
            let profile = GoogleUserProfile(
                id: "google_\(sub)",
                email: email,
                name: name,
                picture: pictureURL,
                idToken: idToken
            )
            return .success(profile)
        } catch {
            let nsError = error as NSError
            if nsError.code == GIDSignInError.canceled.rawValue {
                print("DEBUG: ℹ️ Google Sign-In was cancelled by user.")
                return .failure(NSError(domain: "GoogleSignIn", code: -999, userInfo: [NSLocalizedDescriptionKey: "Sign in with Google was cancelled."]))
            }
            print("DEBUG: ❌ Google Sign-In error: \(error.localizedDescription)")
            return .failure(error)
        }
    }
}
