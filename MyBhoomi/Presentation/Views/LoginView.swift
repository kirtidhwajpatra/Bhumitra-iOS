//
//  LoginView.swift
//  MyBhoomi
//
//  Production Onboarding & Authentication Flow
//  Pixel-perfect matching with Figma (v8JckKKMCLm5a8BhVxXSv7):
//  - Onboarding 1: 772:327 ("Keep your land records secure")
//  - Onboarding 2: 772:381 ("Navigate every plot with ease")
//  - Onboarding 3: 772:399 ("Find plots that is right for you")
//  - Login Screen: 772:442 ("Your land journey starts here")
//

import SwiftUI
import AuthenticationServices

// MARK: - Figma Design Tokens (Direct from Figma 772:442)

private enum LoginDesign {
    static let primaryText = Color(red: 25 / 255, green: 12 / 255, blue: 48 / 255) // #190C30
    static let authButtonBorder = Color(red: 251 / 255, green: 251 / 255, blue: 251 / 255) // #FBFBFB
    
    static let loginTitleSize: CGFloat = 32
    static let loginTitleTracking: CGFloat = -1.15
    
    static let authButtonWidth: CGFloat = 269
    static let authButtonHeight: CGFloat = 60
    static let authButtonBorderWidth: CGFloat = 3.926
    static let authButtonCornerRadius: CGFloat = 49
    
    // Canvas Linear Gradient (Figma #781:2223)
    static var canvasGradient: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: Color(hex: "#FDFCFF"), location: 0.01),
                .init(color: Color(hex: "#E7D5FD"), location: 1.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

public struct LoginView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @StateObject private var authManager = AuthManager.shared
    
    @State private var isLoading: Bool = false
    @State private var isGoogleLoading: Bool = false
    @State private var errorMessage: String? = nil
    @State private var coordinator = AppleSignInCoordinator()
    
    var triggerSource: String = "launch"
    var onDismiss: (() -> Void)? = nil
    
    public init(
        triggerSource: String = "launch",
        onDismiss: (() -> Void)? = nil
    ) {
        self.triggerSource = triggerSource
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Edge-to-Edge Canvas Linear Gradient
                LoginDesign.canvasGradient
                    .ignoresSafeArea()
                
                // Login Screen (Figma 772:442)
                loginScreen(in: geometry)
                
                // Top Close Button if presented as a modal/sheet
                if onDismiss != nil {
                    VStack {
                        HStack {
                            Spacer()
                            Button {
                                if let onDismiss = onDismiss {
                                    onDismiss()
                                } else {
                                    dismiss()
                                }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 28, weight: .medium))
                                    .foregroundColor(Color.black.opacity(0.4))
                                    .padding(16)
                            }
                            .buttonStyle(.plain)
                        }
                        Spacer()
                    }
                    .padding(.top, max(geometry.safeAreaInsets.top, 20))
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            AnalyticsService.shared.log(.authScreenViewed(triggerSource: triggerSource))
        }
    }
    
    // MARK: - Login Screen (Figma 772:442)
    private func loginScreen(in geometry: GeometryProxy) -> some View {
        ZStack(alignment: .bottom) {
            // Landscape background pinned to absolute bottom ignoring safe area with width fitted
            VStack(spacing: 0) {
                Spacer()
                Image("LoginBackground")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: geometry.size.width)
                    .blendMode(.multiply)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Title: "Your land journey\nstarts here"
                Text("Your land journey\nstarts here")
                    .font(.stackSansHeadline(size: LoginDesign.loginTitleSize, weight: .regular))
                    .tracking(LoginDesign.loginTitleTracking)
                    .lineSpacing(2)
                    .multilineTextAlignment(.center)
                    .foregroundColor(LoginDesign.primaryText)
                    .padding(.top, max(geometry.size.height * 0.22, 140))
                    .padding(.horizontal, 32)
                
                Spacer()
                    .frame(height: max(geometry.size.height * 0.15, 84))
                
                // Auth Action Buttons
                VStack(spacing: 14) {
                    // Sign in with Apple
                    authButton(
                        isLoading: isLoading,
                        action: startAppleSignIn
                    ) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .black))
                        } else {
                            Image(systemName: "applelogo")
                                .font(.system(size: 19, weight: .medium))
                                .foregroundColor(.black)
                            Text("sign in with apple")
                                .font(.stackSansHeadline(size: 22, weight: .regular))
                                .foregroundColor(.black)
                        }
                    }
                    
                    // Sign in with Google
                    authButton(
                        isLoading: isGoogleLoading,
                        action: startGoogleSignIn
                    ) {
                        if isGoogleLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .black))
                        } else {
                            GoogleLogoView(size: 24)
                            Text("sign in with google")
                                .font(.stackSansHeadline(size: 22, weight: .regular))
                                .foregroundColor(.black)
                        }
                    }
                    
                    if let error = errorMessage {
                        Text(error)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.red)
                            .padding(.horizontal, 24)
                            .padding(.top, 4)
                            .transition(.opacity)
                    }
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
        .clipped()
    }
    
    // MARK: - Auth Button
    private func authButton<Label: View>(
        isLoading: Bool,
        action: @escaping () -> Void,
        @ViewBuilder label: () -> Label
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                label()
            }
            .frame(
                width: LoginDesign.authButtonWidth,
                height: LoginDesign.authButtonHeight
            )
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.35))
            )
            .overlay(
                Capsule()
                    .stroke(LoginDesign.authButtonBorder, lineWidth: LoginDesign.authButtonBorderWidth)
            )
            .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
        }
        .buttonStyle(TactileGlassButtonStyle())
        .disabled(isLoading || isGoogleLoading)
    }
    
    // MARK: - Native Sign in with Apple Trigger
    private func startAppleSignIn() {
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
    
    // MARK: - Sign in with Google Trigger
    private func startGoogleSignIn() {
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
                                errorMessage = error.localizedDescription
                                AnalyticsService.shared.log(.loginFailed(provider: .google, errorCategory: .backendError))
                            }
                        }
                    }
                case .failure(let error):
                    let nsError = error as NSError
                    if nsError.code == -5 || nsError.code == -999 || nsError.code == 1 {
                        AnalyticsService.shared.log(.loginFailed(provider: .google, errorCategory: .cancelled))
                    } else {
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
