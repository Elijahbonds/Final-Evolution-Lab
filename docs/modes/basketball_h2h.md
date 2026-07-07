# Basketball H2H — Mode Design Document

**Mode ID:** `basketball_h2h`  
**Target Score:** 21 points  
**Accent Color:** `#FF9900` (burnt orange)  
**Status:** Production

---

## Game Loop

First player to 21 points wins. Possession alternates each bucket. AI opponent scales across four difficulty tiers (Rookie → Pro → Elite → Legend).

### Scoring
| Shot Type | Points |
|-----------|--------|
| Regular make | +1 |
| Three-pointer | +3 |
| And-1 dunk | +2 |
| Posterize dunk | +2 |

### Shot Timing Meter
The player taps at the apex of a moving arc. Timing rating maps to make probability:

| Rating | Make % |
|--------|--------|
| PERFECT | 98% |
| GOOD | 78% |
| EARLY | 42% |
| LATE | 38% |
| RUSHED | 20% |

### Hot Hand System
Three consecutive makes activates **Hot Hand**. While active, GOOD shots are upgraded to PERFECT probability and a visual fire effect plays. A miss or turnover resets the streak.

### Combo Multiplier
Consecutive makes stack a multiplier (1× → 2× → 3× → 4× max). Multiplier feeds the combo-point feedback label and momentum system — it does **not** multiply raw score, only the PRQ gain calculation.

### Momentum System
`playerMomentum` ranges from −3 to +3.  
- +1 per make (capped at +3)  
- −1 per miss (floor −3)  
- Legend AI reads momentum; if player is on a hot streak, AI gets temporary boost to mimic real defensive adjustments.

### Clutch Time
When either player reaches 18+ (within 3 of 21), the **CLUTCH TIME** overlay activates:
- Red vignette radial gradient pulses at screen edges
- `impactRigid` haptic fires once on activation
- Deactivates when game resets (new game)

### Dunk System
Two special shot outcomes on high-quality attempts with above-average momentum:
- **Posterize Dunk** — 15% chance when quality > 0.8; screen shake `triggerShake(16)` + `triggerBurst(orange, 20)` + "AND-1!" label
- **And-1** — additional +1 point added to basket total

---

## Server Integration

### Match Lifecycle
```
POST /api/matches/create   { mode_id: "basketball_h2h" }
POST /api/matches/join     { match_id }
GET  /api/matches/{id}     → { seed, judge_offsets, ... }
WS   /ws/match/{id}        → live score_events
POST /api/matches/{id}/save-result
GET  /api/matches/{id}/export-replay
```

### Deterministic Seed
Each match has a 64-bit `seed` generated at creation. The seed drives:
- AI's RNG streak (prevents identical AI behavior across replays)
- Replay reconstruction (same seed = identical AI decisions)

### PRQ Delta Formula
```
prqDelta = baseGain × comboMultiplier × (1 + cardExecutionBonus)
baseGain  = isWin ? 3.0 : −1.5
```

---

## Visual Effects

| Event | Shake | Burst | Label |
|-------|-------|-------|-------|
| Make | 8 | orange 12 | "+1" / "+3" |
| Posterize dunk | 16 | orange 20 | "AND-1!" |
| Hot hand ignites | 12 | orange 16 | "HE'S COOKING" |
| Opponent scores | 10 | — | — |
| Win | 20 | yellow 24 | Victory confetti |

### Confetti
On P1 victory, `ResultScreen` triggers 55-piece GPU-rendered confetti rain via `TimelineView(.animation) + Canvas`. Runs for 5 seconds then fades.

---

## AI Behavior by Difficulty

| Tier | Make % | 3PT chance | Dunk chance | Comeback logic |
|------|--------|------------|-------------|----------------|
| Rookie | 35% | 10% | 5% | None |
| Pro | 52% | 20% | 12% | Soft (±5%) |
| Elite | 68% | 32% | 20% | Moderate (±10%) |
| Legend | 80% | 45% | 28% | Aggressive (momentum-aware) |

---

## Acceptance Criteria

- [ ] First to 21 wins; game resets cleanly
- [ ] Hot hand activates exactly on the 3rd consecutive make
- [ ] CLUTCH TIME overlay appears ≤ 50ms after score crosses 18
- [ ] Posterize dunk fires burst + shake and awards correct points
- [ ] PRQ delta written to `game_results` via `GameResultService`
- [ ] `export-replay` returns seed, all events, and match metadata
- [ ] No frame drops below 55fps during burst animations (Xcode gauge)

---

## Known Capability Gaps (AAA Roadmap)

| Feature | Gap | Effort | Path |
|---------|-----|--------|------|
| GPU skinning / bone animation | SwiftUI Canvas is CPU; no skeleton | 3–5 wk | Migrate to SpriteKit or Metal |
| Spatial crowd audio | AVAudioEngine not integrated | 1–2 wk | Add `SpatialAudioEngine.swift` |
| Real-time authoritative physics | FastAPI async not game-tick capable | 4–8 wk | Dedicated UDP game server (Go/Rust) |
| Ball arc physics (realistic drag) | Current: parametric curve | 2 wk | Integrate GameplayKit GKAgent or custom integrator |
| Android AAB | iOS-only Swift project | 8–12 wk | Full React Native or Flutter port |
