import Foundation

nonisolated struct PerformanceMetrics: Codable, Sendable {
    var efficiencyScore: Double
    var prqScore: Double
    var readinessScore: Double
    var verticalPotential: Double
    var neuralDrive: Double
    var currentOutfit: String

    static let empty = PerformanceMetrics(
        efficiencyScore: 0,
        prqScore: PRQ.default,
        readinessScore: 0,
        verticalPotential: 0,
        neuralDrive: 0,
        currentOutfit: "standard"
    )
}

nonisolated enum TrendDirection: String, Sendable {
    case improving = "Improving"
    case stable = "Stable"
    case declining = "Declining"
}

nonisolated struct PerformanceTrend: Sendable {
    let direction: TrendDirection
    let metric: String
    let changePercent: Double

    static func compute(sessions: [Double], metric: String) -> PerformanceTrend {
        guard sessions.count >= 2 else {
            return PerformanceTrend(direction: .stable, metric: metric, changePercent: 0)
        }
        let recent = sessions.suffix(7)
        guard let first = recent.first, let last = recent.last, first > 0 else {
            return PerformanceTrend(direction: .stable, metric: metric, changePercent: 0)
        }
        let change = ((last - first) / first) * 100
        let direction: TrendDirection
        if change > 2.5 {
            direction = .improving
        } else if change < -2.5 {
            direction = .declining
        } else {
            direction = .stable
        }
        return PerformanceTrend(direction: direction, metric: metric, changePercent: change)
    }
}

nonisolated struct WeeklyPRQSummary: Sendable {
    let sessions: [Double]

    var weeklyPeakPRQ: Double {
        sessions.max() ?? 0.0
    }

    var weeklyLowPRQ: Double {
        sessions.min() ?? 0.0
    }

    var trend: PerformanceTrend {
        PerformanceTrend.compute(sessions: sessions, metric: "PRQ")
    }
}
