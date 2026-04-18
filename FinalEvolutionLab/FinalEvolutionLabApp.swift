import SwiftUI

@main
struct FinalEvolutionLabApp: App {
    init() {
        _ = RorkScoreManager.shared
        EmergentRealtimeClient.shared.startIfConfigured()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
