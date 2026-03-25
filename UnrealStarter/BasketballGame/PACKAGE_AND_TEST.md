# FEL basketball — package & test (publish-ready path)

Use this when you want a **Mac Development build for internal QA**, a **folder/zip for testers**, or to continue to **iOS** packaging from Unreal.

**Not the Swift app:** The iOS product in this repo is **`FinalEvolutionLabUnreal.xcodeproj`** — see **`XCODE_CLEAN_AND_RUN.md`**. Unreal is a **separate** project (e.g. **FinalEvolutionLab** under *Documents*).

---

## Contents

| Section | What |
|---------|------|
| [1. Preconditions](#1-preconditions) | Blockers before cook |
| [2. Default map & game mode](#2-default-map--game-mode) | Maps & Modes + config snippets |
| [3. Input](#3-input-mac--gamepad) | Legacy PlayerInput + FEL bindings |
| [4. Readiness JSON](#4-readiness-json-optional-for-qa) | Snapshot + session export |
| [5. Mac Development packaging](#5-mac-development-packaging) | Editor UI + **RunUAT** CLI |
| [6. Tester checklist](#6-tester-checklist) | What QA should verify |
| [7. iOS (Unreal)](#7-ios-unreal--testflight-path) | Pointers to run/package on device |
| [8. Notarization (Mac)](#8-notarization-mac) | Short note for distribution |
| [9. Repo artifacts & FinalEvolutionLab defaults](#9-repo-artifacts--myprojec-defaults) | Files in this repo + what’s on disk |
| [10. Short path (TL;DR)](#10-short-path-tldr) | Ordered steps |
| [11. Cross-links](#11-cross-links) | Related docs |

---

## 1. Preconditions

| Check | Why |
|--------|-----|
| **FinalEvolutionLabEditor compiles** | C++ must build before cook. On this Mac use **UE 5.7** + current Xcode unless you match an older pair — see **`../MAC_PLATFORM_MAC_INVALID.md`**. |
| **A playable `.umap`** under **`/Game/FEL/Maps/`** | Blank template projects often have **no** shipped Content maps; **OpenWorld** is not a basketball court. |
| **PlayerStart** in that map | Pawn spawn location. |
| **At least one `FELHoopScoreVolume`** | Otherwise **Buckets** stay **0** — looks like a broken game. |
| **Meshes imported** (recommended) | Elijah / ball / optional Luma or Venice per **`../IMPORT_CHECKLIST.md`**. Missing assets → warnings or invisible mesh. |

**Fastest map:** Enable **Editor → Plugins → Python Editor Script Plugin**, restart Editor, run **`../EditorPython/fel_quick_playtest_level.py`**. It creates **`/Game/FEL/Maps/L_FEL_Playtest`**: scaled **Engine** cube floor, **PlayerStart**, two **`FELHoopScoreVolume`** actors. Requires **compiled FinalEvolutionLab C++** (`AFELHoopScoreVolume`).

---

## 2. Default map & game mode

**Project Settings → Maps & Modes**

- **Game Default Map** — e.g. **`/Game/FEL/Maps/L_FEL_Playtest`** (after the Python script), or **`L_VeniceLuma_Main`** when you build the full art map.
- **Editor Startup Map** — same as game default for day-to-day.
- **Default GameMode** — **`FELBasketballGameMode`**, or rely on **`GlobalDefaultGameMode`** in **`DefaultEngine.ini`**.

**Mergeable snippets (this folder)**

| File | Purpose |
|------|---------|
| **`CONFIG_DefaultEngine.ini.snippet`** | **OpenWorld** as default so the project **always opens** before `L_FEL_Playtest` exists; **commented** lines to switch to **`L_FEL_Playtest`** or **`L_VeniceLuma_Main`**; sets **`GlobalDefaultGameMode`**. |
| **`CONFIG_DefaultGame_FEL.ini`** | **`GeneralProjectSettings`** (name, company, version, description) + **`ProjectPackagingSettings`** for **Development** cook, **pak**, **IoStore**, **English** only. |

---

## 3. Input (Mac / gamepad)

In **`Config/DefaultInput.ini`** keep:

- `DefaultPlayerInputClass=/Script/Engine.PlayerInput`
- `DefaultInputComponentClass=/Script/Engine.InputComponent`
- The FEL axis/action block from **`CONFIG_DefaultInput_FEL.ini`**.

**Smoke test:** **WASD**, **mouse look**, **Space** jump, **gamepad** move / look / face-button jump.

---

## 4. Readiness JSON (optional for QA)

- Copy **`example_readiness_snapshot.json`** → **`Saved/FEL/readiness_snapshot.json`** next to the **`.uproject`**, or **`Content/FEL/Config/readiness_snapshot.json`**. If missing, defaults apply (PRQ **75**).
- After a match that **ends** with scoring on, check **`Saved/FEL/last_session_result.json`** (`GameSessionResult`-shaped). See **`QA_GAMEPLAY_AUDIT.md`** for modes that never end (no file).

---

## 5. Mac Development packaging

### Option A — Editor

1. **Platforms → Mac → Package Project** (or **File → Package Project → Mac**).
2. Choose output folder (e.g. Desktop).
3. Use **Development** for internal QA (console **`~`**, logs) unless you need **Shipping**.

### Option B — Command line (`RunUAT.sh` **BuildCookRun**)

Script: **`UnrealStarter/scripts/package_fel_mac.sh`** (executable). It invokes:

`Engine/Build/BatchFiles/RunUAT.sh BuildCookRun` — **Mac**, **Development**, **-build -cook -stage -pak -archive**.

```bash
chmod +x UnrealStarter/scripts/package_fel_mac.sh
UnrealStarter/scripts/package_fel_mac.sh "/path/to/FinalEvolutionLab.uproject" "/path/to/output-archive-dir"
```

**Defaults:** `UE_ROOT=/Users/Shared/Epic Games/UE_5.7`, project `~/Documents/Unreal Projects/FinalEvolutionLab/FinalEvolutionLab.uproject`, archive `./FEL-Mac-Development-Archive`. Override **`UE_ROOT`** if your engine lives elsewhere.

**Cook failures:** **Project Settings → Packaging → Maps to include** — add your FEL map, or ensure **Game Default Map** points at a cooked map under **`/Game`**.

---

## 6. Tester checklist

- [ ] App launches (no immediate crash).
- [ ] Move / look / jump; ball spawns with physics.
- [ ] Ball through **`FELHoopScoreVolume`** increases HUD score.
- [ ] **`FELBasketballGameMode` `PlayMode`** variants behave per **`GAME_MODES.md`** (timer, target, practice).
- [ ] After match end, move/look lock; if the mode ended with scoring on, **`last_session_result.json`** exists under **`Saved/FEL/`**.

---

## 7. iOS (Unreal / TestFlight path)

Unreal **does not** install through **`FinalEvolutionLabUnreal.xcodeproj`**. You **package iOS** from the Unreal Editor (or automation), then open the **generated iOS `.xcworkspace`**, sign, run or archive.

Read in order:

1. **`../RUN_UNREAL_ON_IPHONE_XCODE.md`** — device run, workspace location, signing.
2. **`../../UNREAL_EXPORT_TO_XCODE.md`** — export / Xcode integration notes.
3. **`../../METAL_TOOLCHAIN_UNREAL.md`** — Metal / Xcode components if the build asks for them.

---

## 8. Notarization (Mac)

**Internal QA:** a **Development** packaged folder is usually enough; Gatekeeper may still prompt — testers can right-click → Open the first time.

**Wider Mac distribution** (DMG, zip outside TestFlight): Apple expects **notarization** for apps signed with Developer ID (Apple Developer Program). Use **Epic’s Mac packaging docs** + **Apple notarization** workflow when you move past the lab. **App Store** Mac has a separate pipeline.

---

## 9. Repo artifacts & FinalEvolutionLab defaults

**In this repo (`UnrealStarter/`):**

| Path | Role |
|------|------|
| **`BasketballGame/PACKAGE_AND_TEST.md`** | This document |
| **`EditorPython/fel_quick_playtest_level.py`** | Creates **`L_FEL_Playtest`** |
| **`scripts/package_fel_mac.sh`** | **RunUAT** Mac Development archive |
| **`BasketballGame/CONFIG_DefaultGame_FEL.ini`** | Merge into **`DefaultGame.ini`** |
| **`BasketballGame/CONFIG_DefaultEngine.ini.snippet`** | Merge into **`DefaultEngine.ini`** |
| **`BasketballGame/example_readiness_snapshot.json`** | Optional QA payload |

**Applied on a typical FinalEvolutionLab under *Documents* (mirror these if you clone fresh):**

- **`Config/DefaultGame.ini`** — project metadata + **Development** **`ProjectPackagingSettings`** (aligned with **`CONFIG_DefaultGame_FEL.ini`**).
- **`Config/DefaultEngine.ini`** — **`OpenWorld`** as **GameDefaultMap** / **EditorStartupMap** until **`L_FEL_Playtest`** exists; **commented** lines to switch to **`/Game/FEL/Maps/L_FEL_Playtest.L_FEL_Playtest`**; **`GlobalDefaultGameMode=FELBasketballGameMode`**.

---

## 10. Short path (TL;DR)

1. Open **FinalEvolutionLab** in **UE 5.7**.
2. Enable **Python Editor Script Plugin**, restart Editor.
3. Run **`UnrealStarter/EditorPython/fel_quick_playtest_level.py`** (Execute Python Script or Output Log `py "/full/path/to/fel_quick_playtest_level.py"`).
4. In **`Config/DefaultEngine.ini`**, set **`GameDefaultMap`** and **`EditorStartupMap`** to **`/Game/FEL/Maps/L_FEL_Playtest.L_FEL_Playtest`** (uncomment or paste).
5. **Platforms → Mac → Package Project** (**Development**) **or** run **`UnrealStarter/scripts/package_fel_mac.sh`**.
6. Hand testers this file + optional **`example_readiness_snapshot.json`**.

---

## 11. Cross-links

| Doc | Why |
|-----|-----|
| **`BasketballGame/README.md`** | Integrate C++, Json modules, links here |
| **`GAME_FINISHED.md`** | Playable slice + ship pointer |
| **`../README.md`** (UnrealStarter) | Entry + script paths |
| **`../VISION_ALIGNMENT.md`** | Product scope (Arena lab, not separate IP) |
| **`../../XCODE_CLEAN_AND_RUN.md` §4** | Unreal vs Swift Xcode |
| **`QA_GAMEPLAY_AUDIT.md`** | Mode/export QA matrix |
| **`GAME_MODES.md`** | `PlayMode` behavior |

---

*Arena lab — not a separate product.*
