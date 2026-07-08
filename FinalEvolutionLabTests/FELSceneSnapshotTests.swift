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
            (.karateEndless, "snapshot_karate_endless"),
            (.basketballDunkContest3D, "snapshot_dunk"),
            (.basketballHeadToHead, "snapshot_bball_h2h"),
            (.basketball3v3, "snapshot_bball_3v3"),
            (.venicePickup, "snapshot_venice_pickup"),
            (.courtCarnival, "snapshot_court_carnival"),
            (.tennis, "snapshot_tennis"),
            (.skateboarding, "snapshot_skate"),
            (.gymnastics, "snapshot_gymnastics"),
            (.soccer, "snapshot_soccer"),
            (.baseball, "snapshot_baseball"),
            (.golf, "snapshot_golf"),
            (.snowboarding, "snapshot_snowboard"),
            (.surfing, "snapshot_surf"),
        ]
        // Simulator processes share the host filesystem — write somewhere
        // retrievable after ephemeral test clones are destroyed.
        let docs = URL(fileURLWithPath: "/tmp/fel_snapshots", isDirectory: true)
        try FileManager.default.createDirectory(at: docs, withIntermediateDirectories: true)
        var diagnostics: [String] = []
        defer {
            try? diagnostics.joined(separator: "\n")
                .write(to: docs.appendingPathComponent("diag.txt"), atomically: true, encoding: .utf8)
        }

        // Basketball family intentionally uses panorama + procedural court
        // (no USDZ venue) — the photoreal backdrop is the look.
        let venueMapped: Set<GameModeId> = [
            .karate, .karateEndless, .tennis, .skateboarding, .snowboarding,
            .surfing, .golf, .soccer, .baseball, .gymnastics, .marketBrowse,
        ]
        for (mode, name) in modes {
            let scene = GameSceneFactory.buildScene(for: mode)
            if venueMapped.contains(mode) {
                #expect(scene.rootNode.childNode(withName: "bundledVenueBackdrop", recursively: true) != nil,
                        "\(mode.rawValue): bundled USDZ venue missing — fallback in use")
            }

            var cameraNode: SCNNode?
            var lights: [String] = []
            scene.rootNode.enumerateHierarchy { node, _ in
                if node.camera != nil && cameraNode == nil { cameraNode = node }
                if let light = node.light {
                    lights.append("\(node.name ?? "?")=\(light.type.rawValue)@\(Int(light.intensity))")
                }
            }
            diagnostics.append("\(mode.rawValue) camera=\(cameraNode?.name ?? "NONE") pos=\(cameraNode.map { "\($0.worldPosition)" } ?? "-") lights=\(lights)")
            for avatarName in ["fighter1", "fighter2", "dunker", "batter", "kicker", "goalkeeper", "golfer", "player", "opponent", "vPlayer1"] {
                if let avatar = scene.rootNode.childNode(withName: avatarName, recursively: true) {
                    var geo = 0, skin = 0, anim = 0
                    avatar.enumerateHierarchy { n, _ in
                        if n.geometry != nil { geo += 1 }
                        if n.skinner != nil { skin += 1 }
                        anim += n.animationKeys.count
                    }
                    diagnostics.append("\(mode.rawValue).\(avatarName) pos=\(avatar.worldPosition) scale=\(avatar.scale) geo=\(geo) skin=\(skin) anim=\(anim)")
                    // Where do this avatar's meshes actually render? Skinned
                    // meshes follow their joints, statics follow node transform.
                    avatar.enumerateHierarchy { n, _ in
                        if n.geometry != nil {
                            let (c, r) = n.boundingSphere
                            let wc = n.convertPosition(c, to: nil)
                            let wt = n.worldTransform
                            let sx = (wt.m11 * wt.m11 + wt.m12 * wt.m12 + wt.m13 * wt.m13).squareRoot()
                            diagnostics.append("\(mode.rawValue).\(avatarName)   geo '\(n.name ?? "?")' skinner=\(n.skinner != nil) worldCenter=\(wc) worldR=\(r * sx)")
                        }
                        for joint in ["Hips", "Head", "LeftFoot"] where n.name == joint {
                            diagnostics.append("\(mode.rawValue).\(avatarName)   joint \(joint) world=\(n.worldPosition)")
                        }
                    }
                } else {
                    diagnostics.append("\(mode.rawValue).\(avatarName) MISSING")
                }
            }
            // Any geometry anywhere in the scene with a giant world-space
            // bounding sphere (excluding skinner nodes whose bbox is padded).
            scene.rootNode.enumerateHierarchy { n, _ in
                guard n.geometry != nil, n.skinner == nil else { return }
                let (c, r) = n.boundingSphere
                let wt = n.worldTransform
                let sx = (wt.m11 * wt.m11 + wt.m12 * wt.m12 + wt.m13 * wt.m13).squareRoot()
                let wr = r * sx
                if wr > 40 {
                    diagnostics.append("\(mode.rawValue) BIGGEO '\(n.name ?? "?")' parent='\(n.parent?.name ?? "?")' worldCenter=\(n.convertPosition(c, to: nil)) worldR=\(wr)")
                }
            }

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
