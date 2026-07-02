import Foundation
import SceneKit
import Testing
@testable import FinalEvolutionLab

/// Flagship 3D coverage: every playable mode must resolve to a real, loadable,
/// lit environment mesh at runtime — dojo, shop, and all the rest, not just the
/// dunk court. Exercises the actual `Bundle.main` resolution path the app uses,
/// so a pass proves environments will attach on device.
struct VenueCoverageTests {

    /// Modes that render a 3D venue (both dunk variants + venicePickup share
    /// runtime venues via nexusRuntimeModeId; marketBrowse is the shop).
    private static let venueModes: [GameModeId] = [
        .basketballHeadToHead, .venicePickup, .basketballDunkContest3D, .basketball3v3,
        .karate, .karateEndless, .baseball, .football, .soccer, .golf, .tennis,
        .volleyball, .gymnastics, .surfing, .skateboarding, .snowboarding,
        .brainBrawl, .whoSceneIt, .courtCarnival, .marketBrowse,
    ]

    @Test func manifestAndMeshesAreBundled() {
        // Proves the "Bundle NEXUS venue assets" phase shipped the manifest into
        // the app bundle — otherwise every runtime resolution below is moot.
        #expect(!NexusBundledMeshLoader.importedMeshFilenames.isEmpty)
    }

    @Test func everyModeResolvesALoadableLitEnvironmentAtRuntime() throws {
        // Guard: if the manifest didn't bundle, fail loudly rather than skip.
        try #require(!NexusBundledMeshLoader.importedMeshFilenames.isEmpty,
                     "manifest not bundled — cannot verify venue coverage")

        for mode in Self.venueModes {
            let assets = try #require(NexusBundledMeshLoader.venueAssets(for: mode),
                                      "no venue mapped for \(mode.rawValue)")

            // Preferred path: recreated textured .scn (full PBR from source FBX).
            let scnNode = try #require(
                NexusBundledMeshLoader.loadSceneKitSceneNode(assetId: assets.environmentAssetId),
                "\(mode.rawValue) → \(assets.environmentAssetId).scn missing from bundle"
            )
            var texturedGeo: SCNGeometry?
            scnNode.enumerateHierarchy { n, stop in
                if let g = n.geometry { texturedGeo = g; stop.pointee = true }
            }
            let geo = try #require(texturedGeo, "\(mode.rawValue) .scn has no geometry")
            #expect((geo.sources(for: .vertex).first?.vectorCount ?? 0) > 0)
            if NexusBundledMeshLoader.importedMeshFilenames[assets.environmentAssetId] != nil {
                #expect(!geo.sources(for: .texcoord).isEmpty,
                        "\(mode.rawValue) venue has no UVs — textures cannot map")
            }
            #expect(geo.materials.first?.lightingModel == .physicallyBased,
                    "\(mode.rawValue) environment is not lit")

            // Fallback path: mobile JSON LOD still resolves and builds — for
            // assets that have one (procedural placeholders are .scn-only).
            if NexusBundledMeshLoader.importedMeshFilenames[assets.environmentAssetId] != nil {
                let path = try #require(
                    NexusBundledMeshLoader.resolveMeshPathNatively(assetId: assets.environmentAssetId),
                    "\(mode.rawValue) JSON fallback did not resolve"
                )
                let data = try Data(contentsOf: URL(fileURLWithPath: path))
                #expect(NexusBundledMeshLoader.buildGeometry(fromJSONData: data) != nil,
                        "\(mode.rawValue) JSON fallback failed to build")
            }
        }
    }

    @Test func loadNodeProducesAttachableNodeForDojoAndShop() throws {
        try #require(!NexusBundledMeshLoader.importedMeshFilenames.isEmpty)

        let dojo = try #require(NexusBundledMeshLoader.venueAssets(for: .karate))
        #expect(dojo.environmentAssetId == "zen_dojo_environment_model_fbx")
        let dojoNode = try #require(
            NexusBundledMeshLoader.loadNode(assetId: dojo.environmentAssetId,
                                            nodeName: "bundledVenueEnvironment",
                                            position: SCNVector3(0, 0, 0),
                                            scale: SCNVector3(1, 1, 1)),
            "dojo did not load into a SceneKit node"
        )
        #expect(containsGeometry(dojoNode))

        // Veniceball Shop: generated placeholder until a real Luma capture of
        // the shop replaces it (the sourced FBX contained a person scan).
        let shop = try #require(NexusBundledMeshLoader.venueAssets(for: .marketBrowse))
        #expect(shop.environmentAssetId == "veniceball_shop_placeholder")
        let shopNode = try #require(
            NexusBundledMeshLoader.loadNode(assetId: shop.environmentAssetId,
                                            nodeName: "bundledVenueEnvironment",
                                            position: SCNVector3(0, 0, 0),
                                            scale: SCNVector3(1, 1, 1))
        )
        #expect(containsGeometry(shopNode))
    }

    private func containsGeometry(_ node: SCNNode) -> Bool {
        var found = false
        node.enumerateHierarchy { n, stop in
            if n.geometry != nil { found = true; stop.pointee = true }
        }
        return found
    }
}
