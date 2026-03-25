import Foundation

/// Mirrors Unreal `FELAcademyPrescription::ComputePrescription` — kinetic heat 0…1 → prioritized module keys (`mod1`…`mod12`).
nonisolated enum AcademyPrescriptionEngine {
    struct Prescription: Sendable {
        let highPriorityModuleIds: [String]
        let mediumPriorityModuleIds: [String]
        let rationale: String
    }

    private enum Band {
        case primed, moderate, leaking
    }

    private static func band(from heat01: Double) -> Band {
        let h = min(1, max(0, heat01))
        if h < 0.30 { return .primed }
        if h < 0.65 { return .moderate }
        return .leaking
    }

    /// Same 0…1 heat mapping as `PRQManager.kineticJointHeats` / Unreal snapshot.
    static func heatTriple(from audit: BiomechanicsAudit?) -> (Double, Double, Double) {
        guard let a = audit else { return (0.2, 0.2, 0.2) }
        func heat(_ status: JointStatus) -> Double {
            switch status {
            case .optimal: return 0.12
            case .moderate: return 0.48
            case .deficit: return 0.88
            }
        }
        return (heat(a.ankleDorsiflexion.status), heat(a.kneeTracking.status), heat(a.hipExtension.status))
    }

    static func compute(
        ankleHeat: Double,
        kneeHeat: Double,
        hipHeat: Double,
        sfmaMultiSegmentalRotationPassed: Bool? = nil
    ) -> Prescription {
        var high: [String] = []
        var med: [String] = []

        func addHigh(_ id: String) {
            if !high.contains(id) { high.append(id) }
        }
        func addMed(_ id: String) {
            if !med.contains(id), !high.contains(id) { med.append(id) }
        }

        if sfmaMultiSegmentalRotationPassed == false {
            addHigh("mod6")
            addMed("mod5")
        }

        let a = band(from: ankleHeat)
        let k = band(from: kneeHeat)
        let h = band(from: hipHeat)

        if h == .moderate || h == .leaking {
            addHigh("mod5")
            addHigh("mod6")
            if h == .leaking { addHigh("mod4") }
        }
        if k == .moderate || k == .leaking {
            addHigh("mod6")
            addMed("mod2")
        }
        if a == .moderate || a == .leaking {
            addHigh("mod1")
            addMed("mod8")
        }
        if a == .leaking || k == .leaking || h == .leaking {
            addMed("mod11")
        }

        let rationale: String
        if high.isEmpty && med.isEmpty {
            addMed("mod9")
            addMed("mod10")
            rationale = "Joints PRIMED — progress Elastic Engine and Flight Blueprint."
        } else {
            rationale = "Prescription from kinetic heat map: prioritize high-leakage chains before max plyometric volume."
        }

        return Prescription(highPriorityModuleIds: high, mediumPriorityModuleIds: med, rationale: rationale)
    }
}
