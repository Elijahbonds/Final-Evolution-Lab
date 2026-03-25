# iOS play-test readiness (Xcode)

This document states **what is actually in this repository** so your next device test matches expectations.

## Gold Master / TestFlight

- **Checklist:** `GOLD_MASTER_DEPLOYMENT.md` (icons, Shipping/Unreal, Xcode Release flags, `Documents/FEL` + cold-start import).

## Build status

- **Target:** `FinalEvolutionLab` (Swift/SwiftUI, iOS 18+ per project settings).
- **Verification:** `xcodebuild -scheme FinalEvolutionLabUnreal -destination 'generic/platform=iOS' build` should complete with **BUILD SUCCEEDED** after the fixes for `TennisArenaViews.swift` (missing `RadialGradient` parenthesis) and `BaseballArenaViews.swift` (`CGSize` uses `width`/`height`, not `x`/`y`).

## Game modes in the Arena (SwiftUI — operable in this app)

All `GameModeId` cases in `GameModeRegistry.all` are wired into **Arena → venues → mode rows** and launch a playable flow:

| Mode | Solo play | Local Versus (Multipeer) | Notes |
|------|-----------|---------------------------|--------|
| Head to Head / 3v3 | `GenericArenaPlayView` | Same | Venice canvas + contest window for P2 |
| Dunk Contest | `ArenaDunkPlayView` | N/A in shell (solo path in `ArenaGameFlowView`) | 2D phase bars + `DunkContestState`; Lab has separate 3D dunk path |
| Karate | `GenericArenaPlayView` | Same | Block window for P2 |
| Baseball, Football, Tennis, Volleyball, Gymnastics | `GenericArenaPlayView` | Same | Themed backgrounds + canvases |
| Soccer | `PenaltyKickView` | `GenericArenaPlayView` + penalty canvas | Solo = interactive kick UI |
| Golf | `GolfSwingView` | `GenericArenaPlayView` + pin canvas | Solo = swing UI |
| Brain Brawl | `BrainBrawlPlayView` | `GenericArenaPlayView` + duel canvas | Solo = full quiz UI |
| Brain Brawl (Versus) | — | Commit-style rounds + academy visuals | Not the full quiz UI; PRQ-driven commit flow |

**Mechanics (Arena, non–Brain Brawl solo quiz):** Tap or **Cross (✕)** to commit; round outcome is driven by **PRQ / mode reward** logic in `GenericArenaPlayView` (see `PROJECT_FLOWS.md`). This is **not** a full physics simulation per sport—it is an arcade shell with sport-specific presentation.

## PS5 / DualSense controller (iOS)

- The app uses Apple’s **GameController** framework.
- `ControllerDiscoveryService` observes `GCControllerDidConnect` / `DidDisconnect` and sets `hasPhysicalController` / `controllerName` (DualSense is recognized via vendor/product strings).
- **Arena** and **Dunk** hide the on-screen `PS2GamepadOverlay` when a physical controller is present; **Cross** is mapped via `onPhysicalControllerCross` modifiers where implemented.
- You do **not** need Unreal or Unity for the controller to work with these SwiftUI flows.

## Unity (optional embedded game layer)

- `UnityManager` loads **`UnityFramework.framework`** from the app’s **PrivateFrameworks** directory **if you embed a Unity iOS build** there.
- **This repo does not include** Unity C# sources or a built `UnityFramework`. Without that framework, Unity views show a **placeholder** (“Tap to activate the Unity runtime”) and the rest of the app still runs.
- See `FINAL_EVOLUTION_LAB_CONTEXT.md` for the intended Swift ↔ Unity manifest mapping.

## Unreal ↔ Swift bridge (when UE is embedded)

- **Readiness:** Swift writes `Documents/FEL/readiness_snapshot.json` (`PRQManager`); Unreal `FELReadinessIO` resolves that path first on iOS.
- **Session end:** Unreal writes `Documents/FEL/session_results.json`, then posts `FELUnrealSessionResultsReady` (see `FELNativeBridge` + `FELUnrealSessionImporter`).
- **Exit:** `UFELMatchResultsWidget` “Return to Dashboard” posts `FELUnrealExitToDashboard` so the host can tear down the UE view.

## Unreal Engine (not inside this Xcode app)

- **`UnrealStarter/`** holds **reference C++ snippets and docs** for a separate Unreal project workflow (e.g. basketball bridge, readiness types). It is **not** compiled into `FinalEvolutionLabUnreal.app`.
- Running **Unreal** gameplay on iOS requires exporting an Unreal project as an iOS app or library and integrating it **outside** the scope of this Swift-only target. **This repository does not ship a packaged Unreal runtime or full asset pipeline for Xcode.**

If your milestone is “Unreal + all assets + full gameplay on device,” that is a **different deliverable** than this Swift app; plan for an Unreal iOS build, plugins, content cooking, and optional native bridging—not something this repo can complete by editing Swift alone.

## Suggested test checklist (device + DualSense)

1. Build & run **FinalEvolutionLab** on a physical iPhone.
2. Pair **DualSense** (Settings → Bluetooth on iPhone).
3. **Arena:** open each venue mode once (solo); confirm Get Ready → Play → Result.
4. **Local Play:** host/join one mode (e.g. Head to Head) on two devices if available.
5. **Lab:** exercise dunk / RealityKit paths per your usual flow (see `PROJECT_FLOWS.md`).
6. If you embed Unity later: drop `UnityFramework.framework`, rebuild, retest `UnityContainerView`.

---

*Last updated: build fixes for Arena view compile errors; aligns docs with Unity vs Unreal reality.*
