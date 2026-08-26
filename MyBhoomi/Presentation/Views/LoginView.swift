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
                // Top Header Bar with Liquid Glass Dismiss Button
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
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Color.black.opacity(0.65))
                            .frame(width: 34, height: 34)
                            .glassEffect(
                                .regular.interactive(),
                                in: .circle
                            )
                    }
                    .padding(.trailing, 20)
                    .padding(.top, 10)
                }
                
                Spacer(minLength: 4)
                
                // Centered Main Illustration Card with Taller Frame & Breathing Room
                VStack(spacing: 0) {
                    // Looping Video Animation
                    LoopingVideoBackgroundView(
                        videoName: "bhoomitra_light",
                        videoExtension: "mp4",
                        videoGravity: .resizeAspectFill,
                        playerBackgroundColor: .clear
                    )
                    .frame(height: 380)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    
                    Spacer(minLength: 6)
                    
                    // Card Subtitle with clear vertical breathing space
                    Text("Let’s take care of your land ♥")
                        .font(.system(size: 21, weight: .medium, design: .default))
                        .foregroundColor(Color(red: 20/255, green: 20/255, blue: 20/255))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 22)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 470)
                .background(Color(red: 255/255, green: 252/255, blue: 246/255)) // Warm ivory card
                .clipShape(RoundedRectangle(cornerRadius: 38, style: .continuous))
                .shadow(color: Color.black.opacity(0.04), radius: 18, x: 0, y: 8)
                .padding(.horizontal, 24)
                
                Spacer(minLength: 16)
                
                // Bottom Authentication & Legal Section (Elevated Position)
                VStack(spacing: 14) {
                    // Compact Black Sign in with Apple Pill Button
                    Button(action: startAppleSignIn) {
                        HStack(spacing: 8) {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "applelogo")
                                    .font(.system(size: 19, weight: .semibold))
                                    .foregroundColor(.white)
                                Text("Sign in with Apple")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(width: 300, height: 54)
                        .background(Color.black)
                        .clipShape(Capsule())
                        .shadow(color: Color.black.opacity(0.18), radius: 10, x: 0, y: 5)
                    }
                    .buttonStyle(TactileGlassButtonStyle())
                    .disabled(isLoading)
                    
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
                        .font(.system(size: 10.5, weight: .regular))
                        .foregroundColor(Color(red: 135/255, green: 140/255, blue: 146/255))
                        .tint(Color(red: 0/255, green: 122/255, blue: 255/255))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 36)
                        .padding(.bottom, 12)
                }
                
                Spacer(minLength: 8)
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
