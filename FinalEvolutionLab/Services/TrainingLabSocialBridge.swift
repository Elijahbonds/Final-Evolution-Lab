import Foundation
import FirebaseDataConnect
import SocialDataConnect

/// Whether a Movement Snack feed post is framed as measured athlete findings or general education (BODYIQ-01).
enum MovementSnackFeedProvenance {
    /// Verified measured Lab scan met competitive commit thresholds — athlete-specific framing is allowed.
    case measuredAthleteSpecific
    /// Demo / readiness / low-confidence scan — post as general education, not personalized correction claims.
    case generalEducation
}

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

        let existing = try await connector.getUserByFirebaseUidQuery.execute()
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
            let again = try await connector.getUserByFirebaseUidQuery.execute()
            if let u = again.data?.users.first {
                persistSqlIdentity(userId: u.id, firebaseUid: uid)
                return u.id
            }
            throw error
        }
    }

    /// Updates peak PRQ on the SQL `User` row from a **measured** Lab scan only (SCAN-51).
    func syncPeakPRQFromScanResult(_ result: SystemScanResult) async {
        guard result.commitsCompetitiveMetrics else { return }
        guard FirebaseBootstrap.isConfigured else { return }
        configureConnectorIfNeeded()
        do {
            try await FirebaseIdentity.ensureUserSignedIn()
            guard FirebaseIdentity.userId != nil else { return }

            let connector = DataConnect.socialConnector
            _ = try await ensureSqlUserRegistration(displayName: nil)

            let refreshed = try await connector.getUserByFirebaseUidQuery.execute()
            guard let row = refreshed.data?.users.first else { return }
            let prior = row.topPRQScore
            let top = max(prior ?? 0, result.prqScore)
            _ = try await connector.updateMyTrainingProfileMutation.execute(topPRQScore: top) { _ in }
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
            guard FirebaseIdentity.userId != nil else { return }

            let connector = DataConnect.socialConnector
            _ = try await ensureSqlUserRegistration(displayName: nil)

            let refreshed = try await connector.getUserByFirebaseUidQuery.execute()
            guard let row = refreshed.data?.users.first else { return }
            let prior = row.topPRQScore
            guard let verified = scan.avatar.verifiedPerformancePRQ, verified > 0 else { return }
            let top = max(prior ?? 0, verified)

            _ = try await connector.updateMyTrainingProfileMutation.execute(topPRQScore: top) { _ in }
        } catch {
#if DEBUG
            print("[TrainingLabSocialBridge] syncTrainingProfileFromScan error: \(error.localizedDescription)")
#endif
        }
    }

    func createFeedPost(
        content: String,
        gameModeId: String?,
        trainingScore: Double?,
        clipUrl: String?,
        feedSource: String?
    ) async throws {
        try AthleteSafetyPolicy.assertSensitiveMinorGate(profile: SaveSystem.loadProfile())
        configureConnectorIfNeeded()
        try await FirebaseIdentity.ensureUserSignedIn()
        _ = try await DataConnect.socialConnector.createPostMutation.execute(content: content) { v in
            if let gameModeId { v.gameModeId = gameModeId }
            if let trainingScore { v.trainingScore = trainingScore }
            if let clipUrl { v.clipUrl = clipUrl }
            if let feedSource { v.feedSource = feedSource }
        }
    }

    /// Arena shard **credits** must be applied by a trusted backend (admin ``AppendShardLedger`` after session verification). Clients cannot mint SQL balance.
    /// Local clients accumulate ``UserProfile/pendingUnverifiedShardCredits`` until that pipeline exists (GAME-43).
    func recordShardLedgerForArenaSession(gameModeId: String, deltaShards: Int, sessionId: String) async {
        guard deltaShards > 0 else { return }
#if DEBUG
        print("[TrainingLabSocialBridge] Arena shard SQL grant skipped (\(deltaShards) shards, mode \(gameModeId), session \(sessionId.prefix(8))…) — pending bucket holds credits until verified AppendShardLedger.")
#endif
    }

    /// Persists a shard **spend** (negative `deltaShards`) or gameplay reward (positive `deltaShards`) via Data Connect.
    func recordShardLedgerDelta(deltaShards: Int, reason: String, referenceId: String) async throws {
        guard deltaShards != 0 else { return }
        guard deltaShards < 0 || reason.contains("brain_brawl") || reason.contains("gameplay") || reason.contains("reward") else {
            throw TrainingLabSocialBridgeError.shardIncreasesRequireServerGrant
        }
        guard FirebaseBootstrap.isConfigured else {
            throw TrainingLabSocialBridgeError.firebaseNotConfigured
        }
        configureConnectorIfNeeded()
        try await FirebaseIdentity.ensureUserSignedIn()
        guard FirebaseIdentity.userId != nil else {
            throw TrainingLabSocialBridgeError.noFirebaseUid
        }
        let reasonField = String(reason.prefix(64))
        let refField = String(referenceId.prefix(128))
        _ = try await DataConnect.socialConnector.spendEvolutionShardsMutation.execute(
            deltaShards: deltaShards,
            reason: reasonField
        ) { v in
            v.referenceId = refField
        }
    }

    /// Records SQL ownership of a catalog card after a successful ``SpendEvolutionShards`` for `creator_card_purchase` with the same `referenceId` as `catalogCardId`.
    func claimCreatorCardOwnership(catalogCardId: String) async throws {
        guard FirebaseBootstrap.isConfigured else {
            throw TrainingLabSocialBridgeError.firebaseNotConfigured
        }
        configureConnectorIfNeeded()
        try await FirebaseIdentity.ensureUserSignedIn()
        _ = try await ensureSqlUserRegistration(displayName: nil)
        _ = try await DataConnect.socialConnector.claimCreatorCardOwnershipMutation.execute(
            catalogCardId: String(catalogCardId.prefix(64))
        )
    }

    /// Executes an atomic marketplace purchase: debits the buyer, credits the seller, revokes seller ownership, grants buyer ownership, and deactivates the listing.
    func executeMarketplacePurchase(
        listingId: UUID,
        buyerId: UUID,
        sellerId: UUID,
        catalogCardId: String,
        priceShards: Int
    ) async throws {
        guard FirebaseBootstrap.isConfigured else {
            throw TrainingLabSocialBridgeError.firebaseNotConfigured
        }
        configureConnectorIfNeeded()
        try await FirebaseIdentity.ensureUserSignedIn()
        
        _ = try await DataConnect.socialConnector.executeMarketplacePurchaseMutation.execute(
            listingId: listingId,
            buyerId: buyerId,
            sellerId: sellerId,
            catalogCardId: catalogCardId,
            buyerDeltaShards: -priceShards,
            sellerDeltaShards: priceShards
        )
    }

    /// Executes an atomic marketplace purchase with a 10% royalty to the original creator.
    func executeMarketplacePurchaseWithRoyalty(
        listingId: UUID,
        buyerId: UUID,
        sellerId: UUID,
        catalogCardId: String,
        priceShards: Int,
        creatorId: UUID,
        royaltyShards: Int
    ) async throws {
        guard FirebaseBootstrap.isConfigured else {
            throw TrainingLabSocialBridgeError.firebaseNotConfigured
        }
        configureConnectorIfNeeded()
        try await FirebaseIdentity.ensureUserSignedIn()
        
        _ = try await DataConnect.socialConnector.executeMarketplacePurchaseWithRoyaltyMutation.execute(
            listingId: listingId,
            buyerId: buyerId,
            sellerId: sellerId,
            catalogCardId: catalogCardId,
            buyerDeltaShards: -priceShards,
            sellerDeltaShards: priceShards,
            creatorId: creatorId,
            royaltyShards: royaltyShards
        )
    }

    /// Claims the pending royalties for the current user and moves them to the spendable shard balance.
    func claimRoyalties(claimId: String, amount: Int? = nil) async throws {
        guard FirebaseBootstrap.isConfigured else {
            throw TrainingLabSocialBridgeError.firebaseNotConfigured
        }
        configureConnectorIfNeeded()
        try await FirebaseIdentity.ensureUserSignedIn()
        let claimAmount = amount ?? SaveSystem.loadProfile().pendingRoyaltyShards
        _ = try await DataConnect.socialConnector.claimRoyaltiesMutation.execute(claimId: claimId, amount: claimAmount)
    }

    /// Atomic 500-shard escrow + `CoachCritiqueRequest` row (ledger reason `critique_escrow`). `requestKey` must be unique (e.g. `UUID().uuidString`).
    func createCritiqueRequestWithEscrow(requestKey: String, exerciseName: String, notes: String?) async throws {
        try AthleteSafetyPolicy.assertSensitiveMinorGate(profile: SaveSystem.loadProfile())
        guard FirebaseBootstrap.isConfigured else {
            throw TrainingLabSocialBridgeError.firebaseNotConfigured
        }
        configureConnectorIfNeeded()
        try await FirebaseIdentity.ensureUserSignedIn()
        _ = try await ensureSqlUserRegistration(displayName: nil)
        let name = String(exerciseName.prefix(128))
        _ = try await DataConnect.socialConnector.createCritiqueRequestWithEscrowMutation.execute(
            requestKey: String(requestKey.prefix(40)),
            exerciseName: name
        ) { v in
            if let notes, !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                v.notes = String(notes.prefix(4096))
            }
        }
    }

    /// SQL **Post** row framing a Movement Snack as a Lab feed discovery / achievement.
    func publishMovementSnackDiscovery(
        snack: MovementSnack,
        athleteDisplayName: String,
        provenance: MovementSnackFeedProvenance
    ) async throws {
        try AthleteSafetyPolicy.assertSensitiveMinorGate(profile: SaveSystem.loadProfile())
        guard FirebaseBootstrap.isConfigured else {
            throw TrainingLabSocialBridgeError.firebaseNotConfigured
        }
        configureConnectorIfNeeded()
        try await FirebaseIdentity.ensureUserSignedIn()
        _ = try await ensureSqlUserRegistration(displayName: athleteDisplayName)
        let targets = snack.targetedCategories.map(\.rawValue).joined(separator: ", ")
        let (content, feedSource): (String, String) = {
            switch provenance {
            case .measuredAthleteSpecific:
                let leakageBit =
                    targets.isEmpty
                    ? "Staying primed with a maintenance Movement Snack."
                    : "Just patched kinetic leakage focus: \(targets)."
                return (
                    "\(athleteDisplayName) — \(leakageBit) Snack: \(snack.title). NEXUS \(snack.requiredAnimationAssetID).",
                    "body_iq_discovery"
                )
            case .generalEducation:
                return (
                    "Education lab · general Movement Snack idea (not from a measured pose audit): \(snack.title). NEXUS \(snack.requiredAnimationAssetID).",
                    "body_iq_discovery_general"
                )
            }
        }()
        try await createFeedPost(
            content: content,
            gameModeId: "education_lab",
            trainingScore: Double(snack.durationSeconds),
            clipUrl: nil,
            feedSource: feedSource
        )
    }

    func publishKinesiologyCertification(
        athleteDisplayName: String,
        certificateId: String,
        scorePct: Double
    ) async throws {
        try AthleteSafetyPolicy.assertSensitiveMinorGate(profile: SaveSystem.loadProfile())
        guard FirebaseBootstrap.isConfigured else {
            throw TrainingLabSocialBridgeError.firebaseNotConfigured
        }
        configureConnectorIfNeeded()
        try await FirebaseIdentity.ensureUserSignedIn()
        _ = try await ensureSqlUserRegistration(displayName: athleteDisplayName)
        
        let content = "🎓 KINESIOLOGY CERTIFIED! \(athleteDisplayName) has passed the Applied Kinesiology Board Examination with a score of \(String(format: "%.1f%%", scorePct))! Verification Credential ID: \(certificateId). #AppliedKinesiology #BondsStandard #FinalEvolution"
        
        try await createFeedPost(
            content: content,
            gameModeId: "education_lab",
            trainingScore: scorePct,
            clipUrl: nil,
            feedSource: "kinesiology_certification"
        )
    }
}

enum TrainingLabSocialBridgeError: Error, LocalizedError {
    case noFirebaseUid
    case emptyDataConnectResult
    case firebaseNotConfigured
    /// Positive SQL shard balance changes must use admin-only ``AppendShardLedger`` after verified grants — not the mobile ``SpendEvolutionShards`` path.
    case shardIncreasesRequireServerGrant
    case minorRequiresGuardianConsent

    var errorDescription: String? {
        switch self {
        case .noFirebaseUid:
            return "Sign in is required before training lab features can sync."
        case .emptyDataConnectResult:
            return "Training lab sync returned no data (cloud sync may be offline)."
        case .firebaseNotConfigured:
            return "Firebase is not configured in this build (PREVIEW)."
        case .shardIncreasesRequireServerGrant:
            return "Shard credits require server verification (saved on device until you sign in)."
        case .minorRequiresGuardianConsent:
            return "Parent/guardian consent is required for athletes under 18. Turn it on in Settings → Safety."
        }
    }
}
