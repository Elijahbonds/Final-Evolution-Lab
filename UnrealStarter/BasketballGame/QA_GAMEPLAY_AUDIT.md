# Gameplay & game modes — QA audit

**Scope:** Unreal **FEL basketball** (`BasketballGame/` / FinalEvolutionLab) plus **high-level parity** notes vs Swift **Arena** (`ArenaView`, dunk flow).  
**Purpose:** Pre-release / internal test checklist, known gaps, and doc-vs-code truth.

---

## 1. Unreal mode matrix (code vs docs)

| `PlayMode` | Scoring | Target | Timer | `EndMatch` triggers | Session JSON | Notes |
|------------|---------|--------|-------|---------------------|--------------|--------|
| Street Ball | On | 0 | 0 | **Never** | **Never** (no end state) | Open sandbox; OK for PIE, weak for “session complete” QA. |
| Half-Court Shootout | On | `ShootoutTargetBuckets` | 0 | Score ≥ target | On end | Two balls; same `gameModeId` as Swift **3v3** (naming only — not 3v3 sim). |
| Timed Blitz | On | 0 | `TimedBlitzSeconds` | Time ≤ 0 | On end | Score at timeout = final buckets. |
| Practice | **Off** | 0 | 0 | **Never** | **Never** | Buckets not counted; movement tuning still applies. |
| First to 21 | On | `FirstToNTargetBuckets` | 0 | Score ≥ target | On end | `gameModeId` = `basketball_dunk` (Arena label **Hang Time**); not dunk mini-game logic. |

**Doc correction:** `GAME_MODES.md` must not imply **Street** or **Practice** produce **`last_session_result.json`** without a future “end session” action.

---

## 2. Scoring & physics

| Area | Behaviour | QA risk |
|------|-----------|---------|
| **Hoop volume** | Overlap with **`AFELBasketballActor` only**; per-volume cooldown `ScoreCooldownSeconds` | Pawn body overlapping volume does not score (good). Two balls + two volumes: OK. Same volume + two balls same tick: second often blocked by cooldown (good). |
| **Points per bucket** | `PointsPerBucket` (default 1) | If set &gt; 1, can overshoot target in one tick — usually acceptable. |
| **Match end** | `AddScore` / `TickMatchTime` → `EndMatch` | Idempotent; duplicate `EndMatch` safe. |
| **Input lock** | Move + look ignored after end | **Jump** and other actions **not** disabled — player can still jump; low severity polish. |
| **Ball spawn** | First **`PlayerStart`** in `GetAllActorsOfClass` order + offset | Order **undefined** if multiple starts; document “single PlayerStart for deterministic QA.” |
| **Readiness apply** | Timer **0.08s** after `StartPlay` | Late-spawned pawns/balls might miss one apply pass; rare in default flow. |

---

## 3. Economy & export (`FELArenaBridge` / `FELSessionExport`)

| Rule | Implementation | QA status |
|------|------------------|-----------|
| Practice / scoring off | `shardsEarned` / `prqBonus` = 0 | OK |
| Scoring on, score = 0 | Shards floor **≥ 1** via `max(1, …)` | By design (participation); confirm testers expect non-zero shards on 0-bucket Timed Blitz. |
| `prqBonus` score = 0 | Returns **0** (fixed; previously clamped to 0.1) | Aligns with “no buckets → no bonus.” |
| `date` field | Seconds since **2001-01-01 UTC** | Swift: use default `Date` decoding or `.deferredToDate`. |
| Output file | **Overwrites** `Saved/FEL/last_session_result.json` | Not a session history log — one slot only. |
| `duration` | `WorldTimeNow - MatchStartWorldTimeSeconds` | If `ApplyRules` ran with no world, start = 0 → duration inflated — edge case. |

---

## 4. Swift Arena (iOS) — parity (expect **not** 1:1)

| Aspect | Swift (`ArenaView`, `ArenaDunkPlayView`, etc.) | Unreal lab |
|--------|-----------------------------------------------|------------|
| Loop | Charge / commit, PRQ-driven quality, rounds, contests | Physics court, bucket triggers |
| Basketball IDs | `basketball_h2h`, `basketball_3v3`, `basketball_dunk` | Same **string ids** for export/HUD only |
| Dunk | Dedicated dunk phase machine + judges | “First to N” buckets + **Hang Time** label |
| Opponent | Simulated / UI | None (`opponentScore` always 0) |

**QA takeaway:** Validate Unreal on **its own acceptance criteria**; do not expect iOS round flow without extra design.

---

## 5. Recommended test cases (Unreal)

### Smoke

- [ ] Launch PIE / packaged Mac build; no immediate assert/crash.
- [ ] WASD, mouse look, Space jump; ball spawns and rolls.
- [ ] One hoop volume: ball through → score increments; HUD updates.

### Per mode

- [ ] **Half-Court Shootout:** two balls spawn; reach target → end banner; input lock; JSON written.
- [ ] **Timed Blitz:** timer counts down; at 0 → end; 0 buckets → `prqBonus` **0**, shards still ≥ 1 if economy on.
- [ ] **Practice:** score line shows practice text; overlaps **do not** change score.
- [ ] **First to 21:** target 21 (or lower for quick test) ends match; HUD shows **Hang Time** line.
- [ ] **Street:** confirm **no** end state and **no** session file unless you add a stop rule.

### Readiness

- [ ] With **`example_readiness_snapshot.json`** in `Saved/FEL/`: PRQ HUD changes; movement feel differs from default.
- [ ] Without file: defaults (PRQ **75**) still run.

### Regression watch

- [ ] After match end, cannot increase score via hoops (scoring gated on `HasMatchEnded`).
- [ ] Console `~` still available in **Development** builds for logs.

---

## 6. Severity summary

| Sev | Item |
|-----|------|
| **S3 — Doc** | Street / Practice session export expectations (addressed in `GAME_MODES.md`). |
| **S3 — Product** | No “Quit / end session” for Street & Practice → no export; intentional unless spec adds menu. |
| **S2 — Polish** | Jump not disabled at match end. |
| **S2 — Env** | Multiple `PlayerStart` → nondeterministic ball spawn. |
| **S1 — Fixed** | `prqBonus` no longer forced to **0.1** when bucket score is **0**. |

---

## 7. References

- **`GAME_MODES.md`** — mode table + PRQ hooks  
- **`GAME_FINISHED.md`** — playable slice definition  
- **`PACKAGE_AND_TEST.md`** — build & tester handoff  
- **`../VISION_ALIGNMENT.md`** — ecosystem scope  

---

*Audit living document — update when modes or export rules change.*
