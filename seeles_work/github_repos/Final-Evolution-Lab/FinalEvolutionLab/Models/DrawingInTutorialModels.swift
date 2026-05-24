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
