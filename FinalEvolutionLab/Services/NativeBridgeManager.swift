import Foundation

@Observable
@MainActor
final class NativeBridgeManager {
    static let shared = NativeBridgeManager()

    private(set) var prqScore: Int
    private(set) var lastUpdateDate: Date?

    private init() {
        prqScore = RorkScoreManager.shared.currentPrqScore

        NotificationCenter.default.addObserver(
            forName: RorkScoreManager.scoreUpdatedNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let score = notification.userInfo?["score"] as? Int else { return }
            self.prqScore = score
            self.lastUpdateDate = Date()
        }

        NotificationCenter.default.addObserver(
            forName: RorkScoreManager.scoreDidUpdateNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let score = notification.userInfo?["score"] as? Int else { return }
            self.prqScore = score
            self.lastUpdateDate = Date()
        }
    }

    var prqTier: String {
        RorkScoreManager.shared.prqTier
    }

    var tierColor: String {
        RorkScoreManager.shared.tierColor
    }

    func simulateScore(_ score: Int) {
        RorkScoreManager.shared.simulateUnityScore(score)
    }
}
