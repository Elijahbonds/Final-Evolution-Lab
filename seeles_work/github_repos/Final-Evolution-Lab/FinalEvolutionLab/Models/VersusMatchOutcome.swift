import Foundation

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
