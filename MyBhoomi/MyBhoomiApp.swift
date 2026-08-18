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
    @StateObject private var authManager = AuthManager.shared
    
    var body: some View {
        Group {
            if !authManager.isAuthenticated {
                LoginView()
            } else {
                MainView()
            }
        }
        .animation(.easeInOut(duration: 0.35), value: authManager.isAuthenticated)
    }
}
