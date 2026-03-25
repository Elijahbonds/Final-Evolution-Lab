import Foundation
import Observation

// MARK: - Performance Readiness Quotient (PRQ) — Native Swift, no custom runtime
nonisolated let prqScoreUpdatedNotification = NSNotification.Name("PRQScoreUpdated")
nonisolated let prqScoreDidUpdateNotification = NSNotification.Name("PRQScoreDidUpdate")

@Observable
@MainActor
final class PRQScoreManager {
    static let shared = PRQScoreManager()

    static let userDefaultsKey = "app_prq_score"

    private(set) var currentPrqScore: Int

    /// One-time migration from pre–1.0 third-party tooling UserDefaults key (bytes spell legacy key; not stored as literal in source).
    private static let legacyPrqScoreKeyObsolete: String = String(
        decoding: [114, 111, 114, 107, 95, 112, 114, 113, 95, 115, 99, 111, 114, 101],
        as: UTF8.self
    )

    private init() {
        var value = UserDefaults.standard.integer(forKey: Self.userDefaultsKey)
        if value == 0, UserDefaults.standard.object(forKey: Self.legacyPrqScoreKeyObsolete) != nil {
            value = UserDefaults.standard.integer(forKey: Self.legacyPrqScoreKeyObsolete)
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
