import Testing
import SceneKit
@testable import FinalEvolutionLab

@MainActor
struct FELBundledAssetsTests {

    @Test func everyBundledAssetLoads() {
        for asset in FELBundledAsset.allCases {
            let node = FELBundledAssets.node(for: asset)
            #expect(node != nil, "missing or unreadable USDZ: \(asset.rawValue)")
            if let node {
                #expect(!node.childNodes.isEmpty, "empty scene graph: \(asset.rawValue)")
            }
        }
    }

    @Test func venueNormalizationGroundsAndScales() {
        guard let venue = FELBundledAssets.venueNode(.venueShimogamoDojo, footprint: 18) else {
            Issue.record("dojo venue failed to load")
            return
        }
        let (minVec, maxVec) = venue.boundingBox
        let width = maxVec.x - minVec.x
        let depth = maxVec.z - minVec.z
        #expect(abs(max(width, depth) - 18) < 0.5, "footprint should be ~18, got \(max(width, depth))")
        #expect(abs(minVec.y) < 0.5, "venue base should sit near y=0, got \(minVec.y)")
    }

    @Test func characterNormalizationMatchesHeight() {
        guard let fighter = FELBundledAssets.characterNode(.fighterKarateIdle, height: 1.75) else {
            Issue.record("karate fighter failed to load")
            return
        }
        let (minVec, maxVec) = fighter.boundingBox
        let height = maxVec.y - minVec.y
        #expect(abs(height - 1.75) < 0.2, "fighter height should be ~1.75, got \(height)")
    }
}
