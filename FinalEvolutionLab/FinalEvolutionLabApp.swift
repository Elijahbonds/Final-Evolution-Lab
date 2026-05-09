import SwiftUI

@main
struct FinalEvolutionLabApp: App {
    init() {
        FirebaseBootstrap.configureIfNeeded()
        _ = RorkScoreManager.shared
        EmergentRealtimeClient.shared.startIfConfigured()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
