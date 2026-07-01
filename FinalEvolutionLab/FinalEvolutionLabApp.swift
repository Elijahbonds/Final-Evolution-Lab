import SwiftUI

@main
struct FinalEvolutionLabApp: App {
    /// `-ScreenshotHarness` — PR/docs only (DEBUG). Skips the tab shell and opens ``GameModeScreenshotHarnessView``.
    /// Normal Run from Xcode must **not** pass this argument; shipping launch always uses ``ContentView``.
    private var screenshotHarness: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-ScreenshotHarness")
        #else
        false
        #endif
    }

    init() {
        FELPerformanceMonitor.shared.start()
        NexusAIStudioBootstrap.configureIfNeeded()
        FirebaseBootstrap.configureIfNeeded()
        Task { @MainActor in
            TrainingLabSocialBridge.shared.configureConnectorIfNeeded()
        }
        _ = FELScoreManager.shared
        EmergentRealtimeClient.shared.startIfConfigured()
        Task {
            _ = await NexusBackendClient.fetchMobileConfig()
        }
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
