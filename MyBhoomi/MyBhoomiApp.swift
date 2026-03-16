import SwiftUI
import MapLibre

@main
struct MyBhoomiApp: App {
    
    // Initializing the application
    init() {
        print("MyBhoomi App Initialized")
        AdManager.shared.initialize()
    }
    
    var body: some Scene {
        WindowGroup {
            MainView()
        }
    }
}
