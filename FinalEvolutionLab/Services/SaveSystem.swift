import Foundation

struct SaveSystem {
    private static let profileKey = "finalEvolution_profile"
    private static let sessionsKey = "finalEvolution_sessions"
    private static let gameResultsKey = "finalEvolution_gameResults"
    private static let coachEconomyKey = "finalEvolution_coachEconomy"
    private static let critiqueRequestsKey = "finalEvolution_critiqueRequests"
    private static let trainingProgressKey = "finalEvolution_trainingProgress"
    private static let creatorMarketplaceKey = "finalEvolution_creatorMarketplace"
    private static let eventHubKey = "finalEvolution_eventHub"
    private static let academyProgressKey = "finalEvolution_academyProgress"
    private static let lastMutationTimestampKey = "finalEvolution_lastMutationTimestamp"

    static func saveProfile(_ profile: UserProfile) {
        writeValue(profile, key: profileKey)
    }

    static func loadProfile() -> UserProfile {
        readValue(UserProfile.self, key: profileKey, defaultValue: .guest)
    }

    static func saveSessions(_ sessions: [WorkoutSession]) {
        writeValue(sessions, key: sessionsKey)
    }

    static func loadSessions() -> [WorkoutSession] {
        readValue([WorkoutSession].self, key: sessionsKey, defaultValue: [])
    }

    static func saveGameResult(_ result: GameSessionResult) {
        var results = loadGameResults()
        results.append(result)
        writeValue(results, key: gameResultsKey)
    }

    static func loadGameResults() -> [GameSessionResult] {
        readValue([GameSessionResult].self, key: gameResultsKey, defaultValue: [])
    }

    static func saveCoachEconomy(_ economy: CoachEconomy) {
        writeValue(economy, key: coachEconomyKey)
    }

    static func loadCoachEconomy() -> CoachEconomy {
        readValue(CoachEconomy.self, key: coachEconomyKey, defaultValue: CoachEconomy())
    }

    static func saveCritiqueRequests(_ requests: [CritiqueRequest]) {
        writeValue(requests, key: critiqueRequestsKey)
    }

    static func loadCritiqueRequests() -> [CritiqueRequest] {
        readValue([CritiqueRequest].self, key: critiqueRequestsKey, defaultValue: [])
    }

    static func saveTrainingProgress(_ progress: TrainingProgress) {
        writeValue(progress, key: trainingProgressKey)
    }

    static func loadTrainingProgress() -> TrainingProgress {
        readValue(TrainingProgress.self, key: trainingProgressKey, defaultValue: .initial)
    }

    static func saveCreatorMarketplace(_ marketplace: CreatorCardMarketplaceState) {
        writeValue(marketplace, key: creatorMarketplaceKey)
    }

    static func loadCreatorMarketplace() -> CreatorCardMarketplaceState {
        readValue(CreatorCardMarketplaceState.self, key: creatorMarketplaceKey, defaultValue: CreatorCardMarketplaceState())
    }

    static func saveEventHub(_ eventHub: EventHubState) {
        writeValue(eventHub, key: eventHubKey)
    }

    static func loadEventHub() -> EventHubState {
        readValue(EventHubState.self, key: eventHubKey, defaultValue: EventHubState())
    }

    static func saveAcademyProgress(_ progress: AcademyProgressState) {
        writeValue(progress, key: academyProgressKey)
    }

    static func loadAcademyProgress() -> AcademyProgressState {
        readValue(AcademyProgressState.self, key: academyProgressKey, defaultValue: .initial)
    }

    static func refreshFromCloudIfAvailable() async {
        guard let snapshot = await FirebasePersistenceService.pullSnapshot() else {
            return
        }
        let localMutationDate = Date(timeIntervalSince1970: UserDefaults.standard.double(forKey: lastMutationTimestampKey))
        guard snapshot.updatedAt > localMutationDate else {
            return
        }

        writeValue(snapshot.profile, key: profileKey, triggerCloudSync: false)
        writeValue(snapshot.sessions, key: sessionsKey, triggerCloudSync: false)
        writeValue(snapshot.gameResults, key: gameResultsKey, triggerCloudSync: false)
        writeValue(snapshot.coachEconomy, key: coachEconomyKey, triggerCloudSync: false)
        writeValue(snapshot.critiqueRequests, key: critiqueRequestsKey, triggerCloudSync: false)
        writeValue(snapshot.trainingProgress, key: trainingProgressKey, triggerCloudSync: false)
        writeValue(snapshot.creatorMarketplace, key: creatorMarketplaceKey, triggerCloudSync: false)
        writeValue(snapshot.eventHub, key: eventHubKey, triggerCloudSync: false)
        writeValue(snapshot.academyProgress, key: academyProgressKey, triggerCloudSync: false)
        UserDefaults.standard.set(snapshot.updatedAt.timeIntervalSince1970, forKey: lastMutationTimestampKey)
    }

    private static func writeValue<T: Encodable>(_ value: T, key: String, triggerCloudSync: Bool = true) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        UserDefaults.standard.set(data, forKey: key)

        if triggerCloudSync {
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastMutationTimestampKey)
            triggerFirebaseSync()
        }
    }

    private static func readValue<T: Decodable>(_ type: T.Type, key: String, defaultValue: T) -> T {
        guard let data = UserDefaults.standard.data(forKey: key),
              let value = try? JSONDecoder().decode(T.self, from: data) else {
            return defaultValue
        }
        return value
    }

    private static func triggerFirebaseSync() {
        Task {
            let snapshot = CloudAppSnapshot(
                profile: loadProfile(),
                sessions: loadSessions(),
                gameResults: loadGameResults(),
                coachEconomy: loadCoachEconomy(),
                critiqueRequests: loadCritiqueRequests(),
                trainingProgress: loadTrainingProgress(),
                creatorMarketplace: loadCreatorMarketplace(),
                eventHub: loadEventHub(),
                academyProgress: loadAcademyProgress(),
                updatedAt: Date()
            )
            await FirebasePersistenceService.pushSnapshot(snapshot)
        }
    }
}
