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
    /// Runtime WebSocket URL for Emergent bridge (matches UE `EMERGENT_GAME_WS_URL` / DefaultGame.ini).
    static let emergentGameWebSocketDefaultsKey = "fel_emergent_game_ws_url"

    /// UserDefaults key: route Firestore (and optional other Firebase clients) to local emulators.
    static let useFirebaseEmulatorsDefaultsKey = "fel_use_firebase_emulators"

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

    /// Cached SQL `User.id` (UUID string) for Data Connect posts; set by ``TrainingLabSocialBridge``.
    static let sqlSocialUserIdKey = "fel_sql_social_user_id"

    /// Paired with ``sqlSocialUserIdKey`` — if `auth.uid` changes, cache is discarded.
    static let sqlSocialFirebaseUidKey = "fel_sql_social_firebase_uid"

    /// UE / server sets this to the active verified gameplay session id; inbound Emergent WS payloads must repeat it to mutate PRQ or surface ``fel_game_result``.
    static let trustedGameplaySessionDefaultsKey = "fel_trusted_ue_gameplay_session_id"

    /// Non-empty URL from process environment `EMERGENT_GAME_WS_URL`, then UserDefaults ``emergentGameWebSocketDefaultsKey``.
    static func resolvedEmergentGameWebSocketURL() -> String? {
        if let env = ProcessInfo.processInfo.environment["EMERGENT_GAME_WS_URL"],
           !env.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return env
        }
        let ud = UserDefaults.standard.string(forKey: emergentGameWebSocketDefaultsKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (ud?.isEmpty == false) ? ud : nil
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
}
