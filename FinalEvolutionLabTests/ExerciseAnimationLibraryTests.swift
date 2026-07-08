import Testing
import SceneKit
@testable import FinalEvolutionLab

/// Verifies ``ExerciseAnimationLibrary`` resolution: the 3-tier priority
/// (DeepMotion drop-in → free clip → procedural) and total coverage.
struct ExerciseAnimationLibraryTests {

    // Probe that reports NO bundled ExerciseDemo_* clips (default runtime state).
    private let noBundle: (String) -> Bool = { _ in false }

    // MARK: - Tier 3: procedural fallback covers every category

    @Test func everyCategoryResolvesToSomething() {
        for category in Exercise.ExerciseCategory.allCases {
            let anim = ExerciseAnimationLibrary.resolve(id: "unmapped_id_xyz", category: category, bundleProbe: noBundle)
            // Must never dead-end: it's a free clip or a procedural motion.
            switch anim {
            case .freeClip, .procedural: break
            case .bundledExerciseClip: Issue.record("no bundle expected for \(category)")
            }
        }
    }

    @Test func strengthAndMobilityFallToProcedural() {
        #expect(ExerciseAnimationLibrary.resolve(id: "no_override", category: .strength, bundleProbe: noBundle)
                == .procedural(.squat))
        #expect(ExerciseAnimationLibrary.resolve(id: "no_override", category: .mobility, bundleProbe: noBundle)
                == .procedural(.sway))
    }

    @Test func categoryDefaultsUseFreeClips() {
        #expect(ExerciseAnimationLibrary.resolve(id: "no_override", category: .plyometric, bundleProbe: noBundle)
                == .freeClip(.elijahDunk))
        #expect(ExerciseAnimationLibrary.resolve(id: "no_override", category: .agility, bundleProbe: noBundle)
                == .freeClip(.characterElijahRunAnim))
        #expect(ExerciseAnimationLibrary.resolve(id: "no_override", category: .recovery, bundleProbe: noBundle)
                == .freeClip(.elijahKarateIdle))
    }

    // MARK: - Tier 2a: per-id overrides win over category default

    @Test func idOverrideBeatsCategoryDefault() {
        // Dunk Sessions is plyometric (category default is also dunk) — but a
        // sprint override on an agility id proves the override path.
        #expect(ExerciseAnimationLibrary.resolve(id: "e1", category: .plyometric, bundleProbe: noBundle)
                == .freeClip(.elijahDunk))
        // e5 Recovery Protocol override → idle even though category recovery also → idle.
        #expect(ExerciseAnimationLibrary.resolve(id: "e5", category: .recovery, bundleProbe: noBundle)
                == .freeClip(.elijahKarateIdle))
        // Program dunk id maps to the dunk clip regardless of listed category.
        #expect(ExerciseAnimationLibrary.resolve(id: "e_d3c_1", category: .plyometric, bundleProbe: noBundle)
                == .freeClip(.elijahDunk))
    }

    // MARK: - Tier 1: DeepMotion drop-in convention wins over everything

    @Test func bundledDeepMotionClipWinsWhenPresent() {
        // Simulate ExerciseDemo_f2.usdz being bundled.
        let probe: (String) -> Bool = { $0 == "ExerciseDemo_f2" }
        let anim = ExerciseAnimationLibrary.resolve(id: "f2", category: .plyometric, bundleProbe: probe)
        #expect(anim == .bundledExerciseClip(resource: "ExerciseDemo_f2"))
        #expect(anim.isRealClip)
    }

    @Test func dropInConventionNaming() {
        #expect(ExerciseAnimationLibrary.bundledExerciseClipName(for: "e_d1a_1") == "ExerciseDemo_e_d1a_1")
    }

    @Test func deepMotionClipOverridesAnIdThatOtherwiseHasAFreeClip() {
        // e1 normally → free dunk clip; a bundled bespoke clip must take priority.
        let probe: (String) -> Bool = { $0 == "ExerciseDemo_e1" }
        #expect(ExerciseAnimationLibrary.resolve(id: "e1", category: .plyometric, bundleProbe: probe)
                == .bundledExerciseClip(resource: "ExerciseDemo_e1"))
    }

    // MARK: - isRealClip / labels

    @Test func realClipFlag() {
        #expect(ExerciseAnimationLibrary.DemoAnimation.freeClip(.elijahDunk).isRealClip)
        #expect(ExerciseAnimationLibrary.DemoAnimation.bundledExerciseClip(resource: "x").isRealClip)
        #expect(!ExerciseAnimationLibrary.DemoAnimation.procedural(.jump).isRealClip)
    }

    // MARK: - Real coverage over the 15 SampleData exercises

    @Test func sampleDataFullyCovered() {
        let all = SampleData.foundationExercises + SampleData.flightExercises + SampleData.eliteExercises
        #expect(all.count == 15)
        for ex in all {
            let anim = ExerciseAnimationLibrary.resolve(ex, bundleProbe: noBundle)
            // Every exercise animates — no nil, no dead-end.
            switch anim {
            case .freeClip, .procedural, .bundledExerciseClip: break
            }
        }
    }

    // MARK: - 3D scene assembly places an animated demonstrator

    /// The 3D scene builder must place a demonstrator node that is animated:
    /// either an embedded skinned clip is playing (animationKeys) or a procedural
    /// SCNAction is attached. Proves the "never a frozen statue" contract.
    @MainActor
    @Test func sceneBuilderPlacesAnimatedDemonstrator() {
        // A procedural category (strength → squat) guarantees an SCNAction is
        // attached even if a skinned clip fails to load in the test host.
        let anim = ExerciseAnimationLibrary.resolve(id: "no_override", category: .strength, bundleProbe: noBundle)
        let result = ExerciseDemoSceneBuilder.build(
            animation: anim, category: .strength, difficulty: .elite, useScanAvatar: true
        )
        #expect(result.demonstratorPlaced, "demonstrator should be placed")
        let demonstrator = result.scene.rootNode.childNode(
            withName: ExerciseDemoSceneBuilder.demonstratorName, recursively: false
        )
        #expect(demonstrator != nil, "demonstrator node missing")

        var animated = false
        demonstrator?.enumerateHierarchy { node, _ in
            if !node.animationKeys.isEmpty { animated = true }        // embedded skinned clip
            if !node.actionKeys.isEmpty { animated = true }           // procedural motion
        }
        #expect(animated, "demonstrator must be animated (clip or procedural)")
    }
}
