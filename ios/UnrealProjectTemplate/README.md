# Final Evolution Lab - Unreal Engine Template

This template mirrors the Unity bridge flow using Unreal C++ and Enhanced Input.

## Included files

- `Source/FinalEvolutionLab/Public|Private/RorkNativeBridgeComponent.*`
  - Posts PRQ score to native iOS with `_PostRorkScore(int32)`.
  - Receives native score confirmations via `OnRorkScoreUpdated(int32)`.
- `Source/FinalEvolutionLab/Public|Private/MotionDataReceiverComponent.*`
  - Receives motion JSON payload (`ax, ay, az, gx, gy, gz, t`).
- `Source/FinalEvolutionLab/Public|Private/PlayerScoreManager.*`
  - Centralized local score manager.
- `Source/FinalEvolutionLab/Public|Private/RorkPlayerCharacter.*`
  - Enhanced Input movement + dunk flow.
  - On dunk: local score update first, then native post.
- `Source/FinalEvolutionLab/Private/IOS/RorkNativeBridgeIOSStub.mm`
  - iOS bridge stub (no `_PostRorkScore` definition).
- `Source/FinalEvolutionLab/FinalEvolutionLab.Build.cs`
  - Module dependencies for Enhanced Input + JSON + UMG.

## Required Unreal setup

1. Create/import an Unreal C++ project and add these files into your game module.
2. Confirm module name in macros (`FINALEVOLUTIONLAB_API`) matches your module.
3. Enable plugins:
   - Enhanced Input
4. Build the project so classes appear in editor.

## Input setup (Enhanced Input)

Create assets:

- `IMC_Gameplay` (`Input Mapping Context`)
- `IA_Move` (`Input Action`, value type `Axis2D`)
- `IA_Dunk` (`Input Action`, value type `Boolean`)

Suggested bindings:

- `IA_Move`: WASD, Left Stick
- `IA_Dunk`: Space Bar, Gamepad Face Button Bottom

Assign on your player character blueprint (derived from `ARorkPlayerCharacter`):

- `GameplayMappingContext` -> `IMC_Gameplay`
- `MoveAction` -> `IA_Move`
- `DunkAction` -> `IA_Dunk`

## Scene wiring

1. Place a `PlayerScoreManager` actor in level.
2. On your player actor:
   - Add `RorkNativeBridgeComponent`.
   - Add `MotionDataReceiverComponent` (or a dedicated actor with this component).
3. If using UMG, bind text widgets to:
   - `RorkNativeBridgeComponent.OnInternalPrqUpdated`
   - `RorkNativeBridgeComponent.OnNativePrqUpdated`
   - `MotionDataReceiverComponent.OnMotionPayloadUpdated`

## Native iOS bridge compatibility

This project's iOS app already exports:

- `_PostRorkScore` via Swift `@_cdecl("_PostRorkScore")`

So Unreal can call `_PostRorkScore` directly from `RorkNativeBridgeComponent` in iOS builds.

## Dunk score flow

Implemented in `ARorkPlayerCharacter::Dunk(...)`:

1. `CurrentScore = PlayerScoreManager->GetPlayerScore()`
2. `NewScore = CurrentScore + 10`
3. `PlayerScoreManager->UpdatePlayerScore(NewScore)`  // local first
4. `RorkBridge->PostRorkScoreToNative(NewScore)`      // then native
