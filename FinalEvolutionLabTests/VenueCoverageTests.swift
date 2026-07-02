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
            let path = try #require(
                NexusBundledMeshLoader.resolveMeshPathNatively(assetId: assets.environmentAssetId),
                "\(mode.rawValue) → \(assets.environmentAssetId) did not resolve in bundle"
            )
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            let geo = try #require(NexusBundledMeshLoader.buildGeometry(fromJSONData: data),
                                   "\(mode.rawValue) failed to build geometry")
            #expect((geo.sources(for: .vertex).first?.vectorCount ?? 0) > 0)
            #expect((geo.elements.first?.primitiveCount ?? 0) > 0)
            // Real venue meshes carry normals → lit shading.
            #expect(geo.materials.first?.lightingModel == .physicallyBased,
                    "\(mode.rawValue) environment is not lit")
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
        #expect(dojoNode.geometry != nil)

        let shop = try #require(NexusBundledMeshLoader.venueAssets(for: .marketBrowse))
        #expect(shop.environmentAssetId == "luma_venice_shop_environment_model_fbx")
        let shopNode = try #require(
            NexusBundledMeshLoader.loadNode(assetId: shop.environmentAssetId,
                                            nodeName: "bundledVenueEnvironment",
                                            position: SCNVector3(0, 0, 0),
                                            scale: SCNVector3(1, 1, 1))
        )
        #expect(shopNode.geometry != nil)
    }
}
