import Foundation

/// Pure, testable selection of which skinned clip a basketball player should be
/// playing, given possession + input. Kept free of SceneKit / UIKit so it can
/// be unit-tested and reused by the movement loop in GameSceneHostView.
///
/// Possession model for the basketball modes (basketballHeadToHead,
/// venicePickup, basketball3v3, basketballDunkContest3D): the human/tracked
/// player starts WITH the ball. While they have it, their clip is driven by
/// movement — dribble-loop when moving, dribble-idle when standing, with an
/// optional one-shot crossover. With NO ball, they fall back to the existing
/// locomotion (walk/run/idle) so shots/dunks that free the ball look right.
enum DribbleAnimationState: Equatable {
    /// Has ball, stick magnitude above the move threshold → sustained dribble.
    case dribbleMoving
    /// Has ball, standing (below move threshold) → dribble in place.
    case dribbleIdle
    /// Has ball, crossover input fired → one-shot crossover, then back to
    /// moving/idle.
    case crossover
    /// No ball → existing locomotion (CharacterElijahRunning etc.).
    case locomotion

    /// The retargeted dribble clip this state maps to, or nil when the state is
    /// the fall-through to the pre-existing walk/run/idle locomotion.
    var dribbleClip: FELBundledAsset? {
        switch self {
        case .dribbleMoving: return .dribbleLoop
        case .dribbleIdle:   return .dribbleIdle
        case .crossover:     return .dribbleCrossover
        case .locomotion:    return nil
        }
    }

    /// True while the player is dribbling (any has-ball state).
    var hasBall: Bool { self != .locomotion }
}

enum BasketballDribbleLogic {
    /// Stick magnitude at/above which the player counts as "moving".
    static let moveThreshold: Float = 0.08

    /// Pure state selection.
    /// - Parameters:
    ///   - hasBall: whether this player currently possesses the ball.
    ///   - stickMagnitude: left-stick magnitude (0…~1.4).
    ///   - crossoverActive: a crossover one-shot is currently playing (or just
    ///     triggered) — takes priority over moving/idle while it holds the ball.
    static func state(hasBall: Bool,
                      stickMagnitude: Float,
                      crossoverActive: Bool) -> DribbleAnimationState {
        guard hasBall else { return .locomotion }
        if crossoverActive { return .crossover }
        return stickMagnitude > moveThreshold ? .dribbleMoving : .dribbleIdle
    }

    // MARK: - Ball tracking / bounce

    /// Height (world units) the dribbled ball reaches at the TOP of its bounce
    /// (roughly waist height on the Elijah rig).
    static let bounceTopY: Float = 0.95
    /// Height at the BOTTOM of the bounce (just off the floor).
    static let bounceBottomY: Float = 0.12
    /// Bounce cycles per second while moving (fast) vs. standing (slow).
    static let bounceHzMoving: Float = 3.4
    static let bounceHzIdle: Float = 2.2

    /// Sinusoidal dribble height at time `t` for a given bounce rate. Returns a
    /// value in [bounceBottomY, bounceTopY]; phase chosen so the ball is near
    /// the floor at the sine trough (a real dribble sits low most of the cycle).
    static func bounceY(t: Float, hz: Float) -> Float {
        // |sin| gives a bounce that spends more time low and snaps up — closer
        // to a real dribble than a symmetric sine.
        let phase = abs(sin(t * hz * .pi))
        return bounceBottomY + (bounceTopY - bounceBottomY) * phase
    }
}
