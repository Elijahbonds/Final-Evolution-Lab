import Foundation

/// On-device survival-wave engine for `karateEndless`.
///
/// Runs entirely locally (no Nexus backend): escalating waves of opponents,
/// a running score with wave-clear bonuses, a survival timer, and a short
/// intermission beat between rounds. GamePlayView owns one in `@State`, feeds
/// it landed hits and a per-second tick, and reads back the fields it renders
/// in the karate survival HUD. Deterministic given a seed.
nonisolated struct KarateEndlessWaveEngine: Sendable {

    enum Phase: String, Sendable {
        case combat
        case intermission
        case defeat
    }

    // MARK: - Tuning

    static let playerMaxHP = 100
    static let intermissionDuration: TimeInterval = 2.6
    static let waveClearBaseBonus = 50
    static let waveClearPerWave = 15

    // MARK: - State

    private(set) var wave: Int = 1
    private(set) var phase: Phase = .combat
    private(set) var playerHP: Int = playerMaxHP
    private(set) var score: Int = 0
    private(set) var opponentsRemaining: Int = 1
    private(set) var opponentsClearedThisWave: Int = 0
    private(set) var intermissionRemaining: TimeInterval = 0
    private(set) var elapsedSeconds: Int = 0
    private(set) var lastClearedWave: Int = 0

    let playerMaxHPValue = playerMaxHP

    var isOver: Bool { phase == .defeat }
    var playerHPFraction: Double { Double(playerHP) / Double(Self.playerMaxHP) }

    /// Difficulty profile for the current wave — the opponent AI is built from
    /// this each time a new opponent spawns.
    var currentDifficulty: KarateOpponentAI.Difficulty {
        KarateOpponentAI.Difficulty.forWave(wave)
    }

    init() {
        opponentsRemaining = Self.opponentsForWave(1)
    }

    // MARK: - Wave shape

    /// Opponents alive simultaneously is 1 (single-lane duel feel); this is the
    /// number the player must defeat to clear the wave.
    static func opponentsForWave(_ wave: Int) -> Int {
        switch wave {
        case ..<4: return 2
        case ..<7: return 3
        case ..<10: return 4
        default: return 4 + (wave - 10) / 2
        }
    }

    /// Score multiplier that grows with depth, rewarding survival.
    var scoreMultiplier: Double { 1.0 + Double(wave - 1) * 0.12 }

    // MARK: - Events

    /// Register a landed player strike on the active opponent. `basePoints`
    /// and `comboMultiplier` come from the existing scoring path.
    mutating func registerPlayerHit(basePoints: Int, comboMultiplier: Double) {
        guard phase == .combat else { return }
        let gained = Int((Double(basePoints) * comboMultiplier * scoreMultiplier).rounded())
        score += max(1, gained)
    }

    /// Register that the active opponent was defeated. Returns true if this
    /// cleared the wave (caller shows the "WAVE CLEARED" beat).
    @discardableResult
    mutating func registerOpponentDefeated() -> Bool {
        guard phase == .combat else { return false }
        opponentsClearedThisWave += 1
        opponentsRemaining = max(0, opponentsRemaining - 1)
        if opponentsRemaining == 0 {
            clearWave()
            return true
        }
        return false
    }

    /// Player took an unblocked opponent strike.
    mutating func registerPlayerDamage(_ amount: Int) {
        guard phase == .combat else { return }
        playerHP = max(0, playerHP - amount)
        if playerHP == 0 { phase = .defeat }
    }

    private mutating func clearWave() {
        lastClearedWave = wave
        score += Self.waveClearBaseBonus + wave * Self.waveClearPerWave
        phase = .intermission
        intermissionRemaining = Self.intermissionDuration
    }

    // MARK: - Tick

    /// Advance one second of survival time. Drives intermission countdown and
    /// a small heal between rounds, then spawns the next wave.
    mutating func tickSecond() {
        guard phase != .defeat else { return }
        elapsedSeconds += 1
        if phase == .intermission {
            intermissionRemaining -= 1
            playerHP = min(Self.playerMaxHP, playerHP + 5)   // light regen between waves
            if intermissionRemaining <= 0 {
                advanceWave()
            }
        }
    }

    private mutating func advanceWave() {
        wave += 1
        opponentsClearedThisWave = 0
        opponentsRemaining = Self.opponentsForWave(wave)
        phase = .combat
        intermissionRemaining = 0
    }

    // MARK: - Summary

    struct Summary: Sendable {
        let wavesSurvived: Int
        let finalScore: Int
        let survivalSeconds: Int
    }

    func makeSummary() -> Summary {
        Summary(wavesSurvived: max(0, lastClearedWave),
                finalScore: score,
                survivalSeconds: elapsedSeconds)
    }
}
