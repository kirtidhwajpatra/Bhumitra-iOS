//
//  LoginView.swift
//  MyBhoomi
//
//  Sign-in screen (launch flow and modal). Same language as the rest of the
//  app: one SheetChrome background, leading-aligned title, a short list of
//  what an account gives you, and 52pt CTA-style sign-in buttons pinned to
//  the bottom with the legal line under them.
//

import SwiftUI
import AuthenticationServices

public struct LoginView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authManager = AuthManager.shared

    @State private var isLoading: Bool = false
    @State private var isGoogleLoading: Bool = false
    @State private var errorMessage: String? = nil
    @State private var coordinator = AppleSignInCoordinator()

    var triggerSource: String = "launch"
    var onDismiss: (() -> Void)? = nil
    /// Launch flow only: lets people use the app without an account.
    var onContinueAsGuest: (() -> Void)? = nil

    public init(
        triggerSource: String = "launch",
        onDismiss: (() -> Void)? = nil,
        onContinueAsGuest: (() -> Void)? = nil
    ) {
        self.triggerSource = triggerSource
        self.onDismiss = onDismiss
        self.onContinueAsGuest = onContinueAsGuest
    }

    private var isBusy: Bool { isLoading || isGoogleLoading }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            topBar

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    benefits.padding(.top, 32)
                }
                .padding(.horizontal, SheetChrome.inset)
                .padding(.top, 24)
                .padding(.bottom, 24)
            }
            .scrollBounceBehavior(.basedOnSize)

            actions
        }
        .background(SheetChrome.background.ignoresSafeArea())
        .animation(.easeOut(duration: 0.2), value: errorMessage)
        .onAppear {
            AnalyticsService.shared.log(.authScreenViewed(triggerSource: triggerSource))
        }
    }

    // MARK: - Top bar (close only when presented modally)

    private var topBar: some View {
        HStack {
            Spacer()
            if onDismiss != nil {
                SheetIconButton("xmark", accessibilityLabel: "Close", action: close)
            }
        }
        .frame(height: SheetChrome.iconButtonSize)
        .padding(.horizontal, SheetChrome.inset)
        .padding(.top, 12)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            if authManager.sessionExpiredNotice {
                Label("Your session ended. Sign in again to use your plot searches.", systemImage: "clock.arrow.circlepath")
                    .font(.googleSans(size: 13, weight: .medium))
                    .foregroundColor(Theme.Color.bhumitraPrimaryText)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 12).fill(SheetChrome.controlFill))
                    .padding(.bottom, 8)
            }
            Text(AppInfo.name)
                .font(.googleSans(size: 15, weight: .semibold))
                .foregroundColor(Theme.Color.bhumitraPrimary)

            Text("Sign in to keep your plot searches safe")
                .font(.stackSansHeadline(size: 30, weight: .semibold))
                .tracking(-0.6)
                .foregroundColor(Theme.Color.bhumitraPrimaryText)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            Text("Your plot searches and purchases stay with your account, on any device. You can also continue without an account.")
                .font(.googleSans(size: 16, weight: .regular))
                .foregroundColor(Theme.Color.bhumitraSecondaryText)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - What an account gives you

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 0) {
            benefitRow(icon: "doc.text.magnifyingglass", text: "Land records (RoR) from the Odisha Bhulekh portal")
            SheetHairline().padding(.leading, 48)
            benefitRow(icon: "map", text: "Plot boundaries on a live map")
            SheetHairline().padding(.leading, 48)
            benefitRow(icon: "lock.shield", text: "Private sign-in with Apple or Google")
        }
    }

    private func benefitRow(icon: String, text: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Theme.Color.bhumitraSecondaryText)
                .frame(width: 34, height: 34)
                .background(Circle().fill(SheetChrome.controlFill))
                .accessibilityHidden(true)
            Text(text)
                .font(.googleSans(size: 15, weight: .regular))
                .foregroundColor(Theme.Color.bhumitraPrimaryText)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
    }

    // MARK: - Sign-in actions (pinned bottom)

    private var actions: some View {
        VStack(spacing: 10) {
            if let error = errorMessage {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(Theme.Color.bhumitraError)
                    Text(error)
                        .foregroundColor(Theme.Color.bhumitraPrimaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .font(.googleSans(size: 13, weight: .regular))
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 14).fill(Theme.Color.bhumitraErrorSurface))
                .padding(.bottom, 4)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            // Apple's guidelines: black (light) / white (dark) button, Apple
            // logo, "Continue with Apple" — `.contrast` gives exactly that.
            Button(action: startAppleSignIn) {
                if isLoading {
                    ProgressView()
                } else {
                    Label("Continue with Apple", systemImage: "applelogo")
                }
            }
            .buttonStyle(CTAButtonStyle(.contrast))
            .disabled(isBusy && !isLoading)
            .allowsHitTesting(!isBusy)

            Button(action: startGoogleSignIn) {
                if isGoogleLoading {
                    ProgressView()
                } else {
                    Label {
                        Text("Continue with Google")
                    } icon: {
                        GoogleLogoView(size: 18)
                    }
                }
            }
            .buttonStyle(CTAButtonStyle(.outline))
            .disabled(isBusy && !isGoogleLoading)
            .allowsHitTesting(!isBusy)

            if let onContinueAsGuest {
                Button("Continue without an account") {
                    authManager.sessionExpiredNotice = false
                    onContinueAsGuest()
                }
                    .font(.googleSans(size: 15, weight: .semibold))
                    .foregroundColor(Theme.Color.bhumitraPrimary)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .disabled(isBusy)
            }

            Text(legalText)
                .font(.googleSans(size: 12, weight: .regular))
                .foregroundColor(Theme.Color.bhumitraTertiaryText)
                .tint(Theme.Color.bhumitraSecondaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, 6)

            #if DEBUG
            Button("Debug sign-in") {
                authManager.signInTestUser()
                close()
            }
            .font(.googleSans(size: 12, weight: .medium))
            .foregroundColor(Theme.Color.bhumitraTertiaryText)
            .padding(.top, 2)
            #endif
        }
        .padding(.horizontal, SheetChrome.inset)
        .padding(.top, 12)
        .padding(.bottom, 12)
    }

    private var legalText: AttributedString {
        let markdown = "By continuing, you agree to the [Terms of Use](\(AppInfo.termsURL.absoluteString)) and [Privacy Policy](\(AppInfo.privacyPolicyURL.absoluteString))."
        var text = (try? AttributedString(markdown: markdown))
            ?? AttributedString("By continuing, you agree to the Terms of Use and Privacy Policy.")
        for run in text.runs where run.link != nil {
            text[run.range].underlineStyle = .single
        }
        return text
    }

    private func close() {
        authManager.sessionExpiredNotice = false
        if let onDismiss { onDismiss() } else { dismiss() }
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
                        close()
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
                                close()
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
