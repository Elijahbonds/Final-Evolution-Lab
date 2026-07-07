import SceneKit

/// Bundled 3D assets converted offline from Meshy/Seeles/DeepMotion sources via
/// `scripts/asset_pipeline/blender_to_usdz.py`. Loading is fail-soft: every
/// caller keeps its procedural fallback, so a missing/corrupt USDZ never
/// breaks gameplay — it just renders the old placeholder look.
nonisolated enum FELBundledAsset: String, CaseIterable, Sendable {
    // Venues (static meshes)
    case venueShimogamoDojo = "VenueShimogamoDojo"
    case venueVeniceBlacktop = "VenueVeniceBlacktop"
    case venueTennisCourt = "VenueTennisCourt"
    case venueSkatePark = "VenueSkatePark"
    case venueMountainSlope = "VenueMountainSlope"
    case venueSurfBreak = "VenueSurfBreak"
    case venueLinksGolf = "VenueLinksGolf"
    case venueSoccerStadium = "VenueSoccerStadium"
    case venueBallpark = "VenueBallpark"
    case venueGymnasticsGym = "VenueGymnasticsGym"
    case venueMuscleBeachStage = "VenueMuscleBeachStage"
    case venueMuscleBeachGym = "VenueMuscleBeachGym"

    // Prop packs (per-sport equipment sets, staged for mode wiring)
    case propsTennis = "PropsTennis"
    case propsVolleyball = "PropsVolleyball"
    case propsBaseball = "PropsBaseball"
    case propsFootball = "PropsFootball"
    case propsSoccer = "PropsSoccer"
    case propsBoardSports = "PropsBoardSports"
    case propsSedan = "PropsSedan"

    // Characters (skinned, baked animation loops) — all use the Elijah Bonds
    // Meshy model. Walking/Running are Meshy-native; the rest come out of the
    // mocap retarget pipeline with absolute meter units baked in.
    case characterElijahWalking = "CharacterElijahWalking"
    case characterElijahRunning = "CharacterElijahRunning"
    case elijahKarateIdle = "ElijahKarateIdle"
    case elijahKarateCombo = "ElijahKarateCombo"
    case elijahDunk = "ElijahDunk"

    // Karate strike one-shots — Meshy preset animations on the Elijah Bonds
    // model, converted via blender_to_usdz.py (see PR context: strike playback).
    case elijahStrikeJab = "ElijahStrikeJab"
    case elijahStrikeHook = "ElijahStrikeHook"
    case elijahStrikeUppercut = "ElijahStrikeUppercut"
    case elijahStrikeRoundhouse = "ElijahStrikeRoundhouse"
    case elijahStrikeHighKick = "ElijahStrikeHighKick"
    case elijahGuard = "ElijahGuard"

    // NPCs — other Meshy models auto-rigged (autorig_npc.py) and driven by
    // retargeted Seeles clips.
    case npcEricNashIdle = "NPCEricNashIdle"
    case npcEricNashKarateCombo = "NPCEricNashKarateCombo"
    case npcTallAthleticIdle = "NPCTallAthleticIdle"

    var isVenue: Bool {
        switch self {
        case .venueShimogamoDojo, .venueVeniceBlacktop, .venueTennisCourt,
             .venueSkatePark, .venueMountainSlope, .venueSurfBreak,
             .venueLinksGolf, .venueSoccerStadium, .venueBallpark,
             .venueGymnasticsGym, .venueMuscleBeachStage, .venueMuscleBeachGym,
             .propsTennis, .propsVolleyball, .propsBaseball,
             .propsFootball, .propsSoccer, .propsBoardSports, .propsSedan:
            return true
        default:
            return false
        }
    }

    /// Pipeline clips are exported at real-world scale (1.85m character) and
    /// must NOT be bbox-normalized — skinned-mesh bounding boxes are unreliable.
    var isPipelineClip: Bool {
        switch self {
        case .elijahKarateIdle, .elijahKarateCombo, .elijahDunk,
             .elijahStrikeJab, .elijahStrikeHook, .elijahStrikeUppercut,
             .elijahStrikeRoundhouse, .elijahStrikeHighKick, .elijahGuard,
             .npcEricNashIdle, .npcEricNashKarateCombo,
             .npcTallAthleticIdle:
            return true
        default:
            return false
        }
    }
}

@MainActor
enum FELBundledAssets {
    private static var cache: [FELBundledAsset: SCNNode] = [:]

    /// Loads the asset's root node. Static venues are cached and cloned;
    /// skinned characters are ALWAYS loaded fresh — cloning a node tree with
    /// an SCNSkinner leaves the skinner bound to the original skeleton, so
    /// the cloned mesh renders at the original's location (i.e. nowhere).
    static func node(for asset: FELBundledAsset) -> SCNNode? {
        if asset.isVenue, let cached = cache[asset] {
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
        if asset.isVenue {
            cache[asset] = root
            return root.clone()
        }
        return root
    }

    /// Venue mesh normalized into gameplay space: centered on origin,
    /// grounded at y=0, uniformly scaled so its footprint spans `footprint`
    /// world units on its longest horizontal side.
    static func venueNode(_ asset: FELBundledAsset, footprint: Float) -> SCNNode? {
        guard let node = node(for: asset) else { return nil }
        return normalized(node, longestSide: footprint, sizeAxis: .horizontal)
    }

    /// Skinned character normalized to `height` world units, feet at y=0.
    ///
    /// Pipeline clips are measured from their SKELETON JOINTS (Hips/Head/
    /// feet import as real nodes) — bounding boxes are unreliable for
    /// skinned meshes, and exporter unit metadata has proven untrustworthy
    /// across the Blender→USD→SceneKit chain.
    static func characterNode(_ asset: FELBundledAsset, height: Float) -> SCNNode? {
        guard let node = node(for: asset) else { return nil }
        if asset.isPipelineClip {
            let container = SCNNode()
            container.addChildNode(node)
            let head = node.childNode(withName: "head_end", recursively: true)
                ?? node.childNode(withName: "Head", recursively: true)
            let foot = node.childNode(withName: "LeftFoot", recursively: true)
                ?? node.childNode(withName: "RightFoot", recursively: true)
            if let head, let foot {
                // Head joint sits ~8% below the crown; feet joints ~ankle height.
                // NOTE: do NOT re-root here from rest-pose joints — animated
                // hips differ from rest hips and clips exported through the
                // mocap pipeline are already re-rooted. Source-side re-rooting
                // (blender_to_usdz/mocap_pipeline) is the single owner of that.
                let jointSpan = head.worldPosition.y - foot.worldPosition.y
                if jointSpan > 0.0001 {
                    let scale = height / (jointSpan * 1.12)
                    container.scale = SCNVector3(scale, scale, scale)
                }
            }
            // Skinned meshes carry unreliable bounding boxes; SceneKit frustum-
            // culls by bbox, which can cull a visibly-on-screen character.
            // Give every skinned node a generous bbox so it is never culled.
            node.enumerateHierarchy { child, _ in
                if child.skinner != nil {
                    child.boundingBox = (
                        min: SCNVector3(-50, -50, -50),
                        max: SCNVector3(50, 50, 50)
                    )
                }
            }
            return container
        }
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
