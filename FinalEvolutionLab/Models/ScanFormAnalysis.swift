import Foundation

/// Pure, deterministic biomechanics readouts for the Lift-App-parity scan surfaces
/// (3D replay, optimal-form overlay, body-segment measurements). All values are
/// derived from an existing ``SystemScanResult`` + ``BiomechanicsAudit`` — this type
/// adds NO new measurement, it only reshapes what the scan already produced into a
/// coaching-friendly form. Kept free of SwiftUI/SceneKit so it is unit-testable.
nonisolated struct ScanFormAnalysis: Sendable {
    /// One anatomical segment with a human label and its length in the avatar's
    /// normalized rig units (1.0 == baseline human proportion). `measured` marks
    /// whether the length is inferred from a real captured metric vs a rig default.
    struct Segment: Sendable, Equatable, Identifiable {
        let id: String
        let label: String
        /// Length in avatar-rig meters (matches ``NexusGameplayAvatarLoader`` capsule heights).
        let lengthMeters: Double
        /// Length as a percentage of the baseline proportion (100% == neutral rig).
        let proportionPercent: Double
        let measured: Bool
    }

    /// A tracked joint with its current angle, an ideal target, and a good/off verdict.
    struct JointReadout: Sendable, Equatable, Identifiable {
        enum Verdict: String, Sendable, Equatable {
            case good        // within tolerance of ideal
            case watch       // moderate deviation
            case off         // outside tolerance — highlight in overlay
        }
        let id: String
        let label: String
        let angleDeg: Double
        let idealDeg: Double
        let verdict: Verdict
        /// Signed deviation from ideal (angle − ideal), degrees.
        var deviationDeg: Double { angleDeg - idealDeg }
    }

    let segments: [Segment]
    let joints: [JointReadout]
    /// Kinetic-leakage callouts lifted straight from ``BiomechanicsAudit`` (severity 0…1).
    let leakageZones: [LeakageZone]
    /// True when the underlying scan is a verified measured capture (SCAN accuracy boundary);
    /// false ⇒ segment lengths + joint angles are ILLUSTRATIVE (rig defaults / synthetic bands).
    let isMeasured: Bool

    // MARK: - Ideal targets (degrees) — athletic loaded-stance references.

    static let idealKneeDeg: Double = 105     // loaded athletic knee flexion
    static let idealHipDeg: Double = 95        // hip hinge at load
    static let idealAnkleDeg: Double = 75      // dorsiflexed drive angle

    // MARK: - Tolerances (degrees) for verdict classification.

    static let goodToleranceDeg: Double = 12
    static let watchToleranceDeg: Double = 25

    static func classify(angle: Double, ideal: Double) -> JointReadout.Verdict {
        let dev = abs(angle - ideal)
        if dev <= goodToleranceDeg { return .good }
        if dev <= watchToleranceDeg { return .watch }
        return .off
    }

    // MARK: - Baseline rig proportions (meters) — mirror NexusGameplayAvatarLoader capsule heights.

    private enum Baseline {
        static let torso: Double = 0.35 + 0.25   // upper + lower torso capsule heights
        static let upperArm: Double = 0.32
        static let forearm: Double = 0.28        // derived (loader has a single arm capsule; split ~46%)
        static let thigh: Double = 0.42
        static let shin: Double = 0.38
        static let reachSpan: Double = 0.32      // shoulder→wrist reach capsule
    }

    /// Builds the analysis from the scan result and its derived audit.
    /// `avatarConfig` supplies the height/limb scale factors that the generated
    /// avatar is actually built with, so the measurements match the rendered rig.
    static func make(result: SystemScanResult, audit: BiomechanicsAudit) -> ScanFormAnalysis {
        let measured = result.commitsCompetitiveMetrics
        let h = result.avatarConfig.heightScale
        let l = result.avatarConfig.limbLength
        let w = result.avatarConfig.weightScale

        func seg(_ id: String, _ label: String, base: Double, scale: Double) -> Segment {
            let length = base * scale
            let pct = scale * 100.0
            return Segment(id: id, label: label, lengthMeters: length, proportionPercent: pct, measured: measured)
        }

        let segments: [Segment] = [
            seg("torso", "Torso", base: Baseline.torso, scale: h),
            seg("upperArm", "Upper Arm", base: Baseline.upperArm, scale: l),
            seg("forearm", "Forearm", base: Baseline.forearm, scale: l),
            seg("thigh", "Thigh", base: Baseline.thigh, scale: l * h),
            seg("shin", "Shin", base: Baseline.shin, scale: l * h),
            seg("reach", "Reach Span", base: Baseline.reachSpan, scale: l * w),
        ]

        // Joint angles: use the audit's derived scores mapped back to plausible
        // athletic angles. On measured scans these reflect captured composites;
        // on demo scans they land near ideal (audit is neutral) — hence illustrative.
        let kneeAngle = angleFromScore(audit.kneeTracking.value, ideal: idealKneeDeg, spread: 40)
        let hipAngle = angleFromScore(audit.hipExtension.value, ideal: idealHipDeg, spread: 45)
        let ankleAngle = angleFromScore(audit.ankleDorsiflexion.value, ideal: idealAnkleDeg, spread: 35)

        let joints: [JointReadout] = [
            JointReadout(id: "knee", label: "Knee Flexion", angleDeg: kneeAngle, idealDeg: idealKneeDeg,
                         verdict: classify(angle: kneeAngle, ideal: idealKneeDeg)),
            JointReadout(id: "hip", label: "Hip Hinge", angleDeg: hipAngle, idealDeg: idealHipDeg,
                         verdict: classify(angle: hipAngle, ideal: idealHipDeg)),
            JointReadout(id: "ankle", label: "Ankle Dorsiflexion", angleDeg: ankleAngle, idealDeg: idealAnkleDeg,
                         verdict: classify(angle: ankleAngle, ideal: idealAnkleDeg)),
        ]

        return ScanFormAnalysis(
            segments: segments,
            joints: joints,
            leakageZones: audit.kineticLeakageZones,
            isMeasured: measured
        )
    }

    /// Maps a 0…100 joint score to an angle: score 100 lands on ideal, lower
    /// scores fan out below ideal (more collapse). Deterministic and bounded.
    private static func angleFromScore(_ score: Double, ideal: Double, spread: Double) -> Double {
        let s = min(100, max(0, score)) / 100.0
        // 100 → ideal, 0 → ideal - spread (collapsed / under-loaded).
        return ideal - (1.0 - s) * spread
    }
}
