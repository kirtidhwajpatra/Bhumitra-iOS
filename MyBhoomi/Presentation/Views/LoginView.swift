import SwiftUI
import AuthenticationServices
import AVFoundation

public struct LoginView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.openURL) private var openURL
    @StateObject private var authManager = AuthManager.shared
    
    @State private var isLoading = false
    @State private var isGoogleLoading = false
    @State private var errorMessage: String? = nil
    @State private var coordinator = AppleSignInCoordinator()
    
    var triggerSource: String = "profile_tab"
    var onDismiss: (() -> Void)? = nil
    
    public init(triggerSource: String = "profile_tab", onDismiss: (() -> Void)? = nil) {
        self.triggerSource = triggerSource
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        ZStack {
            // Light neutral canvas background (#F1F1F1)
            Color(red: 241/255, green: 241/255, blue: 241/255)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top Header Bar with Larger Liquid Glass Dismiss Button
                HStack {
                    Spacer()
                    Button(action: {
                        Theme.haptic(.light)
                        AnalyticsService.shared.log(.guestSessionStarted(triggerSource: triggerSource))
                        if let onDismiss = onDismiss {
                            onDismiss()
                        } else {
                            dismiss()
                        }
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color.black.opacity(0.65))
                            .frame(width: 44, height: 44)
                            .glassEffect(
                                .regular.interactive(),
                                in: .circle
                            )
                    }
                    .padding(.trailing, 20)
                    .padding(.top, 10)
                }
                
                Spacer(minLength: 4)
                
                // Centered Main Illustration Card with Pure White Surface & Shifted Down Video
                VStack(spacing: 0) {
                    // Looping Video Animation (Shifted slightly down to center character)
                    LoopingVideoBackgroundView(
                        videoName: "bhoomitra_light",
                        videoExtension: "mp4",
                        videoGravity: .resizeAspectFill,
                        playerBackgroundColor: .white
                    )
                    .frame(height: 360)
                    .offset(y: 16)
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
                .frame(height: 450)
                .background(Color.white) // Pure white card matching video background
                .clipShape(RoundedRectangle(cornerRadius: 38, style: .continuous))
                .shadow(color: Color.black.opacity(0.04), radius: 18, x: 0, y: 8)
                .padding(.horizontal, 24)
                
                Spacer(minLength: 12)
                
                // Bottom Authentication & Legal Section (Elevated Position)
                VStack(spacing: 11) {
                    // 1. Sign in with Apple Pill Button
                    Button(action: startAppleSignIn) {
                        HStack(spacing: 8) {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "applelogo")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                Text("Sign in with Apple")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(width: 300, height: 50)
                        .background(Color.black)
                        .clipShape(Capsule())
                        .shadow(color: Color.black.opacity(0.16), radius: 8, x: 0, y: 4)
                    }
                    .buttonStyle(TactileGlassButtonStyle())
                    .disabled(isLoading || isGoogleLoading)
                    
                    // 2. Continue with Google Pill Button
                    Button(action: startGoogleSignIn) {
                        HStack(spacing: 9) {
                            if isGoogleLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .black))
                            } else {
                                GoogleLogoView(size: 19)
                                Text("Continue with Google")
                                    .font(.system(size: 16.5, weight: .semibold))
                                    .foregroundColor(Color(red: 32/255, green: 33/255, blue: 36/255))
                            }
                        }
                        .frame(width: 300, height: 50)
                        .background(Color.white)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color.black.opacity(0.12), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 3)
                    }
                    .buttonStyle(TactileGlassButtonStyle())
                    .disabled(isLoading || isGoogleLoading)
                    
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
                        .padding(.top, 4)
                        .padding(.bottom, 8)
                }
                
                Spacer(minLength: 6)
            }
        }
        .onAppear {
            AnalyticsService.shared.log(.authScreenViewed(triggerSource: triggerSource))
        }
    }
    
    // MARK: - Native Sign in with Apple Trigger
    
    private func startAppleSignIn() {
        Theme.haptic(.medium)
        errorMessage = nil
        AnalyticsService.shared.log(.loginStarted(provider: .apple))
        
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
                        AnalyticsService.shared.log(.loginFailed(provider: .apple, errorCategory: .backendError))
                    }
                }
            }
            
        case .failure(let error):
            let nsError = error as NSError
            if nsError.code == ASAuthorizationError.canceled.rawValue {
                AnalyticsService.shared.log(.loginFailed(provider: .apple, errorCategory: .cancelled))
            } else {
                errorMessage = error.localizedDescription
                AnalyticsService.shared.log(.loginFailed(provider: .apple, errorCategory: .providerError))
            }
        }
    }
    
    // MARK: - Sign in with Google Trigger (Official Google SDK)
    
    private func startGoogleSignIn() {
        Theme.haptic(.medium)
        errorMessage = nil
        isGoogleLoading = true
        AnalyticsService.shared.log(.loginStarted(provider: .google))
        
        Task {
            let result = await GoogleAuthCoordinator.shared.signIn()
            await MainActor.run {
                isGoogleLoading = false
                switch result {
                case .success(let profile):
                    Task {
                        let authResult = await authManager.handleGoogleProfile(profile)
                        await MainActor.run {
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
                                AnalyticsService.shared.log(.loginFailed(provider: .google, errorCategory: .backendError))
                            }
                        }
                    }
                case .failure(let error):
                    let nsError = error as NSError
                    if nsError.code == -999 || nsError.code == 1 {
                        AnalyticsService.shared.log(.loginFailed(provider: .google, errorCategory: .cancelled))
                    } else {
                        Theme.haptic(.medium)
                        errorMessage = error.localizedDescription
                        AnalyticsService.shared.log(.loginFailed(provider: .google, errorCategory: .providerError))
                    }
                }
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
