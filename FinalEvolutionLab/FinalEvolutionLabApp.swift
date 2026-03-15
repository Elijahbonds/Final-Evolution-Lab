import SwiftUI

@main
struct FinalEvolutionLabApp: App {
    init() {
        _ = PRQScoreManager.shared
        Task { @MainActor in
            ControllerDiscoveryService.shared.startObserving()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
