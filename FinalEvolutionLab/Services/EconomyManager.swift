import Foundation
import FirebaseDataConnect
import SocialDataConnect

/// Cloud SQL **Evolution Shards** + ledger reads via Firebase Data Connect.
/// Shard **spends** sync via ``TrainingLabSocialBridge`` / ``SpendEvolutionShards`` (negative deltas only). Credits require admin ``AppendShardLedger`` after verified sessions.
@MainActor
final class EconomyManager {
    static let shared = EconomyManager()

    private init() {}

    /// Pulls ``User.evolutionShards`` from SQL for the signed-in Firebase user (read-only).
    func syncEvolutionShardsFromDataConnect(into profile: inout UserProfile) async {
        guard FirebaseBootstrap.isConfigured else { return }
        TrainingLabSocialBridge.shared.configureConnectorIfNeeded()
        do {
            try await FirebaseIdentity.ensureUserSignedIn()
            _ = try await TrainingLabSocialBridge.shared.ensureSqlUserRegistration(displayName: nil)
            let result = try await DataConnect.socialConnector.getUserByFirebaseUidQuery.execute()
            guard let row = result.data?.users.first else { return }
            profile.evolutionShards = row.evolutionShards
            SaveSystem.saveProfile(profile)
        } catch {
#if DEBUG
            print("[EconomyManager] syncEvolutionShardsFromDataConnect: \(error.localizedDescription)")
#endif
        }
    }

    /// Recent ledger rows for achievements UI / reconciliation (signed-in user only).
    func fetchMyShardLedgerPreview(limit: Int = 25) async -> [ListShardLedgerForUserQuery.Data.ShardLedger] {
        guard FirebaseBootstrap.isConfigured else { return [] }
        TrainingLabSocialBridge.shared.configureConnectorIfNeeded()
        do {
            try await FirebaseIdentity.ensureUserSignedIn()
            let result = try await DataConnect.socialConnector.listShardLedgerForUserQuery.execute { v in
                v.limit = limit
            }
            return result.data?.shardLedgers ?? []
        } catch {
#if DEBUG
            print("[EconomyManager] fetchMyShardLedgerPreview: \(error.localizedDescription)")
#endif
            return []
        }
    }

}
