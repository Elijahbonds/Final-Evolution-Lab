import Foundation
import SceneKit
import Testing
@testable import FinalEvolutionLab

/// Mocap pipeline: bundled animation assets (procedural starters now,
/// DeepMotion/Vision-captured dunks later — same format) must decode and
/// target only joints that exist on the capsule rig every mode's avatar uses.
@MainActor
struct AnimationLibraryTests {

    /// Node names created by GameSceneFactory.addPlayerAvatar /
    /// NexusGameplayAvatarLoader + the extended joints CourtSceneView animates.
    private static let rigJoints: Set<String> = [
        "head", "neck", "torso", "hip",
        "lArm", "rArm", "lUpperArm", "rUpperArm",
        "lLeg", "rLeg", "lShin", "rShin", "lKnee", "rKnee",
    ]

    @Test func starterLibraryIsBundledAndIndexed() {
        let ids = NexusAnimationLibrary.availableIds()
        #expect(ids.count >= 6, "expected the 6 starter animations, got \(ids)")
        #expect(ids.contains("starter_dunk_power"))
        #expect(ids.contains("starter_dunk_windmill"))
        #expect(ids.contains("starter_idle_breathe"))
    }

    @Test func everyBundledAssetDecodesAndTargetsRigJoints() throws {
        for id in NexusAnimationLibrary.availableIds() {
            let asset = try #require(NexusAnimationLibrary.asset(id: id),
                                     "asset failed to decode: \(id)")
            #expect(!asset.keyframes.isEmpty, "\(id) has no keyframes")
            #expect(asset.header.duration > 0)
            // Timestamps monotonic — the player interpolates between frames.
            let ts = asset.keyframes.map(\.timestamp)
            #expect(ts == ts.sorted(), "\(id) keyframes out of order")
            // Every animated joint must exist on the rig, or motion is lost.
            let joints = Set(asset.keyframes.flatMap { $0.jointRotations.keys })
            #expect(joints.isSubset(of: Self.rigJoints),
                    "\(id) targets unknown joints: \(joints.subtracting(Self.rigJoints))")
        }
    }

    @Test func dunkCategoryCoversTheContestPhases() {
        let dunks = NexusAnimationLibrary.assets(category: "dunk").map(\.header.id)
        // Charge → slam → land: the phases BasketballDunkGameView sequences.
        #expect(dunks.contains("starter_jump_charge"))
        #expect(dunks.contains("starter_dunk_power"))
        #expect(dunks.contains("starter_land_recover"))
    }

    @Test func hipTranslationCarriesBallisticJumpArc() throws {
        let dunk = try #require(NexusAnimationLibrary.asset(id: "starter_dunk_power"))
        let hipYs = dunk.keyframes.compactMap { $0.translationOffsets["hip"]?.y }
        let apex = hipYs.max() ?? 0
        // 0.62s flight ⇒ h = g·t²/8 ≈ 0.47m — the jump must actually leave the ground.
        #expect(apex > 0.3, "dunk apex \(apex) too low — no real jump arc")
        #expect(abs((hipYs.first ?? -1)) < 0.05, "jump must start grounded")
    }
}
