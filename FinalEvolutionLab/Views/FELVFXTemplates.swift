import SceneKit
import UIKit

/// Sprint 1 (nexus/audio-vfx) — reusable SceneKit VFX templates.
///
/// Budgets follow `infra/asset_spec.md` (mobile-mid: ≤2,048 live particles per
/// scene, ≤8 particle draws): every template documents its worst-case particle
/// contribution, and the sum used by the dunk-contest demo (trail 120 + burst
/// 180 + crowd bed ~15) stays far under the cap.
///
/// All effects are procedural (no bundled textures) and attach to nodes that
/// ``GameSceneFactory`` already names ("ball", "dunker", "mainCamera",
/// "judge0"…"judge2").
@MainActor
enum FELVFXTemplates {

    // MARK: - Dunk trail

    /// Comet trail while the ball (or dunker) is in flight.
    /// Worst case ~120 live particles (birthRate 240 × 0.5 s lifespan).
    @discardableResult
    static func attachDunkTrail(to node: SCNNode,
                                color: UIColor = UIColor(red: 1.0, green: 0.55, blue: 0.1, alpha: 1)) -> SCNParticleSystem {
        let trail = SCNParticleSystem()
        trail.birthRate = 240
        trail.particleLifeSpan = 0.5
        trail.particleLifeSpanVariation = 0.1
        trail.particleSize = 0.05
        trail.particleSizeVariation = 0.02
        trail.particleColor = color
        trail.particleColorVariation = SCNVector4(0.05, 0.1, 0.0, 0.0)
        trail.particleVelocity = 0.05
        trail.spreadingAngle = 4
        trail.emitterShape = SCNSphere(radius: 0.08)
        trail.blendMode = .additive
        trail.isAffectedByGravity = false
        trail.particleBounce = 0
        node.addParticleSystem(trail)
        return trail
    }

    static func removeDunkTrail(from node: SCNNode) {
        node.removeAllParticleSystems()
    }

    // MARK: - Impact burst

    /// One-shot radial burst (rim impact, landing). ~180 particles, self-removing.
    static func playParticleBurst(in scene: SCNScene,
                                  at position: SCNVector3,
                                  color: UIColor = UIColor(red: 1.0, green: 0.8, blue: 0.2, alpha: 1)) {
        let host = SCNNode()
        host.position = position

        let burst = SCNParticleSystem()
        burst.birthRate = 1800
        burst.emissionDuration = 0.1
        burst.particleLifeSpan = 0.6
        burst.particleLifeSpanVariation = 0.2
        burst.particleSize = 0.04
        burst.particleSizeVariation = 0.03
        burst.particleColor = color
        burst.particleVelocity = 2.2
        burst.particleVelocityVariation = 1.0
        burst.spreadingAngle = 180
        burst.blendMode = .additive
        burst.isAffectedByGravity = true
        burst.acceleration = SCNVector3(0, -4.5, 0)
        host.addParticleSystem(burst)
        scene.rootNode.addChildNode(host)

        host.runAction(.sequence([.wait(duration: 1.2), .removeFromParentNode()]))
    }

    // MARK: - Camera shake

    /// Decaying positional shake on the scene's "mainCamera" node.
    /// `intensity` 0…1 maps to a ±(0.05…0.22) m offset.
    static func shakeCamera(in scene: SCNScene, intensity: Float = 0.6, duration: TimeInterval = 0.45) {
        guard let camera = scene.rootNode.childNode(withName: "mainCamera", recursively: true) else { return }
        let amplitude = 0.05 + 0.17 * max(0, min(1, intensity))
        let steps = 6
        var actions: [SCNAction] = []
        for step in 0..<steps {
            let falloff = Float(steps - step) / Float(steps)
            let dx = CGFloat(Float.random(in: -amplitude...amplitude) * falloff)
            let dy = CGFloat(Float.random(in: -amplitude...amplitude) * falloff * 0.6)
            let stepDuration = duration / Double(steps * 2)
            actions.append(.moveBy(x: dx, y: dy, z: 0, duration: stepDuration))
            actions.append(.moveBy(x: -dx, y: -dy, z: 0, duration: stepDuration))
        }
        camera.runAction(.sequence(actions), forKey: "felCameraShake")
    }

    // MARK: - Judge reveal

    /// Score cards flip up above the judge tables ("judge0"…"judge2") with a
    /// stagger, hold, then sink away. Pure geometry + emissive text; no assets.
    /// Returns the total animation duration so callers can sequence audio
    /// (``FELAudioDirector/playJudgeReveal(score:)``) and UI.
    @discardableResult
    static func playJudgeReveal(in scene: SCNScene, scores: [Int]) -> TimeInterval {
        let stagger: TimeInterval = 0.35
        let hold: TimeInterval = 1.6
        var revealed = 0

        for (index, score) in scores.prefix(3).enumerated() {
            guard let judge = scene.rootNode.childNode(withName: "judge\(index)", recursively: true) else { continue }
            revealed += 1

            let card = SCNBox(width: 0.5, height: 0.65, length: 0.04, chamferRadius: 0.03)
            let front = SCNMaterial()
            front.diffuse.contents = UIColor(white: 0.96, alpha: 1)
            front.emission.contents = UIColor(white: 0.25, alpha: 1)
            card.materials = [front]

            let cardNode = SCNNode(geometry: card)
            cardNode.position = SCNVector3(judge.position.x, judge.position.y + 0.4, judge.position.z)
            cardNode.eulerAngles.x = -.pi / 2 // face-down start
            cardNode.opacity = 0

            let text = SCNText(string: "\(max(0, min(50, score)))", extrusionDepth: 0.01)
            text.font = UIFont.systemFont(ofSize: 0.32, weight: .black)
            text.flatness = 0.05
            let textMaterial = SCNMaterial()
            textMaterial.diffuse.contents = UIColor(red: 1.0, green: 0.55, blue: 0.1, alpha: 1)
            textMaterial.emission.contents = UIColor(red: 0.9, green: 0.45, blue: 0.05, alpha: 1)
            text.materials = [textMaterial]
            let textNode = SCNNode(geometry: text)
            let (minBound, maxBound) = textNode.boundingBox
            textNode.position = SCNVector3(-(maxBound.x - minBound.x) / 2,
                                           -(maxBound.y - minBound.y) / 2,
                                           0.03)
            cardNode.addChildNode(textNode)
            scene.rootNode.addChildNode(cardNode)

            let delay = stagger * Double(index)
            let flipUp = SCNAction.group([
                .fadeIn(duration: 0.15),
                .rotateBy(x: .pi / 2, y: 0, z: 0, duration: 0.3),
                .moveBy(x: 0, y: 0.55, z: 0, duration: 0.3),
            ])
            flipUp.timingMode = .easeOut
            let sink = SCNAction.group([
                .fadeOut(duration: 0.35),
                .moveBy(x: 0, y: -0.3, z: 0, duration: 0.35),
            ])
            cardNode.runAction(.sequence([.wait(duration: delay), flipUp,
                                          .wait(duration: hold), sink,
                                          .removeFromParentNode()]))
        }

        guard revealed > 0 else { return 0 }
        return stagger * Double(revealed - 1) + 0.3 + hold + 0.35
    }

    // MARK: - Dunk contest demo sequence

    /// Full made-dunk moment for the dunk contest scene: trail already on the
    /// ball, rim burst, camera shake, judge reveal, and the paired audio beat.
    static func playDunkScoredSequence(in scene: SCNScene, judgeScores: [Int]) {
        if let ball = scene.rootNode.childNode(withName: "ball", recursively: true) {
            playParticleBurst(in: scene, at: ball.position)
        }
        shakeCamera(in: scene, intensity: 0.8)
        let total = judgeScores.reduce(0, +)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            playJudgeReveal(in: scene, scores: judgeScores)
            FELAudioDirector.shared.playJudgeReveal(score: total)
        }
    }
}
