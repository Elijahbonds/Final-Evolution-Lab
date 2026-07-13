import Testing
@testable import FinalEvolutionLab

struct BasketballDribbleStateTests {

    // MARK: - Possession / animation-state selection

    @Test func hasBallAndMovingSelectsDribbleLoop() {
        let state = BasketballDribbleLogic.state(
            hasBall: true, stickMagnitude: 0.9, crossoverActive: false)
        #expect(state == .dribbleMoving)
        #expect(state.dribbleClip == .dribbleLoop)
        #expect(state.hasBall)
    }

    @Test func hasBallAndStandingSelectsDribbleIdle() {
        let state = BasketballDribbleLogic.state(
            hasBall: true, stickMagnitude: 0.02, crossoverActive: false)
        #expect(state == .dribbleIdle)
        #expect(state.dribbleClip == .dribbleIdle)
        #expect(state.hasBall)
    }

    @Test func noBallSelectsLocomotion() {
        let moving = BasketballDribbleLogic.state(
            hasBall: false, stickMagnitude: 0.9, crossoverActive: false)
        let standing = BasketballDribbleLogic.state(
            hasBall: false, stickMagnitude: 0.0, crossoverActive: false)
        #expect(moving == .locomotion)
        #expect(standing == .locomotion)
        // No-ball ⇒ falls through to the existing walk/run/idle (no dribble clip).
        #expect(moving.dribbleClip == nil)
        #expect(!moving.hasBall)
    }

    @Test func crossoverTakesPriorityWhileHoldingBall() {
        // Even while moving, an active crossover one-shot wins.
        let state = BasketballDribbleLogic.state(
            hasBall: true, stickMagnitude: 1.0, crossoverActive: true)
        #expect(state == .crossover)
        #expect(state.dribbleClip == .dribbleCrossover)
    }

    @Test func crossoverIgnoredWithoutBall() {
        let state = BasketballDribbleLogic.state(
            hasBall: false, stickMagnitude: 0.0, crossoverActive: true)
        #expect(state == .locomotion)
    }

    @Test func moveThresholdBoundary() {
        let t = BasketballDribbleLogic.moveThreshold
        // At/below threshold ⇒ idle; strictly above ⇒ moving.
        #expect(BasketballDribbleLogic.state(hasBall: true, stickMagnitude: t, crossoverActive: false) == .dribbleIdle)
        #expect(BasketballDribbleLogic.state(hasBall: true, stickMagnitude: t + 0.01, crossoverActive: false) == .dribbleMoving)
    }

    // MARK: - Ball bounce

    @Test func bounceStaysWithinFloorToWaist() {
        let hz = BasketballDribbleLogic.bounceHzMoving
        var lo = Float.greatestFiniteMagnitude
        var hi = -Float.greatestFiniteMagnitude
        // Sample a couple of full cycles.
        for i in 0..<400 {
            let y = BasketballDribbleLogic.bounceY(t: Float(i) * 0.005, hz: hz)
            lo = min(lo, y); hi = max(hi, y)
            #expect(y >= BasketballDribbleLogic.bounceBottomY - 0.001)
            #expect(y <= BasketballDribbleLogic.bounceTopY + 0.001)
        }
        // The bounce actually spans most of the range (not a flat line).
        #expect(hi - lo > (BasketballDribbleLogic.bounceTopY - BasketballDribbleLogic.bounceBottomY) * 0.8)
    }

    @Test func movingBouncesFasterThanIdle() {
        #expect(BasketballDribbleLogic.bounceHzMoving > BasketballDribbleLogic.bounceHzIdle)
    }
}
