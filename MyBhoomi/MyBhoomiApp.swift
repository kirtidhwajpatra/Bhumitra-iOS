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
            MainView()
        }
    }
}
