import Foundation
import FirebaseDataConnect
import SocialDataConnect

/// Registers the signed-in Firebase user in Data Connect SQL, keeps a cached SQL `User.id`, and performs
/// training / scan–related mutations. Call ``configureConnectorIfNeeded()`` after ``FirebaseBootstrap/configureIfNeeded()``.
@MainActor
final class TrainingLabSocialBridge {
    static let shared = TrainingLabSocialBridge()

    private init() {}

    private var connectorConfigured = false

    func configureConnectorIfNeeded() {
        guard FirebaseBootstrap.isConfigured, !connectorConfigured else { return }
        let connector = DataConnect.socialConnector
        if Config.useFirebaseEmulators {
            connector.useEmulator(host: Config.dataConnectEmulatorHost, port: Config.dataConnectEmulatorPort)
        }
        connectorConfigured = true
    }

    private func clearSqlIdentityCache() {
        let ud = UserDefaults.standard
        ud.removeObject(forKey: Config.sqlSocialUserIdKey)
        ud.removeObject(forKey: Config.sqlSocialFirebaseUidKey)
    }

    private func persistedSqlIdentity(for firebaseUid: String) -> UUID? {
        let ud = UserDefaults.standard
        let storedUid = ud.string(forKey: Config.sqlSocialFirebaseUidKey)
        guard storedUid == firebaseUid, let s = ud.string(forKey: Config.sqlSocialUserIdKey) else {
            clearSqlIdentityCache()
            return nil
        }
        return UUID(uuidString: s)
    }

    private func persistSqlIdentity(userId id: UUID, firebaseUid uid: String) {
        let ud = UserDefaults.standard
        ud.set(id.uuidString, forKey: Config.sqlSocialUserIdKey)
        ud.set(uid, forKey: Config.sqlSocialFirebaseUidKey)
    }

    /// Phase 8: when Auth UID changes (sign-out or signing into a different account),
    /// proactively discard any cached SQL `User.id` that belonged to the previous UID.
    func reconcileCachedIdentityWithCurrentAuth() {
        guard let uid = FirebaseIdentity.userId else {
            clearSqlIdentityCache()
            return
        }
        _ = persistedSqlIdentity(for: uid) // will clear cache if mismatch
    }

    /// Ensures a SQL `User` row exists for `auth.uid` and returns its primary key.
    func ensureSqlUserRegistration(displayName: String?) async throws -> UUID {
        configureConnectorIfNeeded()
        try await FirebaseIdentity.ensureUserSignedIn()
        guard let uid = FirebaseIdentity.userId else {
            throw TrainingLabSocialBridgeError.noFirebaseUid
        }

        let connector = DataConnect.socialConnector

        if let cached = persistedSqlIdentity(for: uid) {
            return cached
        }

        let existing = try await connector.getUserByFirebaseUidQuery.execute(firebaseUid: uid)
        if let row = existing.data?.users.first {
            persistSqlIdentity(userId: row.id, firebaseUid: uid)
            return row.id
        }

        let username: String = {
            if let displayName, !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return String(displayName.prefix(64))
            }
            return "Athlete_\(uid.prefix(8))"
        }()
        let email = "\(uid)@anonymous.fel.app"

        do {
            let result = try await connector.registerSignedInUserMutation.execute(username: username, email: email)
            guard let inserted = result.data?.user_insert else {
                throw TrainingLabSocialBridgeError.emptyDataConnectResult
            }
            let id = inserted.id
            persistSqlIdentity(userId: id, firebaseUid: uid)
            return id
        } catch {
            let again = try await connector.getUserByFirebaseUidQuery.execute(firebaseUid: uid)
            if let u = again.data?.users.first {
                persistSqlIdentity(userId: u.id, firebaseUid: uid)
                return u.id
            }
            throw error
        }
    }

    /// Updates peak PRQ on the SQL `User` row from an in-app **demo** scan (`SystemScanView`) before posting to the feed.
    func syncPeakPRQFromScanResult(_ result: SystemScanResult) async {
        guard FirebaseBootstrap.isConfigured else { return }
        configureConnectorIfNeeded()
        do {
            try await FirebaseIdentity.ensureUserSignedIn()
            guard let uid = FirebaseIdentity.userId else { return }

            let connector = DataConnect.socialConnector
            _ = try await ensureSqlUserRegistration(displayName: nil)

            let refreshed = try await connector.getUserByFirebaseUidQuery.execute(firebaseUid: uid)
            guard let row = refreshed.data?.users.first else { return }
            let prior = row.topPRQScore
            let top = max(prior ?? 0, result.prqScore)
            _ = try await connector.updateUserTrainingProfileMutation.execute(userKey: row.userKey, topPRQScore: top) { _ in }
        } catch {
#if DEBUG
            print("[TrainingLabSocialBridge] syncPeakPRQFromScanResult error: \(error.localizedDescription)")
#endif
        }
    }

    /// Upserts PRQ peak from a System Scan into SQL (for feed badges / profile).
    func syncTrainingProfileFromScan(_ scan: SystemScanRecord) async {
        guard FirebaseBootstrap.isConfigured else { return }
        configureConnectorIfNeeded()
        do {
            try await FirebaseIdentity.ensureUserSignedIn()
            guard let uid = FirebaseIdentity.userId else { return }

            let connector = DataConnect.socialConnector
            _ = try await ensureSqlUserRegistration(displayName: nil)

            let refreshed = try await connector.getUserByFirebaseUidQuery.execute(firebaseUid: uid)
            guard let row = refreshed.data?.users.first else { return }
            let prior = row.topPRQScore
            let incoming = scan.avatar.prqScore
            let top = max(prior ?? 0, incoming)

            _ = try await connector.updateUserTrainingProfileMutation.execute(userKey: row.userKey, topPRQScore: top) { _ in }
        } catch {
#if DEBUG
            print("[TrainingLabSocialBridge] syncTrainingProfileFromScan error: \(error.localizedDescription)")
#endif
        }
    }

    func createFeedPost(
        content: String,
        authorId: UUID,
        gameModeId: String?,
        trainingScore: Double?,
        clipUrl: String?,
        feedSource: String?
    ) async throws {
        configureConnectorIfNeeded()
        try await FirebaseIdentity.ensureUserSignedIn()
        _ = try await DataConnect.socialConnector.createPostMutation.execute(content: content, authorId: authorId) { v in
            if let gameModeId { v.gameModeId = gameModeId }
            if let trainingScore { v.trainingScore = trainingScore }
            if let clipUrl { v.clipUrl = clipUrl }
            if let feedSource { v.feedSource = feedSource }
        }
    }

    /// SQL **Post** row framing a Movement Snack as a Lab feed discovery / achievement.
    func publishMovementSnackDiscovery(snack: MovementSnack, athleteDisplayName: String) async throws {
        guard FirebaseBootstrap.isConfigured else {
            throw TrainingLabSocialBridgeError.firebaseNotConfigured
        }
        configureConnectorIfNeeded()
        try await FirebaseIdentity.ensureUserSignedIn()
        let authorId = try await ensureSqlUserRegistration(displayName: athleteDisplayName)
        let targets = snack.targetedCategories.map(\.rawValue).joined(separator: ", ")
        let leakageBit =
            targets.isEmpty
            ? "Staying primed with a maintenance Movement Snack."
            : "Just patched kinetic leakage focus: \(targets)."
        let content =
            "\(athleteDisplayName) — \(leakageBit) Snack: \(snack.title). UE \(snack.requiredUnrealAnimationAssetID)."
        try await createFeedPost(
            content: content,
            authorId: authorId,
            gameModeId: "education_lab",
            trainingScore: Double(snack.durationSeconds),
            clipUrl: nil,
            feedSource: "body_iq_discovery"
        )
    }
}

enum TrainingLabSocialBridgeError: Error {
    case noFirebaseUid
    case emptyDataConnectResult
    case firebaseNotConfigured
}
