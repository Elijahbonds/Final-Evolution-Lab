import Foundation

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

struct CloudAppSnapshot: Codable {
    let profile: UserProfile
    let sessions: [WorkoutSession]
    let gameResults: [GameSessionResult]
    let coachEconomy: CoachEconomy
    let critiqueRequests: [CritiqueRequest]
    let trainingProgress: TrainingProgress
    let creatorMarketplace: CreatorCardMarketplaceState
    let eventHub: EventHubState
    let academyProgress: AcademyProgressState
    let cloneProfile: CloneProfile?
    let movementDatabase: MovementDatabase
    let bondsAIStudio: BondsAIStudioState
    let updatedAt: Date

    init(
        profile: UserProfile,
        sessions: [WorkoutSession],
        gameResults: [GameSessionResult],
        coachEconomy: CoachEconomy,
        critiqueRequests: [CritiqueRequest],
        trainingProgress: TrainingProgress,
        creatorMarketplace: CreatorCardMarketplaceState,
        eventHub: EventHubState,
        academyProgress: AcademyProgressState,
        cloneProfile: CloneProfile?,
        movementDatabase: MovementDatabase,
        bondsAIStudio: BondsAIStudioState,
        updatedAt: Date
    ) {
        self.profile = profile
        self.sessions = sessions
        self.gameResults = gameResults
        self.coachEconomy = coachEconomy
        self.critiqueRequests = critiqueRequests
        self.trainingProgress = trainingProgress
        self.creatorMarketplace = creatorMarketplace
        self.eventHub = eventHub
        self.academyProgress = academyProgress
        self.cloneProfile = cloneProfile
        self.movementDatabase = movementDatabase
        self.bondsAIStudio = bondsAIStudio
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        profile = try container.decode(UserProfile.self, forKey: .profile)
        sessions = try container.decode([WorkoutSession].self, forKey: .sessions)
        gameResults = try container.decode([GameSessionResult].self, forKey: .gameResults)
        coachEconomy = try container.decode(CoachEconomy.self, forKey: .coachEconomy)
        critiqueRequests = try container.decode([CritiqueRequest].self, forKey: .critiqueRequests)
        trainingProgress = try container.decode(TrainingProgress.self, forKey: .trainingProgress)
        creatorMarketplace = (try? container.decode(CreatorCardMarketplaceState.self, forKey: .creatorMarketplace)) ?? CreatorCardMarketplaceState()
        eventHub = (try? container.decode(EventHubState.self, forKey: .eventHub)) ?? EventHubState()
        academyProgress = (try? container.decode(AcademyProgressState.self, forKey: .academyProgress)) ?? .initial
        cloneProfile = try container.decodeIfPresent(CloneProfile.self, forKey: .cloneProfile)
        movementDatabase = (try? container.decode(MovementDatabase.self, forKey: .movementDatabase)) ?? MovementDatabase()
        bondsAIStudio = (try? container.decode(BondsAIStudioState.self, forKey: .bondsAIStudio)) ?? BondsAIStudioState()
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
}

enum FirebasePersistenceService {
    static func pushSnapshot(_ snapshot: CloudAppSnapshot) async {
#if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        FirebaseBootstrap.configureIfNeeded()
        guard let userId = await ensureAnonymousUserId() else { return }
        guard let encoded = try? JSONEncoder().encode(snapshot) else { return }

        let document: [String: Any] = [
            "payloadVersion": 1,
            "updatedAt": Timestamp(date: snapshot.updatedAt),
            "blob": encoded.base64EncodedString()
        ]

        do {
            let db = Firestore.firestore()
            try await db.collection("users")
                .document(userId)
                .collection("state")
                .document("snapshot")
                .setData(document, merge: true)
        } catch {
            print("[FirebasePersistenceService] Push failed: \(error.localizedDescription)")
        }
#endif
    }

    static func pullSnapshot() async -> CloudAppSnapshot? {
#if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        FirebaseBootstrap.configureIfNeeded()
        guard let userId = await ensureAnonymousUserId() else { return nil }

        do {
            let db = Firestore.firestore()
            let document = try await db.collection("users")
                .document(userId)
                .collection("state")
                .document("snapshot")
                .getDocument()

            guard let data = document.data(),
                  let blob = data["blob"] as? String,
                  let encoded = Data(base64Encoded: blob),
                  let snapshot = try? JSONDecoder().decode(CloudAppSnapshot.self, from: encoded) else {
                return nil
            }

            return snapshot
        } catch {
            print("[FirebasePersistenceService] Pull failed: \(error.localizedDescription)")
            return nil
        }
#else
        return nil
#endif
    }

#if canImport(FirebaseAuth)
    private static func ensureAnonymousUserId() async -> String? {
        if let user = Auth.auth().currentUser {
            return user.uid
        }

        do {
            let result = try await Auth.auth().signInAnonymously()
            return result.user.uid
        } catch {
            print("[FirebasePersistenceService] Anonymous sign-in failed: \(error.localizedDescription)")
            return nil
        }
    }
#endif
}
