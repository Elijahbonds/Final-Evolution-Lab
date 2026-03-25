import Foundation

/// Degree thresholds (ankle dorsiflexion, knee flexion at takeoff, hip extension) — mirrors Unreal `FELJointAngleThresholds.h`.
nonisolated enum FELJointAngleThresholds {
    static func statusAnkleDorsiflexion(measurement: Double) -> JointStatus {
        bandToStatus(Self.classifyAnkle(measurement))
    }

    static func statusKneeFlexion(measurement: Double) -> JointStatus {
        bandToStatus(Self.classifyKnee(measurement))
    }

    static func statusHipExtension(measurement: Double) -> JointStatus {
        bandToStatus(Self.classifyHip(measurement))
    }

    private enum Band { case optimal, moderate, deficit }

    private static func bandToStatus(_ b: Band) -> JointStatus {
        switch b {
        case .optimal: return JointStatus.optimal
        case .moderate: return JointStatus.moderate
        case .deficit: return JointStatus.deficit
        }
    }

    private static func classifyAnkle(_ d: Double) -> Band {
        if (18...28).contains(d) { return .optimal }
        if (12..<18).contains(d) || (28...35).contains(d) { return .moderate }
        return .deficit
    }

    private static func classifyKnee(_ d: Double) -> Band {
        if (32...42).contains(d) { return .optimal }
        if (24..<32).contains(d) || (42...52).contains(d) { return .moderate }
        return .deficit
    }

    private static func classifyHip(_ d: Double) -> Band {
        if (165...178).contains(d) { return .optimal }
        if (155..<165).contains(d) || (178...180).contains(d) { return .moderate }
        return .deficit
    }
}
