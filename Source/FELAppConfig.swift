import Foundation

/// Central configuration for secrets and service URLs. Resolution order (first non-empty wins):
/// 1. `ProcessInfo.processInfo.environment` — map these in the Xcode scheme, CI secrets, or host dashboard for TestFlight/CI.
/// 2. `Bundle.main` Info.plist keys (from `INFOPLIST_KEY_*` / generated plist).
///
/// Keys: `GEMINI_API_KEY`, `FEL_SUPABASE_URL`, `FEL_SUPABASE_ANON_KEY`, optional `FEL_SOVEREIGN_*`.
enum FELAppConfig {
    private static func stringEnv(_ key: String) -> String? {
        if let v = ProcessInfo.processInfo.environment[key]?.trimmingCharacters(in: .whitespacesAndNewlines), !v.isEmpty {
            return v
        }
        if let v = Bundle.main.object(forInfoDictionaryKey: key) as? String {
            let t = v.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? nil : t
        }
        return nil
    }

    static var geminiAPIKey: String? { stringEnv("GEMINI_API_KEY") }

    /// Alpha 1 / TestFlight: set to your **production** project `https://<ref>.supabase.co` (same host as Edge Functions + Stripe webhook). Via scheme env or `INFOPLIST_KEY_FEL_SUPABASE_URL` at archive time.
    static var felSupabaseURL: String? { stringEnv("FEL_SUPABASE_URL") }

    /// Public anon key from Supabase Dashboard → Settings → API (not the service_role key).
    static var felSupabaseAnonKey: String? { stringEnv("FEL_SUPABASE_ANON_KEY") }

    static var sovereignLeaderboardURL: String? { stringEnv("FEL_SOVEREIGN_LEADERBOARD_URL") }

    static var sovereignLeaderboardToken: String? { stringEnv("FEL_SOVEREIGN_LEADERBOARD_TOKEN") }
}
