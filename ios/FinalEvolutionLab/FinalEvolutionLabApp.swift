import SwiftUI

@main
struct FinalEvolutionLabApp: App {
    init() {
        FELArenaDiagnosticsPreference.seedDefaultsIfNeeded()
        FirebaseBootstrap.configureIfNeeded()
        _ = RorkScoreManager.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    _ = FELArenaRuntimePreference.applyIfHandled(url: url)
                }
        }
    }
}
