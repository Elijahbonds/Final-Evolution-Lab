import SwiftUI

// Legacy pad vocabulary — kept because the FELGamepadState bridge
// (legacyFaceButton/legacyDirection) and the per-mode GamePlayView handlers
// still speak it. Moved here from the retired ArenaPadOverlay view.
nonisolated enum ArenaPadFaceButton: String, Sendable {
    case triangle
    case square
    case circle
    case cross
}

nonisolated enum ArenaPadDPadDirection: String, Sendable {
    case up
    case down
    case left
    case right
}

/// One controller vocabulary for every game mode. Face buttons keep the arcade
/// glyph identity (△ ○ ✕ □); shoulders and triggers are digital on-screen.
nonisolated enum FELPadButton: String, Sendable, CaseIterable, Hashable {
    case cross, circle, square, triangle
    case l1, r1, l2, r2

    var glyph: String {
        switch self {
        case .cross: return "✕"
        case .circle: return "○"
        case .square: return "□"
        case .triangle: return "△"
        case .l1: return "L1"
        case .r1: return "R1"
        case .l2: return "L2"
        case .r2: return "R2"
        }
    }

    var isFaceButton: Bool {
        switch self {
        case .cross, .circle, .square, .triangle: return true
        default: return false
        }
    }

    /// Bridge to the legacy per-mode handlers used by existing gameplay views.
    var legacyFaceButton: ArenaPadFaceButton? {
        switch self {
        case .cross: return .cross
        case .circle: return .circle
        case .square: return .square
        case .triangle: return .triangle
        default: return nil
        }
    }
}

nonisolated enum FELPadDirection: String, Sendable, CaseIterable, Hashable {
    case up, down, left, right

    var vector: CGPoint {
        switch self {
        case .up: return CGPoint(x: 0, y: 1)
        case .down: return CGPoint(x: 0, y: -1)
        case .left: return CGPoint(x: -1, y: 0)
        case .right: return CGPoint(x: 1, y: 0)
        }
    }

    var legacyDirection: ArenaPadDPadDirection {
        switch self {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        }
    }
}

nonisolated enum FELPadEvent: Sendable, Equatable {
    case buttonDown(FELPadButton)
    case buttonUp(FELPadButton)
    case dpadDown(FELPadDirection)
    case dpadUp(FELPadDirection)
}

/// Shared, observable controller state. Gameplay reads continuous values
/// (sticks, held sets) each frame and/or subscribes to discrete events.
/// One instance per gameplay session; the overlay writes, the mode reads.
@Observable
@MainActor
final class FELGamepadState {
    /// Normalized -1...1, y-up. Deadzone already applied.
    var leftStick: CGPoint = .zero
    var rightStick: CGPoint = .zero
    var heldDirections: Set<FELPadDirection> = []
    var heldButtons: Set<FELPadButton> = []

    /// Discrete edge events (button/dpad down & up), delivered in press order.
    var onEvent: ((FELPadEvent) -> Void)?

    /// D-pad and left stick merged into one movement vector, normalized to unit length.
    var moveVector: CGPoint {
        var x = leftStick.x
        var y = leftStick.y
        for direction in heldDirections {
            x += direction.vector.x
            y += direction.vector.y
        }
        let magnitude = hypot(x, y)
        guard magnitude > 1 else { return CGPoint(x: x, y: y) }
        return CGPoint(x: x / magnitude, y: y / magnitude)
    }

    func setStick(_ stick: ReferenceWritableKeyPath<FELGamepadState, CGPoint>, raw: CGPoint) {
        let filtered = InputManager.getAnalogStick(x: raw.x, y: raw.y)
        self[keyPath: stick] = CGPoint(x: filtered.x, y: filtered.y)
    }

    func press(_ button: FELPadButton) {
        guard !heldButtons.contains(button) else { return }
        heldButtons.insert(button)
        onEvent?(.buttonDown(button))
    }

    func release(_ button: FELPadButton) {
        guard heldButtons.contains(button) else { return }
        heldButtons.remove(button)
        onEvent?(.buttonUp(button))
    }

    func press(_ direction: FELPadDirection) {
        guard !heldDirections.contains(direction) else { return }
        heldDirections.insert(direction)
        onEvent?(.dpadDown(direction))
    }

    func release(_ direction: FELPadDirection) {
        guard heldDirections.contains(direction) else { return }
        heldDirections.remove(direction)
        onEvent?(.dpadUp(direction))
    }

    func reset() {
        leftStick = .zero
        rightStick = .zero
        heldDirections = []
        heldButtons = []
    }
}
