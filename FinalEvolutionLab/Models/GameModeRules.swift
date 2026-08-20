import Foundation

/// Duration / rounds / win rules keyed by mode — **not** derived from ``GameMode/multiplayerType``.
nonisolated struct GameModeRules: Sendable {
    /// Wall-clock countdown shown in HUD (vs round-based / target-score flows).
    let useMatchCountdown: Bool
    let matchDurationSeconds: Int
    let roundLimit: Int
    let usesTargetScoreWin: Bool
    let targetScore: Int

    /// Minimum engaged actions before loss rewards count as participation (anti idle-farm).
    let rewardEligibleMinActions: Int

    static func forMode(_ mode: GameModeId) -> GameModeRules {
        switch mode {
        case .basketballHeadToHead, .venicePickup:
            return GameModeRules(
                useMatchCountdown: false,
                matchDurationSeconds: 0,
                roundLimit: 1,
                usesTargetScoreWin: true,
                targetScore: 21,
                rewardEligibleMinActions: 5
            )
        case .basketball3v3:
            return GameModeRules(
                useMatchCountdown: true,
                matchDurationSeconds: 120,
                roundLimit: 24,
                usesTargetScoreWin: true,
                targetScore: 21,
                rewardEligibleMinActions: 6
            )
        case .basketballDunkContestIRL, .basketballDunkContest3D:
            return GameModeRules(
                useMatchCountdown: false,
                matchDurationSeconds: 0,
                roundLimit: 3,
                usesTargetScoreWin: false,
                targetScore: 0,
                rewardEligibleMinActions: 4
            )
        case .karate:
            return GameModeRules(
                useMatchCountdown: true,
                matchDurationSeconds: 90,
                roundLimit: 99,
                usesTargetScoreWin: false,
                targetScore: 0,
                rewardEligibleMinActions: 6
            )
        case .karateEndless:
            return GameModeRules(
                useMatchCountdown: true,
                matchDurationSeconds: 240,
                roundLimit: 999,
                usesTargetScoreWin: false,
                targetScore: 0,
                rewardEligibleMinActions: 8
            )
        case .brainBrawl:
            return GameModeRules(
                useMatchCountdown: false,
                matchDurationSeconds: 0,
                roundLimit: 10,
                usesTargetScoreWin: false,
                targetScore: 0,
                rewardEligibleMinActions: 5
            )
        case .whoSceneIt:
            return GameModeRules(
                useMatchCountdown: false,
                matchDurationSeconds: 0,
                roundLimit: 7,
                usesTargetScoreWin: false,
                targetScore: 0,
                rewardEligibleMinActions: 5
            )
        case .courtCarnival:
            return GameModeRules(
                useMatchCountdown: false,
                matchDurationSeconds: 0,
                roundLimit: 5,
                usesTargetScoreWin: true,
                targetScore: 15,
                rewardEligibleMinActions: 6
            )
        case .surfing, .skateboarding, .snowboarding, .gymnastics:
            return GameModeRules(
                useMatchCountdown: false,
                matchDurationSeconds: 0,
                roundLimit: 6,
                usesTargetScoreWin: false,
                targetScore: 0,
                rewardEligibleMinActions: 5
            )
        case .tennis:
            return GameModeRules(
                useMatchCountdown: true,
                matchDurationSeconds: 120,
                roundLimit: 1,
                usesTargetScoreWin: false,
                targetScore: 0,
                rewardEligibleMinActions: 5
            )
        case .volleyball:
            return GameModeRules(
                useMatchCountdown: true,
                matchDurationSeconds: 90,
                roundLimit: 1,
                usesTargetScoreWin: false,
                targetScore: 0,
                rewardEligibleMinActions: 4
            )
        case .baseball:
            return GameModeRules(
                useMatchCountdown: false,
                matchDurationSeconds: 0,
                roundLimit: 5,
                usesTargetScoreWin: false,
                targetScore: 0,
                rewardEligibleMinActions: 6
            )
        case .football:
            return GameModeRules(
                useMatchCountdown: false,
                matchDurationSeconds: 0,
                roundLimit: 1,
                usesTargetScoreWin: false,
                targetScore: 0,
                rewardEligibleMinActions: 4
            )
        case .soccer:
            return GameModeRules(
                useMatchCountdown: false,
                matchDurationSeconds: 0,
                roundLimit: 5,
                usesTargetScoreWin: false,
                targetScore: 0,
                rewardEligibleMinActions: 5
            )
        case .golf:
            return GameModeRules(
                useMatchCountdown: false,
                matchDurationSeconds: 0,
                roundLimit: 9,
                usesTargetScoreWin: false,
                targetScore: 0,
                rewardEligibleMinActions: 6
            )
        case .marketBrowse, .movementLab:
            return GameModeRules(
                useMatchCountdown: false,
                matchDurationSeconds: 0,
                roundLimit: 1,
                usesTargetScoreWin: false,
                targetScore: 0,
                rewardEligibleMinActions: 0
            )
        }
    }
}
