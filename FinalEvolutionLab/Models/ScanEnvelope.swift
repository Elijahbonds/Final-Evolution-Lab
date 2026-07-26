import Foundation

/// POST body for `fel.generate.arena_from_scan` — shared with NEXUS C++ `scan_envelope_mapper`.
nonisolated struct ScanEnvelope: Codable, Sendable, Equatable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var scanId: String
    var source: ScanCaptureSource
    var capturedAtEpochMs: Int64
    var confidence01: Double
    var joints: JointMetrics
    var motion: MotionMetrics
    var frcProxies: FRCProxies?

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case scanId = "scan_id"
        case source
        case capturedAtEpochMs = "captured_at_epoch_ms"
        case confidence01
        case joints
        case motion
        case frcProxies = "frc_proxies"
    }

    nonisolated struct JointMetrics: Codable, Sendable, Equatable {
        var leftKneeAngleDeg: Double
        var rightKneeAngleDeg: Double
        var leftShoulderReach01: Double
        var rightShoulderReach01: Double
        var hipStability01: Double

        enum CodingKeys: String, CodingKey {
            case leftKneeAngleDeg = "left_knee_angle_deg"
            case rightKneeAngleDeg = "right_knee_angle_deg"
            case leftShoulderReach01 = "left_shoulder_reach01"
            case rightShoulderReach01 = "right_shoulder_reach01"
            case hipStability01 = "hip_stability01"
        }
    }

    nonisolated struct MotionMetrics: Codable, Sendable, Equatable {
        var verticalEstimateInches: Double
        var flightTimeSeconds: Double
        var peakAccelG: Double

        enum CodingKeys: String, CodingKey {
            case verticalEstimateInches = "vertical_estimate_inches"
            case flightTimeSeconds = "flight_time_seconds"
            case peakAccelG = "peak_accel_g"
        }
    }

    nonisolated struct FRCProxies: Codable, Sendable, Equatable {
        var mobility01: Double
        var activeRange01: Double
        var control01: Double

        enum CodingKeys: String, CodingKey {
            case mobility01
            case activeRange01 = "active_range01"
            case control01 = "control01"
        }
    }
}

nonisolated enum ScanCaptureSource: String, Codable, Sendable {
    case arkitPose = "arkit_pose"
    case visionCamera = "vision_camera"
    case coreMotion = "coremotion"
    case simulated = "simulated"
}

/// Deterministic Swift-side mapping for unit tests (mirrors C++ `scanEnvelopeToCommandJson`).
enum ScanEnvelopeCommandMapper {
    static func commandPlan(for envelope: ScanEnvelope) -> [String: Any] {
        let reach = (envelope.joints.leftShoulderReach01 + envelope.joints.rightShoulderReach01) * 0.5
        let mobility = envelope.frcProxies?.mobility01
            ?? min(1, max(0, 1 - abs(((envelope.joints.leftKneeAngleDeg + envelope.joints.rightKneeAngleDeg) * 0.5) - 165) / 90))
        let activeRange = envelope.frcProxies?.activeRange01
            ?? min(1, max(0, reach * 0.7 + (180 - (envelope.joints.leftKneeAngleDeg + envelope.joints.rightKneeAngleDeg) * 0.5) / 180 * 0.3))
        let control = envelope.frcProxies?.control01
            ?? min(1, max(0, envelope.joints.hipStability01 * 0.6 + envelope.confidence01 * 0.4))
        let engagement = min(1, max(0, envelope.motion.flightTimeSeconds / 0.72))
        let confidence = min(1, max(0, envelope.confidence01 * 0.85 + envelope.motion.peakAccelG / 3 * 0.15))
        let breathPhase = envelope.motion.flightTimeSeconds > 0.5 ? 1 : 0

        let composite = min(1, max(0, reach * 0.55 + control * 0.45))
        let difficultyTier: Int
        switch composite {
        case 0.78...: difficultyTier = 3
        case 0.58..<0.78: difficultyTier = 2
        case 0.38..<0.58: difficultyTier = 1
        default: difficultyTier = 0
        }

        let arenaScale = min(1.15, max(0.85, 0.88 + mobility * 0.24 + (envelope.confidence01 - 0.5) * 0.06))
        let paintRadius = min(12, max(2, Int(round(2 + reach * 10))))
        let material: Int
        switch difficultyTier {
        case 3: material = 9
        case 2: material = 7
        case 1: material = 5
        default: material = 3
        }

        let recommendedMode: String
        if envelope.motion.verticalEstimateInches >= 26 {
            recommendedMode = "basketball_dunk"
        } else if (envelope.joints.leftKneeAngleDeg + envelope.joints.rightKneeAngleDeg) * 0.5 <= 110 {
            recommendedMode = "karate_endless"
        } else {
            recommendedMode = "court_carnival"
        }

        let fitnessParams: [String: Any] = [
            "frc_mobility": mobility,
            "frc_active_range": activeRange,
            "frc_control": control,
            "iap_engagement": engagement,
            "iap_confidence": confidence,
            "breath_phase": breathPhase,
        ]

        let fillParams: [String: Any] = [
            "min": [-paintRadius, 0, -paintRadius],
            "max": [paintRadius, 0, paintRadius],
            "voxel": ["material": material, "solid": true],
        ]

        let envelopeDict = (try? JSONSerialization.jsonObject(with: JSONEncoder().encode(envelope))) as? [String: Any] ?? [:]

        return [
            "schema_version": 1,
            "commands": [
                ["command": "fel.fitness.update", "params": fitnessParams],
                ["command": "fel.creative.fill_region", "params": fillParams],
                ["command": "fel.generate.arena_from_scan", "params": envelopeDict],
            ],
            "generative": [
                "arena_scale": arenaScale,
                "difficulty_tier": difficultyTier,
                "recommended_mode_id": recommendedMode,
                "voxel_material": material,
                "paint_radius": paintRadius,
            ] as [String: Any],
        ]
    }
}
