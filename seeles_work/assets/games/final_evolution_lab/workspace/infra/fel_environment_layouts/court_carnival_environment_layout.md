# FEL Staging Mode — court_carnival Environment Layout Spec
## Venue: Venice_Beach_Court | Mode: court_carnival
**Status:** staging → preview | **gamemode_class:** `/Script/FEL.BP_CourtCarnival`
**Map Token:** `/Game/FEL/Venues/VeniceBeach/VeniceBeach`
**Schema Version:** 1.0 | **Source:** fel_environment_layouts_ue57_ios_plan v1.0

---

## 1. Venue Overview

- **Visual Identity:** Sunset Venice boardwalk, warm concrete, cyan-magenta FEL accents, chain-link perimeter, branded backboards, distant palm silhouettes, crowd strips, carnival dressing layer (bunting, neon ring-toss kiosks, overhead string lights).
- **Base Venue Inherited From:** Venice_Beach_Court sublevel. court_carnival loads a dedicated `SL_CourtCarnival` sublevel on top of the shared court shell; basketball-specific props (shot clocks, dunk runway decals, stanchion logos) are disabled via sublevel visibility toggle.
- **Mode Character:** Social party multi-activity loop — players rotate through Around-the-World shooting landmarks, carnival mini-game pads, and social staging zones rather than competing in a single objective lane.
- **iOS Complexity Tier:** Tier B — Mid-Complexity Arena Map (same as Venice_Beach_Court base). Keep total visible triangle budget at or below 950k during peak carnival dressing load.
- **Coordinate System:** Unreal Engine world units (cm). Origin `(0, 0, 0)` is the center-court logo. +X = toward the primary backboard (north). +Y = toward player-right sideline (east). +Z = up.

---

## 2. Interactive Object Coordinates

All objects listed below require a `UTriggerVolume` (radius 120 cm unless noted) and an `UInteractableComponent` with a single readable prompt face (+X forward by default).

### 2.1 Around-the-World Shooting Landmarks
Seven canonical landmark positions define the Around-the-World circuit. Each has a `BP_ATW_LandmarkPost` actor with embedded score trigger, FEL holographic ring indicator, and per-station shot arc decal.

| Station ID | Label | World Position (X, Y, Z) | Facing | Notes |
|---|---|---|---|---|
| `ATW_01` | Right Corner | (620, 660, 0) | −X, −Y | Tight angle corner 3; concrete painted arc |
| `ATW_02` | Right Wing | (480, 520, 0) | −X, −Y | Mid-range wing; overlaps party apron edge |
| `ATW_03` | Right Elbow | (300, 310, 0) | −X, −Y | High elbow; clear sightline to rim |
| `ATW_04` | Top of the Key | (0, 0, 0) | −X | Center key top; shares space with center logo |
| `ATW_05` | Left Elbow | (300, −310, 0) | −X, +Y | Mirror of ATW_03 |
| `ATW_06` | Left Wing | (480, −520, 0) | −X, +Y | Mirror of ATW_02 |
| `ATW_07` | Left Corner | (620, −660, 0) | −X, +Y | Mirror of ATW_01 |

- **Trigger Radius:** 150 cm per station (wider than default for carnival readability).
- **Activation Rule:** `BP_ATW_Sequencer` validates stations must be hit in order 01→07 for full circuit bonus; freestyle mode ignores order.
- **LOD Rule:** `BP_ATW_LandmarkPost` LOD1 transitions at 800 cm camera distance; LOD2 at 1800 cm. Total poly budget per post: ≤ 3,200 tris at LOD0.

### 2.2 Carnival Mini-Game Pads
Placed in the support ring (sideline apron, east and west) and activated by stepping on trigger floors.

| Pad ID | Type | World Position (X, Y, Z) | Footprint (cm) | Facing |
|---|---|---|---|---|
| `CMP_01` | Ring Toss Kiosk | (−420, 760, 0) | 200 × 180 | −Y (faces court) |
| `CMP_02` | Free Throw Blitz | (−560, 0, 0) | 250 × 200 | +X (faces key) |
| `CMP_03` | Ring Toss Kiosk | (−420, −760, 0) | 200 × 180 | +Y (faces court) |
| `CMP_04` | Trick Shot Ramp | (650, 0, 0) | 300 × 260 | −X (faces baseline) |
| `CMP_05` | Score Blitz Pad | (0, 760, 0) | 220 × 220 | −Y (faces court) |
| `CMP_06` | Score Blitz Pad | (0, −760, 0) | 220 × 220 | +Y (faces court) |

- **Activation:** `BP_CarnivalPad_Trigger` floor tile, emissive color pulse (cyan idle → magenta active).
- **Hard Collision:** Kiosk frames, ramp structure; soft collision on decorative bunting and string light cables.
- **Reset Volume:** Each pad has a 320 cm radius `UKillVolume` beneath it to catch fall-throughs.

### 2.3 Pickup / Collectible Nodes
Rotating collectibles spawned by `BP_CarnivalItemSpawner`. Six fixed spawn positions; items randomized each round.

| Node ID | World Position (X, Y, Z) | Respawn Timer (s) |
|---|---|---|
| `ITM_01` | (180, 400, 80) | 12 |
| `ITM_02` | (180, −400, 80) | 12 |
| `ITM_03` | (−180, 400, 80) | 15 |
| `ITM_04` | (−180, −400, 80) | 15 |
| `ITM_05` | (500, 0, 80) | 18 |
| `ITM_06` | (−500, 0, 80) | 18 |

### 2.4 Scoreboard / Display Props
| Prop ID | Asset | World Position (X, Y, Z) | Scale | Notes |
|---|---|---|---|---|
| `SBD_01` | `SM_FEL_ScoreboardLarge` | (−780, 0, 460) | 1.0 | North end, always-visible |
| `SBD_02` | `SM_FEL_ScoreboardSmall` | (780, 0, 380) | 0.8 | South baseline |
| `LDB_01` | `SM_FEL_LeaderPylon` | (0, 780, 0) | 1.0 | East sideline center |
| `LDB_02` | `SM_FEL_LeaderPylon` | (0, −780, 0) | 1.0 | West sideline center |

---

## 3. Around-the-World Shooting Landmarks — Extended Detail

### 3.1 Circuit Flow
```
ATW_01 (Right Corner) → ATW_02 (Right Wing) → ATW_03 (Right Elbow)
    → ATW_04 (Top of Key) → ATW_05 (Left Elbow) → ATW_06 (Left Wing)
    → ATW_07 (Left Corner) → [CIRCUIT COMPLETE]
```
- Full circuit fires `OnATWCircuitComplete` delegate → awards `SHARD_BONUS_ATW = 75`.
- Partial circuit (≥ 4 stations) fires `OnATWPartialComplete` → awards `SHARD_BONUS_ATW_PARTIAL = 30`.

### 3.2 Per-Station Shot Properties
| Station | Shot Distance (cm) | Recommended Aim Assist Cone (°) | Score Value (base) |
|---|---|---|---|
| ATW_01 / ATW_07 | 680 | 8 | 3 pts |
| ATW_02 / ATW_06 | 540 | 9 | 2 pts |
| ATW_03 / ATW_05 | 360 | 10 | 2 pts |
| ATW_04 | 490 | 9 | 2 pts |

### 3.3 Visual Guidance System
- `BP_ATW_LandmarkPost` emits a **floor halo decal** (radius 80 cm) at idle state.
- When a station is active in sequence: halo pulses cyan; holographic ring floats 220 cm above floor.
- When a station is completed: halo locks magenta; post plays a 1.2s burst particle.
- Completed station overlays a persistent check glyph on the HUD `StatTicker` via WebSocket event `atw_station_update`.

### 3.4 Landmark Collision Rules
- Each `BP_ATW_LandmarkPost` base uses a 40 cm radius cylinder hard collision to prevent players from standing inside the post.
- No hard collision above 120 cm to avoid obstructing shot arcs.
- Post mesh backface is transparent-culled; players approaching from behind still see prompt.

---

## 4. Social Spawn Points

### 4.1 Spawn Classification
court_carnival uses **Spawn Type C — Spectator/Party Spawn** as the primary entry because there is no competing objective at match start — all players begin in the social hub state.

### 4.2 Named Spawn Points
| Spawn ID | Label | World Position (X, Y, Z) | Forward Vector | Capacity | Type |
|---|---|---|---|---|---|
| `SP_SOCIAL_01` | Center Hub — North | (−200, 0, 0) | +X | 2 | Party/social entry |
| `SP_SOCIAL_02` | Center Hub — South | (200, 0, 0) | −X | 2 | Party/social entry |
| `SP_SOCIAL_03` | East Apron Social | (0, 600, 0) | −Y | 2 | Sideline social |
| `SP_SOCIAL_04` | West Apron Social | (0, −600, 0) | +Y | 2 | Sideline social |
| `SP_ATW_START` | ATW Circuit Entry | (680, 700, 0) | −X, −Y | 1 | Around-the-World start |
| `SP_CARNIVAL_A` | East Carnival Apron | (−350, 680, 0) | −Y | 2 | Carnival pad zone |
| `SP_CARNIVAL_B` | West Carnival Apron | (−350, −680, 0) | +Y | 2 | Carnival pad zone |
| `SP_RESET_01` | Baseline Reset — North | (−730, 0, 0) | +X | 4 | Reset spawn (all modes) |
| `SP_RESET_02` | Baseline Reset — South | (730, 0, 0) | −X | 4 | Reset spawn (all modes) |
| `SP_SPECTATE_01` | Bleacher Row A | (−820, 350, 120) | +X, −Y | 4 | Spectator (non-competitive) |
| `SP_SPECTATE_02` | Bleacher Row B | (−820, −350, 120) | +X, +Y | 4 | Spectator (non-competitive) |

### 4.3 Spawn Rules
- No two social spawns within 180 cm of each other after all players are placed.
- `SP_ATW_START` is reserved; only the active ATW circuit challenger may occupy it.
- Spectator spawns (`SP_SPECTATE_*`) are disabled in 1v1 competitive fallback mode.
- Minimum 200 cm clear radius around each spawn — no carnival props, VFX emitters, or kiosk collision within radius.

---

## 5. Camera Zones

| Zone ID | Type | Coverage Center (X, Y, Z) | Extent (X, Y, Z) | Trigger Condition |
|---|---|---|---|---|
| `CAM_DEFAULT` | Social Browse | (0, 0, 120) | (1200, 1400, 400) | Default on load |
| `CAM_ATW_WIDE` | Gameplay — ATW | (400, 0, 200) | (900, 1400, 300) | ATW circuit active |
| `CAM_ATW_HERO` | Hero Shot | Station XY +Z 60 | (120, 120, 180) | Ball released at station |
| `CAM_CARNIVAL_E` | Mini-game East | (−420, 760, 60) | (300, 220, 220) | CMP_01/05 active |
| `CAM_CARNIVAL_W` | Mini-game West | (−420, −760, 60) | (300, 220, 220) | CMP_03/06 active |
| `CAM_TRICKTSHOT` | Hero Trick Shot | (650, 0, 200) | (280, 260, 300) | CMP_04 launch |
| `CAM_RESULT` | Round Result | (0, 0, 300) | (1400, 1600, 500) | Round end event |

- `CAM_ATW_HERO` is per-station: position offsets to be 300 cm behind the active ATW station's approach vector. Duration: 2.2s max.
- Camera zone transitions must not occur within a 1.8s window of a shot timing input.

---

## 6. Collision Volume Summary

| Volume ID | Type | Shape | World Position (X, Y, Z) | Extent or Radius |
|---|---|---|---|---|
| `COL_COURT_FLOOR` | Hard | Box | (0, 0, −2) | (780, 750, 4) |
| `COL_NORTH_WALL` | Hard | Box | (−850, 0, 200) | (10, 850, 400) |
| `COL_SOUTH_WALL` | Hard | Box | (850, 0, 200) | (10, 850, 400) |
| `COL_EAST_FENCE` | Soft | Box | (0, 800, 200) | (850, 10, 400) |
| `COL_WEST_FENCE` | Soft | Box | (0, −800, 200) | (850, 10, 400) |
| `COL_BLEACHER_E` | Hard | Box | (−750, 450, 100) | (120, 300, 200) |
| `COL_BLEACHER_W` | Hard | Box | (−750, −450, 100) | (120, 300, 200) |
| `RST_NORTH_OOB` | Kill/Reset | Box | (−950, 0, 0) | (100, 1000, 600) |
| `RST_SOUTH_OOB` | Kill/Reset | Box | (950, 0, 0) | (100, 1000, 600) |
| `RST_EAST_OOB` | Kill/Reset | Box | (0, 900, 0) | (1000, 100, 600) |
| `RST_WEST_OOB` | Kill/Reset | Box | (0, −900, 0) | (1000, 100, 600) |

---

## 7. Sublevel Composition
- `SL_VeniceBeach_Shell` — shared court floor, fence, bleachers, sky, and palm backdrop. Always loaded.
- `SL_CourtCarnival_Dressing` — carnival bunting, string lights, kiosk meshes, `BP_ATW_LandmarkPost` actors, `BP_CarnivalPad_Trigger` floors. Loaded only for `court_carnival`.
- `SL_Basketball_Dressing` — shot clocks, dunk decals, stanchion branding. **Unloaded** for `court_carnival`.
- `SL_CourtCarnival_FX` — ambient FX: firefly particles, mid-air confetti loop, sunset lens bloom. Keep total emitter count ≤ 8 for iOS.

---

## 8. iOS Performance Notes
- Venice_Beach_Court base is Tier B. Carnival dressing (`SL_CourtCarnival_Dressing`) adds approx +120k triangles at peak view. Stay within 950k total.
- String lights use `SM_StringLight_Segment` card mesh (4 tris each) on a spline, not individual emissive sphere meshes.
- Carnival kiosks share one `MI_CarnivalKiosk_Master` material instance; no unique per-kiosk texture sheets.
- Confetti FX in `SL_CourtCarnival_FX`: GPU particle emitter, max 400 particles, no collision simulation.

---

## 9. Map Smoke Checklist — court_carnival

- [ ] `SL_CourtCarnival_Dressing` loads cleanly; `SL_Basketball_Dressing` confirms hidden.
- [ ] All 7 `BP_ATW_LandmarkPost` actors present, halo decals visible from `SP_ATW_START`.
- [ ] ATW sequencer fires `OnATWCircuitComplete` on stations 01→07 hit in order.
- [ ] All 6 `BP_CarnivalPad_Trigger` floors activate on player step.
- [ ] No social spawn overlaps a kiosk hard collision volume.
- [ ] `CAM_ATW_HERO` zone does not persist beyond 2.2s.
- [ ] All OOB reset volumes (`RST_*`) return player to nearest `SP_RESET_*`.
- [ ] String light spline: zero performance warnings on iOS sim at 3-minute mark.
- [ ] Confetti emitter stays ≤ 400 GPU particles during peak carnival pad activity.
- [ ] Sublevel `SL_CourtCarnival_FX` disables cleanly on mode exit without orphaned emitters.
