import Foundation

/// Sovereign Launch — direct-to-consumer shard ledger + Supabase wallet (`user_balances`).
/// After migration `20260324140000`, subscribe to Realtime on `user_balances` for instant dashboard refresh when Stripe credits shards.
/// Purchase API: `https://finalevolutiongroup.com/api/v1/shards` (POST). Wallet: Supabase REST `user_balances`.
nonisolated struct FELWalletSnapshot: Sendable {
    var shardBalance: Int
    var cloudCortexCredits: Int
    /// Optional server-driven gear paths keyed by slot (`jersey`, `shoes`).
    var equippedGearTexturePaths: [String: String]
}

enum FELSovereignShardEconomy {
    private static let purchaseURLString = "https://finalevolutiongroup.com/api/v1/shards"
    private static let userBalancesTable = "user_balances"

    // MARK: - Athlete ↔ auth link (RPC)

    /// Calls `fel_upsert_athlete_profile_link` with the user JWT (Stripe webhook resolves `athlete_id` via `athlete_profile_link`).
    static func upsertAthleteProfileLinkRPC(athleteId: String, accessToken: String) async -> Bool {
        guard let baseRaw = FELAppConfig.felSupabaseURL,
              let keyRaw = FELAppConfig.felSupabaseAnonKey,
              let root = URL(string: baseRaw.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return false
        }
        guard var comp = URLComponents(url: root, resolvingAgainstBaseURL: true) else { return false }
        let p = comp.path.hasSuffix("/") ? String(comp.path.dropLast()) : comp.path
        comp.path = (p.isEmpty ? "" : p) + "/rest/v1/rpc/fel_upsert_athlete_profile_link"
        guard let url = comp.url else { return false }
        let body: [String: Any] = ["p_athlete_id": athleteId]
        guard let httpBody = try? JSONSerialization.data(withJSONObject: body) else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(keyRaw, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = httpBody

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return false }
            return (200...299).contains(http.statusCode)
        } catch {
            return false
        }
    }

    // MARK: - Purchase → Sovereign API

    /// Posts a marketplace gear/outfit purchase to the Final Evolution LLC API before local ledger reconciliation.
    /// Fail-closed: returns `false` on network/5xx — caller must not deduct shards. `athleteId` must match `fel_upsert_athlete_profile_link` for Stripe metadata ↔ `auth.uid()` parity.
    static func postMarketplacePurchase(item: ShopItem, grossShards: Int, athleteId: String, displayName: String) async -> Bool {
        await postPurchase(
            kind: "marketplace",
            itemId: item.id,
            itemName: item.name,
            grossShards: grossShards,
            athleteId: athleteId,
            displayName: displayName,
            creatorMerchantID: item.creatorMerchantID
        )
    }

    static func postCreatorCardUnlock(card: CreatorCard, grossShards: Int, athleteId: String, displayName: String) async -> Bool {
        await postPurchase(
            kind: "creator_card",
            itemId: card.id,
            itemName: card.title,
            grossShards: grossShards,
            athleteId: athleteId,
            displayName: displayName,
            creatorMerchantID: card.felMerchantID
        )
    }

    private static func postPurchase(
        kind: String,
        itemId: String,
        itemName: String,
        grossShards: Int,
        athleteId: String,
        displayName: String,
        creatorMerchantID: String?
    ) async -> Bool {
        guard let url = URL(string: purchaseURLString) else { return false }
        var body: [String: Any] = [
            "kind": kind,
            "itemId": itemId,
            "itemName": itemName,
            "grossShards": grossShards,
            "athleteId": athleteId,
            "displayName": displayName,
        ]
        if let m = creatorMerchantID { body["creatorMerchantId"] = m }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let tok = FELAppConfig.sovereignLeaderboardToken, !tok.isEmpty {
            request.setValue("Bearer \(tok)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return false }
            return (200...299).contains(http.statusCode)
        } catch {
            return false
        }
    }

    // MARK: - Supabase wallet

    /// Reads `user_balances` for the signed-in Supabase user (RLS: `auth.uid()` = `user_id`).
    static func syncWallet(userId: UUID, accessToken: String) async -> FELWalletSnapshot? {
        guard let baseRaw = FELAppConfig.felSupabaseURL,
              let keyRaw = FELAppConfig.felSupabaseAnonKey,
              !baseRaw.isEmpty, !keyRaw.isEmpty,
              let root = URL(string: baseRaw.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return nil
        }
        guard var comp = URLComponents(url: root, resolvingAgainstBaseURL: true) else { return nil }
        let p = comp.path.hasSuffix("/") ? String(comp.path.dropLast()) : comp.path
        comp.path = (p.isEmpty ? "" : p) + "/rest/v1/\(userBalancesTable)"
        let uid = userId.uuidString.lowercased()
        comp.queryItems = [
            URLQueryItem(name: "select", value: "*"),
            URLQueryItem(name: "user_id", value: "eq.\(uid)"),
            URLQueryItem(name: "limit", value: "1"),
        ]

        guard let url = comp.url else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(keyRaw, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
                  !data.isEmpty else { return nil }
            return parseWalletRows(data)
        } catch {
            return nil
        }
    }

    private static func parseWalletRows(_ data: Data) -> FELWalletSnapshot? {
        guard let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let row = arr.first else { return nil }

        let shards = intValue(row, keys: ["shard_balance", "shards", "evolution_shards", "balance"])
        let cortex = intValue(row, keys: ["cortex_credits", "cloud_cortex_credits", "credits", "gemini_credits", "ai_credits"])
        var gear: [String: String] = [:]
        if let paths = row["equipped_gear_texture_paths"] as? [String: String] {
            gear = paths
        } else if let raw = row["sovereign_gear_json"] as? String,
                  let d = raw.data(using: .utf8),
                  let decoded = try? JSONSerialization.jsonObject(with: d) as? [String: String] {
            gear = decoded
        } else if let unlocked = row["unlocked_gear_json"] as? [String: Any] {
            for (k, v) in unlocked {
                if let s = v as? String { gear[k] = s }
            }
        }

        return FELWalletSnapshot(
            shardBalance: shards,
            cloudCortexCredits: cortex,
            equippedGearTexturePaths: gear
        )
    }

    private static func intValue(_ row: [String: Any], keys: [String]) -> Int {
        for k in keys {
            if let i = row[k] as? Int { return i }
            if let d = row[k] as? Double { return Int(d.rounded()) }
            if let s = row[k] as? String, let v = Int(s) { return v }
        }
        return 0
    }
}
