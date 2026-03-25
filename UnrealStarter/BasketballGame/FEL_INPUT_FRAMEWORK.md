# Final Evolution Input Framework (Bonds Bounce)

## UFELInputComponent

- Inherits **`UEnhancedInputComponent`** (add **`EnhancedInput`** to `Build.cs`).
- **150 ms** input buffer for Jump (Kick/Interact hooks reserved).
- Default pawn subobject: constructor uses `SetDefaultSubobjectClass<UFELInputComponent>(TEXT("InputComponent0"))`. If your engine build uses a different `ACharacter` input subobject name, adjust that string to match the default subobject name in `ACharacter`.

## Coyote time

- **`AFELBasketballCharacter`**: **0.1 s** grace after walking off a ledge (`CoyoteTimeRemaining`), integrated with **`CanJump()`** and a manual airborne impulse path when not grounded.

## Hit stop

- **Perfect** **`EFELJumpTimingBand`**: **`CustomTimeDilation = 0.05`** on the character for **~2 frames** at 60 Hz (`2.f/60.f` real-time timer), then reset to **1.0**. Coexists with Neuro-Flow global dilation (multiplicative).

## Enhanced Input mapping contexts

- **`AFELBasketballPlayerController::ApplyArenaInputForMode`** — call site wired from **`AFELBasketballGameMode`** (`StartPlay` + async mode load). Implement **`AddMappingContext` / `RemoveMappingContext`** once **`UInputMappingContext`** assets exist per mode (or reference them from **`UFELArenaModeData`**).

## IFELInteractable + magnet

- **`AFELHoopTargetActor`** — rim/goal target; strength scales with Neural Drive (75+).
- **`AFELBasketballActor`** — applies subtle **`AddForce`** toward the first **`AFELHoopTargetActor`** in the level when **`CachedNeuralDriveForMagnet` ≥ 75**.
