# Basketball Dunk Contest — Mode Design Document

**Mode ID:** `basketball_dunk`  
**Format:** 3 attempts, 3-judge panel (max 30 pts per dunk, 90 total)  
**Accent Color:** `#FF9900` (burnt orange)  
**Status:** Production

---

## Game Loop

Player selects a dunk style, performs an approach phase, then an execution phase. Three AI judges score each dunk. The server derives judge scores deterministically from the match seed, so replay is bit-exact.

### Dunk Styles (7 total)

| Style | Difficulty | Label |
|-------|-----------|-------|
| 360 Windmill | 1.0 | "360 WINDMILL" |
| Between Legs | 0.9 | "BETWEEN THE LEGS" |
| Reverse Jam | 0.8 | "REVERSE JAM" |
| Tomahawk | 0.7 | "TOMAHAWK" |
| Alley-Oop | 0.75 | "ALLEY-OOP" |
| Finger Roll | 0.5 | "FINGER ROLL" |
| Power Slam | 0.6 | "POWER SLAM" |

`style_difficulty` (0.0–1.0) scales the judge score ceiling via:
```
base = (approach × 0.40 + execution × 0.60) × 50 × (0.7 + style_difficulty × 0.3)
```

---

## Approach Phase

Player taps a moving power bar. Tap position maps to `approach_quality` (0.0–1.0):
- Left 10% → 0.0–0.2 (too early)
- Center zone → 0.7–1.0 (green)
- Right 10% → 0.0–0.3 (too late)

---

## Execution Phase

Player swipes up on a timing arc. Swipe velocity and release angle produce `execution_quality` (0.0–1.0). This is the dominant factor in the scoring formula (60% weight).

---

## Server-Side Scoring

The server scores each dunk authoritatively via `POST /api/matches/{match_id}/score_dunk`.

### Scoring Formula
```python
base = clamp((approach × 0.40 + execution × 0.60) × 50 × (0.7 + style × 0.3), 0, 50)
j_i  = clamp(round(base/50 × 10 + judge_offset_i), 3, 10)
total = j1 + j2 + j3   # range: 9–30
```

### Judge Offsets
Derived deterministically from match seed:
```python
judge_offsets = derive_judge_offsets(match.seed)  # 3 ints in [−5, +5]
```
All three judges share a single seed per match; offsets are fixed for the entire match (i.e., a judge who scored generously on dunk 1 will score generously on dunk 3).

### Score Messages
| Total | Message |
|-------|---------|
| 28–30 (all ≥ 9) | PERFECT SCORE |
| 28–30 | OUTSTANDING |
| 24–27 | OUTSTANDING |
| 18–23 | SOLID DUNK |
| < 18 | NEEDS WORK |

---

## Creator Card Modifiers

`compute_loadout_modifiers(loadout)` is called at match start and sent in `match_start.players[].computed_modifiers`. Key fields:

| Card | Effect on Dunk |
|------|---------------|
| `iron_grip` | +0.08 to execution_quality |
| `clutch_gene` | +0.12 to execution_quality |
| `sky_walker` | ×1.25 jump multiplier (visual only; affects approach quality bonus) |
| `beast_mode` | ×1.10 speed + jump |

The iOS client should apply `execution_bonus` before calling the score endpoint:
```swift
let effectiveExecution = min(1.0, rawExecution + computedModifiers.execution_bonus)
```

---

## Visual Effects

| Event | Shake | Burst | Label |
|-------|-------|-------|-------|
| Dunk lands | 14 | orange 14 | Score display |
| PERFECT (≥28, all 9+) | 20 | yellow 20 | "PERFECT!" + confetti |
| OUTSTANDING (24–27) | 16 | orange 16 | "OUTSTANDING!" |
| Judge reveal | 10 | — | Judge score cards animate in |
| Style select | — | — | Style card flip |

---

## Replay Export

```
GET /api/matches/{match_id}/export-replay
```
Returns:
```json
{
  "match_id": "...",
  "seed": 12345678901234,
  "judge_offsets": [2, -1, 4],
  "events": [
    { "type": "match_start", ... },
    { "type": "dunk_result", "j1": 9, "j2": 8, "j3": 10, "total": 27 },
    ...
  ],
  "metadata": { "export_version": "1.0", "event_count": 5 }
}
```
Seeded replay: replay the match with the same `judge_offsets` to reproduce identical scores.

---

## Acceptance Criteria

- [ ] Judge offsets are identical for same seed across two independent calls
- [ ] `score_dunk` endpoint returns 200 with `j1/j2/j3/total/message`
- [ ] `dunk_result` event persisted to match event log
- [ ] Perfect dunk (approach=1.0, execution=1.0, style=1.0, offsets=[5,5,5]) → total=30
- [ ] Min dunk (approach=0.0, execution=0.0, offsets=[0,0,0]) → all judges ≥ 3
- [ ] `export-replay` returns `match_start` event with seed
- [ ] Creator card `execution_bonus` applied client-side before POST
- [ ] No UI freeze during judge reveal animation (all on main thread with `.animation`)

---

## Known Capability Gaps

| Feature | Gap | Effort |
|---------|-----|--------|
| 3D dunk animation | 2D Canvas stick figure only | 3–5 wk (SpriteKit assets) |
| Crowd reaction audio | No AVAudioEngine integration | 1 wk |
| Multiplayer simultaneous dunks | Sequential only; no real-time sync | 4 wk (UDP game server) |
| Slow-motion replay | No video buffer; no Metal frame capture | 6 wk |
