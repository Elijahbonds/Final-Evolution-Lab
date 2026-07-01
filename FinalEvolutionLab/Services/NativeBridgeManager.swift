import Foundation

@Observable
@MainActor
final class NativeBridgeManager {
    static let shared = NativeBridgeManager()

    private(set) var prqScore: Int
    private(set) var lastUpdateDate: Date?

    private init() {
        prqScore = FELScoreManager.shared.currentPrqScore

        NotificationCenter.default.addObserver(
            forName: felScoreUpdatedNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let score = notification.userInfo?["score"] as? Int else { return }
            MainActor.assumeIsolated {
                self.prqScore = score
                self.lastUpdateDate = Date()
            }
        }

        NotificationCenter.default.addObserver(
            forName: felScoreDidUpdateNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let score = notification.userInfo?["score"] as? Int else { return }
            MainActor.assumeIsolated {
                self.prqScore = score
                self.lastUpdateDate = Date()
            }
        }
    }

    var prqTier: String {
        FELScoreManager.shared.prqTier
    }

    var tierColor: String {
        FELScoreManager.shared.tierColor
    }

    func simulateScore(_ score: Int) {
        FELScoreManager.shared.simulateUnityScore(score)
    }
}
