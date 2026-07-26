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
    /// Denormalized avatar knobs for Firestore + latest doc at `avatar_performance/current`.
    var avatar: AvatarPerformanceAttributes
    /// Optional pose / stability metrics (ARKit or future CV). When nil, bridge sends nulls — UE must not infer APT/valgus from avatar scalars alone.
    var stability: BiomechanicsStabilitySnapshot?

    struct VitalsSnapshot: Codable {
        var heartRateBpm: Double?
        var restingHeartRateBpm: Double?
        var hrvSdnnMs: Double?
        var activeKcal: Double?
        var weeklyHrvAverageMs: Double?
        /// Asleep hours from **sleepAnalysis** in the recent window (see HealthKitService).
        var sleepHoursLastNight: Double?
    }

    struct ReadinessSnapshot: Codable {
        var neuralReadinessScore: Double
        var grade: String
        var hrvTrend: String
        var recoveryEstimateHours: Double
    }
}

/// Pose-derived stability fields for UE `UE_AvatarScaleController` / biomechanical layering (optional until CV mesh lands).
struct BiomechanicsStabilitySnapshot: Codable, Sendable {
    var anteriorPelvicTiltEvidence01: Double?
    var ribFlareEvidence01: Double?
    var rearLegInternalRotation01: Double?
    var poseConfidence01: Double?
    var meshMemoryBudget01: Double?
    /// Stores ``PressureReleaseStatus/rawValue``.
    var pressureReleaseRaw: String?
}

/// Normalized **0...1** performance vector shared by Swift UI, Firestore, and NEXUS bridge JSON.
struct AvatarPerformanceAttributes: Codable, Sendable {
    var schemaVersion: Int
    var updatedAt: Timestamp
    var explosiveness: Double
    var endurance: Double
    var recovery: Double
    var neuralFocus: Double
    var biomechanicalEfficiency: Double
    /// Recovery / autonomic proxy (0–100). Not competitive lab PRQ (PRQ-03).
    var readinessScore: Double
    /// Competitive lab PRQ from verified measurement only; SQL peak & feed use this when non-nil.
    var verifiedPerformancePRQ: Double?
    /// Legacy UE field: competitive PRQ **only** — 0 when only readiness/vitals exist (e.g. HealthKit).
    var prqScore: Double
    var readinessGrade: String
    var speedMultiplier: Double
    var hangTimeBonus: Double
    var isRecoveryMode: Bool

    enum CodingKeys: String, CodingKey {
        case schemaVersion, updatedAt, explosiveness, endurance, recovery, neuralFocus, biomechanicalEfficiency
        case readinessScore, verifiedPerformancePRQ, prqScore, readinessGrade, speedMultiplier, hangTimeBonus, isRecoveryMode
    }

    init(
        schemaVersion: Int,
        updatedAt: Timestamp,
        explosiveness: Double,
        endurance: Double,
        recovery: Double,
        neuralFocus: Double,
        biomechanicalEfficiency: Double,
        readinessScore: Double,
        verifiedPerformancePRQ: Double?,
        prqScore: Double,
        readinessGrade: String,
        speedMultiplier: Double,
        hangTimeBonus: Double,
        isRecoveryMode: Bool
    ) {
        self.schemaVersion = schemaVersion
        self.updatedAt = updatedAt
        self.explosiveness = explosiveness
        self.endurance = endurance
        self.recovery = recovery
        self.neuralFocus = neuralFocus
        self.biomechanicalEfficiency = biomechanicalEfficiency
        self.readinessScore = readinessScore
        self.verifiedPerformancePRQ = verifiedPerformancePRQ
        self.prqScore = prqScore
        self.readinessGrade = readinessGrade
        self.speedMultiplier = speedMultiplier
        self.hangTimeBonus = hangTimeBonus
        self.isRecoveryMode = isRecoveryMode
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try c.decode(Int.self, forKey: .schemaVersion)
        updatedAt = try c.decode(Timestamp.self, forKey: .updatedAt)
        explosiveness = try c.decode(Double.self, forKey: .explosiveness)
        endurance = try c.decode(Double.self, forKey: .endurance)
        recovery = try c.decode(Double.self, forKey: .recovery)
        neuralFocus = try c.decode(Double.self, forKey: .neuralFocus)
        biomechanicalEfficiency = try c.decode(Double.self, forKey: .biomechanicalEfficiency)
        verifiedPerformancePRQ = try c.decodeIfPresent(Double.self, forKey: .verifiedPerformancePRQ)
        let readinessDecoded = try c.decodeIfPresent(Double.self, forKey: .readinessScore)
        let prqDecoded = try c.decodeIfPresent(Double.self, forKey: .prqScore)
        if let r = readinessDecoded {
            readinessScore = r
        } else if verifiedPerformancePRQ == nil, let legacy = prqDecoded {
            readinessScore = legacy
        } else {
            readinessScore = 50
        }
        prqScore = verifiedPerformancePRQ ?? ((readinessDecoded != nil) ? (prqDecoded ?? 0) : 0)
        readinessGrade = try c.decode(String.self, forKey: .readinessGrade)
        speedMultiplier = try c.decode(Double.self, forKey: .speedMultiplier)
        hangTimeBonus = try c.decode(Double.self, forKey: .hangTimeBonus)
        isRecoveryMode = try c.decode(Bool.self, forKey: .isRecoveryMode)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(schemaVersion, forKey: .schemaVersion)
        try c.encode(updatedAt, forKey: .updatedAt)
        try c.encode(explosiveness, forKey: .explosiveness)
        try c.encode(endurance, forKey: .endurance)
        try c.encode(recovery, forKey: .recovery)
        try c.encode(neuralFocus, forKey: .neuralFocus)
        try c.encode(biomechanicalEfficiency, forKey: .biomechanicalEfficiency)
        try c.encode(readinessScore, forKey: .readinessScore)
        try c.encodeIfPresent(verifiedPerformancePRQ, forKey: .verifiedPerformancePRQ)
        try c.encode(prqScore, forKey: .prqScore)
        try c.encode(readinessGrade, forKey: .readinessGrade)
        try c.encode(speedMultiplier, forKey: .speedMultiplier)
        try c.encode(hangTimeBonus, forKey: .hangTimeBonus)
        try c.encode(isRecoveryMode, forKey: .isRecoveryMode)
    }
}

// MARK: - HealthKit mapping

extension SystemScanRecord {
    /// Random-but-plausible vitals for **Debug**; avatar vector comes from ``AvatarPerformanceAttributes/calculateAttributes(vitals:readiness:sleepHoursForMapping:speedMultiplier:hangTimeBonus:isRecoveryMode:)``.
    static func makeSimulatedRandom() -> SystemScanRecord {
        let sleepHrs = Double.random(in: 4.5 ... 9.25)
        let vitals = VitalsSnapshot(
            heartRateBpm: Double.random(in: 58 ... 118),
            restingHeartRateBpm: Double.random(in: 48 ... 74),
            hrvSdnnMs: Double.random(in: 20 ... 72),
            activeKcal: Double.random(in: 95 ... 720),
            weeklyHrvAverageMs: Double.random(in: 26 ... 58),
            sleepHoursLastNight: sleepHrs
        )

        let score = Self.simulatedPrqScore(from: vitals)
        let grade = Self.readinessGradeString(forScore: score)
        let trends = ["IMPROVING", "STABLE", "DECLINING"]
        let trend = trends.randomElement()!
        let recoveryHours = grade == "RECOVERING"
            ? Double.random(in: 4 ... 20)
            : Double.random(in: 0 ... 4)

        let readiness = ReadinessSnapshot(
            neuralReadinessScore: score,
            grade: grade,
            hrvTrend: trend,
            recoveryEstimateHours: recoveryHours
        )

        let arcade = Self.simulatedArcadeParams(forGrade: grade)
        let avatar = AvatarPerformanceAttributes.calculateAttributes(
            vitals: vitals,
            readiness: readiness,
            sleepHoursForMapping: sleepHrs,
            speedMultiplier: arcade.speed,
            hangTimeBonus: arcade.hang,
            isRecoveryMode: arcade.isRecovery
        )

        return SystemScanRecord(
            schemaVersion: 1,
            source: "debug_simulated",
            capturedAt: Timestamp(date: Date()),
            vitals: vitals,
            readiness: readiness,
            avatar: avatar,
            stability: nil
        )
    }

    private static func simulatedPrqScore(from vitals: VitalsSnapshot) -> Double {
        let hrv = vitals.hrvSdnnMs ?? 40
        let hrvN = min(1.0, max(0, (hrv - 18) / 72.0))
        let rhr = vitals.restingHeartRateBpm ?? 60
        let rhrAdj = rhr > 68 ? -12.0 : (rhr < 55 ? 6.0 : 0)
        let cal = vitals.activeKcal ?? 200
        let calAdj = min(12, cal / 55.0)
        let sleep = vitals.sleepHoursLastNight ?? 6.5
        let sleepAdj = (min(1.0, sleep / 8.0) - 0.5) * 18.0
        let base = 32 + hrvN * 48 + calAdj + sleepAdj + rhrAdj
        return min(100, max(15, base + Double.random(in: -6 ... 8)))
    }

    private static func readinessGradeString(forScore score: Double) -> String {
        switch score {
        case 80...: return "ELITE"
        case 60 ..< 80: return "PRIMED"
        case 40 ..< 60: return "READY"
        default: return "RECOVERING"
        }
    }

    private static func simulatedArcadeParams(forGrade grade: String) -> (speed: Double, hang: Double, isRecovery: Bool) {
        switch grade {
        case "ELITE": return (1.15, 0.3, false)
        case "PRIMED": return (1.05, 0.15, false)
        case "READY": return (1.0, 0, false)
        default: return (0.9, -0.1, true)
        }
    }

    @MainActor
    static func makeFromHealthKit(_ health: HealthKitService) -> SystemScanRecord {
        let buff = health.arcadePhysicsBuff
        let vitals = VitalsSnapshot(
            heartRateBpm: health.heartRate > 0 ? health.heartRate : nil,
            restingHeartRateBpm: health.restingHeartRate > 0 ? health.restingHeartRate : nil,
            hrvSdnnMs: health.hrvValue > 0 ? health.hrvValue : nil,
            activeKcal: health.activeCalories > 0 ? health.activeCalories : nil,
            weeklyHrvAverageMs: health.weeklyHRVAverage > 0 ? health.weeklyHRVAverage : nil,
            sleepHoursLastNight: health.sleepHoursLastNight > 0 ? health.sleepHoursLastNight : nil
        )
        let readiness = ReadinessSnapshot(
            neuralReadinessScore: health.neuralReadinessScore,
            grade: health.neuralReadinessGrade.rawValue,
            hrvTrend: health.dailyTrend.rawValue,
            recoveryEstimateHours: health.recoveryEstimateHours
        )
        let sleepForMapping = health.sleepHoursLastNight > 0 ? health.sleepHoursLastNight : nil
        let avatar = AvatarPerformanceAttributes.calculateAttributes(
            vitals: vitals,
            readiness: readiness,
            sleepHoursForMapping: sleepForMapping,
            speedMultiplier: buff.speedMultiplier,
            hangTimeBonus: buff.hangTimeBonus,
            isRecoveryMode: buff.isRecoveryMode
        )
        return SystemScanRecord(
            schemaVersion: 1,
            source: "healthkit",
            capturedAt: Timestamp(date: health.lastSyncDate ?? Date()),
            vitals: vitals,
            readiness: readiness,
            avatar: avatar,
            stability: nil
        )
    }
}

extension AvatarPerformanceAttributes {
    /// Maps raw vitals + PRQ readiness + optional sleep duration into **0…1** avatar axes (deterministic, tunable).
    ///
    /// **Neural focus** weights: HRV level, HRV vs weekly baseline, sleep debt/adequacy, PRQ, trend.
    /// **Explosiveness** weights: sympathetic reserve (HR − RHR), training load (active kcal), RHR reserve, recovery headroom, tier speed multiplier.
    static func calculateAttributes(
        vitals: SystemScanRecord.VitalsSnapshot,
        readiness: SystemScanRecord.ReadinessSnapshot,
        sleepHoursForMapping: Double?,
        speedMultiplier: Double,
        hangTimeBonus: Double,
        isRecoveryMode: Bool
    ) -> AvatarPerformanceAttributes {
        let hrv = vitals.hrvSdnnMs ?? 0
        let week = vitals.weeklyHrvAverageMs ?? 0
        let rhr = vitals.restingHeartRateBpm ?? 0
        let hr = vitals.heartRateBpm ?? 0
        let kcal = vitals.activeKcal ?? 0

        let hrvLevel = normalizeHrvSdnn(hrv)
        let hrvVsBaseline: Double = {
            guard week > 1, hrv > 0 else { return hrvLevel }
            let ratio = hrv / week
            return clamp01(0.5 + (ratio - 1.0) * 1.15)
        }()

        let sleepScore = sleepQuality01(fromHours: sleepHoursForMapping)

        let prqN = clamp01(readiness.neuralReadinessScore / 100.0)

        let trendBoost: Double = {
            switch readiness.hrvTrend.uppercased() {
            case "IMPROVING": return 0.08
            case "DECLINING": return -0.07
            default: return 0
            }
        }()

        let neuralFocus = clamp01(
            0.34 * hrvVsBaseline
                + 0.28 * sleepScore
                + 0.22 * hrvLevel
                + 0.16 * prqN
                + trendBoost
        )

        let hrReserve = heartRateReserve01(heartRate: hr, resting: rhr)
        let activityN = clamp01(kcal / 520.0)
        let rhrReserve = restingHrReserve01(restingBpm: rhr)
        let recoveryHeadroom = clamp01(1.0 - min(1.0, readiness.recoveryEstimateHours / 28.0))
        let tierExpl = clamp01((speedMultiplier - 0.88) / 0.24)

        let explosiveness = clamp01(
            0.28 * tierExpl
                + 0.22 * hrReserve
                + 0.18 * activityN
                + 0.17 * rhrReserve
                + 0.15 * recoveryHeadroom
        )

        let endurance = clamp01(0.55 * prqN + 0.25 * activityN + 0.20 * sleepScore)
        let recovery = clamp01(0.45 * recoveryHeadroom + 0.35 * sleepScore + 0.20 * hrvVsBaseline)
        let biomechanicalEfficiency = clamp01(0.5 * hrvLevel + 0.3 * hrvVsBaseline + 0.2 * rhrReserve)

        return AvatarPerformanceAttributes(
            schemaVersion: 2,
            updatedAt: Timestamp(date: Date()),
            explosiveness: explosiveness,
            endurance: endurance,
            recovery: recovery,
            neuralFocus: neuralFocus,
            biomechanicalEfficiency: biomechanicalEfficiency,
            readinessScore: readiness.neuralReadinessScore,
            verifiedPerformancePRQ: nil,
            prqScore: 0,
            readinessGrade: readiness.grade,
            speedMultiplier: speedMultiplier,
            hangTimeBonus: hangTimeBonus,
            isRecoveryMode: isRecoveryMode
        )
    }

    private static func sleepQuality01(fromHours hours: Double?) -> Double {
        guard let hours, hours > 0.25 else {
            return 0.48
        }
        let optimalLow = 7.0
        let optimalHigh = 8.5
        if hours >= optimalLow, hours <= optimalHigh { return 1.0 }
        if hours < optimalLow {
            return clamp01((hours - 4.0) / (optimalLow - 4.0))
        }
        return clamp01(1.0 - (hours - optimalHigh) / 4.0)
    }

    private static func normalizeHrvSdnn(_ ms: Double) -> Double {
        guard ms > 0 else { return 0.42 }
        return clamp01((ms - 18.0) / 70.0)
    }

    private static func heartRateReserve01(heartRate: Double, resting: Double) -> Double {
        guard heartRate > 0, resting > 0, heartRate > resting else { return 0.5 }
        let span = max(40.0, 185.0 - resting)
        return clamp01((heartRate - resting) / span)
    }

    private static func restingHrReserve01(restingBpm: Double) -> Double {
        guard restingBpm > 0 else { return 0.5 }
        let baseline = 60.0
        return clamp01((baseline + 12.0 - restingBpm) / 24.0)
    }

    private static func clamp01(_ x: Double) -> Double {
        min(1.0, max(0.0, x))
    }
}

// MARK: - FEL scan bridge JSON (stable field names for WebSocket / backend routing)

/// Numeric times only; keep in sync with `infra/SYSTEM_SCAN_FIRESTORE_SCHEMA.md`.
struct FELScanBridgePayload: Codable, Sendable {
    var schemaVersion: Int
    var capturedAtEpochMs: Int64
    var vitals: VitalsDTO
    var readiness: ReadinessDTO
    var avatar: AvatarDTO
    /// Optional pose / stability pass-through for bridge consumers (null when not measured).
    var stability: StabilityDTO?

    struct VitalsDTO: Codable, Sendable {
        var heartRateBpm: Double?
        var restingHeartRateBpm: Double?
        var hrvSdnnMs: Double?
        var activeKcal: Double?
        var weeklyHrvAverageMs: Double?
        var sleepHoursLastNight: Double?
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
        var readinessScore: Double?
        var verifiedPerformancePRQ: Double?
        var prqScore: Double
        var readinessGrade: String
        var speedMultiplier: Double
        var hangTimeBonus: Double
        var isRecoveryMode: Bool
    }

    struct StabilityDTO: Codable, Sendable {
        var anteriorPelvicTiltEvidence01: Double?
        var ribFlareEvidence01: Double?
        var rearLegInternalRotation01: Double?
        var poseConfidence01: Double?
        var meshMemoryBudget01: Double?
        var pressureRelease: String?
    }
}

extension SystemScanRecord {
    func felScanBridgePayload() -> FELScanBridgePayload {
        let v = vitals
        let r = readiness
        let a = avatar
        let stab = stability.map { s in
            FELScanBridgePayload.StabilityDTO(
                anteriorPelvicTiltEvidence01: s.anteriorPelvicTiltEvidence01,
                ribFlareEvidence01: s.ribFlareEvidence01,
                rearLegInternalRotation01: s.rearLegInternalRotation01,
                poseConfidence01: s.poseConfidence01,
                meshMemoryBudget01: s.meshMemoryBudget01,
                pressureRelease: s.pressureReleaseRaw
            )
        }
        return FELScanBridgePayload(
            schemaVersion: schemaVersion,
            capturedAtEpochMs: Int64(capturedAt.dateValue().timeIntervalSince1970 * 1000),
            vitals: FELScanBridgePayload.VitalsDTO(
                heartRateBpm: v.heartRateBpm,
                restingHeartRateBpm: v.restingHeartRateBpm,
                hrvSdnnMs: v.hrvSdnnMs,
                activeKcal: v.activeKcal,
                weeklyHrvAverageMs: v.weeklyHrvAverageMs,
                sleepHoursLastNight: v.sleepHoursLastNight
            ),
            readiness: FELScanBridgePayload.ReadinessDTO(
                neuralReadinessScore: r.neuralReadinessScore,
                grade: r.grade,
                hrvTrend: r.hrvTrend,
                recoveryEstimateHours: r.recoveryEstimateHours
            ),
            avatar: FELScanBridgePayload.AvatarDTO(
                schemaVersion: a.schemaVersion,
                updatedAtEpochMs: Int64(a.updatedAt.dateValue().timeIntervalSince1970 * 1000),
                explosiveness: a.explosiveness,
                endurance: a.endurance,
                recovery: a.recovery,
                neuralFocus: a.neuralFocus,
                biomechanicalEfficiency: a.biomechanicalEfficiency,
                readinessScore: a.readinessScore,
                verifiedPerformancePRQ: a.verifiedPerformancePRQ,
                prqScore: a.prqScore,
                readinessGrade: a.readinessGrade,
                speedMultiplier: a.speedMultiplier,
                hangTimeBonus: a.hangTimeBonus,
                isRecoveryMode: a.isRecoveryMode
            ),
            stability: stab
        )
    }

    func felScanBridgeJSON() throws -> Data {
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        return try enc.encode(felScanBridgePayload())
    }
}
