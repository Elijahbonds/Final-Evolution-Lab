import Foundation

/// Staged cue sequence for **Drawing In** + staggered V myofascial hip release (Bonds Standard).
nonisolated enum DrawingInTutorialStage: Int, CaseIterable, Identifiable, Sendable {
    case torqueInternalRotation = 0
    case hipHikeLoading = 1
    case replaceDownTuck = 2

    var id: Int { rawValue }

    var shortTitle: String {
        switch self {
        case .torqueInternalRotation: return "TORQUE"
        case .hipHikeLoading: return "HIP HIKE"
        case .replaceDownTuck: return "REPLACE ↓"
        }
    }

    var headlineCue: String {
        switch self {
        case .torqueInternalRotation:
            return "Internally rotate the rear leg — release lateral line tension."
        case .hipHikeLoading:
            return "Hike the hip — create capsule space before the tuck."
        case .replaceDownTuck:
            return "Replace the Up with the Down — corset the trunk, drop the tuck."
        }
    }

    var detailCue: String {
        switch self {
        case .torqueInternalRotation:
            return "Torque phase: spiral the rear femur until the glow reads STABLE (blue), not LEAKAGE (red)."
        case .hipHikeLoading:
            return "Loading phase: lateral shift — fascial line hip → rib cage primes the obliques / QL."
        case .replaceDownTuck:
            return "Tuck / tensegrity: Transverse Abdominis drawing-in (corset), posterior pelvic tilt grounding into the floor."
        }
    }

    var educationalNote: String {
        switch self {
        case .torqueInternalRotation:
            return "Internal rotation reduces lateral compression so the hip can load cleanly."
        case .hipHikeLoading:
            return "We are creating space in the joint capsule before we tuck."
        case .replaceDownTuck:
            return "Staggered V + rotation optimizes the Bonds Standard for core stability and biotensegrity."
        }
    }
}

nonisolated enum TutorialPhase: String, Codable, Sendable, CaseIterable {
    case intro = "Intro"
    case demonstration = "Demonstration"
    case practice = "Practice"
    case assessment = "Assessment"

    var isInteractive: Bool {
        switch self {
        case .intro, .demonstration: return false
        case .practice, .assessment: return true
        }
    }

    var next: TutorialPhase? {
        switch self {
        case .intro: return .demonstration
        case .demonstration: return .practice
        case .practice: return .assessment
        case .assessment: return nil
        }
    }
}

nonisolated struct DrawingStroke: Codable, Sendable, Identifiable {
    let id: UUID
    let timestamp: Date
    let qualityScore: Double            // 0-100
    let biomechanicalCorrectnessPercent: Double  // 0-100
    let strokeDurationSeconds: Double

    init(qualityScore: Double, biomechanicalCorrectnessPercent: Double, strokeDurationSeconds: Double) {
        self.id = UUID()
        self.timestamp = Date()
        self.qualityScore = max(0, min(100, qualityScore))
        self.biomechanicalCorrectnessPercent = max(0, min(100, biomechanicalCorrectnessPercent))
        self.strokeDurationSeconds = strokeDurationSeconds
    }

    var combinedScore: Double {
        (qualityScore + biomechanicalCorrectnessPercent) / 2.0
    }
}

nonisolated struct DrawingSession: Codable, Sendable, Identifiable {
    let id: UUID
    var currentPhase: TutorialPhase
    var strokes: [DrawingStroke]
    let startedAt: Date

    init() {
        self.id = UUID()
        self.currentPhase = .intro
        self.strokes = []
        self.startedAt = Date()
    }

    var averageQuality: Double {
        guard !strokes.isEmpty else { return 0.0 }
        return strokes.reduce(0.0) { $0 + $1.qualityScore } / Double(strokes.count)
    }

    var averageBiomechanicalCorrectness: Double {
        guard !strokes.isEmpty else { return 0.0 }
        return strokes.reduce(0.0) { $0 + $1.biomechanicalCorrectnessPercent } / Double(strokes.count)
    }

    mutating func addStroke(_ stroke: DrawingStroke) {
        strokes.append(stroke)
    }

    mutating func advancePhase() {
        if let next = currentPhase.next {
            currentPhase = next
        }
    }
}
