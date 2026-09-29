import SwiftUI
import GoogleSignIn

@main
struct MyBhoomiApp: App {
    
    init() {
        // Creating the singleton configures Firebase once.
        _ = AnalyticsService.shared
        // Start the StoreKit Transaction.updates listener at launch, before any
        // view touches the manager (Ask to Buy approvals, renewals, refunds).
        _ = SubscriptionManager.shared
        // Fonts are registered by iOS from UIAppFonts (CustomInfo.plist);
        // registering them again at runtime only produced "already registered" errors.
        //
        // The in-app test suites used to run here on every Debug launch, on the
        // main thread, and one of them wiped the real offline parcel cache.
        // They run from the MyBhoomiTests target instead.
    }
    
    var body: some Scene {
        WindowGroup {
            RootContainerView()
                .onOpenURL { url in
                    _ = GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}

struct RootContainerView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var remoteConfig = RemoteConfigManager.shared
    @StateObject private var authManager = AuthManager.shared
    @ObservedObject private var appearanceManager = AppearanceManager.shared
    @State private var showRecommendedAlert: Bool = true
    @State private var isSplashFinished: Bool = false
    @AppStorage(OnboardingState.completedKey) private var onboardingCompleted: Bool = false
    @AppStorage(OnboardingState.guestChosenKey) private var guestModeChosen: Bool = false
    
    var body: some View {
        ZStack {
            Group {
                if remoteConfig.maintenanceMode {
                    // 1. Server Maintenance Mode Screen (BLOCK)
                    ZStack {
                        LinearGradient(
                            colors: [Color(red: 16/255, green: 10/255, blue: 34/255), Color(red: 25/255, green: 14/255, blue: 50/255)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .ignoresSafeArea()
                        
                        VStack(spacing: 16) {
                            Image(systemName: "wrench.and.screwdriver.fill")
                                .font(.system(size: 48))
                                .foregroundColor(Theme.neonPurple)
                            
                            Text("Under Maintenance")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            
                            Text(remoteConfig.maintenanceMessage ?? "Bhumitra services are currently undergoing scheduled maintenance. Please check back shortly.")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                            
                            Button("Refresh") {
                                Task {
                                    await remoteConfig.fetchRemoteConfig(force: true)
                                }
                            }
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Theme.neonPurple)
                            .cornerRadius(12)
                            .padding(.top, 12)
                        }
                    }
                } else if remoteConfig.isUpdateRequired {
                    // 2. Critical Minimum Version Not Met or Force Update Active (HARD BLOCK)
                    ZStack {
                        MainView()
                            .blur(radius: 6)
                            .allowsHitTesting(false)
                        
                        ForceUpdateView()
                    }
                } else if !onboardingCompleted && !authManager.isAuthenticated {
                    // 3. First-launch intro (shown once)
                    OnboardingView(onFinish: {
                        withAnimation(.easeInOut(duration: 0.3)) { onboardingCompleted = true }
                    })
                    .transition(.opacity)
                } else if !authManager.isAuthenticated && !guestModeChosen {
                    // 4. Launch sign-in. Signing in is optional (Guideline 5.1.1(v)):
                    //    "Not now" continues as a guest on the device session.
                    LoginView(triggerSource: "launch", onContinueAsGuest: {
                        withAnimation(.easeInOut(duration: 0.3)) { guestModeChosen = true }
                    })
                    .transition(.opacity)
                } else {
                    // 4. Authenticated Home Screen (MainView) / Optional Soft Recommended Update Prompt
                    MainView()
                        .transition(.opacity)
                        .alert(
                            "New Version Available",
                            isPresented: Binding(
                                get: { remoteConfig.isRecommendedUpdateAvailable && showRecommendedAlert },
                                set: { showRecommendedAlert = $0 }
                            )
                        ) {
                            Button("Update Now") {
                                if let url = URL(string: remoteConfig.appStoreURL) {
                                    UIApplication.shared.open(url)
                                }
                            }
                            Button("Later", role: .cancel) {
                                showRecommendedAlert = false
                            }
                        } message: {
                            Text("A newer version (v\(remoteConfig.recommendedVersion)) of Bhumitra is available with performance and cadastral map improvements.")
                        }
                }
            }
            
            // 5. Bhumitra Launch Splash Screen
            if !isSplashFinished {
                SplashScreenView(isFinished: $isSplashFinished)
                    .transition(.opacity)
                    .zIndex(100)
            }
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                Task {
                    await remoteConfig.fetchRemoteConfig(force: true)
                }
            }
        }
        .preferredColorScheme(appearanceManager.colorScheme)
    }
}

