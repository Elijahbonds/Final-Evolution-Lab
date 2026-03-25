import Foundation

nonisolated enum PRQ: Sendable {
    static let min: Double = 0
    static let max: Double = 100
    static let `default`: Double = 75
    static let legendaryThreshold: Double = 95

    static func clamp(_ value: Double) -> Double {
        guard value.isFinite else { return `default` }
        return Swift.min(`max`, Swift.max(`min`, value))
    }

    static func fromVerticalInches(_ verticalInches: Double) -> Int {
        Int(round(FELPRQScanFormula.scoreFromVerticalInches(verticalInches)))
    }

    static func matchReward(won: Bool, tied: Bool) -> Double {
        if won { return 2.0 }
        if tied { return 0.5 }
        return 0.2
    }

    static func modeReward(mode: GameModeId, won: Bool, tied: Bool, combo: Int, criticals: Int, scoreDifferential: Int) -> Double {
        let base = matchReward(won: won, tied: tied)
        let modeMultiplier = modeWeight(for: mode)
        let comboBonus = Swift.min(1.0, Double(combo) * 0.05)
        let criticalBonus = Swift.min(0.5, Double(criticals) * 0.1)
        let dominanceBonus = won ? Swift.min(0.5, Double(Swift.max(0, scoreDifferential)) * 0.05) : 0
        let raw = base * modeMultiplier + comboBonus + criticalBonus + dominanceBonus
        let minimumParticipation: Double = 0.1
        return clamp(Swift.max(minimumParticipation, raw))
    }

    static func modeWeight(for mode: GameModeId) -> Double {
        switch mode {
        case .basketballHeadToHead: 1.2
        case .basketballDunkContest: 1.0
        case .basketball3v3: 1.3
        case .karate: 1.4
        case .baseball: 1.0
        case .football: 1.5
        case .soccer: 1.1
        case .golf: 0.9
        case .tennis: 1.1
        case .volleyball: 1.2
        case .gymnastics: 1.0
        case .brainBrawl: 0.95
        }
    }

    /// Win chance per round: PRQ 50 ≈ 58–62%, 75 ≈ 72–76%, 90 ≈ 84–88% by mode. Floor and ceiling keep games fair.
    static func successChanceFromPRQ(_ prq: Double, for mode: GameModeId) -> Double {
        let safe = prq.isFinite ? prq : `default`
        let normalized = Swift.min(Swift.max(safe / 100.0, 0), 1)
        let (modeBase, ceiling): (Double, Double)
        switch mode {
        case .basketballHeadToHead, .basketball3v3: (modeBase, ceiling) = (0.34, 0.88)
        case .basketballDunkContest: (modeBase, ceiling) = (0.36, 0.90)
        case .karate: (modeBase, ceiling) = (0.30, 0.86)
        case .baseball: (modeBase, ceiling) = (0.28, 0.84)
        case .football: (modeBase, ceiling) = (0.32, 0.88)
        case .soccer: (modeBase, ceiling) = (0.32, 0.86)
        case .golf: (modeBase, ceiling) = (0.26, 0.82)
        case .tennis: (modeBase, ceiling) = (0.32, 0.86)
        case .volleyball: (modeBase, ceiling) = (0.34, 0.88)
        case .gymnastics: (modeBase, ceiling) = (0.28, 0.84)
        case .brainBrawl: (modeBase, ceiling) = (0.30, 0.86)
        }
        let raw = modeBase + normalized * (ceiling - modeBase)
        return Swift.min(Swift.max(raw, 0.18), 0.92)
    }

    static func attributeLabel(for mode: GameModeId) -> String {
        switch mode {
        case .basketballHeadToHead, .basketball3v3: "Court IQ"
        case .basketballDunkContest: "Hang Time"
        case .karate: "Fight IQ"
        case .baseball: "Bat Speed"
        case .football: "Burst Speed"
        case .soccer: "Shot Accuracy"
        case .golf: "Swing Precision"
        case .tennis: "Rally Control"
        case .volleyball: "Spike Power"
        case .gymnastics: "Form Score"
        case .brainBrawl: "Brain Speed"
        }
    }

    static func attributeValue(prq: Double, for mode: GameModeId) -> Double {
        let safe = prq.isFinite ? prq : `default`
        let normalized = Swift.min(Swift.max(safe / 100.0, 0), 1)
        let modeScale: Double
        switch mode {
        case .basketballHeadToHead, .basketball3v3: modeScale = 0.85
        case .basketballDunkContest: modeScale = 0.90
        case .karate: modeScale = 0.80
        case .baseball: modeScale = 0.75
        case .football: modeScale = 0.80
        case .soccer: modeScale = 0.78
        case .golf: modeScale = 0.70
        case .tennis: modeScale = 0.78
        case .volleyball: modeScale = 0.82
        case .gymnastics: modeScale = 0.75
        case .brainBrawl: modeScale = 0.78
        }
        return (modeScale * normalized * 100).rounded() / 100
    }
}
