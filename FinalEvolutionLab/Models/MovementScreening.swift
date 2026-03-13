import Foundation

nonisolated enum MovementScreenKind: String, Codable, Sendable, CaseIterable {
    case fms = "FMS"
    case sfma = "SFMA"
    case fcs = "FCS"
    case frc = "FRC"
}

nonisolated enum MovementRiskBand: String, Codable, Sendable {
    case low
    case moderate
    case high
}

nonisolated struct MovementScreenItem: Codable, Sendable, Identifiable {
    let id: String
    let title: String
    let score: Double
    let maxScore: Double
    let notes: String
}

nonisolated struct MovementScreenResult: Codable, Sendable, Identifiable {
    let id: String
    let kind: MovementScreenKind
    let totalScore: Double
    let maxScore: Double
    let riskBand: MovementRiskBand
    let items: [MovementScreenItem]

    var percent: Double {
        guard maxScore > 0 else { return 0 }
        return min(1.0, max(0, totalScore / maxScore))
    }
}

nonisolated enum MovementDysfunctionSeverity: String, Codable, Sendable {
    case mild
    case moderate
    case severe
}

nonisolated struct MovementDysfunction: Codable, Sendable, Identifiable {
    let id: String
    let title: String
    let severity: MovementDysfunctionSeverity
    let confidence: Double
    let sourceScreens: [MovementScreenKind]
    let clinicalSummary: String
    let correctiveFocus: [String]
}

nonisolated struct StressTestCapture: Codable, Sendable {
    let clipDurationSeconds: Double
    let frameRate: Double
    let estimatedRepCount: Int
    let burstRatePerMinute: Double
    let fatigueIndex: Double
    let asymmetryIndex: Double
    let landingStability: Double
    let effortIndex: Double
}

nonisolated struct MovementCaptureSample: Codable, Sendable {
    let ankleControl: Double
    let kneeControl: Double
    let hipControl: Double
    let trunkControl: Double
    let decelerationControl: Double
    let mobilityBandwidth: Double
}

nonisolated struct WorkoutPrescription: Codable, Sendable {
    let trainingTrack: TrainingTrack
    let equipmentFocus: EquipmentType
    let rationale: String
    let priorityBlocks: [String]
}

nonisolated struct MovementScreeningReport: Codable, Sendable {
    let stressTest: StressTestCapture
    let movementCapture: MovementCaptureSample
    let screenResults: [MovementScreenResult]
    let dysfunctions: [MovementDysfunction]
    let prescription: WorkoutPrescription
    let confidence: Double
}
