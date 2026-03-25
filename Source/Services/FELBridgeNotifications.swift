import Foundation

// MARK: - Unreal Engine → Swift (NSNotification bridge; mirrors PRQNativeBridge direction inverted)

extension Notification.Name {
    /// Posted when `session_results.json` is written; `userInfo["sessionResultsPath"]` is the absolute path string.
    static let felUnrealSessionResultsReady = Notification.Name("FELUnrealSessionResultsReady")

    /// User chose Return to Dashboard on UFELMatchResultsWidget — host may dismiss embedded UE view.
    static let felUnrealExitToDashboard = Notification.Name("FELUnrealExitToDashboard")

    /// After System Scan + `readiness_snapshot.json` write — Unreal / embedded runtime can hot-reload readiness.
    static let felBioSyncComplete = Notification.Name("FelBioSyncComplete")

    /// Match Results "Share Your Evolution" — Swift host renders Athlete Card (PRQ + vertical estimate).
    static let felShareEvolutionFromUnreal = Notification.Name("FelShareEvolutionFromUnreal")

    /// Unreal → iOS haptics — `userInfo["kind"]` Int: 0 terminal, 1 academy module, 2 elite dunk, 3 match end, 4 Perfect dunk (legacy), 5 Perfect strike, 6 warp thud, 7 Sonic Flare apex.
    static let felUnrealUINotificationFeedback = Notification.Name("FelUnrealUINotificationFeedback")

    /// Unreal `GenerateAthletePerformanceJSON` — `userInfo["json"]` UTF-8 string (AI Coach + Share Performance).
    static let felCoachPerformanceSnapshot = Notification.Name("FelCoachPerformanceSnapshot")

    /// Unreal `UFELSaveGame::ExportSaveToJSON` — `userInfo["base64"]` XOR+Base64 blob (Universal Master sync).
    static let felUniversalSyncExport = Notification.Name("FelUniversalSyncExport")

    /// `UFELAvatarSnapshotSubsystem` — `userInfo["pngData"]` is PNG bytes (`Data`).
    static let felAvatarSnapshotPngReady = Notification.Name("FelAvatarSnapshotPngReady")

    /// Neuro-Flow Perfect Moment — `userInfo["mp4Path"]` is absolute path to `.mp4` (Swift saves to Photos).
    static let felNeuroFlowMp4ExportReady = Notification.Name("FelNeuroFlowMp4ExportReady")

    /// Unreal Luma Sovereign Shop hotspot — optional `userInfo["hotspotId"]`, `userInfo["lumaCaptureId"]`; presents shard marketplace.
    static let felUnrealShardMarketplaceRequest = Notification.Name("FelUnrealShardMarketplaceRequest")

    /// Unreal → Swift: `GameMode::BeginPlay` — `userInfo["mapName"]` NSString (cancels arena handshake watchdog).
    static let felUnrealLevelLoaded = Notification.Name("FELUnrealLevelLoaded")

    /// After `felUnrealLevelLoaded` + short settle delay — viewport placeholder may hide (approximate first scene render / `IsSceneRendered`).
    static let felUnrealViewportSceneRendered = Notification.Name("FELUnrealViewportSceneRendered")

    /// Swift → embedded UE host: `userInfo["command"]` e.g. `r.ScreenPercentage 75` (see `FELUnrealScalabilityBridge`).
    static let felUnrealConsoleCommandRequested = Notification.Name("felUnrealConsoleCommandRequested")

    /// Unreal `InputLatencyMonitor` → Swift: `userInfo["latencyMs"]` Double (press→`Jump()` ms). Post when sample taken.
    static let felInputLatencyJumpMsSample = Notification.Name("felInputLatencyJumpMsSample")

    /// Supabase Realtime `user_balances` update — wallet merged in `PRQManager.syncWallet`.
    static let felWalletBalanceDidUpdate = Notification.Name("FELWalletBalanceDidUpdate")

    /// Unreal Bonds Apex ≥40" demo replay (3s window) started — `userInfo["estimatedApexInches"]` Double; ReplayKit hero clip (Arena).
    static let felHeroMomentExportReady = Notification.Name("felHeroMomentExportReady")

    /// After `PRQManager.switchAthleteProfile` — Arena may pulse `setUnrealReady` for Unreal biometric reload.
    static let felUnrealReadinessHandshakeRequested = Notification.Name("felUnrealReadinessHandshakeRequested")

    /// SFMA fail → thoracic / spiral congestion + Unreal JSON (`SFMA_DiagnosticManager.unrealClinicalJSON`).
    static let felSFMAClinicalAnatomyHeatmap = Notification.Name("felSFMAClinicalAnatomyHeatmap")

    /// Fascial sling visualization (Spiral + Back Functional lines) — `userInfo["active"]` Bool.
    static let felFascialSlingToggle = Notification.Name("felFascialSlingToggle")

    /// Push 1,2 penultimate stride cue — `userInfo["phase"]` 0 = Push, 1 = beat 1, 2 = beat 2.
    static let felPenultimateStrideRhythm = Notification.Name("felPenultimateStrideRhythm")
}
