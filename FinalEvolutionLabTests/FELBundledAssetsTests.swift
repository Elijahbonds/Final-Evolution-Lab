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

    /// Every character asset must ship with skinned geometry (a real skin,
    /// not bare bones or static shells) AND at least one baked animation.
    @Test func charactersAreSkinnedAndAnimated() {
        let characters = FELBundledAsset.allCases.filter { !$0.isVenue }
        for asset in characters {
            guard let node = FELBundledAssets.node(for: asset) else {
                Issue.record("\(asset.rawValue) failed to load")
                continue
            }
            var hasSkinner = false
            var hasAnimation = false
            node.enumerateHierarchy { child, _ in
                if child.skinner != nil { hasSkinner = true }
                if !child.animationKeys.isEmpty { hasAnimation = true }
            }
            #expect(hasSkinner, "\(asset.rawValue): no skinned mesh")
            #expect(hasAnimation, "\(asset.rawValue): no animation")
        }
    }

    /// Venues must contain visible geometry.
    @Test func venuesHaveGeometry() {
        for asset in FELBundledAsset.allCases.filter(\.isVenue) {
            guard let node = FELBundledAssets.node(for: asset) else {
                Issue.record("\(asset.rawValue) failed to load")
                continue
            }
            var geometryCount = 0
            node.enumerateHierarchy { child, _ in
                if child.geometry != nil { geometryCount += 1 }
            }
            #expect(geometryCount > 0, "\(asset.rawValue): no geometry")
        }
    }
}
