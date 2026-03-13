# Final Evolution Lab (Unreal Project Scaffold)

This is a real Unreal project scaffold you can open in Unreal Editor after generating project files.

## Structure

- `FinalEvolutionLab.uproject`
- `Config/`
  - `DefaultGame.ini`
  - `DefaultEngine.ini`
  - `DefaultInput.ini`
- `Source/`
  - `FinalEvolutionLab.Target.cs`
  - `FinalEvolutionLabEditor.Target.cs`
  - `FinalEvolutionLab/`
    - module bootstrap files
    - bridge and gameplay classes

## Included gameplay/bridge classes

- `ARorkPlayerCharacter`
  - Enhanced Input movement.
  - Dunk action updates local score first, then posts score to native.
- `APlayerScoreManager`
  - Centralized local score actor.
- `URorkNativeBridgeComponent`
  - Calls `_PostRorkScore(int32)` on iOS.
  - Exposes native score update callback/event hooks.
- `UMotionDataReceiverComponent`
  - Parses incoming motion JSON (`ax, ay, az, gx, gy, gz, t`).
- `URorkBridgeRoutingLibrary`
  - Utility route functions for native/plugin bridge calls into scene components.

## Unreal setup steps

1. Open `FinalEvolutionLab.uproject` in Unreal Engine 5.4+.
2. Let Unreal generate/build C++ project files.
3. Create a character blueprint from `ARorkPlayerCharacter`.
4. Add in-world actors/components:
   - `APlayerScoreManager` actor in level.
   - `URorkNativeBridgeComponent` on player (or a dedicated bridge actor).
   - `UMotionDataReceiverComponent` on player or dedicated receiver actor.
5. Create Enhanced Input assets:
   - `IMC_Gameplay` mapping context.
   - `IA_Move` (Axis2D) bound to WASD/left stick.
   - `IA_Dunk` (Boolean) bound to Space / gamepad south button.
6. Assign those input assets on `ARorkPlayerCharacter` properties.

## iOS native symbol compatibility

This repo's native iOS host already exports:

- `_PostRorkScore` via Swift `@_cdecl("_PostRorkScore")`

So Unreal can call the symbol directly on iOS builds.

Keep `Source/FinalEvolutionLab/Private/IOS/RorkNativeBridgeIOSStub.mm` as a stub only.
