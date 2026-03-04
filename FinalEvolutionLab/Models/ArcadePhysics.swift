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
    let perfectGuardWindow: Double
    let specialMeterGainRate: Double

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
            auraLevel: aura,
            perfectGuardWindow: 0.1 + normalized * 0.05,
            specialMeterGainRate: 8.0 + normalized * 12.0
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

    func trickStylePoints(for trick: TrickCombo) -> Int {
        let base = trick.baseStylePoints
        let speedBonus = trick.requiresFastInput ? 2 : 0
        let burst = neuralBurstActive ? Int(Double(base) * 0.5) : 0
        return base + speedBonus + burst
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

nonisolated struct DunkPhysicsConfig: Sendable {
    static let qteWindowSeconds: Double = 0.4
    static let apexWindowSeconds: Double = 0.35

    let launchUpward: Float
    let launchForward: Float
    let hangTimeMultiplier: Float

    static func fromPRQ(_ prq: Double, physicsConfig: GamePhysicsConfig) -> DunkPhysicsConfig {
        let normalized = Float(min(max(prq / 100.0, 0), 1))
        return DunkPhysicsConfig(
            launchUpward: 15 + normalized * 5,
            launchForward: 3.5 + normalized * 1.5,
            hangTimeMultiplier: 1.0 + normalized * 0.5
        )
    }
}

nonisolated enum TrickDirection: String, Sendable, CaseIterable {
    case up, down, left, right, neutral
}

nonisolated struct TrickCombo: Sendable, Identifiable {
    let id: String
    let name: String
    let displayName: String
    let direction: TrickDirection
    let requiresFastInput: Bool
    let baseStylePoints: Int
    let isSpecial: Bool
    let riskMultiplier: Double

    static let dunkCombos: [TrickCombo] = [
        TrickCombo(id: "windmill", name: "Windmill Dunk", displayName: "WINDMILL!", direction: .up, requiresFastInput: false, baseStylePoints: 8, isSpecial: false, riskMultiplier: 1.0),
        TrickCombo(id: "between_legs", name: "Between the Legs", displayName: "BETWEEN THE LEGS!", direction: .down, requiresFastInput: false, baseStylePoints: 9, isSpecial: false, riskMultiplier: 1.1),
        TrickCombo(id: "tomahawk", name: "Tomahawk", displayName: "TOMAHAWK!", direction: .left, requiresFastInput: false, baseStylePoints: 7, isSpecial: false, riskMultiplier: 0.9),
        TrickCombo(id: "360_dunk", name: "360 Dunk", displayName: "360!", direction: .right, requiresFastInput: false, baseStylePoints: 10, isSpecial: false, riskMultiplier: 1.2),
        TrickCombo(id: "giant_killer", name: "Giant Killer", displayName: "GIANT KILLER!", direction: .neutral, requiresFastInput: true, baseStylePoints: 15, isSpecial: true, riskMultiplier: 1.5),
    ]

    static let karateCombos: [TrickCombo] = [
        TrickCombo(id: "rasengan", name: "Rasengan Strike", displayName: "RASENGAN!", direction: .up, requiresFastInput: false, baseStylePoints: 8, isSpecial: false, riskMultiplier: 1.0),
        TrickCombo(id: "lions_barrage", name: "Lion's Barrage", displayName: "LION'S BARRAGE!", direction: .down, requiresFastInput: true, baseStylePoints: 12, isSpecial: false, riskMultiplier: 1.3),
        TrickCombo(id: "chidori", name: "Chidori", displayName: "CHIDORI!", direction: .left, requiresFastInput: false, baseStylePoints: 10, isSpecial: false, riskMultiplier: 1.1),
        TrickCombo(id: "shadow_clone", name: "Shadow Clone Combo", displayName: "SHADOW CLONE!", direction: .right, requiresFastInput: false, baseStylePoints: 9, isSpecial: false, riskMultiplier: 1.0),
        TrickCombo(id: "gate_of_death", name: "Gate of Death", displayName: "GATE OF DEATH!", direction: .neutral, requiresFastInput: true, baseStylePoints: 20, isSpecial: true, riskMultiplier: 2.0),
    ]

    static func combos(for mode: GameModeId) -> [TrickCombo] {
        switch mode {
        case .basketballDunkContest, .basketballHeadToHead, .basketball3v3:
            return dunkCombos
        case .karate:
            return karateCombos
        default:
            return dunkCombos
        }
    }

    static func resolve(direction: TrickDirection, mode: GameModeId) -> TrickCombo {
        let pool = combos(for: mode)
        return pool.first(where: { $0.direction == direction }) ?? pool[0]
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
        case .volleyball:
            return GamePhysicsConfig(
                jumpHeight: 1.2 + (normalized + auditBonus) * 2.0,
                moveSpeed: 0.6 + (normalized + auditBonus) * 0.7,
                impactIntensity: 0.5 + normalized * 0.6,
                floorShakeAmplitude: 0.02 + normalized * 0.03,
                particleTrailDensity: 10 + normalized * 25
            )
        case .gymnastics:
            return GamePhysicsConfig(
                jumpHeight: 1.0 + normalized * 1.8,
                moveSpeed: 0.5 + normalized * 0.6,
                impactIntensity: 0.4 + normalized * 0.5,
                floorShakeAmplitude: 0.01 + normalized * 0.03,
                particleTrailDensity: 12 + normalized * 28
            )
        }
    }
}
