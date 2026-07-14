import Foundation
import CoreGraphics

// MARK: - Collision Types

/// How two bodies physically overlapped
public enum CollisionType: Equatable {
    case glancing       // ~20° or less contact angle — minor redirect
    case shoulder       // side-angle — partial stagger
    case chest          // head-on — full stagger + knockback
    case slide          // low angle tackle / slide
    case screen         // set pick / stationary block
}

/// Outcome of resolving a collision for the primary body
public enum CollisionOutcome: Equatable {
    case none
    case stumble(duration: Double)          // slight loss of balance
    case stagger(duration: Double)          // clear disruption, stops movement
    case knockback(velocity: CGPoint, duration: Double)  // launched backward
    case fallDown(duration: Double)         // goes down, needs to get up
    case ballLoose(ballVelocity: CGPoint)  // ball knocked free
}

/// A single resolved collision event
public struct CollisionEvent: Identifiable {
    public let id = UUID()
    public let timestamp: Double
    public let type: CollisionType
    public let contactPoint: CGPoint
    public let primaryBodyId: String
    public let secondaryBodyId: String
    public let outcome: CollisionOutcome
    public let impulseMagnitude: CGFloat   // for visual FX scaling
    public let hasBallEffect: Bool
}

// MARK: - Physics Body

/// A rigid body tracked by the collision engine.
public struct CollisionBody {
    public var id: String
    public var position: CGPoint
    public var velocity: CGPoint = .zero
    public var radius: CGFloat
    public var mass: CGFloat = 1.0
    public var friction: CGFloat = 0.85    // velocity multiplied each frame (0=ice, 1=sticky)
    public var isKinematic: Bool = false   // if true, not pushed by collisions (walls, goals)
    public var prqStrength: Double = 0.5  // 0..1, scales with PRQ — stronger body = better outcomes

    public init(id: String, position: CGPoint, radius: CGFloat,
                mass: CGFloat = 1.0, prqStrength: Double = 0.5) {
        self.id = id
        self.position = position
        self.radius = radius
        self.mass = mass
        self.prqStrength = prqStrength
    }

    public mutating func integrate(dt: CGFloat) {
        guard !isKinematic else { return }
        position.x += velocity.x * dt
        position.y += velocity.y * dt
        velocity.x *= friction
        velocity.y *= friction
        // Stop micro-movement
        if abs(velocity.x) < 0.5 { velocity.x = 0 }
        if abs(velocity.y) < 0.5 { velocity.y = 0 }
    }

    public var speed: CGFloat {
        sqrt(velocity.x * velocity.x + velocity.y * velocity.y)
    }
}

// MARK: - Ball Body

public struct PhysicsBall {
    public var position: CGPoint
    public var velocity: CGPoint = .zero
    public var radius: CGFloat = 7
    public var isLoose: Bool = false       // knocked free — flies independently
    public var looseClock: Double = 0     // seconds since becoming loose

    public mutating func integrate(dt: CGFloat) {
        position.x += velocity.x * dt
        position.y += velocity.y * dt
        // Gravity simulation (screen Y-down, so positive Y = falling)
        if isLoose { velocity.y += 280 * dt }  // ~280 px/s² approximate screen gravity
        velocity.x *= 0.92
        if !isLoose { velocity.y *= 0.92 }
        if abs(velocity.x) < 0.5 { velocity.x = 0 }
        if !isLoose && abs(velocity.y) < 0.5 { velocity.y = 0 }
    }

    /// Reset to dribbling (re-possessed)
    public mutating func possess(at position: CGPoint) {
        self.position = position
        self.velocity = .zero
        self.isLoose  = false
        self.looseClock = 0
    }
}

// MARK: - Stagger State (per body)

public struct StaggerState {
    public var isActive: Bool = false
    public var duration: Double = 0
    public var elapsed: Double = 0
    public var type: StaggerAnimKind = .stumble

    public var progress: Double { isActive ? min(1.0, elapsed / max(0.001, duration)) : 1.0 }
    public var isRecovering: Bool { isActive && elapsed > duration * 0.6 }

    public mutating func trigger(kind: StaggerAnimKind, dur: Double) {
        isActive = true
        type = kind
        duration = dur
        elapsed = 0
    }

    public mutating func update(dt: Double) {
        guard isActive else { return }
        elapsed += dt
        if elapsed >= duration { isActive = false; elapsed = 0 }
    }

    public var animPose: String {
        guard isActive else { return "idle" }
        switch type {
        case .stumble:   return progress > 0.7 ? "idle" : "hit"
        case .stagger:   return progress > 0.5 ? "idle" : "staggered"
        case .knockback: return progress > 0.55 ? "idle" : "staggered"
        case .fallDown:  return progress > 0.65 ? "getUp" : "fallDown"
        }
    }
}

public enum StaggerAnimKind: Equatable {
    case stumble, stagger, knockback, fallDown
}

// MARK: - Body Collision Engine

/// Universal 2D physics engine for body-to-body contact across all game modes.
/// No rendering — pure simulation.
/// Call `addBody(_:)` to register bodies, `update(dt:)` each frame,
/// and observe `pendingEvents` for collision callbacks.
public final class BodyCollisionEngine {

    // ── Registered bodies ────────────────────────────────────────────────────
    public private(set) var bodies:    [String: CollisionBody]  = [:]
    public private(set) var staggerStates: [String: StaggerState] = [:]

    // ── Ball ─────────────────────────────────────────────────────────────────
    public var ball: PhysicsBall = PhysicsBall(position: .zero)
    public var ballHolderId: String? = nil   // which body currently holds the ball

    // ── Events ───────────────────────────────────────────────────────────────
    public private(set) var pendingEvents: [CollisionEvent] = []
    public var onCollision: ((CollisionEvent) -> Void)? = nil

    // ── Settings ─────────────────────────────────────────────────────────────
    public var worldBounds: CGRect = .zero   // if non-zero, bodies clamp inside
    public var currentTime: Double = 0

    public init() {}

    // MARK: - Body Management

    public func addBody(_ body: CollisionBody) {
        bodies[body.id] = body
        staggerStates[body.id] = StaggerState()
    }

    public func removeBody(id: String) {
        bodies.removeValue(forKey: id)
        staggerStates.removeValue(forKey: id)
        if ballHolderId == id { ballHolderId = nil }
    }

    public func moveBody(id: String, to position: CGPoint) {
        bodies[id]?.position = position
    }

    public func setVelocity(id: String, velocity: CGPoint) {
        bodies[id]?.velocity = velocity
    }

    // MARK: - Ball Control

    public func giveBall(to id: String, at position: CGPoint? = nil) {
        ballHolderId = id
        ball.isLoose  = false
        ball.velocity = .zero
        if let pos = position ?? bodies[id]?.position {
            ball.position = pos
        }
    }

    // MARK: - Update

    /// Advance physics by `dt` seconds. Call every frame.
    public func update(dt: Double) {
        currentTime += dt

        // Integrate velocities
        for id in bodies.keys {
            bodies[id]?.integrate(dt: CGFloat(dt))
            staggerStates[id]?.update(dt: dt)
            if let state = staggerStates[id], state.isActive {
                bodies[id]?.velocity.x *= 0.7
                bodies[id]?.velocity.y *= 0.7
            }
        }

        // Ball follows holder unless loose
        if !ball.isLoose, let holderId = ballHolderId, let holder = bodies[holderId] {
            ball.position = holder.position
        } else {
            ball.integrate(dt: CGFloat(dt))
            // Check if any non-holder body can pick up loose ball
            checkBallPickup()
        }

        if ball.isLoose { ball.looseClock += dt }

        // Clamp to world bounds
        if worldBounds != .zero {
            for id in bodies.keys {
                if let b = bodies[id] {
                    bodies[id]?.position = clampToBounds(b.position, radius: b.radius)
                }
            }
            if ball.isLoose {
                ball.position = clampToBounds(ball.position, radius: ball.radius)
            }
        }

        // Broad-phase collision detection
        detectCollisions()

        // Drain pending events
        pendingEvents.removeAll { $0.timestamp < currentTime - 2.0 }
    }

    // MARK: - Active Collision Trigger

    /// Manually trigger a bump/steal attempt. The collision engine resolves it.
    /// - Parameters:
    ///   - initiatorId: the defending body trying to steal
    ///   - targetId: the ball-handler being pressured
    ///   - prq: initiator's PRQ (0–100)
    ///   - defenseMode: "zone" / "man" / "press"
    /// - Returns: the resulting CollisionEvent
    @discardableResult
    public func triggerBump(
        initiatorId: String,
        targetId: String,
        prq: Double,
        defenseMode: String = "man"
    ) -> CollisionEvent? {
        guard let initiator = bodies[initiatorId],
              let target    = bodies[targetId] else { return nil }

        let dist = distance(initiator.position, target.position)
        let reachRange = initiator.radius + target.radius + 22  // generous reach radius

        // Must be in range
        guard dist < reachRange else { return nil }

        // Determine collision type based on approach angle + distance
        let colType: CollisionType
        if dist < initiator.radius + target.radius {
            colType = .chest
        } else if dist < reachRange * 0.6 {
            colType = .shoulder
        } else {
            colType = .glancing
        }

        // PRQ-scaled steal probability
        // Base: glancing=12%, shoulder=28%, chest=52%
        // PRQ bonus: up to +35% at PRQ=100
        let baseChance: Double
        switch colType {
        case .chest:    baseChance = 0.52
        case .shoulder: baseChance = 0.28
        case .glancing: baseChance = 0.12
        default:        baseChance = 0.10
        }
        let prqBonus  = (prq / 100.0) * 0.35
        let pressMult = defenseMode == "press" ? 1.25 : defenseMode == "zone" ? 0.80 : 1.0
        let stealChance = min(0.88, (baseChance + prqBonus) * pressMult)

        // Resolve direction vector
        let dx = target.position.x - initiator.position.x
        let dy = target.position.y - initiator.position.y
        let norm = max(0.001, sqrt(dx * dx + dy * dy))
        let pushX = CGFloat(dx / norm)
        let pushY = CGFloat(dy / norm)

        // Impulse magnitudes
        let impulse: CGFloat
        switch colType {
        case .chest:    impulse = 180
        case .shoulder: impulse = 110
        case .glancing: impulse = 55
        default:        impulse = 40
        }

        // Apply knockback to target
        let mass = target.mass
        bodies[targetId]?.velocity.x += pushX * impulse / mass
        bodies[targetId]?.velocity.y += pushY * impulse / mass

        // Determine outcome
        let roll = Double.random(in: 0...1)
        let outcome: CollisionOutcome
        let hasBallEffect: Bool

        if roll < stealChance {
            // Ball knocked loose!
            let ballVx = pushX * impulse * 1.4
            let ballVy = pushY * impulse * 1.4 - 60 // slight upward component
            ball.velocity = CGPoint(x: ballVx, y: ballVy)
            ball.isLoose  = true
            ball.looseClock = 0
            ballHolderId  = nil
            outcome = .ballLoose(ballVelocity: CGPoint(x: ballVx, y: ballVy))
            hasBallEffect = true

            // Trigger stagger on target
            switch colType {
            case .chest:    staggerStates[targetId]?.trigger(kind: .stagger, dur: 0.55)
            case .shoulder: staggerStates[targetId]?.trigger(kind: .stumble, dur: 0.30)
            default:        staggerStates[targetId]?.trigger(kind: .stumble, dur: 0.18)
            }
        } else if roll < stealChance * 1.6 {
            // Stumble but keeps ball
            switch colType {
            case .chest:    staggerStates[targetId]?.trigger(kind: .stagger, dur: 0.45)
            case .shoulder: staggerStates[targetId]?.trigger(kind: .stumble, dur: 0.28)
            default: break
            }
            outcome = colType == .chest
                ? .stagger(duration: 0.45)
                : .stumble(duration: 0.28)
            hasBallEffect = false
        } else {
            // Glancing bump, minor effect
            outcome = colType == .glancing ? .none : .stumble(duration: 0.18)
            hasBallEffect = false
        }

        // Contact point = midpoint
        let contactX = (initiator.position.x + target.position.x) / 2
        let contactY = (initiator.position.y + target.position.y) / 2

        let event = CollisionEvent(
            timestamp: currentTime,
            type: colType,
            contactPoint: CGPoint(x: contactX, y: contactY),
            primaryBodyId: initiatorId,
            secondaryBodyId: targetId,
            outcome: outcome,
            impulseMagnitude: impulse,
            hasBallEffect: hasBallEffect
        )
        pendingEvents.append(event)
        onCollision?(event)
        return event
    }

    // MARK: - Passive collision detection (bodies walking into each other)

    private func detectCollisions() {
        let ids = Array(bodies.keys)
        for i in 0..<ids.count {
            for j in (i + 1)..<ids.count {
                let idA = ids[i], idB = ids[j]
                guard let a = bodies[idA], let b = bodies[idB] else { continue }
                guard !a.isKinematic || !b.isKinematic else { continue }

                let dx = b.position.x - a.position.x
                let dy = b.position.y - a.position.y
                let dist = sqrt(dx * dx + dy * dy)
                let minDist = a.radius + b.radius

                guard dist < minDist && dist > 0.001 else { continue }

                // Overlap correction — push apart
                let overlap = minDist - dist
                let nx = dx / dist; let ny = dy / dist

                if !a.isKinematic {
                    bodies[idA]?.position.x -= nx * overlap * 0.5
                    bodies[idA]?.position.y -= ny * overlap * 0.5
                }
                if !b.isKinematic {
                    bodies[idB]?.position.x += nx * overlap * 0.5
                    bodies[idB]?.position.y += ny * overlap * 0.5
                }

                // Velocity exchange (elastic-ish)
                let relVx = (b.velocity.x) - (a.velocity.x)
                let relVy = (b.velocity.y) - (a.velocity.y)
                let relDotN = relVx * nx + relVy * ny

                if relDotN < 0 { continue }  // already separating

                let restitution: CGFloat = 0.35
                let j_imp = (1 + restitution) * CGFloat(relDotN) / (1 / a.mass + 1 / b.mass)

                if !a.isKinematic {
                    bodies[idA]?.velocity.x += j_imp / a.mass * nx
                    bodies[idA]?.velocity.y += j_imp / a.mass * ny
                }
                if !b.isKinematic {
                    bodies[idB]?.velocity.x -= j_imp / b.mass * nx
                    bodies[idB]?.velocity.y -= j_imp / b.mass * ny
                }

                // Passive contact event (no ball effect, low impulse — just a bump)
                let closingSpeed = abs(CGFloat(relDotN))
                if closingSpeed > 30 {
                    let colType: CollisionType = closingSpeed > 80 ? .chest : closingSpeed > 45 ? .shoulder : .glancing
                    if (staggerStates[idA]?.isActive == false) && (staggerStates[idB]?.isActive == false) {
                        let dur = colType == .chest ? 0.38 : colType == .shoulder ? 0.22 : 0.10
                        let kind: StaggerAnimKind = colType == .chest ? .stagger : .stumble
                        staggerStates[idA]?.trigger(kind: kind, dur: dur)
                        staggerStates[idB]?.trigger(kind: kind, dur: dur)

                        let event = CollisionEvent(
                            timestamp: currentTime,
                            type: colType,
                            contactPoint: CGPoint(x: (a.position.x + b.position.x) / 2,
                                                  y: (a.position.y + b.position.y) / 2),
                            primaryBodyId: idA,
                            secondaryBodyId: idB,
                            outcome: colType == .chest ? .stagger(duration: 0.38) : .stumble(duration: 0.22),
                            impulseMagnitude: closingSpeed,
                            hasBallEffect: false
                        )
                        pendingEvents.append(event)
                        onCollision?(event)
                    }
                }
            }
        }
    }

    // MARK: - Ball pickup check

    private func checkBallPickup() {
        guard ball.isLoose else { return }
        for (id, body) in bodies {
            guard id != ballHolderId else { continue }
            let dist = distance(body.position, ball.position)
            if dist < body.radius + ball.radius + 8 {
                // Close enough — can pick up after 0.3s loose time (prevent instant re-grab)
                if ball.looseClock > 0.3 {
                    ballHolderId = id
                    ball.isLoose = false
                    ball.velocity = .zero
                    ball.looseClock = 0
                    let pickupEvent = CollisionEvent(
                        timestamp: currentTime,
                        type: .glancing,
                        contactPoint: ball.position,
                        primaryBodyId: id,
                        secondaryBodyId: ballHolderId ?? "",
                        outcome: .none,
                        impulseMagnitude: 0,
                        hasBallEffect: true
                    )
                    pendingEvents.append(pickupEvent)
                    onCollision?(pickupEvent)
                    return
                }
            }
        }
    }

    // MARK: - Helpers

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = a.x - b.x; let dy = a.y - b.y
        return sqrt(dx * dx + dy * dy)
    }

    private func clampToBounds(_ point: CGPoint, radius: CGFloat) -> CGPoint {
        CGPoint(
            x: max(worldBounds.minX + radius, min(worldBounds.maxX - radius, point.x)),
            y: max(worldBounds.minY + radius, min(worldBounds.maxY - radius, point.y))
        )
    }
}

// MARK: - Collision Flash FX (Canvas drawing helper)

/// Draw a contact burst at a point — call from Canvas during a collision event.
public struct CollisionFlashFX {

    /// Draw an impact burst at the given canvas point.
    /// `progress` 0→1 is the age of the flash (1 = fully faded).
    public static func draw(
        ctx: inout GraphicsContext,
        at point: CGPoint,
        progress: Double,
        magnitude: CGFloat,
        type: CollisionType
    ) {
        let alpha = max(0, 1.0 - progress * 1.4)
        guard alpha > 0.01 else { return }

        let radius = magnitude * 0.12 * CGFloat(1 + progress * 0.5)
        let innerR  = radius * 0.55

        // Outer burst ring
        var ring = Path()
        ring.addEllipse(in: CGRect(x: point.x - radius, y: point.y - radius * 0.65,
                                   width: radius * 2, height: radius * 1.3))
        let ringColor: Color
        switch type {
        case .chest:    ringColor = Color(red: 1.0, green: 0.3, blue: 0.1)
        case .shoulder: ringColor = Color(red: 1.0, green: 0.65, blue: 0.1)
        case .glancing: ringColor = Color(red: 0.9, green: 0.9, blue: 0.4)
        case .slide:    ringColor = Color(red: 0.4, green: 0.8, blue: 1.0)
        case .screen:   ringColor = Color(red: 0.7, green: 0.7, blue: 1.0)
        }

        var gc = ctx
        gc.addFilter(.blur(radius: 4))
        gc.stroke(ring, with: .color(ringColor.opacity(alpha * 0.7)), lineWidth: 2.5)
        ctx.stroke(ring, with: .color(ringColor.opacity(alpha * 0.55)), lineWidth: 1.2)

        // Inner spark dots
        let numSparks = type == .chest ? 8 : 5
        for i in 0..<numSparks {
            let angle = Double(i) / Double(numSparks) * .pi * 2 + progress * 3.0
            let sparkR = innerR * CGFloat(0.5 + progress * 0.8)
            let sx = point.x + CGFloat(cos(angle)) * sparkR
            let sy = point.y + CGFloat(sin(angle)) * sparkR * 0.65
            let dotR: CGFloat = 2.5 * CGFloat(1 - progress)
            ctx.fill(
                Path(ellipseIn: CGRect(x: sx - dotR, y: sy - dotR, width: dotR * 2, height: dotR * 2)),
                with: .color(Color.white.opacity(alpha * 0.85))
            )
        }

        // Screen-shake indicator line for heavy chest collisions
        if type == .chest && progress < 0.3 {
            let lineLen = magnitude * 0.15 * CGFloat(1 - progress / 0.3)
            var hLine = Path()
            hLine.move(to: CGPoint(x: point.x - lineLen, y: point.y))
            hLine.addLine(to: CGPoint(x: point.x + lineLen, y: point.y))
            ctx.stroke(hLine, with: .color(ringColor.opacity(alpha * 0.5)), lineWidth: 1.5)
        }
    }

    /// Slow-motion vignette overlay when a big collision is happening
    public static func drawSlowMoVignette(
        ctx: inout GraphicsContext,
        canvasSize: CGSize,
        intensity: Double   // 0..1
    ) {
        guard intensity > 0.01 else { return }
        let W = canvasSize.width; let H = canvasSize.height
        // Dark edge vignette
        var gc = ctx
        gc.addFilter(.blur(radius: 24))
        gc.fill(
            Path(CGRect(origin: .zero, size: canvasSize)),
            with: .linearGradient(
                Gradient(stops: [
                    .init(color: .black.opacity(intensity * 0.55), location: 0),
                    .init(color: .clear, location: 0.4),
                    .init(color: .clear, location: 0.6),
                    .init(color: .black.opacity(intensity * 0.55), location: 1)
                ]),
                startPoint: .zero,
                endPoint: CGPoint(x: 0, y: H)
            )
        )
        // Chromatic aberration hint — left/right color splits at edges
        ctx.fill(
            Path(CGRect(x: 0, y: 0, width: W * 0.05, height: H)),
            with: .color(Color.red.opacity(intensity * 0.08))
        )
        ctx.fill(
            Path(CGRect(x: W * 0.95, y: 0, width: W * 0.05, height: H)),
            with: .color(Color.blue.opacity(intensity * 0.08))
        )
    }
}

// MARK: - PRQ Defensive Rating

/// Translate a player's PRQ score to concrete defensive attributes.
public struct PRQDefenseRating {
    public let prq: Double  // 0–100

    /// Steal chance bonus (additive, 0..0.35)
    public var stealBonus: Double   { min(0.35, prq / 100.0 * 0.35) }
    /// Bump impulse multiplier (1.0..1.5)
    public var bumpForce: Double    { 1.0 + (prq / 100.0) * 0.5 }
    /// Loose ball recovery speed (1.0..2.0)
    public var recoverySpeed: Double { 1.0 + (prq / 100.0) * 1.0 }
    /// Reach radius bonus in px (0..18)
    public var reachBonus: Double   { (prq / 100.0) * 18.0 }
    /// Foul tendency (inverse of PRQ — higher skill = cleaner play)
    public var foulRisk: Double     { max(0.02, 0.22 - (prq / 100.0) * 0.18) }

    /// Composite label shown in UI
    public var tierLabel: String {
        if prq >= 85 { return "LOCKDOWN" }
        if prq >= 65 { return "STOPPER" }
        if prq >= 45 { return "SOLID" }
        if prq >= 25 { return "AVERAGE" }
        return "RAW"
    }
}
