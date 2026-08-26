import SwiftUI
import AuthenticationServices
import AVFoundation

public struct LoginView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.openURL) private var openURL
    @StateObject private var authManager = AuthManager.shared
    
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var coordinator = AppleSignInCoordinator()
    
    var onDismiss: (() -> Void)? = nil
    
    public init(onDismiss: (() -> Void)? = nil) {
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        ZStack {
            // Light neutral canvas background (#F1F1F1)
            Color(red: 241/255, green: 241/255, blue: 241/255)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header Bar with subtle dismiss button
                HStack {
                    Spacer()
                    Button(action: {
                        Theme.haptic(.light)
                        if let onDismiss = onDismiss {
                            onDismiss()
                        } else {
                            dismiss()
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 26))
                            .foregroundColor(Color.black.opacity(0.18))
                    }
                    .padding(.trailing, 20)
                    .padding(.top, 14)
                }
                
                Spacer(minLength: 8)
                
                // Centered Main Illustration Card with Edge-to-Edge Zoomed Video
                ZStack(alignment: .bottom) {
                    // Full Edge-to-Edge Zoomed Looping Video inside card
                    LoopingVideoBackgroundView(
                        videoName: "bhoomitra_light",
                        videoExtension: "mp4",
                        videoGravity: .resizeAspectFill,
                        playerBackgroundColor: .clear
                    )
                    .frame(height: 420)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    
                    // Card Subtitle overlayed at the bottom
                    Text("Let’s take care of your land ♥")
                        .font(.system(size: 21, weight: .medium, design: .default))
                        .foregroundColor(Color(red: 20/255, green: 20/255, blue: 20/255))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 420)
                .background(Color(red: 255/255, green: 252/255, blue: 246/255)) // Warm ivory card
                .clipShape(RoundedRectangle(cornerRadius: 38, style: .continuous))
                .shadow(color: Color.black.opacity(0.05), radius: 18, x: 0, y: 8)
                .padding(.horizontal, 24)
                
                Spacer(minLength: 28)
                
                // Bottom Authentication & Legal Section
                VStack(spacing: 18) {
                    // Liquid Glass Sign in with Apple Button
                    Button(action: startAppleSignIn) {
                        HStack(spacing: 8) {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .primary))
                            } else {
                                Image(systemName: "applelogo")
                                    .font(.system(size: 20, weight: .semibold))
                                Text("Sign in with Apple")
                                    .font(.system(size: 19, weight: .semibold))
                            }
                        }
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .glassEffect(
                            .regular.interactive(),
                            in: .capsule
                        )
                        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 5)
                    }
                    .buttonStyle(TactileGlassButtonStyle())
                    .disabled(isLoading)
                    .padding(.horizontal, 24)
                    
                    // Error message if any
                    if let error = errorMessage {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.red)
                            Text(error)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.red)
                        }
                        .padding(.horizontal, 24)
                        .transition(.opacity)
                    }
                    
                    // Simplified Legal Terms Footer
                    Text("By signing up for Bhumitra, you agree to our [Terms of Service](https://www.apple.com/legal/internet-services/itunes/dev/stdeula/) and [Privacy Policy](https://kirtidhwajpatra.github.io/Bhumitra_PrivacyPolicy/).")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(Color(red: 130/255, green: 135/255, blue: 142/255))
                        .tint(Color(red: 0/255, green: 122/255, blue: 255/255))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.top, 2)
                        .padding(.bottom, 16)
                }
            }
        }
    }
    
    // MARK: - Native Sign in with Apple Trigger
    
    private func startAppleSignIn() {
        Theme.haptic(.medium)
        errorMessage = nil
        
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = coordinator
        controller.presentationContextProvider = coordinator
        
        coordinator.onCompletion = { result in
            handleAppleSignIn(result: result)
        }
        
        controller.performRequests()
    }
    
    // MARK: - Sign in with Apple Result Handler
    
    private func handleAppleSignIn(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            isLoading = true
            Task {
                let authResult = await authManager.handleAppleAuthorization(authorization: authorization)
                await MainActor.run {
                    isLoading = false
                    switch authResult {
                    case .success:
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        if let onDismiss = onDismiss {
                            onDismiss()
                        } else {
                            dismiss()
                        }
                    case .failure(let error):
                        Theme.haptic(.medium)
                        errorMessage = error.localizedDescription
                    }
                }
            }
            
        case .failure(let error):
            if (error as NSError).code != ASAuthorizationError.canceled.rawValue {
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Apple Sign In Presentation Coordinator

final class AppleSignInCoordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    var onCompletion: ((Result<ASAuthorization, Error>) -> Void)?
    
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }) ?? windowScene.windows.first else {
            return UIWindow()
        }
        return window
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        onCompletion?(.success(authorization))
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        onCompletion?(.failure(error))
    }
}
