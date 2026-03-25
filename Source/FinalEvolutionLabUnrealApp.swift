import SwiftUI

@main
struct FinalEvolutionLabUnrealApp: App {
    @UIApplicationDelegateAdaptor(FELAppDelegate.self) private var appDelegate

    /// Single app-owned reference to the Unreal overlay runtime so `environmentObject` is always satisfied (avoids missing-injection crashes).
    @StateObject private var unrealRuntime = UFELUnrealOverlayRuntime.shared

    init() {
        migrateLegacyGoldMasterFirstLaunchFlags()
        _ = PRQScoreManager.shared
        _ = UFELCreatorRevenueSubsystem.shared
        _ = UFELCreatorInviteService.shared
        Task { @MainActor in
#if !targetEnvironment(simulator)
            FELUnityNativeCallbacks.register()
            FELUnrealMediaBridge.shared.register()
            UnityManager.shared.preloadUnityAtLaunch()
            ControllerDiscoveryService.shared.startObserving()
#else
            ControllerDiscoveryService.shared.startObserving()
#endif
            if let key = FELAppConfig.geminiAPIKey {
                GeminiService.shared.configure(apiKey: key)
            }
        }
    }

    /// Existing installs: skip first-launch splash + forced scan if profile already has onboarding + System Scan.
    private func migrateLegacyGoldMasterFirstLaunchFlags() {
        let d = UserDefaults.standard
        let kSeen = "felHasSeenDeleteTheFearSplash"
        let kScan = "felHasCompletedFirstLaunchSystemScan"
        if d.object(forKey: kSeen) != nil { return }
        let p = SaveSystem.loadProfile()
        if p.hasCompletedOnboarding && p.systemScan != nil {
            d.set(true, forKey: kSeen)
            d.set(true, forKey: kScan)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(unrealRuntime)
        }
    }
}
