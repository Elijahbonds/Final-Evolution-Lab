import Foundation

/// Deterministic, on-device opponent AI for the karate modes.
///
/// Replaces the static red-tinted mirror with a readable attack/block/idle
/// rhythm. Fully deterministic (seeded ``SplitMix64``) so investor demos and
/// tests replay identically. Pure model — no SceneKit here; ``tick(now:)``
/// emits ``Intent`` values that the scene coordinator turns into fresh clip
/// swaps (never clones) and the HUD turns into an HP bar.
nonisolated struct KarateOpponentAI: Sendable {

    // MARK: - Attacks

    enum Attack: String, Sendable, CaseIterable {
        case jab, hook, uppercut, roundhouse, highKick

        var asset: FELBundledAsset {
            switch self {
            case .jab: return .elijahStrikeJab
            case .hook: return .elijahStrikeHook
            case .uppercut: return .elijahStrikeUppercut
            case .roundhouse: return .elijahStrikeRoundhouse
            case .highKick: return .elijahStrikeHighKick
            }
        }

        /// Damage dealt to the player if the attack lands unblocked.
        var damage: Int {
            switch self {
            case .jab: return 6
            case .hook: return 9
            case .uppercut: return 12
            case .roundhouse: return 14
            case .highKick: return 16
            }
        }

        /// Approx. baked-clip length; used as the recover budget if the clip
        /// hierarchy reports no animation player.
        var clipDuration: TimeInterval {
            switch self {
            case .jab: return 0.5
            case .hook: return 0.55
            case .uppercut: return 0.6
            case .roundhouse: return 0.75
            case .highKick: return 0.8
            }
        }
    }

    /// What the opponent intends this frame. The coordinator maps these to
    /// visuals; equatable so it only re-applies on transitions.
    enum Intent: Equatable, Sendable {
        case idle
        /// Wind-up telegraph before the strike lands. Player can block during
        /// this window. `landsAt` is the absolute time the hit resolves.
        case telegraph(Attack, landsAt: TimeInterval)
        /// The strike resolves this frame (one-shot edge).
        case strike(Attack)
        case block
        /// Knocked back after being hit; recovering.
        case stagger
    }

    // MARK: - Difficulty

    struct Difficulty: Sendable {
        var attackChance: Double       // share of decisions that become attacks
        var blockChance: Double        // share that become blocks
        var telegraph: TimeInterval    // wind-up window (fair-block budget)
        var actionGap: ClosedRange<TimeInterval>  // idle between decisions
        var maxHP: Int

        static let easy = Difficulty(
            attackChance: 0.45, blockChance: 0.15, telegraph: 0.55,
            actionGap: 1.1...2.0, maxHP: 60)
        static let normal = Difficulty(
            attackChance: 0.60, blockChance: 0.20, telegraph: 0.45,
            actionGap: 0.8...1.6, maxHP: 80)
        static let hard = Difficulty(
            attackChance: 0.72, blockChance: 0.28, telegraph: 0.35,
            actionGap: 0.55...1.15, maxHP: 110)

        /// Endless-wave scaling: tightens gaps, shortens telegraphs, raises HP.
        static func forWave(_ wave: Int) -> Difficulty {
            let w = max(1, wave)
            let ramp = min(1.0, Double(w - 1) / 12.0)   // 0 at wave 1 → 1 at wave 13
            let gapLo = 1.1 - 0.55 * ramp
            let gapHi = 2.0 - 0.85 * ramp
            return Difficulty(
                attackChance: 0.45 + 0.27 * ramp,
                blockChance: 0.15 + 0.13 * ramp,
                telegraph: max(0.32, 0.55 - 0.23 * ramp),
                actionGap: gapLo...gapHi,
                maxHP: 55 + min(w, 13) * 5)
        }
    }

    // MARK: - State

    private var rng: SplitMix64
    private let difficulty: Difficulty
    private(set) var hp: Int
    let maxHP: Int

    private var intent: Intent = .idle
    private var stateEndsAt: TimeInterval = 0
    private var started = false

    var isDefeated: Bool { hp <= 0 }
    var hpFraction: Double { maxHP > 0 ? Double(hp) / Double(maxHP) : 0 }
    /// True only during a telegraph/strike window — the moment a player hit
    /// can be blocked by the opponent's own guard is tracked separately.
    var isBlocking: Bool { intent == .block }

    init(difficulty: Difficulty = .normal, seed: UInt64) {
        self.difficulty = difficulty
        self.maxHP = difficulty.maxHP
        self.hp = difficulty.maxHP
        self.rng = SplitMix64(seed: seed)
    }

    // MARK: - Tick

    /// Advance the state machine. Returns the current intent; a `.strike` is
    /// emitted for exactly one tick when a telegraph resolves.
    mutating func tick(now: TimeInterval) -> Intent {
        if !started {
            started = true
            enterIdle(now: now)
            return intent
        }

        switch intent {
        case .telegraph(let attack, let landsAt):
            if now >= landsAt {
                intent = .strike(attack)
                stateEndsAt = now + attack.clipDuration
                return intent
            }
            return intent

        case .strike:
            // The `.strike` edge was returned on the previous tick and already
            // consumed by the caller (visual swap + damage). Collapse to an
            // idle-visual recover, keeping the clip's `stateEndsAt` budget, then
            // decide the next action once recover elapses.
            intent = .idle
            if now >= stateEndsAt {
                decide(now: now)
            }
            return intent

        case .idle, .block, .stagger:
            if now >= stateEndsAt {
                decide(now: now)
            }
            return intent
        }
    }

    /// Apply a landed player strike: damage + stagger, interrupting any plan.
    mutating func takeDamage(_ amount: Int, now: TimeInterval) {
        hp = max(0, hp - amount)
        intent = .stagger
        stateEndsAt = now + 0.45
    }

    // MARK: - Decisions

    private mutating func decide(now: TimeInterval) {
        let roll = rng.nextDouble(in: 0...1)
        if roll < difficulty.attackChance {
            let attack = Attack.allCases[Int(rng.next() % UInt64(Attack.allCases.count))]
            intent = .telegraph(attack, landsAt: now + difficulty.telegraph)
            stateEndsAt = now + difficulty.telegraph
        } else if roll < difficulty.attackChance + difficulty.blockChance {
            intent = .block
            stateEndsAt = now + rng.nextDouble(in: 0.35...0.7)
        } else {
            enterIdle(now: now)
        }
    }

    private mutating func enterIdle(now: TimeInterval) {
        intent = .idle
        stateEndsAt = now + rng.nextDouble(in: difficulty.actionGap)
    }
}
