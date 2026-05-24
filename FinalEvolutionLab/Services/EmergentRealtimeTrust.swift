import Foundation

/// Gates WebSocket-driven gameplay mutations so spoofed JSON cannot rewrite PRQ without a matched trusted session id (set by UE bridge or server after verification).
enum EmergentRealtimeTrust {
    static func bindTrustedGameplaySession(id: String) {
        UserDefaults.standard.set(id, forKey: Config.trustedGameplaySessionDefaultsKey)
    }

    static func clearTrustedGameplaySession() {
        UserDefaults.standard.removeObject(forKey: Config.trustedGameplaySessionDefaultsKey)
    }

    static func extractSessionId(from obj: [String: Any]) -> String? {
        let keys = ["game_session_id", "ue_session_id", "session_id", "fel_session_id", "gameSessionId"]
        for k in keys {
            if let s = obj[k] as? String, !s.isEmpty { return s }
        }
        return nil
    }

    /// Returns true when inbound payloads may affect PRQ, share drafts, or other progression-adjacent side effects.
    static func canApplyInboundGameplayMutation(from obj: [String: Any]) -> Bool {
#if DEBUG
        if ProcessInfo.processInfo.environment["FEL_ALLOW_UNVERIFIED_EMERGENT"] == "1" {
            return true
        }
#endif
        guard let sid = extractSessionId(from: obj), !sid.isEmpty else { return false }
        let trusted = UserDefaults.standard.string(forKey: Config.trustedGameplaySessionDefaultsKey)
        return trusted == sid
    }
}
