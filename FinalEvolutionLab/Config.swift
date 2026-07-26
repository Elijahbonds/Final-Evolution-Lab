// Config.swift - Auto-generated at build time
// Environment variables from Project Settings are injected here
//
// Usage: Config.YOUR_ENV_NAME
// Example: If you set MY_API_KEY in Environment Variables,
//          use Config.MY_API_KEY in your code

import Foundation

enum AppRuntimeEnvironment: String, Sendable {
    case development
    case staging
    case testFlight
    case production
}

enum Config {
    /// Runtime WebSocket URL for Emergent bridge (matches UE `FEL_GAME_WS_URL` / DefaultGame.ini).
    static let emergentGameWebSocketDefaultsKey = "fel_emergent_game_ws_url"

    /// UserDefaults key: route Firestore (and optional other Firebase clients) to local emulators.
    static let useFirebaseEmulatorsDefaultsKey = "fel_use_firebase_emulators"

    /// Retro console library shell (OpenEmu-style Modes tab + in-game cartridge switch).
    static let emulatorShellDefaultsKey = "fel_emulator_shell_enabled"

    /// Subtle CRT scanline overlay on emulator surfaces.
    static let crtScanlineDefaultsKey = "fel_crt_scanline_enabled"

    /// Set `FEL_APP_ENV=staging` in scheme environment, or switch in Settings later.
    static var appRuntimeEnvironment: AppRuntimeEnvironment {
        if let raw = ProcessInfo.processInfo.environment["FEL_APP_ENV"]?.lowercased() {
            if raw == "staging" { return .staging }
            if raw == "production" || raw == "prod" { return .production }
        }
        #if DEBUG
        return .development
        #else
        if Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt" {
            return .testFlight
        }
        return .production
        #endif
    }

    /// `true` when using local Firebase emulators (Firestore on 8085 per repo `firebase.json`).
    static var useFirebaseEmulators: Bool {
        if ProcessInfo.processInfo.environment["FEL_USE_FIREBASE_EMULATORS"] == "1" { return true }
        return UserDefaults.standard.bool(forKey: useFirebaseEmulatorsDefaultsKey)
    }

    static var firestoreEmulatorHost: String {
        ProcessInfo.processInfo.environment["FEL_FIRESTORE_EMULATOR_HOST"] ?? "127.0.0.1:8085"
    }

    /// Data Connect emulator (see Firebase docs); wire after adding `FirebaseDataConnect` + generated connector.
    static var dataConnectEmulatorHost: String {
        ProcessInfo.processInfo.environment["FEL_DATACONNECT_EMULATOR_HOST"] ?? "127.0.0.1"
    }

    static var dataConnectEmulatorPort: Int {
        if let p = ProcessInfo.processInfo.environment["FEL_DATACONNECT_EMULATOR_PORT"], let n = Int(p) { return n }
        return 9399
    }

    static var authEmulatorHost: String {
        ProcessInfo.processInfo.environment["FEL_AUTH_EMULATOR_HOST"] ?? "127.0.0.1"
    }

    static var authEmulatorPort: Int {
        if let p = ProcessInfo.processInfo.environment["FEL_AUTH_EMULATOR_PORT"], let n = Int(p) { return n }
        return 9099
    }

    /// UserDefaults key: trusted gameplay session ID bound by NexusBridge after server verification.
    static let trustedGameplaySessionDefaultsKey = "fel_trusted_gameplay_session_id"

    /// Cached SQL `User.id` (UUID string) for Data Connect posts; set by ``TrainingLabSocialBridge``.
    static let sqlSocialUserIdKey = "fel_sql_social_user_id"

    /// Paired with ``sqlSocialUserIdKey`` — if `auth.uid` changes, cache is discarded.
    static let sqlSocialFirebaseUidKey = "fel_sql_social_firebase_uid"

    /// FastAPI base (`docs/NEXUS_BACKEND_CONTRACT.md`). Override: `FEL_API_BASE_URL`.
    static var felBackendApiBaseURL: String { NexusBackendClient.apiBaseURL }

    /// Production session receipt endpoint (matches C++ ``SessionReceiptClient`` / ``FEL_SESSION_RECEIPT_URL``).
    static var gameplaySessionReceiptURL: String { NexusBackendClient.sessionReceiptURL }

    /// Public mobile bootstrap (`GET /api/mobile/config`).
    static var mobileConfigURL: String { NexusBackendClient.mobileConfigURL }

    #if DEBUG
    /// POST native Swift session results to ``gameplaySessionReceiptURL`` and ingest via ``GameplaySessionReceiptCoordinator`` when auth succeeds.
    static var submitNativeGameplayReceiptsInDebug: Bool {
        if ProcessInfo.processInfo.environment["FEL_SKIP_SESSION_RECEIPT"] == "1" { return false }
        return true
    }
    #endif

    /// Non-empty URL from process environment `FEL_GAME_WS_URL`, then UserDefaults ``emergentGameWebSocketDefaultsKey``.
    static func resolvedEmergentGameWebSocketURL() -> String? {
        if let env = ProcessInfo.processInfo.environment["FEL_GAME_WS_URL"],
           !env.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return env
        }
        let ud = UserDefaults.standard.string(forKey: emergentGameWebSocketDefaultsKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (ud?.isEmpty == false) ? ud : nil
    }

    /// HUD frame relay WebSocket (spec §7.3). Env `FEL_HUD_WS_URL`, default nil (log-only stub).
    static func resolvedHUDWebSocketURL() -> String? {
        if let env = ProcessInfo.processInfo.environment["FEL_HUD_WS_URL"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !env.isEmpty {
            return env
        }
        return nil
    }

    // MARK: - Shipping gameplay / meta flags (GAME-26, GAME-32)

    /// When `true`, global leaderboard + matchmaking pool use ``SampleData`` and simulated stats. **Ship with `false`** unless intentionally demoing.
    static var useDemoLeaderboardAndMatchmaking: Bool {
        if ProcessInfo.processInfo.environment["FEL_DEMO_LEADERBOARDS"] == "1" { return true }
        if ProcessInfo.processInfo.environment["FEL_DEMO_LEADERBOARDS"] == "0" { return false }
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    /// UI automation (`-UITestMode`, screenshot harness) — stable shell + skip lobby overlays.
    static var isUITestMode: Bool {
        let args = ProcessInfo.processInfo.arguments
        return args.contains("-UITestMode") || args.contains("-ScreenshotHarness")
    }

    /// OpenEmu-style cartridge library for Arena Modes + quick-switch drawer during gameplay.
    static var useEmulatorShell: Bool {
        if isUITestMode { return true }
        if ProcessInfo.processInfo.environment["FEL_EMULATOR_SHELL"] == "1" { return true }
        if ProcessInfo.processInfo.environment["FEL_EMULATOR_SHELL"] == "0" { return false }
        if UserDefaults.standard.object(forKey: emulatorShellDefaultsKey) != nil {
            return UserDefaults.standard.bool(forKey: emulatorShellDefaultsKey)
        }
        return true
    }

    /// NEXUS 3D engine — Metal venue + SceneKit player rig + third-person chase camera during match.
    /// Emulator shell enables by default; override with `NEXUS_3D_GAMEPLAY=0` to force 2D/legacy viewport.
    static var useNexus3DGameplay: Bool {
        if isUITestMode { return true }
        if ProcessInfo.processInfo.environment["NEXUS_3D_GAMEPLAY"] == "1" { return true }
        if ProcessInfo.processInfo.environment["NEXUS_3D_GAMEPLAY"] == "0" { return false }
        return useEmulatorShell
    }

    /// Includes ``GameModeReleaseState.preview`` modes in Arena navigation (DEBUG on; release off unless `FEL_PREVIEW_GAME_MODES=1`).
    static var showPreviewGameModes: Bool {
        if ProcessInfo.processInfo.environment["FEL_PREVIEW_GAME_MODES"] == "1" { return true }
        if ProcessInfo.processInfo.environment["FEL_PREVIEW_GAME_MODES"] == "0" { return false }
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    // MARK: - AI Studio (Gemini REST — no Firebase required)

    /// Primary env var for Google AI Studio API key. Also see ``NexusAIStudioBootstrap``.
    static var nexusAIStudioAPIKeyEnvNames: [String] {
        ["NEXUS_AI_STUDIO_API_KEY", "NEXUS_AGENT_GEMINI_KEY", "GEMINI_API_KEY", "FEL_LLM_KEY"]
    }

    /// Resolved model (`NEXUS_AI_STUDIO_MODEL` → `NEXUS_AGENT_GEMINI_MODEL` → `gemini-2.0-flash`).
    static var nexusAiStudioModel: String { NexusAIStudioBootstrap.resolvedModel }

    /// `true` when AI Studio key is configured (scheme env or Keychain).
    static var hasNexusAiStudioKey: Bool { NexusAIStudioBootstrap.isConfigured }
}
