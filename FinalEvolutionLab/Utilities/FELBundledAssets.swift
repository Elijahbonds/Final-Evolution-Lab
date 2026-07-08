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

    // Animated locomotion clips (Meshy "basic_animations" walk/run, converted
    // via blender_anim_glb_to_usdz.py with the root LOCKED IN PLACE so the
    // cycle loops on the spot). These carry an embedded SkelAnimation that is
    // auto-played on load — used to keep moving players/AI and standing NPCs
    // visibly alive instead of frozen posed statues.
    case npcEricNashWalk = "NPCEricNashWalk"
    case npcEricNashRun = "NPCEricNashRun"
    case npcTallAthleticWalk = "NPCTallAthleticWalk"
    case npcTallAthleticRun = "NPCTallAthleticRun"
    case characterElijahWalkAnim = "CharacterElijahWalkAnim"
    case characterElijahRunAnim = "CharacterElijahRunAnim"

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
             .npcTallAthleticIdle,
             .npcEricNashWalk, .npcEricNashRun,
             .npcTallAthleticWalk, .npcTallAthleticRun,
             .characterElijahWalkAnim, .characterElijahRunAnim:
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
            // The mocap-retarget Elijah clips ship with a leftover static
            // "Alpha_Surface" T-pose mesh in raw centimeter units; under the
            // joint-normalization container scale (~90x) it becomes a
            // kilometers-wide statue that swallows whole scenes (the soccer/
            // golf/baseball cameras sat inside it). It is never the visible
            // character — the skinned char1 mesh is — so drop it at load.
            node.childNode(withName: "Alpha_Surface", recursively: true)?
                .removeFromParentNode()
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
            // #1 on-device bug fix: USDZ skeletal animations do NOT auto-play
            // in SceneKit. Kick every embedded SCNAnimationPlayer so the
            // character is alive the instant it is placed (every mode, every
            // code path loads through here). Clip-less skinned meshes get a
            // gentle procedural "alive" idle so nothing is ever a frozen statue.
            playAllAnimations(on: container, loop: true)
            ensureAlive(container)
            return container
        }
        let container = normalized(node, longestSide: height, sizeAxis: .vertical)
        playAllAnimations(on: container, loop: true)
        ensureAlive(container)
        return container
    }

    // MARK: - Animation liveness

    /// Finds every `SCNAnimationPlayer` in `node`'s hierarchy, starts it, and
    /// makes it loop. USDZ-imported skeletal clips arrive paused/one-shot in
    /// SceneKit; without this every skinned character renders frozen on its
    /// first posed frame. Returns the number of players started (0 ⇒ the mesh
    /// carries no embedded animation).
    @discardableResult
    static func playAllAnimations(on node: SCNNode, loop: Bool) -> Int {
        var started = 0
        node.enumerateHierarchy { child, _ in
            for key in child.animationKeys {
                guard let player = child.animationPlayer(forKey: key) else { continue }
                if loop {
                    player.animation.repeatCount = .greatestFiniteMagnitude
                    player.animation.autoreverses = false
                }
                player.play()
                started += 1
            }
        }
        return started
    }

    /// Guarantees `node` is never a frozen statue. If it already has embedded
    /// animation playing, this is a no-op. Otherwise it applies a subtle
    /// whole-node "breathing" idle — a small vertical bob plus a micro yaw
    /// sway — so procedural avatars and any clip-less skinned mesh still read
    /// as alive. Applied under a stable key so it is idempotent.
    static func ensureAlive(_ node: SCNNode) {
        var hasEmbedded = false
        node.enumerateHierarchy { child, _ in
            if !child.animationKeys.isEmpty { hasEmbedded = true }
        }
        applyAliveIdle(to: node, force: false, alreadyAnimated: hasEmbedded)
    }

    /// Whole-node procedural idle. `force` re-applies even if embedded
    /// animation exists (unused today; kept for callers that want belt-and-
    /// suspenders liveness). No-op if the node is already carrying our idle.
    static func applyAliveIdle(to node: SCNNode, force: Bool, alreadyAnimated: Bool) {
        guard force || !alreadyAnimated else { return }
        guard node.action(forKey: aliveIdleKey) == nil else { return }
        // Deterministic-but-varied phase so a crowd of NPCs does not breathe in
        // lockstep (hash the node's identity into a 0…1 phase).
        let phase = Double(abs((node.name ?? "\(ObjectIdentifier(node).hashValue)").hashValue % 1000)) / 1000.0
        let bobAmount: CGFloat = 0.018
        let bobDur = 1.6 + phase * 0.8
        let bob = SCNAction.sequence([
            SCNAction.moveBy(x: 0, y: bobAmount, z: 0, duration: bobDur),
            SCNAction.moveBy(x: 0, y: -bobAmount, z: 0, duration: bobDur)
        ])
        bob.timingMode = .easeInEaseOut
        // Micro yaw sway around the node's current heading.
        let baseYaw = CGFloat(node.eulerAngles.y)
        let swayDur = 2.1 + phase * 0.9
        let sway = SCNAction.sequence([
            SCNAction.rotateTo(x: 0, y: baseYaw + 0.05, z: 0, duration: swayDur, usesShortestUnitArc: true),
            SCNAction.rotateTo(x: 0, y: baseYaw - 0.05, z: 0, duration: swayDur, usesShortestUnitArc: true)
        ])
        sway.timingMode = .easeInEaseOut
        node.runAction(SCNAction.repeatForever(bob), forKey: aliveIdleKey)
        node.runAction(SCNAction.repeatForever(sway), forKey: aliveSwayKey)
    }

    /// Removes the procedural idle (e.g. when a node starts real locomotion).
    static func stopAliveIdle(_ node: SCNNode) {
        node.removeAction(forKey: aliveIdleKey)
        node.removeAction(forKey: aliveSwayKey)
    }

    static let aliveIdleKey = "felAliveIdle"
    static let aliveSwayKey = "felAliveSway"

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
