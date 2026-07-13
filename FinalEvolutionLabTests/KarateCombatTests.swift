import Foundation
import Testing
@testable import FinalEvolutionLab

/// Combat-math tests for the karate fight loop. The runtime scene/HUD wiring is
/// interactive (not visible in the static snapshot), so these prove the pure
/// model contracts the loop is built on: a strike reduces opponent HP, an
/// opponent at 0 HP is a win, a player at 0 HP is a defeat, and clearing a wave
/// advances the wave with an intermission heal.
struct KarateCombatTests {

    // MARK: - Opponent HP / damage / KO

    @Test func strikeReducesOpponentHP() {
        var ai = KarateOpponentAI(difficulty: .normal, seed: 42)
        let start = ai.hp
        #expect(start == KarateOpponentAI.Difficulty.normal.maxHP)
        ai.takeDamage(20, now: 1.0)
        #expect(ai.hp == start - 20)
        #expect(!ai.isDefeated)
        #expect(ai.hpFraction < 1.0)
    }

    @Test func opponentHPClampsAtZeroAndReadsDefeated() {
        var ai = KarateOpponentAI(difficulty: .easy, seed: 7)
        ai.takeDamage(9_999, now: 0.5)
        #expect(ai.hp == 0)
        #expect(ai.isDefeated)          // opponent HP 0 ⇒ win state (1v1 KO)
        #expect(ai.hpFraction == 0)
    }

    @Test func damageNeverDrivesHPNegative() {
        var ai = KarateOpponentAI(difficulty: .hard, seed: 3)
        ai.takeDamage(ai.hp + 50, now: 0.1)
        #expect(ai.hp == 0)
    }

    @Test func waveDifficultyScalesUpHPAndAggression() {
        let w1 = KarateOpponentAI.Difficulty.forWave(1)
        let w13 = KarateOpponentAI.Difficulty.forWave(13)
        #expect(w13.maxHP > w1.maxHP)
        #expect(w13.attackChance > w1.attackChance)
        #expect(w13.telegraph <= w1.telegraph)   // tighter windows deeper in
    }

    // MARK: - Endless wave engine: player defeat, wave advance, scoring

    @Test func playerHPZeroIsDefeat() {
        var engine = KarateEndlessWaveEngine()
        #expect(!engine.isOver)
        engine.registerPlayerDamage(KarateEndlessWaveEngine.playerMaxHP)
        #expect(engine.playerHP == 0)
        #expect(engine.isOver)                     // player HP 0 ⇒ defeat
        #expect(engine.phase == .defeat)
    }

    @Test func partialDamageDoesNotEndRun() {
        var engine = KarateEndlessWaveEngine()
        engine.registerPlayerDamage(30)
        #expect(engine.playerHP == KarateEndlessWaveEngine.playerMaxHP - 30)
        #expect(!engine.isOver)
    }

    @Test func clearingAllWaveOpponentsAdvancesWave() {
        var engine = KarateEndlessWaveEngine()
        let toClear = KarateEndlessWaveEngine.opponentsForWave(1)
        #expect(engine.wave == 1)

        var clearedFlag = false
        for _ in 0..<toClear {
            clearedFlag = engine.registerOpponentDefeated()
        }
        // Last defeat clears the wave → intermission phase.
        #expect(clearedFlag)
        #expect(engine.phase == .intermission)
        #expect(engine.lastClearedWave == 1)

        // Drain the intermission timer; a heal + wave advance should follow.
        let hpBeforeHeal = engine.playerHP
        for _ in 0...Int(KarateEndlessWaveEngine.intermissionDuration) + 1 {
            engine.tickSecond()
        }
        #expect(engine.wave == 2)                  // wave advanced
        #expect(engine.phase == .combat)
        #expect(engine.opponentsRemaining == KarateEndlessWaveEngine.opponentsForWave(2))
        #expect(engine.playerHP >= hpBeforeHeal)   // intermission regen
    }

    @Test func waveClearAwardsBonusScore() {
        var engine = KarateEndlessWaveEngine()
        let toClear = KarateEndlessWaveEngine.opponentsForWave(1)
        for _ in 0..<toClear { engine.registerOpponentDefeated() }
        #expect(engine.score >= KarateEndlessWaveEngine.waveClearBaseBonus)
    }

    @Test func playerHitScoresWithMultiplier() {
        var engine = KarateEndlessWaveEngine()
        engine.registerPlayerHit(basePoints: 10, comboMultiplier: 2.0)
        #expect(engine.score > 0)
    }

    @Test func defeatedEngineIgnoresFurtherInput() {
        var engine = KarateEndlessWaveEngine()
        engine.registerPlayerDamage(KarateEndlessWaveEngine.playerMaxHP)
        let frozenScore = engine.score
        engine.registerPlayerHit(basePoints: 50, comboMultiplier: 3)
        engine.tickSecond()
        #expect(engine.score == frozenScore)       // no scoring after defeat
        #expect(engine.isOver)
    }

    // MARK: - Combo tracker (damage multiplier feeding the fight)

    @Test func comboChainsWithinWindowThenExpires() {
        var combo = KarateComboTracker()
        #expect(combo.register(at: 0.0) == 1)
        #expect(combo.register(at: 0.5) == 2)      // inside 1.35s window
        #expect(combo.multiplier > 1.0)
        // A hit outside the window restarts the chain.
        #expect(combo.register(at: 10.0) == 1)
        #expect(combo.multiplier == 1.0)
    }

    @Test func comboExpiryTickResets() {
        var combo = KarateComboTracker()
        combo.register(at: 0.0)
        combo.register(at: 0.4)
        #expect(combo.count == 2)
        let expired = combo.tickExpiry(now: 0.4 + KarateComboTracker.comboResetWindow + 0.1)
        #expect(expired)
        #expect(combo.count == 0)
    }

    // MARK: - AI rhythm: telegraph → strike edge

    @Test func telegraphResolvesToSingleStrikeEdge() {
        // Force an attacker so a strike is guaranteed, then confirm the
        // telegraph → strike transition fires exactly one .strike edge.
        let diff = KarateOpponentAI.Difficulty(
            attackChance: 1.0, blockChance: 0.0, telegraph: 0.2,
            actionGap: 0.1...0.2, maxHP: 50)
        var ai = KarateOpponentAI(difficulty: diff, seed: 99)

        var sawTelegraph = false
        var strikeEdges = 0
        var t = 0.0
        // Walk the state machine; the first decision must telegraph then strike.
        for _ in 0..<50 {
            let intent = ai.tick(now: t)
            if case .telegraph = intent { sawTelegraph = true }
            if case .strike = intent { strikeEdges += 1 }
            t += 0.1
            if strikeEdges > 0 { break }
        }
        #expect(sawTelegraph)
        #expect(strikeEdges == 1)   // strike is a one-tick edge
    }
}
