import Foundation
import SceneKit
import Testing
@testable import FinalEvolutionLab

/// Flagship 3D: the venue-mesh loader must produce faithful, lit geometry from
/// the real Luma/Meshy `.nexusmesh.json` assets — the foundation the dunk scene
/// (and every venue mode) renders on.
struct NexusMeshLoaderTests {

    /// A tiny hand-authored mesh: a single lit quad (2 triangles, 4 verts).
    private func quadJSON(withNormals: Bool) -> Data {
        func vertex(_ x: Double, _ y: Double) -> [String: Any] {
            var v: [String: Any] = ["position": [x, y, 0.0], "color": [0.2, 0.6, 0.9]]
            if withNormals { v["normal"] = [0.0, 0.0, 1.0] }
            return v
        }
        let json: [String: Any] = [
            "vertices": [vertex(0, 0), vertex(1, 0), vertex(1, 1), vertex(0, 1)],
            "indices": [0, 1, 2, 0, 2, 3],
        ]
        return try! JSONSerialization.data(withJSONObject: json)
    }

    @Test func buildsLitGeometryWithNormals() throws {
        let geo = try #require(NexusBundledMeshLoader.buildGeometry(fromJSONData: quadJSON(withNormals: true)))
        #expect(geo.sources(for: .vertex).first?.vectorCount == 4)
        #expect(geo.sources(for: .normal).first?.vectorCount == 4)
        #expect(geo.sources(for: .color).first?.vectorCount == 4)
        // Normals present → physically-based lighting, not flat constant.
        #expect(geo.materials.first?.lightingModel == .physicallyBased)
        // 2 triangles.
        #expect(geo.elements.first?.primitiveCount == 2)
    }

    @Test func fallsBackToConstantLightingWithoutNormals() throws {
        let geo = try #require(NexusBundledMeshLoader.buildGeometry(fromJSONData: quadJSON(withNormals: false)))
        #expect(geo.sources(for: .normal).isEmpty)
        #expect(geo.materials.first?.lightingModel == .constant)
    }

    @Test func rejectsOutOfRangeIndices() {
        let json: [String: Any] = [
            "vertices": [["position": [0.0, 0.0, 0.0]]],
            "indices": [0, 1, 2], // references verts that don't exist
        ]
        let data = try! JSONSerialization.data(withJSONObject: json)
        #expect(NexusBundledMeshLoader.buildGeometry(fromJSONData: data) == nil)
    }

    /// Load the real bundled Venice court (the dunk venue) via the runtime
    /// `Bundle.main` resolver and prove it comes through faithfully — no
    /// shredding, full triangle count, lit.
    @Test func loadsRealVeniceCourtFaithfully() throws {
        try #require(!NexusBundledMeshLoader.importedMeshFilenames.isEmpty,
                     "manifest not bundled")
        let path = try #require(
            NexusBundledMeshLoader.resolveMeshPathNatively(assetId: "venice_beach_court_model_fbx")
        )
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let geo = try #require(NexusBundledMeshLoader.buildGeometry(fromJSONData: data))
        // Mobile LOD: 40,076 verts / 80,000 tris — loaded whole, not decimated.
        #expect(geo.sources(for: .vertex).first?.vectorCount == 40_076)
        #expect(geo.elements.first?.primitiveCount == 80_000)
        #expect(geo.sources(for: .normal).first?.vectorCount == 40_076)
        #expect(geo.materials.first?.lightingModel == .physicallyBased)
    }
}
