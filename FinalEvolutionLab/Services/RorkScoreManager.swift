import Foundation

@Observable
final class RorkScoreManager: @unchecked Sendable {
    static let shared = RorkScoreManager()

    static let scoreUpdatedNotification = NSNotification.Name("RorkScoreUpdated")
    static let scoreDidUpdateNotification = NSNotification.Name("rorkScoreDidUpdate")
    static let userDefaultsKey = "rork_prq_score"

    private(set) var currentPrqScore: Int

    private init() {
        currentPrqScore = UserDefaults.standard.integer(forKey: Self.userDefaultsKey)
        if currentPrqScore == 0 {
            currentPrqScore = Int(PRQ.default)
        }

        NotificationCenter.default.addObserver(
            forName: Self.scoreUpdatedNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let score = notification.userInfo?["score"] as? Int else { return }
            self.currentPrqScore = score
            UserDefaults.standard.set(score, forKey: Self.userDefaultsKey)
            NotificationCenter.default.post(name: Self.scoreDidUpdateNotification, object: nil, userInfo: ["score": score])
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
            name: Self.scoreUpdatedNotification,
            object: nil,
            userInfo: ["score": score]
        )
    }
}
