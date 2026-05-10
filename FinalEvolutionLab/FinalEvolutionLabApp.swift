import SwiftUI

@main
struct FinalEvolutionLabApp: App {
    init() {
        FirebaseBootstrap.configureIfNeeded()
        Task { @MainActor in
            TrainingLabSocialBridge.shared.configureConnectorIfNeeded()
            UnrealManager.shared.startFirebaseIdentityObservation()
        }
        _ = RorkScoreManager.shared
        EmergentRealtimeClient.shared.startIfConfigured()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
