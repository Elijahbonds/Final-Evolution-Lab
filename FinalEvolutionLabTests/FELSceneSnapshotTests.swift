import Testing
import SceneKit
@testable import FinalEvolutionLab

/// Renders hero-mode scenes offscreen and writes PNGs to the app container's
/// Documents directory — used by the asset pipeline to visually verify venue
/// and character integration without driving the UI.
@MainActor
struct FELSceneSnapshotTests {

    @Test func snapshotHeroModeScenes() throws {
        let modes: [(GameModeId, String)] = [
            (.karate, "snapshot_karate"),
            (.basketballDunkContest3D, "snapshot_dunk"),
        ]
        // Simulator processes share the host filesystem — write somewhere
        // retrievable after ephemeral test clones are destroyed.
        let docs = URL(fileURLWithPath: "/tmp/fel_snapshots", isDirectory: true)
        try FileManager.default.createDirectory(at: docs, withIntermediateDirectories: true)

        for (mode, name) in modes {
            let scene = GameSceneFactory.buildScene(for: mode)
            #expect(scene.rootNode.childNode(withName: "bundledVenueBackdrop", recursively: true) != nil,
                    "\(mode.rawValue): bundled USDZ venue missing — fallback in use")

            var cameraNode: SCNNode?
            var lights: [String] = []
            scene.rootNode.enumerateHierarchy { node, _ in
                if node.camera != nil && cameraNode == nil { cameraNode = node }
                if let light = node.light {
                    lights.append("\(node.name ?? "?")=\(light.type.rawValue)@\(Int(light.intensity))")
                }
            }
            print("[snapshot] \(mode.rawValue) camera=\(cameraNode?.name ?? "NONE") lights=\(lights)")

            let renderer = SCNRenderer(device: MTLCreateSystemDefaultDevice(), options: nil)
            renderer.scene = scene
            renderer.pointOfView = cameraNode
            let image = renderer.snapshot(
                atTime: 0.5,
                with: CGSize(width: 1200, height: 560),
                antialiasingMode: .multisampling2X
            )
            let url = docs.appendingPathComponent("\(name).png")
            try image.pngData()?.write(to: url)
            print("[snapshot] wrote \(url.path)")

            // Diagnostic pass: flood with ambient light to separate geometry
            // placement problems from lighting problems.
            let ambient = SCNNode()
            ambient.light = SCNLight()
            ambient.light?.type = .ambient
            ambient.light?.intensity = 1500
            ambient.light?.color = UIColor.white
            scene.rootNode.addChildNode(ambient)
            let litImage = renderer.snapshot(
                atTime: 1.0,
                with: CGSize(width: 1200, height: 560),
                antialiasingMode: .multisampling2X
            )
            try litImage.pngData()?.write(to: docs.appendingPathComponent("\(name)_lit.png"))
            ambient.removeFromParentNode()
        }
    }
}
