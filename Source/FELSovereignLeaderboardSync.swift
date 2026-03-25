import Foundation

/// Pushes `allTimePeakZ` + `displayName` to a public Sovereign leaderboard.
/// **Shard purchases** are routed through `https://finalevolutiongroup.com/api/v1/shards` via `FELSovereignShardEconomy` (see `FELCreatorRevenueQueue` + `PRQManager.syncWallet`).
/// **Supabase:** migration `20260327120000_sovereign_peak_leaderboard.sql` — columns `athlete_id` (text PK), `display_name`, `all_time_peak_z`, `user_id` (auth.users, RLS). REST upsert `on_conflict=athlete_id`.
/// **Webhook:** alternatively set `FEL_SOVEREIGN_LEADERBOARD_URL` (POST JSON body). Optional `FEL_SOVEREIGN_LEADERBOARD_TOKEN` for Bearer auth. Response may include `rank`, `world_rank`, or `global_rank`.
enum FELSovereignLeaderboardSync {
    /// Wallet sync — delegates to `FELSovereignShardEconomy.syncWallet` (`user_balances` table).
    static func syncWallet(athleteId: String) async -> FELWalletSnapshot? {
        _ = athleteId
        guard let state = await FELSupabaseWalletSync.shared.authState() else { return nil }
        return await FELSovereignShardEconomy.syncWallet(userId: state.userId, accessToken: state.accessToken)
    }
    private static let sovereignTable = "sovereign_peak_leaderboard"

    /// Returns world rank when the backend includes it in the response body.
    static func push(displayName: String, allTimePeakZ: Double, athleteId: String) async -> Int? {
        let supUrl = FELAppConfig.felSupabaseURL ?? ""
        let supKey = FELAppConfig.felSupabaseAnonKey ?? ""
        if !supUrl.isEmpty, !supKey.isEmpty {
            return await pushSupabaseREST(displayName: displayName, allTimePeakZ: allTimePeakZ, athleteId: athleteId)
        }
        return await pushWebhook(displayName: displayName, allTimePeakZ: allTimePeakZ, athleteId: athleteId)
    }

    private static func pushWebhook(displayName: String, allTimePeakZ: Double, athleteId: String) async -> Int? {
        guard let s = FELAppConfig.sovereignLeaderboardURL,
              let url = URL(string: s.trimmingCharacters(in: .whitespacesAndNewlines)),
              !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let tok = FELAppConfig.sovereignLeaderboardToken, !tok.isEmpty {
            request.setValue("Bearer \(tok)", forHTTPHeaderField: "Authorization")
        }
        let body: [String: Any] = [
            "displayName": displayName,
            "allTimePeakZ": allTimePeakZ,
            "athleteId": athleteId,
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return nil }
            return parseRank(from: data)
        } catch {
            return nil
        }
    }

    private static func pushSupabaseREST(displayName: String, allTimePeakZ: Double, athleteId: String) async -> Int? {
        guard let baseRaw = FELAppConfig.felSupabaseURL,
              let keyRaw = FELAppConfig.felSupabaseAnonKey,
              !baseRaw.isEmpty, !keyRaw.isEmpty,
              let root = URL(string: baseRaw.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return nil
        }
        guard let state = await FELSupabaseWalletSync.shared.authState() else { return nil }
        let uid = state.userId.uuidString.lowercased()
        guard var comp = URLComponents(url: root, resolvingAgainstBaseURL: true) else { return nil }
        let p = comp.path.hasSuffix("/") ? String(comp.path.dropLast()) : comp.path
        comp.path = (p.isEmpty ? "" : p) + "/rest/v1/\(sovereignTable)"
        comp.queryItems = [URLQueryItem(name: "on_conflict", value: "athlete_id")]
        guard let url = comp.url else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(keyRaw, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(state.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")

        let row: [String: Any] = [
            "athlete_id": athleteId,
            "display_name": displayName,
            "all_time_peak_z": allTimePeakZ,
            "user_id": uid,
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: row)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return nil }
            if let rank = parseRank(from: data) { return rank }
            // Minimal success without rank in body — caller can still show sync OK via optional future RPC.
            return nil
        } catch {
            return nil
        }
    }

    private static func parseRank(from data: Data) -> Int? {
        guard !data.isEmpty, let obj = try? JSONSerialization.jsonObject(with: data) else { return nil }
        if let d = obj as? [String: Any] {
            if let r = d["rank"] as? Int { return r }
            if let r = d["world_rank"] as? Int { return r }
            if let r = d["global_rank"] as? Int { return r }
        }
        if let arr = obj as? [[String: Any]], let first = arr.first {
            if let r = first["rank"] as? Int { return r }
            if let r = first["world_rank"] as? Int { return r }
        }
        return nil
    }
}
