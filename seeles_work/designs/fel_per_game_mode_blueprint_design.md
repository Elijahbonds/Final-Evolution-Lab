# Per-Game-Mode Architecture Blueprint — Final Evolution Lab

Definitive per-game-mode architecture blueprint for all 19 Final Evolution Lab modes. Assigns each mode a corrected production status, cooked venue path, gameplay loop, win/loss conditions, scoring rules, session receipt contract, input scheme, interactables, spawn points, camera zones, PRQ/reward boundaries, API dependencies, smoke test criteria, and registry alignment patches. Provides a first-5-venue production priority, remaining backlog, registry patch list, smoke test matrix, and "do not ship until" checklist that Seele AI can execute against.

---

## Goals

- Assign definitive production status to all 19 modes: 12 production, 4 staging, 2 preview, 1 non-game module
- Define cooked venue path (source of truth: [EmergentPlayMap] INI) for each mode
- Specify gameplay loop, win/loss/fail conditions, and scoring rules for each mode
- Define session receipt event contract per mode
- Specify required player inputs, interactables, spawn points, and camera zones
- Define PRQ/readiness boundaries and reward boundaries (XP, shards, cards, certificates)
- Document backend/API dependencies per mode
- Establish smoke test acceptance criteria per mode
- Identify all missing repo registry entries and define exact patches needed
- Produce first-5-venue production priority list (8 modes across 5 venues)
- Produce remaining 14-mode backlog with priority ordering
- Produce registry alignment patch list across 6 source files
- Produce smoke test matrix for every mode
- Produce "do not ship until" checklist with hard gates

---

## 1. Corrected Production Status (19 Modes)

### Status Definitions

| Status | Definition |
|--------|-----------|
| **production** | Full gameplay loop, session receipt, routing, PRQ, shards all wired. Ships in v1. |
| **staging** | Gameplay loop designed, map may exist, but routing/session/economy incomplete. Ships in v1.x. |
| **preview** | Concept only; no complete routing, no standard session receipt, no gameplay contract. Ships when ready. |
| **non-game module** | Not a scoring game mode. No session receipt, no PRQ, no shards. |

### Final Status Assignment

| # | mode_id | Corrected Status | Rationale |
|---|---------|-----------------|-----------|
| 1 | basketball_h2h | **production** | Full infra across all 6 registries |
| 2 | basketball_dunk | **production** | Full infra across all 6 registries |
| 3 | basketball_3v3 | **production** | Full infra across all 6 registries |
| 4 | karate_h2h | **production** | Full infra; `karate` is private alias |
| 5 | karate_endless | **production** | Swift enum ✅, EmergentPlayMap ✅, ModeManager ✅; missing from VenueRegistry only (shares Dojo) |
| 6 | baseball | **production** | Full infra |
| 7 | football | **production** | Full infra |
| 8 | soccer | **production** | Full infra |
| 9 | golf | **production** | Full infra |
| 10 | tennis | **production** | Full infra |
| 11 | volleyball | **production** | Full infra |
| 12 | surfing | **production** | Full infra; shares VeniceBeach map (confirmed in ArenaSettings + EmergentPlayMap) |
| 13 | skateboarding | **staging** | Swift enum ✅ but map NOT in MapsToCook; EmergentPlayMap falsely routes to VeniceBeach |
| 14 | snowboarding | **staging** | Swift enum ✅ but map NOT in MapsToCook; EmergentPlayMap falsely routes to VeniceBeach |
| 15 | gymnastics | **staging** | Swift enum ✅, map in MapsToCook (TrainingFloor); close to production but no dedicated venue map |
| 16 | brain_brawl | **staging** | Swift enum ✅, dedicated backend endpoint, EmergentPlayMap ✅; but bScoringEnabled=false, different XP formula |
| 17 | who_scene_it | **preview** | Missing: Swift enum, ue_mode_maps, VenueRegistry, standard session receipt, EmergentPlayMap (code-only hardcode) |
| 18 | court_carnival | **preview** | Replaces mario_party_fever; missing: Swift enum, ue_mode_maps, VenueRegistry, standard session receipt |
| 19 | market_browse | **non-game module** | 3D shop browser, no scoring, no session receipt, no PRQ. Module Library. |

---

## 2. Master Per-Mode Blueprint (19 Modes × 15 Attributes)

### MODE 1: basketball_h2h
| Attribute | Value |
|-----------|-------|
| Status | production |
| Venue path | `/Game/FEL/Venues/VeniceBeach/VeniceBeach` |
| Gameplay loop | 1v1 arcade shootout on Venice Beach half-court. Charge shots with timing-based release. First to targetScore (3). PRQ adjusts physics (jumpScale 1.03, walkScale 1.045). Neuro-kinetic leakage enabled. |
| Win/loss/fail | Win = reach 3. Loss = opponent reaches 3. Fail = disconnect/timeout. |
| Scoring | 2pt/3pt per basket. targetScore=3. No time limit. XP = max(10, score/5). Shards: 50w/25d/15l + combo×5 + criticals×10. PRQ delta: base 2.0 (win) × 1.2 weight. |
| Session receipt | `POST /api/games/session` → `{mode_id: "basketball_h2h", score, opponent_score, duration_seconds, is_multiplayer: true}` |
| Inputs | charge (hold to charge shot power, release to shoot) |
| Interactables | Basketball (1), hoop, backboard, court boundaries |
| Spawn points | 2 player positions (home/away) at half-court |
| Camera zones | Behind-player 3rd person; rim-cam on dunk; replay cam on score |
| PRQ boundaries | Weight 1.2. Attribute: "Court IQ", base 0.40. Arcade: speed 0.9–1.15×, hang -0.10–+0.30 |
| Rewards | XP (uncapped), shards (50/25/15 + bonuses), PRQ delta (+2.0 win × 1.2) |
| API deps | `POST /api/games/session`, `POST /api/streaming/launch-mode`, `POST /api/session/state`, WS `/ws/game/{room_id}` |
| Smoke test | Deep link → MapLoaded ≤10s → play to 3 → session receipt → XP + shards + PRQ delta + activity feed |
| Missing registry | None |

### MODE 2: basketball_dunk
| Attribute | Value |
|-----------|-------|
| Status | production |
| Venue path | `/Game/FEL/Venues/VeniceBeach/VeniceBeach` |
| Gameplay loop | Dunk contest. Style + height + hang time scoring. First to 21. ballSpawnType: SingleAtPrimary. Neuro-kinetic leakage enabled. |
| Win/loss/fail | Win = reach 21. Loss = opponent reaches 21. Fail = disconnect. |
| Scoring | Style per dunk (1–5). targetScore=21. No time limit. modeWeight 1.0. Attribute: "Hang Time", base 0.45. |
| Session receipt | `POST /api/games/session` → `{mode_id: "basketball_dunk", score, opponent_score, duration_seconds, is_multiplayer: true}` |
| Inputs | charge (charge jump → release for dunk → timing for style) |
| Interactables | Basketball (1), hoop, backboard, dunk lane |
| Spawn points | 2 player positions at dunk approach lane |
| Camera zones | Side-angle approach; slow-mo rim cam on dunk; judge-view replay |
| PRQ boundaries | Weight 1.0. PRQ → hang time directly affected. ELITE: +0.30 hang time. |
| Rewards | XP, shards (50/25/15), PRQ delta (base × 1.0) |
| API deps | Same as basketball_h2h |
| Smoke test | Deep link → dunk → style score → reach 21 → session receipt → economy |
| Missing registry | None |

### MODE 3: basketball_3v3
| Attribute | Value |
|-----------|-------|
| Status | production |
| Venue path | `/Game/FEL/Venues/VeniceBeach/VeniceBeach` |
| Gameplay loop | 3v3 streetball half-court. Team arcade. 2 balls. First to 11. Physics: jumpScale 1.035, walkScale 1.055. Help defense. |
| Win/loss/fail | Win = team reaches 11. Loss = opponent team 11. Fail = disconnect. |
| Scoring | 2pt/3pt. targetScore=11. ballCount=2. modeWeight 1.3. |
| Session receipt | `POST /api/games/session` → `{mode_id: "basketball_3v3", score, opponent_score, duration_seconds, is_multiplayer: true}` |
| Inputs | charge (shoot + pass/switch) |
| Interactables | Basketballs (2), hoop, court, AI teammates/opponents |
| Spawn points | 6 positions (3 home, 3 away) |
| Camera zones | Overhead broadcast; follow-ball; fast break transition |
| PRQ boundaries | Weight 1.3 (highest basketball). Attribute: "Court IQ", base 0.40. |
| Rewards | XP, shards, PRQ delta (base × 1.3) |
| API deps | Same + WS room for 6 players |
| Smoke test | Deep link → 3v3 formation → 2 balls → score 11 → session receipt → economy |
| Missing registry | None |

### MODE 4: karate_h2h
| Attribute | Value |
|-----------|-------|
| Status | production |
| Venue path | `/Game/FEL/Venues/Dojo/Dojo` |
| Gameplay loop | 1v1 point sparring. Strike detection + combo chains. First to 5 or time 150s. `karate` is private alias. |
| Win/loss/fail | Win = 5 pts or lead at time. Loss = opponent wins. Draw = tied at expiry. Fail = disconnect. |
| Scoring | 1–3 pts per strike. targetScore=5. timeLimit=150s. modeWeight 1.4. |
| Session receipt | `POST /api/games/session` → `{mode_id: "karate_h2h", score, opponent_score, duration_seconds, is_multiplayer: true}` |
| Inputs | charge (strike power, directional, block/dodge) |
| Interactables | Opponent character, dojo mat, combo indicator |
| Spawn points | 2 fighter positions center mat |
| Camera zones | Side-angle fight; combo close-up; slow-mo critical |
| PRQ boundaries | Weight 1.4 (highest all modes). Attribute: "Fight IQ", base 0.38. |
| Rewards | XP, shards, PRQ delta (base × 1.4) |
| API deps | `POST /api/games/session`, launch-mode, session/state, WS game room |
| Smoke test | Deep link → Dojo → strike → combo → score 5 → session receipt → PRQ delta |
| Missing registry | ArenaSettings.json uses unified `karate` — must split into `karate_h2h` + `karate_endless` |

### MODE 5: karate_endless
| Attribute | Value |
|-----------|-------|
| Status | production |
| Venue path | `/Game/FEL/Venues/Dojo/Dojo` |
| Gameplay loop | Endless wave survival. Difficulty scales per wave. Score accumulates. No targetScore. No time limit. |
| Win/loss/fail | No win — survival. Loss = health depleted. Score = total at death. |
| Scoring | Points per wave + per opponent. No targetScore. modeWeight 1.4. Shard reward based on loss (15 + bonuses). |
| Session receipt | `POST /api/games/session` → `{mode_id: "karate_endless", score, duration_seconds, is_multiplayer: false}` |
| Inputs | charge (same as karate_h2h) |
| Interactables | Wave opponents, dojo mat, health bar |
| Spawn points | 1 player center + enemy spawn ring |
| Camera zones | Dynamic fight cam, zoom out as waves increase |
| PRQ boundaries | Weight 1.4. Attribute: "Fight IQ", base 0.38. |
| Rewards | XP, shards (loss formula + combo/critical bonuses), PRQ delta |
| API deps | `POST /api/games/session`, launch-mode |
| Smoke test | Deep link → Dojo → waves → difficulty increases → death → score submitted → economy |
| Missing registry | Not in UE VenueRegistry; not in ArenaSettings.json as separate entry |

### MODE 6: baseball
| Attribute | Value |
|-----------|-------|
| Status | production |
| Venue path | `/Game/FEL/Venues/BaseballPark/BaseballPark` |
| Gameplay loop | Home Run Derby. Swipe to swing. Timing + angle = distance. First to 6 HRs or time 300s. |
| Win/loss/fail | Win = 6 HRs first. Loss = opponent 6 first. Draw = tied at time. |
| Scoring | 1pt per HR. targetScore=6. timeLimit=300s. modeWeight 1.0. |
| Session receipt | `POST /api/games/session` → `{mode_id: "baseball", score, opponent_score, duration_seconds}` |
| Inputs | swipe (direction + timing = bat angle + power) |
| Interactables | Baseball (1), bat, pitcher AI, fences, distance markers |
| Spawn points | Batter box, pitcher mound |
| Camera zones | Behind-batter; ball-follow on hit; replay on HR |
| PRQ boundaries | Weight 1.0. Attribute: "Bat Speed", base 0.35. |
| Rewards | XP, shards, PRQ delta (base × 1.0) |
| API deps | `POST /api/games/session`, launch-mode, session/state |
| Smoke test | Deep link → BallPark → swipe → hit → score → session receipt → economy |
| Missing registry | None |

### MODE 7: football
| Attribute | Value |
|-----------|-------|
| Status | production |
| Venue path | `/Game/FEL/Venues/Gridiron/Gridiron` |
| Gameplay loop | Kick Return sudden death. Dodge mechanics. Sprint to endzone. 3 TDs to win. timeLimit=240s. walkScale 1.05. |
| Win/loss/fail | Win = 3 TDs first. Loss = opponent 3 first. Fail = tackled/timeout. |
| Scoring | 1pt per TD. targetScore=3. modeWeight 1.5 (highest single mode). |
| Session receipt | `POST /api/games/session` → `{mode_id: "football", score, opponent_score, duration_seconds}` |
| Inputs | kickReturn (swipe dodge, tap sprint, charge stiff-arm) |
| Interactables | Football (1), tacklers AI, endzone, field markers |
| Spawn points | Kick return position, defenders scattered |
| Camera zones | Behind-runner; overhead on big play; tackle replay |
| PRQ boundaries | Weight 1.5. Attribute: "Burst Speed", base 0.42. |
| Rewards | XP, shards, PRQ delta (base × 1.5) |
| API deps | `POST /api/games/session`, launch-mode |
| Smoke test | Deep link → Gridiron → kick return → dodge → TD → session receipt → economy |
| Missing registry | None |

### MODE 8: soccer
| Attribute | Value |
|-----------|-------|
| Status | production |
| Venue path | `/Game/FEL/Venues/SoccerStadium/SoccerStadium` |
| Gameplay loop | Penalty Shootout. Swipe direction + power. Alternating shooter/keeper. 5 goals to win. timeLimit=180s. |
| Win/loss/fail | Win = 5 goals first. Loss = opponent 5. Draw = sudden death. |
| Scoring | 1pt per goal. targetScore=5. modeWeight 1.1. |
| Session receipt | `POST /api/games/session` → `{mode_id: "soccer", score, opponent_score, duration_seconds, is_multiplayer: true}` |
| Inputs | penaltyKick (swipe direction/speed; keeper: tap quadrant) |
| Interactables | Soccer ball (1), goal, goalkeeper, penalty spot |
| Spawn points | Penalty spot (shooter), goal line (keeper) |
| Camera zones | Behind-kicker; keeper POV on save; net-cam on goal |
| PRQ boundaries | Weight 1.1. Attribute: "Shot Accuracy", base 0.40. |
| Rewards | XP, shards, PRQ delta (base × 1.1) |
| API deps | `POST /api/games/session`, launch-mode, WS game room |
| Smoke test | Deep link → Stadium → swipe shoot → goal/save → session receipt → economy |
| Missing registry | None |

### MODE 9: golf
| Attribute | Value |
|-----------|-------|
| Status | production |
| Venue path | `/Game/FEL/Venues/Links/Links` |
| Gameplay loop | Closest to Pin. Wii-style swing arc. 5 holes. timeLimit=300s. |
| Win/loss/fail | Win = closest aggregate distance. Loss = opponent closer. Fail = timeout. |
| Scoring | Distance-from-pin (lower=better). targetScore=5 holes. modeWeight 0.9 (lowest). |
| Session receipt | `POST /api/games/session` → `{mode_id: "golf", score, opponent_score, duration_seconds}` |
| Inputs | swipeGolf (draw-back power, release angle, tempo spin) |
| Interactables | Golf ball (1), tee, pin/flag, green, hazards |
| Spawn points | Tee box per hole |
| Camera zones | Tee-box behind; ball-flight track; green overhead |
| PRQ boundaries | Weight 0.9. Attribute: "Swing Precision", base 0.30. |
| Rewards | XP, shards, PRQ delta (base × 0.9) |
| API deps | `POST /api/games/session`, launch-mode |
| Smoke test | Deep link → Links → swing → ball lands → 5 holes → session receipt |
| Missing registry | None |

### MODE 10: tennis
| Attribute | Value |
|-----------|-------|
| Status | production |
| Venue path | `/Game/FEL/Venues/TennisCourt/TennisCourt` |
| Gameplay loop | Rally Ace. Serve + volley. First to 5. timeLimit=120s. walkScale 1.04. |
| Win/loss/fail | Win = 5 first. Loss = opponent 5. Draw = tied at time. |
| Scoring | 1pt per ace/winner. targetScore=5. modeWeight 1.1. |
| Session receipt | `POST /api/games/session` → `{mode_id: "tennis", score, opponent_score, duration_seconds, is_multiplayer: true}` |
| Inputs | rallyAce (swipe direction, timing power, tap volley) |
| Interactables | Tennis ball (1), racket, net, court lines, opponent |
| Spawn points | 2 baseline positions |
| Camera zones | Behind server; follow-ball rally; net-cam volley |
| PRQ boundaries | Weight 1.1. Attribute: "Rally Control", base 0.38. |
| Rewards | XP, shards, PRQ delta (base × 1.1) |
| API deps | `POST /api/games/session`, launch-mode, WS game room |
| Smoke test | Deep link → TennisCourt → serve → rally → point → session receipt |
| Missing registry | None |

### MODE 11: volleyball
| Attribute | Value |
|-----------|-------|
| Status | production |
| Venue path | `/Game/FEL/Venues/SandCourt/SandCourt` |
| Gameplay loop | Rally Ace variant. Drag-to-aim spike. First to 5. timeLimit=120s. walkScale 1.04. |
| Win/loss/fail | Win = 5 pts. Loss = opponent 5. Draw = tied at time. |
| Scoring | 1pt per spike/ace. targetScore=5. modeWeight 1.2. |
| Session receipt | `POST /api/games/session` → `{mode_id: "volleyball", score, opponent_score, duration_seconds, is_multiplayer: true}` |
| Inputs | rallyAce (drag aim spike, release power, timed bump/set) |
| Interactables | Volleyball (1), net, court, opponent |
| Spawn points | 2 net sides |
| Camera zones | Side broadcast; overhead spike; net-level block |
| PRQ boundaries | Weight 1.2. Attribute: "Spike Power", base 0.40. |
| Rewards | XP, shards, PRQ delta (base × 1.2) |
| API deps | `POST /api/games/session`, launch-mode, WS game room |
| Smoke test | Deep link → SandCourt → set → spike → point → session receipt |
| Missing registry | None |

### MODE 12: surfing
| Attribute | Value |
|-----------|-------|
| Status | production |
| Venue path | `/Game/FEL/Venues/VeniceBeach/VeniceBeach` |
| Gameplay loop | Line & balance. Rhythm-tap tricks. Score accumulates. No targetScore. timeLimit=180s. walkScale 1.06, jumpScale 1.04. ballCount=0. |
| Win/loss/fail | Win = higher trick score at time. Loss = lower. Fail = wipeout. |
| Scoring | Style × multiplier chain. No targetScore. modeWeight 1.05. |
| Session receipt | `POST /api/games/session` → `{mode_id: "surfing", score, duration_seconds, is_multiplayer: true}` |
| Inputs | rhythmTap (timed tricks, hold balance, swipe direction) |
| Interactables | Surfboard, waves (procedural), trick indicators |
| Spawn points | 1 player on wave start |
| Camera zones | Side-angle wave; close-up trick; underwater wipeout |
| PRQ boundaries | Weight 1.05. Attribute: "Wave IQ", base 0.36. |
| Rewards | XP, shards, PRQ delta (base × 1.05) |
| API deps | `POST /api/games/session`, launch-mode |
| Smoke test | Deep link → VeniceBeach → ride → tricks → score → session receipt |
| Missing registry | Shares VeniceBeach map (confirmed) |

### MODE 13: skateboarding
| Attribute | Value |
|-----------|-------|
| Status | **staging** |
| Venue path (target) | `/Game/FEL/Venues/Skate_Park/Skate_Park` (NOT in MapsToCook) |
| Current bug | EmergentPlayMap routes to VeniceBeach (wrong map) |
| Gameplay loop | Park lines. Rhythm-tap tricks on rails/ramps. Score-based. timeLimit=180s. walkScale 1.05, jumpScale 1.06. |
| Win/loss/fail | Win = higher trick score. Loss = lower. Fail = bail. |
| Scoring | Style × line multiplier. No targetScore. modeWeight TBD. |
| Session receipt | `POST /api/games/session` (when promoted) |
| Inputs | rhythmTap (tricks, swipe grind direction) |
| Interactables | Skateboard, rails, ramps, half-pipe |
| Spawn points | 1 player park entrance |
| Camera zones | Follow cam; trick close-up; overhead half-pipe |
| PRQ boundaries | Attribute: "Line Control", base 0.36. |
| Smoke test gate | Skate_Park in MapsToCook → EmergentPlayMap corrected → deep link → park loads → tricks → session receipt |
| Missing registry | Map NOT in MapsToCook; EmergentPlayMap wrong venue; PRQ modeWeight undefined |

### MODE 14: snowboarding
| Attribute | Value |
|-----------|-------|
| Status | **staging** |
| Venue path (target) | `/Game/FEL/Venues/Mountain_Slope/Mountain_Slope` (NOT in MapsToCook) |
| Current bug | EmergentPlayMap→VeniceBeach (wrong). ArenaSettings→TrainingFloor (also wrong). |
| Gameplay loop | Slope control. Downhill rhythm-tap. Score-based. timeLimit=180s. walkScale 1.04, jumpScale 1.05. |
| Win/loss/fail | Win = higher score. Loss = lower. Fail = crash. |
| Scoring | Style + speed points. No targetScore. |
| Session receipt | `POST /api/games/session` (when promoted) |
| Inputs | rhythmTap (jump/trick timing, tilt carving) |
| Interactables | Snowboard, moguls, jumps, rails, gates |
| Spawn points | 1 player slope top |
| Camera zones | Behind-rider follow; aerial jump; finish-line |
| PRQ boundaries | Attribute: "Edge Control", base 0.36. |
| Smoke test gate | Mountain_Slope in MapsToCook → EmergentPlayMap corrected → ArenaSettings corrected → slope loads |
| Missing registry | Map NOT in MapsToCook; EmergentPlayMap wrong; ArenaSettings wrong venue |

### MODE 15: gymnastics
| Attribute | Value |
|-----------|-------|
| Status | **staging** |
| Venue path | `/Game/FEL/Venues/TrainingFloor/TrainingFloor` (in MapsToCook ✅) |
| Gameplay loop | Olympic routines. Rhythm-tap tumbling. targetScore=5 routines. timeLimit=240s. |
| Win/loss/fail | Win = higher form score. Loss = lower. Fail = fall. |
| Scoring | Form 1.0–10.0 per routine. targetScore=5. modeWeight TBD. |
| Session receipt | `POST /api/games/session` (when promoted) |
| Inputs | rhythmTap (tumbling sequences, hold balances) |
| Interactables | Floor mat, balance beam, parallel bars |
| Spawn points | 1 player routine start |
| Camera zones | Judge-angle wide; skill close-up; slow-mo landing |
| PRQ boundaries | Attribute: "Form Score", base 0.35. |
| Smoke test gate | Map already in MapsToCook → deep link → TrainingFloor loads → routine → form score → session receipt |
| Missing registry | PRQ modeWeight undefined; closest to production of all staging modes |

### MODE 16: brain_brawl
| Attribute | Value |
|-----------|-------|
| Status | **staging** |
| Venue path | `/Game/FEL/Venues/NeuroArena/NeuroArena` (in MapsToCook ✅) |
| Gameplay loop | Cognitive quiz. Timed questions. ballCount=0. bScoringEnabled=false. timeLimit=120s. Deep-link only. |
| Win/loss/fail | Win = highest quiz score. Loss = lower. Fail = timeout. |
| Scoring | Points per correct × speed bonus. XP = score//10 (non-standard). No targetScore. |
| Session receipt | `POST /api/brain-brawl/submit` (NON-STANDARD). |
| Inputs | tap (select answer) |
| Interactables | Question display, answer buttons, timer, score |
| Spawn points | 1 player arena center |
| Camera zones | Static quiz-board; question transitions |
| PRQ boundaries | Attribute: "Cognitive Flex", base 0.42. No PRQ delta currently. |
| Rewards | XP only (score//10). No shards. No PRQ delta. Education track (4 briefings). |
| API deps | `POST /api/brain-brawl/submit`, `GET /api/brain-brawl/questions` |
| Smoke test gate | Standard session receipt integration → shard rewards → PRQ delta → quiz works |
| Missing registry | Non-standard session endpoint; no shards; no PRQ delta |

### MODE 17: who_scene_it
| Attribute | Value |
|-----------|-------|
| Status | **preview** |
| Venue path (target) | `/Game/FEL/Venues/NeuroArena/NeuroArena` |
| Gameplay loop | Scene recognition trivia. Timer + accuracy. Custom telemetry channel. |
| Win/loss/fail | Win = highest accuracy. Loss = lower. Fail = time expired. |
| Scoring | TBD (not implemented). |
| Session receipt | NONE (only config endpoint exists). |
| Inputs | tap (identify scenes from choices) |
| API deps | `GET /api/games/who-scene-it` (config only) |
| Smoke test | CANNOT PASS — no Swift enum, no ue_mode_maps, no EmergentPlayMap, no session receipt |
| Missing registry | Swift enum, ue_mode_maps, VenueRegistry, EmergentPlayMap, standard session receipt, scoring |

### MODE 18: court_carnival
| Attribute | Value |
|-----------|-------|
| Status | **preview** |
| Venue path (target) | `/Game/FEL/Venues/VeniceBeach/VeniceBeach` |
| Gameplay loop | Board-style party arcade (replaces mario_party_fever). 40 spaces. Mini-game rotation. Creator cards. Power-ups. |
| Win/loss/fail | Win = most stars. Loss = fewer. Fail = disconnect. |
| Scoring | Stars + mini-game wins. Partially defined in mario-party config. |
| Session receipt | `POST /api/games/mario-party/session` (non-standard; must rename). |
| Inputs | Mixed (tap, swipe, charge, rhythm per mini-game) |
| API deps | `GET /api/games/mario-party`, `POST /api/games/mario-party/session` |
| Smoke test | CANNOT PASS — no Swift enum, no ue_mode_maps, rename needed |
| Missing registry | Swift enum, ue_mode_maps, VenueRegistry, EmergentPlayMap, rename mario_party_fever→court_carnival |

### MODE 19: market_browse
| Attribute | Value |
|-----------|-------|
| Status | **non-game module** (Module Library) |
| Venue path | `/Game/FEL/Venues/Luma_Venice_Shop/Luma_Venice_Shop` (in MapsToCook ✅) |
| Gameplay loop | N/A — 3D shop browsing. No scoring. bScoringEnabled=false. ballCount=0. No timeLimit. |
| Win/loss/fail | N/A |
| Scoring | N/A |
| Session receipt | NONE |
| Inputs | Spatial navigation (tap select, swipe browse, pinch zoom) |
| Interactables | Shop shelves, item displays, Creator Card previews |
| Spawn points | 1 player shop entrance |
| Camera zones | Free-look shop; item focus; purchase overlay |
| PRQ boundaries | N/A |
| Rewards | N/A (purchases via shard/PayPal) |
| API deps | `POST /api/cards/purchase`, shop catalog endpoints |
| Smoke test | Deep link → Luma_Venice_Shop loads → browse → select → purchase flow → NO session receipt |
| Missing registry | Swift enum (marketBrowse), ue_mode_maps entry |

---

## 3. First-5-Venue Production Priority

| Priority | Venue | Cooked Path | Modes | Count | Rationale |
|----------|-------|-------------|-------|-------|-----------|
| 1 | Venice Beach Court | `/Game/FEL/Venues/VeniceBeach/VeniceBeach` | basketball_h2h, basketball_dunk, basketball_3v3 | 3 | Core franchise, featured mode |
| 2 | Zen Dojo | `/Game/FEL/Venues/Dojo/Dojo` | karate_h2h, karate_endless | 2 | Highest PRQ weight (1.4) |
| 3 | Baseball Park | `/Game/FEL/Venues/BaseballPark/BaseballPark` | baseball | 1 | Unique swipe mechanic |
| 4 | Gridiron Stadium | `/Game/FEL/Venues/Gridiron/Gridiron` | football | 1 | Highest single mode weight (1.5) |
| 5 | Soccer Stadium | `/Game/FEL/Venues/SoccerStadium/SoccerStadium` | soccer | 1 | Unique penaltyKick input |

**Total first-5-venue modes: 8**

---

## 4. Remaining Venue/Mode Backlog

| Priority | Venue | Mode | Status | Blocker |
|----------|-------|------|--------|---------|
| 6 | Links Course | golf | production | None |
| 7 | Tennis Court | tennis | production | None |
| 8 | Sand Court | volleyball | production | None |
| 9 | Venice Beach | surfing | production | Verify surfing spawns in shared map |
| 10 | Training Floor | gymnastics | staging | Need PRQ modeWeight |
| 11 | Neuro Arena | brain_brawl | staging | Standard session receipt, shards |
| 12 | Skate Park | skateboarding | staging | Map NOT in MapsToCook, EmergentPlayMap misrouted |
| 13 | Mountain Slope | snowboarding | staging | Map NOT in MapsToCook, EmergentPlayMap + ArenaSettings wrong |
| 14 | Neuro Arena | who_scene_it | preview | All registries missing |
| 15 | Venice Beach | court_carnival | preview | Rename + all registries |
| 16 | Luma Venice Shop | market_browse | non-game | Swift enum + ue_mode_maps only |

---

## 5. Registry Alignment Patch List

### Patch 1: `backend/FEL_ModeManager.production.json`
- Fix `total_modes`: 17 → 19
- Fix ALL map paths: `/Game/FEL/Maps/X` → `/Game/FEL/Venues/{Token}/{Token}`
- Change `who_scene_it.status`: "production" → "preview"
- Rename `mario_party_fever` → `court_carnival`, status → "preview"

### Patch 2: `FinalEvolutionLab/Models/GameMode.swift`
- Add: `case whoSceneIt = "who_scene_it"`
- Add: `case courtCarnival = "court_carnival"`
- Add: `case marketBrowse = "market_browse"`
- Add inputScheme + GameModeRegistry entries for each

### Patch 3: `backend/ue_mode_maps.json`
- Add: `"who_scene_it": "Neuro_Arena"`
- Add: `"court_carnival": "Venice_Beach_Court"`
- Add: `"market_browse": "Sovereign_Shop"`

### Patch 4: `infra/ue5_config/DefaultGame.ini` [EmergentPlayMap]
- REMOVE: `skateboarding=/Game/FEL/Venues/VeniceBeach/VeniceBeach` (wrong venue)
- REMOVE: `snowboarding=/Game/FEL/Venues/VeniceBeach/VeniceBeach` (wrong venue)
- ADD: `who_scene_it=/Game/FEL/Venues/NeuroArena/NeuroArena`
- ADD: `court_carnival=/Game/FEL/Venues/VeniceBeach/VeniceBeach`
- ADD (when promoting): correct paths for skateboarding + snowboarding

### Patch 5: `infra/ue5_config/DefaultGame.ini` [MapsToCook]
- ADD (promotion): `+MapsToCook=(FilePath="/Game/FEL/Venues/Skate_Park/Skate_Park")`
- ADD (promotion): `+MapsToCook=(FilePath="/Game/FEL/Venues/Mountain_Slope/Mountain_Slope")`

### Patch 6: `UnrealStarter/.../ArenaSettings.json`
- SPLIT `karate` → `karate_h2h` + `karate_endless`
- ADD `who_scene_it`, `court_carnival` entries
- FIX `snowboarding.unrealOpenLevelPackage`: TrainingFloor → Mountain_Slope (when ready)

### Patch 7: VenueRegistry files (both backend + UE)
- Add `karate_endless`, `who_scene_it`, `court_carnival`, `market_browse` entries

### Patch 8: `FELEmergentDeepLinkSubsystem.cpp`
- Rename `mario_party_fever` → `court_carnival` in GetModeToVenueMap()

### Patch 9: `backend/server.py`
- Add shard + PRQ delta to `create_game_session`
- Add XP cap (500/session)
- Rename mario-party endpoints → court-carnival

---

## 6. Smoke Test Matrix

### Universal (All 12 Production Modes)

| # | Test | Pass Criteria |
|---|------|--------------|
| T1 | Deep link launch | Correct UE map opens |
| T2 | MapLoaded event | WS `map_loaded` ≤10s |
| T3 | Session receipt | `POST /api/games/session` → 200 |
| T4 | XP award | User XP += max(10, score/5) |
| T5 | Shard reward | Correct shards (50/25/15 + bonuses) **BLOCKED: not implemented** |
| T6 | PRQ delta | modeReward() applied **BLOCKED: not in backend** |
| T7 | Activity feed | Entry with type=game |
| T8 | Sovereign telemetry | JSON with correct arena_game_mode_id |
| T9 | E3DS travel | ue_mode_maps token → correct map |
| T10 | Input scheme | Mode-specific input fires |

### Mode-Specific Tests
- basketball_h2h: Charge → shot → basket → score to 3 → win
- basketball_dunk: Charge jump → dunk style → score to 21
- basketball_3v3: Team formed → 2 balls → help defense → score to 11
- karate_h2h: Strike → combo chain → score to 5 or time 150s
- karate_endless: Wave spawns → defeat → harder wave → death → score submitted
- baseball: Swipe → bat contact → distance → HR → score to 6 or time 300s
- football: Kick return → dodge → TD → score to 3
- soccer: Swipe kick → goal/save → alternate → score to 5
- golf: SwipeGolf → flight → distance-to-pin → 5 holes
- tennis: Serve → rally → point → score to 5 or time 120s
- volleyball: Set → spike → point → score to 5 or time 120s
- surfing: Wave ride → rhythm tricks → score → time 180s

---

## 7. "Do Not Ship Until" Checklist

### Hard Gates

| # | Gate | Status |
|---|------|--------|
| G1 | `fel_prebuild_ci_check.sh --strict` passes | ⚠️ Will fail on map path mismatch |
| G2 | All 12 production deep links resolve correctly | ⚠️ surfing sharing needs verify |
| G3 | ModeManager total_modes matches entries | ❌ Says 17, has 19 |
| G4 | who_scene_it + court_carnival NOT "production" | ❌ who_scene_it is "production" |
| G5 | EmergentPlayMap no wrong-venue staging routes | ❌ skateboarding+snowboarding→VeniceBeach |
| G6 | .app bundle has cookeddata/.pak | Must verify |
| G7 | CFBundleIdentifier correct | ✅ |
| G8 | URL scheme registered | ✅ |
| G9 | All 12 modes post valid session receipts | ✅ |
| G10 | No AltStore/SideStore/OTA references | ✅ |

### Economy Gates

| # | Gate | Status |
|---|------|--------|
| E1 | create_game_session awards shards | ❌ Not implemented |
| E2 | create_game_session computes PRQ delta | ❌ Not implemented |
| E3 | XP cap ≤500/session | ❌ Not implemented |

---

*Generated from `anti-gravity-fel` branch — Commit: 9519541*
*Date: 2026-05-22*
