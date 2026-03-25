# FEL basketball (Unreal) — game modes, Elijah, ball, Venice + Luma

C++ templates for **UE 5.2+**; verified on **UE 5.7** with **Xcode 26** (see **`UE57_IWYU.md`** for `.cpp` include order). **Meshes are not compiled** — import OBJ/GLB per **`../IMPORT_CHECKLIST.md`**, then build C++.

**Not a separate product:** This folder is **FEL Arena / Gaming Labs** — a technical and design **lab** inside the same ecosystem as the Swift app (`PITCH_DECK.md`, `app-synopsis.md`). It is **not** positioned as its own basketball title. Read **`../VISION_ALIGNMENT.md`** for north star, honest scope, guardrails, and Swift schema links (`PerformanceMetrics`, `GameSessionResult`, `GameModeId`, `PRQScoring`).

## Prerequisites

1. **Unreal C++ project** (e.g. `FinalEvolutionLab`) that **compiles** on your Mac (see **`../MAC_PLATFORM_MAC_INVALID.md`** — Xcode / UE version).
2. Assets in Content:
   - **`SKM_ElijahBonds_Walking`** → `/Game/FEL/Characters/ElijahBonds/`
   - **`SM_HoopBusBasketball`** → `/Game/FEL/Props/`
   - **`SM_LumaCourt`** → `/Game/FEL/Environment/Luma/`
   - **`SM_VeniceCourt`** (import `Venice_beach_UE5/Venice_mesh.obj` or GLB) → `/Game/FEL/Environment/Venice/`

## Integrate into your module (e.g. `FinalEvolutionLab`)

1. Copy every **`FEL*.h`** and **`FEL*.cpp`** from this folder into **`Source/FinalEvolutionLab/`** (same folder as `FinalEvolutionLab.Build.cs`).
2. Replace **`FINALEVOLUTIONLAB_API`** with your module’s API macro (e.g. **`FINALEVOLUTIONLAB_API`** if the module is `FinalEvolutionLab`).
3. In **`FinalEvolutionLab.Build.cs`**, ensure dependencies include at least:

```csharp
PublicDependencyModuleNames.AddRange(new string[] {
    "Core", "CoreUObject", "Engine", "InputCore",
    "PhysicsCore", "Json", "JsonUtilities"
});
```

(`Json` modules are required for **readiness snapshot** + **session export**; **`UMG` / `Slate` / `SlateCore`** for **`UFELNeuroDebugHUDWidget`**; Enhanced Input is optional for this slice—see **`CONFIG_DefaultInput_FEL.ini`** — includes **`FELHotReloadReadiness` → R** for JSON hot-reload in non-Shipping.)

4. Regenerate project files, build.
5. **Editor:** create map **`Content/FEL/Maps/L_VeniceLuma_Main`** (name as you like), place **Venice** + **Luma** static meshes per **`VENICE_LUMA_LEVEL.md`**, add **PlayerStart**, set **World Settings → GameMode Override** to **`FELBasketballGameMode`** (or a Blueprint child).
6. Optional: merge **`CONFIG_DefaultEngine.ini.snippet`** into `Config/DefaultEngine.ini` (adjust map path).

## What you get

| Class | Role |
|--------|------|
| **`AFELBasketballGameMode`** | **`EFELMatchPhase`** (Waiting → InProgress → MatchComplete), countdown, **`OnMatchComplete`**; **`ApplyModeSpecificBehaviors`** after countdown (Brain Brawl / Dunk); **`session_results.json`** + **`last_session_result.json`**. |
| **`FELArenaModeDefinitions.h` / `.cpp`** | **`EFELArenaMode`** enum + **`FELArenaModeFromSwiftId`** (replaces standalone **`FELGameModeDefinitions.cpp`** — use **`FELArenaModeDefinitions.cpp`** in your `.Build.cs` / Xcode target). |
| **`AFELBasketballCharacter`** | Third-person **Elijah**, spring arm + camera, **WASD / mouse / jump**; **`ApplyReadiness`**. |
| **`AFELBasketballActor`** | Physics **HoopBus** ball; **`ApplyReadiness`**. |
| **`AFELBasketballGameState`** | Buckets, timers, **`OnMatchEnded`** (GameMode writes rewards + **`session_results.json`**). |
| **`AFELBasketballHUD`** | Mode, **PRQ**, attribute line, score, timer, end banner. |
| **`AFELHoopScoreVolume`** | Rim overlap → **`AddScore`**. |
| **`FELReadinessIO` / `FFELReadinessSnapshot`** | Load **`readiness_snapshot.json`** (Documents/FEL on iOS, then Saved, then Content). |
| **`UFELNeuroMechanicBridgeSubsystem`** | **`UGameInstanceSubsystem`**: **`TryLoadSnapshot`**, **`ApplyReadiness`**, **`OnNeuroHUDStatsRefresh`** (HUD handshake); optional delayed world-init re-apply after level loads. |
| **`AFELBasketballPlayerController`** | Default **`PlayerControllerClass`**; non-Shipping: **`UFELNeuroDebugHUDWidget`** + **`R`** → **`ReloadSnapshotFromDiskAndApply`**. |
| **`UFELNeuroDebugHUDWidget`** | Live **vertEst / PRQ / JumpZ / Speed** (subsystem cache + **`FELNeuroMechanicDisplay`**). |
| **`FELArenaBridge` / `FELSessionExport`** | Shards/PRQ bonus curves; **`session_results.json`** (Vault/Social keys + neuro fields) + legacy **`last_session_result.json`**. |
| **`UFELProgressionSubsystem`** | Session + lifetime Shards/XP; **`progression_session.json`** under FEL data dir. |
| **`FELPlatformPaths` / `FELPlatformPaths_IOS.mm`** | **`Documents/FEL`** on device vs **`Saved/FEL`** on desktop. |
| **`UFELOnboardingWidget`** | First Lab visit; writes **`lab_onboarding_completed.flag`**. |

**Playable checklist:** **`GAME_FINISHED.md`** · **All modes:** **`GAME_MODES.md`** · **Input:** **`CONFIG_DefaultInput_FEL.ini`**

**Package / QA / testers:** **`PACKAGE_AND_TEST.md`** (minimal map script, Mac cook, iOS pointer) · **`QA_GAMEPLAY_AUDIT.md`** (modes, export rules, Swift parity, test matrix).

**Readiness file:** Copy **`example_readiness_snapshot.json`** to **`Saved/FEL/readiness_snapshot.json`** (created next to your `.uproject`’s Saved folder) or **`Content/FEL/Config/readiness_snapshot.json`**. Optional **`ArenaSettings.json`** → **`Content/FEL/Config/ArenaSettings.json`** (see repo **`ArenaSettings.json`**) — data-driven rules for all 12 Swift **`GameModeId`** modes; `active_mode` in the snapshot picks the row.

After a match ends, check **`Saved/FEL/last_session_result.json`** for **`GameSessionResult`**-shaped output.

## Optional

- Drop **`../FELPlayerController.cpp/.h`** into the same module and set **`PlayerControllerClass`** on your GameMode Blueprint to **`FELPlayerController`**.
- Extend **Half-Court Shootout** in Blueprint or C++ (shot clock, scoring volumes).

---

*Final Evolution Lab — UnrealStarter.*
