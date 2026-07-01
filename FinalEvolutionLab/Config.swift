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

    /// UserDefaults key: trusted gameplay session ID bound by NexusBridge after server verification.
    static let trustedGameplaySessionDefaultsKey = "fel_trusted_gameplay_session_id"

    /// Cached SQL `User.id` (UUID string) for Data Connect posts; set by ``TrainingLabSocialBridge``.
    static let sqlSocialUserIdKey = "fel_sql_social_user_id"

    /// Paired with ``sqlSocialUserIdKey`` — if `auth.uid` changes, cache is discarded.
    static let sqlSocialFirebaseUidKey = "fel_sql_social_firebase_uid"

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
}
