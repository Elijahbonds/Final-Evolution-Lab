import Foundation

nonisolated struct RorkAthleteManifest: Codable, Sendable {
    let prqScore: Double
    let neuralDrive: Double
    let elasticity: Double
    let athleteTier: String

    static func from(metrics: PerformanceMetrics, arcade: ArcadePhysics) -> RorkAthleteManifest {
        let tier = PRQTier.fromPRQ(metrics.prqScore).rawValue.lowercased().capitalized
        // Map hang-time physics into a 0-100 elasticity input for Unity animation tuning.
        let elasticity = min(max((arcade.hangTimeMultiplier - 1.0) * 25.0, 0), 100)
        return RorkAthleteManifest(
            prqScore: metrics.prqScore,
            neuralDrive: metrics.neuralDrive,
            elasticity: elasticity,
            athleteTier: tier
        )
    }

    func toJSONString() -> String? {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
