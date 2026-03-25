# Neuro-Mechanic bridge — Swift ↔ Unreal

This repo implements **readiness-gated play** in two layers:

1. **Swift (ship today):** `PRQManager` derives `kineticLeakageMultiplier` and `hangTimeScale` from `SystemScanResult` + `BiomechanicsAudit` (ankle / knee / hip **PRIMED** vs **MODERATE** / **LEAKING**). Arena outcomes already use `effectiveMetrics.prqScore` via `GenericArenaPlayView` and related flows.
2. **Unreal (copy `UnrealStarter/` into your game module):** `FFELReadinessSnapshot` + `FELReadinessIO::TryLoadSnapshot` consume the **same JSON** keys. `UFELNeuroMechanicBridgeSubsystem::ReloadSnapshotFromDiskAndApply` is the **single load path** in `AFELBasketballGameMode::StartPlay`; `FELKineticLeakage` applies leakage + hang scale to jump and sprint caps in `AFELBasketballCharacter::ApplyReadiness`. The GameMode still exposes Blueprint-readonly **Neuro*** doubles after `StartPlay`, sourced from the subsystem cache.

## Neuro-Mechanic philosophy (abstract → concrete)

- **Efficiency = height:** `EfficiencyScore` scales realized vertical impulse after the scan-derived **potential** curve (`FELNeuroMechanicPhysics::EfficiencyHeightScale`).
- **Potential cap:** `verticalEstimateInches` maps to a **Bonds Bounce Blueprint** ceiling (`PotentialJumpZFromVerticalInches`); this is *not* a flat “tap to jump” scalar.
- **Neural drive realizes potential:** `NeuralDriveRealizationFactor` maps 0–100 drive into how much of that ceiling becomes **JumpZVelocity** on the ground.
- **Dynamic kinetic leakage:** Joint scan leakage (`KineticLeakageMultiplier` via `FELKineticLeakage`) stacks with **input-timing leakage** (`ComputeBondsBounceTimingLeakage`) — gather seconds vs an ideal ~280 ms window; **Early/Late** bands drive “Leaky” animation hooks (`LastJumpTimingBand`).
- **Elite apex control (Dunk Contest):** at `neuralDrive >= 90`, mid-air **planar nudges** (`ApplyMidAirNeuralCorrection`) simulate pro-grade body control (not a canned apex).
- **Neuro-Flow:** three **Perfect** timing jumps in a row (Dunk Contest) triggers short **Bloom + vignette + character time dilation** (`UpdateNeuroFlowVisuals`) so the arena reads the athlete’s streak.

## Sport-specific layer (12 Arena modes)

- **Registry:** `FFELArenaRules` embeds `FFELSportNeuroConstants` (kick power, swing window ms, slice multiplier, lateral strain thresholds, Karate/Baseball PRQ window expansion, etc.). Defaults are merged in `FELArenaRulesRegistry::ApplySportNeuroDefaults` per `EFELArenaMode`.
- **Lateral kinetic leakage:** `FELKineticLeakage::ApplyLateralCutWalkMultiplier` penalizes **Tennis / Soccer / Football** when lateral ground velocity exceeds the mode threshold while `neuralDrive` is below `LateralNeuralDriveRequired` (ankle/knee instability vs scan leakage).
- **Neuro-Skill buffer:** `FELNeuroSkill::PerfectHitWindowMsFromPRQ` widens the Baseball/Karate perfect-hit window as **PRQ** rises (`BaseballSwingWindowMs` + PRQ × `BaseballPerfectWindowPRQExpandMs`, same pattern for Karate).
- **Debug HUD metric 3:** `FELNeuroMechanicDisplay::GetSportHudMetric3` labels the third line (e.g. Kick Power, Perfect Window ms, Slice Control).
- **Session export:** `session_results.json` includes **`masteryScore`** and **`masteryMetric`** (Swift `GameSessionResult`) from `FELSportMastery::ComputeMasteryScoreAndMetric`.

## JSON contract (`readiness_snapshot.json`)

| Key | Source (Swift) |
|-----|----------------|
| `active_mode` | `GameModeId.rawValue` (Unreal: `EFELArenaMode` + `ArenaSettings.json` rules) |
| `prqScore`, `efficiencyScore`, `readinessScore`, `verticalPotential`, `neuralDrive`, `popForce`, `currentOutfit` | `PerformanceMetrics` |
| `verticalEstimateInches` | `SystemScanResult.verticalEstimateInches` |
| `hangTimeScale` | PRQ + flight time heuristic in `PRQManager` |
| `kineticLeakageMultiplier` | Joint statuses in `BiomechanicsAudit` |

Swift writes:

- **Documents:** `Documents/FEL/readiness_snapshot.json` (on device; use Files / iTunes File Sharing to copy into Unreal `Saved/FEL/` for desktop playtests).
- **UserDefaults** cache key: `fel_readiness_snapshot_json_cache`.

## PS5 / DualSense (Arena dunk)

When `ControllerDiscoveryService.hasPhysicalController` is true:

- **L2 (left trigger):** sprint hold / release mirrors Cross down/up during approach.
- **R2 (right trigger):** confirms **gather → jump** while phase is `.launch`.
- **Virtual overlay:** still gated off when a physical controller is present (`ArenaDunkPlayView` + `PS2GamepadOverlay`).

## Venue routing

`VenueManager` maps hub shortcuts (e.g. Games → **Venice** / **Dojo**) to `preselectedArenaModeId` and Arena tab selection, and calls `PRQManager.shared.sync` so export stays fresh before Unreal ingest.

## Exercise demonstration (ghost avatar)

Before the first Lab session, **`UFELOnboardingWidget`** can run **`AFELBasketballGameMode::TriggerExerciseDemo`** (“Watch Demo”): **`UFELDemoManager`** spawns a **`AFELExerciseDemonstrator`** ghost using **`FFELSportNeuroConstants::DemonstratorSkeletalMesh`** + **`DemonstratorAnimInstanceClass`** (author **`UFELArenaModeData`** per mode, with registry defaults → `/Game/Models/Avatar/`). **`ApplyDemonstrationPlayRateFromNeuro`** scales **`UAnimInstance::GlobalAnimRateScale`** from **`NeuroPRQScore`** and **`NeuroKineticLeakageMultiplier`**. Optional **Perfect Form** lines come from the Data Asset **`Hud`**. Dismiss blends the camera back to the pawn, then **`StartMatchCountdown`** runs.

**Data + async:** each Swift **`active_mode`** triggers **`FStreamableManager::RequestAsyncLoad`** on **`FELArenaModeCatalog`** soft paths so only that mode’s **`UFELArenaModeData`** and referenced meshes resolve for the session.
