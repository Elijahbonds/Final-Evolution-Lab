import Foundation

struct SaveSystem {
    private static let profileKey = "finalEvolution_profile"
    private static let sessionsKey = "finalEvolution_sessions"

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

    private static let gameResultsKey = "finalEvolution_gameResults"

    private static let maxStoredGameResults = 100

    static func saveGameResult(_ result: GameSessionResult) {
        var results = loadGameResults()
        results.append(result)
        if results.count > maxStoredGameResults {
            results = Array(results.suffix(maxStoredGameResults))
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
        if results.count > maxStoredGameResults {
            return Array(results.suffix(maxStoredGameResults))
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
