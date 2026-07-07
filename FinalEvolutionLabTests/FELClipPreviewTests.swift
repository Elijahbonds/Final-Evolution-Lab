import Testing
import SceneKit
@testable import FinalEvolutionLab

/// Asset-pipeline verification hook: drop a USDZ at /tmp/fel_clip_preview.usdz
/// (simulator shares the host filesystem) and this renders three frames of it
/// through SceneKit — the renderer that actually ships. Skips when absent.
@MainActor
struct FELClipPreviewTests {

    @Test func renderDroppedClip() throws {
        let input = URL(fileURLWithPath: "/tmp/fel_clip_preview.usdz")
        guard FileManager.default.fileExists(atPath: input.path) else { return }

        // Pipeline clips carry absolute meter units (1.85m character at the
        // origin) — load as-is; bbox normalization lies for skinned meshes.
        let scene = try SCNScene(url: input, options: [.checkConsistency: false])

        // Drive bundled animation players from scene time so offscreen
        // snapshots can scrub the clip deterministically.
        var duration: TimeInterval = 0
        scene.rootNode.enumerateHierarchy { node, _ in
            for key in node.animationKeys {
                if let player = node.animationPlayer(forKey: key) {
                    player.animation.usesSceneTimeBase = true
                    duration = max(duration, player.animation.duration)
                }
            }
        }

        // Fixed camera — content is normalized to 1.75 units tall at origin.
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.zFar = 100
        cameraNode.position = SCNVector3(0, 1.2, 4.2)
        cameraNode.look(at: SCNVector3(0, 0.9, 0))
        scene.rootNode.addChildNode(cameraNode)

        let light = SCNNode()
        light.light = SCNLight()
        light.light?.type = .directional
        light.light?.intensity = 1200
        light.eulerAngles = SCNVector3(-0.8, 0.4, 0)
        scene.rootNode.addChildNode(light)
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 500
        scene.rootNode.addChildNode(ambient)

        let renderer = SCNRenderer(device: MTLCreateSystemDefaultDevice(), options: nil)
        renderer.scene = scene
        renderer.pointOfView = cameraNode

        let outDir = URL(fileURLWithPath: "/tmp/fel_clip_preview_frames", isDirectory: true)
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
        let sampleTimes = duration > 0 ? [0.0, duration / 2, duration * 0.95] : [0.0]
        for (index, time) in sampleTimes.enumerated() {
            renderer.sceneTime = time
            let image = renderer.snapshot(
                atTime: time,
                with: CGSize(width: 600, height: 600),
                antialiasingMode: .multisampling2X
            )
            try image.pngData()?.write(to: outDir.appendingPathComponent("clip_\(index).png"))
        }
        print("[clip-preview] rendered \(sampleTimes.count) frames, duration \(duration)s")
    }
}
