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

nonisolated enum ArcadeFaceButton: String, Sendable, CaseIterable {
    case square
    case triangle
    case circle
    case cross

    var dunkCategory: String {
        switch self {
        case .square: return "Windmill"
        case .triangle: return "Contortion"
        case .circle: return "Power"
        case .cross: return "Technical"
        }
    }

    var symbol: String {
        switch self {
        case .square: return "□"
        case .triangle: return "△"
        case .circle: return "○"
        case .cross: return "✕"
        }
    }

    var displayColor: (r: Double, g: Double, b: Double) {
        switch self {
        case .square: return (0.96, 0.44, 0.71)
        case .triangle: return (0.3, 0.78, 0.47)
        case .circle: return (0.97, 0.44, 0.44)
        case .cross: return (0.38, 0.65, 0.98)
        }
    }
}

nonisolated enum DunkModifier: String, Sendable {
    case standard
    case flashy
    case power
    case signature

    var label: String {
        switch self {
        case .standard: return "STANDARD"
        case .flashy: return "FLASHY"
        case .power: return "POWER"
        case .signature: return "SIGNATURE"
        }
    }

    var scoreMultiplier: Double {
        switch self {
        case .standard: return 1.0
        case .flashy: return 1.25
        case .power: return 1.35
        case .signature: return 1.8
        }
    }
}

nonisolated struct InputBufferEntry: Sendable {
    let button: ArcadeFaceButton
    let timestamp: Double
    let modifier: DunkModifier
}

nonisolated struct ArcadeInputBuffer: Sendable {
    static let bufferWindowFrames: Int = 4
    static let bufferWindowSeconds: Double = Double(bufferWindowFrames) / 60.0
    static let doubleTapWindow: Double = 0.25
    static let comboChainWindow: Double = 0.4

    let entries: [InputBufferEntry]

    init(entries: [InputBufferEntry] = []) {
        self.entries = entries
    }

    func adding(_ entry: InputBufferEntry) -> ArcadeInputBuffer {
        var updated = entries.filter { entry.timestamp - $0.timestamp < Self.comboChainWindow }
        updated.append(entry)
        if updated.count > 8 { updated = Array(updated.suffix(8)) }
        return ArcadeInputBuffer(entries: updated)
    }

    var lastEntry: InputBufferEntry? { entries.last }

    func isDoubleTap(_ button: ArcadeFaceButton) -> Bool {
        let matching = entries.filter { $0.button == button }
        guard matching.count >= 2 else { return false }
        let last = matching[matching.count - 1]
        let prev = matching[matching.count - 2]
        return (last.timestamp - prev.timestamp) < Self.doubleTapWindow
    }

    func comboChain() -> [ArcadeFaceButton] {
        guard let last = entries.last else { return [] }
        return entries
            .filter { last.timestamp - $0.timestamp < Self.comboChainWindow }
            .map { $0.button }
    }

    var chainLength: Int { comboChain().count }

    func isMidAirBranch() -> Bool {
        let chain = comboChain()
        guard chain.count >= 2 else { return false }
        return chain[chain.count - 1] != chain[chain.count - 2]
    }
}

nonisolated struct MidAirTrickState: Sendable {
    var activeTricks: [ArcadeFaceButton] = []
    var branchCount: Int = 0
    var comboMultiplier: Double = 1.0
    var totalStylePoints: Int = 0
    var isStyleLandingAvailable: Bool = false

    static let maxBranches: Int = 3
    static let branchBonusMultiplier: Double = 0.3

    mutating func addTrick(_ button: ArcadeFaceButton) {
        let isBranch = !activeTricks.isEmpty && activeTricks.last != button
        activeTricks.append(button)
        if isBranch && branchCount < Self.maxBranches {
            branchCount += 1
            comboMultiplier += Self.branchBonusMultiplier
        }
    }

    mutating func addStylePoints(_ points: Int) {
        totalStylePoints += Int(Double(points) * comboMultiplier)
    }

    mutating func styleLandingRevert() -> Int {
        guard isStyleLandingAvailable else { return 0 }
        isStyleLandingAvailable = false
        let bonus = Int(Double(totalStylePoints) * 0.25)
        comboMultiplier += 0.5
        return bonus
    }

    mutating func reset() {
        activeTricks = []
        branchCount = 0
        comboMultiplier = 1.0
        totalStylePoints = 0
        isStyleLandingAvailable = false
    }

    var trickChainLabel: String {
        activeTricks.map { $0.dunkCategory }.joined(separator: " → ")
    }
}

nonisolated struct DunkTrickResolver: Sendable {
    static func resolve(button: ArcadeFaceButton, modifier: DunkModifier, isDoubleTap: Bool) -> DunkTrickSlot {
        switch button {
        case .square:
            if isDoubleTap { return .freeThrowLine }
            return modifier == .power ? .doubleClutch : .windmill
        case .triangle:
            if isDoubleTap { return .elbowHang }
            return modifier == .flashy ? .betweenLegs : .threeSixty
        case .circle:
            if isDoubleTap { return .reverseJam }
            return modifier == .power ? .freeThrowLine : .tomahawk
        case .cross:
            if isDoubleTap { return .doubleClutch }
            return modifier == .flashy ? .elbowHang : .reverseJam
        }
    }

    static func freestylePoints(button: ArcadeFaceButton, modifier: DunkModifier, isDoubleTap: Bool, chainLength: Int) -> Int {
        let trick = resolve(button: button, modifier: modifier, isDoubleTap: isDoubleTap)
        let base = trick.baseStylePoints
        let modBonus = Int(Double(base) * (modifier.scoreMultiplier - 1.0))
        let chainBonus = chainLength > 1 ? (chainLength - 1) * 3 : 0
        let doubleTapBonus = isDoubleTap ? 5 : 0
        return base + modBonus + chainBonus + doubleTapBonus
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

    static let dunkContest = PS2MovementConfig(
        topSpeed: 10.0,
        acceleration: 50,
        deceleration: 80,
        airControl: 0.65,
        baseJump: 8.0,
        chargedJump: 16.0,
        cameraLerpFactor: 6,
        cameraTargetLerpFactor: 8
    )

    static func forMode(_ mode: GameModeId) -> PS2MovementConfig {
        switch mode {
        case .basketballDunkContest:
            return .dunkContest
        case .basketballHeadToHead, .basketball3v3:
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
        case .baseball:
            return PS2MovementConfig(
                topSpeed: 5.0,
                acceleration: 8,
                deceleration: 20,
                airControl: 0.12,
                baseJump: 3.0,
                chargedJump: 5.0,
                cameraLerpFactor: 9,
                cameraTargetLerpFactor: 11
            )
        case .golf:
            return PS2MovementConfig(
                topSpeed: 4.0,
                acceleration: 6,
                deceleration: 18,
                airControl: 0.08,
                baseJump: 2.0,
                chargedJump: 4.0,
                cameraLerpFactor: 7,
                cameraTargetLerpFactor: 9
            )
        case .tennis:
            return PS2MovementConfig(
                topSpeed: 7.0,
                acceleration: 13,
                deceleration: 27,
                airControl: 0.24,
                baseJump: 6.0,
                chargedJump: 11.0,
                cameraLerpFactor: 8,
                cameraTargetLerpFactor: 10
            )
        case .gymnastics:
            return PS2MovementConfig(
                topSpeed: 6.0,
                acceleration: 14,
                deceleration: 30,
                airControl: 0.28,
                baseJump: 7.5,
                chargedJump: 12.0,
                cameraLerpFactor: 8,
                cameraTargetLerpFactor: 10
            )
        case .brainBrawl:
            return PS2MovementConfig(
                topSpeed: 5.0,
                acceleration: 8,
                deceleration: 22,
                airControl: 0.15,
                baseJump: 4.0,
                chargedJump: 6.0,
                cameraLerpFactor: 9,
                cameraTargetLerpFactor: 11
            )
        }
    }
}
