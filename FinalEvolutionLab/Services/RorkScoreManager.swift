import Foundation

nonisolated let rorkScoreUpdatedNotification = NSNotification.Name("RorkScoreUpdated")
nonisolated let rorkScoreDidUpdateNotification = NSNotification.Name("rorkScoreDidUpdate")

@Observable
@MainActor
final class RorkScoreManager {
    static let shared = RorkScoreManager()

    static let userDefaultsKey = "rork_prq_score"

    private(set) var currentPrqScore: Int

    private init() {
        currentPrqScore = UserDefaults.standard.integer(forKey: Self.userDefaultsKey)
        if currentPrqScore == 0 {
            currentPrqScore = Int(PRQ.default)
        }

        NotificationCenter.default.addObserver(
            forName: rorkScoreUpdatedNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let score = notification.userInfo?["score"] as? Int else { return }
            MainActor.assumeIsolated {
                self.currentPrqScore = score
                UserDefaults.standard.set(score, forKey: RorkScoreManager.userDefaultsKey)
                NotificationCenter.default.post(name: rorkScoreDidUpdateNotification, object: nil, userInfo: ["score": score])
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
            name: rorkScoreUpdatedNotification,
            object: nil,
            userInfo: ["score": score]
        )
    }
}
