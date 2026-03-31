import Foundation

enum PRQ: Sendable {
    static let min: Double = 0
    static let max: Double = 100
    static let `default`: Double = 75
    static let legendaryThreshold: Double = 95

    static func clamp(_ value: Double) -> Double {
        guard value.isFinite else { return `default` }
        return Swift.min(`max`, Swift.max(`min`, value))
    }

    static func fromVerticalInches(_ verticalInches: Double) -> Int {
        guard verticalInches.isFinite, verticalInches >= 0 else { return Int(`default`) }
        let normalized = (verticalInches - 15) / 35
        let raw = 50 + normalized * 50
        return Int(round(clamp(raw)))
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
        return clamp(base * modeMultiplier + comboBonus + criticalBonus + dominanceBonus)
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
        }
    }

    static func successChanceFromPRQ(_ prq: Double, for mode: GameModeId) -> Double {
        let normalized = Swift.min(Swift.max(prq / 100.0, 0), 1)
        let modeBase: Double
        switch mode {
        case .basketballHeadToHead, .basketball3v3: modeBase = 0.40
        case .basketballDunkContest: modeBase = 0.45
        case .karate: modeBase = 0.38
        case .baseball: modeBase = 0.35
        case .football: modeBase = 0.42
        case .soccer: modeBase = 0.40
        case .golf: modeBase = 0.30
        case .tennis: modeBase = 0.38
        case .volleyball: modeBase = 0.40
        case .gymnastics: modeBase = 0.35
        }
        return modeBase + normalized * (0.90 - modeBase)
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
        }
    }

    static func attributeValue(prq: Double, for mode: GameModeId) -> Double {
        let normalized = Swift.min(Swift.max(prq / 100.0, 0), 1)
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
        }
        return (modeScale * normalized * 100).rounded() / 100
    }
}
