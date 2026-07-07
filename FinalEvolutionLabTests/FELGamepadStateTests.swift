import Testing
import CoreGraphics
@testable import FinalEvolutionLab

@MainActor
struct FELGamepadStateTests {

    @Test func buttonPressAndReleaseEmitEdgeEvents() {
        let state = FELGamepadState()
        var events: [FELPadEvent] = []
        state.onEvent = { events.append($0) }

        state.press(.cross)
        state.press(.cross) // held — must not re-fire
        state.release(.cross)
        state.release(.cross) // already up — must not fire

        #expect(events == [.buttonDown(.cross), .buttonUp(.cross)])
        #expect(state.heldButtons.isEmpty)
    }

    @Test func dpadHoldTracksHeldDirections() {
        let state = FELGamepadState()
        state.press(FELPadDirection.up)
        state.press(FELPadDirection.right)
        #expect(state.heldDirections == [.up, .right])

        state.release(FELPadDirection.up)
        #expect(state.heldDirections == [.right])
    }

    @Test func moveVectorMergesDpadAndStickAndNormalizes() {
        let state = FELGamepadState()

        // D-pad only: unit vector right
        state.press(FELPadDirection.right)
        #expect(state.moveVector.x == 1)
        #expect(state.moveVector.y == 0)

        // Stick pushed up too: combined vector must be normalized to length 1
        state.leftStick = CGPoint(x: 0, y: 1)
        let merged = state.moveVector
        let magnitude = hypot(merged.x, merged.y)
        #expect(abs(magnitude - 1) < 0.0001)
        #expect(merged.x > 0 && merged.y > 0)
    }

    @Test func stickDeadzoneZeroesSmallDeflections() {
        let state = FELGamepadState()
        state.setStick(\.leftStick, raw: CGPoint(x: 0.03, y: 0.02))
        #expect(state.leftStick == .zero)

        state.setStick(\.leftStick, raw: CGPoint(x: 1, y: 0))
        #expect(abs(state.leftStick.x - 1) < 0.0001)
    }

    @Test func resetClearsEverything() {
        let state = FELGamepadState()
        state.press(.l2)
        state.press(FELPadDirection.down)
        state.leftStick = CGPoint(x: 0.5, y: 0.5)

        state.reset()

        #expect(state.heldButtons.isEmpty)
        #expect(state.heldDirections.isEmpty)
        #expect(state.leftStick == .zero)
    }
}
