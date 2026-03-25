import Foundation
import Supabase

/// Supabase Auth session + Realtime `user_balances` so Stripe-credited shards appear instantly in the Lab shell.
/// Alpha 1: `subscribeWithError` on `public.user_balances` — ensure `FEL_SUPABASE_URL` points at production (same project as `stripe-webhook-handler`).
@MainActor
final class FELSupabaseWalletSync {
    static let shared = FELSupabaseWalletSync()

    private var client: SupabaseClient?
    private var realtimeChannel: RealtimeChannelV2?
    private var postgresChangeSubscription: RealtimeSubscription?
    private var listenTask: Task<Void, Never>?
    private var walletReconnectTask: Task<Void, Never>?
    private var walletReconnectAttempt: Int = 0

    private enum Key {
        static let email = "felSupabaseSignInEmail"
        /// Persisted local `athlete_id` for `athlete_profile_link` upserts after token refresh / foreground.
        static let linkedAthleteId = "felLinkedAthleteId"
    }

    var lastErrorMessage: String?

    private init() {}

    private func makeClient() -> SupabaseClient? {
        if let client {
            return client
        }
        guard let baseRaw = FELAppConfig.felSupabaseURL,
              let keyRaw = FELAppConfig.felSupabaseAnonKey,
              let url = URL(string: baseRaw.trimmingCharacters(in: .whitespacesAndNewlines)),
              !keyRaw.isEmpty else {
            return nil
        }
        let c = SupabaseClient(supabaseURL: url, supabaseKey: keyRaw)
        client = c
        return c
    }

    /// Signed-in JWT + user id for REST `user_balances` (RLS requires `auth.uid()`).
    func authState() async -> (userId: UUID, accessToken: String)? {
        guard let client = makeClient() else { return nil }
        do {
            let session = try await client.auth.session
            return (session.user.id, session.accessToken)
        } catch {
            return nil
        }
    }

    /// Restore session from Keychain (Supabase Auth), link athlete row, start Realtime.
    func resumeSessionIfNeeded(labViewModel: LabViewModel) {
        listenTask?.cancel()
        listenTask = Task {
            guard await authState() != nil else { return }
            UserDefaults.standard.set(labViewModel.profile.id, forKey: Key.linkedAthleteId)
            await upsertAthleteProfileLink(athleteId: labViewModel.profile.id)
            await syncProfileSupabaseId(labViewModel: labViewModel)
            await startWalletRealtime(labViewModel: labViewModel)
        }
    }

    func signIn(email: String, password: String, labViewModel: LabViewModel) async -> Bool {
        lastErrorMessage = nil
        guard let client = makeClient() else {
            lastErrorMessage = "Supabase not configured (FEL_SUPABASE_URL / FEL_SUPABASE_ANON_KEY)."
            return false
        }
        do {
            try await client.auth.signIn(email: email, password: password)
            UserDefaults.standard.set(email, forKey: Key.email)
            UserDefaults.standard.set(labViewModel.profile.id, forKey: Key.linkedAthleteId)
            await upsertAthleteProfileLink(athleteId: labViewModel.profile.id)
            await syncProfileSupabaseId(labViewModel: labViewModel)
            await PRQManager.shared.syncWallet()
            await startWalletRealtime(labViewModel: labViewModel)
            return true
        } catch {
            lastErrorMessage = error.localizedDescription
            return false
        }
    }

    func signOut() async {
        listenTask?.cancel()
        listenTask = nil
        postgresChangeSubscription = nil
        if let ch = realtimeChannel, let c = makeClient() {
            await c.realtimeV2.removeChannel(ch)
        }
        realtimeChannel = nil
        guard let client = makeClient() else { return }
        try? await client.auth.signOut()
        UserDefaults.standard.removeObject(forKey: Key.linkedAthleteId)
        lastErrorMessage = nil
    }

    /// Foreground / post-refresh: re-link `athlete_id` ↔ `user_id` so Stripe webhooks resolve after session rotation.
    func refreshAthleteProfileLink(athleteId: String) async {
        guard await authState() != nil else { return }
        await upsertAthleteProfileLink(athleteId: athleteId)
    }

    private func syncProfileSupabaseId(labViewModel: LabViewModel) async {
        guard let state = await authState() else { return }
        var p = labViewModel.profile
        let uuid = state.userId.uuidString.lowercased()
        guard p.supabaseUserId != uuid else { return }
        p.supabaseUserId = uuid
        labViewModel.profile = p
        SaveSystem.saveProfile(p)
    }

    private func upsertAthleteProfileLink(athleteId: String) async {
        guard let state = await authState() else { return }
        let ok = await FELSovereignShardEconomy.upsertAthleteProfileLinkRPC(athleteId: athleteId, accessToken: state.accessToken)
        if !ok {
            lastErrorMessage = "Could not upsert athlete_profile_link (check RPC migration and JWT)."
        }
    }

    private func startWalletRealtime(labViewModel: LabViewModel) async {
        guard let client = makeClient() else { return }
        guard let session = try? await client.auth.session else { return }

        // Do not cancel `listenTask` here — this function is often invoked from that task; self-cancel would drop the session chain.
        postgresChangeSubscription = nil
        if let ch = realtimeChannel {
            await client.realtimeV2.removeChannel(ch)
        }
        realtimeChannel = nil

        let uid = session.user.id
        let token = session.accessToken
        let realtime = client.realtimeV2
        await realtime.setAuth(token)
        await realtime.connect()

        let topic = "wallet-\(uid.uuidString.lowercased())"
        let channel = realtime.channel(topic)
        realtimeChannel = channel

        let filter = "user_id=eq.\(uid.uuidString.lowercased())"
        postgresChangeSubscription = channel.onPostgresChange(
            AnyAction.self,
            schema: "public",
            table: "user_balances",
            filter: filter
        ) { _ in
            Task { @MainActor in
                await PRQManager.shared.syncWallet()
            }
        }

        do {
            try await channel.subscribeWithError()
            walletReconnectAttempt = 0
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
            scheduleWalletRealtimeReconnect(labViewModel: labViewModel)
        }
    }

    /// Edge case: WebSocket / channel drops — bounded exponential backoff, then full re-subscribe (Stripe webhook still lands on next foreground sync).
    private func scheduleWalletRealtimeReconnect(labViewModel: LabViewModel) {
        walletReconnectTask?.cancel()
        let attempt = walletReconnectAttempt
        walletReconnectAttempt = min(attempt + 1, 12)
        let delaySec = min(60.0, pow(2.0, Double(attempt)))
        walletReconnectTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(delaySec * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await startWalletRealtime(labViewModel: labViewModel)
        }
    }
}
