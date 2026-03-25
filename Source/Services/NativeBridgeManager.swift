import Foundation
import Observation

@Observable
@MainActor
final class NativeBridgeManager {
    static let shared = NativeBridgeManager()

    private(set) var prqScore: Int
    private(set) var lastUpdateDate: Date?

    private init() {
        prqScore = PRQScoreManager.shared.currentPrqScore

        NotificationCenter.default.addObserver(
            forName: prqScoreUpdatedNotification,
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
            forName: prqScoreDidUpdateNotification,
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
        PRQScoreManager.shared.prqTier
    }

    var tierColor: String {
        PRQScoreManager.shared.tierColor
    }

    func simulateScore(_ score: Int) {
        PRQScoreManager.shared.simulateUnityScore(score)
    }
}
