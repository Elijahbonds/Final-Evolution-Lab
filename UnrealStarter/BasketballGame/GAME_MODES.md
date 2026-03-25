# FEL basketball — all game modes

These modes are **Arena-style shells**: same verbs as **`PITCH_DECK.md`** (street play, shootout, timed challenge, practice, first-to-N). They are the **Unreal lab** surface for Gaming Labs — not a finished consumer mode pack.

**PRQ / attribute modulation (today vs vision):**

- **In Unreal now:** HUD shows **PRQ** and the primary Arena attribute (**Court IQ** or **Hang Time**) derived like **`PRQScoring.swift`**; **`readiness_snapshot.json`** tunes jump, move speed, and ball mass; match end emits **`GameSessionResult`-shaped** JSON (shards / `prqBonus` are lab formulas).
- **Still pending for “full” vision:** **Shot accuracy** and other attributes as **gameplay** variance (miss cones, contests), iOS **ingest** of session files, and strict **readiness-gated** policy as in shipping Arena.

Details and schema links: **`../VISION_ALIGNMENT.md`**.

Set **`PlayMode`** on **`FELBasketballGameMode`** (World Settings, map override, or Blueprint child). Tune numbers on the same actor.

| Mode | Swift `gameModeId` | Balls | Scoring | Win / end condition | Tunable properties | PRQ hook (vision) |
|------|---------------------|-------|---------|---------------------|--------------------|-------------------|
| **Street Ball** | `basketball_h2h` | 1 | On | None (open play) | — | Court IQ + tuning; **no automatic match end** → **no** `last_session_result.json` until you add a stop rule |
| **Half-Court Shootout** | `basketball_3v3` | 2 | On | First to **`ShootoutTargetBuckets`** (default **11**) | `ShootoutTargetBuckets` | Higher **modeWeight** → more shards; attribute = Court IQ |
| **Timed Blitz** | `basketball_h2h` | 1 | On | Clock hits **0** → shows final bucket count | `TimedBlitzSeconds` (default **120**) | Same as H2H; time pressure could later scale with **neuralDrive** |
| **Practice** | `basketball_h2h` | 1 | **Off** | Never ends on score | — | **No economy**; **no match end** → **no** session file unless you add stop UI; movement tuning still applies |
| **First to 21** | `basketball_dunk` | 1 | On | Reach **`FirstToNTargetBuckets`** (default **21**) | `FirstToNTargetBuckets` | **Hang Time** attribute line; dunk-line tuning can lean on **verticalPotential** later |

## Behaviour details

- **Game state** (`FELBasketballGameState`) stores score, target, timer, and **`bMatchEnded`**.
- **Hoop volumes** only add score when scoring is enabled and the match has not ended.
- When a mode **ends** (target reached or time up), **move / look input** is disabled; restart **PIE** or reload the level.
- **HUD** shows mode name, **PRQ**, primary **Arena attribute** (Court IQ / Hang Time), score (`X / target` when applicable), countdown for timed modes, and an end banner.
- Drop **`example_readiness_snapshot.json`** into `Saved/FEL/readiness_snapshot.json` (or `Content/FEL/Config/`) to override defaults; see **`../VISION_ALIGNMENT.md`**.

## Blueprint

Subclass **`FELBasketballGameMode`** and set **`PlayMode`** + overrides per map, or use **World Settings → GameMode Override** pointing at that Blueprint.

---

*Implemented in `FinalEvolutionLab` and mirrored under `UnrealStarter/BasketballGame/`.*
