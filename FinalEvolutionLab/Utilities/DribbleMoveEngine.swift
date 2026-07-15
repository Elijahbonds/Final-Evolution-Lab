import Foundation
import CoreGraphics

// MARK: - Dribble Input Recognition

/// Raw gesture passed in from DragGesture or virtual joystick
public struct DribbleGestureInput {
    public let translation: CGPoint   // total drag delta
    public let velocity:    CGPoint   // px/s at gesture end
    public let duration:    Double    // seconds the drag lasted

    public init(translation: CGPoint, velocity: CGPoint, duration: Double) {
        self.translation = translation
        self.velocity = velocity
        self.duration = duration
    }
}

/// Recognized dribble moves
public enum DribbleMove: String, Equatable {
    case none
    case crossoverLeft       = "CROSSOVER →"
    case crossoverRight      = "← CROSSOVER"
    case spinMoveLeft        = "SPIN MOVE ↺"
    case spinMoveRight       = "SPIN MOVE ↻"
    case behindBackLeft      = "BEHIND THE BACK →"
    case behindBackRight     = "← BEHIND THE BACK"
    case betweenLegs         = "BETWEEN THE LEGS"
    case sizeUp              = "SIZE-UP"
    case euroStep            = "EURO STEP"
    case hesiPull            = "HESITATION"

    public var durationSeconds: Double {
        switch self {
        case .crossoverLeft, .crossoverRight:         return 0.34
        case .spinMoveLeft, .spinMoveRight:           return 0.52
        case .behindBackLeft, .behindBackRight:       return 0.40
        case .betweenLegs:                            return 0.44
        case .sizeUp:                                 return 0.36
        case .euroStep:                               return 0.48
        case .hesiPull:                               return 0.28
        case .none:                                   return 0
        }
    }

    /// Does this move transfer the ball to the opposite hand at the end?
    public var transfersHand: Bool {
        switch self {
        case .crossoverLeft, .crossoverRight,
             .behindBackLeft, .behindBackRight,
             .betweenLegs:
            return true
        default:
            return false
        }
    }
}

// MARK: - Dribble Hand Side

public enum DribbleHand: Equatable {
    case right, left
    public var flipped: DribbleHand { self == .right ? .left : .right }
}

// MARK: - Dribble Move Engine

/// Pure state machine – no SwiftUI. Call `update(dt:)` every frame.
/// Read `ballCanvasPosition(playerCX:floorY:)` each frame to draw the ball.
/// Read `activeMove` and `moveBannerAlpha` to show the move name overlay.
/// Read `dribbleHandSide` to know which side the ball is on.
public final class DribbleMoveEngine {

    // ── Public observable state ───────────────────────────────────────────────

    /// Which hand currently has/dribbles the ball
    public private(set) var dribbleHand: DribbleHand = .right

    /// Currently executing move (nil / .none when in normal dribble)
    public private(set) var activeMove: DribbleMove = .none

    /// 0→1 progress through the active move animation
    public private(set) var moveProgress: Double = 0

    /// 1→0 fade for the banner flash after a move completes
    public private(set) var moveBannerAlpha: Double = 0

    /// 0→1 normal dribble phase (drives bounce height)
    public private(set) var dribblePhase: Double = 0

    /// Whether the ball is currently in transit across the body (crossover arc)
    public var isInTransit: Bool { activeMove != .none && activeMove != .sizeUp && activeMove != .hesiPull }

    // ── Private timing ────────────────────────────────────────────────────────

    private var moveClock: Double = 0      // seconds since move started
    private var bannerClock: Double = 0   // seconds since move completed
    private let bannerDuration: Double = 1.0
    private var dribbleClock: Double = 0  // total dribble time (for phase)

    // Dribble speed in bounces per second (normal ~2.2 bps, fast ~3.5 bps)
    private var dribbleBPS: Double = 2.2

    // ── Queued inputs ────────────────────────────────────────────────────────

    private var pendingMove: DribbleMove = .none

    // MARK: - Public API

    /// Call once per display frame with the elapsed time step.
    /// `fastDribble` – true when player is sprinting/approaching the rim.
    public func update(dt: Double, fastDribble: Bool = false) {
        dribbleBPS = fastDribble ? 3.4 : 2.2
        dribbleClock += dt * dribbleBPS
        dribblePhase = dribbleClock.truncatingRemainder(dividingBy: 1.0)

        // Start pending move at the right moment in the dribble cycle (ball at floor)
        if activeMove == .none && pendingMove != .none {
            // Snap to start on ball-floor contact (phase near 0.5 or wherever ball is lowest)
            activeMove  = pendingMove
            moveClock   = 0
            pendingMove = .none
        }

        if activeMove != .none {
            moveClock += dt
            let dur = activeMove.durationSeconds
            moveProgress = min(1.0, moveClock / dur)

            if moveProgress >= 1.0 {
                if activeMove.transfersHand {
                    dribbleHand = dribbleHand.flipped
                }
                let completed = activeMove
                activeMove   = .none
                moveClock    = 0
                moveProgress = 0
                // Reset dribble clock so the new hand starts clean
                dribbleClock = 0
                _ = completed  // suppress unused warning; banner handled below
                moveBannerAlpha = 1.0
                bannerClock     = 0
            }
        }

        // Fade banner
        if moveBannerAlpha > 0 {
            bannerClock  += dt
            moveBannerAlpha = max(0, 1.0 - bannerClock / bannerDuration)
        }
    }

    /// Queue a move from a gesture. Safe to call mid-move (queues for next cycle).
    public func enqueueMove(_ move: DribbleMove) {
        guard move != .none else { return }
        if activeMove == .none {
            pendingMove = move
        }
        // If another move is already running, silently ignore (player must wait)
    }

    /// Recognize a dribble move from a raw gesture and queue it.
    public func recognizeGesture(_ input: DribbleGestureInput) {
        let tx = input.translation.x
        let ty = input.translation.y
        let vx = input.velocity.x
        let vy = input.velocity.y
        let dist = sqrt(tx * tx + ty * ty)

        // Minimum gesture size
        guard dist > 20 else { return }

        // ── Speed of flick
        let flickSpeed = sqrt(vx * vx + vy * vy)

        // ── Circular gesture detection (spin move)
        // Heuristic: if x & y both have significant magnitude relative to each other
        // and the travel was not mostly linear, classify as circle/spin
        let isCircular = dist > 40 && abs(tx) > 30 && abs(ty) > 30
        if isCircular && flickSpeed < 800 {
            let move: DribbleMove = tx > 0 ? .spinMoveRight : .spinMoveLeft
            enqueueMove(move)
            return
        }

        // ── Diagonal-down → behind the back
        // tx significant, ty is downward and |ty| > 0.4 * |tx|
        if abs(tx) > 35 && ty > 25 && ty > abs(tx) * 0.35 {
            let move: DribbleMove = tx > 0 ? .behindBackRight : .behindBackLeft
            enqueueMove(move)
            return
        }

        // ── Horizontal flick → crossover
        // Fast horizontal with small vertical component
        if abs(tx) > 30 && abs(ty) < abs(tx) * 0.6 && flickSpeed > 350 {
            let move: DribbleMove = tx > 0 ? .crossoverRight : .crossoverLeft
            enqueueMove(move)
            return
        }

        // ── Vertical down-up → between legs
        if ty > 45 && abs(tx) < ty * 0.5 {
            enqueueMove(.betweenLegs)
            return
        }

        // ── Upward flick → size-up / hesitation
        if ty < -40 && abs(tx) < abs(ty) * 0.5 {
            enqueueMove(flickSpeed > 600 ? .sizeUp : .hesiPull)
            return
        }
    }

    // MARK: - Canvas Drawing Data

    /// Returns the ball's canvas position relative to the player's feet anchor.
    /// Add playerCX / floorY in the calling site to get absolute canvas coords.
    ///
    /// - Returns: CGPoint where .x is horizontal offset from player center, .y is distance *above* floorY
    public func ballOffset(playerWidth: CGFloat, floorY: CGFloat) -> CGPoint {
        let handXOffset = playerWidth * (dribbleHand == .right ? 0.28 : -0.28)
        let normalBounce = normalDribbleBallY(floorY: floorY)

        switch activeMove {
        case .none, .sizeUp, .hesiPull:
            // Normal dribble — ball rises to hand height then drops
            return CGPoint(x: handXOffset, y: normalBounce)

        case .crossoverLeft, .crossoverRight:
            // Ball travels horizontally from one side to the other in a low arc
            let targetX = playerWidth * (dribbleHand == .right ? -0.28 : 0.28)
            let t = moveProgress
            // Ease in-out
            let smoothT = t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
            let arcBallX = handXOffset + (targetX - handXOffset) * CGFloat(smoothT)
            // Low parabolic arc that peaks mid-body
            let arcY = normalBounce + floorY * 0.06 * CGFloat(sin(t * .pi))
            return CGPoint(x: arcBallX, y: arcY)

        case .spinMoveLeft, .spinMoveRight:
            // Ball stays wide on one side, comes around with the body spin
            let spinAngle = moveProgress * .pi * 2
            let radius = playerWidth * 0.32
            let spinX = CGFloat(cos(spinAngle + (dribbleHand == .right ? 0 : .pi))) * radius
            let spinY = normalBounce * 0.7 + floorY * 0.04 * CGFloat(sin(moveProgress * .pi))
            return CGPoint(x: spinX, y: spinY)

        case .behindBackLeft, .behindBackRight:
            // Ball goes diagonally behind body (x & y toward back)
            let targetX = playerWidth * (dribbleHand == .right ? -0.24 : 0.24)
            let t = moveProgress
            let smoothT = sin(t * .pi / 2)
            let backX = handXOffset + (targetX - handXOffset) * CGFloat(smoothT)
            // Dips slightly lower behind back (behind = further from camera, shown as lower)
            let backY = normalBounce - floorY * 0.04 * CGFloat(sin(t * .pi))
            return CGPoint(x: backX, y: backY)

        case .betweenLegs:
            // Ball passes between legs: x stays near center, y briefly touches near-floor
            let t = moveProgress
            let legX = handXOffset * CGFloat(1.0 - 2 * t)  // crosses center at t=0.5
            let legY: CGFloat
            if t < 0.5 {
                legY = normalBounce * CGFloat(1 - t * 2 * 0.5) // sinks to floor
            } else {
                legY = normalBounce * CGFloat((t - 0.5) * 2)    // rises to other hand
            }
            return CGPoint(x: legX, y: legY)

        case .euroStep:
            // Ball follows player in a lateral step arc
            let stepX = handXOffset + playerWidth * 0.15 * CGFloat(sin(moveProgress * .pi))
            return CGPoint(x: stepX, y: normalBounce)
        }
    }

    /// Returns (left hand should reach down, right hand should reach down)
    /// to sync hand-to-ball contact at the top of each bounce
    public func handReachFraction() -> (left: Double, right: Double) {
        let phase = dribblePhase
        // Hand reaches down at phases 0.75–1.0 (ball coming up)
        let reachNormal = max(0, phase > 0.7 ? (phase - 0.7) / 0.3 : 0)

        if activeMove == .none || activeMove == .hesiPull || activeMove == .sizeUp {
            if dribbleHand == .right {
                return (left: 0, right: reachNormal)
            } else {
                return (left: reachNormal, right: 0)
            }
        }

        // During crossover / transfer: receiving hand starts reaching down at 0.6 progress
        let receivingReach = max(0, moveProgress > 0.6 ? (moveProgress - 0.6) / 0.4 : 0)
        let sendingHand: DribbleHand = dribbleHand
        let receivingHand: DribbleHand = dribbleHand.flipped

        let leftReach  = receivingHand == .left  ? receivingReach : reachNormal * (activeMove == .none ? 0 : 0.2)
        let rightReach = receivingHand == .right ? receivingReach : reachNormal * (activeMove == .none ? 0 : 0.2)
        _ = sendingHand  // suppress unused
        return (left: leftReach, right: rightReach)
    }

    // MARK: - Private helpers

    private func normalDribbleBallY(floorY: CGFloat) -> CGFloat {
        // phase 0 = hand level, phase 0.5 = floor, uses abs(sin(phase*pi)) mapped to 0..1
        // Returns y offset above floor (0 = floor, maxBounceHeight = hand height)
        let bounceH = floorY * 0.18  // ~18% of canvas height
        let raw = CGFloat(abs(sin(dribblePhase * .pi)))
        return raw * bounceH
    }
}

// MARK: - Virtual Joystick Gesture Helper

/// Utility to turn a DragGesture's values into DribbleGestureInput.
/// Usage in SwiftUI:
///   .gesture(DragGesture(minimumDistance: 8)
///     .onEnded { v in dribbleEngine.recognizeGesture(v.asDribbleInput()) })
extension DragGesture.Value {
    public func asDribbleInput() -> DribbleGestureInput {
        DribbleGestureInput(
            translation: CGPoint(x: translation.width, y: translation.height),
            velocity: CGPoint(x: velocity.width, y: velocity.height),
            duration: time.timeIntervalSince(startLocation == .zero ? Date() : Date())
        )
    }
}
