import Foundation

nonisolated struct PerformanceMetrics: Codable, Sendable {
    var efficiencyScore: Double
    var prqScore: Double
    var readinessScore: Double
    var verticalPotential: Double
    var neuralDrive: Double
    /// Pop Force: elastic reactivity & ground-contact efficiency (RFD + GRF). 0–100.
    var popForce: Double
    var currentOutfit: String

    static let empty = PerformanceMetrics(
        efficiencyScore: 0,
        prqScore: PRQ.default,
        readinessScore: 0,
        verticalPotential: 0,
        neuralDrive: 0,
        popForce: 0,
        currentOutfit: "standard"
    )

    init(efficiencyScore: Double, prqScore: Double, readinessScore: Double, verticalPotential: Double, neuralDrive: Double, popForce: Double, currentOutfit: String) {
        self.efficiencyScore = efficiencyScore
        self.prqScore = prqScore
        self.readinessScore = readinessScore
        self.verticalPotential = verticalPotential
        self.neuralDrive = neuralDrive
        self.popForce = popForce
        self.currentOutfit = currentOutfit
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        efficiencyScore = try c.decode(Double.self, forKey: .efficiencyScore)
        let rawPrq = (try? c.decode(Double.self, forKey: .prqScore)) ?? PRQ.default
        prqScore = PRQ.clamp(rawPrq.isFinite ? rawPrq : PRQ.default)
        readinessScore = try c.decode(Double.self, forKey: .readinessScore)
        verticalPotential = try c.decode(Double.self, forKey: .verticalPotential)
        neuralDrive = try c.decode(Double.self, forKey: .neuralDrive)
        popForce = (try? c.decode(Double.self, forKey: .popForce)) ?? 0
        currentOutfit = try c.decode(String.self, forKey: .currentOutfit)
    }
}
