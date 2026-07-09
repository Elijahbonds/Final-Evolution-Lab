import Foundation
import SceneKit

/// Resolves a per-sport gameplay ACTION (golf swing, tennis serve, baseball
/// swing, soccer kick/save, volleyball spike, …) to the best AVAILABLE full-body
/// animation, and provides the drop-in seam for the user's future DeepMotion
/// captures — the sports analog of ``ExerciseAnimationLibrary``.
///
/// # Why this exists
/// Today the per-sport action trigger (``GameSceneHostView`` `triggerAvatarAction`)
/// plays an **arm-only** procedural `rArm` swing on the player node. That reads as
/// a stand-in, not a real swing/serve/spike. This registry lets a bundled baked
/// clip take over the instant one is dropped in — with ZERO code change.
///
/// # DeepMotion drop-in convention
/// To upgrade a sport action to a real full-body animation:
///  1. Capture the motion in DeepMotion (e.g. a golf swing on the Elijah rig),
///     run it through `scripts/asset_pipeline/mocap_pipeline.py` →
///     `blender_to_usdz.py` (root locked in place, real-world 1.85m scale — the
///     same contract as the existing pipeline clips like DribbleLoop / ElijahDunk).
///  2. Drop the result into `FinalEvolutionLab/Resources3D/` named
///     **`Action_<mode>_<action>.usdz`** where `<mode>` is the ``GameModeId``
///     raw value's sport family and `<action>` is the lowercased action name.
///     Canonical examples (the ones the current triggers already ask for):
///       - `Action_golf_swing.usdz`
///       - `Action_tennis_serve.usdz`
///       - `Action_tennis_rally.usdz`
///       - `Action_baseball_swing.usdz`
///       - `Action_soccer_kick.usdz`
///       - `Action_soccer_save.usdz`
///       - `Action_volleyball_spike.usdz`
///     Filesystem-synchronized groups pick the file up automatically — no
///     `project.pbxproj` edit.
///  3. Done. ``resolve(mode:action:)`` finds it by name via
///     ``bundledActionClipName(mode:action:)`` and prefers it over the arm-only
///     procedural fallback. No code change — dropping `Action_golf_swing.usdz`
///     into Resources3D upgrades golf to a real full-body swing.
///
/// Loading is fail-soft everywhere: if the resolved USDZ is missing or corrupt,
/// the caller falls back to the existing procedural arm-swing.
enum SportActionAnimationLibrary {

    /// A resolved animation for one (mode, action) request.
    enum ActionAnimation: Equatable {
        /// A bundled full-body baked clip resolved by the drop-in convention
        /// (`Action_<mode>_<action>.usdz`). `resource` is the bundle resource
        /// name (no extension).
        case bundledClip(resource: String)
        /// The existing procedural arm-only swing (no matching clip available).
        case proceduralArmSwing

        /// True when a real baked full-body clip drives this action.
        var isRealClip: Bool {
            switch self {
            case .bundledClip: return true
            case .proceduralArmSwing: return false
            }
        }

        /// Short human label for UI / diagnostics.
        var sourceLabel: String {
            switch self {
            case .bundledClip: return "DeepMotion clip"
            case .proceduralArmSwing: return "Procedural arm swing"
            }
        }
    }

    /// The sport families whose action trigger consults this registry, keyed by
    /// the `<mode>` token used in the drop-in filename. Kept explicit (rather
    /// than derived from every GameModeId) so the convention is documented and
    /// the resolver only probes the bundle for modes that can actually be
    /// upgraded — no wasted lookups for basketball/karate (which have their own
    /// baked-clip systems) or the non-physical minigames.
    static func modeToken(for mode: GameModeId) -> String? {
        switch mode {
        case .golf:         return "golf"
        case .tennis:       return "tennis"
        case .baseball:     return "baseball"
        case .soccer:       return "soccer"
        case .volleyball:   return "volleyball"
        case .football:     return "football"
        // Board / precision rhythm modes: registered so the per-action trigger
        // consults the registry and — until a bundled Action_<mode>_<action>.usdz
        // ships — fires the procedural full-body pulse/arm-swing on the avatar.
        // Without this, landing a trick left the avatar in idle (the "idle-only"
        // complaint). Real ollie/aerial/tumble/carve clips drop in by convention.
        case .skateboarding: return "skateboarding"
        case .snowboarding:  return "snowboarding"
        case .surfing:       return "surfing"
        case .gymnastics:    return "gymnastics"
        default:            return nil
        }
    }

    /// Normalizes a UI action label ("Swing", "Serve", "Spike", "Break Away") to
    /// the `<action>` token used in the drop-in filename (lowercased, spaces →
    /// underscores). e.g. "Break Away" → "break_away".
    static func actionToken(for action: String) -> String {
        action
            .lowercased()
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: " ", with: "_")
    }

    // MARK: - Drop-in convention

    /// Resource name (no extension) a bundled full-body clip for `(mode, action)`
    /// must use. Bundle it as `<name>.usdz` in `Resources3D` and it auto-resolves.
    /// Returns nil for modes not covered by this registry (basketball/karate/
    /// minigames), which never consult it.
    static func bundledActionClipName(mode: GameModeId, action: String) -> String? {
        guard let modeTok = modeToken(for: mode) else { return nil }
        return "Action_\(modeTok)_\(actionToken(for: action))"
    }

    /// Explicit (mode, action) → shipped mocap clip resource, for actions whose
    /// UI label doesn't equal the capture's token. Consulted BEFORE the generic
    /// `Action_<mode>_<action>` convention so EVERY gameplay action a mode fires
    /// resolves to a real DeepMotion clip: tennis Volley/Baseline reuse the serve
    /// capture, football "Break Away" plays the scramble capture, and each
    /// extreme-mode trick name maps to that board's single ride/trick capture.
    /// Returns nil to fall through to the generic convention (which already
    /// catches golf "Swing", tennis "Serve", volleyball "Spike", baseball
    /// "Swing", football "Catch").
    static func bundledActionOverride(mode: GameModeId, action: String) -> String? {
        let tok = actionToken(for: action)
        switch mode {
        case .golf:
            return "Action_golf_swing"
        case .tennis:
            return "Action_tennis_serve"
        case .volleyball:
            return "Action_volleyball_spike"
        case .baseball:
            switch tok {
            case "pitch": return "Action_baseball_pitch"
            case "field", "throw": return "Action_baseball_field"
            default: return "Action_baseball_swing"   // swing / bunt
            }
        case .football:
            switch tok {
            case "catch": return "Action_football_catch"
            case "throw", "pass": return "Action_football_throw"
            case "juke": return "Action_football_juke"
            default: return "Action_football_scramble" // "Break Away" / run
            }
        case .surfing:
            return "Action_surfing_ride"
        case .skateboarding:
            return "Action_skateboarding_trick"
        case .snowboarding:
            return "Action_snowboarding_trick"
        default:
            return nil
        }
    }

    /// Whether a bundled full-body clip is present for `(mode, action)`.
    /// Injectable `bundleProbe` keeps this unit-testable without a real bundle.
    static func hasBundledActionClip(
        mode: GameModeId,
        action: String,
        bundleProbe: (String) -> Bool = defaultBundleProbe
    ) -> Bool {
        guard let name = bundledActionClipName(mode: mode, action: action) else { return false }
        return bundleProbe(name)
    }

    /// Default probe: does `Resources3D` ship `<name>.usdz`?
    static let defaultBundleProbe: (String) -> Bool = { name in
        Bundle.main.url(forResource: name, withExtension: "usdz") != nil
    }

    // MARK: - Resolution

    /// Resolve the best available animation for a sport action. Pure and
    /// unit-testable; `bundleProbe` is injectable so tier-1 resolution can be
    /// exercised without a real bundle.
    ///
    /// Resolution order:
    ///  1. **Explicit override clip** — `bundledActionOverride`, for the shipped
    ///     mocap captures whose action token differs from the UI label.
    ///  2. **Bundled full-body clip** — `Action_<mode>_<action>.usdz` if present.
    ///  3. **Procedural arm swing** — the existing arm-only fallback (always
    ///     available, so resolution never dead-ends).
    static func resolve(
        mode: GameModeId,
        action: String,
        bundleProbe: (String) -> Bool = defaultBundleProbe
    ) -> ActionAnimation {
        if let override = bundledActionOverride(mode: mode, action: action),
           bundleProbe(override) {
            return .bundledClip(resource: override)
        }
        if let name = bundledActionClipName(mode: mode, action: action),
           bundleProbe(name) {
            return .bundledClip(resource: name)
        }
        return .proceduralArmSwing
    }
}
