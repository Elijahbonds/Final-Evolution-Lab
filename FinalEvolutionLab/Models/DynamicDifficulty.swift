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
}
