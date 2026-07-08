import Foundation

/// Deterministic, self-contained combo tracker for the karate modes.
///
/// Chains successive landed strikes into a combo while each hit lands inside
/// ``comboResetWindow`` of the previous one. Drives the combo-counter HUD
/// (tier label + damage multiplier) and recognizes a handful of named
/// button-sequence chains for bonus points. Value type — GamePlayView holds
/// it in `@State` and mutates it on the main actor.
nonisolated struct KarateComboTracker: Sendable {

    // MARK: - Tuning

    /// Consecutive hits chain while each lands within this window (seconds).
    static let comboResetWindow: TimeInterval = 1.35

    /// Ascending tiers: `threshold` hits → `multiplier` damage/points, `label`.
    static let tiers: [(threshold: Int, multiplier: Double, label: String)] = [
        (2, 1.15, "COMBO"),
        (3, 1.30, "STRONG"),
        (5, 1.55, "BLAZING"),
        (8, 1.90, "INFERNO"),
        (12, 2.40, "LEGENDARY"),
    ]

    // MARK: - State

    private(set) var count: Int = 0
    private(set) var multiplier: Double = 1.0
    private(set) var lastHitTime: TimeInterval = 0

    // MARK: - Derived

    /// Human-readable tier label for the current count ("" below the first tier).
    var tierLabel: String {
        Self.tiers.last(where: { $0.threshold <= count })?.label ?? ""
    }

    /// True once the combo is deep enough to warrant elite HUD glow.
    var isElite: Bool { count >= 5 }

    // MARK: - Mutation

    /// Register a landed strike at `time`. Chains if inside the window,
    /// otherwise restarts the count at 1. Returns the new count.
    @discardableResult
    mutating func register(at time: TimeInterval) -> Int {
        if count > 0, time - lastHitTime <= Self.comboResetWindow {
            count += 1
        } else {
            count = 1
        }
        lastHitTime = time
        updateMultiplier()
        return count
    }

    /// Expire the combo if the window has elapsed since the last hit. Call
    /// from a lightweight tick loop. Returns true if it just expired.
    @discardableResult
    mutating func tickExpiry(now: TimeInterval) -> Bool {
        guard count > 0, now - lastHitTime > Self.comboResetWindow else { return false }
        reset()
        return true
    }

    /// Hard reset (miss, round end).
    mutating func reset() {
        count = 0
        multiplier = 1.0
        lastHitTime = 0
    }

    private mutating func updateMultiplier() {
        multiplier = Self.tiers.last(where: { $0.threshold <= count })?.multiplier ?? 1.0
    }
}

/// Named button-sequence chains. Detection runs against the tail of the
/// player's recent face-button history; a match awards flat bonus points and
/// a splash label. Purely offensive flourish — independent of the numeric
/// combo tier above.
nonisolated enum KarateNamedCombo: String, Sendable, CaseIterable {
    case rush       // Jab → Jab → Hook
    case launcher   // Jab → Uppercut
    case storm      // Roundhouse → Roundhouse
    case inferno    // Hook → Hook → Roundhouse
    case cyclone    // Uppercut → Uppercut → Uppercut
    case finisher   // Roundhouse → Uppercut → Jab

    var displayName: String {
        switch self {
        case .rush: return "RUSH"
        case .launcher: return "LAUNCHER"
        case .storm: return "STORM"
        case .inferno: return "INFERNO"
        case .cyclone: return "CYCLONE"
        case .finisher: return "FINISHER"
        }
    }

    var bonusPoints: Int {
        switch self {
        case .rush: return 40
        case .launcher: return 35
        case .storm: return 50
        case .inferno: return 70
        case .cyclone: return 85
        case .finisher: return 120
        }
    }

    /// Face-button pattern (most recent last).
    private var pattern: [ArenaPadFaceButton] {
        switch self {
        case .rush: return [.square, .square, .circle]
        case .launcher: return [.square, .cross]
        case .storm: return [.triangle, .triangle]
        case .inferno: return [.circle, .circle, .triangle]
        case .cyclone: return [.cross, .cross, .cross]
        case .finisher: return [.triangle, .cross, .square]
        }
    }

    /// Longest matching chain whose pattern is a suffix of `history`.
    /// Prefers longer patterns so 3-button chains win over 2-button ones.
    static func detect(in history: [ArenaPadFaceButton]) -> KarateNamedCombo? {
        allCases
            .filter { combo in
                let p = combo.pattern
                return history.count >= p.count && history.suffix(p.count).elementsEqual(p)
            }
            .max(by: { $0.pattern.count < $1.pattern.count })
    }
}
