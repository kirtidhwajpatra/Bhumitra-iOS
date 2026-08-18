import SwiftUI

public struct ForceUpdateView: View {
    @ObservedObject var remoteConfig = RemoteConfigManager.shared
    
    private var appStoreURL: URL {
        URL(string: remoteConfig.appStoreURL) ?? URL(string: "https://apps.apple.com/app/bhumitra-odisha-land-records/id6742337788")!
    }
    
    public init() {}
    
    public var body: some View {
        ZStack {
            // Premium Dark Modern Gradient Background
            LinearGradient(
                colors: [
                    Color(red: 14/255, green: 8/255, blue: 30/255),
                    Color(red: 26/255, green: 14/255, blue: 54/255)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 28) {
                Spacer()
                
                // App Logo / Update Badge Icon
                ZStack {
                    Circle()
                        .fill(Theme.neonPurple.opacity(0.15))
                        .frame(width: 120, height: 120)
                    
                    Circle()
                        .fill(Theme.neonPurple.opacity(0.25))
                        .frame(width: 96, height: 96)
                    
                    Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                        .font(.system(size: 52))
                        .foregroundColor(Theme.neonPurple)
                        .shadow(color: Theme.neonPurple.opacity(0.8), radius: 16)
                }
                
                // Typography Section
                VStack(spacing: 12) {
                    Text("Please Update Bhumitra")
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    Text("A critical update is required to continue using Bhumitra. Please update to the latest version on the App Store.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 36)
                }
                
                // Version Matrix Badge
                HStack(spacing: 20) {
                    VStack(spacing: 4) {
                        Text("YOUR VERSION")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white.opacity(0.4))
                        Text("v\(remoteConfig.currentAppVersion)")
                            .font(.system(size: 14, weight: .black, design: .monospaced))
                            .foregroundColor(.red.opacity(0.8))
                    }
                    
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white.opacity(0.3))
                    
                    VStack(spacing: 4) {
                        Text("REQUIRED VERSION")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white.opacity(0.4))
                        Text("v\(remoteConfig.minSupportedVersion)+")
                            .font(.system(size: 14, weight: .black, design: .monospaced))
                            .foregroundColor(Theme.neonGreen)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(Color.white.opacity(0.04))
                .cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 1))
                
                Spacer()
                
                // Action Buttons (Blocks app until updated)
                VStack(spacing: 14) {
                    Button(action: openAppStore) {
                        HStack(spacing: 10) {
                            Image(systemName: "arrow.down.app.fill")
                                .font(.system(size: 18))
                            Text("Update on App Store")
                                .font(.system(size: 16, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            LinearGradient(
                                colors: [Theme.neonPurple, Color(red: 140/255, green: 30/255, blue: 230/255)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(16)
                        .shadow(color: Theme.neonPurple.opacity(0.4), radius: 15, y: 5)
                    }
                    
                    Button(action: {
                        Task {
                            await remoteConfig.fetchRemoteConfig(force: true)
                        }
                    }) {
                        HStack(spacing: 6) {
                            if remoteConfig.isLoading {
                                ProgressView().tint(.white.opacity(0.6)).scaleEffect(0.8)
                            } else {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 12))
                            }
                            Text("Check Again")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.vertical, 8)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 36)
            }
        }
        .interactiveDismissDisabled(true)
    }
    
    private func openAppStore() {
        hapticFeedback(.medium)
        if UIApplication.shared.canOpenURL(appStoreURL) {
            UIApplication.shared.open(appStoreURL)
        }
    }
}
