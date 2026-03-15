import Foundation

// MARK: - Performance Readiness Quotient (PRQ) — Native Swift, no custom runtime
nonisolated let prqScoreUpdatedNotification = NSNotification.Name("PRQScoreUpdated")
nonisolated let prqScoreDidUpdateNotification = NSNotification.Name("PRQScoreDidUpdate")

@Observable
@MainActor
final class PRQScoreManager {
    static let shared = PRQScoreManager()

    static let userDefaultsKey = "app_prq_score"

    private(set) var currentPrqScore: Int

    private static let legacyUserDefaultsKey = "rork_prq_score"

    private init() {
        var value = UserDefaults.standard.integer(forKey: Self.userDefaultsKey)
        if value == 0, UserDefaults.standard.object(forKey: Self.legacyUserDefaultsKey) != nil {
            value = UserDefaults.standard.integer(forKey: Self.legacyUserDefaultsKey)
            UserDefaults.standard.set(value, forKey: Self.userDefaultsKey)
        }
        currentPrqScore = value
        if currentPrqScore == 0 {
            currentPrqScore = Int(PRQ.default)
        }

        NotificationCenter.default.addObserver(
            forName: prqScoreUpdatedNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let score = notification.userInfo?["score"] as? Int else { return }
            MainActor.assumeIsolated {
                self.currentPrqScore = score
                UserDefaults.standard.set(score, forKey: PRQScoreManager.userDefaultsKey)
                NotificationCenter.default.post(name: prqScoreDidUpdateNotification, object: nil, userInfo: ["score": score])
            }
        }
    }

    var prqTier: String {
        if currentPrqScore >= 95 { return "LEGENDARY" }
        if currentPrqScore >= 80 { return "ELITE" }
        if currentPrqScore >= 60 { return "ADVANCED" }
        if currentPrqScore >= 40 { return "DEVELOPING" }
        return "FOUNDATION"
    }

    var tierColor: String {
        if currentPrqScore >= 95 { return "gold" }
        if currentPrqScore >= 80 { return "purple" }
        if currentPrqScore >= 60 { return "blue" }
        if currentPrqScore >= 40 { return "green" }
        return "gray"
    }

    func simulateUnityScore(_ score: Int) {
        NotificationCenter.default.post(
            name: prqScoreUpdatedNotification,
            object: nil,
            userInfo: ["score": score]
        )
    }
}
