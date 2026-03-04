import Foundation

nonisolated struct DynamicDifficulty: Sendable {
    static let maxAggression: Double = 1.4
    static let minAggression: Double = 0.6

    static func aggression(playerScore: Int, aiScore: Int) -> Double {
        let gap = Double(playerScore - aiScore)
        if gap >= 5 { return maxAggression }
        if gap <= -5 { return minAggression }
        let t = (gap + 5) / 10
        return minAggression + t * (maxAggression - minAggression)
    }

    static func opponentSuccessChance(baseChance: Double, playerScore: Int, aiScore: Int, sessionReadiness: Double) -> Double {
        let dda = aggression(playerScore: playerScore, aiScore: aiScore)
        let readinessModifier = 1.0 - (sessionReadiness / 400.0)
        return min(0.85, baseChance * dda * readinessModifier)
    }

    static func opponentPoints(playerScore: Int, aiScore: Int, maxPoints: Int = 3) -> Int {
        let dda = aggression(playerScore: playerScore, aiScore: aiScore)
        let scaledMax = max(1, Int(Double(maxPoints) * dda))
        return Int.random(in: 1...scaledMax)
    }

    static func damageMultiplier(playerScore: Int, aiScore: Int) -> Double {
        let dda = aggression(playerScore: playerScore, aiScore: aiScore)
        return 0.8 + dda * 0.4
    }

    static func aiResponseDelay(playerScore: Int, aiScore: Int) -> Double {
        let dda = aggression(playerScore: playerScore, aiScore: aiScore)
        let baseDelay = 0.8
        return max(0.2, baseDelay - (dda - 1.0) * 0.5)
    }

    static func momentumBonus(consecutiveWins: Int) -> Double {
        let capped = min(consecutiveWins, 5)
        return 1.0 + Double(capped) * 0.08
    }

    static func rubberBandFactor(playerScore: Int, aiScore: Int, targetScore: Int) -> Double {
        guard targetScore > 0 else { return 1.0 }
        let playerProgress = Double(playerScore) / Double(targetScore)
        let aiProgress = Double(aiScore) / Double(targetScore)
        let progressGap = playerProgress - aiProgress

        if progressGap > 0.3 {
            return 1.3
        } else if progressGap < -0.3 {
            return 0.7
        }
        return 1.0
    }

    static func scaledOpponentChance(
        baseChance: Double,
        playerScore: Int,
        aiScore: Int,
        sessionReadiness: Double,
        targetScore: Int,
        consecutivePlayerWins: Int
    ) -> Double {
        let base = opponentSuccessChance(
            baseChance: baseChance,
            playerScore: playerScore,
            aiScore: aiScore,
            sessionReadiness: sessionReadiness
        )
        let rubber = rubberBandFactor(playerScore: playerScore, aiScore: aiScore, targetScore: targetScore)
        let momentum = momentumBonus(consecutiveWins: consecutivePlayerWins)
        return min(0.9, base * rubber / momentum)
    }
}
