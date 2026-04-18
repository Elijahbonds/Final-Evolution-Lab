// Config.swift - Auto-generated at build time
// Environment variables from Project Settings are injected here
//
// Usage: Config.YOUR_ENV_NAME
// Example: If you set MY_API_KEY in Environment Variables,
//          use Config.MY_API_KEY in your code

import Foundation

enum Config {
    /// Runtime WebSocket URL for Emergent bridge (matches UE `EMERGENT_GAME_WS_URL` / DefaultGame.ini).
    static let emergentGameWebSocketDefaultsKey = "fel_emergent_game_ws_url"

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
