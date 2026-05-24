import Foundation

/// Staged cue sequence for **Drawing In** + staggered V myofascial hip release (Bonds Standard).
/// Guided **Bonds Standard Coach** flow (staggered V → rotation → hike → tuck → TA drawing-in).
nonisolated enum BondsStandardCoachStep: Int, CaseIterable, Identifiable, Sendable {
    case staggeredV = 0
    case internalRotation = 1
    case hipHike = 2
    case replaceDownTuck = 3
    case drawingInCore = 4

    var id: Int { rawValue }

    var cardTitle: String {
        switch self {
        case .staggeredV: return "THE STAGGERED V"
        case .internalRotation: return "INTERNAL ROTATION"
        case .hipHike: return "HIP HIKE"
        case .replaceDownTuck: return "REPLACE ↓"
        case .drawingInCore: return "DRAWING IN"
        }
    }

    var prompt: String {
        switch self {
        case .staggeredV:
            return "Staggered V: anchor the feet into the holographic V — pelvis open, rear side loaded."
        case .internalRotation:
            return "Rear femur internally rotates — spiral inward until the thigh reads STABLE (blue), not leakage (red)."
        case .hipHike:
            return "Hike the hip — load fascial tension hip → rib cage before the tuck."
        case .replaceDownTuck:
            return "Replace the Up with the Down."
        case .drawingInCore:
            return "Brace the corset — Transverse Abdominis drawing-in with IAP."
        }
    }

    var anatomyHint: String? {
        switch self {
        case .internalRotation:
            return "Visual tension: adductors & lateral line — spiral the rear femur inward."
        case .hipHike:
            return "Fascial line: hip → obliques / QL."
        case .drawingInCore:
            return "Slow exhale — ribs stay wide while the corset tightens."
        default:
            return nil
        }
    }
}

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
