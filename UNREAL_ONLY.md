# Final Evolution Lab — Unreal-Only Architecture

**Canonical direction:** The **Unreal Engine project** is the single **runtime**, **UI shell**, and **shipping client** for Final Evolution Lab. **iOS and console are both first-class products** — same Unreal game, packaged per platform (with tuning for mobile vs. console). Swift/SwiftUI under `FinalEvolutionLab/` is an **older prototype shell**, not the intended ship path for the App Store build.

This document is the **source of truth** for agents and humans: **new features ship in Unreal** (C++ / Blueprint / UMG / Media).

---

## Why Unreal-only

| Concern | Unreal |
|--------|--------|
| Arena, physics, character, Venice/Luma | Native |
| Film review, dual video, telestrator | **Media Framework** + UMG / HUD + render targets |
| Live/VOD instruction | **Media Player** (HLS/DASH URLs) + UI; backend unchanged |
| iOS / desktop / console | **Single codebase** via UE packaging (same gameplay, per-platform tuning) |

Swift is **not** required for gameplay, film vault, or streaming UI when those live in-engine.

---

## Repository layout (mental model)

| Path | Role |
|------|------|
| **`UnrealStarter/BasketballGame/FinalEvolutionLab.uproject`** | **Canonical in-repo Unreal project.** Module: `Source/FinalEvolutionLab/` (all FEL C++), `Config/` defaults merged from `CONFIG_*` snippets, `Content/` for maps & assets. Open this in UE 5.7, **Generate Xcode Project** (Mac) or **Refresh Visual Studio** / Rider, then build **FinalEvolutionLabEditor**. |
| **`UnrealStarter/`** (other) | Editor Python (`EditorPython/`), packaging (`scripts/package_fel_mac.sh`), **Phase 9 compile matrix** (`scripts/verify_fel_build_matrix.sh` — Editor + Mac game UBT; optional iOS via `check_fel_ios_engine.sh`, skippable with `VERIFY_FEL_SKIP_IOS=1`), **Phase 10 engineering sign-off** (`scripts/verify_fel_phase10_signoff.sh` — static file + symbol checks for Phases 1–9; add `--compile` on macOS to chain the matrix), import docs (`IMPORT_CHECKLIST.md`, `FEL_UE52_LevelSetup.md`). **Go-live** (DMG + Netlify) is separate — see `Content/FEL/Venues/GOLD_MASTER_MAC_PACKAGING.txt` Phase 10 and repo-root `scripts/verify_gold_master_distribution.sh`. |
| **`FinalEvolutionLab/`** (Xcode tree at repo root) | **Legacy iOS shell** — not the shipping gameplay client; see **Swift codebase status** below. |
| **Root markdown** (`PITCH_DECK.md`, `VISION_ALIGNMENT.md`, etc.) | Product + planning; implementation lands in **Unreal**. |

### End-to-end integration (designed system)

1. **Gameplay & shell:** One UE client — Arena (`FELBasketballGameMode`, modes catalog, HUD), readiness (`FELReadinessIO`, `UFELNeuroMechanicBridgeSubsystem`), Academy subsystems, session export — all in `Source/FinalEvolutionLab/`. **Arena modes** are canonical in `EFELArenaMode` + `FELArenaModeIds`; use `FELArenaModeFromIdString` / `FELArenaModeToIdString` for JSON (`active_mode`) and `ArenaSettings.json` — not a secondary stack’s naming.  
2. **External readiness (optional):** Any host or pipeline may write `readiness_snapshot.json`; Unreal reads via existing I/O (see `PHASE3_UNREAL_MERGE_AND_BRIDGE.md`, `NEURO_MECHANIC_BRIDGE.md`). Legacy Swift-only Arena UI is not the ship path.  
3. **Ship:** Mac Development / iOS packaging from Unreal (`PACKAGE_AND_TEST.md`, `RUN_UNREAL_ON_IPHONE_XCODE.md`); **not** a Swift-only Xcode app for core Arena simulation.

---

## Feature migration map (conceptual)

| Former idea (multi-stack) | Unreal implementation |
|---------------------------|------------------------|
| Film Vault dual player | Two `MediaPlayer` / `MediaTexture` or twin `FileMediaSource` players; **UMG** for layout; sync via shared timeline or replicated seek |
| Vector / joint overlays | **Canvas**-style: `UUserWidget` custom paint, **Slate** `OnPaint`, or material on quad over video |
| Analyst checkpoints JSON | `FJsonObject` / `UDataTable` / `UDataAsset` rows; load from `Content/` or HTTP |
| Instructor stream | `StreamMediaSource` or URL in `MediaPlayer`; WebSocket plugin or HTTP for `REP_GOAL`-style signals |
| XP / progress | `UGameInstanceSubsystem` or **SaveGame** + your backend; same design as any UE title |
| Readiness / PRQ bridge | Already sketched in `BasketballGame/` (e.g. readiness I/O) — extend in C++ |

---

## Phased work (recommended)

1. **Lock the UE project** — Use **`UnrealStarter/BasketballGame/FinalEvolutionLab.uproject`** (in-repo). Generate IDE project files from the `.uproject`, compile **FinalEvolutionLabEditor**, run `EditorPython/fel_quick_playtest_level.py` for `L_FEL_Playtest`, then PIE.
2. **One vertical slice** — Open level → Elijah pawn → ball + hoop logic from `BasketballGame/` (see `PACKAGE_AND_TEST.md`).
3. **Film Vault v0** — Single `MediaPlayer` full-screen + pause/seek; then add second player + sync.
4. **Single surface** — New features land in Unreal only; do not duplicate in Swift unless explicitly requested for a legacy app.

---

## Agent / Cursor instructions

**Policy:** **FEL: implement only in Unreal; never Swift unless I say so.**

When implementing Final Evolution Lab features:

- **Default target:** Unreal only — C++ / Blueprint / UMG / Niagara / Editor Python under **`UnrealStarter/BasketballGame/`** (and shared **`UnrealStarter/EditorPython/`**).
- **Do not** edit Swift, SceneKit, or `ios/FinalEvolutionLab` unless the user **explicitly** asks for Swift/iOS work. Do not suggest Swift as the primary path for gameplay, arena, film, or UI.
- Follow **`.cursorrules`** (UE 5.2+ C++ standard) for engine code.

---

## Swift codebase status

The **`FinalEvolutionLab`** Xcode target remains in the repo as **historical / reference** code (ideas, UI experiments, data models). It is **not** the canonical way to ship **iOS** — that is **Unreal’s iOS target** (same game as console/PC). If you need Apple-only APIs (e.g. HealthKit), prefer **Unreal plugins** or a **minimal** native bridge; you still do **not** need a separate “side” app.

**Removing** the Swift tree is a **manual product decision** (archive, export, then delete). This doc does not delete it automatically.

---

## Dual track until convergence (App Store + in-app)

This section title is retained so **Phase 8** tooling and `FELArenaRuntimePreference` cross-references stay greppable. **Implementation:** default to **Unreal only** (see Agent instructions above). “Convergence” means Unreal’s **iOS** packaged build becomes the primary player-facing download; any in-repo Swift shell remains optional reference, not the ship path for new features.

**Single iOS app (ship):** The **Unreal Engine** packaged iOS build is the **one** player-facing gaming app. The in-repo **Swift** project (`ios/`) remains optional legacy / lab tooling, not a second install path for core Arena.

---

## Dual track (historical note)

Some docs still describe a **SceneKit / Swift** shell alongside Unreal. **For Cursor agents and new work, assume Unreal-only** — ship and iterate in UE (including UE’s **iOS** packaging target). The Swift tree may remain in the repo for reference; it is **not** the default implementation surface unless explicitly requested.

---

*Last updated: canonical Unreal-only direction for Final Evolution Lab.*
