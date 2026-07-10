# Basketball 3v3 — Mode Design Document

**Mode ID:** `basketball_3v3`  
**Format:** 21-point game, 3 players per side  
**Accent Color:** `#FF9900` (burnt orange)  
**Status:** Production

---

## Game Loop

Team game to 21. Players control a lead ball-handler; two AI teammates run set plays. Opponent runs a symmetric AI squad. Possession alternates on makes.

### Team Mechanics

#### Fatigue System
Each player has a `stamina` value (0.0–1.0). Sprinting, driving, and posting up burn stamina. Fatigue reduces make probability and drive success rate:
```
effectiveMake% = baseMake% × (0.6 + stamina × 0.4)
```
Stamina recovers when player rests (bench sub or non-possession).

#### Substitutions
Three bench players available. Subbing in resets the substituted player's stamina to 1.0 but the benched player begins recovery at their current value. Sub UI appears as a slide-up panel.

#### Hot Zones
The court is divided into 6 zones. The lead player accumulates a zone-specific heat index per make from that zone. When heat index ≥ 3 in a zone, that zone glows and grants +10% make probability for shots from it.

---

## Set Plays

The player selects a set play from a 4-option menu (appears on offense). AI teammates execute the blocking/screening pattern autonomously.

| Play | Description | Success bonus |
|------|-------------|--------------|
| Pick & Roll | Teammate screens; ball handler drives lane | +15% drive |
| Corner Cut | Weak-side teammate cuts for open 3 | +20% 3PT |
| Post Up | Center posts; kick-out option | +12% mid-range |
| Fast Break | Push transition after turnover | +25% layup |

---

## Drive Mechanic

Player can initiate a drive when momentum ≥ 1. Drive outcome is determined by:
- `driveQuality` (swipe speed × direction accuracy)  
- Opponent's current fatigue  
- Active set play bonus

Drive paths: Lane finish (×1.5 pt weight), Kick-out 3, Contact (And-1 chance 20%).

---

## Hype System

`hypeLevel` (0–100) builds on dunks, hot zone makes, And-1s, and blocked shots. At 100:
- **HYPE BURST** triggers full-court confetti
- All five players' stamina temporarily boosted +0.3
- Next shot from any hot zone has 98% make chance
- Resets to 0 after burst

---

## Highlight Slow-Mo

On scoring plays that include a dunk, alley-oop, or And-1:
- Game freezes for 0.4s
- A slow-motion replay vignette slides in from right (0.3× playback via `speed(0.3)` on animation)
- `triggerShake(18)` + `triggerBurst(.yellow, 20)` fire on resume

---

## Server Integration

3v3 uses the same match lifecycle as H2H. The `mode_id` is `basketball_3v3`.

`match_start.players[]` includes all six player slots (3 per team). In mock mode, teams are auto-filled with AI players.

Team loadout is aggregated:
```
teamModifiers = average(compute_loadout_modifiers(p.loadout) for p in team)
```

PRQ delta uses team win, not individual:
```
prqDelta = isWin ? 4.0 : −2.0   (team game earns more PRQ)
```

---

## Visual Effects

| Event | Shake | Burst | Label |
|-------|-------|-------|-------|
| Team make | 8 | orange 12 | "+1" / "+2" / "+3" |
| Drive finish (And-1) | 14 | orange 18 | "AND-1!" |
| Alley-oop | 18 | yellow 20 | "ALLEY-OOP!" |
| Hype burst | 22 | yellow 28 | "HYPE BURST!" + confetti |
| Block | 12 | cyan 14 | "BLOCKED!" |
| Sub in | — | — | Sub card slide-up |
| Hot zone ignites | — | — | Zone glow overlay |

---

## Acceptance Criteria

- [ ] Fatigue drains correctly on drives and sprints, recovers on rest
- [ ] Sub UI swaps stamina values correctly
- [ ] Set plays trigger teammate movement animations
- [ ] Hot zone heat index persists correctly across possessions
- [ ] Hype meter fills and fires burst at exactly 100
- [ ] Highlight slow-mo triggers only on eligible plays
- [ ] PRQ delta of +4.0 written on win
- [ ] `export-replay` includes all team scoring events

---

## Known Capability Gaps

| Feature | Gap | Effort |
|---------|-----|--------|
| True 3v3 multiplayer | Single player vs AI only; no P2P | 6–10 wk (dedicated server + matchmaking) |
| Teammate AI pathfinding | Set plays are scripted animations, not real pathfinding | 3 wk (GKAgent2D) |
| 3D court rendering | 2D Canvas top-down | 4–6 wk (SceneKit) |
| Spatial audio positional | Crowd noise is mono | 1 wk (AVAudioEngine 3D) |
| Real-time physics collision | Parametric arc, no box2D | 3 wk (custom integrator) |
