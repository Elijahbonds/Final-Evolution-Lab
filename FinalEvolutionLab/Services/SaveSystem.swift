import Foundation

struct SaveSystem {
    private static let profileKey = "finalEvolution_profile"
    private static let sessionsKey = "finalEvolution_sessions"
    private static let pendingSystemScansKey = "finalEvolution_pendingSystemScans_v1"

    static func saveProfile(_ profile: UserProfile) {
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: profileKey)
        }
    }

    static func loadProfile() -> UserProfile {
        guard let data = UserDefaults.standard.data(forKey: profileKey),
              let profile = try? JSONDecoder().decode(UserProfile.self, from: data) else {
            return .guest
        }
        return profile
    }

    static func saveSessions(_ sessions: [WorkoutSession]) {
        if let data = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(data, forKey: sessionsKey)
        }
    }

    static func loadSessions() -> [WorkoutSession] {
        guard let data = UserDefaults.standard.data(forKey: sessionsKey),
              let sessions = try? JSONDecoder().decode([WorkoutSession].self, from: data) else {
            return []
        }
        return sessions
    }

    // MARK: - Offline queue (System Scan → Firestore)

    static func enqueuePendingSystemScan(_ scan: SystemScanRecord) {
        var queue = loadPendingSystemScans()
        queue.append(scan)
        // Keep queue bounded so an offline device doesn't blow up UserDefaults.
        if queue.count > 25 {
            queue = Array(queue.suffix(25))
        }
        if let data = try? JSONEncoder().encode(queue) {
            UserDefaults.standard.set(data, forKey: pendingSystemScansKey)
        }
    }

    static func loadPendingSystemScans() -> [SystemScanRecord] {
        guard let data = UserDefaults.standard.data(forKey: pendingSystemScansKey),
              let scans = try? JSONDecoder().decode([SystemScanRecord].self, from: data) else {
            return []
        }
        return scans
    }

    static func replacePendingSystemScans(_ scans: [SystemScanRecord]) {
        if scans.isEmpty {
            UserDefaults.standard.removeObject(forKey: pendingSystemScansKey)
            return
        }
        if let data = try? JSONEncoder().encode(scans) {
            UserDefaults.standard.set(data, forKey: pendingSystemScansKey)
        }
    }

    /// Last mode the player explicitly chose on the Arena grid (GAME-35); global matchmaking uses this instead of registry order.
    private static let lastArenaModeIdKey = "fel_last_selected_arena_mode_id"

    static func saveLastSelectedArenaModeId(_ rawValue: String) {
        UserDefaults.standard.set(rawValue, forKey: lastArenaModeIdKey)
    }

    static func loadLastSelectedArenaModeId() -> String? {
        UserDefaults.standard.string(forKey: lastArenaModeIdKey)
    }

    private static let gameResultsKey = "finalEvolution_gameResults"
    private static let maxCachedGameResults = 64

    static func saveGameResult(_ result: GameSessionResult) {
        var results = loadGameResults()
        results.removeAll { $0.id == result.id }
        results.append(result)
        if results.count > maxCachedGameResults {
            results = Array(results.suffix(maxCachedGameResults))
        }
        if let data = try? JSONEncoder().encode(results) {
            UserDefaults.standard.set(data, forKey: gameResultsKey)
        }
    }

    static func loadGameResults() -> [GameSessionResult] {
        guard let data = UserDefaults.standard.data(forKey: gameResultsKey),
              let results = try? JSONDecoder().decode([GameSessionResult].self, from: data) else {
            return []
        }
        return results
    }

    private static let coachEconomyKey = "finalEvolution_coachEconomy"

    static func saveCoachEconomy(_ economy: CoachEconomy) {
        if let data = try? JSONEncoder().encode(economy) {
            UserDefaults.standard.set(data, forKey: coachEconomyKey)
        }
    }

    static func loadCoachEconomy() -> CoachEconomy {
        guard let data = UserDefaults.standard.data(forKey: coachEconomyKey),
              let economy = try? JSONDecoder().decode(CoachEconomy.self, from: data) else {
            return CoachEconomy()
        }
        return economy
    }

    private static let critiqueRequestsKey = "finalEvolution_critiqueRequests"

    static func saveCritiqueRequests(_ requests: [CritiqueRequest]) {
        if let data = try? JSONEncoder().encode(requests) {
            UserDefaults.standard.set(data, forKey: critiqueRequestsKey)
        }
    }

    static func loadCritiqueRequests() -> [CritiqueRequest] {
        guard let data = UserDefaults.standard.data(forKey: critiqueRequestsKey),
              let requests = try? JSONDecoder().decode([CritiqueRequest].self, from: data) else {
            return []
        }
        return requests
    }

    private static let trainingProgressKey = "finalEvolution_trainingProgress"

    static func saveTrainingProgress(_ progress: TrainingProgress) {
        if let data = try? JSONEncoder().encode(progress) {
            UserDefaults.standard.set(data, forKey: trainingProgressKey)
        }
    }

    static func loadTrainingProgress() -> TrainingProgress {
        guard let data = UserDefaults.standard.data(forKey: trainingProgressKey),
              let progress = try? JSONDecoder().decode(TrainingProgress.self, from: data) else {
            return .initial
        }
        return progress
    }
}
