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
}
