# React to Unreal Mapping Guide

| Web Component (React/Three.js) | Unreal Engine Equivalent |
|---|---|
| `App.tsx` / `UserContext` | `UFE_GameInstance` |
| `BasketballLab.tsx` | `AFE_LabManager` actor (or `ALevelScriptActor`) |
| `DunkerModel.tsx` | Skeletal mesh actor/character + Animation Blueprint |
| `ArenaRoom.tsx` | Level + PostProcessVolume + `AArenaActor` dynamic materials |
| `saveSystem.ts` | `UFE_SaveGame` + `UGameplayStatics` save/load in `UFE_GameInstance` |
| `CoachingPortal.tsx` | `UFE_CoachingPortalWidget` (UMG / CommonUI) |
| Rapier Physics | Chaos Physics (built-in Unreal) |

## Implemented in this scaffold

- `UFE_GameInstance` stores shards, PRQ, streak, and player attributes.
- `UFE_SaveGame` serializes shards/PRQ/attributes.
- `UFE_GameInstance::SavePlayerState()` and `LoadPlayerState()` handle persistence.
- `AArenaActor::ApplyTheme(EGameModeId)` applies mode-based wall/floor/light themes.
- `AFE_LabManager` manages current mode and syncs state from game instance.
- `UFE_CoachingPortalWidget` exposes portal actions and refresh hooks for UMG.

## UI + Input guidance

- Build portal and vault views in UMG.
- Prefer CommonUI widgets for cross-platform controller/touch behavior.
- Use Enhanced Input assets for gameplay and UI actions.

## Character guidance

- Import dunker GLB as skeletal mesh.
- Drive state transitions via Animation Blueprint (Idle/Run/Dunk/Special).
- Bind gameplay state (`EGameModeId`, PRQ, Neural Drive) into animation parameters.

## Material guidance

- Use a master material with:
  - `BaseColor` (Vector)
  - `AccentColor` (Vector)
  - `EmissiveIntensity` (Scalar)
- `AArenaActor` applies runtime values via dynamic material instances.

## Blueprint-first workflow

- Keep systems in C++ for deterministic core logic.
- Expose knobs with `UPROPERTY(EditAnywhere, BlueprintReadWrite)` and `UFUNCTION(BlueprintCallable)`.
- Tune balance in Blueprint/Editor without recompilation.
