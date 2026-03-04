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
        prqScore: 0,
        readinessScore: 0,
        verticalPotential: 0,
        neuralDrive: 0,
        currentOutfit: "standard"
    )
}
