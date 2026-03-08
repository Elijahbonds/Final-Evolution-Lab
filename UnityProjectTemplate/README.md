# Final Evolution Lab - Unity Project Template

This folder contains the Unity-side bridge scripts and iOS plugin stub needed to connect a Unity scene to the native iOS app in this repository.

## Included files

- `Assets/Scripts/RorkNativeBridge.cs`
  - Sends PRQ score to native via `_PostRorkScore(int)`.
  - Receives native score updates via `OnRorkScoreUpdated(string)`.
- `Assets/Scripts/MotionDataReceiver.cs`
  - Receives motion JSON from native via `OnMotionData(string)`.
  - Uses Unity `JsonUtility` (no third-party dependency required).
- `Assets/Scripts/NativeBridgeTestButton.cs`
  - Optional helper script for a UI button to send sample PRQ updates.
- `Assets/Scripts/PlayerMovement.cs`
  - Input System movement/dunk callbacks.
  - On dunk, updates local score and posts PRQ score to native.
- `Assets/Scripts/PlayerScoreManager.cs`
  - Simple singleton score store used by `PlayerMovement`.
- `Assets/Plugins/iOS/RorkNativeBridge.mm`
  - Stub plugin file; intentionally does not define `_PostRorkScore`.

## Scene setup (required names/signatures)

Create a scene with:

1. A `Canvas` + TMP text fields:
   - `PRQScoreText`
   - `MotionDataText`
   - `UnityPRQInternalText`
2. A button:
   - `SendPRQButton`
3. Empty objects:
   - `NativeBridge` (attach `RorkNativeBridge`)
   - `MotionReceiver` (attach `MotionDataReceiver`)
   - `PlayerScoreManager` (attach `PlayerScoreManager`)
4. A player object:
   - Add `Rigidbody`
   - Attach `PlayerMovement`
   - Add `PlayerInput` with actions for `Move` (Vector2) and `Dunk` (Button)

`MotionReceiver` must keep that exact name because native code sends:

- GameObject: `MotionReceiver`
- Method: `OnMotionData`

## Inspector wiring

- On `NativeBridge`:
  - `Prq Score Display` -> `PRQScoreText`
  - `Unity Prq Internal Display` -> `UnityPRQInternalText`
- On `MotionReceiver`:
  - `Motion Data Display` -> `MotionDataText`
- On `SendPRQButton`:
  - Attach `NativeBridgeTestButton`
  - `Rork Native Bridge` -> `NativeBridge`

## iOS build notes

- Build target: iOS, IL2CPP, ARM64.
- Keep `Assets/Plugins/iOS/RorkNativeBridge.mm` as a stub unless you need to expose additional Objective-C symbols.
- Ensure your native app exports `_PostRorkScore` (Swift `@_cdecl("_PostRorkScore")`) or an equivalent native bridge.
- Install/enable Unity Input System package and set Active Input Handling to include Input System.

## Native expectations in this repository

The iOS app currently sends motion updates to Unity using:

- `UnityManager.sendDataToUnity(data:)`
- `sendMessageToGO("MotionReceiver", method: "OnMotionData", message: json)`

So `MotionDataReceiver.OnMotionData(string)` is ready to receive this directly.
