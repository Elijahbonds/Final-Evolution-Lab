import Foundation

nonisolated struct MatchReport: Sendable {
    let roundScores: [(home: Int, away: Int)]
    let trickHighlights: [String]
    let efficiencyRating: Double  // 0-100

    var winningSide: String {
        let homeTotal = roundScores.reduce(0) { $0 + $1.home }
        let awayTotal = roundScores.reduce(0) { $0 + $1.away }
        if homeTotal > awayTotal { return "home" }
        if awayTotal > homeTotal { return "away" }
        return "tie"
    }
}

/// Shared head-to-head result rules (player vs opponent columns in ``GamePlayView``).
nonisolated enum VersusMatchOutcome {
    enum Side: Sendable {
        case playerWins
        case opponentWins
        case draw
    }

    static func playerWins(playerScore: Int, opponentScore: Int) -> Bool {
        playerScore > opponentScore
    }

    static func didTie(playerScore: Int, opponentScore: Int) -> Bool {
        playerScore == opponentScore
    }

    static func winnerSide(playerScore: Int, opponentScore: Int) -> Side {
        if didTie(playerScore: playerScore, opponentScore: opponentScore) { return .draw }
        if playerWins(playerScore: playerScore, opponentScore: opponentScore) { return .playerWins }
        return .opponentWins
    }

    /// Shards / PRQ helpers: `won` means player column beat opponent column.
    static func rewardFlags(playerScore: Int, opponentScore: Int) -> (won: Bool, tied: Bool) {
        (
            playerWins(playerScore: playerScore, opponentScore: opponentScore),
            didTie(playerScore: playerScore, opponentScore: opponentScore)
        )
    }
}

extension VersusMatchOutcome {
    /// XP earned for the player given match outcome, optional streak, and optional PRQ delta.
    /// - Parameters:
    ///   - side: The resolved ``Side`` for the player.
    ///   - streakDays: Consecutive win-streak days; capped contribution at 50 XP bonus.
    ///   - prqDelta: Change in PRQ earned this match; contributes 5 XP per point.
    static func xpEarned(side: Side, streakDays: Int = 0, prqDelta: Double = 0) -> Int {
        let base: Int
        switch side {
        case .playerWins: base = 100
        case .draw:       base = 50
        case .opponentWins: base = 25
        }
        let streakBonus = min(50, streakDays * 10)
        let prqBonus = Int(max(0, prqDelta) * 5)
        return base + streakBonus + prqBonus
    }

    /// Shards earned for the player given match outcome.
    static func shardsEarned(side: Side) -> Int {
        switch side {
        case .playerWins:   return 50
        case .draw:         return 25
        case .opponentWins: return 15
        }
    }
}
