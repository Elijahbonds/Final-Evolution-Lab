# Vision audit — Final Evolution Lab (Mar 2026)

## Canonical direction (`UNREAL_ONLY.md`)

- **Shipping gameplay shell:** Unreal Engine (C++ / UMG / Media) for arena, film, streams, iOS/console packages.
- **Repo reality:** A full **Swift/SwiftUI** app (`FinalEvolutionLab/`) and a **Unity 6** project (`UnityProject/`) remain for UaaL, prototypes, and tooling.

**Gap (acknowledged):** Two runtime stacks exist. New **product** features should land in **Unreal** per `UNREAL_ONLY.md`. Unity work here targets **library / bridge / vertical slices**, not a second shipping client, unless product explicitly keeps Unity on iOS.

---

## Unity project (`UnityProject/`) — what was missing vs “finish the game”

| Area | Status |
|------|--------|
| Game mode stubs (`GameModes/*`, `GameModeManager`) | Present; wiring to input + scenes is still designer work. |
| Native bridge symbols vs iOS `FELNativeCallProxy` | **Fixed:** `FELNativeBridge.cs` + `NativeCallProxy` now call `FEL_OnExerciseComplete` / `FEL_UpdateUserXP` / `FEL_OnRepCompleted`. |
| Workout summary | Still uses optional `UnityOnWorkoutSummary` (add to native host if you need parity). |
| Meshy / GLB environments | **Added:** `FELMeshyStreamingLoader` + **glTFast** + StreamingAssets pipeline; five soccer/tennis props. |
| Unity 6 physics API | **Fixed:** `Rigidbody.velocity` → `linearVelocity` where required. |

---

## Assets integrated (your Meshy exports)

Copied into `UnityProject/Assets/StreamingAssets/Meshy/`:

- Stadium (soccer, stylized)
- Goal posts
- Soccer ball (FIFA-style)
- Tennis racket
- Tennis ball

Loader assigns **Rigidbody** + **convex collider** on balls; **SoccerMode** / **TennisMode** resolve the ball after load.

---

## Recommended next steps (Unreal-first)

1. Merge `UnrealStarter/BasketballGame` into your tracked `.uproject`; use `PACKAGE_AND_TEST.md` for a vertical slice.
2. Re-import the same GLBs in Unreal (Datasmith / glTF plugin) for the **canonical** stadium look.
3. If iOS Unity remains: embed `UnityFramework`, keep `FELNativeBridge` names aligned with `FELNativeCallProxy.m`.

---

*This file complements `FINAL_EVOLUTION_LAB_CONTEXT.md` and `UNREAL_ONLY.md`.*
