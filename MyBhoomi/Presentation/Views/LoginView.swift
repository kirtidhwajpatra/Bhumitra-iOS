import SwiftUI
import AuthenticationServices
import AVFoundation

public struct LoginView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.openURL) private var openURL
    @StateObject private var authManager = AuthManager.shared
    
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    
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
                        hapticFeedback(.light)
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
                
                // Centered Main Illustration Card
                VStack(spacing: 0) {
                    // Looping Video Animation
                    LoopingVideoBackgroundView(
                        videoName: "bhoomitra_light",
                        videoExtension: "mp4",
                        videoGravity: .resizeAspect,
                        playerBackgroundColor: .clear
                    )
                    .frame(height: 330)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .padding(.top, 20)
                    .padding(.horizontal, 16)
                    
                    // Card Subtitle
                    Text("Let’s take care of your land ♥")
                        .font(.system(size: 21, weight: .medium, design: .default))
                        .foregroundColor(Color(red: 20/255, green: 20/255, blue: 20/255))
                        .multilineTextAlignment(.center)
                        .padding(.top, 14)
                        .padding(.bottom, 28)
                }
                .frame(maxWidth: .infinity)
                .background(Color(red: 255/255, green: 252/255, blue: 246/255)) // Warm ivory card
                .clipShape(RoundedRectangle(cornerRadius: 38, style: .continuous))
                .shadow(color: Color.black.opacity(0.04), radius: 16, x: 0, y: 6)
                .padding(.horizontal, 24)
                
                Spacer(minLength: 28)
                
                // Bottom Authentication & Legal Section
                VStack(spacing: 16) {
                    // Sign in with Apple Button
                    ZStack {
                        SignInWithAppleButton(
                            .signIn,
                            onRequest: { request in
                                request.requestedScopes = [.fullName, .email]
                            },
                            onCompletion: { result in
                                handleAppleSignIn(result: result)
                            }
                        )
                        .signInWithAppleButtonStyle(.black)
                        .frame(height: 56)
                        .clipShape(Capsule())
                        .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 5)
                        
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        }
                    }
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
                    
                    // Legal Terms and Disclaimer Footer
                    VStack(spacing: 6) {
                        Text("By signing up for Bhumitra, you agree to our [Terms of Service](https://www.apple.com/legal/internet-services/itunes/dev/stdeula/) and [Privacy Policy](https://kirtidhwajpatra.github.io/Bhumitra_PrivacyPolicy/).")
                            .font(.system(size: 9.5, weight: .regular))
                            .foregroundColor(Color(red: 130/255, green: 135/255, blue: 142/255))
                            .tint(Color(red: 0/255, green: 122/255, blue: 255/255))
                            .multilineTextAlignment(.center)
                        
                        Text("The information and insights provided in the app are for general guidance and may not always be accurate or complete. Bhumitra does not guarantee the accuracy of property, land, location, or other information. Please verify important details independently before making any decisions.")
                            .font(.system(size: 9, weight: .regular))
                            .foregroundColor(Color(red: 145/255, green: 150/255, blue: 156/255))
                            .multilineTextAlignment(.center)
                            .lineSpacing(1.5)
                    }
                    .padding(.horizontal, 32)
                    .padding(.top, 4)
                    .padding(.bottom, 12)
                }
            }
        }
    }
    
    // MARK: - Sign in with Apple Handler
    
    private func handleAppleSignIn(result: Result<ASAuthorization, Error>) {
        hapticFeedback(.medium)
        errorMessage = nil
        
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
                        hapticFeedback(.medium)
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
