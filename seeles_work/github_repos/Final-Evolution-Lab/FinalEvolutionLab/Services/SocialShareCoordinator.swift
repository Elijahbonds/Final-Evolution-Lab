import Foundation
import Combine

/// Draft shown in ``SocialPostComposerSheet`` after a game result or scan achievement.
struct SocialFeedDraft: Identifiable {
    let id = UUID()
    var content: String
    var gameModeId: String?
    var trainingScore: Double?
    var clipUrl: String?
    var feedSource: String
}

@MainActor
final class SocialShareCoordinator: ObservableObject {
    static let shared = SocialShareCoordinator()

    @Published var composerDraft: SocialFeedDraft?

    private init() {}

    func presentGameResult(gameModeId: String, score: Double?, clipUrl: String?) {
        let scoreText = score.map { String(format: "%.1f", $0) } ?? "—"
        composerDraft = SocialFeedDraft(
            content: "Finished \(gameModeId.replacingOccurrences(of: "_", with: " ")) — score \(scoreText)",
            gameModeId: gameModeId,
            trainingScore: score,
            clipUrl: clipUrl,
            feedSource: "game_mode"
        )
    }

    func presentScanAchievement(prq: Double, grade: String) {
        composerDraft = SocialFeedDraft(
            content: "System scan: PRQ \(String(format: "%.1f", prq)) · \(grade)",
            gameModeId: nil,
            trainingScore: prq,
            clipUrl: nil,
            feedSource: "system_scan"
        )
    }

    func dismissComposer() {
        composerDraft = nil
    }
}
