//
//  Basketball3v3AIController.swift
//  FinalEvolutionLab
//
//  Deterministic, self-contained 3v3 streetball AI controller for the SceneKit
//  scene produced by GameSceneFactory.build3v3Scene().
//
//  It drives six pre-existing named nodes (blue1..blue3, red1..red3) plus the
//  "ball" node by *moving* them each frame. It never rebuilds, clones, or
//  replaces skinned character nodes — only cheap primitive ground rings are
//  added as children. All randomness is seeded (SplitMix64 + accumulated
//  simTime); no Date()/Float.random is used, so a given seed replays identically.
//
//  NOTE: not yet wired into any view. It only needs to compile cleanly and be
//  correct/self-contained. The team lead will decide GameSceneHostView hooks.
//

import Combine
import SceneKit
import simd
#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class Basketball3v3AIController {

    // MARK: - Public Types

    enum Team {
        case blue
        case red
    }

    struct Config {
        var seed: UInt64
        var offenseSide: Team
        var baseSpeed: Float = 1.6
        var neuralDrive: Double = 50
        /// Court half-extents (x, z). Nodes are clamped to these bounds.
        var bounds: SIMD2<Float> = SIMD2<Float>(4.6, 2.7)
        var hoopX: Float = 4.5
        var humanControlledBlue1: Bool = true

        init(
            seed: UInt64,
            offenseSide: Team,
            baseSpeed: Float = 1.6,
            neuralDrive: Double = 50,
            bounds: SIMD2<Float> = SIMD2<Float>(4.6, 2.7),
            hoopX: Float = 4.5,
            humanControlledBlue1: Bool = true
        ) {
            self.seed = seed
            self.offenseSide = offenseSide
            self.baseSpeed = baseSpeed
            self.neuralDrive = neuralDrive
            self.bounds = bounds
            self.hoopX = hoopX
            self.humanControlledBlue1 = humanControlledBlue1
        }
    }

    // MARK: - Public State

    private(set) var blueScore: Int = 0
    private(set) var redScore: Int = 0

    /// Fired when a team scores. Parameters: scoring team, that team's new total.
    var onScore: ((Team, Int) -> Void)?

    // MARK: - Private State

    private var config: Config
    private var rng: SplitMix64

    /// Accumulated simulation time (seconds). Drives deterministic sinusoids.
    private var simTime: Float = 0

    private var didBootstrap = false

    /// Current offense/defense team & hoop we attack this possession.
    private var offenseTeam: Team
    private var currentHoopX: Float

    /// Node names for each team in fixed order.
    private let blueNames = ["blue1", "blue2", "blue3"]
    private let redNames = ["red1", "red2", "red3"]

    /// Index (0..2) of the current ball-handler within the offense team.
    private var ballHandlerIndex = 0

    /// Pass state. When a pass is in flight the ball lerps passer -> receiver.
    private var passActive = false
    private var passProgress: Float = 0          // 0..1
    private var passFromName = ""
    private var passToName = ""
    private var pendingHandlerIndex = 0
    private var nextPassTime: Float = 2.5         // simTime at which we try a pass

    /// Cached last position of the ball-handler for velocity estimation.
    private var lastHandlerPos = SIMD3<Float>(0, 0, 0)
    private var handlerVel = SIMD3<Float>(0, 0, 0)

    // Team colors (match the factory palette).
    #if canImport(UIKit)
    private let blueColor = UIColor(red: 0, green: 0.83, blue: 1, alpha: 1)
    private let redColor = UIColor(red: 1, green: 0.25, blue: 0.2, alpha: 1)
    #endif

    // MARK: - Init

    init(config: Config) {
        self.config = config
        self.rng = SplitMix64(seed: config.seed)
        self.offenseTeam = config.offenseSide
        self.currentHoopX = config.hoopX
    }

    // MARK: - Convenience Accessors

    private var offenseNames: [String] { offenseTeam == .blue ? blueNames : redNames }
    private var defenseNames: [String] { offenseTeam == .blue ? redNames : blueNames }

    private func team(for name: String) -> Team { name.hasPrefix("blue") ? .blue : .red }

    private func node(_ name: String, in scene: SCNScene) -> SCNNode? {
        scene.rootNode.childNode(withName: name, recursively: true)
    }

    // MARK: - Tick

    func tick(dt: Float, in scene: SCNScene) {
        guard dt > 0 else { return }
        simTime += dt

        if !didBootstrap {
            bootstrap(in: scene)
            didBootstrap = true
        }

        // Resolve nodes (fail-soft: skip whatever is missing).
        var nodes: [String: SCNNode] = [:]
        for name in blueNames + redNames {
            if let n = node(name, in: scene) { nodes[name] = n }
        }
        guard let ball = node("ball", in: scene) else {
            // Without a ball we can still shuffle players, but scoring needs it.
            moveDefault(nodes: nodes, dt: dt)
            return
        }

        let handlerName = offenseNames[ballHandlerIndex]

        // Estimate ball-handler velocity for body-up checks.
        if let hNode = nodes[handlerName] {
            let p = simd3(hNode.position)
            let dv = (p - lastHandlerPos)
            handlerVel = dt > 0 ? dv / dt : SIMD3<Float>(0, 0, 0)
            lastHandlerPos = p
        }

        let defenseSpeedScale = Float(DefensivePhysics.lateralQuicknessScale(perimeterDefense: config.neuralDrive))

        // --- Compute targets ---
        var targets: [String: SIMD3<Float>] = [:]

        // OFFENSE
        for (i, name) in offenseNames.enumerated() {
            guard let n = nodes[name] else { continue }
            let cur = simd3(n.position)
            if i == ballHandlerIndex {
                targets[name] = offenseHandlerTarget(current: cur)
            } else if i == cutterIndex {
                targets[name] = offenseCutterTarget(current: cur, playerIndex: i)
            } else {
                targets[name] = offenseSpacingTarget(current: cur, playerIndex: i)
            }
        }

        // DEFENSE
        computeDefenseTargets(nodes: nodes, into: &targets)

        // --- Apply movement ---
        for (name, target) in targets {
            guard let n = nodes[name] else { continue }
            // Never write blue1 when human-controlled.
            if config.humanControlledBlue1 && name == "blue1" { continue }

            let isDefense = defenseNames.contains(name)
            let speed = config.baseSpeed * (isDefense ? defenseSpeedScale : 1.0)
            moveNode(n, toward: target, speed: speed, dt: dt)
        }

        // --- Ball follow / pass ---
        updateBall(ball, nodes: nodes, dt: dt)

        // --- Scoring ---
        checkScore(nodes: nodes, in: scene)

        // --- Trigger passes deterministically ---
        maybeStartPass(nodes: nodes)
    }

    /// Fallback shuffle when the ball is missing — still deterministic-ish drift.
    private func moveDefault(nodes: [String: SCNNode], dt: Float) {
        for (name, n) in nodes {
            if config.humanControlledBlue1 && name == "blue1" { continue }
            let cur = simd3(n.position)
            let jitter = SIMD3<Float>(
                sin(simTime * 0.7 + Float(name.hashValue % 7)) * 0.4,
                0,
                cos(simTime * 0.5 + Float(name.hashValue % 5)) * 0.3
            )
            moveNode(n, toward: cur + jitter, speed: config.baseSpeed * 0.4, dt: dt)
        }
    }

    // MARK: - Bootstrap (first tick)

    private func bootstrap(in scene: SCNScene) {
        // 1. Strip the factory's fighting actions so we own movement.
        for name in blueNames + redNames {
            guard let n = node(name, in: scene) else { continue }
            n.removeAction(forKey: "shuffle")
            n.removeAction(forKey: "homingDefense")
        }
        // The ball's bob action is unkeyed; clear it so our lerp owns Y too.
        node("ball", in: scene)?.removeAllActions()

        // 2. Add team-colored ground rings (idempotent).
        for name in blueNames + redNames {
            addGroundRing(to: name, in: scene)
        }

        // 3. Seed ball-handler position cache.
        if let h = node(offenseNames[ballHandlerIndex], in: scene) {
            lastHandlerPos = simd3(h.position)
        }
        nextPassTime = 2.5 + Float(rng.nextDouble(in: 0...1.5))
    }

    private func addGroundRing(to playerName: String, in scene: SCNScene) {
        guard let player = node(playerName, in: scene) else { return }
        let ringName = "ring_\(playerName)"
        // Idempotent: skip if already present as a direct child.
        if player.childNodes.contains(where: { $0.name == ringName }) { return }

        let torus = SCNTorus(ringRadius: 0.32, pipeRadius: 0.03)
        let mat = SCNMaterial()
        #if canImport(UIKit)
        let color = team(for: playerName) == .blue ? blueColor : redColor
        mat.diffuse.contents = color
        mat.emission.contents = color
        #endif
        torus.materials = [mat]

        let ringNode = SCNNode(geometry: torus)
        ringNode.name = ringName
        ringNode.eulerAngles.x = .pi / 2      // lay flat on the floor
        ringNode.position = SCNVector3(0, 0.03, 0)
        player.addChildNode(ringNode)
    }

    // MARK: - Offense Targets

    /// The teammate who cuts to the rim (the offense player that is neither the
    /// ball-handler nor the highest-index spacer). Deterministic per possession.
    private var cutterIndex: Int {
        // Pick the first non-handler index as the cutter.
        for i in 0..<offenseNames.count where i != ballHandlerIndex { return i }
        return (ballHandlerIndex + 1) % offenseNames.count
    }

    private func offenseHandlerTarget(current: SIMD3<Float>) -> SIMD3<Float> {
        let rimZ: Float = 0
        let rimSlotX = currentHoopX - (currentHoopX >= 0 ? 0.55 : -0.55)
        let laneOpen = isLaneOpen(from: current)

        if laneOpen {
            // Drive toward the rim slot.
            return clampToBounds(SIMD3<Float>(rimSlotX, current.y, rimZ))
        } else {
            // Hold with a small deterministic dribble jitter.
            let jx = sin(simTime * 2.3) * 0.18
            let jz = cos(simTime * 1.9) * 0.18
            return clampToBounds(SIMD3<Float>(current.x + jx, current.y, current.z + jz))
        }
    }

    /// Lane is "open" when no defender sits between the handler and the rim.
    private func isLaneOpen(from pos: SIMD3<Float>) -> Bool {
        // Simplified: treat lane as open if we oscillate open on a slow cycle.
        // Deterministic gate based on simTime so drives happen periodically.
        let phase = sin(simTime * 0.8 + Float(ballHandlerIndex))
        return phase > -0.2
    }

    private func offenseCutterTarget(current: SIMD3<Float>, playerIndex: Int) -> SIMD3<Float> {
        // Seeded sinusoidal cut to the rim and back.
        let rimX = currentHoopX
        let anchorX: Float = currentHoopX >= 0 ? -1.0 : 1.0
        // 0..1 sinusoid: 0 at anchor, 1 at rim.
        let s = (sin(simTime * 1.1 + Float(playerIndex) * 1.3) + 1) / 2
        let x = anchorX + (rimX - anchorX) * s * 0.85
        let z = sin(simTime * 0.9 + Float(playerIndex)) * 1.4
        return clampToBounds(SIMD3<Float>(x, current.y, z))
    }

    private func offenseSpacingTarget(current: SIMD3<Float>, playerIndex: Int) -> SIMD3<Float> {
        // Hold a wing spacing anchor with slow drift.
        let side: Float = (playerIndex % 2 == 0) ? 1 : -1
        let anchorX: Float = (currentHoopX >= 0 ? -1.5 : 1.5)
        let anchorZ: Float = side * 2.0
        let drift = sin(simTime * 0.5 + Float(playerIndex)) * 0.35
        return clampToBounds(SIMD3<Float>(anchorX + drift, current.y, anchorZ - drift * 0.5))
    }

    // MARK: - Defense Targets

    private func computeDefenseTargets(nodes: [String: SCNNode], into targets: inout [String: SIMD3<Float>]) {
        let handlerName = offenseNames[ballHandlerIndex]
        guard let handlerNode = nodes[handlerName] else { return }
        let handlerPos = simd3(handlerNode.position)

        // On-ball defender = defense[0]; help defenders = defense[1..].
        let onBallName = defenseNames[0]

        // Contain point: between man and hoop.
        let toHoop = normalizedXZ(SIMD3<Float>(currentHoopX, 0, 0) - handlerPos)
        let containPoint = handlerPos + toHoop * 0.9

        if let onBall = nodes[onBallName] {
            let dPos = simd3(onBall.position)
            let bodiedUp = DefensivePhysics.checkBodyUp(
                ballHandlerPos: SIMD3<Double>(Double(handlerPos.x), Double(handlerPos.y), Double(handlerPos.z)),
                ballHandlerVel: SIMD3<Double>(Double(handlerVel.x), Double(handlerVel.y), Double(handlerVel.z)),
                defenderPos: SIMD3<Double>(Double(dPos.x), Double(dPos.y), Double(dPos.z))
            )

            if bodiedUp {
                // Contained: hold contain point.
                targets[onBallName] = clampToBounds(containPoint)
            } else {
                // Beaten: ask HelpDefense3v3 to rotate a helper, on-ball recovers.
                let closeout = requestCloseout(nodes: nodes)
                targets[onBallName] = clampToBounds(handlerPos)  // recover to ball

                if let result = closeout, let helperNode = nodes[result.helperId] {
                    // Helper rotates to cover the ball (X-out).
                    let helperTarget = handlerPos + toHoop * 0.6
                    targets[result.helperId] = clampToBounds(helperTarget)
                    _ = helperNode
                }
            }
        }

        // Remaining help defenders sag toward the ball.
        for name in defenseNames where name != onBallName {
            if targets[name] != nil { continue }  // already assigned by closeout
            guard let n = nodes[name] else { continue }
            let cur = simd3(n.position)
            let sagPoint = cur + normalizedXZ(handlerPos - cur) * 0.8
            targets[name] = clampToBounds(sagPoint)
        }
    }

    /// Build Player3v3Position snapshots and call HelpDefense3v3.xCloseout.
    private func requestCloseout(nodes: [String: SCNNode]) -> HelpDefense3v3.CloseoutResult? {
        let handlerName = offenseNames[ballHandlerIndex]
        let onBallName = defenseNames[0]

        var players: [Player3v3Position] = []
        for name in offenseNames {
            guard let n = nodes[name] else { continue }
            let p = simd3(n.position)
            players.append(Player3v3Position(
                id: name,
                position: SIMD3<Double>(Double(p.x), Double(p.y), Double(p.z)),
                isOffense: true,
                assignedDefenderId: nil
            ))
        }
        for name in defenseNames {
            guard let n = nodes[name] else { continue }
            let p = simd3(n.position)
            // The lead defender is assigned to the ball-handler.
            let assigned = (name == onBallName) ? handlerName : nil
            players.append(Player3v3Position(
                id: name,
                position: SIMD3<Double>(Double(p.x), Double(p.y), Double(p.z)),
                isOffense: false,
                assignedDefenderId: assigned
            ))
        }

        return HelpDefense3v3.xCloseout(
            players: players,
            ballHandlerId: handlerName,
            defenderIds: defenseNames
        )
    }

    // MARK: - Ball

    private func updateBall(_ ball: SCNNode, nodes: [String: SCNNode], dt: Float) {
        let target: SIMD3<Float>
        if passActive {
            passProgress += dt * 2.2   // ~0.45s pass
            let from = nodes[passFromName].map { simd3($0.position) } ?? simd3(ball.position)
            let to = nodes[passToName].map { simd3($0.position) } ?? simd3(ball.position)
            let t = min(1, passProgress)
            let mid = from + (to - from) * t
            // Add a small arc.
            let arc = sin(t * .pi) * 0.4
            target = SIMD3<Float>(mid.x, 1.4 + arc, mid.z)
            if passProgress >= 1 {
                passActive = false
                ballHandlerIndex = pendingHandlerIndex
                if let h = nodes[offenseNames[ballHandlerIndex]] {
                    lastHandlerPos = simd3(h.position)
                }
            }
        } else {
            let handlerName = offenseNames[ballHandlerIndex]
            let hp = nodes[handlerName].map { simd3($0.position) } ?? simd3(ball.position)
            target = SIMD3<Float>(hp.x, 1.4, hp.z)
        }

        let cur = simd3(ball.position)
        let lerped = cur + (target - cur) * min(1, dt * 10)
        ball.position = SCNVector3(lerped.x, lerped.y, lerped.z)
    }

    private func maybeStartPass(nodes: [String: SCNNode]) {
        guard !passActive, simTime >= nextPassTime else { return }

        let handlerName = offenseNames[ballHandlerIndex]
        guard let handlerNode = nodes[handlerName] else { return }
        let hp = simd3(handlerNode.position)

        // Pass to the nearest open teammate.
        var bestIdx = -1
        var bestDistSq = Float.greatestFiniteMagnitude
        for (i, name) in offenseNames.enumerated() where i != ballHandlerIndex {
            guard let n = nodes[name] else { continue }
            let p = simd3(n.position)
            let d = simd_distance_squared(SIMD2<Float>(hp.x, hp.z), SIMD2<Float>(p.x, p.z))
            if d < bestDistSq {
                bestDistSq = d
                bestIdx = i
            }
        }
        guard bestIdx >= 0 else { return }

        passActive = true
        passProgress = 0
        passFromName = handlerName
        passToName = offenseNames[bestIdx]
        pendingHandlerIndex = bestIdx

        // Schedule the next pass with a seeded interval.
        nextPassTime = simTime + Float(rng.nextDouble(in: 2.0...4.0))
    }

    // MARK: - Scoring

    private func checkScore(nodes: [String: SCNNode], in scene: SCNScene) {
        guard !passActive else { return }
        let handlerName = offenseNames[ballHandlerIndex]
        guard let handlerNode = nodes[handlerName] else { return }
        let hp = simd3(handlerNode.position)

        let rimSlotX = currentHoopX - (currentHoopX >= 0 ? 0.55 : -0.55)
        let rim = SIMD2<Float>(rimSlotX, 0)
        let dist = simd_distance(SIMD2<Float>(hp.x, hp.z), rim)

        guard dist < 0.6 else { return }

        // Seeded make/miss. Blend neuralDrive into make probability.
        let makeProb = 0.5 + config.neuralDrive / 100.0 * 0.35
        let roll = rng.nextDouble(in: 0...1)
        if roll <= makeProb {
            if offenseTeam == .blue {
                blueScore += 2
                onScore?(.blue, blueScore)
            } else {
                redScore += 2
                onScore?(.red, redScore)
            }
        }
        // Whether make or miss, possession changes.
        reset(in: scene)
    }

    // MARK: - Reset / New Possession

    func reset(in scene: SCNScene) {
        // Flip offense side + attacking hoop.
        offenseTeam = (offenseTeam == .blue) ? .red : .blue
        currentHoopX = -currentHoopX

        // Deterministic new ball-handler for the new offense.
        ballHandlerIndex = Int(rng.next() % UInt64(offenseNames.count))

        passActive = false
        passProgress = 0
        nextPassTime = simTime + Float(rng.nextDouble(in: 2.0...3.5))

        // Snap to an inbound formation. Offense spreads near their own end
        // (opposite the hoop they attack); defense sits between ball & hoop.
        let ownEndX: Float = currentHoopX >= 0 ? -3.0 : 3.0

        let offenseSpots: [SIMD3<Float>] = [
            SIMD3<Float>(ownEndX, 0, 0),
            SIMD3<Float>(ownEndX + copysign(0.8, currentHoopX), 0, 1.8),
            SIMD3<Float>(ownEndX + copysign(0.8, currentHoopX), 0, -1.8)
        ]
        let defenseSpots: [SIMD3<Float>] = [
            SIMD3<Float>(ownEndX + copysign(1.2, currentHoopX), 0, 0),
            SIMD3<Float>(ownEndX + copysign(1.6, currentHoopX), 0, 1.4),
            SIMD3<Float>(ownEndX + copysign(1.6, currentHoopX), 0, -1.4)
        ]

        for (i, name) in offenseNames.enumerated() {
            if config.humanControlledBlue1 && name == "blue1" { continue }
            snap(name, to: offenseSpots[i], in: scene)
        }
        for (i, name) in defenseNames.enumerated() {
            if config.humanControlledBlue1 && name == "blue1" { continue }
            snap(name, to: defenseSpots[i], in: scene)
        }

        // Move ball to the new ball-handler.
        if let ball = node("ball", in: scene) {
            let handlerName = offenseNames[ballHandlerIndex]
            if let h = node(handlerName, in: scene) {
                let p = simd3(h.position)
                ball.position = SCNVector3(p.x, 1.4, p.z)
                lastHandlerPos = p
            }
        }
    }

    private func snap(_ name: String, to pos: SIMD3<Float>, in scene: SCNScene) {
        guard let n = node(name, in: scene) else { return }
        let clamped = clampToBounds(pos)
        n.position = SCNVector3(clamped.x, n.position.y, clamped.z)
    }

    // MARK: - Movement Helpers

    private func moveNode(_ n: SCNNode, toward target: SIMD3<Float>, speed: Float, dt: Float) {
        let cur = simd3(n.position)
        let flatTarget = SIMD3<Float>(target.x, cur.y, target.z)
        let step = speed * dt
        let next = moveTowardsLocal(current: cur, target: flatTarget, maxDistanceDelta: step)
        let clamped = clampToBounds(next)
        n.position = SCNVector3(clamped.x, cur.y, clamped.z)   // preserve Y

        let dx = clamped.x - cur.x
        let dz = clamped.z - cur.z
        if abs(dx) > 0.001 || abs(dz) > 0.001 {
            n.eulerAngles.y = atan2(dx, dz)
        }
    }

    private func moveTowardsLocal(current: SIMD3<Float>, target: SIMD3<Float>, maxDistanceDelta: Float) -> SIMD3<Float> {
        let delta = target - current
        let dist = simd_length(delta)
        if dist <= maxDistanceDelta || dist < 1e-6 {
            return target
        }
        return current + (delta / dist) * maxDistanceDelta
    }

    private func clampToBounds(_ p: SIMD3<Float>) -> SIMD3<Float> {
        SIMD3<Float>(
            min(config.bounds.x, max(-config.bounds.x, p.x)),
            p.y,
            min(config.bounds.y, max(-config.bounds.y, p.z))
        )
    }

    private func normalizedXZ(_ v: SIMD3<Float>) -> SIMD3<Float> {
        let flat = SIMD3<Float>(v.x, 0, v.z)
        let len = simd_length(flat)
        return len < 1e-6 ? SIMD3<Float>(0, 0, 0) : flat / len
    }

    private func simd3(_ v: SCNVector3) -> SIMD3<Float> {
        SIMD3<Float>(Float(v.x), Float(v.y), Float(v.z))
    }
}

// MARK: - Observable Score Box

@MainActor
final class AI3v3ScoreBox: ObservableObject {
    @Published var blue = 0
    @Published var red = 0

    func apply(_ team: Basketball3v3AIController.Team) {
        if team == .blue {
            blue += 2
        } else {
            red += 2
        }
    }
}
