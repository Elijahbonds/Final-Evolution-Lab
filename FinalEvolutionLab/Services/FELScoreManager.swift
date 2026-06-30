import Foundation

nonisolated let felScoreUpdatedNotification = NSNotification.Name("FELScoreUpdated")
nonisolated let felScoreDidUpdateNotification = NSNotification.Name("felScoreDidUpdate")

@Observable
@MainActor
final class FELScoreManager {
    static let shared = FELScoreManager()

    static let userDefaultsKey = "fel_prq_score"

    private(set) var currentPrqScore: Int

    private init() {
        currentPrqScore = UserDefaults.standard.integer(forKey: Self.userDefaultsKey)
        if currentPrqScore == 0 {
            currentPrqScore = Int(PRQ.default)
        }

        NotificationCenter.default.addObserver(
            forName: felScoreUpdatedNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let score = notification.userInfo?["score"] as? Int else { return }
            MainActor.assumeIsolated {
                self.currentPrqScore = score
                UserDefaults.standard.set(score, forKey: FELScoreManager.userDefaultsKey)
                NotificationCenter.default.post(name: felScoreDidUpdateNotification, object: nil, userInfo: ["score": score])
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
            name: felScoreUpdatedNotification,
            object: nil,
            userInfo: ["score": score]
        )
    }

    /// Clamps to 0…100 then applies the same path as Unity / Emergent score updates.
    func applyClampedPrq(_ score: Int) {
        let clamped = min(100, max(0, score))
        simulateUnityScore(clamped)
    }
}
