import SceneKit
import UIKit

/// Self-contained impact-VFX helper for the karate dojo.
///
/// Spawns a short-lived additive particle burst at the point of contact when a
/// strike lands, plus a quick flash sprite. Kept out of the large scene files
/// so it can evolve independently. Everything is fail-soft and performance-
/// tiered; on `.lowPower` the burst is skipped entirely.
enum KarateImpactVFX {

    private static let cyan = UIColor(red: 0, green: 0.95, blue: 0.9, alpha: 1)
    private static let hotOrange = UIColor(red: 1.0, green: 0.55, blue: 0.15, alpha: 1)

    /// Emit a contact burst at `position` in `scene`. `critical` makes it
    /// bigger, hotter and longer. Auto-removes after its lifespan.
    static func burst(in scene: SCNScene, at position: SCNVector3, critical: Bool) {
        let tier = FELPerformanceMonitor.shared.currentTier
        let birth: CGFloat
        switch tier {
        case .high: birth = critical ? 900 : 600
        case .balanced: birth = critical ? 500 : 320
        case .lowPower: birth = 0
        }
        guard birth > 0 else { return }

        let node = SCNNode()
        node.position = position

        let particles = SCNParticleSystem()
        // One quick puff: high birth rate but emit for a fraction of a second.
        particles.birthRate = birth
        particles.emissionDuration = critical ? 0.10 : 0.07
        particles.loops = false
        particles.particleLifeSpan = critical ? 0.42 : 0.32
        particles.particleLifeSpanVariation = 0.12
        particles.particleSize = critical ? 0.022 : 0.016
        particles.particleSizeVariation = 0.008
        particles.particleColor = critical ? hotOrange : cyan
        particles.emitterShape = SCNSphere(radius: 0.06)
        particles.birthLocation = .surface
        particles.birthDirection = .random
        particles.spreadingAngle = 45
        particles.particleVelocity = critical ? 3.2 : 2.4
        particles.particleVelocityVariation = 1.0
        particles.acceleration = SCNVector3(0, -2.5, 0)   // slight fall for weight
        particles.dampingFactor = 1.2
        particles.blendMode = .additive
        particles.isLightingEnabled = false
        node.addParticleSystem(particles)
        scene.rootNode.addChildNode(node)

        // Impact flash: a brief additive billboard that scales out and fades.
        let flash = flashNode(critical: critical)
        flash.position = position
        scene.rootNode.addChildNode(flash)

        let lifetime = particles.particleLifeSpan + Double(particles.emissionDuration) + 0.1
        node.runAction(.sequence([
            .wait(duration: lifetime),
            .removeFromParentNode()
        ]))
    }

    private static func flashNode(critical: Bool) -> SCNNode {
        let size: CGFloat = critical ? 0.9 : 0.6
        let plane = SCNPlane(width: size, height: size)
        let mat = SCNMaterial()
        mat.diffuse.contents = critical ? hotOrange : cyan
        mat.emission.contents = critical ? hotOrange : cyan
        mat.blendMode = .add
        mat.isDoubleSided = true
        mat.writesToDepthBuffer = false
        mat.lightingModel = .constant
        plane.materials = [mat]

        let node = SCNNode(geometry: plane)
        node.opacity = critical ? 0.95 : 0.8
        let billboard = SCNBillboardConstraint()
        node.constraints = [billboard]

        node.runAction(.sequence([
            .group([
                .scale(to: critical ? 2.4 : 1.8, duration: 0.16),
                .fadeOut(duration: 0.16)
            ]),
            .removeFromParentNode()
        ]))
        return node
    }
}
