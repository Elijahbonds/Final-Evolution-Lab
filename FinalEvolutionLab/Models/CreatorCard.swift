import Foundation
import SwiftUI

nonisolated struct CreatorCard: Identifiable, Sendable {
    let id: String
    let creatorName: String
    let title: String
    let description: String
    let costCredits: Int
    var costShards: Int { costCredits } // Legacy alias for older UI bindings.
    let iconName: String
    let accentColor: Color
    let metricsBoost: PerformanceMetrics
    let movementSignature: MovementSignature

    static let catalog: [CreatorCard] = [
        CreatorCard(
            id: "coach_v_elite",
            creatorName: "Coach V",
            title: "Coach V Elite Card",
            description: "Unlock Coach V's elite movement data. +15 PRQ, +20 Vertical, +10 Neural Drive.",
            costCredits: 500,
            iconName: "crown.fill",
            accentColor: .yellow,
            metricsBoost: PerformanceMetrics(
                efficiencyScore: 10,
                prqScore: 15,
                readinessScore: 5,
                verticalPotential: 20,
                neuralDrive: 10,
                currentOutfit: "coach_v"
            ),
            movementSignature: MovementSignature(
                style: .explosive,
                jumpApex: 1.3,
                hangTimeFactor: 1.4,
                firstStepBurst: 1.2,
                limbEmission: 0.5,
                trailColor: .yellow
            )
        ),
        CreatorCard(
            id: "bonds_bounce",
            creatorName: "Bonds Bounce",
            title: "Bonds Bounce Blueprint",
            description: "The vertical jump architecture. +12 PRQ, +25 Vertical, +8 Efficiency.",
            costCredits: 750,
            iconName: "bolt.trianglebadge.exclamationmark.fill",
            accentColor: Color(red: 0.95, green: 0.49, blue: 0.15),
            metricsBoost: PerformanceMetrics(
                efficiencyScore: 8,
                prqScore: 12,
                readinessScore: 5,
                verticalPotential: 25,
                neuralDrive: 8,
                currentOutfit: "bonds_bounce"
            ),
            movementSignature: MovementSignature(
                style: .vertical,
                jumpApex: 1.5,
                hangTimeFactor: 1.6,
                firstStepBurst: 1.0,
                limbEmission: 0.6,
                trailColor: Color(red: 0.95, green: 0.49, blue: 0.15)
            )
        ),
        CreatorCard(
            id: "flight_lab",
            creatorName: "Flight Lab",
            title: "Flight Lab Pro Card",
            description: "Advanced flight mechanics data. +10 PRQ, +18 Vertical, +15 Neural Drive.",
            costCredits: 600,
            iconName: "airplane.departure",
            accentColor: Color(red: 0, green: 0.95, blue: 0.9),
            metricsBoost: PerformanceMetrics(
                efficiencyScore: 5,
                prqScore: 10,
                readinessScore: 8,
                verticalPotential: 18,
                neuralDrive: 15,
                currentOutfit: "flight_lab"
            ),
            movementSignature: MovementSignature(
                style: .fluid,
                jumpApex: 1.2,
                hangTimeFactor: 1.8,
                firstStepBurst: 1.1,
                limbEmission: 0.7,
                trailColor: Color(red: 0, green: 0.95, blue: 0.9)
            )
        ),
        CreatorCard(
            id: "neural_max",
            creatorName: "Neural Max",
            title: "Neural Max Override",
            description: "Peak CNS recruitment protocols. +8 PRQ, +12 Vertical, +25 Neural Drive.",
            costCredits: 400,
            iconName: "brain.head.profile.fill",
            accentColor: Color(red: 0.6, green: 0.2, blue: 1.0),
            metricsBoost: PerformanceMetrics(
                efficiencyScore: 5,
                prqScore: 8,
                readinessScore: 10,
                verticalPotential: 12,
                neuralDrive: 25,
                currentOutfit: "neural_max"
            ),
            movementSignature: MovementSignature(
                style: .neural,
                jumpApex: 1.1,
                hangTimeFactor: 1.2,
                firstStepBurst: 1.5,
                limbEmission: 0.9,
                trailColor: Color(red: 0.6, green: 0.2, blue: 1.0)
            )
        ),
    ]
}

nonisolated struct MovementSignature: Sendable {
    let style: MovementStyle
    let jumpApex: Double
    let hangTimeFactor: Double
    let firstStepBurst: Double
    let limbEmission: Double
    let trailColor: Color
}

nonisolated enum MovementStyle: String, Sendable {
    case explosive
    case vertical
    case fluid
    case neural
    case standard

    var animationSpeed: Double {
        switch self {
        case .explosive: 0.8
        case .vertical: 1.0
        case .fluid: 1.2
        case .neural: 0.7
        case .standard: 1.0
        }
    }
}
