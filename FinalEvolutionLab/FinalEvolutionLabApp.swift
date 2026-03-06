import SwiftUI

@main
struct FinalEvolutionLabApp: App {
    init() {
        _ = RorkScoreManager.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
