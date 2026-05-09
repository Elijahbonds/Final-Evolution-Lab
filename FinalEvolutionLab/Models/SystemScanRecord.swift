import Foundation
import FirebaseFirestore

// MARK: - Firestore + UE bridge schema (System Scan)

/// Immutable PRQ / readiness snapshot for one sync. Stored under `users/{uid}/system_scans/{docId}`.
struct SystemScanRecord: Codable {
    /// Bump when you change field meanings (UE + Swift must agree).
    var schemaVersion: Int
    var source: String
    var capturedAt: Timestamp
    var vitals: VitalsSnapshot
    var readiness: ReadinessSnapshot
    /// Denormalized avatar knobs for Unreal + latest doc at `avatar_performance/current`.
    var avatar: AvatarPerformanceAttributes

    struct VitalsSnapshot: Codable {
        var heartRateBpm: Double?
        var restingHeartRateBpm: Double?
        var hrvSdnnMs: Double?
        var activeKcal: Double?
        var weeklyHrvAverageMs: Double?
    }

    struct ReadinessSnapshot: Codable {
        var neuralReadinessScore: Double
        var grade: String
        var hrvTrend: String
        var recoveryEstimateHours: Double
    }
}

/// Normalized **0...1** performance vector shared by Swift UI, Firestore, and Unreal (via JSON).
struct AvatarPerformanceAttributes: Codable, Sendable {
    var schemaVersion: Int
    var updatedAt: Timestamp
    var explosiveness: Double
    var endurance: Double
    var recovery: Double
    var neuralFocus: Double
    var biomechanicalEfficiency: Double
    var prqScore: Double
    var readinessGrade: String
    var speedMultiplier: Double
    var hangTimeBonus: Double
    var isRecoveryMode: Bool
}

// MARK: - HealthKit mapping

extension SystemScanRecord {
    @MainActor
    static func makeFromHealthKit(_ health: HealthKitService) -> SystemScanRecord {
        let avatar = AvatarPerformanceAttributes.from(health: health)
        return SystemScanRecord(
            schemaVersion: 1,
            source: "healthkit",
            capturedAt: Timestamp(date: health.lastSyncDate ?? Date()),
            vitals: VitalsSnapshot(
                heartRateBpm: health.heartRate > 0 ? health.heartRate : nil,
                restingHeartRateBpm: health.restingHeartRate > 0 ? health.restingHeartRate : nil,
                hrvSdnnMs: health.hrvValue > 0 ? health.hrvValue : nil,
                activeKcal: health.activeCalories > 0 ? health.activeCalories : nil,
                weeklyHrvAverageMs: health.weeklyHRVAverage > 0 ? health.weeklyHRVAverage : nil
            ),
            readiness: ReadinessSnapshot(
                neuralReadinessScore: health.neuralReadinessScore,
                grade: health.neuralReadinessGrade.rawValue,
                hrvTrend: health.dailyTrend.rawValue,
                recoveryEstimateHours: health.recoveryEstimateHours
            ),
            avatar: avatar
        )
    }
}

extension AvatarPerformanceAttributes {
    @MainActor
    static func from(health: HealthKitService) -> AvatarPerformanceAttributes {
        let buff = health.arcadePhysicsBuff
        let score = health.neuralReadinessScore
        let expl = clamp01((buff.speedMultiplier - 0.85) / 0.30)
        let endur = clamp01(score / 100.0)
        let rec = clamp01(1.0 - min(1.0, health.recoveryEstimateHours / 36.0))
        let focus = clamp01((score - 35) / 55.0)
        let bio = clamp01((health.hrvValue > 0 ? (health.hrvValue - 15) / 70.0 : 0.5))

        return AvatarPerformanceAttributes(
            schemaVersion: 1,
            updatedAt: Timestamp(date: Date()),
            explosiveness: expl,
            endurance: endur,
            recovery: rec,
            neuralFocus: focus,
            biomechanicalEfficiency: bio,
            prqScore: score,
            readinessGrade: health.neuralReadinessGrade.rawValue,
            speedMultiplier: buff.speedMultiplier,
            hangTimeBonus: buff.hangTimeBonus,
            isRecoveryMode: buff.isRecoveryMode
        )
    }

    private static func clamp01(_ x: Double) -> Double {
        min(1.0, max(0.0, x))
    }
}

// MARK: - Unreal JSON (stable field names for FJsonObject / bridge)

/// Numeric times only — UE-friendly; keep in sync with `infra/SYSTEM_SCAN_FIRESTORE_SCHEMA.md`.
struct UnrealSystemScanPayload: Codable, Sendable {
    var schemaVersion: Int
    var capturedAtEpochMs: Int64
    var vitals: VitalsDTO
    var readiness: ReadinessDTO
    var avatar: AvatarDTO

    struct VitalsDTO: Codable, Sendable {
        var heartRateBpm: Double?
        var restingHeartRateBpm: Double?
        var hrvSdnnMs: Double?
        var activeKcal: Double?
        var weeklyHrvAverageMs: Double?
    }

    struct ReadinessDTO: Codable, Sendable {
        var neuralReadinessScore: Double
        var grade: String
        var hrvTrend: String
        var recoveryEstimateHours: Double
    }

    struct AvatarDTO: Codable, Sendable {
        var schemaVersion: Int
        var updatedAtEpochMs: Int64
        var explosiveness: Double
        var endurance: Double
        var recovery: Double
        var neuralFocus: Double
        var biomechanicalEfficiency: Double
        var prqScore: Double
        var readinessGrade: String
        var speedMultiplier: Double
        var hangTimeBonus: Double
        var isRecoveryMode: Bool
    }
}

extension SystemScanRecord {
    func unrealBridgePayload() -> UnrealSystemScanPayload {
        let v = vitals
        let r = readiness
        let a = avatar
        return UnrealSystemScanPayload(
            schemaVersion: schemaVersion,
            capturedAtEpochMs: Int64(capturedAt.dateValue().timeIntervalSince1970 * 1000),
            vitals: UnrealSystemScanPayload.VitalsDTO(
                heartRateBpm: v.heartRateBpm,
                restingHeartRateBpm: v.restingHeartRateBpm,
                hrvSdnnMs: v.hrvSdnnMs,
                activeKcal: v.activeKcal,
                weeklyHrvAverageMs: v.weeklyHrvAverageMs
            ),
            readiness: UnrealSystemScanPayload.ReadinessDTO(
                neuralReadinessScore: r.neuralReadinessScore,
                grade: r.grade,
                hrvTrend: r.hrvTrend,
                recoveryEstimateHours: r.recoveryEstimateHours
            ),
            avatar: UnrealSystemScanPayload.AvatarDTO(
                schemaVersion: a.schemaVersion,
                updatedAtEpochMs: Int64(a.updatedAt.dateValue().timeIntervalSince1970 * 1000),
                explosiveness: a.explosiveness,
                endurance: a.endurance,
                recovery: a.recovery,
                neuralFocus: a.neuralFocus,
                biomechanicalEfficiency: a.biomechanicalEfficiency,
                prqScore: a.prqScore,
                readinessGrade: a.readinessGrade,
                speedMultiplier: a.speedMultiplier,
                hangTimeBonus: a.hangTimeBonus,
                isRecoveryMode: a.isRecoveryMode
            )
        )
    }

    func unrealBridgeJSON() throws -> Data {
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        return try enc.encode(unrealBridgePayload())
    }
}
