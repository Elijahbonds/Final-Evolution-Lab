import Foundation

/// MotionModule registry — links pipeline-produced motion clips
/// (`scripts/asset_pipeline`, tracked in `assets/motion/registry.json`) to the
/// game modes that play them. This is the AssetManager piece of Phase 4:
/// gameplay asks "which clips can this mode use?" and gets back typed
/// ``MotionClip`` values that resolve to a bundled USDZ via ``FELBundledAsset``.
///
/// Source of truth is fail-soft, matching ``FELBundledAssets`` conventions:
/// a compiled-in table covers every clip that ships in the app bundle, and if
/// a pipeline `registry.json` is ALSO bundled (it normally lives in the repo,
/// not the app), its processed clips are merged in on top. A missing or
/// malformed registry never breaks anything — callers just get the compiled
/// table.
nonisolated struct MotionClip: Sendable, Identifiable, Equatable {
    /// How a clip drives gameplay — parsed from the pipeline registry's
    /// `type` strings (`dunk_or_jump_reach`, `kick`, `jump`, `ground_move`).
    nonisolated enum MoveType: String, Codable, Sendable {
        case dunkOrJumpReach = "dunk_or_jump_reach"
        case kick = "kick"
        case jump = "jump"
        case groundMove = "ground_move"
        case unknown

        /// Lenient parse — unrecognized pipeline types degrade to ``unknown``
        /// instead of failing the whole registry decode.
        init(registryType: String) {
            self = MoveType(rawValue: registryType) ?? .unknown
        }
    }

    /// Stable clip identity — the pipeline `crop_id`, or the
    /// ``FELBundledAsset`` raw value for compiled-in bundled clips.
    let id: String
    /// Provenance: the raw mocap take (BVH/FBX) this clip was cropped from.
    let sourceTake: String
    let moveType: MoveType
    /// Dunk clips are re-targeted so the reach apex matches a regulation rim.
    let rimNormalized: Bool
    /// The bundled USDZ that plays this clip, when it ships in the app bundle.
    /// Registry-only clips (processed but not yet bundled) are `nil` and can't
    /// be loaded on device.
    let bundledAsset: FELBundledAsset?
    /// Game modes this clip is approved for.
    let modes: [GameModeId]

    var isBundled: Bool { bundledAsset != nil }
}

nonisolated enum FELMotionLibrary {

    // MARK: - Compiled-in table (bundled clips)

    /// Every motion clip that ships inside the app bundle, keyed to its
    /// ``FELBundledAsset``. This table is the guaranteed floor — it never
    /// depends on a registry.json being present.
    static let bundledClips: [MotionClip] = [
        MotionClip(
            id: FELBundledAsset.elijahDunk.rawValue,
            sourceTake: "ElijahDunkMSDunks_customModel_ucoj55mFKU8zNnT6izbssr.bvh",
            moveType: .dunkOrJumpReach,
            rimNormalized: true,
            bundledAsset: .elijahDunk,
            modes: [.basketballDunkContest3D]
        ),
        MotionClip(
            id: FELBundledAsset.elijahKarateIdle.rawValue,
            sourceTake: FELBundledAsset.elijahKarateIdle.rawValue,
            moveType: .groundMove,
            rimNormalized: false,
            bundledAsset: .elijahKarateIdle,
            modes: [.karate, .karateEndless]
        ),
        MotionClip(
            id: FELBundledAsset.elijahKarateCombo.rawValue,
            sourceTake: FELBundledAsset.elijahKarateCombo.rawValue,
            moveType: .kick,
            rimNormalized: false,
            bundledAsset: .elijahKarateCombo,
            modes: [.karate, .karateEndless]
        ),
        MotionClip(
            id: FELBundledAsset.npcEricNashIdle.rawValue,
            sourceTake: FELBundledAsset.npcEricNashIdle.rawValue,
            moveType: .groundMove,
            rimNormalized: false,
            bundledAsset: .npcEricNashIdle,
            modes: [.karate, .karateEndless]
        ),
        MotionClip(
            id: FELBundledAsset.npcEricNashKarateCombo.rawValue,
            sourceTake: FELBundledAsset.npcEricNashKarateCombo.rawValue,
            moveType: .kick,
            rimNormalized: false,
            bundledAsset: .npcEricNashKarateCombo,
            modes: [.karate, .karateEndless]
        ),
        MotionClip(
            id: FELBundledAsset.npcTallAthleticIdle.rawValue,
            sourceTake: FELBundledAsset.npcTallAthleticIdle.rawValue,
            moveType: .groundMove,
            rimNormalized: false,
            bundledAsset: .npcTallAthleticIdle,
            modes: [.basketballDunkContest3D, .basketballHeadToHead, .venicePickup]
        ),
    ]

    // MARK: - Catalog

    /// Bundled clips plus any processed clips from a bundled pipeline
    /// registry. Computed once; the bundle contents don't change at runtime.
    static let allClips: [MotionClip] = merged(
        bundled: bundledClips,
        registry: registryClips(in: .main)
    )

    /// All clips approved for `mode`, bundled clips first.
    static func clips(for mode: GameModeId) -> [MotionClip] {
        allClips.filter { $0.modes.contains(mode) }
    }

    // MARK: - Optional pipeline registry decode

    /// Decodes `registry.json` if the app bundle carries one. The pipeline
    /// registry normally lives in the repo (`assets/motion/registry.json`),
    /// so absence is the expected case — return the empty floor, never throw.
    static func registryClips(in bundle: Bundle) -> [MotionClip] {
        guard let url = bundle.url(forResource: "registry", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            return []
        }
        return decodeRegistry(data)
    }

    /// Decodes pipeline registry JSON into clips. Fail-soft: malformed JSON
    /// yields `[]`; unknown move types map to ``MotionClip/MoveType/unknown``;
    /// unknown mode ids are dropped per-clip; only `processed` clips (or clips
    /// with no status field) are included.
    static func decodeRegistry(_ data: Data) -> [MotionClip] {
        guard let registry = try? JSONDecoder().decode(RegistryFile.self, from: data) else {
            return []
        }
        return registry.clips.compactMap { entry in
            if let status = entry.status, status != "processed" { return nil }
            return MotionClip(
                id: entry.cropId,
                sourceTake: entry.take,
                moveType: MotionClip.MoveType(registryType: entry.type),
                rimNormalized: entry.rimNormalized ?? false,
                bundledAsset: FELBundledAsset(rawValue: entry.cropId),
                modes: entry.modes.compactMap(GameModeId.init(rawValue:))
            )
        }
    }

    /// Bundled table first, then registry clips whose ids aren't already
    /// covered by a compiled-in entry.
    static func merged(bundled: [MotionClip], registry: [MotionClip]) -> [MotionClip] {
        let bundledIds = Set(bundled.map(\.id))
        return bundled + registry.filter { !bundledIds.contains($0.id) }
    }

    // MARK: - Registry JSON shape (assets/motion/registry.json)

    private struct RegistryFile: Decodable {
        let clips: [RegistryClip]
    }

    private struct RegistryClip: Decodable {
        let cropId: String
        let take: String
        let type: String
        let rimNormalized: Bool?
        let status: String?
        let modes: [String]

        enum CodingKeys: String, CodingKey {
            case cropId = "crop_id"
            case take
            case type
            case rimNormalized = "rim_normalized"
            case status
            case modes
        }
    }
}
