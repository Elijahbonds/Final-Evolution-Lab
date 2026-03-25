# Phase 3 — Merge `UnrealStarter` into a real `.uproject` + Neuro-Mechanic bridge

**Audience:** Lead game dev / systems architect moving Arena gameplay from Swift templates into Unreal while keeping Swift as shell (Social / Vault / Dashboard).

**References:** `UNREAL_ONLY.md`, `NEURO_MECHANIC_BRIDGE.md`, `BasketballGame/PACKAGE_AND_TEST.md`.

---

## 1. Recommended folder structure (real Unreal project)

Assume your game module is named **`MyProjec`** (replace with your project name everywhere).

```
MyProjec/
├── MyProjec.uproject
├── Config/
│   ├── DefaultEngine.ini          ← merge CONFIG_DefaultEngine.ini.snippet + GlobalDefaultGameMode
│   ├── DefaultGame.ini            ← merge CONFIG_DefaultGame_FEL.ini (sections)
│   └── DefaultInput.ini           ← merge CONFIG_DefaultInput_FEL.ini
├── Content/
│   └── FEL/
│       ├── Maps/                  ← L_FEL_Playtest, L_VeniceLuma_Main, …
│       ├── Blueprints/            ← UI shell hooks, BP_GameInstance if needed
│       └── Config/
│           └── readiness_snapshot.json   ← optional packaged default (Swift overwrites via bridge)
├── Plugins/                       ← optional: iOS file provider, HTTP, your bridge
├── Saved/
│   └── FEL/                       ← runtime: readiness_snapshot.json, last_session_result.json (QA)
└── Source/
    └── MyProjec/
        ├── MyProjec.Build.cs
        ├── MyProjec.h / MyProjec.cpp
        └── FEL/                   ← all C++ from repo UnrealStarter/BasketballGame/
            ├── FELReadinessTypes.h
            ├── FELReadinessIO.h / .cpp
            ├── FELKineticLeakage.h / .cpp
            ├── FELBasketballCharacter.h / .cpp
            ├── FELBasketballActor.h / .cpp
            ├── FELBasketballGameMode.h / .cpp
            ├── FELBasketballGameState.h / .cpp
            ├── FELBasketballHUD.h / .cpp
            ├── FELHoopScoreVolume.h / .cpp
            ├── FELSessionExport.h / .cpp
            ├── FELArenaBridge.h / .cpp
            ├── FELNeuroMechanicBridgeSubsystem.h / .cpp
            └── … (see glob under BasketballGame/)
```

**Editor Python (keep in repo, symlink or copy):**

```
UnrealStarter/EditorPython/
├── fel_setup_level.py
├── fel_quick_playtest_level.py
└── README.md
```

Point Unreal’s **Additional Non-Asset Directories to Package** or document “run from repo clone path” — or **copy** scripts into `MyProjec/EditorPython/` for a self-contained project repo.

**Naming:** If you prefer a dedicated module `FELBasketball` instead of `MyProjec/FEL/`, split into a **second module** — only worth it if you want a plugin boundary; a single **game module** with `FEL` subfolder is enough for Phase 3.

---

## 2. Neuro-Mechanic bridge — C++ outline (and Blueprint surface)

**Existing contract** is already in-tree:

| Piece | Role |
|-------|------|
| `FFELReadinessSnapshot` | `FELReadinessTypes.h` — mirrors Swift metrics + `HangTimeScale`, `KineticLeakageMultiplier` |
| `FELReadinessIO::TryLoadSnapshot` | Loads JSON from `Saved/FEL/` or `Content/FEL/Config/` |
| `AFELBasketballCharacter::ApplyReadiness` | Applies snapshot to jump / move caps |
| `FELKineticLeakage` | Leakage math shared with character |
| `FELArenaBridge` | Shards / PRQ bonus parity with Swift `PRQScoring` |

**Subsystem (implemented in repo):** `BasketballGame/FELNeuroMechanicBridgeSubsystem.h` / `.cpp` — `UGameInstanceSubsystem` so readiness survives level loads.

| Method | Role |
|--------|------|
| `TryLoadSnapshot` | Disk only; wraps `FELReadinessIO::TryLoadSnapshot` (Saved first, then `Content/FEL/Config/`). |
| `ApplyReadiness` | Caches snapshot, applies to `AFELBasketballCharacter` (if player pawn) + all `AFELBasketballActor`; broadcasts `OnReadinessApplied`. |
| `ReloadSnapshotFromDiskAndApply` | One-shot load + apply (GameMode / shell). |
| `ApplySnapshotFromJsonString` | Uses `FELReadinessIO::ParseSnapshotJsonString` (same keys as `NEURO_MECHANIC_BRIDGE.md` / `example_readiness_snapshot.json`). |
| `ReapplyCachedToCurrentWorld` | After travel, re-push cached struct to new pawns/balls. |

`bAutoLoadFromDiskOnFirstWorldInit` — delayed **0.08s** after `OnPostWorldInitialization` (off by default; **`AFELBasketballGameMode`** calls **`ReloadSnapshotFromDiskAndApply`** after ball spawn — single disk read). `bReapplyCachedOnWorldInit` — same delay, re-applies cache only (off by default; enable for travel where actors respawn without a GameMode reload).

**Blueprint graph (minimal):**

- Get **Game Instance Subsystem** → class **`FEL Neuro Mechanic Bridge Subsystem`** → **Reload Snapshot From Disk And Apply** (or **Apply Snapshot From Json String**).
- Optional: bind **On Readiness Applied** → HUD / WBP for debug.

**JSON parsing from string:** implemented via `FELReadinessIO::ParseSnapshotJsonString` (aligned with file keys, not raw `JsonObjectStringToUStruct` alone).

---

## 3. Swift: what can deprecate when Unreal owns Arena

**Safe to treat as legacy (after UE Arena ships and users launch Unreal, not Swift UI):**

| Area | Notes |
|------|--------|
| `ArenaView.swift` — **in-match** flow | `ArenaGameFlowView`, `GenericArenaPlayView`, sport canvas stacks, `ArenaDunkPlayView`, solo soccer/golf multi-round wrappers — entire **play** phase |
| `GameScreensView.swift` — **GetReady / Result** when only used from Arena | Keep if other tabs reuse; else thin |
| `GameModeRegistry` + venue rows | Replace Arena tab with **“Launch Arena (Unreal)”** or embedded UE view; keep **models** if shared with export |
| `VenueManager.openMode` / `preselectedArenaModeId` | Replace with **deep link** or **GameModeId string** passed to Unreal bootstrap |
| `LocalPlayLobbyView` + Multipeer for Arena | Superseded by UE networking when replicated |

**Keep (shell + data pipeline):**

| Area | Why |
|------|-----|
| `PRQManager`, `BiomechanicsAudit`, `SystemScanResult`, `PerformanceMetrics` | Source of truth for **readiness_snapshot.json** export |
| `LabView` (non-Arena), Training, Dashboard, Vault, Social, Film/Stream | Product shell per your roadmap |
| `UnityExportManifest` / export builders | Until fully replaced by UE pipeline |
| `FELNativeCallProxy` / minimal bridge | If embedding UE in iOS or passing stats |

**Transitional pattern:** Arena tab shows **one** primary action — **“Open Arena”** → present **Unreal view** (metal view / plugin) or **open sibling Unreal app** via URL — while **PRQManager.shared.sync** runs **before** launch so `readiness_snapshot.json` is fresh on disk or in app group container for UE to read.

---

## 4. First step: initialize core Unreal project while keeping Swift shell

**Ordered first step (do this before feature work):**

1. **Create** a new **C++** Unreal project (UE **5.2+** per `.cursorrules`, or **5.7** to match `PACKAGE_AND_TEST.md`) named e.g. `MyProjec`, **with Starter Content off** (or minimal) to avoid OpenWorld-only default confusion.
2. **Copy** all `UnrealStarter/BasketballGame/*.h` and `*.cpp` into `Source/MyProjec/FEL/` (or your chosen subfolder).
3. **Merge** `MyProjec.Build.cs.snippet` dependencies: **Json**, **JsonUtilities**, **InputCore**, **PhysicsCore** — see snippet file.
4. **Generate project files** → **build** in IDE until **MyProjecEditor** compiles.
5. **Merge** `Config` snippets; set **Default GameMode** to `FELBasketballGameMode` (see `PACKAGE_AND_TEST.md` §2).
6. Run **`fel_quick_playtest_level.py`** → get **`L_FEL_Playtest`** with floor, **PlayerStart**, **FELHoopScoreVolume**.
7. **PIE:** move, jump, score — confirm readiness JSON optional load works.

**Only after step 7:** wire **Swift** to export JSON to a **shared location** (App Group, iTunes File Sharing path documented in `NEURO_MECHANIC_BRIDGE.md`) or implement **`UFELNeuroMechanicBridgeSubsystem::ApplySnapshot`** from a **native plugin** that receives bytes from the shell.

**Swift shell unchanged in Phase 3 step 1:** no Xcode deletion — you add a **parallel** Unreal deliverable; tab swap comes later.

---

*Cross-link: `PROJECT_AUDIT_AND_FINISH_PLAN.md` Phase 3.*
