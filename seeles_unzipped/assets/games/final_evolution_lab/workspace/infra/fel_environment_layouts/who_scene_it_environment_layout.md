# FEL Staging Mode — who_scene_it Environment Layout Spec
## Venue: Neuro_Arena | Mode: who_scene_it
**Status:** staging → preview | **gamemode_class:** (pending; inherits Neuro_Arena base)
**Map Token:** `/Game/FEL/Venues/NeuroArena/NeuroArena`
**Schema Version:** 1.0 | **Source:** fel_environment_layouts_ue57_ios_plan v1.0

---

## 1. Venue Overview

- **Visual Identity:** Neon cerebral arena, dark clinical shell, cyan pulse-line flooring, modular holographic media screens, suspended spotlight rigs, quiz-show energy with FEL esports aesthetic.
- **Base Venue Inherited From:** Neuro_Arena sublevel (shared with `brain_brawl`). `who_scene_it` loads a dedicated `SL_WhoSceneIt` sublevel that replaces brain_brawl podiums with media screen towers, contestant platforms, and a cinematic reveal stage.
- **Mode Character:** Scene-identification / media trivia show. Players view a presented media clip on large screens, identify the source (film, game, scene), and buzz-in from their contestant platform. Host camera sweeps punctuate round beats.
- **iOS Complexity Tier:** Tier B — Mid-Complexity Arena Map. Media screens render to `UTextureRenderTarget2D` at 512 × 288 to stay within iOS memory constraints.
- **Coordinate System:** Same as court_carnival. Origin `(0, 0, 0)` is center stage floor. +X = toward host/reveal wall (north). +Y = contestant-right (east). +Z = up.

---

## 2. Media Screen Placements

All screens are `BP_FEL_MediaScreen` actors containing a `UStaticMeshComponent` (flat panel) + `UMediaPlayerComponent` + `UMaterialInstanceDynamic` (render target display surface).

### 2.1 Primary Reveal Screen (Hero Screen)
The dominant media source that presents the scene clip to all players.

| Property | Value |
|---|---|
| Actor ID | `MSC_HERO_01` |
| World Position (X, Y, Z) | (−860, 0, 480) |
| Rotation (Pitch, Yaw, Roll) | (0°, 0°, 0°) — faces +X (toward contestants) |
| Physical Size | 640 cm wide × 360 cm tall |
| Render Target Resolution | 1024 × 576 (hero only; all others 512 × 288) |
| Material Slot | `MI_HeroScreen_Master` |
| Visibility State | `IDLE`: static FEL logo loop; `REVEAL`: plays `UMediaSource` asset; `RESULT`: freeze-frame + overlay |
| Emissive Intensity | 2.4 (idle), 3.8 (reveal) |
| LOD Rule | No LOD; always full res — this is the primary focal prop |

### 2.2 Flanking Commentary Screens (Secondary)
Two screens flanking the hero screen display contestant camera feeds, score counters, and reaction overlays.

| Actor ID | World Position (X, Y, Z) | Rotation (Yaw) | Physical Size | Render Target | Purpose |
|---|---|---|---|---|---|
| `MSC_FLANK_L` | (−820, 520, 420) | 25° (angled toward center) | 320 cm × 180 cm | 512 × 288 | Left contestant feed / score |
| `MSC_FLANK_R` | (−820, −520, 420) | −25° | 320 cm × 180 cm | 512 × 288 | Right contestant feed / score |

### 2.3 Contestant Answer Preview Screens
Smaller screens mounted above each contestant platform. Shows the active question category, buzz-in state, and answer feedback.

| Actor ID | World Position (X, Y, Z) | Rotation (Yaw) | Physical Size | Render Target | Purpose |
|---|---|---|---|---|---|
| `MSC_CTX_01` | (300, 560, 300) | 180° (faces stage) | 180 cm × 100 cm | 512 × 288 | Contestant 1 answer screen |
| `MSC_CTX_02` | (300, 0, 300) | 180° | 180 cm × 100 cm | 512 × 288 | Contestant 2 answer screen |
| `MSC_CTX_03` | (300, −560, 300) | 180° | 180 cm × 100 cm | 512 × 288 | Contestant 3 answer screen |
| `MSC_CTX_04` | (300, −560, 300) | 180° | 180 cm × 100 cm | 512 × 288 | Contestant 4 (optional; disabled at < 4 players) |

### 2.4 Ambient Atmosphere Screens
Decorative panels on the outer ring that display animated FEL branding loops, not interactive.

| Actor ID | World Position (X, Y, Z) | Physical Size | Notes |
|---|---|---|---|
| `MSC_AMB_01` | (0, −900, 520) | 260 cm × 146 cm | South wall atmosphere panel |
| `MSC_AMB_02` | (0, 900, 520) | 260 cm × 146 cm | North wall atmosphere panel |
| `MSC_AMB_03` | (500, 700, 360) | 180 cm × 100 cm | NE column face |
| `MSC_AMB_04` | (500, −700, 360) | 180 cm × 100 cm | NW column face |

- Ambient screens use a single shared `MI_AmbientScreen_Master` with `UTexture2D` flipbook — no real-time render target; safe for iOS.
- All ambient screens disable emissive intensity to 0.6 during `REVEAL` phase to avoid competing with `MSC_HERO_01`.

### 2.5 Media Screen Activation States
```
IDLE       → Static FEL logo loop on all screens. Emissive at rest level.
BRIEFING   → MSC_HERO_01 shows category card; MSC_CTX_* show player names + scores.
REVEAL     → MSC_HERO_01 plays clip; MSC_FLANK_* show contestant cam feeds.
             MSC_AMB_* dim to 0.6 emissive. Clip duration: 8–15s.
BUZZ_IN    → Active contestant MSC_CTX_* pulses cyan. Others hold BRIEFING state.
RESULT     → MSC_HERO_01 freeze-frame; correct answer overlay drawn via UMG widget.
             MSC_CTX_* show correct / incorrect glyph per contestant.
ROUND_END  → All screens play shared celebration or round-complete loop asset.
```

---

## 3. Contestant Positioning

### 3.1 Contestant Platforms
Each contestant stands on a raised `BP_ContestantPlatform` actor with embedded `UTriggerVolume` (buzz-in zone), score display, and per-platform spotlight.

| Platform ID | Contestant Slot | World Position (X, Y, Z) | Platform Height (Z offset) | Spotlight Color |
|---|---|---|---|---|
| `PLT_C1` | Contestant 1 | (320, 560, 0) | +60 cm raised plinth | Cyan `#00E5FF` |
| `PLT_C2` | Contestant 2 | (320, 0, 0) | +60 cm raised plinth | Cyan `#00E5FF` |
| `PLT_C3` | Contestant 3 | (320, −560, 0) | +60 cm raised plinth | Cyan `#00E5FF` |
| `PLT_C4` | Contestant 4 (optional) | (320, −840, 0) | +60 cm raised plinth | Magenta `#FF00C8` |

- Platform plinths: 200 cm × 120 cm footprint, hard collision on all faces.
- Each platform emits a subtle idle emissive rim light at `0.8` intensity; pulses to `3.5` on buzz-in.
- Contestant 4 platform activates/deactivates dynamically; mesh visibility and collision driven by `bFourthContestantActive` flag on `BP_WhoSceneIt_GameMode`.

### 3.2 Contestant Spawn Points (Linked to Platforms)
Contestants spawn at their assigned `SP_CONTESTANT_*` then walk-animate to their platform. Spawn points are offset 160 cm behind the platform.

| Spawn ID | Linked Platform | World Position (X, Y, Z) | Forward Vector |
|---|---|---|---|
| `SP_CONTESTANT_01` | PLT_C1 | (480, 560, 0) | −X (faces stage) |
| `SP_CONTESTANT_02` | PLT_C2 | (480, 0, 0) | −X |
| `SP_CONTESTANT_03` | PLT_C3 | (480, −560, 0) | −X |
| `SP_CONTESTANT_04` | PLT_C4 | (480, −840, 0) | −X |

### 3.3 Host Position
| Actor ID | World Position (X, Y, Z) | Rotation (Yaw) | Notes |
|---|---|---|---|
| `HOST_STAND` | (−280, 0, 0) | 180° (faces contestants) | Host presenter position; `BP_HostPresenterMarker` |
| `SP_HOST` | (−320, 0, 0) | 0° | Host spawn — faces `MSC_HERO_01` on load |

- Host position is a non-player marker in single-player / AI-host mode.
- In multiplayer host mode, `SP_HOST` functions as a standard Spawn Type A for the human host player.

### 3.4 Buzz-In Trigger Volumes
Each platform has an embedded `UBoxComponent` trigger that fires `OnBuzzIn(ContestantSlot)`.

| Trigger ID | Linked Platform | Trigger Extent (X, Y, Z) | Activation Method |
|---|---|---|---|
| `BZZ_01` | PLT_C1 | (100, 100, 160) | Tap input on platform surface |
| `BZZ_02` | PLT_C2 | (100, 100, 160) | Tap input |
| `BZZ_03` | PLT_C3 | (100, 100, 160) | Tap input |
| `BZZ_04` | PLT_C4 | (100, 100, 160) | Tap input |

- Only one buzz-in trigger can fire per REVEAL phase (lock-out logic in `BP_WhoSceneIt_GameMode.OnBuzzInReceived()`).
- First buzz-in triggers `CAM_BUZZIN_HERO` sweep (see Camera Sweeps below).

---

## 4. Camera Sweeps

All camera sweeps are authored as `ACineCameraActor` + `ULevelSequenceActor` pairs, driven by `BP_WhoSceneIt_CameraDirector`. Each sweep defines entry trigger, duration, blend type, and exit target.

### 4.1 Sweep Catalogue

| Sweep ID | Name | Trigger Event | Duration (s) | Start Position (X, Y, Z) | End Position (X, Y, Z) | FOV (°) | Blend In/Out |
|---|---|---|---|---|---|---|---|
| `SWP_INTRO` | Show Open | Round load complete | 4.0 | (900, −800, 600) | (0, 0, 300) | 55 → 65 | 0.6s ease-in / 0.4s cut |
| `SWP_HERO_REVEAL` | Hero Screen Pull-In | `REVEAL` state begins | 2.5 | (200, 0, 250) | (−600, 0, 350) | 65 → 50 | 0.4s / 0.3s |
| `SWP_BUZZIN_HERO` | Buzz-In Spotlight | `OnBuzzIn` fires | 1.8 | Current cam | PLT_Cx +100Z, −200X | 50 → 42 | 0.3s / 0.2s |
| `SWP_CORRECT` | Correct Answer Reveal | `OnCorrectAnswer` fires | 3.2 | PLT_Cx −200X, +100Z | (−700, 0, 400) | 42 → 72 | 0.2s / 0.8s |
| `SWP_WRONG` | Wrong Answer React | `OnWrongAnswer` fires | 1.4 | Current cam | Host position +200Z | 55 | 0.2s / 0.2s cut |
| `SWP_SCORE_REVEAL` | Round Score Board | `OnRoundEnd` fires | 3.5 | (600, 0, 500) | (−200, 0, 350) | 75 → 60 | 0.5s / 0.6s |
| `SWP_FINAL_WINNER` | Final Winner Sweep | Match end | 5.0 | (800, −600, 700) | (320, WinnerY, 120) | 55 → 35 | 0.8s / 1.0s ease-out |

- `WinnerY` in `SWP_FINAL_WINNER` is resolved at runtime to the winning contestant's platform Y coordinate.
- `SWP_BUZZIN_HERO` start position is parameterized to the currently buzzing contestant's platform; `PLT_Cx` is a runtime variable.
- No two sweeps may be queued simultaneously; `BP_WhoSceneIt_CameraDirector` uses a priority queue — `SWP_CORRECT` overrides `SWP_BUZZIN_HERO` if both trigger within 0.3s.

### 4.2 Default Gameplay Camera Zone (Non-Sweep)
When no sweep is active, the default camera zone provides a stable broadcast angle covering all contestant platforms and `MSC_HERO_01`.

| Zone ID | Type | Coverage Center (X, Y, Z) | Extent (X, Y, Z) | Condition |
|---|---|---|---|---|
| `CAM_DEFAULT` | Broadcast Wide | (0, 0, 200) | (1200, 1400, 500) | No active sweep |
| `CAM_BRIEFING` | Briefing Focus | (−400, 0, 250) | (700, 1000, 300) | `BRIEFING` state |
| `CAM_RESULT` | Reveal Wide | (−200, 0, 300) | (900, 1400, 400) | `RESULT` state |

---

## 5. Spawn Point Full Catalogue

| Spawn ID | Label | World Position (X, Y, Z) | Forward Vector | Type |
|---|---|---|---|---|
| `SP_CONTESTANT_01` | Contestant 1 Entry | (480, 560, 0) | −X | Type A — Match Start |
| `SP_CONTESTANT_02` | Contestant 2 Entry | (480, 0, 0) | −X | Type A |
| `SP_CONTESTANT_03` | Contestant 3 Entry | (480, −560, 0) | −X | Type A |
| `SP_CONTESTANT_04` | Contestant 4 Entry | (480, −840, 0) | −X | Type A (conditional) |
| `SP_HOST` | Host Position | (−320, 0, 0) | 0° (faces hero screen) | Type A — Host |
| `SP_RESET_STAGE` | Stage Reset | (500, 0, 0) | −X | Type B — Reset |
| `SP_SPECTATE_01` | Outer Ring Spectator A | (0, 920, 200) | −Y | Type C — Spectator |
| `SP_SPECTATE_02` | Outer Ring Spectator B | (0, −920, 200) | +Y | Type C — Spectator |

---

## 6. Collision Volume Summary

| Volume ID | Type | Shape | World Position (X, Y, Z) | Extent or Radius |
|---|---|---|---|---|
| `COL_STAGE_FLOOR` | Hard | Box | (0, 0, −2) | (900, 1000, 4) |
| `COL_HERO_SCREEN_WALL` | Hard | Box | (−870, 0, 400) | (20, 1000, 800) |
| `COL_EAST_WALL` | Hard | Box | (0, 960, 400) | (900, 20, 800) |
| `COL_WEST_WALL` | Hard | Box | (0, −960, 400) | (900, 20, 800) |
| `COL_SOUTH_WALL` | Hard | Box | (900, 0, 400) | (20, 960, 800) |
| `COL_PLT_C1` | Hard | Box | (320, 560, 60) | (100, 60, 60) |
| `COL_PLT_C2` | Hard | Box | (320, 0, 60) | (100, 60, 60) |
| `COL_PLT_C3` | Hard | Box | (320, −560, 60) | (100, 60, 60) |
| `COL_PLT_C4` | Hard | Box | (320, −840, 60) | (100, 60, 60) |
| `COL_HOST_STAND` | Soft | Capsule | (−280, 0, 100) | R=60, H=200 |
| `RST_STAGE_OOB` | Kill/Reset | Box | (1000, 0, 0) | (60, 1200, 800) |
| `RST_BACK_OOB` | Kill/Reset | Box | (−1000, 0, 0) | (60, 1200, 800) |

---

## 7. Sublevel Composition
- `SL_NeuroArena_Shell` — arena walls, floor pulse lines, suspended rigging, ambient atmosphere. Always loaded.
- `SL_WhoSceneIt_Dressing` — `MSC_HERO_01`, flanking screens, contestant platform meshes, host stand, answer terminals, category totems. Loaded only for `who_scene_it`.
- `SL_BrainBrawl_Dressing` — brain_brawl podiums, countdown pillars, duel indicators. **Unloaded** for `who_scene_it`.
- `SL_WhoSceneIt_Sequences` — All `ULevelSequenceActor` instances for the 7 camera sweeps. Loaded on `who_scene_it` init; none execute until triggered.
- `SL_WhoSceneIt_FX` — screen glow halos, buzz-in spark bursts, winner confetti. Max 6 GPU emitters for iOS.

---

## 8. iOS Performance Notes
- `MSC_HERO_01` uses 1024 × 576 render target — the single highest-cost screen. All others use 512 × 288.
- Limit concurrent active `UMediaPlayerComponent` instances to 1 (hero screen). Flanking screens (`MSC_FLANK_*`) use `UTexture2D` frame captures, not live render targets, during `REVEAL` phase.
- Each `ACineCameraActor` is pooled; only the active sweep camera is ticked. All others: `PrimaryActorTick.bCanEverTick = false`.
- Contestant spotlight per-platform: use `USpotLightComponent` (stationary), not dynamic shadow casters. Shadows baked into stage floor lightmap.
- `SL_WhoSceneIt_FX` respects 6-emitter cap: buzz-in spark (1) + screen glow (4 max simultaneous) + winner confetti (1). Winner confetti disables all other emitters on fire.

---

## 9. Map Smoke Checklist — who_scene_it

- [ ] `SL_WhoSceneIt_Dressing` loads cleanly; `SL_BrainBrawl_Dressing` confirms hidden.
- [ ] `MSC_HERO_01` cycles through `IDLE → BRIEFING → REVEAL → RESULT` without render target leak.
- [ ] All 4 `MSC_CTX_*` screens display correct contestant name and score on `BRIEFING`.
- [ ] Contestant 4 platform (`PLT_C4`) activates/deactivates cleanly with `bFourthContestantActive` flag.
- [ ] All buzz-in trigger volumes (`BZZ_01–04`) fire `OnBuzzIn` on tap; lock-out prevents simultaneous fires.
- [ ] `SWP_BUZZIN_HERO` targets correct platform Y at runtime for each contestant.
- [ ] `SWP_FINAL_WINNER` resolves `WinnerY` correctly for all 4 possible winning contestants.
- [ ] No two camera sweeps queue simultaneously; priority queue resolves `SWP_CORRECT` over `SWP_BUZZIN_HERO`.
- [ ] `SL_WhoSceneIt_Sequences` level sequences do not auto-play on load.
- [ ] Active render target count ≤ 2 during `REVEAL` phase (1 hero + 1 max flanking) on iOS memory profile.
- [ ] `SL_WhoSceneIt_FX` GPU emitter count ≤ 6 during winner confetti phase.
- [ ] `RST_STAGE_OOB` and `RST_BACK_OOB` return player to `SP_RESET_STAGE`.
- [ ] `CAM_DEFAULT` recovers correctly after all 7 sweeps without camera lock residue.
