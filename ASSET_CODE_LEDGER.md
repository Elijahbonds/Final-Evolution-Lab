# FEL Asset & Code Ledger — inventory reconciled against the mode vision
Generated 2026-07-15 (Task A step 1 of the Environment/Tech pass).
Rule: vision decides need; nothing is built just because an asset exists.
**Nothing is deleted without Elijah's explicit sign-off. Parked ≠ lost.**

## Verdict summary
USE-NOW = serves the Dunk/Venice slice → wire it in.
PARK = plausibly useful later → listed in the backlog manifest below.
CUT = dead/duplicate → awaiting sign-off, listed at bottom.

---

## 3D ASSETS

### USE-NOW (Dunk / Venice hero environment)
| Asset | Path | Mode/scene | Notes |
|---|---|---|---|
| Venice Beach court (Meshy FBX) | assets/nexus/source/venice_beach_court_model_fbx.fbx | dunk / venice | Source of record; needs Blender→GLB. **License NEEDS-VERIFY (Meshy tier unrecorded)** |
| Luma Venice shop (Meshy FBX) | assets/nexus/source/luma_venice_shop_environment_model_fbx.fbx | venice landmark | Same conversion + license flag |
| Venice blacktop GLB | abacus-app/public/models/maps/venice-blacktop.glb | dunk / venice | Already GLB — fastest path into Babylon. Provenance/license NEEDS-VERIFY |
| Venice blue court GLB | abacus-app/public/models/maps/venice-blue-court.glb | dunk alt court | Same |
| Venice sky day/sunset | assets/skyboxes/venice-sky-{day,sunset}.png | venice skybox | Elijah's own photos — **license SAFE** |
| Elijah avatar rigs | abacus-app/public/models/elijah{,-hero}.glb | shared avatar | Own likeness ✓; rig↔anim-JSON compatibility NEEDS-VERIFY |
| Dunk mocap | abacus-app/public/mocap/dunk.json | dunk action | Pairs with hybrid anim/physics blend work |

### USE-NOW (animation keyframes — dunk loop set, from seeles_work/assets/animations)
anim_standing_idle · anim_basketball_dunk · anim_basketball_dribble_run ·
anim_basketball_jump_shot · anim_basketball_defensive_idle · anim_sprint_run_loop
(Provenance: Seele pipeline regenerated as nexusanim keyframes — rights NEEDS-VERIFY once, covers all 22.)

### PARK (backlog manifest — declared by archetype)
| Group | Paths | Archetype / future mode |
|---|---|---|
| 11 environment FBX | assets/nexus/source/{baseball_park, golf_course, gridiron_stadium, gymnastics_floor, mountain_slope, neuro_arena, skate_park, soccer_stadium, tennis_court, volleyball_sand, zen_dojo}* | Court-rally / Ride-carve / Court-free-3D venues, post-dunk |
| 4 map GLBs | abacus-app/public/models/maps/{dojo,shop,venice-skatepark}.glb + story-hub.glb | karate / shop / skate / story |
| 16 remaining anim JSONs | seeles_work/assets/animations/* | per-mode actions, post-dunk |
| Venue photo set | abacus-app/public/{venues,backdrops}/* | menus/cards (2D, license from Meshy renders NEEDS-VERIFY) |

### Missing vs vision (no asset exists — flagged, not fabricated)
- **Audio: ZERO audio files in the repo** — the sensory-bus impact SFX (feel DoD) has nothing to play. Need one commercial-safe impact SFX minimum.
- Rim/backboard as separate gameplay-grade mesh (courts may bake them in — verify during Venice assembly; integrity gate requires a rim node).
- Placeholder NPC/defender capsule set (cheap, generate in-engine).

## CODE MODULES

### USE-NOW (primary Babylon slice — frontend/src)
PlayDunkPage · game/modes/dunking/{Mode,Scene,HUD} · GameModeInterface ·
ModeRegistry · input/{InputSystem,GamepadOverlay} · systems/{Score,Combo,PRQ,
HUDState,Audio,VFX,Analytics,SkillLab,Wearable,OfflineCache} (wired via
createSharedSystems). Karate trio = next-in-line (registry-live, unrouted).

### PARK (code)
| Module | Why parked |
|---|---|
| frontend/src/game/core/movement/{Jump,Locomotion,Strike,Dodge}Core | Orphaned (only re-exported); superseded by the coming /systems stateMachine+feelConfig build — harvest constants, don't wire |
| 6 gated sport modes (golf/soccer/tennis/football/volleyball/baseball JS) | Post-dunk; registry keeps them stubbed |
| app/gameplay + engine/* (C++), tests/unit | Donor/spec only per working context |
| backend/app (FastAPI platform) + dataconnect/supabase/firebase configs | Platform track, post-FEL |
| abacus-app/ | Deployed demo + money-rails testbed; keep syncing exports |
| Unity6-FinalEvolutionLab · UnrealIntegration · UnrealStarter · NexusStarter · FinalEvolutionLab (iOS) + fastlane/Gemfile | Legacy/parallel runtimes — frozen |
| seeles_work/ | Asset source of record (keep) |

### CUT — EXECUTED 2026-07-15 (approved by Elijah)
1. ✂ `seeles_unzipped/` — removed (seeles_work remains the source of record).
2. ✂ `build-gate/`, `build-headless/`, `build-story/` on-disk trees — deleted
   (regenerable; gitignored).
3. ✂ `ping_pong_output.txt`, `udp_output.txt` — removed.
4. ✂ `frontend/build/` local artifacts — deleted (regenerable).

## Venice USE-NOW plan (next step after sign-off)
venice-blacktop.glb (immediate) + FBX→GLB conversions (hero fidelity) +
skyboxes + rim/backboard integrity nodes + spawn markers → assembled via the
scene-manifest schema (Task A step 3), gated by required-node smoke test.
