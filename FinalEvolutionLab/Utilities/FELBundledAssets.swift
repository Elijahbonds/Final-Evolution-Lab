import SceneKit

/// Bundled 3D assets converted offline from Meshy/Seeles/DeepMotion sources via
/// `scripts/asset_pipeline/blender_to_usdz.py`. Loading is fail-soft: every
/// caller keeps its procedural fallback, so a missing/corrupt USDZ never
/// breaks gameplay — it just renders the old placeholder look.
nonisolated enum FELBundledAsset: String, CaseIterable, Sendable {
    // Venues (static meshes)
    case venueShimogamoDojo = "VenueShimogamoDojo"
    case venueVeniceBlacktop = "VenueVeniceBlacktop"

    // Characters (skinned, baked animation loops)
    case characterElijahWalking = "CharacterElijahWalking"
    case characterElijahRunning = "CharacterElijahRunning"
    case fighterKarateIdle = "FighterKarateIdle"
    case fighterKarateCombo = "FighterKarateCombo"
    case playerDunk = "PlayerDunk"

    var isVenue: Bool {
        switch self {
        case .venueShimogamoDojo, .venueVeniceBlacktop: return true
        default: return false
        }
    }
}

@MainActor
enum FELBundledAssets {
    private static var cache: [FELBundledAsset: SCNNode] = [:]

    /// Loads the asset's root node (cached; clones per call so scenes can
    /// mutate freely). Returns nil when the USDZ is missing or unreadable.
    static func node(for asset: FELBundledAsset) -> SCNNode? {
        if let cached = cache[asset] {
            return cached.clone()
        }
        guard let url = Bundle.main.url(forResource: asset.rawValue, withExtension: "usdz"),
              let scene = try? SCNScene(url: url, options: [.checkConsistency: false]) else {
            return nil
        }
        let root = SCNNode()
        for child in scene.rootNode.childNodes {
            root.addChildNode(child)
        }
        cache[asset] = root
        return root.clone()
    }

    /// Venue mesh normalized into gameplay space: centered on origin,
    /// grounded at y=0, uniformly scaled so its footprint spans `footprint`
    /// world units on its longest horizontal side.
    static func venueNode(_ asset: FELBundledAsset, footprint: Float) -> SCNNode? {
        guard let node = node(for: asset) else { return nil }
        return normalized(node, longestSide: footprint, sizeAxis: .horizontal)
    }

    /// Skinned character normalized to `height` world units, feet at y=0.
    static func characterNode(_ asset: FELBundledAsset, height: Float) -> SCNNode? {
        guard let node = node(for: asset) else { return nil }
        return normalized(node, longestSide: height, sizeAxis: .vertical)
    }

    // MARK: - Normalization

    private enum SizeAxis { case horizontal, vertical }

    private static func normalized(_ node: SCNNode, longestSide: Float, sizeAxis: SizeAxis) -> SCNNode {
        let container = SCNNode()
        container.addChildNode(node)

        let (minVec, maxVec) = node.boundingBox
        let size = SCNVector3(maxVec.x - minVec.x, maxVec.y - minVec.y, maxVec.z - minVec.z)
        let reference: Float
        switch sizeAxis {
        case .horizontal: reference = max(size.x, size.z)
        case .vertical: reference = size.y
        }
        guard reference > 0.0001 else { return container }

        let scale = longestSide / reference
        node.scale = SCNVector3(scale, scale, scale)

        // Recenter: origin at footprint center, base sitting on y=0.
        let centerX = (minVec.x + maxVec.x) / 2 * scale
        let centerZ = (minVec.z + maxVec.z) / 2 * scale
        let baseY = minVec.y * scale
        node.position = SCNVector3(-centerX, -baseY, -centerZ)

        return container
    }
}
