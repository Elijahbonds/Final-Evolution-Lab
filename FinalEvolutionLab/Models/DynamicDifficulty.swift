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

    static func opponentSuccessChance(baseChance: Double, playerScore: Int, aiScore: Int, sessionReadiness: Double, playerPRQ: Double = PRQ.default) -> Double {
        let dda = aggression(playerScore: playerScore, aiScore: aiScore)
        let readinessModifier = 1.0 - (sessionReadiness / 350.0)
        let prqPressure = 1.0 - (min(max(playerPRQ, 0), 100) / 400.0)
        return min(0.80, baseChance * dda * readinessModifier * prqPressure)
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

    static func getDDAWindowScale(playerScore: Int, aiScore: Int, targetScore: Int) -> Double {
        guard targetScore > 0 else { return 1.0 }
        let playerProgress = Double(playerScore) / Double(targetScore)
        let aiProgress = Double(aiScore) / Double(targetScore)
        let gap = aiProgress - playerProgress

        if gap > 0.25 {
            return 1.35
        } else if gap > 0.1 {
            return 1.15
        } else if gap < -0.25 {
            return 0.75
        } else if gap < -0.1 {
            return 0.9
        }
        return 1.0
    }

    static func scaledSuccessWindow(
        baseWindow: Double,
        playerScore: Int,
        aiScore: Int,
        targetScore: Int,
        mode: GameModeId
    ) -> Double {
        let windowScale = getDDAWindowScale(playerScore: playerScore, aiScore: aiScore, targetScore: targetScore)
        let modeAdjust: Double
        switch mode {
        case .baseball: modeAdjust = 1.1
        case .golf: modeAdjust = 0.9
        case .football: modeAdjust = 1.2
        case .soccer: modeAdjust = 1.0
        case .tennis: modeAdjust = 1.0
        case .volleyball: modeAdjust = 1.05
        default: modeAdjust = 1.0
        }
        return baseWindow * windowScale * modeAdjust
    }

    static func scaledOpponentChance(
        baseChance: Double,
        playerScore: Int,
        aiScore: Int,
        sessionReadiness: Double,
        targetScore: Int,
        consecutivePlayerWins: Int,
        playerPRQ: Double = PRQ.default
    ) -> Double {
        let base = opponentSuccessChance(
            baseChance: baseChance,
            playerScore: playerScore,
            aiScore: aiScore,
            sessionReadiness: sessionReadiness,
            playerPRQ: playerPRQ
        )
        let rubber = rubberBandFactor(playerScore: playerScore, aiScore: aiScore, targetScore: targetScore)
        let momentum = momentumBonus(consecutiveWins: consecutivePlayerWins)
        return min(0.9, base * rubber / momentum)
    }

    static func prqScaledOpponentMaxPoints(playerPRQ: Double, mode: GameModeId, maxPoints: Int = 3) -> Int {
        let normalized = min(max(playerPRQ / 100.0, 0), 1)
        let modeScale: Double
        switch mode {
        case .basketballHeadToHead, .basketball3v3: modeScale = 1.0
        case .basketballDunkContest: modeScale = 0.8
        case .karate, .karateEndless: modeScale = 1.2
        case .baseball: modeScale = 0.7
        case .football: modeScale = 1.5
        case .soccer: modeScale = 0.9
        case .golf: modeScale = 0.6
        case .tennis: modeScale = 0.9
        case .volleyball: modeScale = 1.0
        case .gymnastics: modeScale = 0.8
        case .surfing, .skateboarding, .snowboarding: modeScale = 0.95
        case .brainBrawl, .whoSceneIt: modeScale = 0.85
        case .courtCarnival: modeScale = 1.0
        case .marketBrowse: modeScale = 0.5
        }
        let scaled = Double(maxPoints) * modeScale * (0.6 + normalized * 0.4)
        return max(1, Int(scaled.rounded()))
    }
}

nonisolated struct PRQDrivenDDA: Sendable {
    let playerPRQ: Double
    let neuralDrive: Double
    let mode: GameModeId

    var prqNormalized: Double { min(max(playerPRQ / 100.0, 0), 1) }
    var neuralNormalized: Double { min(max(neuralDrive / 100.0, 0), 1) }

    var aiAggressionFloor: Double {
        0.4 + prqNormalized * 0.3
    }

    var aiAggressionCeiling: Double {
        1.0 + prqNormalized * 0.5
    }

    func scaledAggression(playerScore: Int, aiScore: Int) -> Double {
        let base = DynamicDifficulty.aggression(playerScore: playerScore, aiScore: aiScore)
        let prqScale = 0.7 + prqNormalized * 0.6
        let neuralPressure = neuralNormalized > 0.8 ? 1.15 : 1.0
        return min(aiAggressionCeiling, max(aiAggressionFloor, base * prqScale * neuralPressure))
    }

    func aiReactionSpeed(playerScore: Int, aiScore: Int) -> Double {
        let baseDelay = DynamicDifficulty.aiResponseDelay(playerScore: playerScore, aiScore: aiScore)
        let prqReduction = prqNormalized * 0.3
        return max(0.1, baseDelay - prqReduction)
    }

    func qteWindowScale(playerScore: Int, aiScore: Int, targetScore: Int) -> Double {
        let base = DynamicDifficulty.getDDAWindowScale(playerScore: playerScore, aiScore: aiScore, targetScore: targetScore)
        let prqShrink = 1.0 - prqNormalized * 0.15
        return base * prqShrink
    }

    func aiComboChance(playerScore: Int, aiScore: Int) -> Double {
        let aggression = scaledAggression(playerScore: playerScore, aiScore: aiScore)
        let baseCombo = 0.1 + prqNormalized * 0.25
        return min(0.6, baseCombo * aggression)
    }

    func aiSpecialMeterRate(playerScore: Int, aiScore: Int) -> Double {
        let aggression = scaledAggression(playerScore: playerScore, aiScore: aiScore)
        return 5.0 + aggression * 8.0 + prqNormalized * 4.0
    }

    func aiBlockChance(playerScore: Int, aiScore: Int) -> Double {
        let aggression = scaledAggression(playerScore: playerScore, aiScore: aiScore)
        let base = 0.15 + prqNormalized * 0.2
        return min(0.55, base * aggression)
    }

    var difficultyTier: DifficultyTier {
        switch prqNormalized {
        case 0.9...: return .legendary
        case 0.75..<0.9: return .elite
        case 0.55..<0.75: return .competitive
        case 0.35..<0.55: return .developing
        default: return .rookie
        }
    }
}

nonisolated enum DifficultyTier: String, Sendable {
    case rookie = "ROOKIE"
    case developing = "DEVELOPING"
    case competitive = "COMPETITIVE"
    case elite = "ELITE"
    case legendary = "LEGENDARY"

    var aiPatternComplexity: Int {
        switch self {
        case .rookie: return 1
        case .developing: return 2
        case .competitive: return 3
        case .elite: return 4
        case .legendary: return 5
        }
    }

    var aiFeintChance: Double {
        switch self {
        case .rookie: return 0.0
        case .developing: return 0.1
        case .competitive: return 0.2
        case .elite: return 0.35
        case .legendary: return 0.5
        }
    }

    var counterWindowShrink: Double {
        switch self {
        case .rookie: return 1.3
        case .developing: return 1.15
        case .competitive: return 1.0
        case .elite: return 0.85
        case .legendary: return 0.7
        }
    }
}
