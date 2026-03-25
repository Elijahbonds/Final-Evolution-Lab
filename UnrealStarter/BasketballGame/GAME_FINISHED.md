# FEL basketball — “finished” vertical slice

## Playable slice (this doc)

**Done here:** move, look, jump, physics ball, **score when the ball enters a hoop trigger**, on-screen **HUD**, **five** mode rules (timers / targets / practice), and **lab** wiring: optional **`readiness_snapshot.json`**, **PRQ + attribute** on HUD, **`last_session_result.json`** on match end. That is a **complete Unreal vertical slice** for Arena-style iteration.

## Versus the full PRQ-gated vision (`PITCH_DECK.md`)

The **product** vision is **readiness-gated Arena**: scan-backed fairness, richer attribute effects on **outcomes**, shared progression, and (eventually) console/Unreal as the same data story. This prototype **does not** replace that: **no** automatic app sync, **no** shot-accuracy simulation, **no** multiplayer opponent score — see **`../VISION_ALIGNMENT.md`** for the honest map and ordered next steps.

**In one line:** *Playable lab slice = yes. Shipped FEL Arena economy + gating = not yet.*

## C++ pieces

| Class | Role |
|--------|------|
| **`AFELBasketballCharacter`** | WASD / stick move, mouse / right stick look, Space / A jump. |
| **`AFELBasketballGameMode`** | Spawns ball(s); modes; applies readiness after spawn. |
| **`AFELBasketballGameState`** | **`AddScore`**, timers, match end, session export. |
| **`AFELBasketballHUD`** | Mode, **PRQ**, attribute, score, hints (canvas, no UMG). |
| **`AFELHoopScoreVolume`** | Box overlap with **`AFELBasketballActor`** → **`AddScore`** (cooldown). |
| **`FELReadinessIO` / `FFELReadinessSnapshot`** | Load **`readiness_snapshot.json`** (Saved or Content path). |
| **`FELArenaBridge` / `FELSessionExport`** | Swift-style attribute math; **`last_session_result.json`** on match end. |

## Editor setup (required once)

1. **Place mode** → search **`FELHoopScoreVolume`** → drag **one or two** into the level.
2. Position/scale each volume so the **box** covers the **rim / net** area (where the ball should pass to count).
3. **`PointsPerBucket`** / **`ScoreCooldownSeconds`** are editable on the actor.

Without hoop volumes, the game still **runs**; **Buckets** stays **0**.

## Input

Project uses **legacy `PlayerInput`** (not Enhanced Input) so bindings work without Blueprint IMCs. Merge **`CONFIG_DefaultInput_FEL.ini`** into **`DefaultInput.ini`** and set:

```ini
DefaultPlayerInputClass=/Script/Engine.PlayerInput
DefaultInputComponentClass=/Script/Engine.InputComponent
```

## Game modes (built out)

See **`GAME_MODES.md`** — Street Ball, Half-Court Shootout, Timed Blitz, Practice, First to 21 (targets/timers on **`FELBasketballGameMode`**).

## Ship / test builds

See **`PACKAGE_AND_TEST.md`** — create **`L_FEL_Playtest`** with **`../EditorPython/fel_quick_playtest_level.py`**, set default map, then **Package (Mac)** or follow **`../RUN_UNREAL_ON_IPHONE_XCODE.md`** and **`../../UNREAL_EXPORT_TO_XCODE.md`** for Unreal on device.

## Not in scope (next steps)

- Pickup / dribble attachment to character
- AI opponents, multiplayer replication (`isMultiplayer` / `opponentScore` in export are placeholders)
- Automatic iOS ↔ Unreal file bridge (copy snapshot in / session JSON out)
- Menus, pause, audio polish

---

*FinalEvolutionLab on disk includes these changes; templates live under this folder.*
