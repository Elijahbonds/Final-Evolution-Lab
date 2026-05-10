import Foundation

// MARK: - Bonds Standard → prescription taxonomy

/// High-level kinetic fault buckets used to route CARS / corrective / IAP phases.
nonisolated enum KineticLeakageCategory: String, Codable, Sendable, CaseIterable, Identifiable {
    case corePelvicChain
    case ankleInstability
    case kneeTracking
    case hipExtensionPower

    var id: String { rawValue }

    /// Maps existing ``LeakageZone`` joints into prescription lanes (core = lumbo-pelvic–hip chain).
    static func inferred(from audit: BiomechanicsAudit) -> [KineticLeakageCategory] {
        var set: Set<KineticLeakageCategory> = []
        for zone in audit.kineticLeakageZones {
            switch zone.joint {
            case .ankle:
                set.insert(.ankleInstability)
            case .knee:
                set.insert(.kneeTracking)
                if zone.severity >= 0.28 {
                    set.insert(.corePelvicChain)
                }
            case .hip:
                set.insert(.hipExtensionPower)
                set.insert(.corePelvicChain)
            }
        }
        let kneeHip = audit.kineticLeakageZones.contains(where: { $0.joint == .knee })
            && audit.kineticLeakageZones.contains(where: { $0.joint == .hip })
        if kneeHip {
            set.insert(.corePelvicChain)
        }
        return Array(set).sorted { $0.rawValue < $1.rawValue }
    }
}

// MARK: - Movement Snack (bite-sized prescription)

/// A single **Movement Snack**: 60–90s, game-framed corrective loop with Unreal asset hooks.
nonisolated struct MovementSnack: Identifiable, Codable, Sendable, Hashable {
    var id: String
    /// Primary UE animation Montage / Sequence id (required for Phase B playback contract).
    var requiredUnrealAnimationAssetID: String
    /// Phase A — capsule CARS / FRC-style joint prep.
    var phaseMappingCarsCue: String
    /// Phase B — corrective posture demonstrated in Unreal (may equal `requiredUnrealAnimationAssetID` or a paired pose).
    var unrealCorrectivePoseAssetID: String
    /// Phase C — diaphragm / IAP breath loop in-engine.
    var unrealDiaphragmBreathAssetID: String
    var title: String
    var subtitle: String
    var targetedCategories: [KineticLeakageCategory]
    /// Intended length in seconds (60…90 per product spec).
    var durationSeconds: Int
    var phaseBreathCue: String

    /// Normalized 0…1 “neural focus” used only for UI cue speed (from scan avatar or neural drive proxy).
    var recommendedNeuralFocusHint: Double?

    static func sampleCoreLeakPatch() -> MovementSnack {
        MovementSnack(
            id: "snack_core_kinetic_patch_v1",
            requiredUnrealAnimationAssetID: "FEL_BodyIQ_CoreSequence_v1",
            phaseMappingCarsCue:
                "Hip CARS: slow circles — internal→external rotation, pain-free range only. 45s · 3 reps each direction.",
            unrealCorrectivePoseAssetID: "FEL_BodyIQ_Corrective_DeepSquatHold_v1",
            unrealDiaphragmBreathAssetID: "FEL_BodyIQ_IAP_Diaphragm360_Loop_v1",
            title: "Core Kinetic Patch",
            subtitle: "Close the loop — capsule map → stack → breath.",
            targetedCategories: [.corePelvicChain],
            durationSeconds: 75,
            phaseBreathCue:
                "360° IAP: ribs expand laterally, exhale long through the straw — 4s in / 6s out × 6 while holding the corrective stance.",
            recommendedNeuralFocusHint: nil
        )
    }
}

// MARK: - Engine

nonisolated enum MovementSnackEngine {
    /// Derives 1…n snacks from the latest biomechanical audit (Bonds Standard leakage → prescription).
    static func snacks(from audit: BiomechanicsAudit, neuralFocus01: Double?) -> [MovementSnack] {
        let categories = KineticLeakageCategory.inferred(from: audit)
        if categories.isEmpty {
            return [primedMaintenanceSnack(neuralFocus01: neuralFocus01)]
        }

        var result: [MovementSnack] = []
        if categories.contains(.corePelvicChain) {
            var core = MovementSnack.sampleCoreLeakPatch()
            core.recommendedNeuralFocusHint = neuralFocus01
            result.append(core)
        }
        if categories.contains(.ankleInstability) {
            result.append(ankleStabilitySnack(neuralFocus01: neuralFocus01))
        }
        if categories.contains(.kneeTracking) && !categories.contains(.corePelvicChain) {
            result.append(kneeStackSnack(neuralFocus01: neuralFocus01))
        }
        if categories.contains(.hipExtensionPower) && !categories.contains(.corePelvicChain) {
            result.append(hipDriveSnack(neuralFocus01: neuralFocus01))
        }
        var seen = Set<String>()
        return result.filter { seen.insert($0.id).inserted }
    }

    /// Optional bridge from Firestore ``SystemScanRecord`` when no live demo scan exists — uses avatar vector only.
    static func snacksFromRecord(_ record: SystemScanRecord) -> [MovementSnack] {
        let audit = BiomechanicsAudit.fromAvatarAttributes(record.avatar, capturedAt: record.capturedAt.dateValue())
        let nf = record.avatar.neuralFocus
        return snacks(from: audit, neuralFocus01: nf)
    }

    static func proprioceptivePulsePeriodSeconds(neuralFocus01: Double) -> Double {
        let n = min(1.0, max(0.08, neuralFocus01))
        return 3.15 - n * 2.05
    }

    private static func primedMaintenanceSnack(neuralFocus01: Double?) -> MovementSnack {
        MovementSnack(
            id: "snack_maintenance_cars_v1",
            requiredUnrealAnimationAssetID: "FEL_BodyIQ_Maintenance_JointCircles_v1",
            phaseMappingCarsCue: "Full-body CARS lite: ankle, knee, hip — one slow rep each plane.",
            unrealCorrectivePoseAssetID: "FEL_BodyIQ_NeutralStand_Alignment_v1",
            unrealDiaphragmBreathAssetID: "FEL_BodyIQ_IAP_BoxBreath_Loop_v1",
            title: "Primed Maintenance",
            subtitle: "No major leakage — keep the chassis tuned.",
            targetedCategories: [],
            durationSeconds: 60,
            phaseBreathCue: "Box breath 4-4-4-4 × 4 rounds — steady eyes, soft jaw.",
            recommendedNeuralFocusHint: neuralFocus01
        )
    }

    private static func ankleStabilitySnack(neuralFocus01: Double?) -> MovementSnack {
        MovementSnack(
            id: "snack_ankle_stability_v1",
            requiredUnrealAnimationAssetID: "FEL_BodyIQ_Ankle_CARSequence_v1",
            phaseMappingCarsCue: "Ankle CARS: dorsi/plantar + inversion/eversion in half-kneel, controlled.",
            unrealCorrectivePoseAssetID: "FEL_BodyIQ_SplitSquat_IsometricHold_v1",
            unrealDiaphragmBreathAssetID: "FEL_BodyIQ_IAP_Diaphragm360_Loop_v1",
            title: "Ankle Stack Snack",
            subtitle: "Reclaim ground contact quality.",
            targetedCategories: [.ankleInstability],
            durationSeconds: 72,
            phaseBreathCue: "Low IAP brace before each rep — exhale on the press into the floor.",
            recommendedNeuralFocusHint: neuralFocus01
        )
    }

    private static func kneeStackSnack(neuralFocus01: Double?) -> MovementSnack {
        MovementSnack(
            id: "snack_knee_tracking_v1",
            requiredUnrealAnimationAssetID: "FEL_BodyIQ_Knee_TrackSequence_v1",
            phaseMappingCarsCue: "Tibia / hip rotation CARS — own the knee window without valgus collapse.",
            unrealCorrectivePoseAssetID: "FEL_BodyIQ_Corrective_SplitSquatKneeLine_v1",
            unrealDiaphragmBreathAssetID: "FEL_BodyIQ_IAP_RibAnchor_Loop_v1",
            title: "Knee Line Snack",
            subtitle: "Bias tracking without losing torque.",
            targetedCategories: [.kneeTracking],
            durationSeconds: 68,
            phaseBreathCue: "Inhale expand ribs; exhale — lightly drag kneecap lateral + root heel.",
            recommendedNeuralFocusHint: neuralFocus01
        )
    }

    private static func hipDriveSnack(neuralFocus01: Double?) -> MovementSnack {
        MovementSnack(
            id: "snack_hip_extension_v1",
            requiredUnrealAnimationAssetID: "FEL_BodyIQ_Hip_CARSequence_v1",
            phaseMappingCarsCue: "Hip flex/extension CARS in quadruped → tall-kneel transitions.",
            unrealCorrectivePoseAssetID: "FEL_BodyIQ_Corrective_HipExtensionWallDrill_v1",
            unrealDiaphragmBreathAssetID: "FEL_BodyIQ_IAP_Diaphragm360_Loop_v1",
            title: "Hip Drive Snack",
            subtitle: "Expose length without losing intra-abdominal pressure.",
            targetedCategories: [.hipExtensionPower],
            durationSeconds: 80,
            phaseBreathCue: "360 breath while owning hip extension — no lumbar hinge.",
            recommendedNeuralFocusHint: neuralFocus01
        )
    }
}

// MARK: - BiomechanicsAudit + SystemScanRecord helpers

private extension BiomechanicsAudit {
    /// Lightweight audit when only persistent avatar axes exist (HealthKit / Firestore path).
    static func fromAvatarAttributes(_ a: AvatarPerformanceAttributes, capturedAt: Date) -> BiomechanicsAudit {
        let prq = a.prqScore
        let vertical = a.hangTimeBonus * 40.0
        let flight = a.speedMultiplier * 0.35
        let synthetic = SystemScanResult(
            id: "avatar_snapshot",
            date: capturedAt,
            prqScore: prq,
            verticalEstimateInches: vertical,
            flightTimeSeconds: flight,
            movementGrade: a.readinessGrade,
            notes: [],
            recommendedTrack: "",
            avatarConfig: .default
        )
        return BiomechanicsAudit.fromScanResult(synthetic)
    }
}
