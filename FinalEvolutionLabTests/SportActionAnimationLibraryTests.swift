import Testing
@testable import FinalEvolutionLab

/// Unit tests for the per-sport action drop-in seam
/// (``SportActionAnimationLibrary``). Uses an injected `bundleProbe` so tier-1
/// (bundled full-body clip) resolution is exercised without a real app bundle.
struct SportActionAnimationLibraryTests {

    // MARK: - Filename / token convention

    @Test func modeTokenCoversPhysicalSportsOnly() {
        #expect(SportActionAnimationLibrary.modeToken(for: .golf) == "golf")
        #expect(SportActionAnimationLibrary.modeToken(for: .tennis) == "tennis")
        #expect(SportActionAnimationLibrary.modeToken(for: .baseball) == "baseball")
        #expect(SportActionAnimationLibrary.modeToken(for: .soccer) == "soccer")
        #expect(SportActionAnimationLibrary.modeToken(for: .volleyball) == "volleyball")
        #expect(SportActionAnimationLibrary.modeToken(for: .football) == "football")
        // Board / precision rhythm modes: registered so the per-action trigger
        // fires the procedural pulse until real clips ship (fixes idle-only).
        #expect(SportActionAnimationLibrary.modeToken(for: .skateboarding) == "skateboarding")
        #expect(SportActionAnimationLibrary.modeToken(for: .snowboarding) == "snowboarding")
        #expect(SportActionAnimationLibrary.modeToken(for: .surfing) == "surfing")
        #expect(SportActionAnimationLibrary.modeToken(for: .gymnastics) == "gymnastics")
        // Modes with their own baked-clip systems / no physical action: nil.
        #expect(SportActionAnimationLibrary.modeToken(for: .basketballHeadToHead) == nil)
        #expect(SportActionAnimationLibrary.modeToken(for: .karate) == nil)
        #expect(SportActionAnimationLibrary.modeToken(for: .brainBrawl) == nil)
    }

    @Test func actionTokenNormalizesLabel() {
        #expect(SportActionAnimationLibrary.actionToken(for: "Swing") == "swing")
        #expect(SportActionAnimationLibrary.actionToken(for: "Serve") == "serve")
        #expect(SportActionAnimationLibrary.actionToken(for: "Break Away") == "break_away")
        #expect(SportActionAnimationLibrary.actionToken(for: "  Spike  ") == "spike")
    }

    @Test func bundledClipNameFollowsConvention() {
        #expect(SportActionAnimationLibrary.bundledActionClipName(mode: .golf, action: "Swing") == "Action_golf_swing")
        #expect(SportActionAnimationLibrary.bundledActionClipName(mode: .tennis, action: "Serve") == "Action_tennis_serve")
        #expect(SportActionAnimationLibrary.bundledActionClipName(mode: .baseball, action: "Swing") == "Action_baseball_swing")
        #expect(SportActionAnimationLibrary.bundledActionClipName(mode: .soccer, action: "Save") == "Action_soccer_save")
        #expect(SportActionAnimationLibrary.bundledActionClipName(mode: .volleyball, action: "Spike") == "Action_volleyball_spike")
        // Uncovered mode → nil (never probes the bundle).
        #expect(SportActionAnimationLibrary.bundledActionClipName(mode: .karate, action: "Punch") == nil)
    }

    // MARK: - Resolution order

    @Test func resolvesProceduralWhenNoClipBundled() {
        // Nothing ships under the Action_ convention today.
        let noProbe: (String) -> Bool = { _ in false }
        let r = SportActionAnimationLibrary.resolve(mode: .golf, action: "Swing", bundleProbe: noProbe)
        #expect(r == .proceduralArmSwing)
        #expect(!r.isRealClip)
    }

    @Test func prefersBundledClipWhenPresent() {
        // Simulate a dropped-in Action_golf_swing.usdz.
        let probe: (String) -> Bool = { $0 == "Action_golf_swing" }
        let r = SportActionAnimationLibrary.resolve(mode: .golf, action: "Swing", bundleProbe: probe)
        #expect(r == .bundledClip(resource: "Action_golf_swing"))
        #expect(r.isRealClip)
    }

    @Test func bundledClipIsScopedToItsOwnMode() {
        // A bundled golf-swing clip must NOT be used for tennis (cross-mode
        // scoping still holds). Within golf, the single swing capture is
        // intentionally reused for every golf action (see override), so we only
        // assert the cross-mode boundary here.
        let probe: (String) -> Bool = { $0 == "Action_golf_swing" }
        #expect(SportActionAnimationLibrary.resolve(mode: .tennis, action: "Swing", bundleProbe: probe) == .proceduralArmSwing)
    }

    // MARK: - Shipped mocap override coverage (13 real DeepMotion clips)

    @Test func overrideMapsEveryModeActionToAShippedClip() {
        // Every action a mode actually fires must resolve to one of the 13
        // bundled Action_*.usdz captures. Probe answers true only for those.
        let shipped: Set<String> = [
            "Action_baseball_swing", "Action_baseball_pitch", "Action_baseball_field",
            "Action_football_throw", "Action_football_catch", "Action_football_juke",
            "Action_football_scramble", "Action_golf_swing", "Action_tennis_serve",
            "Action_volleyball_spike", "Action_surfing_ride",
            "Action_skateboarding_trick", "Action_snowboarding_trick",
        ]
        let probe: (String) -> Bool = { shipped.contains($0) }
        let cases: [(GameModeId, [String])] = [
            (.golf, ["Swing"]),
            (.tennis, ["Serve", "Volley", "Baseline"]),
            (.volleyball, ["Spike"]),
            (.baseball, ["Swing", "Bunt"]),
            (.football, ["Catch", "Break Away"]),
            (.surfing, ["Snap", "Carve", "Aerial", "Ollie"]),
            (.skateboarding, ["Ollie", "Grind", "Kickflip"]),
            (.snowboarding, ["Carve", "Jump", "Butter"]),
        ]
        for (mode, actions) in cases {
            for action in actions {
                let r = SportActionAnimationLibrary.resolve(mode: mode, action: action, bundleProbe: probe)
                #expect(r.isRealClip, "\(mode.rawValue) '\(action)' should resolve to a shipped clip, got \(r)")
                if case let .bundledClip(resource) = r {
                    #expect(shipped.contains(resource), "\(mode.rawValue) '\(action)' → unshipped \(resource)")
                    // Every resolved resource must have a matching FELBundledAsset
                    // case so playSportAction can load it.
                    #expect(FELBundledAsset(rawValue: resource) != nil, "no FELBundledAsset for \(resource)")
                }
            }
        }
    }

    @Test func footballBreakAwayMapsToScrambleCapture() {
        let probe: (String) -> Bool = { _ in true }
        #expect(SportActionAnimationLibrary.resolve(mode: .football, action: "Break Away", bundleProbe: probe) == .bundledClip(resource: "Action_football_scramble"))
    }

    @Test func tennisNonServeActionsReuseServeCapture() {
        let probe: (String) -> Bool = { _ in true }
        #expect(SportActionAnimationLibrary.resolve(mode: .tennis, action: "Volley", bundleProbe: probe) == .bundledClip(resource: "Action_tennis_serve"))
        #expect(SportActionAnimationLibrary.resolve(mode: .tennis, action: "Baseline", bundleProbe: probe) == .bundledClip(resource: "Action_tennis_serve"))
    }

    @Test func uncoveredModeAlwaysResolvesProcedural() {
        // Even if a probe would answer true, an uncovered mode has no clip name
        // and must fall through to procedural.
        let alwaysTrue: (String) -> Bool = { _ in true }
        #expect(SportActionAnimationLibrary.resolve(mode: .karate, action: "Punch", bundleProbe: alwaysTrue) == .proceduralArmSwing)
        #expect(SportActionAnimationLibrary.resolve(mode: .brainBrawl, action: "Focus", bundleProbe: alwaysTrue) == .proceduralArmSwing)
    }
}
