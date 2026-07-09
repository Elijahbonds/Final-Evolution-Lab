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

    @Test func bundledClipIsScopedToItsOwnModeAndAction() {
        // A bundled golf-swing clip must NOT be used for tennis, or for a golf
        // action other than swing.
        let probe: (String) -> Bool = { $0 == "Action_golf_swing" }
        #expect(SportActionAnimationLibrary.resolve(mode: .tennis, action: "Swing", bundleProbe: probe) == .proceduralArmSwing)
        #expect(SportActionAnimationLibrary.resolve(mode: .golf, action: "Putt", bundleProbe: probe) == .proceduralArmSwing)
    }

    @Test func uncoveredModeAlwaysResolvesProcedural() {
        // Even if a probe would answer true, an uncovered mode has no clip name
        // and must fall through to procedural.
        let alwaysTrue: (String) -> Bool = { _ in true }
        #expect(SportActionAnimationLibrary.resolve(mode: .karate, action: "Punch", bundleProbe: alwaysTrue) == .proceduralArmSwing)
        #expect(SportActionAnimationLibrary.resolve(mode: .brainBrawl, action: "Focus", bundleProbe: alwaysTrue) == .proceduralArmSwing)
    }
}
