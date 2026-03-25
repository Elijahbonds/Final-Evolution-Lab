import Foundation

/// Educational "Movement Audit" layer: joint heat → copy + primary Academy module (mirrors `FELMovementDecoderAcademy` in Unreal).
nonisolated enum SystemScanMovementDecoder {
    /// Threshold for kinetic leak messaging (matches product spec; prescription bands use 0.65 in `AcademyPrescriptionEngine`).
    static let leakThreshold: Double = 0.6

    struct JointInsightCard: Identifiable, Sendable {
        let id: JointType
        let heat01: Double
        let statusLabel: String
        let whyMatters: String
        let fixModuleId: String?
        let fixModuleDisplayTitle: String?

        var heatPercent: Int { Int((min(1, max(0, heat01)) * 100).rounded()) }
        var isLeak: Bool { heat01 > leakThreshold }
    }

    struct PRQBreakdown: Sendable {
        /// Share of PRQ from flight / reactive component (0…1 of the two main pillars).
        let neuralShare: Double
        /// Share from vertical / structural stiffness proxy (0…1).
        let structuralShare: Double
        let neuralComponent: Double
        let structuralComponent: Double
        let tierComponent: Double
    }

    static func jointInsights(from audit: BiomechanicsAudit) -> [JointInsightCard] {
        let heats = AcademyPrescriptionEngine.heatTriple(from: audit)
        return [
            makeCard(.ankle, heat: heats.0, audit: audit),
            makeCard(.knee, heat: heats.1, audit: audit),
            makeCard(.hip, heat: heats.2, audit: audit)
        ]
    }

    private static func makeCard(_ joint: JointType, heat: Double, audit: BiomechanicsAudit) -> JointInsightCard {
        let status: JointStatus
        switch joint {
        case .ankle: status = audit.ankleDorsiflexion.status
        case .knee: status = audit.kneeTracking.status
        case .hip: status = audit.hipExtension.status
        }
        let label = "\(joint.displayName.uppercased()) — \(status.label)"
        let why = whyMatters(joint: joint, heat: heat)
        let fix = fixModule(for: joint, heat: heat)
        return JointInsightCard(
            id: joint,
            heat01: heat,
            statusLabel: label,
            whyMatters: why,
            fixModuleId: fix?.id,
            fixModuleDisplayTitle: fix?.displayTitle
        )
    }

    static func prqBreakdown(scan: SystemScanResult, goal: String?) -> PRQBreakdown {
        let pqVert = FELPRQScanFormula.scoreFromVerticalInches(scan.verticalEstimateInches)
        let pqFlight = min(100, max(0, scan.flightTimeSeconds * 95))
        let tier = FELPRQScanFormula.goalTier(from: goal)
        let tierBias = Double(tier) * 2.5
        let neural = 0.42 * pqFlight
        let structural = 0.48 * pqVert
        let tierContrib = tierBias * 0.10
        let sum = neural + structural
        let nShare = sum > 1e-6 ? neural / sum : 0.5
        let sShare = sum > 1e-6 ? structural / sum : 0.5
        return PRQBreakdown(
            neuralShare: nShare,
            structuralShare: sShare,
            neuralComponent: neural,
            structuralComponent: structural,
            tierComponent: tierContrib
        )
    }

    static func whyMatters(joint: JointType, heat: Double) -> String {
        if heat <= leakThreshold {
            return "This chain is in a good window — keep clearing the freeway before you chase volume."
        }
        switch joint {
        case .ankle:
            return "Limited ankle dorsiflexion causes energy to bleed into the floor, reducing your vertical potential. Clear dorsiflexion so force exits upward instead of collapsing into the arch."
        case .knee:
            return "Knee tracking and stiffness issues leak torque and elastic return. Restoring alignment lets the spring recoil and protects the patellar tendon."
        case .hip:
            return "Short hip extension caps triple extension and shifts load upstream. Open the hip hinge so power transfers instead of leaking into the lumbar spine."
        }
    }

    /// Primary corrective module per joint when heat is above `leakThreshold` (aligned with `FELMovementDecoderAcademy::PrimaryFixModuleId`).
    static func fixModule(for joint: JointType, heat: Double) -> VerticalVelocityModule? {
        guard heat > leakThreshold else { return nil }
        let id: String
        switch joint {
        case .ankle: id = "mod1"
        case .knee: id = "mod2"
        case .hip: id = "mod5"
        }
        return VerticalVelocityAcademyCurriculum.module(id: id)
    }
}
