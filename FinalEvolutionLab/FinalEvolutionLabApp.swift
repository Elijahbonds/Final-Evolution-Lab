import SwiftUI

@main
struct FinalEvolutionLabApp: App {
    init() {
        FirebaseBootstrap.configureIfNeeded()
        _ = RorkScoreManager.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
