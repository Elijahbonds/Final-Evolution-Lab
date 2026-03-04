import Foundation

nonisolated struct ArcadePhysics: Sendable {
    let hangTimeMultiplier: Double
    let explosiveFirstStep: Double
    let comboDecayRate: Double
    let maxComboMultiplier: Double
    let successChanceBase: Double
    let criticalHitChance: Double
    let neuralBurstActive: Bool
    let neuralBurstMultiplier: Double
    let impactIntensity: Double
    let auraLevel: AuraLevel

    static func fromPRQ(_ prq: Double, neuralDrive: Double, audit: BiomechanicsAudit? = nil) -> ArcadePhysics {
        let normalized = min(max(prq / 100.0, 0), 1)
        let neural = min(max(neuralDrive / 100.0, 0), 1)

        var ankleModifier: Double = 1.0
        var kneeModifier: Double = 1.0
        var hipModifier: Double = 1.0

        if let audit {
            ankleModifier = audit.ankleDorsiflexion.status == .deficit ? 0.7 : (audit.ankleDorsiflexion.status == .moderate ? 0.85 : 1.0)
            kneeModifier = audit.kneeTracking.status == .deficit ? 0.75 : (audit.kneeTracking.status == .moderate ? 0.88 : 1.0)
            hipModifier = audit.hipExtension.status == .deficit ? 0.7 : (audit.hipExtension.status == .moderate ? 0.85 : 1.0)
        }

        let isEliteNeural = neuralDrive >= 80
        let burstMultiplier = isEliteNeural ? 1.5 : 1.0

        let aura: AuraLevel
        switch neuralDrive {
        case 80...: aura = .maxIntent
        case 60..<80: aura = .primed
        case 40..<60: aura = .active
        default: aura = .baseline
        }

        return ArcadePhysics(
            hangTimeMultiplier: (1.0 + normalized * 1.8 + neural * 0.4) * hipModifier,
            explosiveFirstStep: (0.3 + normalized * 0.7) * ankleModifier,
            comboDecayRate: max(1.0, 5.0 - normalized * 3.0),
            maxComboMultiplier: 2.0 + normalized * 3.0,
            successChanceBase: (0.45 + normalized * 0.35) * kneeModifier,
            criticalHitChance: 0.05 + normalized * 0.2 + neural * 0.1,
            neuralBurstActive: isEliteNeural,
            neuralBurstMultiplier: burstMultiplier,
            impactIntensity: 0.5 + normalized * 0.5 + (isEliteNeural ? 0.3 : 0),
            auraLevel: aura
        )
    }

    func comboMultiplier(for combo: Int) -> Double {
        min(1.0 + Double(combo) * 0.25, maxComboMultiplier)
    }

    func adjustedPoints(base: Int, combo: Int, isCritical: Bool) -> Int {
        let multiplied = Double(base) * comboMultiplier(for: combo)
        let critical = isCritical ? multiplied * 1.5 : multiplied
        let burst = neuralBurstActive ? critical * neuralBurstMultiplier : critical
        return Int(burst.rounded())
    }
}

nonisolated enum AuraLevel: String, Sendable {
    case baseline = "BASELINE"
    case active = "ACTIVE"
    case primed = "PRIMED"
    case maxIntent = "MAX INTENT"

    var glowIntensity: Double {
        switch self {
        case .baseline: 0.0
        case .active: 0.3
        case .primed: 0.6
        case .maxIntent: 1.0
        }
    }
}

nonisolated struct GamePhysicsConfig: Sendable {
    let jumpHeight: Float
    let moveSpeed: Float
    let impactIntensity: Float
    let floorShakeAmplitude: Float
    let particleTrailDensity: Float

    static func forMode(_ mode: GameModeId, prq: Double, audit: BiomechanicsAudit? = nil) -> GamePhysicsConfig {
        let normalized = Float(min(max(prq / 100.0, 0), 1))
        let auditBonus: Float = audit?.isPrimed == true ? 0.15 : 0

        switch mode {
        case .basketballHeadToHead, .basketballDunkContest, .basketball3v3:
            return GamePhysicsConfig(
                jumpHeight: 1.5 + (normalized + auditBonus) * 2.5,
                moveSpeed: 0.6 + (normalized + auditBonus) * 0.8,
                impactIntensity: 0.5 + normalized * 0.5,
                floorShakeAmplitude: 0.02 + normalized * 0.04,
                particleTrailDensity: 10 + normalized * 30
            )
        case .karate:
            return GamePhysicsConfig(
                jumpHeight: 0.8 + normalized * 1.2,
                moveSpeed: 0.7 + (normalized + auditBonus) * 0.9,
                impactIntensity: 0.6 + normalized * 0.6,
                floorShakeAmplitude: 0.01 + normalized * 0.02,
                particleTrailDensity: 8 + normalized * 20
            )
        case .baseball:
            return GamePhysicsConfig(
                jumpHeight: 0.3,
                moveSpeed: 0.5 + normalized * 0.7,
                impactIntensity: 0.4 + normalized * 0.8,
                floorShakeAmplitude: 0.03 + normalized * 0.05,
                particleTrailDensity: 15 + normalized * 35
            )
        case .football:
            return GamePhysicsConfig(
                jumpHeight: 0.5 + normalized * 0.5,
                moveSpeed: 0.6 + normalized * 0.8,
                impactIntensity: 0.3 + normalized * 0.5,
                floorShakeAmplitude: 0.01 + normalized * 0.03,
                particleTrailDensity: 5 + normalized * 15
            )
        case .soccer:
            return GamePhysicsConfig(
                jumpHeight: 0.4 + normalized * 0.6,
                moveSpeed: 0.7 + normalized * 0.6,
                impactIntensity: 0.5 + normalized * 0.5,
                floorShakeAmplitude: 0.01 + normalized * 0.02,
                particleTrailDensity: 8 + normalized * 20
            )
        case .golf:
            return GamePhysicsConfig(
                jumpHeight: 0.0,
                moveSpeed: 0.4 + normalized * 0.3,
                impactIntensity: 0.3 + normalized * 0.7,
                floorShakeAmplitude: 0.005 + normalized * 0.01,
                particleTrailDensity: 3 + normalized * 10
            )
        case .tennis:
            return GamePhysicsConfig(
                jumpHeight: 0.4 + normalized * 0.6,
                moveSpeed: 0.7 + (normalized + auditBonus) * 0.8,
                impactIntensity: 0.5 + normalized * 0.5,
                floorShakeAmplitude: 0.01 + normalized * 0.02,
                particleTrailDensity: 10 + normalized * 25
            )
        }
    }
}
