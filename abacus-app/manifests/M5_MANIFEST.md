# M5 — Game Parity · MANIFEST

**Milestone:** 5 of 6  
**Track:** Game Parity (fun-loop scaffolding)  
**Date:** 2026-07-15  
**Status:** COMPLETE ✓

---

## What Shipped

### 1. `lib/game-systems.ts` — Client-side Game Systems Module
New unified module providing three composable classes for all 2D canvas and 3D R3F game modes:

| Class | Purpose |
|---|---|
| **ComboTracker** | Chain counting with configurable timing-window decay. Wraps `prq-engine.comboMultiplier()` for the 4/7/10 → 2×/3×/4× ladder. Auto-breaks on timer expiry. |
| **MissGate** | Proximity + QTE-quality gating. Rejects attempts that fail either spatial proximity or minimum quality threshold. Tracks miss/attempt counts. |
| **SessionRecorder** | Accumulates hits/misses/dodges/combos → produces `SessionTallies` for `computeSessionPerformance()` + `computePrqDelta()`. Extra bookkeeping: perfects, bestChain, totalScore for HUD. |
| **createGameSystems()** | Factory that instantiates all three with optional config overrides. |

All gameplay-feel constants tagged `// TUNE(elijah)` — comboWindowMs, proximityThreshold, minQteQuality.

### 2. Dunk Contest — Miss Gating + Combo Integration
`components/games/dunk-game.tsx` patched to use `game-systems.ts`:
- **Miss gating:** QTE quality mapped 0..1; attempts below `minQteQuality` (0.15) are gated out → combo breaks, 0 points, "MISS" message.
- **Combo tracking:** Consecutive successful dunks build chain → multiplier applied to score. HUD shows "N CHAIN · Mx" when chain > 1.
- **Session recording:** Every hit/miss feeds SessionRecorder for end-of-session PRQ delta pipeline.
- Prior behavior: every landing scored (even missed QTE got 0 but still counted). Now: genuine miss/success distinction.

### 3. `/play/karate` Route — Verified Wired
Route already fully mounted: `page.tsx` → `KarateLoader` → `GameShell` with 2D/3D toggle via `is3D('karateEndless')`. No changes needed — confirmed operational.

### 4. Input Contract — Already Standardized
`lib/input-schemes.ts` (205 lines) provides `VCScheme` definitions for all 17 game modes. `VirtualController` + `PhysicalGamepadPoller` funnel through synthetic-keyboard bridge. No additional work needed — already at parity.

---

## Tests & Evidence

| Suite | Tests | Status |
|---|---|---|
| m5-game-smoke.ts | 21 | ✓ ALL PASS |
| m4-tests.ts | 13 | ✓ ALL PASS (no regression) |
| m3-tests.ts | 11 | ✓ ALL PASS (no regression) |
| m2-tests.ts | 9 | ✓ ALL PASS (no regression) |
| tsc --noEmit | 0 errors | ✓ |
| next build | 0 errors, 45+ routes | ✓ |

### M5 Smoke Test Breakdown
```
ComboTracker
  ✓ initial state is zero
  ✓ registerHit increments chain
  ✓ multiplier follows prq-engine ladder (4/7/10)
  ✓ breakCombo resets chain to 0
  ✓ bestChain tracks max
  ✓ update decays window and auto-breaks
  ✓ reset clears everything

MissGate
  ✓ default gate passes decent quality
  ✓ default gate rejects quality below threshold
  ✓ proximity gate rejects too far
  ✓ attemptByQuality ignores proximity
  ✓ reset clears counters

SessionRecorder
  ✓ tallies accumulate correctly
  ✓ reset clears tallies

createGameSystems factory
  ✓ creates all three systems
  ✓ custom options propagate

prq-engine integration
  ✓ comboMultiplier matches ladder
  ✓ computeSessionPerformance produces 0..100 score
  ✓ SessionRecorder tallies feed computeSessionPerformance
  ✓ computePrqDelta returns bounded deltas

End-to-end dunk session simulation
  ✓ simulated dunk session produces valid PRQ delta
```

---

## Files Changed/Added

| Path | Action |
|---|---|
| `lib/game-systems.ts` | **NEW** — ComboTracker, MissGate, SessionRecorder, createGameSystems |
| `components/games/dunk-game.tsx` | **MODIFIED** — miss gating, combo tracking, combo HUD |
| `scripts/m5-game-smoke.ts` | **NEW** — 21 headless smoke tests |

---

## What's Next

**M6 — Studio To Spec** (requires LLM credits):
- Wire CELL Studio LLM-backed code chat + compile endpoints
- Lesson authoring pipeline (nexus-author tooling)
- Adaptive sequencing integration

---

## Open Questions for Elijah

1. **Combo window tuning:** Dunk contest uses 8000ms (generous for turn-based). Karate/skateboard use inline ~500ms. Should these be unified or per-mode?
2. **Miss gate thresholds:** Current minQteQuality = 0.15 (very forgiving). Should this vary by difficulty tier?
3. **Other modes:** 18 remaining 2D games have inline combo/score logic. Priority order for migrating them to `game-systems.ts`?
4. **SessionRecorder → game-shell integration:** Currently dunk-game uses SessionRecorder internally. Should game-shell automatically create GameSystems and pass to all games via GameProps?
