# Final Evolution Lab — UE 5.7 Playable Mode Implementation Package

## 1. Project Overview
- **User Fact**: This package extends the earlier Final Evolution Lab environment layout plan into implementation-ready Unreal layout sheets for each requested game mode.
- **User Fact**: Source of truth remains the Abacus master architecture blueprint, and this package must not redefine backend rules, PRQ truth, economy, App Store policy, or architecture target.
- **User Fact**: Target architecture is Unreal Engine 5.7 production gameplay for one iOS app with a native WKWebView dashboard overlay inside Unreal.
- **User Fact**: Cooked iOS venue paths should follow `/Game/FEL/Venues/{Venue}/{Venue}`.
- **User Fact**: Core playability must not rely on remote streaming.
- **User Fact**: Required outputs are per-mode implementation sheets, per-venue asset checklist, spawn/camera/collision naming convention, iOS performance budget table, missing asset list, first playable milestone plan, and final smoke test checklist.
- **Research Finding**: The previously generated planning asset established venue mappings and layout assumptions for Venice_Beach_Court, Zen_Dojo, Baseball_Park, Gridiron_Stadium, Soccer_Stadium, Links_Course, Tennis_Court, Sand_Court, Venice_Beach_Surf, Skate_Park, Mountain_Slope, Training_Floor, Neuro_Arena, and the registry-gap handling for market_browse and who_scene_it.
- **Assumption**: The uploaded PDF did not parse successfully in this round, so this package continues from the already generated blueprint-derived planning document rather than introducing any new blueprint claims.
- **Planning Mode**: Preproduction to implementation handoff.
- **Depth**: L2 Standard, specialized for Unreal venue packaging and first-playable execution.

## 2. Design Goal
- **User Fact**: Each listed mode needs an implementation-ready Unreal environment/layout package rather than a high-level concept note.
- **Design Goal**: Every mode should be buildable as a playable Unreal venue package with explicit level pathing, sublevel separation, spawn naming, camera behavior, collision labeling, trigger labels, interactables, fallback logic, and smoke validation.
- **Design Goal**: Shared venues should minimize duplicated art cost by using a persistent shell plus mode-specific sublevels.
- **Design Goal**: iOS remains the primary runtime constraint, so every sheet favors low-overdraw sightlines, simplified collision, modular props, and predictable camera framing.
- **Assumption**: Where Abacus registry completeness is unclear, staging and preview modes should ship with safe placeholder layouts rather than speculative full production arenas.

## 3. Spawn, Camera, Collision, and Trigger Naming Convention
- **User Fact**: The user requested explicit spawn point names and counts, camera zone names, collision volume names, and gameplay trigger labels.
- **Naming Rule**: Use `{Venue}_{Mode}_{Type}_{Index}` for all gameplay-critical actors and volumes.
- **Spawn Prefixes**:
  - `SP_Player_01+` for player-controlled starts.
  - `SP_Opponent_01+` for direct opponent starts.
  - `SP_AI_01+` for non-player AI entrants.
  - `SP_Reset_01+` for retry or post-fail placement.
  - Example: `VeniceBeachCourt_BasketballH2H_SP_Player_01`.
- **Camera Prefixes**:
  - `CZ_Gameplay_01+` for default action framing.
  - `CZ_Approach_01+` for spawn-to-objective movement.
  - `CZ_Hero_01+` for scoring, stunt, or reveal moments.
  - `CZ_Recovery_01+` for edge-risk or reset framing.
- **Collision Prefixes**:
  - `COL_Hard_01+` for blocking geometry.
  - `COL_Soft_01+` for guidance collision.
  - `COL_Reset_01+` for out-of-bounds or fail return.
  - `COL_CamBlock_01+` for camera-only blockers.
- **Trigger Prefixes**:
  - `TRG_Start_01+` for match or run start.
  - `TRG_Score_01+` for scoring confirmation.
  - `TRG_Objective_01+` for mode progression.
  - `TRG_Prompt_01+` for contextual UI/world prompts.
  - `TRG_Audio_01+` for localized cue zones.
  - `TRG_Fallback_01+` for missing-asset safe substitutions.
- **Sublevel Rule**: Each venue should use one persistent shell plus sublevels for `Gameplay`, `Lighting`, `Audio`, `ModeProps`, and `Fallback` so shared venues can strip unused content on iOS.

## 4. Per-Mode Implementation Sheets

### 4.1 basketball_h2h
1. **Venue Name**: Venice Beach Court.
2. **Persistent Level Path**: `/Game/FEL/Venues/Venice_Beach_Court/Venice_Beach_Court`.
3. **Required Sublevels**:
   - `SL_VBC_Shell`
   - `SL_VBC_Basketball_Core`
   - `SL_VBC_Basketball_H2H`
   - `SL_VBC_Lighting_DaySunset`
   - `SL_VBC_Audio_Court`
   - `SL_VBC_Fallback`
4. **Player Spawn Point Names and Counts**:
   - `VeniceBeachCourt_BasketballH2H_SP_Player_01` x1.
5. **Opponent/AI Spawn Point Names and Counts**:
   - `VeniceBeachCourt_BasketballH2H_SP_Opponent_01` x1.
6. **Camera Zone Names and Behavior**:
   - `VeniceBeachCourt_BasketballH2H_CZ_Approach_01`: short spawn orientation toward center court.
   - `VeniceBeachCourt_BasketballH2H_CZ_Gameplay_01`: full half-court framing.
   - `VeniceBeachCourt_BasketballH2H_CZ_Hero_01`: rim attack and score beat.
   - `VeniceBeachCourt_BasketballH2H_CZ_Recovery_01`: baseline reset pullback.
7. **Collision Volume Names**:
   - `VeniceBeachCourt_BasketballH2H_COL_Hard_01` court perimeter.
   - `...COL_Hard_02` hoop stanchion.
   - `...COL_Soft_01` bench edge guidance.
   - `...COL_Reset_01` behind-baseline fail strip.
   - `...COL_CamBlock_01` bleacher camera blocker.
8. **Gameplay Trigger Labels**:
   - `TRG_Start_01`, `TRG_Score_01`, `TRG_Objective_01`, `TRG_Prompt_01`.
9. **Interactable Object List**:
   - ball pickup, score hoop, tutorial hologram stand, sideline reset beacon.
10. **Mode-Specific Props**:
   - branded backboard, shot clock, center logo decal, compact crowd banners.
11. **UI/World Prompt Locations**:
   - spawn lane, free-throw arc, baseline reset strip.
12. **Audio Cue Zones**:
   - center court sneaker squeak zone, rim score sting zone, sideline crowd swell zone.
13. **Lighting Setup**:
   - baked sunset shell, stationary rim highlights, low-cost emissive signage.
14. **LOD/HLOD Guidance**:
   - HLOD bleachers and boardwalk shell; LOD1 by midcourt distance for crowd strips and fence props.
15. **Mobile iOS Asset Budget**:
   - 450k visible triangles target, 1 hero dynamic shadow caster, 2K only on court decal/backboard, crowd cards only.
16. **Fail-Safe Fallback if an Asset Is Missing**:
   - replace branded backboard with generic FEL hoop kit; disable crowd strips if memory spikes.
17. **Smoke Test Steps**:
   - spawn facing hoop, dribble lane clear, score trigger fires, baseline reset works, camera avoids stanchion clipping.
18. **Pass/Fail Acceptance Criteria**:
   - pass if one full duel loop is playable with stable framing and no collision snags; fail if spawn orientation, score trigger, or reset path breaks.

### 4.2 basketball_dunk
1. **Venue Name**: Venice Beach Court.
2. **Persistent Level Path**: `/Game/FEL/Venues/Venice_Beach_Court/Venice_Beach_Court`.
3. **Required Sublevels**:
   - `SL_VBC_Shell`
   - `SL_VBC_Basketball_Core`
   - `SL_VBC_Basketball_Dunk`
   - `SL_VBC_Lighting_DaySunset`
   - `SL_VBC_Audio_Court`
   - `SL_VBC_Fallback`
4. **Player Spawn Point Names and Counts**:
   - `VeniceBeachCourt_BasketballDunk_SP_Player_01` x1 runway start.
5. **Opponent/AI Spawn Point Names and Counts**:
   - none required for first playable.
6. **Camera Zone Names and Behavior**:
   - `CZ_Approach_01` runway framing.
   - `CZ_Gameplay_01` lane-to-rim tracking.
   - `CZ_Hero_01` takeoff and rim finish.
   - `CZ_Recovery_01` failed landing reset.
7. **Collision Volume Names**:
   - runway hard bounds, rim support hard collision, side soft barriers, behind-rim reset volume.
8. **Gameplay Trigger Labels**:
   - start, jump timing, dunk score, landing fail, prompt.
9. **Interactable Object List**:
   - ball pickup, jump marker, dunk target ring, retry beacon.
10. **Mode-Specific Props**:
   - runway decals, spotlight rig, hero rim FX anchor.
11. **UI/World Prompt Locations**:
   - runway start, jump takeoff marker, landing zone.
12. **Audio Cue Zones**:
   - crowd build lane, takeoff sting, rim slam impact.
13. **Lighting Setup**:
   - focused rim key light plus baked sunset shell.
14. **LOD/HLOD Guidance**:
   - keep runway props low count; merge distant boardwalk dressing.
15. **Mobile iOS Asset Budget**:
   - 400k visible triangles target, one hero VFX burst at dunk only.
16. **Fail-Safe Fallback if an Asset Is Missing**:
   - use flat decal runway and static rim without hero FX.
17. **Smoke Test Steps**:
   - verify sprint lane, jump trigger timing, dunk confirmation, wipe/reset loop.
18. **Pass/Fail Acceptance Criteria**:
   - pass if dunk loop is readable and retry time stays short; fail if camera changes during jump timing or landing collision is unreliable.

### 4.3 basketball_3v3
1. **Venue Name**: Venice Beach Court.
2. **Persistent Level Path**: `/Game/FEL/Venues/Venice_Beach_Court/Venice_Beach_Court`.
3. **Required Sublevels**:
   - `SL_VBC_Shell`
   - `SL_VBC_Basketball_Core`
   - `SL_VBC_Basketball_3v3`
   - `SL_VBC_Lighting_DaySunset`
   - `SL_VBC_Audio_Court`
   - `SL_VBC_Fallback`
4. **Player Spawn Point Names and Counts**:
   - `...SP_Player_01` to `...SP_Player_03` x3.
5. **Opponent/AI Spawn Point Names and Counts**:
   - `...SP_Opponent_01` to `...SP_Opponent_03` x3.
6. **Camera Zone Names and Behavior**:
   - wide gameplay zone, wing recovery zones, rim hero zone.
7. **Collision Volume Names**:
   - perimeter hard bounds, corner soft guidance, baseline reset, camera blockers at bleachers.
8. **Gameplay Trigger Labels**:
   - possession start, score, inbound reset, prompt, audio crowd swell.
9. **Interactable Object List**:
   - ball spawn, score hoop, inbound marker, tutorial beacon.
10. **Mode-Specific Props**:
   - sideline team benches, score pylon, corner spacing decals.
11. **UI/World Prompt Locations**:
   - team spawn clusters, inbound sideline, paint entry.
12. **Audio Cue Zones**:
   - half-court crowd bed, rim score sting, sideline callout zone.
13. **Lighting Setup**:
   - same shell as H2H with slightly brighter sideline readability.
14. **LOD/HLOD Guidance**:
   - prioritize clear corners and low clutter wings.
15. **Mobile iOS Asset Budget**:
   - 500k visible triangles target, no dense animated crowd.
16. **Fail-Safe Fallback if an Asset Is Missing**:
   - remove benches and use decal-only team zones.
17. **Smoke Test Steps**:
   - all six spawns valid, corners unobstructed, inbound reset works, camera keeps ball readable.
18. **Pass/Fail Acceptance Criteria**:
   - pass if full half-court spacing remains readable and no spawn overlaps occur.

### 4.4 karate_h2h
1. **Venue Name**: Zen Dojo.
2. **Persistent Level Path**: `/Game/FEL/Venues/Zen_Dojo/Zen_Dojo`.
3. **Required Sublevels**: `SL_ZD_Shell`, `SL_ZD_Karate_Core`, `SL_ZD_Karate_H2H`, `SL_ZD_Lighting_Interior`, `SL_ZD_Audio_Dojo`, `SL_ZD_Fallback`.
4. **Player Spawn Point Names and Counts**: `ZenDojo_KarateH2H_SP_Player_01` x1.
5. **Opponent/AI Spawn Point Names and Counts**: `ZenDojo_KarateH2H_SP_Opponent_01` x1.
6. **Camera Zone Names and Behavior**: center duel framing, edge recovery pullback, finisher hero zone.
7. **Collision Volume Names**: tatami hard bounds, pillar hard collision, banner soft collision, ring-out reset volume, camera blockers at shrine wall.
8. **Gameplay Trigger Labels**: round start, strike confirm, ring-out fail, prompt, finisher cue.
9. **Interactable Object List**: gong start trigger, training dummy side prop, reset beacon.
10. **Mode-Specific Props**: tatami emblem, judge lanterns, ceremonial banners.
11. **UI/World Prompt Locations**: spawn corners, center emblem, ring edge.
12. **Audio Cue Zones**: center impact zone, crowd hush bed, finisher sting zone.
13. **Lighting Setup**: baked warm interior with stationary accent lanterns.
14. **LOD/HLOD Guidance**: merge spectator walk and shrine dressing; keep combat square highest fidelity.
15. **Mobile iOS Asset Budget**: 350k visible triangles target, minimal translucency.
16. **Fail-Safe Fallback if an Asset Is Missing**: replace shrine wall set with flat panel backdrop and disable side spectators.
17. **Smoke Test Steps**: mirrored spawns, center engagement clear, ring-out reset valid, no pillar camera clipping.
18. **Pass/Fail Acceptance Criteria**: pass if duel readability stays clean and ring edges behave consistently.

### 4.5 karate_endless
1. **Venue Name**: Zen Dojo.
2. **Persistent Level Path**: `/Game/FEL/Venues/Zen_Dojo/Zen_Dojo`.
3. **Required Sublevels**: `SL_ZD_Shell`, `SL_ZD_Karate_Core`, `SL_ZD_Karate_Endless`, `SL_ZD_Lighting_Interior`, `SL_ZD_Audio_Dojo`, `SL_ZD_Fallback`.
4. **Player Spawn Point Names and Counts**: `ZenDojo_KarateEndless_SP_Player_01` x1.
5. **Opponent/AI Spawn Point Names and Counts**: `ZenDojo_KarateEndless_SP_AI_01` to `SP_AI_04` x4 ingress points.
6. **Camera Zone Names and Behavior**: center gameplay zone, wave pullback zone, finisher hero zone, rear recovery zone.
7. **Collision Volume Names**: tatami hard bounds, gate hard collision, side banner soft collision, rear reset strip.
8. **Gameplay Trigger Labels**: wave start, enemy ingress, wave clear, prompt, fail reset.
9. **Interactable Object List**: wave totem, gong trigger, health/reset beacon.
10. **Mode-Specific Props**: side gate markers, wave lanterns, combo banner strips.
11. **UI/World Prompt Locations**: player spawn, gate thresholds, wave-clear center node.
12. **Audio Cue Zones**: gate spawn cue zones, center combat bed, wave-clear sting.
13. **Lighting Setup**: same dojo shell with stronger gate accent lights.
14. **LOD/HLOD Guidance**: keep enemy ingress silhouettes readable; simplify rear shrine dressing.
15. **Mobile iOS Asset Budget**: 375k visible triangles target plus capped AI count.
16. **Fail-Safe Fallback if an Asset Is Missing**: collapse four ingress gates to two marked spawn pads.
17. **Smoke Test Steps**: wave triggers fire in order, AI enters from readable gates, reset returns to safe strip.
18. **Pass/Fail Acceptance Criteria**: pass if three consecutive waves run without spawn confusion or camera obstruction.

### 4.6 baseball
1. **Venue Name**: Baseball Park.
2. **Persistent Level Path**: `/Game/FEL/Venues/Baseball_Park/Baseball_Park`.
3. **Required Sublevels**: `SL_BP_Shell`, `SL_BP_Baseball_Core`, `SL_BP_Lighting_Night`, `SL_BP_Audio_Stadium`, `SL_BP_Fallback`.
4. **Player Spawn Point Names and Counts**: `BaseballPark_Baseball_SP_Player_01` x1 batter start, `SP_Reset_01` x1.
5. **Opponent/AI Spawn Point Names and Counts**: `BaseballPark_Baseball_SP_AI_01` x1 pitcher machine origin.
6. **Camera Zone Names and Behavior**: batter framing, ball-flight hero zone, quick reset return.
7. **Collision Volume Names**: backstop hard collision, dugout rail hard collision, bench soft collision, foul reset sectors.
8. **Gameplay Trigger Labels**: pitch launch, swing timing, hit confirm, home-run sector, retry prompt.
9. **Interactable Object List**: bat rack, pitch machine, distance marker board, retry beacon.
10. **Mode-Specific Props**: batter spotlight, foul pole indicators, replay board.
11. **UI/World Prompt Locations**: on-deck lane, batter box, hit review marker.
12. **Audio Cue Zones**: plate crack zone, crowd cheer sectors, foul tip cue zone.
13. **Lighting Setup**: baked stadium shell with one hero spotlight on plate.
14. **LOD/HLOD Guidance**: outfield and stands heavily merged; plate area highest fidelity.
15. **Mobile iOS Asset Budget**: 325k visible triangles target, no skeletal crowd.
16. **Fail-Safe Fallback if an Asset Is Missing**: use static pitching origin and disable replay board.
17. **Smoke Test Steps**: pitch cadence stable, swing trigger aligns, ball-flight camera returns to plate.
18. **Pass/Fail Acceptance Criteria**: pass if batting loop repeats cleanly with readable hit sectors.

### 4.7 football
1. **Venue Name**: Gridiron Stadium.
2. **Persistent Level Path**: `/Game/FEL/Venues/Gridiron_Stadium/Gridiron_Stadium`.
3. **Required Sublevels**: `SL_GS_Shell`, `SL_GS_Football_Core`, `SL_GS_Lighting_Night`, `SL_GS_Audio_Stadium`, `SL_GS_Fallback`.
4. **Player Spawn Point Names and Counts**: `GridironStadium_Football_SP_Player_01` x1 end-zone start, `SP_Reset_01` x1 five-yard retry.
5. **Opponent/AI Spawn Point Names and Counts**: `SP_AI_01` to `SP_AI_06` x6 blocker lanes.
6. **Camera Zone Names and Behavior**: chase gameplay zone, blocker pullback zone, milestone hero zone, sideline recovery zone.
7. **Collision Volume Names**: sideline hard bounds, blocker hard collision, bench soft collision, out-of-bounds reset, tunnel camera blocker.
8. **Gameplay Trigger Labels**: run start, dodge lane, milestone, tackle fail, finish line.
9. **Interactable Object List**: boost gate, return marker, retry beacon.
10. **Mode-Specific Props**: yard markers, tunnel smoke anchor, crowd light towers.
11. **UI/World Prompt Locations**: end-zone spawn, first dodge lane, midfield milestone.
12. **Audio Cue Zones**: tunnel intro, crowd swell at milestones, tackle impact zone.
13. **Lighting Setup**: bright lane lighting with darker scenic stands.
14. **LOD/HLOD Guidance**: long-range stadium shell merged aggressively; blockers remain readable silhouettes.
15. **Mobile iOS Asset Budget**: 500k visible triangles target, low overdraw field FX only.
16. **Fail-Safe Fallback if an Asset Is Missing**: replace blockers with simple tackle dummy capsules and disable tunnel smoke.
17. **Smoke Test Steps**: spawn faces upfield, blocker lanes readable, sideline reset works, finish trigger fires.
18. **Pass/Fail Acceptance Criteria**: pass if one full return run is playable at speed without camera loss.

### 4.8 soccer
1. **Venue Name**: Soccer Stadium.
2. **Persistent Level Path**: `/Game/FEL/Venues/Soccer_Stadium/Soccer_Stadium`.
3. **Required Sublevels**: `SL_SS_Shell`, `SL_SS_Soccer_Core`, `SL_SS_Lighting_Stadium`, `SL_SS_Audio_Stadium`, `SL_SS_Fallback`.
4. **Player Spawn Point Names and Counts**: `SoccerStadium_Soccer_SP_Player_01` x1 shooter start, `SP_Reset_01` x1.
5. **Opponent/AI Spawn Point Names and Counts**: `SoccerStadium_Soccer_SP_AI_01` x1 keeper origin.
6. **Camera Zone Names and Behavior**: over-shoulder shot framing, goal hero zone, quick reset zone.
7. **Collision Volume Names**: goal frame hard collision, ad board hard collision, net soft collision, behind-goal reset.
8. **Gameplay Trigger Labels**: shot start, strike confirm, goal sector, save sector, retry prompt.
9. **Interactable Object List**: ball pedestal, target corner markers, retry beacon.
10. **Mode-Specific Props**: keeper cue lights, scoreboard mast, ribbon boards.
11. **UI/World Prompt Locations**: shooter spawn, penalty spot, target corners.
12. **Audio Cue Zones**: kick impact, goal cheer, save sting.
13. **Lighting Setup**: bright goal focus with restrained crowd lighting.
14. **LOD/HLOD Guidance**: goalmouth highest fidelity; stands and upper bowl merged.
15. **Mobile iOS Asset Budget**: 300k visible triangles target.
16. **Fail-Safe Fallback if an Asset Is Missing**: use static target decals instead of animated corner markers.
17. **Smoke Test Steps**: shot line clear, goal sectors align, keeper origin valid, reset loop fast.
18. **Pass/Fail Acceptance Criteria**: pass if repeated penalty shots remain readable and trigger sectors match visuals.

### 4.9 golf
1. **Venue Name**: Links Course.
2. **Persistent Level Path**: `/Game/FEL/Venues/Links_Course/Links_Course`.
3. **Required Sublevels**: `SL_LC_Shell`, `SL_LC_Golf_Core`, `SL_LC_Lighting_Day`, `SL_LC_Audio_Coastal`, `SL_LC_Fallback`.
4. **Player Spawn Point Names and Counts**: `LinksCourse_Golf_SP_Player_01` x1 tee start, `SP_Reset_01` x1 bag stand.
5. **Opponent/AI Spawn Point Names and Counts**: none required for first playable.
6. **Camera Zone Names and Behavior**: tee framing, ball-flight tracking, pin hero zone.
7. **Collision Volume Names**: tee barrier hard collision, retaining wall hard collision, rough soft guidance, water reset volume.
8. **Gameplay Trigger Labels**: swing start, shot confirm, landing ring, closest-pin success, retry prompt.
9. **Interactable Object List**: club stand, wind flag, distance beacon, landing ring marker.
10. **Mode-Specific Props**: bunker edge decals, pin flag, shot review marker.
11. **UI/World Prompt Locations**: tee spawn, swing zone, observation marker.
12. **Audio Cue Zones**: swing impact, wind bed, pin success sting.
13. **Lighting Setup**: baked daylight with low-cost sky contribution.
14. **LOD/HLOD Guidance**: distant cliffs and ocean as low-cost backdrop only.
15. **Mobile iOS Asset Budget**: 275k visible triangles target.
16. **Fail-Safe Fallback if an Asset Is Missing**: replace ocean vista with static sky card and simplify bunker meshes.
17. **Smoke Test Steps**: tee alignment, ball-flight camera, water reset, pin visibility.
18. **Pass/Fail Acceptance Criteria**: pass if closest-to-pin loop is readable and hazards reset correctly.

### 4.10 tennis
1. **Venue Name**: Tennis Court.
2. **Persistent Level Path**: `/Game/FEL/Venues/Tennis_Court/Tennis_Court`.
3. **Required Sublevels**: `SL_TC_Shell`, `SL_TC_Tennis_Core`, `SL_TC_Lighting_Rooftop`, `SL_TC_Audio_Court`, `SL_TC_Fallback`.
4. **Player Spawn Point Names and Counts**: `TennisCourt_Tennis_SP_Player_01` x1 baseline start.
5. **Opponent/AI Spawn Point Names and Counts**: `TennisCourt_Tennis_SP_AI_01` x1 rally source.
6. **Camera Zone Names and Behavior**: broadcast gameplay zone, net-approach hero zone, corner recovery pullback.
7. **Collision Volume Names**: net post hard collision, rear wall hard collision, bench soft collision, baseline reset strip.
8. **Gameplay Trigger Labels**: serve start, rally confirm, ace zone, recovery prompt.
9. **Interactable Object List**: ball machine, serve target, score tower, retry beacon.
10. **Mode-Specific Props**: holographic line judge, umpire chair, replay pylon.
11. **UI/World Prompt Locations**: baseline spawn, service box, net approach lane.
12. **Audio Cue Zones**: racket hit, crowd clap, ace sting.
13. **Lighting Setup**: baked rooftop shell with cool court highlights.
14. **LOD/HLOD Guidance**: skyline and seating merged; court lines remain crisp.
15. **Mobile iOS Asset Budget**: 300k visible triangles target.
16. **Fail-Safe Fallback if an Asset Is Missing**: replace holographic line judge with static signage.
17. **Smoke Test Steps**: baseline spawn valid, ball readability preserved, corner camera stable.
18. **Pass/Fail Acceptance Criteria**: pass if rally loop remains readable and no net/corner camera loss occurs.

### 4.11 volleyball
1. **Venue Name**: Sand Court.
2. **Persistent Level Path**: `/Game/FEL/Venues/Sand_Court/Sand_Court`.
3. **Required Sublevels**: `SL_SC_Shell`, `SL_SC_Volleyball_Core`, `SL_SC_Lighting_Sunset`, `SL_SC_Audio_Beach`, `SL_SC_Fallback`.
4. **Player Spawn Point Names and Counts**: `SandCourt_Volleyball_SP_Player_01` and `SP_Player_02` x2.
5. **Opponent/AI Spawn Point Names and Counts**: `SP_Opponent_01` and `SP_Opponent_02` x2.
6. **Camera Zone Names and Behavior**: wide court framing, net hero zone, deep-corner recovery zone.
7. **Collision Volume Names**: post hard collision, judge stand hard collision, tent soft collision, rope-line reset volume.
8. **Gameplay Trigger Labels**: serve start, set zone, spike confirm, out-of-bounds reset, prompt.
9. **Interactable Object List**: serve marker, spike target, score hut, retry beacon.
10. **Mode-Specific Props**: sponsor tents, beach banners, judge stand.
11. **UI/World Prompt Locations**: service line, center receive triangle, deep corners.
12. **Audio Cue Zones**: beach ambience, spike impact, crowd cheer.
13. **Lighting Setup**: baked sunset shell with bright net readability.
14. **LOD/HLOD Guidance**: palm silhouettes and boardwalk dressing merged; court remains clean.
15. **Mobile iOS Asset Budget**: 350k visible triangles target.
16. **Fail-Safe Fallback if an Asset Is Missing**: remove tents and use rope-line only perimeter.
17. **Smoke Test Steps**: all four spawns valid, net collision stable, out-of-bounds reset works.
18. **Pass/Fail Acceptance Criteria**: pass if rally and spike beats remain readable with no sideline snagging.

### 4.12 surfing
1. **Venue Name**: Venice Beach Surf.
2. **Persistent Level Path**: `/Game/FEL/Venues/Venice_Beach_Surf/Venice_Beach_Surf`.
3. **Required Sublevels**: `SL_VBS_Shell`, `SL_VBS_Surf_Core`, `SL_VBS_Lighting_Day`, `SL_VBS_Audio_Surf`, `SL_VBS_Fallback`.
4. **Player Spawn Point Names and Counts**: `VeniceBeachSurf_Surfing_SP_Player_01` x1 drop-in start, `SP_Reset_01` x1 shoreline.
5. **Opponent/AI Spawn Point Names and Counts**: none required for first playable.
6. **Camera Zone Names and Behavior**: side-follow gameplay zone, tube hero zone, wipeout recovery pullback.
7. **Collision Volume Names**: pier pylon hard collision, shoreline barrier hard collision, foam soft guidance, water reset volume.
8. **Gameplay Trigger Labels**: drop-in start, trick gate, combo chain, wipeout fail, finish marker.
9. **Interactable Object List**: start buoy, trick gate, combo marker, shoreline retry beacon.
10. **Mode-Specific Props**: pier silhouette, buoy lights, shoreline timing board.
11. **UI/World Prompt Locations**: drop-in point, first carve gate, shoreline reset.
12. **Audio Cue Zones**: wave bed, trick success sting, wipeout splash cue.
13. **Lighting Setup**: bright daylight with simplified water shading.
14. **LOD/HLOD Guidance**: distant beach crowd and pier merged; wave lane remains clean.
15. **Mobile iOS Asset Budget**: 425k visible triangles target plus strict water material limits.
16. **Fail-Safe Fallback if an Asset Is Missing**: replace dynamic wave dressing with fixed surf lane spline and static foam cards.
17. **Smoke Test Steps**: drop-in orientation, trick gates readable, wipeout reset fast, camera preserves line.
18. **Pass/Fail Acceptance Criteria**: pass if one full surf line is playable without camera confusion or water overdraw spikes.

### 4.13 skateboarding
1. **Venue Name**: Skate Park.
2. **Persistent Level Path**: `/Game/FEL/Venues/Skate_Park/Skate_Park`.
3. **Required Sublevels**: `SL_SP_Shell`, `SL_SP_Skate_Core`, `SL_SP_Lighting_Neon`, `SL_SP_Audio_Park`, `SL_SP_Fallback`.
4. **Player Spawn Point Names and Counts**: `SkatePark_Skateboarding_SP_Player_01` x1 flow-line start, `SP_Reset_01` x1 plaza center.
5. **Opponent/AI Spawn Point Names and Counts**: none required for first playable.
6. **Camera Zone Names and Behavior**: follow gameplay zone, rail hero zone, bowl transfer hero zone, recovery pullback.
7. **Collision Volume Names**: ramp hard collision, rail hard collision, mural wall soft collision, bowl fail reset.
8. **Gameplay Trigger Labels**: line start, trick confirm, combo chain, bail fail, finish marker.
9. **Interactable Object List**: trick prompt marker, combo gate, retry beacon.
10. **Mode-Specific Props**: LED rails, mural walls, score pylons.
11. **UI/World Prompt Locations**: line start, rail entry, bowl lip, plaza reset.
12. **Audio Cue Zones**: wheel roll bed, grind cue, combo success sting.
13. **Lighting Setup**: baked neon plaza shell with limited emissive accents.
14. **LOD/HLOD Guidance**: outer plaza dressing merged; hero line obstacles remain separate.
15. **Mobile iOS Asset Budget**: 400k visible triangles target.
16. **Fail-Safe Fallback if an Asset Is Missing**: use simple quarter pipe, rail, and manual pad trio as placeholder line.
17. **Smoke Test Steps**: line continuity, rail collision honesty, bowl reset, camera stability on transfers.
18. **Pass/Fail Acceptance Criteria**: pass if one combo line can be completed without snagging or camera loss.

### 4.14 snowboarding
1. **Venue Name**: Mountain Slope.
2. **Persistent Level Path**: `/Game/FEL/Venues/Mountain_Slope/Mountain_Slope`.
3. **Required Sublevels**: `SL_MS_Shell`, `SL_MS_Snowboard_Core`, `SL_MS_Lighting_Day`, `SL_MS_Audio_Slope`, `SL_MS_Fallback`.
4. **Player Spawn Point Names and Counts**: `MountainSlope_Snowboarding_SP_Player_01` x1 summit start, `SP_Reset_01` x1 checkpoint shelf.
5. **Opponent/AI Spawn Point Names and Counts**: none required for first playable.
6. **Camera Zone Names and Behavior**: chase gameplay zone, jump pullback zone, landing hero zone, berm recovery zone.
7. **Collision Volume Names**: rock wall hard collision, lift pylon hard collision, snowbank soft collision, off-course reset volume.
8. **Gameplay Trigger Labels**: run start, gate pass, jump trick, checkpoint, finish line.
9. **Interactable Object List**: gate marker, jump indicator, checkpoint beacon, retry beacon.
10. **Mode-Specific Props**: finish arch, lodge silhouette, slope lights.
11. **UI/World Prompt Locations**: summit spawn, first gate, jump lip, checkpoint shelf.
12. **Audio Cue Zones**: wind bed, jump cue, finish sting.
13. **Lighting Setup**: bright daylight with low-cost snow shading and strong gate contrast.
14. **LOD/HLOD Guidance**: distant mountains and lodge merged; gate sequence remains crisp.
15. **Mobile iOS Asset Budget**: 450k visible triangles target with strict particle limits.
16. **Fail-Safe Fallback if an Asset Is Missing**: use simple downhill lane with gate poles and one jump table.
17. **Smoke Test Steps**: summit orientation, gate readability at speed, checkpoint reset, finish trigger.
18. **Pass/Fail Acceptance Criteria**: pass if downhill line is readable and forgiving without visual clutter.

### 4.15 gymnastics
1. **Venue Name**: Training Floor.
2. **Persistent Level Path**: `/Game/FEL/Venues/Training_Floor/Training_Floor`.
3. **Required Sublevels**: `SL_TF_Shell`, `SL_TF_Gymnastics_Core`, `SL_TF_Lighting_Interior`, `SL_TF_Audio_Arena`, `SL_TF_Fallback`.
4. **Player Spawn Point Names and Counts**: `TrainingFloor_Gymnastics_SP_Player_01` x1 routine start, `SP_Reset_01` x1 corner reset.
5. **Opponent/AI Spawn Point Names and Counts**: none required for first playable.
6. **Camera Zone Names and Behavior**: performance gameplay zone, tumbling hero zone, landing hero zone, full-floor pullback.
7. **Collision Volume Names**: apparatus base hard collision, judge riser hard collision, mat stack soft collision, floor exit reset.
8. **Gameplay Trigger Labels**: routine start, node confirm, landing success, fail reset, prompt.
9. **Interactable Object List**: routine marker, timing light, score display, retry beacon.
10. **Mode-Specific Props**: apparatus silhouettes, LED lane strips, judge table.
11. **UI/World Prompt Locations**: start node, tumbling diagonal, landing zone.
12. **Audio Cue Zones**: routine music bed, landing sting, score reveal cue.
13. **Lighting Setup**: baked indoor shell with focused floor spotlights.
14. **LOD/HLOD Guidance**: perimeter apparatus merged; floor routine path highest fidelity.
15. **Mobile iOS Asset Budget**: 325k visible triangles target.
16. **Fail-Safe Fallback if an Asset Is Missing**: use floor-only routine with decal nodes and no apparatus pods.
17. **Smoke Test Steps**: node order readable, landing zones clear, reset path safe, camera covers full routine.
18. **Pass/Fail Acceptance Criteria**: pass if one routine path can be completed with clear node feedback and stable framing.

### 4.16 brain_brawl
1. **Venue Name**: Neuro Arena.
2. **Persistent Level Path**: `/Game/FEL/Venues/Neuro_Arena/Neuro_Arena`.
3. **Required Sublevels**: `SL_NA_Shell`, `SL_NA_BrainBrawl_Core`, `SL_NA_Lighting_Quiz`, `SL_NA_Audio_Arena`, `SL_NA_Fallback`.
4. **Player Spawn Point Names and Counts**: `NeuroArena_BrainBrawl_SP_Player_01` x1, `SP_Player_02` x1.
5. **Opponent/AI Spawn Point Names and Counts**: mirrored contestant spawns already cover direct opposition; optional `SP_AI_01` host anchor x1.
6. **Camera Zone Names and Behavior**: broadcast gameplay zone, answer reveal hero zone, intro wide zone, podium recovery zone.
7. **Collision Volume Names**: stage edge hard collision, podium hard collision, hologram stand soft collision, rear reset strip.
8. **Gameplay Trigger Labels**: round intro, answer lock, reveal, score confirm, prompt.
9. **Interactable Object List**: answer terminal, countdown pillar, reveal screen, reset beacon.
10. **Mode-Specific Props**: category totems, pulse floor rings, host light mast.
11. **UI/World Prompt Locations**: contestant spawns, podium fronts, reveal wall.
12. **Audio Cue Zones**: countdown bed, correct-answer sting, reveal swell.
13. **Lighting Setup**: dark shell with cyan pulse accents and readable podium key lights.
14. **LOD/HLOD Guidance**: outer audience ring merged; stage and podiums remain separate.
15. **Mobile iOS Asset Budget**: 325k visible triangles target with limited hologram translucency.
16. **Fail-Safe Fallback if an Asset Is Missing**: replace hologram reveal wall with flat emissive panel and static podium screens.
17. **Smoke Test Steps**: both contestant spawns valid, answer terminals readable, reveal wall visible, score trigger fires.
18. **Pass/Fail Acceptance Criteria**: pass if one full question-answer-reveal loop is playable with clear prompts.

### 4.17 who_scene_it
1. **Venue Name**: Neuro Arena staging variant.
2. **Persistent Level Path**: `/Game/FEL/Venues/Neuro_Arena/Neuro_Arena`.
3. **Required Sublevels**: `SL_NA_Shell`, `SL_NA_WhoSceneIt_Staging`, `SL_NA_Lighting_Quiz`, `SL_NA_Audio_Arena`, `SL_NA_Fallback`.
4. **Player Spawn Point Names and Counts**: `NeuroArena_WhoSceneIt_SP_Player_01` x1 host-facing, `SP_Player_02` x1 contestant-facing.
5. **Opponent/AI Spawn Point Names and Counts**: optional `SP_AI_01` x1 presenter anchor.
6. **Camera Zone Names and Behavior**: reveal-stage gameplay zone, scene close-up hero zone, intro wide zone.
7. **Collision Volume Names**: stage edge hard collision, reveal wall hard collision, console soft collision, rear reset strip.
8. **Gameplay Trigger Labels**: scene reveal, answer lock, preview transition, prompt, fallback staging trigger.
9. **Interactable Object List**: reveal console, answer podium, category screen, reset beacon.
10. **Mode-Specific Props**: preview curtains, scene frame panels, category totems.
11. **UI/World Prompt Locations**: contestant podium, reveal wall, host mark.
12. **Audio Cue Zones**: reveal sting, answer timer bed, correct-answer cue.
13. **Lighting Setup**: same Neuro shell with stronger reveal wall spotlight.
14. **LOD/HLOD Guidance**: keep staging compact; no extra scenic shell beyond arena ring.
15. **Mobile iOS Asset Budget**: 300k visible triangles target.
16. **Fail-Safe Fallback if an Asset Is Missing**: remain in staging-only mode with flat preview cards instead of scene-specific set pieces.
17. **Smoke Test Steps**: reveal trigger works, podium prompts appear, fallback staging path loads if scene assets absent.
18. **Pass/Fail Acceptance Criteria**: pass if staging preview loop works without requiring unbuilt scene contracts.

### 4.18 court_carnival
1. **Venue Name**: Venice Beach Party layout staging variant.
2. **Persistent Level Path**: `/Game/FEL/Venues/Venice_Beach_Court/Venice_Beach_Court`.
3. **Required Sublevels**: `SL_VBC_Shell`, `SL_VBC_CourtCarnival_Staging`, `SL_VBC_Lighting_DaySunset`, `SL_VBC_Audio_Court`, `SL_VBC_Fallback`.
4. **Player Spawn Point Names and Counts**: `VeniceBeachCourt_CourtCarnival_SP_Player_01` x1 social spawn, `SP_Player_02` x1 alternate party spawn.
5. **Opponent/AI Spawn Point Names and Counts**: optional `SP_AI_01` to `SP_AI_04` x4 mini-event anchors.
6. **Camera Zone Names and Behavior**: social overview zone, mini-event hero zone, promenade recovery zone.
7. **Collision Volume Names**: court perimeter hard collision, kiosk hard collision, rope soft collision, off-pad reset volume.
8. **Gameplay Trigger Labels**: party intro, mini-event start, reward reveal, prompt, fallback staging trigger.
9. **Interactable Object List**: mini-event kiosk, reward podium, social prompt beacon, reset beacon.
10. **Mode-Specific Props**: party banners, podiums, modular kiosks, light strings.
11. **UI/World Prompt Locations**: social spawn, kiosk fronts, reward podium.
12. **Audio Cue Zones**: party ambience, mini-event sting, reward reveal cue.
13. **Lighting Setup**: sunset shell with low-cost festoon accents.
14. **LOD/HLOD Guidance**: use removable kiosk modules; keep center court open.
15. **Mobile iOS Asset Budget**: 375k visible triangles target.
16. **Fail-Safe Fallback if an Asset Is Missing**: use decal-only activity pads and one generic reward podium.
17. **Smoke Test Steps**: social spawn valid, kiosk prompts readable, fallback staging works with minimal props.
18. **Pass/Fail Acceptance Criteria**: pass if party preview loop is navigable and does not block the shared court shell.

### 4.19 market_browse
1. **Venue Name**: Module Library staging browse hall.
2. **Persistent Level Path**: `/Game/FEL/Venues/Module_Library/Module_Library`.
3. **Required Sublevels**: `SL_ML_Shell`, `SL_ML_MarketBrowse_Staging`, `SL_ML_Lighting_Showcase`, `SL_ML_Audio_Showroom`, `SL_ML_Fallback`.
4. **Player Spawn Point Names and Counts**: `ModuleLibrary_MarketBrowse_SP_Player_01` x1 welcome spawn, `SP_Reset_01` x1 midpoint reset.
5. **Opponent/AI Spawn Point Names and Counts**: none required.
6. **Camera Zone Names and Behavior**: browse gameplay zone, featured-plinth hero zone, promenade recovery zone.
7. **Collision Volume Names**: display island hard collision, wall hard collision, seating soft collision, browse loop reset volume.
8. **Gameplay Trigger Labels**: browse intro, featured item focus, category prompt, fallback showcase trigger.
9. **Interactable Object List**: product plinth, creator card wall, spotlight kiosk, reset beacon.
10. **Mode-Specific Props**: premium signage, floating shelf frames, seasonal feature wall.
11. **UI/World Prompt Locations**: welcome spawn, hero plinth, side alcoves.
12. **Audio Cue Zones**: showroom ambience, featured item sting, category focus cue.
13. **Lighting Setup**: dark-clinical shell with cyan shelf lighting and low-reflection floor treatment.
14. **LOD/HLOD Guidance**: keep browse loop compact; merge all non-featured shelving.
15. **Mobile iOS Asset Budget**: 275k visible triangles target.
16. **Fail-Safe Fallback if an Asset Is Missing**: use four generic display plinths and flat creator cards in a simple loop hall.
17. **Smoke Test Steps**: welcome spawn faces hero display, browse loop intuitive, featured focus trigger works, fallback hall loads if venue art missing.
18. **Pass/Fail Acceptance Criteria**: pass if browse flow works as a non-scoring showcase without dead ends or missing prompts.

## 5. Per-Venue Asset Checklist
- **Venice Beach Court**: court shell, hoop kit, backboard variants, sideline benches, fence kit, bleacher strip, sunset lighting rig, party kiosk kit, runway decals, score pylon.
- **Zen Dojo**: tatami floor kit, pillar set, shoji gate kit, shrine/backdrop wall, lantern set, wave gate markers, training dummy.
- **Baseball Park**: batter box shell, backstop, dugout rail, pitch machine, bat rack, foul pole indicators, replay board.
- **Gridiron Stadium**: field shell, yard markers, blocker dummy kit, tunnel entry kit, sideline bench strip, finish arch.
- **Soccer Stadium**: goal kit, net, ad boards, keeper marker, target corner kit, scoreboard mast.
- **Links Course**: tee box kit, green/pin kit, bunker kit, wind flag, distance beacon, water hazard plane.
- **Tennis Court**: court shell, net kit, umpire chair, ball machine, line judge signage, replay pylon.
- **Sand Court**: sand court shell, net/post kit, judge stand, sponsor tent kit, rope perimeter, score hut.
- **Venice Beach Surf**: surf lane spline, wave shell, buoy kit, pier silhouette, shoreline reset pad, timing board.
- **Skate Park**: quarter pipe, rail set, manual pad, bowl shell, mural wall kit, score pylon.
- **Mountain Slope**: downhill lane shell, gate poles, jump table, checkpoint beacon, finish arch, lodge silhouette.
- **Training Floor**: floor mat shell, routine node decals, apparatus silhouettes, judge table, timing lights.
- **Neuro Arena**: circular stage, podium kit, reveal wall, countdown pillar, category totem, host light mast.
- **Module Library**: browse hall shell, display plinths, creator card wall, spotlight kiosk, feature wall, shelf frame kit.

## 6. iOS Performance Budget Table
- **Tier A Compact Precision Maps**: Baseball Park, Soccer Stadium, Links Course, Tennis Court, Module Library.
  - Visible triangles target: 275k–325k.
  - Materials: 1–2 master families plus instances.
  - Dynamic shadows: 0–1 hero caster.
  - VFX: one hero effect at a time.
  - Crowd/background: static cards or none.
- **Tier B Mid-Complexity Arena Maps**: Venice Beach Court, Zen Dojo, Sand Court, Training Floor, Neuro Arena.
  - Visible triangles target: 325k–500k.
  - Materials: 2 master families max in active play ring.
  - Dynamic shadows: 1 hero caster plus limited stationary accents.
  - VFX: sparse, localized, no stacked translucency.
  - Crowd/background: merged strips only.
- **Tier C Flow Maps**: Gridiron Stadium, Venice Beach Surf, Skate Park, Mountain Slope.
  - Visible triangles target: 400k–500k.
  - Materials: low-overdraw lane materials only.
  - Dynamic shadows: 1 hero caster max.
  - VFX: speed-line or impact bursts only.
  - Background: aggressively merged and non-interactive.
- **Hard Rules**:
  - No decorative collision clutter within 10 meters of spawn.
  - No more than 3 overlapping translucent layers in any hero shot.
  - Use HLOD for stands, skylines, boardwalks, and distant architecture.
  - Keep gameplay prompts and trigger markers readable without expensive post effects.

## 7. Missing Asset List
- **Assumption**: The following items should be treated as missing until confirmed in the workspace or venue registry.
- Module Library persistent venue shell for `market_browse`.
- Dedicated contract-complete scene assets for `who_scene_it`.
- Dedicated Venice Beach Party shell for `court_carnival` beyond shared court staging.
- Final surf wave gameplay mesh and simplified mobile-safe water material.
- Final snowboard slope gate kit and jump feature set.
- Final skate park hero obstacle kit if current park shell is absent.
- Any venue-specific branded signage not already present in shared FEL kits.

## 8. First Playable Milestone Plan
- **Milestone Goal**: Deliver one stable playable slice for the highest-priority venues without waiting on unresolved staging contracts.
- **Phase 1 — Shared Naming and Shell Setup**:
  - Create persistent venue shells and standard sublevel structure for Venice Beach Court, Zen Dojo, Baseball Park, Gridiron Stadium, and Soccer Stadium.
  - Place standardized spawn, camera, collision, and trigger actors using the naming convention in Section 3.
- **Phase 2 — Core Playable Modes**:
  - Implement `basketball_h2h`, `basketball_dunk`, `basketball_3v3`, `karate_h2h`, `karate_endless`, `baseball`, `football`, and `soccer`.
  - Use placeholder props where hero art is missing, but keep gameplay collision and prompts final enough for smoke testing.
- **Phase 3 — Precision and Flow Expansion**:
  - Add `golf`, `tennis`, `volleyball`, `surfing`, `skateboarding`, `snowboarding`, and `gymnastics`.
  - Lock mobile-safe lighting and HLOD passes before adding extra scenic dressing.
- **Phase 4 — Staging and Browse Modes**:
  - Ship `brain_brawl` as production-ready in Neuro Arena.
  - Ship `who_scene_it`, `court_carnival`, and `market_browse` as staging/preview-safe packages with explicit fallback layouts.
- **Milestone Exit Criteria**:
  - Every priority mode loads from its persistent venue path.
  - Every mode has valid spawn, camera, collision, prompt, and reset coverage.
  - Every mode passes the smoke checklist below on iOS-safe settings.

## 9. Final Smoke Test Checklist
- Load each persistent venue path and verify the correct mode sublevels are active.
- Confirm all player, opponent, AI, and reset spawns are above valid floor and outside blocking collision.
- Confirm first objective is visible or clearly signposted from spawn.
- Walk or ride the primary path and verify no decorative prop blocks core play.
- Trigger every camera zone once and verify no wall, pillar, rail, or hero prop clipping.
- Trigger every reset volume and confirm return to the correct reset spawn.
- Verify every prompt appears only at intended approach distance.
- Verify every score, objective, reveal, or finish trigger fires once and only once.
- Disable one non-critical hero prop per venue and confirm fallback layout still supports playability.
- Run a 3-minute iOS smoke pass and confirm stable frame pacing, acceptable thermal behavior, and no memory-driven content loss.

## 10. Assumptions
- **Assumption**: The earlier blueprint-derived planning document remains the authoritative basis for venue mapping in this workspace.
- **Assumption**: `who_scene_it` and `court_carnival` should remain staging/preview packages until Abacus marks their contracts complete.
- **Assumption**: `market_browse` should be implemented as a compact Module Library showcase hall, not a scoring arena.
- **Assumption**: If a venue shell is missing, placeholder layouts should be built first using shared FEL kits rather than blocking the milestone.

## 11. Key Risks
- **Risk**: Shared venues may accumulate too many mode-specific props and exceed iOS memory or draw-call budgets.
- **Risk**: Flow maps can lose readability if long-range scenery or water/snow effects become too expensive.
- **Risk**: Registry gaps for staging modes can cause drift unless fallback layouts are explicitly labeled and isolated in sublevels.
- **Risk**: Camera zones may become over-authored and interfere with timing-sensitive gameplay if transitions are too frequent.

## 12. Recommended Next Step
- Build the first playable venue sheets into engine task tickets starting with Venice Beach Court and Zen Dojo, using the naming convention and sublevel structure defined here.
