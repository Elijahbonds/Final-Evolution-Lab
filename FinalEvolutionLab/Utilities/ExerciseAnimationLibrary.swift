import Foundation
import SceneKit

/// Resolves an exercise (``Exercise`` or ``TrainingExercise``) to the best
/// AVAILABLE 3D demonstration animation for a skinned demonstrator model.
///
/// # Resolution order
/// For a given exercise `id` + `category`, ``resolve(id:category:)`` returns a
/// ``DemoAnimation`` chosen in this priority order:
///
///  1. **Bundled DeepMotion / exercise clip** — a USDZ in `Resources3D` named by
///     the drop-in convention `ExerciseDemo_<exercise.id>.usdz` (see below).
///     Nothing ships under this name today, so this tier is dormant until Elijah
///     converts his DeepMotion clips — at which point they resolve with ZERO code
///     changes.
///  2. **Free bundled clip** — a per-id override, or a per-category default,
///     mapped onto one of the Elijah skinned clips already in the app bundle
///     (walk / run / dunk / karate / guard / idle). These are real baked mocap.
///  3. **Procedural** — a category-appropriate whole-node + drivable-joint
///     animation applied to the skinned model so EVERY exercise animates even
///     when no matching clip exists.
///
/// # DeepMotion drop-in convention (tier 1)
/// To give a specific exercise a bespoke demo:
///  1. Run the user's DeepMotion clip through
///     `scripts/asset_pipeline/mocap_pipeline.py` → `blender_to_usdz.py`
///     (root locked in place so the demo loops on the spot, real-world 1.85m
///     scale — same contract as the existing pipeline clips).
///  2. Drop the result into `FinalEvolutionLab/Resources3D/` named
///     **`ExerciseDemo_<exercise.id>.usdz`** (e.g. `ExerciseDemo_f2.usdz` for the
///     Box Jumps sample exercise, or `ExerciseDemo_e_d1a_1.usdz` for the Elite
///     "Trap Bar Deadlift" program exercise). Filesystem-synchronized groups pick
///     it up automatically — no `project.pbxproj` edit.
///  3. Done. ``resolve`` finds it by name via ``bundledExerciseClipName`` and
///     prefers it over the free-clip / procedural tiers. No code change.
///
/// Loading is fail-soft everywhere: if a resolved USDZ is missing or corrupt the
/// caller falls back to the next tier and ultimately to the 2D ``AvatarDemoView``.
enum ExerciseAnimationLibrary {

    /// A resolved demonstration animation for one exercise.
    enum DemoAnimation: Equatable {
        /// A bespoke bundled clip resolved by the DeepMotion drop-in convention
        /// (`ExerciseDemo_<id>.usdz`). `resource` is the bundle resource name
        /// (no extension).
        case bundledExerciseClip(resource: String)
        /// A free clip already in the app bundle (Elijah walk/run/dunk/karate…).
        case freeClip(FELBundledAsset)
        /// A category-appropriate procedural animation applied to the skinned
        /// demonstrator node (no matching clip available).
        case procedural(ProceduralMotion)

        /// True when this demo is driven by real baked mocap (tier 1 or 2)
        /// rather than a procedural stand-in.
        var isRealClip: Bool {
            switch self {
            case .bundledExerciseClip, .freeClip: return true
            case .procedural: return false
            }
        }

        /// Short human label for UI / diagnostics.
        var sourceLabel: String {
            switch self {
            case .bundledExerciseClip: return "DeepMotion clip"
            case .freeClip: return "Motion-capture clip"
            case .procedural(let m): return "Procedural (\(m.rawValue))"
            }
        }
    }

    /// Category-appropriate procedural motion styles. Each drives the whole
    /// skinned node plus, where present, named limb joints so a clip-less
    /// demonstrator still reads as performing the movement pattern.
    enum ProceduralMotion: String, Equatable, CaseIterable {
        /// Explosive load → jump → land (plyometric).
        case jump
        /// Deep knee-bend squat cycle (strength).
        case squat
        /// Slow full-range sway / reach (mobility).
        case sway
        /// Quick lateral shuffle bob (agility).
        case shuffle
        /// Gentle breathing idle (recovery).
        case breathe
    }

    // MARK: - Drop-in convention

    /// Resource name (no extension) a bespoke DeepMotion demo for `id` must use.
    /// Bundle it as `<name>.usdz` in `Resources3D` and it auto-resolves.
    static func bundledExerciseClipName(for id: String) -> String {
        "ExerciseDemo_\(id)"
    }

    /// Whether a bespoke DeepMotion clip is bundled for `id`. Injectable
    /// `bundleProbe` keeps this unit-testable without a real app bundle.
    static func hasBundledExerciseClip(
        for id: String,
        bundleProbe: (String) -> Bool = defaultBundleProbe
    ) -> Bool {
        bundleProbe(bundledExerciseClipName(for: id))
    }

    /// Default probe: does `Resources3D` ship `<name>.usdz`?
    static let defaultBundleProbe: (String) -> Bool = { name in
        Bundle.main.url(forResource: name, withExtension: "usdz") != nil
    }

    // MARK: - Free-clip mappings (tier 2)

    /// Per-exercise-id overrides onto a free bundled clip. Only ids whose motion
    /// maps well to a specific bundled clip are listed; everything else falls to
    /// the category default. Covers the 15 SampleData ids + a few program ids
    /// whose names strongly imply a bundled clip (dunk / sprint sessions).
    static let clipOverridesById: [String: FELBundledAsset] = [
        // --- SampleData (ExerciseDemoView) ---
        "e1": .elijahDunk,               // Dunk Sessions
        "e4": .characterElijahRunAnim,   // Neural Drive Sprint
        "f5": .characterElijahRunAnim,   // Lateral Shuffles → run-in-place stand-in
        "fl5": .characterElijahRunAnim,  // Cone Agility Circuit
        "e5": .elijahKarateIdle,         // Recovery Protocol → idle/breathing
        // --- Program ids (TrainingExerciseDetailView) whose name implies a clip ---
        "f_d3c_1": .elijahDunk,          // Dunk Session — Approach Progressions
        "fl_d3c_1": .elijahDunk,         // Dunk Session — Approach + Gather
        "e_d3c_1": .elijahDunk,          // Dunk Session — Full Approach
        "e_d3c_2": .elijahDunk,          // Dunk Contest Simulation
        "e_d1b_4": .characterElijahRunAnim, // Neural Drive Sprint
    ]

    /// Per-category default free clip. `nil` means "no good free clip for this
    /// category — use procedural." Strength & mobility have no bundled analog
    /// (no squat/stretch clip), so they animate procedurally by design.
    static func categoryClip(_ category: Exercise.ExerciseCategory) -> FELBundledAsset? {
        switch category {
        case .plyometric: return .elijahDunk            // jump / reach
        case .agility:    return .characterElijahRunAnim // run in place
        case .recovery:   return .elijahKarateIdle       // grounded idle / breathing
        case .strength:   return nil                     // → procedural squat
        case .mobility:   return nil                     // → procedural sway
        }
    }

    /// Category → procedural fallback (tier 3). Total function: every category
    /// maps to a motion, so resolution never dead-ends.
    static func categoryProcedural(_ category: Exercise.ExerciseCategory) -> ProceduralMotion {
        switch category {
        case .plyometric: return .jump
        case .strength:   return .squat
        case .mobility:   return .sway
        case .agility:    return .shuffle
        case .recovery:   return .breathe
        }
    }

    // MARK: - Resolution

    /// Resolve the best available demo animation for an exercise. Pure and
    /// unit-testable; `bundleProbe` is injectable so tier-1 resolution can be
    /// exercised without a real bundle.
    static func resolve(
        id: String,
        category: Exercise.ExerciseCategory,
        bundleProbe: (String) -> Bool = defaultBundleProbe
    ) -> DemoAnimation {
        // Tier 1: bespoke DeepMotion clip by drop-in convention.
        if hasBundledExerciseClip(for: id, bundleProbe: bundleProbe) {
            return .bundledExerciseClip(resource: bundledExerciseClipName(for: id))
        }
        // Tier 2a: per-id free-clip override.
        if let override = clipOverridesById[id] {
            return .freeClip(override)
        }
        // Tier 2b: per-category free clip.
        if let clip = categoryClip(category) {
            return .freeClip(clip)
        }
        // Tier 3: procedural.
        return .procedural(categoryProcedural(category))
    }

    static func resolve(_ exercise: Exercise, bundleProbe: (String) -> Bool = defaultBundleProbe) -> DemoAnimation {
        resolve(id: exercise.id, category: exercise.category, bundleProbe: bundleProbe)
    }

    static func resolve(_ exercise: TrainingExercise, bundleProbe: (String) -> Bool = defaultBundleProbe) -> DemoAnimation {
        resolve(id: exercise.id, category: exercise.category, bundleProbe: bundleProbe)
    }
}
