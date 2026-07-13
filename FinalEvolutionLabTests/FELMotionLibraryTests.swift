import Foundation
import Testing
@testable import FinalEvolutionLab

struct FELMotionLibraryTests {

    /// Mirrors assets/motion/registry.json shape, plus edge cases the decoder
    /// must survive: an unknown type, an unknown mode id, and a pending clip.
    private static let sampleRegistryJSON = """
    {
      "clips": [
        {
          "crop_id": "ElijahDunkMSDunks_custom_01",
          "take": "ElijahDunkMSDunks_customModel_ucoj55mFKU8zNnT6izbssr.bvh",
          "raw_path": "/Users/elijahbonds/Downloads/ElijahDunkMSDunks_customModel_ucoj55mFKU8zNnT6izbssr.bvh",
          "type": "dunk_or_jump_reach",
          "rim_normalized": true,
          "clip_path": "assets/motion/clips/ElijahDunkMSDunks_custom_01.usdz",
          "status": "processed",
          "modes": ["basketball_dunk_3d"]
        },
        {
          "crop_id": "ElijahDunkMSDunks_custom_03",
          "take": "ElijahDunkMSDunks_customModel_ucoj55mFKU8zNnT6izbssr.bvh",
          "type": "kick",
          "rim_normalized": false,
          "clip_path": "assets/motion/clips/ElijahDunkMSDunks_custom_03.usdz",
          "status": "processed",
          "modes": ["karate_h2h", "karate_endless"]
        },
        {
          "crop_id": "ElijahJump_custom_09",
          "take": "ElijahJumpTake.bvh",
          "type": "jump",
          "rim_normalized": false,
          "status": "processed",
          "modes": ["basketball_dunk_3d", "not_a_real_mode"]
        },
        {
          "crop_id": "ElijahShuffle_custom_10",
          "take": "ElijahShuffleTake.bvh",
          "type": "ground_move",
          "rim_normalized": false,
          "status": "processed",
          "modes": ["basketball_h2h"]
        },
        {
          "crop_id": "ElijahMystery_custom_11",
          "take": "ElijahMysteryTake.bvh",
          "type": "backflip_experimental",
          "rim_normalized": false,
          "status": "processed",
          "modes": ["karate_endless"]
        },
        {
          "crop_id": "ElijahPending_custom_12",
          "take": "ElijahPendingTake.bvh",
          "type": "kick",
          "rim_normalized": false,
          "status": "pending",
          "modes": ["karate_h2h"]
        }
      ]
    }
    """

    private func decodedSample() -> [MotionClip] {
        FELMotionLibrary.decodeRegistry(Data(Self.sampleRegistryJSON.utf8))
    }

    // MARK: - Registry decoding

    @Test func registryDecodeSkipsUnprocessedClips() {
        let clips = decodedSample()
        #expect(clips.count == 5, "expected 5 processed clips, got \(clips.count)")
        #expect(!clips.contains { $0.id == "ElijahPending_custom_12" }, "pending clip must be excluded")
    }

    @Test func registryDecodeParsesMoveTypes() throws {
        let clips = decodedSample()
        let byId = Dictionary(uniqueKeysWithValues: clips.map { ($0.id, $0) })

        #expect(byId["ElijahDunkMSDunks_custom_01"]?.moveType == .dunkOrJumpReach)
        #expect(byId["ElijahDunkMSDunks_custom_03"]?.moveType == .kick)
        #expect(byId["ElijahJump_custom_09"]?.moveType == .jump)
        #expect(byId["ElijahShuffle_custom_10"]?.moveType == .groundMove)
        // Unrecognized pipeline types degrade to .unknown, never drop the clip.
        #expect(byId["ElijahMystery_custom_11"]?.moveType == .unknown)
    }

    @Test func registryDecodeMapsModesAndProvenance() throws {
        let clips = decodedSample()
        let byId = Dictionary(uniqueKeysWithValues: clips.map { ($0.id, $0) })

        let dunk = try #require(byId["ElijahDunkMSDunks_custom_01"])
        #expect(dunk.modes == [.basketballDunkContest3D])
        #expect(dunk.rimNormalized)
        #expect(dunk.sourceTake == "ElijahDunkMSDunks_customModel_ucoj55mFKU8zNnT6izbssr.bvh")
        #expect(dunk.bundledAsset == nil, "registry crop ids are not bundled asset names")

        let kick = try #require(byId["ElijahDunkMSDunks_custom_03"])
        #expect(kick.modes == [.karate, .karateEndless])
        #expect(!kick.rimNormalized)

        // Unknown mode ids are dropped per-clip; known ones survive.
        let jump = try #require(byId["ElijahJump_custom_09"])
        #expect(jump.modes == [.basketballDunkContest3D])
    }

    @Test func registryDecodeFailsSoftOnGarbage() {
        #expect(FELMotionLibrary.decodeRegistry(Data("not json".utf8)).isEmpty)
        #expect(FELMotionLibrary.decodeRegistry(Data("{\"clips\": 7}".utf8)).isEmpty)
    }

    // MARK: - Compiled catalog

    @Test func karateModesGetBundledKarateClips() {
        for mode in [GameModeId.karate, .karateEndless] {
            let clips = FELMotionLibrary.clips(for: mode)
            let assets = Set(clips.compactMap(\.bundledAsset))
            #expect(assets.contains(.elijahKarateIdle), "\(mode.rawValue) missing karate idle")
            #expect(assets.contains(.elijahKarateCombo), "\(mode.rawValue) missing karate combo")
            #expect(assets.contains(.npcEricNashKarateCombo), "\(mode.rawValue) missing NPC combo")
        }
    }

    @Test func dunkModeGetsBundledDunkClip() {
        let clips = FELMotionLibrary.clips(for: .basketballDunkContest3D)
        let dunks = clips.filter { $0.moveType == .dunkOrJumpReach }
        #expect(dunks.contains { $0.bundledAsset == .elijahDunk }, "dunk mode missing bundled ElijahDunk")
        #expect(dunks.allSatisfy { $0.rimNormalized }, "all dunk-reach clips must be rim-normalized")
    }

    @Test func bundledTableIsConsistent() {
        let ids = FELMotionLibrary.bundledClips.map(\.id)
        #expect(Set(ids).count == ids.count, "duplicate clip ids in compiled table")
        for clip in FELMotionLibrary.bundledClips {
            #expect(clip.bundledAsset != nil, "\(clip.id): compiled table entries must be bundled")
            #expect(clip.bundledAsset?.isPipelineClip != false, "\(clip.id): bundled motion clips should be pipeline clips")
            #expect(!clip.modes.isEmpty, "\(clip.id): clip mapped to no modes")
        }
    }

    @Test func mergePrefersCompiledTableOverRegistry() {
        let shadow = MotionClip(
            id: FELBundledAsset.elijahDunk.rawValue,
            sourceTake: "shadow.bvh",
            moveType: .unknown,
            rimNormalized: false,
            bundledAsset: nil,
            modes: [.karate]
        )
        let extra = MotionClip(
            id: "RegistryOnly_01",
            sourceTake: "extra.bvh",
            moveType: .jump,
            rimNormalized: false,
            bundledAsset: nil,
            modes: [.basketballDunkContest3D]
        )
        let merged = FELMotionLibrary.merged(bundled: FELMotionLibrary.bundledClips, registry: [shadow, extra])
        #expect(merged.count == FELMotionLibrary.bundledClips.count + 1)
        let dunk = merged.first { $0.id == FELBundledAsset.elijahDunk.rawValue }
        #expect(dunk?.bundledAsset == .elijahDunk, "compiled entry must win over registry shadow")
        #expect(merged.contains { $0.id == "RegistryOnly_01" })
    }
}
