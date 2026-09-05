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

// MARK: - Figma Design Tokens (Direct from Figma 772:327 - 772:442)

private enum OnboardingDesign {
    static let primaryText = Color(red: 25 / 255, green: 12 / 255, blue: 48 / 255) // #190C30
    static let yellowHighlight = Color(red: 255 / 255, green: 245 / 255, blue: 173 / 255) // #FFF5AD
    static let authButtonBorder = Color(red: 251 / 255, green: 251 / 255, blue: 251 / 255) // #FBFBFB
    
    static let headlineSize: CGFloat = 40
    static let headlineLineSpacing: CGFloat = -2
    static let loginTitleSize: CGFloat = 32
    static let loginTitleTracking: CGFloat = -1.15
    
    static let nextButtonWidth: CGFloat = 222
    static let nextButtonHeight: CGFloat = 61
    static let nextButtonBorderWidth: CGFloat = 4
    static let nextButtonCornerRadius: CGFloat = 40
    
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
    
    @State private var currentStep: Int = 0
    @State private var isLoading: Bool = false
    @State private var isGoogleLoading: Bool = false
    @State private var isAnimatingStep: Bool = false
    @State private var isTransitioning: Bool = false
    @State private var errorMessage: String? = nil
    @State private var coordinator = AppleSignInCoordinator()
    
    private let totalSteps = 4
    var triggerSource: String = "launch"
    var onDismiss: (() -> Void)? = nil
    
    public init(
        initialStep: Int = 0,
        triggerSource: String = "launch",
        onDismiss: (() -> Void)? = nil
    ) {
        self._currentStep = State(initialValue: initialStep)
        self.triggerSource = triggerSource
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Edge-to-Edge Canvas Linear Gradient
                OnboardingDesign.canvasGradient
                    .ignoresSafeArea()
                
                TabView(selection: $currentStep) {
                    // Onboarding 1: Keep your land records secure (772:327)
                    secureScreen(in: geometry)
                        .tag(0)
                    
                    // Onboarding 2: Navigate every plot with ease (772:381)
                    navigateScreen(in: geometry)
                        .tag(1)
                    
                    // Onboarding 3: Find plots that is right for you (772:399)
                    findPlotsScreen(in: geometry)
                        .tag(2)
                    
                    // Login Screen: Your land journey starts here (772:442)
                    loginScreen(in: geometry)
                        .tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.spring(response: 0.42, dampingFraction: 0.85), value: currentStep)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            AnalyticsService.shared.log(.authScreenViewed(triggerSource: triggerSource))
        }
    }
    
    // MARK: - Screen 1: Keep your land records secure (Figma 772:327)
    private func secureScreen(in geometry: GeometryProxy) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            headlineBlock(
                lines: [
                    .plain("Keep your"),
                    .plain("land records"),
                    .highlighted("secure")
                ]
            )
            .padding(.top, max(geometry.size.height * 0.16, 80))
            .padding(.horizontal, 24)
            
            Spacer(minLength: 12)
            
            // 3D Safe Illustration (with interaction-triggered animation)
            HStack {
                Spacer()
                InteractionAnimatedGraphicView(
                    videoName: "backgroundleaf",
                    staticImageName: "safe",
                    isTriggered: currentStep == 0 && isAnimatingStep,
                    blendMode: .multiply,
                    onFinish: completeStepTransition
                )
                .frame(maxWidth: geometry.size.width * 0.84, maxHeight: geometry.size.height * 0.44)
            }
            .padding(.trailing, 6)
            
            Spacer(minLength: 16)
            
            nextButton
                .padding(.bottom, max(geometry.size.height * 0.06, 44))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Screen 2: Navigate every plot with ease (Figma 772:381)
    private func navigateScreen(in geometry: GeometryProxy) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // 3D Map & Navigation Illustration (with interaction-triggered animation)
            HStack {
                Spacer()
                InteractionAnimatedGraphicView(
                    videoName: "backgroundleaf",
                    staticImageName: "Group 262",
                    isTriggered: currentStep == 1 && isAnimatingStep,
                    blendMode: .multiply,
                    onFinish: completeStepTransition
                )
                .frame(maxWidth: geometry.size.width * 0.82, maxHeight: geometry.size.height * 0.42)
            }
            .padding(.top, max(geometry.size.height * 0.04, 30))
            .padding(.trailing, 8)
            
            Spacer(minLength: 12)
            
            headlineBlock(
                lines: [
                    .highlighted("Navigate"),
                    .plain("every plot"),
                    .plain("with ease")
                ]
            )
            .padding(.horizontal, 24)
            
            Spacer(minLength: 20)
            
            nextButton
                .padding(.bottom, max(geometry.size.height * 0.06, 44))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Screen 3: Find plots that is right for you (Figma 772:399)
    private func findPlotsScreen(in geometry: GeometryProxy) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            headlineBlock(
                lines: [
                    .plain("Find plots"),
                    .inlineHighlighted(prefix: "that is ", highlight: "right"),
                    .plain("for you")
                ]
            )
            .padding(.top, max(geometry.size.height * 0.16, 80))
            .padding(.horizontal, 24)
            
            Spacer(minLength: 12)
            
            // 3D Land Surveyor & Compass Illustration (with interaction-triggered animation)
            HStack {
                Spacer()
                InteractionAnimatedGraphicView(
                    videoName: "backgroundleaf",
                    staticImageName: "Group 263",
                    isTriggered: currentStep == 2 && isAnimatingStep,
                    blendMode: .multiply,
                    onFinish: completeStepTransition
                )
                .frame(maxWidth: geometry.size.width * 0.88, maxHeight: geometry.size.height * 0.46)
            }
            .padding(.trailing, 2)
            
            Spacer(minLength: 16)
            
            nextButton
                .padding(.bottom, max(geometry.size.height * 0.06, 44))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Screen 4: Login Screen (Figma 772:442)
    private func loginScreen(in geometry: GeometryProxy) -> some View {
        ZStack(alignment: .bottom) {
            // Landscape background pinned to bottom ignoring safe area
            VStack(spacing: 0) {
                Spacer()
                Image("LoginBackground")
                    .resizable()
                    .scaledToFill()
                    .blendMode(.multiply)
                    .frame(width: geometry.size.width)
                    .clipped()
            }
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Title: "Your land journey\nstarts here"
                Text("Your land journey\nstarts here")
                    .font(.stackSansHeadline(size: OnboardingDesign.loginTitleSize, weight: .regular))
                    .tracking(OnboardingDesign.loginTitleTracking)
                    .lineSpacing(2)
                    .multilineTextAlignment(.center)
                    .foregroundColor(OnboardingDesign.primaryText)
                    .padding(.top, max(geometry.size.height * 0.22, 140))
                    .padding(.horizontal, 32)
                
                Spacer()
                    .frame(height: max(geometry.size.height * 0.08, 40))
                
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
    
    // MARK: - Shared Headline Line Enum
    private enum HeadlineLine {
        case plain(String)
        case highlighted(String)
        case inlineHighlighted(prefix: String, highlight: String)
    }
    
    private func headlineBlock(lines: [HeadlineLine]) -> some View {
        VStack(alignment: .leading, spacing: OnboardingDesign.headlineLineSpacing) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                switch line {
                case .plain(let text):
                    Text(text)
                        .font(.stackSansHeadline(size: OnboardingDesign.headlineSize, weight: .regular))
                        .foregroundColor(OnboardingDesign.primaryText)
                    
                case .highlighted(let text):
                    Text(text)
                        .font(.stackSansHeadline(size: OnboardingDesign.headlineSize, weight: .regular))
                        .foregroundColor(OnboardingDesign.primaryText)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(
                            RoundedRectangle(cornerRadius: 3)
                                .fill(OnboardingDesign.yellowHighlight)
                        )
                    
                case .inlineHighlighted(let prefix, let highlight):
                    HStack(spacing: 0) {
                        Text(prefix)
                            .font(.stackSansHeadline(size: OnboardingDesign.headlineSize, weight: .regular))
                            .foregroundColor(OnboardingDesign.primaryText)
                        
                        Text(highlight)
                            .font(.stackSansHeadline(size: OnboardingDesign.headlineSize, weight: .regular))
                            .foregroundColor(OnboardingDesign.primaryText)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(OnboardingDesign.yellowHighlight)
                            )
                    }
                }
            }
        }
    }
    
    // MARK: - Next Button
    private var nextButton: some View {
        HStack {
            Spacer()
            Button(action: handleNextTriggered) {
                Text("Next")
                    .font(.stackSansHeadline(size: 21, weight: .bold))
                    .foregroundColor(.black)
                    .frame(
                        width: OnboardingDesign.nextButtonWidth,
                        height: OnboardingDesign.nextButtonHeight
                    )
                    .background(Color.white.opacity(0.12))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.white, lineWidth: OnboardingDesign.nextButtonBorderWidth)
                    )
                    .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
            }
            .buttonStyle(TactileGlassButtonStyle())
            .keyboardShortcut(.defaultAction)
            .keyboardShortcut(.return, modifiers: [])
            .disabled(isTransitioning)
            Spacer()
        }
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
                width: OnboardingDesign.authButtonWidth,
                height: OnboardingDesign.authButtonHeight
            )
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.35))
            )
            .overlay(
                Capsule()
                    .stroke(OnboardingDesign.authButtonBorder, lineWidth: OnboardingDesign.authButtonBorderWidth)
            )
            .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
        }
        .buttonStyle(TactileGlassButtonStyle())
        .disabled(isLoading || isGoogleLoading)
    }
    
    private func handleNextTriggered() {
        guard !isTransitioning else { return }
        Theme.haptic(.light)
        isTransitioning = true
        isAnimatingStep = true
    }
    
    private func completeStepTransition() {
        guard isTransitioning else { return }
        withAnimation(.spring(response: 0.42, dampingFraction: 0.85)) {
            if currentStep < totalSteps - 1 {
                currentStep += 1
            }
        }
        isAnimatingStep = false
        isTransitioning = false
    }
    
    private func advanceStep() {
        handleNextTriggered()
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
    
    // MARK: - Sign in with Google Trigger
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
