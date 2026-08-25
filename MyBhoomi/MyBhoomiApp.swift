import SwiftUI
import MapLibre

@main
struct MyBhoomiApp: App {
    
    // Initializing the application
    init() {
        GoogleSansFontLoader.registerFonts()
        print("MyBhoomi App Initialized with Google Sans Font Family")
        #if DEBUG
        _Concurrency.Task { @MainActor in
            let (passed, failed, _) = VerifiedParcelCacheTests.runAllTests()
            print("[VerifiedParcelCacheTests] Summary: \(passed) passed, \(failed) failed")
        }
        #endif
    }
    
    var body: some Scene {
        WindowGroup {
            RootContainerView()
        }
    }
}

struct RootContainerView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var remoteConfig = RemoteConfigManager.shared
    @State private var showRecommendedAlert: Bool = true
    
    var body: some View {
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
            } else {
                // 3. Normal Map Usage / Optional Soft Recommended Update Prompt
                MainView()
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
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                Task {
                    await remoteConfig.fetchRemoteConfig()
                }
            }
        }
    }
}

