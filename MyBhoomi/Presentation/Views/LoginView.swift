import SwiftUI

struct LoginView: View {
    @StateObject private var authManager = AuthManager.shared
    
    // Auth Steps
    enum Step {
        case enterMobile
        case enterOTP
        case enterName
    }
    
    @State private var currentStep: Step = .enterMobile
    
    // Form Inputs
    @State private var mobileNumber = ""
    @State private var otpCode = ""
    @State private var fullName = ""
    
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var successMessage: String? = nil
    
    var body: some View {
        ZStack {
            // Elegant background gradient
            LinearGradient(
                colors: [Theme.primary.opacity(0.04), Color.white],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 32) {
                    // Header Logo & Branding
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Theme.primary.opacity(0.1))
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: "map.fill")
                                .font(.system(size: 36, weight: .bold))
                                .foregroundColor(Theme.primary)
                        }
                        .padding(.top, 60)
                        
                        Text("Bhumitra")
                            .font(.system(size: 32, weight: .black, design: .rounded))
                            .foregroundColor(.black)
                        
                        Text(subtitleText)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    
                    // Card Container
                    VStack(spacing: 24) {
                        switch currentStep {
                        case .enterMobile:
                            enterMobileView
                        case .enterOTP:
                            enterOTPView
                        case .enterName:
                            enterNameView
                        }
                    }
                    .padding(24)
                    .background(Color.white.opacity(0.6))
                    .cornerRadius(24)
                    .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white, lineWidth: 2))
                    .shadow(color: .black.opacity(0.03), radius: 20, x: 0, y: 10)
                    .padding(.horizontal, 20)
                    
                    // Error message
                    if let error = errorMessage {
                        Text(error)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                            .transition(.opacity)
                    }
                    
                    // Success message
                    if let success = successMessage {
                        Text(success)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.green)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                            .transition(.opacity)
                    }
                    
                    Spacer(minLength: 40)
                }
            }
        }
    }
    
    private var subtitleText: String {
        switch currentStep {
        case .enterMobile:
            return "Land Records & GIS mapping made simple"
        case .enterOTP:
            return "Verify your phone number to continue"
        case .enterName:
            return "Just a few more details to set up your profile"
        }
    }
    
    // Step 1: Mobile View
    private var enterMobileView: some View {
        VStack(spacing: 20) {
            InputField(
                label: "Mobile Number",
                text: $mobileNumber,
                placeholder: "Enter 10-digit mobile number",
                icon: "phone.fill"
            )
            .keyboardType(.phonePad)
            
            Button(action: handleSendOTP) {
                HStack {
                    if isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text("Send OTP Verification")
                            .font(.system(size: 16, weight: .bold))
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Theme.brandGradient)
                .cornerRadius(16)
                .shadow(color: Theme.primary.opacity(0.3), radius: 12, y: 6)
            }
            .disabled(isLoading)
        }
    }
    
    // Step 2: OTP View
    private var enterOTPView: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Verification Code".uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                    .padding(.leading, 4)
                
                InputField(
                    label: "",
                    text: $otpCode,
                    placeholder: "Enter 6-digit OTP",
                    icon: "lock.shield.fill"
                )
                .keyboardType(.numberPad)
                
                Text("Verification code sent to +91 \(mobileNumber). For testing, use OTP: 123456")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.leading, 4)
                    .padding(.top, 4)
            }
            
            Button(action: handleVerifyOTP) {
                HStack {
                    if isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text("Verify & Continue")
                            .font(.system(size: 16, weight: .bold))
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Theme.brandGradient)
                .cornerRadius(16)
                .shadow(color: Theme.primary.opacity(0.3), radius: 12, y: 6)
            }
            .disabled(isLoading)
            
            Button(action: {
                errorMessage = nil
                successMessage = nil
                otpCode = ""
                withAnimation { currentStep = .enterMobile }
            }) {
                Text("Change Mobile Number")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Theme.primary)
            }
        }
    }
    
    // Step 3: Name View (For New Users)
    private var enterNameView: some View {
        VStack(spacing: 20) {
            InputField(
                label: "Full Name",
                text: $fullName,
                placeholder: "Enter your full name",
                icon: "person.fill"
            )
            .autocapitalization(.words)
            
            Button(action: handleCompleteSignUp) {
                HStack {
                    if isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text("Complete Sign Up")
                            .font(.system(size: 16, weight: .bold))
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Theme.brandGradient)
                .cornerRadius(16)
                .shadow(color: Theme.primary.opacity(0.3), radius: 12, y: 6)
            }
            .disabled(isLoading)
        }
    }
    
    // Actions
    private func handleSendOTP() {
        hapticFeedback(.medium)
        errorMessage = nil
        successMessage = nil
        
        guard mobileNumber.count == 10, CharacterSet.decimalDigits.isSuperset(of: CharacterSet(charactersIn: mobileNumber)) else {
            errorMessage = "Please enter a valid 10-digit mobile number."
            return
        }
        
        isLoading = true
        
        Task {
            // Simulated network delay
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            
            await MainActor.run {
                isLoading = false
                successMessage = "OTP Code sent to +91 \(mobileNumber) successfully!"
                withAnimation { currentStep = .enterOTP }
            }
        }
    }
    
    private func handleVerifyOTP() {
        hapticFeedback(.medium)
        errorMessage = nil
        successMessage = nil
        
        guard otpCode == "123456" else {
            errorMessage = "Invalid verification code. Please enter 123456."
            return
        }
        
        isLoading = true
        
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            
            let isRegistered = authManager.isMobileRegistered(mobileNumber)
            
            await MainActor.run {
                isLoading = false
                if isRegistered {
                    // Log in existing user
                    Task {
                        let result = await authManager.loginWithMobile(mobileNumber)
                        switch result {
                        case .success:
                            successMessage = "Welcome back!"
                        case .failure(let error):
                            errorMessage = error.localizedDescription
                        }
                    }
                } else {
                    // Move to register name step
                    withAnimation { currentStep = .enterName }
                }
            }
        }
    }
    
    private func handleCompleteSignUp() {
        hapticFeedback(.medium)
        errorMessage = nil
        successMessage = nil
        
        guard !fullName.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Please enter your name to complete sign up."
            return
        }
        
        isLoading = true
        
        Task {
            let result = await authManager.registerWithMobile(name: fullName, mobile: mobileNumber)
            await MainActor.run {
                isLoading = false
                switch result {
                case .success:
                    successMessage = "Registration successful!"
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
