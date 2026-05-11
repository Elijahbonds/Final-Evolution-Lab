import SwiftUI

@main
struct FinalEvolutionLabApp: App {
    /// `-ScreenshotHarness` — Arena grid + per-mode gameplay chrome for PR screenshots (see ``GameModeScreenshotHarnessView``).
    private let screenshotHarness: Bool = ProcessInfo.processInfo.arguments.contains("-ScreenshotHarness")

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
            if screenshotHarness {
                GameModeScreenshotHarnessView()
            } else {
                ContentView()
            }
        }
    }
}
