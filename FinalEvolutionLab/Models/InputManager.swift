import Foundation
import QuartzCore

nonisolated struct InputManager: Sendable {
    static let ps2PollIntervalMs: Double = 17
    static let inputLatencyMs: Double = 28
    static let deadzoneRadius: Double = 0.08
    static let deadzoneInner: Double = 0.06

    static func applyDeadzone(_ value: Double, inner: Double = deadzoneInner, outer: Double = 1.0) -> Double {
        let v = max(0, min(outer, value))
        if v <= inner { return 0 }
        return (v - inner) / (outer - inner)
    }

    static func getAnalogStick(x: Double, y: Double, inner: Double = deadzoneInner) -> (x: Double, y: Double, magnitude: Double) {
        let mag = hypot(x, y)
        if mag <= inner { return (0, 0, 0) }
        let rescale = (mag - inner) / (1 - inner)
        let scale = rescale / mag
        return (x * scale, y * scale, min(1, rescale))
    }
}

nonisolated enum ComboDirection: String, Sendable {
    case up, down, left, right, neutral

    var trickDirection: TrickDirection {
        switch self {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .neutral: return .neutral
        }
    }
}

nonisolated struct ComboInput: Sendable {
    let direction: ComboDirection
    let timestamp: Double
    let isModifierHeld: Bool
}

nonisolated struct ComboResolver: Sendable {
    static let comboWindowSeconds: Double = 0.5
    static let doubleTapWindowSeconds: Double = 0.3

    static var dunkModes: Set<GameModeId> {
        [.basketballHeadToHead, .basketballDunkContest, .basketball3v3]
    }

    static var combatModes: Set<GameModeId> {
        [.karate]
    }

    static func isDunkAllowed(for mode: GameModeId) -> Bool {
        dunkModes.contains(mode)
    }

    static func isCombatAllowed(for mode: GameModeId) -> Bool {
        combatModes.contains(mode)
    }

    static func resolve(inputs: [ComboInput], mode: GameModeId) -> TrickCombo? {
        guard !inputs.isEmpty else { return nil }

        let now = inputs.last?.timestamp ?? 0
        let recent = inputs.filter { now - $0.timestamp < comboWindowSeconds }
        guard let latest = recent.last, latest.isModifierHeld else { return nil }

        if recent.count >= 2 {
            let prev = recent[recent.count - 2]
            if prev.direction == .down && latest.direction == .down &&
               (latest.timestamp - prev.timestamp) < doubleTapWindowSeconds {
                let specials = TrickCombo.combos(for: mode).filter { $0.isSpecial }
                if let special = specials.first { return special }
            }
        }

        return TrickCombo.resolve(direction: latest.direction.trickDirection, mode: mode)
    }

    static func resolveFromAction(_ action: String, direction: ComboDirection, isModifierHeld: Bool, mode: GameModeId) -> TrickCombo? {
        guard isModifierHeld else { return nil }
        if action == "Dunk" || action == "Power Dunk" || action == "360 Dunk" || action == "Windmill" {
            guard isDunkAllowed(for: mode) else { return nil }
        }
        if action == "Punch" || action == "Kick" || action == "Block" {
            guard isCombatAllowed(for: mode) else { return nil }
        }
        return TrickCombo.resolve(direction: direction.trickDirection, mode: mode)
    }
}

nonisolated struct CombatInputResolver: Sendable {
    static let perfectGuardWindowSeconds: Double = 0.1
    static let vanishWindowSeconds: Double = 0.15

    static func resolveCombatAction(
        blockPressed: Bool,
        blockTimestamp: Double,
        impactTimestamp: Double,
        stickDirection: ComboDirection?,
        mode: GameModeId = .karate
    ) -> CombatOutcome {
        guard ComboResolver.isCombatAllowed(for: mode) else { return .hit }
        guard blockPressed else { return .hit }

        let reactionTime = abs(impactTimestamp - blockTimestamp)

        if reactionTime <= perfectGuardWindowSeconds {
            if let dir = stickDirection, dir != .neutral {
                return .vanishCounter
            }
            return .perfectGuard
        }

        return .standardBlock
    }
}

nonisolated enum CombatOutcome: String, Sendable {
    case hit
    case standardBlock
    case perfectGuard
    case vanishCounter
}

nonisolated struct DefensiveInputState: Sendable {
    var handsUp: Bool = false
    var quickProtectEndTime: Double = 0
    var defenderDistance: Double = 4.0
    var isBodyUp: Bool = false

    var isQuickProtectActive: Bool {
        CACurrentMediaTime() < quickProtectEndTime
    }

    var driveSpeedMultiplier: Double {
        isQuickProtectActive ? DefensivePhysics.quickProtectSpeedMultiplier : 1.0
    }

    var isStealIgnored: Bool {
        isQuickProtectActive
    }

    func contestResult() -> (percent: Int, label: String, tier: ContestTier) {
        let pct = DefensivePhysics.contestPercent(distance: defenderDistance, handsUp: handsUp)
        let label = DefensivePhysics.contestLabel(percent: pct)
        let tier = DefensivePhysics.contestMeterColor(percent: pct)
        return (pct, label, tier)
    }

    mutating func activateQuickProtect() {
        quickProtectEndTime = CACurrentMediaTime() + DefensivePhysics.quickProtectDurationSeconds
    }

    mutating func toggleHandsUp() {
        handsUp.toggle()
    }

    mutating func updateDefenderDistance(shooterPos: SIMD3<Double>, defenderPos: SIMD3<Double>) {
        let dx = shooterPos.x - defenderPos.x
        let dy = (shooterPos.y - defenderPos.y) * 0.5
        let dz = shooterPos.z - defenderPos.z
        defenderDistance = sqrt(dx * dx + dy * dy + dz * dz)
    }
}

nonisolated struct PS2MovementConfig: Sendable {
    let topSpeed: Float
    let acceleration: Float
    let deceleration: Float
    let airControl: Float
    let baseJump: Float
    let chargedJump: Float
    let cameraLerpFactor: Float
    let cameraTargetLerpFactor: Float

    static let standard = PS2MovementConfig(
        topSpeed: 8.5,
        acceleration: 12,
        deceleration: 28,
        airControl: 0.22,
        baseJump: 7.2,
        chargedJump: 13.2,
        cameraLerpFactor: 8,
        cameraTargetLerpFactor: 10
    )

    static func forMode(_ mode: GameModeId) -> PS2MovementConfig {
        switch mode {
        case .basketballHeadToHead, .basketballDunkContest, .basketball3v3:
            return .standard
        case .karate:
            return PS2MovementConfig(
                topSpeed: 7.0,
                acceleration: 14,
                deceleration: 32,
                airControl: 0.18,
                baseJump: 5.5,
                chargedJump: 9.0,
                cameraLerpFactor: 10,
                cameraTargetLerpFactor: 12
            )
        case .volleyball:
            return PS2MovementConfig(
                topSpeed: 6.5,
                acceleration: 11,
                deceleration: 26,
                airControl: 0.20,
                baseJump: 8.0,
                chargedJump: 14.0,
                cameraLerpFactor: 8,
                cameraTargetLerpFactor: 10
            )
        case .football:
            return PS2MovementConfig(
                topSpeed: 9.5,
                acceleration: 10,
                deceleration: 20,
                airControl: 0.15,
                baseJump: 4.0,
                chargedJump: 7.0,
                cameraLerpFactor: 7,
                cameraTargetLerpFactor: 9
            )
        case .soccer:
            return PS2MovementConfig(
                topSpeed: 8.0,
                acceleration: 12,
                deceleration: 28,
                airControl: 0.20,
                baseJump: 5.0,
                chargedJump: 8.0,
                cameraLerpFactor: 8,
                cameraTargetLerpFactor: 10
            )
        default:
            return PS2MovementConfig(
                topSpeed: 7.0,
                acceleration: 11,
                deceleration: 25,
                airControl: 0.20,
                baseJump: 5.0,
                chargedJump: 9.0,
                cameraLerpFactor: 8,
                cameraTargetLerpFactor: 10
            )
        }
    }
}
