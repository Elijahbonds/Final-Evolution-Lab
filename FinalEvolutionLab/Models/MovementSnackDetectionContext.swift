import Foundation

/// Optional pose / mesh signals used to gate prescriptions that require **real** trunk–pelvis context (not PRQ proxies).
nonisolated struct MovementSnackDetectionContext: Sendable {
    /// Normalized evidence of anterior pelvic tilt signal from pose/mesh (0…1). Nil = not measured this session.
    var anteriorPelvicTiltEvidence01: Double?
    /// Rib flare / thoracic compensation proxy (0…1).
    var ribFlareEvidence01: Double?
    /// Rear-leg internal rotation / torque integrity hint (0…1).
    var rearLegInternalRotation01: Double?
    /// Confidence that pose-derived metrics are trustworthy (0…1).
    var poseConfidence01: Double?
    /// Soft budget for mesh / tracking fidelity (0…1); UE can throttle fidelity when low.
    var meshMemoryBudget01: Double?
    var pressureRelease: PressureReleaseStatus?

    /// No pose pipeline — core–pelvic prescriptions must **not** be inferred from knee/hip leakage scores alone.
    static let unavailable = MovementSnackDetectionContext(
        anteriorPelvicTiltEvidence01: nil,
        ribFlareEvidence01: nil,
        rearLegInternalRotation01: nil,
        poseConfidence01: nil,
        meshMemoryBudget01: nil,
        pressureRelease: nil
    )

    /// Gate **core / pelvic / IAP** Movement Snacks: requires measurable APT or rib evidence plus minimum pose confidence.
    var qualifiesForCorePelvicPrescription: Bool {
        guard let conf = poseConfidence01, conf >= 0.38 else { return false }
        let apt = anteriorPelvicTiltEvidence01 ?? 0
        let rib = ribFlareEvidence01 ?? 0
        return apt >= 0.36 || rib >= 0.36
    }
}

nonisolated enum PressureReleaseStatus: String, Codable, Sendable {
    case unknown
    case open
    case braced
    case restricted
}

extension MovementSnackDetectionContext {
    /// Maps optional Firestore / scan stability snapshot into routing context.
    nonisolated static func fromStability(_ snapshot: BiomechanicsStabilitySnapshot?) -> MovementSnackDetectionContext {
        guard let s = snapshot else { return .unavailable }
        let pr = s.pressureReleaseRaw.flatMap(PressureReleaseStatus.init(rawValue:))
        return MovementSnackDetectionContext(
            anteriorPelvicTiltEvidence01: s.anteriorPelvicTiltEvidence01,
            ribFlareEvidence01: s.ribFlareEvidence01,
            rearLegInternalRotation01: s.rearLegInternalRotation01,
            poseConfidence01: s.poseConfidence01,
            meshMemoryBudget01: s.meshMemoryBudget01,
            pressureRelease: pr
        )
    }
}
