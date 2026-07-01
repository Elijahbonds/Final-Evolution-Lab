import Foundation
import OSLog

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

/// Best-effort Firestore sync for UserProfile and CoachEconomy.
/// Falls back gracefully when Firebase is not configured or the user is not signed in.
/// UserDefaults remains the source of truth for reads; Firestore is the server-authoritative record.
final class ProfileSyncService {
    static let shared = ProfileSyncService()

    private static let log = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "FinalEvolutionLab",
        category: "ProfileSync"
    )

#if canImport(FirebaseFirestore)
    private var db: Firestore? {
        guard FirebaseBootstrap.isConfigured else { return nil }
        return Firestore.firestore()
    }

    private var currentUID: String? {
#if canImport(FirebaseAuth)
        Auth.auth().currentUser?.uid
#else
        nil
#endif
    }
#endif

    // MARK: - Profile

    func pushProfile(_ profile: UserProfile) {
#if canImport(FirebaseFirestore)
        guard let db, let uid = currentUID else { return }
        let encoder = Firestore.Encoder()
        guard let data = try? encoder.encode(profile) else { return }
        db.collection("profiles").document(uid).setData(data, merge: true) { err in
            if let err {
                Self.log.error("Profile push failed: \(err.localizedDescription, privacy: .public)")
            }
        }
#endif
    }

    func pullProfile(into saveBlock: @escaping (UserProfile) -> Void) {
#if canImport(FirebaseFirestore)
        guard let db, let uid = currentUID else { return }
        db.collection("profiles").document(uid).getDocument { snapshot, err in
            if let err {
                Self.log.error("Profile pull failed: \(err.localizedDescription, privacy: .public)")
                return
            }
            guard let snapshot, snapshot.exists else { return }
            let decoder = Firestore.Decoder()
            guard let profile = try? decoder.decode(UserProfile.self, from: snapshot.data() ?? [:]) else { return }
            DispatchQueue.main.async { saveBlock(profile) }
        }
#endif
    }

    // MARK: - Coach Economy

    func pushCoachEconomy(_ economy: CoachEconomy) {
#if canImport(FirebaseFirestore)
        guard let db, let uid = currentUID else { return }
        let encoder = Firestore.Encoder()
        guard let data = try? encoder.encode(economy) else { return }
        db.collection("coachEconomy").document(uid).setData(data, merge: true) { err in
            if let err {
                Self.log.error("CoachEconomy push failed: \(err.localizedDescription, privacy: .public)")
            }
        }
#endif
    }

    // MARK: - Shards delta (append-only ledger entry)

    func appendShardDelta(userId: String, delta: Int, source: String, balanceAfter: Int, gameModeId: String? = nil) {
#if canImport(FirebaseFirestore)
        guard let db, currentUID != nil else { return }
        let entry: [String: Any] = [
            "userId": userId,
            "deltaShards": delta,
            "balanceAfter": balanceAfter,
            "source": source,
            "gameModeId": gameModeId as Any,
            "createdAt": FieldValue.serverTimestamp()
        ]
        db.collection("shardLedger").addDocument(data: entry) { err in
            if let err {
                Self.log.error("ShardLedger append failed: \(err.localizedDescription, privacy: .public)")
            }
        }
#endif
    }
}
