import SwiftUI
import MapLibre

@main
struct MyBhoomiApp: App {
    
    // Initializing the application
    init() {
        print("MyBhoomi App Initialized")
    }
    
    var body: some Scene {
        WindowGroup {
            RootContainerView()
        }
    }
}

struct RootContainerView: View {
    @StateObject private var remoteConfig = RemoteConfigManager.shared
    
    var body: some View {
        Group {
            if remoteConfig.maintenanceMode {
                // Server Maintenance Mode Screen
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
                                await remoteConfig.fetchRemoteConfig()
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
            } else {
                MainView()
                    .alert("Update Required", isPresented: .constant(remoteConfig.isUpdateRequired)) {
                        Button("Update Now") {
                            if let url = URL(string: "https://apps.apple.com/app/id6740000000") {
                                UIApplication.shared.open(url)
                            }
                        }
                    } message: {
                        Text("A new version of Bhumitra is required to continue. Please update from the App Store.")
                    }
            }
        }
    }
}

