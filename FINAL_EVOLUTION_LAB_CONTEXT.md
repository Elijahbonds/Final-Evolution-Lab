# Final Evolution Lab — Agent Context

> **Direction (canonical):** **Unreal Engine** is the single runtime and shipping client. See **`UNREAL_ONLY.md`**. The Swift app (`FinalEvolutionLab/`) is **legacy / reference** for new feature work unless a task explicitly targets iOS native code.

This file summarizes how the **current repo** relates to the **canonical code-dump spec** (iOS + Unity) so any Cursor agent has full context. Historical sections below still describe Swift/Unity alignment; **implementation priority** follows **`UNREAL_ONLY.md`**.

## Project identity

- **Name:** Final Evolution Lab
- **Stack (target):** **Unreal Engine** (C++ / Blueprint / UMG) — see `UnrealStarter/`
- **Stack (legacy in repo):** iOS app (Swift/SwiftUI); Unity C# was spec-only — **not** present as `Unity/` in tree
- **Purpose:** Training/arena experience with Golden Era combo engine, Matrix-style time effects, DDA; **gameplay and UI** converge in Unreal

---

## Current repo vs code-dump alignment

### iOS — Present and aligned

| Dump item | Current location / notes |
|-----------|--------------------------|
| `FinalEvolutionLabApp.swift` | ✅ `FinalEvolutionLab/FinalEvolutionLabApp.swift` |
| `ContentView` (tabs, settings, onboarding) | ✅ `ContentView.swift` — tabs differ: **Lab, Train, Arena, Status, Profile** (no separate Coach/Blueprints tabs) |
| `Theme` | ✅ `FinalEvolutionLab/Utilities/Theme.swift` (extended: brandBlue, brandCyan, mesh, etc.) |
| `simpleMode` environment | ✅ `FinalEvolutionLab/Models/SimpleMode.swift` (`SimpleModeKey` + `EnvironmentValues.simpleMode`) |
| `LabViewModel` | ✅ `FinalEvolutionLab/ViewModels/LabViewModel.swift` |
| `UserProfile` | ✅ `FinalEvolutionLab/Models/UserProfile.swift` (full model: evolutionShards, hasCompletedOnboarding, metrics, etc.) |
| `AppTab` | ✅ In `ContentView.swift`: `.lab`, `.training`, `.dashboard`, `.social`, `.vault` |
| `GoldenEraEngine` | ✅ `FinalEvolutionLab/Models/GoldenEraEngine.swift` |
| `MatrixPhysicsEngine` | ✅ `FinalEvolutionLab/Models/MatrixPhysicsEngine.swift` |
| `DynamicDifficulty` | ✅ `FinalEvolutionLab/Models/DynamicDifficulty.swift` |
| `UnityExportManifest` / `UnityExportBuilder` | ✅ `FinalEvolutionLab/Services/UnityExportManifest.swift` |
| Views: Lab, Coach, Blueprints, GameModeSelection, Vault, Settings, Onboarding | ✅ All exist under `FinalEvolutionLab/Views/` (Lab/Coach/Blueprints richer than dump) |

### iOS — Dump items not in repo (optional add)

| Dump item | Suggestion |
|-----------|------------|
| `Config.swift` (empty enum) | Add if you want a single place for env/build config. |
| `Models/GameTypes.swift` (ComboDirection, GameModeId, PRQ) | Partially covered by `GameMode.swift` and types inside GoldenEraEngine/ComboManager; add `GameTypes.swift` if you want a single shared types module for Swift ↔ Unity. |
| `Utilities/GameLoopHelpers.swift` (highScore, saveHighScoreIfNeeded, restartGameWithHaptic) | Add under `Utilities/` if you want these helpers in the iOS app. |

### Unity — `UnityProject/` (Unity 6) + spec `Unity/`

The repo contains a **Unity 6** project at **`UnityProject/`** (URP, game modes, `FELMeshyStreamingLoader` + Meshy GLBs in `StreamingAssets`, `FELNativeBridge` aligned with iOS). A smaller **`Unity/`** tree holds additional spec scripts (Film Vault, post-process) you can merge into the same project.

The original code dump also described a **Unity/** folder with C# runtime and editor scripts:

- **Runtime:** `PlayerController.cs`, `GameManifestReceiver.cs`, `MatrixPhysicsController.cs`, `MatrixPhysicsEngine.cs`, `ComboManager.cs`, `DynamicDifficultyManager.cs`, `AnimationBridge.cs`
- **Editor:** `URPMaterialBridge.cs`, `ModelImportProcessor.cs`, `MatrixPhysicsColliderSetup.cs`

**Current repo:** No `.cs` files. Unity code is either in a separate Unity project or should be added (e.g. as a `Unity/` subtree or submodule) when you integrate the game layer.

### Docs referenced in dump

- **CURSOR_IOS_FINISH_PLAYBOOK.md** — Not present in repo. Dump describes: “Make it Playable”, “Polish & Feel”, “Final Deployment”, provisioning, Phase 1–4, restart snippet, launch screen, app icon.
- **Unity/IMPORTER_SETUP.md**, **Unity/SCENE_SETUP.md** — Not present. Dump describes importer setup, scene setup, manifest handshake, Spacebar slow-mo test.

---

## Swift ↔ Unity mapping (from dump)

| Swift (iOS) | Unity (C#) |
|-------------|------------|
| `MatrixPhysicsEngine.swift` (TimeScaleManager) | `MatrixPhysicsController.cs`, `TimeScaleManager` in `MatrixPhysicsEngine.cs` |
| `GoldenEraEngine.swift` | `ComboManager.cs` |
| `UnityExportManifest.swift` | `GameManifestReceiver.cs`, `GameManifest` |
| `DynamicDifficulty.swift`, `PRQDrivenDDA` | `DynamicDifficultyManager.cs` |
| `GameTypes` (ComboDirection, GameModeId, PRQ) | `ComboManager.ComboDirection`, `DynamicDifficultyManager.GameModeId` |

---

## Quick reference — Tab structure

**Code-dump tabs:** Lab, Coach, Blueprints, Arena, Vault.

**Current app tabs:** Lab, Train (TrainingHubView), Arena (GameModeSelectionView), Status (DashboardView), Profile (VaultView).

To mirror the dump exactly you’d add Coach and Blueprints as separate tabs and optionally rename/merge Train and Status to match.

---

*Use this file plus the full code-dump document for agent context. The canonical dump is the single source of truth for the intended iOS + Unity structure and APIs.*
