# NEXUS Modes Capability Matrix

**Scope:** `app/gameplay/` headless simulators replacing UE game modes  
**Updated:** 2026-06-27 (mode vision master handoff — per-mode PASS criteria + 18/18 production registry)  
**Build gate:** `ctest --test-dir build-headless` + `./scripts/nexus_validate_production_modes.sh`  
**Authority:** `DELIVERY_BAR_FINAL_EVOLUTION.md` § Gameplay / arena / NEXUS · `NEXUS_QUALITY_BAR.md` mode scorecard · `artifacts/coord/mode_vision_master_handoff.json`

This document maps all **19 registered arena modes** to NEXUS implementation depth. Depth tiers:

| Tier | Meaning |
|------|---------|
| **prod** | Full agent command flow, physics/fitness feedback, integration test |
| **sim** | `OutcomeSportMode` pulse scoring + `GameplayManager::evaluateOutcome()` |
| **staging** | Validate-only simulator (`release_state: validate_only`); registry `kStaging` |
| **non-game** | Navigation module; no scoring |

---

## Production simulators (5)

| Mode ID | Display | Venue | NEXUS simulator | Agent commands | Integration test |
|---------|---------|-------|-----------------|----------------|------------------|
| `basketball_dunk` | Dunk Contest | Venice_Beach_Court | `DunkContestMode` | `fel.dunk.charge_begin`, `charge_release`, `apex_tap` | `flagship_basketball_dunk_validate_only_integration` |
| `karate_endless` | Karate: Dojo Breach | Zen_Dojo | `KarateEndlessMode` | `fel.karate.action` (light/heavy/block/dodge/counter), `fel.karate.wave` (co-op slots, shrine perks, exfil) | `flagship_karate_kata_validate_only_integration` |
| `basketball_h2h` | Head to Head (Venice pickup proxy) | Venice_Beach_Court | `VenicePickupMode` | throw-catch pulse scoring via fitness priming | `flagship_venice_pickup_validate_only_integration` |
| `court_carnival` | Court Carnival | Venice_Beach_Court | `CourtCarnivalMode` | `fel.carnival.trigger_pad`, `fel.carnival.roll_dice` | `flagship_court_carnival_validate_only_integration` |
| `who_scene_it` | Who Scene It | Neuro_Arena | `WhoSceneItMode` | `fel.scene.buzz_in`, `fel.scene.answer` | `flagship_who_scene_it_validate_only_integration` |

**Aliases:** `karate_kata` → `karate_endless` sim; `venice_pickup` → `basketball_h2h` @ Venice_Beach_Court.

### Karate: Dojo Breach — local co-op wave survival (COD Zombies × martial arts)

Extended `KarateEndlessMode` on registry id `karate_endless` (no new production mode slot).

| Feature | Implementation |
|---------|----------------|
| Waves | Escalating breach rounds via `WaveSpawner`; win at wave 10 clear or intermission **exfil** |
| Combat | `fel.karate.action` — light/heavy strike, block, dodge, counter; combo chains; special damage at 8+ streak |
| Local co-op | `fel.karate.wave` `{ "player_count": 1–4 }` — shared score, per-player HP/combo, active fighter slot |
| Shrine perks | Intermission only — `{ "perk": "speed" \| "power" \| "guard" }` (one per breather) |
| Exfil | `{ "exfil": true }` during intermission after wave ≥ 10 |
| Multiplayer honesty | UI labels **LOCAL CO-OP** — no online netcode in MVP |
| Session JSON | `wave_state`, `players[]`, `multiplayer: "local_coop"`, `target_wave: 10` |

Integration test: `karate_endless_local_coop_wave_survival` in `gameplay_test.cpp`.

---

## Dedicated full simulators — promoted to production (4)

Former staging tier (`kStaging` → `kProduction`, 2026-06-19). Full agent command flow + dedicated mode classes; same validate-only CI gate as all production modes.

| Mode ID | Display | Venue | NEXUS simulator | Agent commands | Integration test |
|---------|---------|-------|-----------------|----------------|------------------|
| `gymnastics` | Gymnastics | Training_Floor | `GymnasticsMode` | `fel.gymnastics.tap`, `fel.gymnastics.deduct` | `flagship_gymnastics_validate_only_integration` |
| `brain_brawl` | Brain Brawl | Neuro_Arena | `BrainBrawlMode` | `fel.brain.answer` | `flagship_brain_brawl_validate_only_integration` |
| `skateboarding` | Skateboarding | Skate_Park | `SkateboardingMode` | `fel.skate.trick`, `fel.skate.bail` | `flagship_skateboarding_validate_only_integration` |
| `snowboarding` | Snowboarding | Mountain_Slope | `SnowboardingMode` | `fel.snow.carve`, `fel.snow.jump`, `fel.snow.butter`, `fel.snow.wipeout` | `flagship_snowboarding_validate_only_integration` |

**Note:** `surfing` also has a dedicated `SurfingMode` simulator (not generic `OutcomeSportMode`); see outcome-sport table below for the remaining pulse-evaluator modes.

---

## Outcome-sport simulators (8)

Production registry modes with `OutcomeSportMode` — `fel.sport.pulse` timing/success scoring mapped to mode-specific `MatchScoreInput` fields and `GameplayManager::evaluateOutcome()`. **Ship bar:** each mode needs mode-distinct UX + evaluator depth; generic pulse alone does not satisfy `DELIVERY_BAR_FINAL_EVOLUTION.md` production gameplay pillar.

| Mode ID | Venue | Evaluator | Agent command | Mode-specific pulse param |
|---------|-------|-----------|---------------|---------------------------|
| `basketball_3v3` | Venice_Beach_Court | basketball score compare | `fel.sport.pulse` | `shot_type`: `three_pointer` (+bonus pts); hot-streak at 3+ |
| `karate_h2h` | Zen_Dojo | HP compare | `fel.sport.pulse` | `action`: `light_strike`, `heavy_strike`, `block`, `counter` |
| `baseball` | Baseball_Park | runs @ inning 9 | `fel.sport.pulse` | `play_type`: `home_run` (4 runs @ timing≥0.92), `strikeout` |
| `football` | Gridiron_Stadium | TD compare | `fel.sport.pulse` | `play_type`: `touchdown`, `field_goal` (+3), `turnover` |
| `soccer` | Soccer_Stadium | goals compare | `fel.sport.pulse` | `shot_type`: `penalty` (high-stakes goal exchange) |
| `golf` | Links_Course | strokes vs par | `fel.sport.pulse` | `club`: `putt` (birdie trim @ timing≥0.88); 9-hole par=36 |
| `tennis` | Tennis_Court | sets compare | `fel.sport.pulse` | `shot_type`: `ace` (+2 games); games-to-4 set logic |
| `volleyball` | Sand_Court | rally to 25 | `fel.sport.pulse` | `rally_type`: `ace_serve` (+2 rally points) |

Integration test: `flagship_outcome_sport_validate_only_integration` (baseball + volleyball lifecycle).

**Dedicated surfing sim (not OutcomeSportMode):**

| Mode ID | Venue | NEXUS simulator | Agent commands | Integration test |
|---------|-------|-----------------|----------------|------------------|
| `surfing` | Venice_Beach_Surf | `SurfingMode` | `fel.surf.carve`, `fel.surf.aerial`, `fel.surf.wipeout` | `flagship_surfing_validate_only_integration` |

**Asset honesty:** `surfing` venue mesh is a **Venice court proxy** until dedicated surf-break glTF ships (`assets/nexus/NEXUS_CONTENT_GAPS.md`).

SceneKit iOS shells provide visual gameplay; NEXUS C++ owns session receipts and outcome evaluation.

---

## Non-game module (1)

| Mode ID | Venue | Release | Notes |
|---------|-------|---------|-------|
| `market_browse` | Vault_Shop | non-game | module library navigation |

---

## Cross-cutting systems (all active sessions)

| System | Path | Depth |
|--------|------|-------|
| Throw–catch physics | `throw_catch_physics.cpp` | **prod** — FRC/IAP impulse, catch radius, agent envelope |
| Fitness data | `fitness_data.cpp` | **prod** — `fel.fitness.update/update_frc/update_iap`, `fel.query.get_fitness_state` |
| Creative voxel | `voxel_command_parser.cpp` | **prod** — `fel.creative.*` with `agent_summary` + bounds |
| Arena session | `arena_session_manager.cpp` | **prod** — start/pause/end, receipts, bridge |
| HUD relay | `hud_relay_service.cpp` | **prod** — tick frames with mode_state + throw_catch |

---

## Mode count summary

NEXUS uses a deliberately split registry surface:

| Surface | Count | Notes |
|---------|-------|-------|
| C++ runtime registry | 19 | 18 production gameplay runtimes + `market_browse`; canonical dunk runtime id is `basketball_dunk`. |
| Swift iOS arena registry | 20 | 18 launchable NEXUS runtime ids represented as 19 cards because dunk is split into `basketball_dunk_irl` / `basketball_dunk_3d`, plus `market_browse`. |
| Backend ModeManager JSON | 22 | Adds backend-facing aliases/modules (`basketball_dunk`, split dunk ids, `movement_lab`) for routing and preview metadata. |

| Tier | Count |
|------|-------|
| prod — flagship full sim | 5 |
| prod — dedicated full sim (ex-staging + surfing) | 5 |
| prod — outcome sport (`OutcomeSportMode`) | 8 |
| non-game | 1 |
| **Total registered** | **19** |
| **Production validate @ mobile** | **18** |

---

## Per-mode PASS criteria (vision-aligned — bar not lowered)

Two tiers. **Validate PASS** = CI + protocol honesty (claimable today). **Ship PASS** = `DELIVERY_BAR_FINAL_EVOLUTION.md` gameplay pillar + `NEXUS_QUALITY_BAR.md` world-class criteria — required before marketing a mode as a finished title.

### Universal criteria (all 18 production modes)

| # | Criterion | Validate PASS | Ship PASS |
|---|-----------|:-------------:|:---------:|
| V1 | `./scripts/nexus_validate_production_modes.sh` @ `NEXUS_MESH_PROFILE=mobile` | Required | Required |
| V2 | Dedicated simulator or documented outcome evaluator (not registry stub) | Required | Required |
| V3 | Flagship integration test green in `nexus_gameplay_test` | Required | Required |
| V4 | Agent command contract + win/lose session JSON in mode envelope | Required | Required |
| V5 | iOS launch: `GamePlayView` → `NexusGameplayEngine` + hybrid viewport when mesh bundled | Required | Required |
| V6 | Stick/tap moves **visible** avatar; chase camera (not orbit-only HUD) | Sim **MET** (`3d_gameplay_handoff.json`) | **Device** proof (V-013) |
| V7 | `fel.arena.end_session` → POST-ready receipt per `infra/GAMEPLAY_RECEIPT_CONTRACT.md` | Stub transport **MET** | Live authenticated POST (V-012) |
| V8 | Honest preview labeling (`FELPreviewLabel` where stub; no fake online MP) | Required | Required |
| S1 | Physical iPhone Metal venue draw + Instruments ≥60 FPS sustained | N/A | Required |
| S2 | Athlete avatar: imported seeles mesh **or** explicit procedural honesty in UI | Procedural **MET** (labeled) | Imported rig **OPEN** |
| S3 | Online multiplayer only when explicitly shipped; otherwise **LOCAL CO-OP** label | Required | Required |

### Per-mode matrix

| Mode ID | Cluster | Validate PASS | Ship PASS | Ship blockers (honest) |
|---------|---------|:-------------:|:---------:|------------------------|
| `basketball_dunk` | flagship | **MET** | **PARTIAL** | Device Metal (S1); athlete mesh (S2); live receipt POST |
| `basketball_h2h` | flagship | **MET** | **PARTIAL** | Same + pickup throw-catch rigid-body (engine) |
| `court_carnival` | flagship | **MET** | **PARTIAL** | Device Metal; party-board UX depth vs pulse pads |
| `who_scene_it` | flagship | **MET** | **PARTIAL** | Device Metal; film-quiz content library scale |
| `karate_endless` | flagship | **MET** | **PARTIAL** | Device Metal; **online MP N/A** (local co-op only); athlete mesh |
| `gymnastics` | action | **MET** | **PARTIAL** | Device Metal; judge routine UX vs tap sim |
| `brain_brawl` | neuro | **MET** | **PARTIAL** | Device Metal; trivia bank depth |
| `skateboarding` | action | **MET** | **PARTIAL** | Device Metal; trick animation fidelity |
| `snowboarding` | action | **MET** | **PARTIAL** | Device Metal; line-score UX vs carve sim |
| `surfing` | action | **MET** | **PARTIAL** | Dedicated surf mesh proxy; device Metal |
| `basketball_3v3` | outcome | **MET** | **PARTIAL** | Outcome pulse ≠ full 3v3 sim; device Metal; online MP **OPEN** |
| `karate_h2h` | outcome | **MET** | **PARTIAL** | HP pulse ≠ full fight sim; device Metal; online MP **OPEN** |
| `baseball` | outcome | **MET** | **PARTIAL** | Inning pulse ≠ full diamond sim; device Metal |
| `football` | outcome | **MET** | **PARTIAL** | TD pulse ≠ full gridiron sim; device Metal |
| `soccer` | outcome | **MET** | **PARTIAL** | Penalty pulse ≠ full match sim; device Metal |
| `golf` | outcome | **MET** | **PARTIAL** | Putt pulse ≠ full course sim; device Metal |
| `tennis` | outcome | **MET** | **PARTIAL** | Ace pulse ≠ full rally sim; device Metal |
| `volleyball` | outcome | **MET** | **PARTIAL** | Rally pulse ≠ full sand-court sim; device Metal |
| `market_browse` | non-game | **MET** (preview) | **OPEN** | Non-scoring module; economy authority per contract |

**Cluster audit sources:** `artifacts/coord/mode_vision_master_handoff.json` (synthesizes `sim_all_modes_handoff.json`, `gameplay_handoff.json`, `3d_gameplay_handoff.json`, `karate_zombies_handoff.json`, `assets_handoff.json`, `phase8_gameplay_handoff.json`, `emulator_nexus3d_handoff.json`, `quality_handoff.json`).

---

## Verification

```bash
cmake -S . -B build-headless -DNEXUS_ENABLE_RENDERER=OFF -DNEXUS_BUILD_RUNTIME=OFF -DNEXUS_BUILD_TESTS=ON
cmake --build build-headless -j$(sysctl -n hw.ncpu)
ctest --test-dir build-headless --output-on-failure
./scripts/nexus_gameplay_regression.sh
./scripts/nexus_validate_production_modes.sh   # 18 production modes
./scripts/nexus_build_gate.sh                  # full matrix (staging count 0)
```

Flagship integration tests live in `tests/unit/gameplay/gameplay_test.cpp`.

---

## Honest remaining gaps (OPEN — bar not lowered)

| Gap | Impact | Vision ID |
|-----|--------|-----------|
| **Device Metal venue draw** | 18/18 meshes validate + sim hybrid **MET**; physical iPhone draw + 60 FPS Instruments proof **unproven** | V-013 |
| **Online multiplayer** | No netcode in MVP; `karate_endless` correctly labeled **LOCAL CO-OP**; outcome/H2H modes must not imply online matchmaking until server sync ships | — |
| **Athlete meshes** | Hybrid viewport uses procedural `SCNCharacter` capsules; **35 seeles_work athlete FBX imports pending** — procedural honesty required until import | S2 |
| **Outcome-sport depth vs pulse** | 8 modes use `OutcomeSportMode` evaluators — CI **MET**, ship bar needs mode-distinct UX beyond pulse scoring | DELIVERY_BAR § Gameplay |
| **Surfing venue mesh** | Reuses Venice court mesh (no dedicated surf break asset) | assets_handoff |
| **Live session receipt POST** | Queued locally; authenticated Firebase POST stubbed | V-012 |
| **Signed TestFlight IPA** | Dry-run PASS; no `.xcarchive`/IPA on disk | V-003 |
