import SwiftUI
import AuthenticationServices

public struct LoginView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var authManager = AuthManager.shared
    
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var showPhoneSetup = false
    @State private var phoneNumber = ""
    
    var onDismiss: (() -> Void)? = nil
    
    public init(onDismiss: (() -> Void)? = nil) {
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        ZStack {
            // Elegant subtle background gradient
            LinearGradient(
                colors: [Theme.primary.opacity(0.04), Color(red: 248/255, green: 249/255, blue: 252/255)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header Dismiss Button (if presented modally)
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
                            .font(.system(size: 28))
                            .foregroundColor(Color.black.opacity(0.2))
                    }
                    .padding(.trailing, 20)
                    .padding(.top, 16)
                }
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 32) {
                        // Branding Section
                        VStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(Theme.primary.opacity(0.12))
                                    .frame(width: 88, height: 88)
                                
                                Image(systemName: "map.fill")
                                    .font(.system(size: 38, weight: .bold))
                                    .foregroundColor(Theme.primary)
                            }
                            .padding(.top, 20)
                            
                            Text("Bhumitra")
                                .font(.system(size: 32, weight: .black, design: .rounded))
                                .foregroundColor(.black)
                            
                            Text("Secure, verified cadastral land mapping and official ownership records")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 36)
                        }
                        
                        if showPhoneSetup {
                            phoneSetupCard
                        } else {
                            signInCard
                        }
                        
                        // Error message
                        if let error = errorMessage {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                Text(error)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.red)
                            }
                            .padding(.horizontal, 24)
                            .multilineTextAlignment(.center)
                            .transition(.opacity)
                        }
                        
                        Spacer(minLength: 30)
                    }
                }
            }
        }
    }
    
    // MARK: - Sign In Card
    
    private var signInCard: some View {
        VStack(spacing: 20) {
            VStack(spacing: 12) {
                // Native Sign in with Apple Button
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
                .frame(height: 54)
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.12), radius: 10, y: 5)
            }
            
            // Privacy footnote
            HStack(spacing: 6) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Text("Your Apple ID identity is securely encrypted on-device.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 4)
        }
        .padding(24)
        .background(Color.white)
        .cornerRadius(24)
        .shadow(color: .black.opacity(0.04), radius: 16, y: 8)
        .padding(.horizontal, 20)
    }
    
    // MARK: - Optional Phone Setup Card
    
    private var phoneSetupCard: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("OPTIONAL DETAILS")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                    .tracking(1)
                
                Text("Add Phone Number")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                
                Text("Link a mobile number to receive instant SMS updates for property alerts.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            InputField(
                label: "Mobile Number",
                text: $phoneNumber,
                placeholder: "10-digit mobile number",
                icon: "phone.fill"
            )
            .keyboardType(.phonePad)
            
            VStack(spacing: 12) {
                Button(action: handleSavePhone) {
                    Text("Save & Continue")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Theme.brandGradient)
                        .cornerRadius(14)
                }
                .buttonStyle(ScaledButtonStyle())
                
                Button(action: {
                    hapticFeedback(.light)
                    if let onDismiss = onDismiss {
                        onDismiss()
                    } else {
                        dismiss()
                    }
                }) {
                    Text("Skip for Now")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(24)
        .background(Color.white)
        .cornerRadius(24)
        .shadow(color: .black.opacity(0.04), radius: 16, y: 8)
        .padding(.horizontal, 20)
    }
    
    // MARK: - Actions
    
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
                    case .success(let user):
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        // If user doesn't have a phone number, prompt optionally
                        if user.mobile == nil || user.mobile?.isEmpty == true {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                showPhoneSetup = true
                            }
                        } else {
                            if let onDismiss = onDismiss {
                                onDismiss()
                            } else {
                                dismiss()
                            }
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
    
    private func handleSavePhone() {
        hapticFeedback(.medium)
        let trimmed = phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            guard trimmed.count == 10, CharacterSet.decimalDigits.isSuperset(of: CharacterSet(charactersIn: trimmed)) else {
                errorMessage = "Please enter a valid 10-digit mobile number."
                return
            }
            authManager.updatePhoneNumber(trimmed)
        }
        
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        if let onDismiss = onDismiss {
            onDismiss()
        } else {
            dismiss()
        }
    }
}
