# FEL KNOWN ERRORS — the regression ledger

Every error this project has ever shipped, its root cause, the batch that
fixed it, and the check that proves it hasn't come back. **Every future batch
must run the REGRESSION SWEEP at the bottom before promote.** Copy this file
into every batch handed to Abacus.

| # | Symptom (as seen live) | Root cause | Fixed in | Never-repeat check |
|---|---|---|---|---|
| E1 | "Wrong sceneFilename parameter" — no character loads | `LoadAssetContainerAsync('', '/models/x.glb')` (empty rootUrl + leading slash) and missing glTF loader side-effect import | M29/M30 | Console has zero `sceneFilename` errors; `@babylonjs/loaders/glTF` import present in CharacterLibrary |
| E2 | Every mode: `[FEL-ANIM] MISSING CLIP` — nothing animates | `instantiateModelsToScene` suffixes AnimationGroup names (`guard`→`guard_c58`), breaking alias lookups | M30 | Zero `MISSING CLIP` console lines across a full mode sweep |
| E3 | Every mode errors out seconds after start ("black screen detected" loop) | RenderWatchdog v1 sampled the mid-pipeline framebuffer (false positive) and armed outside the playing phase | M34 | Watchdog samples final composited screenshot, arms ONLY in `playing`, needs 2 consecutive black samples |
| E4 | True black screens with no recovery UI | No error boundary around the 3D canvas | M31 | GlobalErrorBoundary mounts every mode route; smoke test green |
| E5 | Characters sunk to their waists in the floor | Imported GLB clips key `Hips.position` in clip-local space below our floor | M35 | importSanitizer strips imported position tracks + GroundLock clamps every frame; record 60s of karate — zero sunk frames |
| E6 | T-pose after any one-shot animation ends | Finished non-looping AnimationGroup drops weights → bind pose | M35 | `neverBindPose()` wraps every animator; zero T-pose frames in sweep video |
| E7 | Two control decks on screen at once, neither works | Legacy in-canvas buttons AND new deck both mounted; neither wired to InputBus | M35 | DOM census: exactly ONE stick + ONE action cluster; every verb visibly acts |
| E8 | Dunk sequence stalls forever mid-attempt | No timeout on cinematic phases; a failed clip/await hangs the mode | M35 | Watchdog budgets on every phase; deliberately ignore SLAM → auto-resolves as miss |
| E9 | Hero/action out of frame (karate stares at floor, football runner invisible, camera at feet) | Camera targeted feet/look-ahead at y=0 with no pitch cap or subject-height offset | **M37** | FrameGuard: hero projected on-screen ≥95% of a 60s run in every mode; `[FEL-FRAME]` errors are zero |
| E10 | Board sports render NOTHING (flat clear-color screen, HUD ticking) | Ride modes never build world geometry / camera opens facing empty space | **M39** | SpawnGuard: `[FEL-SPAWN]` asserts ≥ N world meshes + hero visible before phase=playing; screenshot of each ride mode shows terrain |
| E11 | Precision sports (tennis/golf/baseball/soccer) have no characters at all | Modes drive a ball but never spawn the athlete or furniture | **M40** | SpawnGuard hero assert; screenshots show athlete + net/flag/plate/keeper |
| E12 | 404 on every mode page: `/img/venues/*.jpg` | Venue thumbnail images never shipped | **M37** | Network tab: zero 404s on mode routes (procedural thumbnails) |
| E13 | Buttons/keys "don't work" even when one deck renders | Touch deck not wired to InputBus; keyboard map undocumented/divergent | M35/M37 | Single KeyboardMap + TouchOverlay both emit the same FelInput; sweep proves every verb acts |
| E14 | Secrets nearly committed (Firebase plist, API keys) | Config files in repo tree | early | `.gitignore` covers them; secret scan green on every batch; env vars only |
| E15 | Real-money features shippable without gates | — | M33/M36 | Cash entry requires geo+18+ +limits; USD rails separate from shards; free contests unaffected |
| E16 | Characters T-pose almost everywhere, on almost every action, across EVERY mode, with no console warning | Every sport-specific clip name in the mode code (`golf_address`, `tennis_forehand`, `board_ride_idle`, `run_forward`, `derby_swing`, `karate_punch_light`, `penalty_strike`, …) does not exist on the live rig — it ships only `guard/high_kick/hook/jab/jumpshot/roundhouse/run/uppercut/walk` plus the M24 authored set. Unresolved `animator.play()` calls silently no-op instead of logging or falling back, so weights stay at zero (bind pose). This is content-availability, not a logic bug — see M42 README "content gap" note. | **M42** | `clipRegistry.REAL_CLIPS`/`SPORT_CLIP` is the only source of clip-name strings in mode code; `installSafePlay` makes an unresolved name impossible to reach silently — any miss logs `[FEL-ANIM] MISSING CLIP` AND substitutes a real clip. Sweep: zero T-pose frames, zero unlogged bind-pose in any mode |
| E17 | Camera pressed flat against a dojo wall, filling the frame with a blank tan plane | M37's occlusion pull-in (`hit.pickedPoint - toCam*0.3`) could still land inside/against geometry in tight venues; the 'fight' preset's 5.2-unit pullback exceeds the dojo room's clearance from off-center player positions | **M42** | CameraDirector v2.2: minimum safe distance (1.8u) + larger pull-in margin (0.6u) + two alternate-angle retries + guaranteed-clear overhead fallback if boxed in on all three; fight preset pulled to 4.2u. Sweep: record 60s of karate near every wall — camera never shows a blank surface at point-blank range |
| E18 | Skater falls through the skatepark floor forever (observed y=0 → y=−151, still falling) | Rider's ground-snap depends entirely on a single downward raycast; if it misses for any reason there is no floor | **M42** | GroundRide v3: hard floor clamp — after N consecutive missed raycasts or any position below the venue floor − 0.5, the rider is force-clamped to the floor and re-grounded. Categorically prevents infinite falling regardless of raycast reliability |
| E19 | Mid-drive in football, the field vanishes and the runner floats in an empty void for ~1s around a tackle/down transition | Suspected: shared bulk-dispose path (`MobPool.disposeAll()`) reaching further than the mode's own defenders | **M42** | FootballRushMode owns its defender list directly and disposes exactly those characters — no shared bulk-dispose call. Sweep: play a full 4-down drive, confirm the field and hero are visible through every tackle/first-down transition |
| E20 | HUD shows duplicated labels: "RD RD 1/7", "5 YD · 0 EVA YD · 0 EVA", "1 GOALS PTS" | Mode code embedded its own label text ("RD ", "YD · N EVA", "GOALS") into a field name the live bezel ALSO auto-decorates | **M42** | Mode code passes bare values (`round: '1/7'`, `yards: 5`, `evades: 0`, `score: 1`) for any bezel-templated field name; custom text goes only in `hint`/`banner`. Sweep: no doubled words in any HUD readout |
| E21 | The entire game is silent — zero `<audio>`/`<video>` elements, zero audio network requests, on every mode | No audio system was ever built; nothing to fix incrementally, there was simply nothing there | **M43** | `SoundKit` (synthesized Web Audio, zero external asset files) wired into every mode: hit-stop/shake bundle now includes sound (`gameFeel.impact()`), plus per-mode whoosh/score/miss/crowd/whistle/ambient calls. Sweep: every mode produces audible feedback on its core actions within the first 10 seconds of play |
| E22 | Every pursuing enemy/defender in every mode (karate opponents, football defenders) has likely been T-posing while chasing the player | `MobSteering.ts`'s shared `Mob.startPursuit()` played a clip named `'run_forward'` — never a real clip (same root cause as E16), but living in shared infrastructure outside every mode file M42 patched, so the earlier clip-registry sweep never caught it | **M45** | `MobSteering.ts` routed through `clipRegistry`/`installSafePlay` like every other spawn path. Sweep: record a pursuing mob in any mode — it is visibly running, never bind-posed |
| E23 | Football field required running further (91.44 units) than the venue is long (90 units) — touchdown was mathematically unreachable via the visible field; defenders could spawn past the back wall | Touchdown/defender-spawn constants were authored independently of `VenueKit.buildGridiron`'s actual dimensions | **M44** | `FIELD_LENGTH`/`DEFENDER_MAX_DEPTH` constants derived from the real venue size. Sweep: a full drive reaches a touchdown before the runner reaches the back wall |
| E24 | A skilled surfer who never wipes out rides off the edge of the world and coasts over empty space for the rest of the session | Only the wave's z-position wrapped every 140 units; the rider's own position grew without bound | **M44** | Rider wraps in lockstep with the wave at the same 140-unit period. Sweep: ride the full 90s pocket without wiping out — the world and wave stay visually present throughout |

| E25 | Dunk Contest: character is in a dead T-pose through the entire charge/launch/apex sequence, legs never bend for the jump, despite console showing zero errors | Live-instrumented proof (patched the actual deployed bundle, not just batch source) shows clip resolution, registration, AND crossfade weight all reach a fully correct state (`k=1.000` on the exact intended clip) — the failure sits at the bone-transform→rendered-mesh boundary, past what remote console/JS instrumentation can directly observe. Forcing CPU skinning (ruling out GPU float-texture skinning limits) did not change the outcome, though a forced shader recompile wasn't confirmed. Test environment caveat: only a software-rendered sandbox browser was available — a real GPU device was never tried | **M51 (partial — mitigation + detection, not a confirmed root-cause fix)** | `SkinningGuard` fires a loud `[FEL-ANIM] SKINNING STALL` console error within ~1/3s of any character whose bone never visibly moves despite a correctly-weighted playing clip, and attempts an automatic CPU-skinning fallback. Also fixed independently in M51: every mode's every-frame `.play(sameClip, {loop:true})` call in `update()` was resetting weight to 0 and restarting the crossfade every single frame — confirmed live via bundle instrumentation — now a no-op for an already-current, already-playing clip. **Needs a real-device check**: confirm whether Dunk Contest animates correctly on actual hardware; if yes, this was a sandbox-only artifact and the CPU-skin fallback can be dropped |

| E26 | 1v1 Hoops / 3v3: right after a shot near the rim, the camera can transiently bury itself in the baseline wall (frame full of flat wall paint) or drop under the court plane (mostly-black frame), recovering after | The `hoops`/`team` presets' pullback + the new drive/arc sequences put the camera behind the baseline where the venue wall and floor edge sit closer than the presets' distance; occlusion resolution recovers but the bad frames are visible | open — found in the M63-live sweep | Candidate fix: clamp camera target z ≥ baseline+margin in hoops/team presets, or reuse the fight preset's MIN_SAFE_DISTANCE+overhead-fallback path for baseline proximity. Sweep: drive to the rim and shoot repeatedly — zero point-blank-wall or under-floor frames |

**E25 RESOLVED (reframed)** — the M63-live sweep shows the player's pose now
visibly differs by phase (bent-forward gather while charging vs. arms-out at
idle), i.e. skeletal animation WORKS and always did — consistent with every
M51 instrumentation result. The residual "T-pose look" is a CONTENT issue:
the authored `idle_stand` clip keys the arms only ~8-10° away from this
rig's arms-out bind pose, so idling is nearly indistinguishable from bind.
Fix is content, not pipeline: re-author `idle_stand` (and the low-deviation
locomotion fills) with arms brought DOWN to a natural stance (~65-75° of
arm rotation), which will also make every mode's idle instantly look right.

## REGRESSION SWEEP (run before every promote)
1. Console sweep of all mode routes: zero `MISSING CLIP`, zero `sceneFilename`,
   zero `[FEL-FRAME]`, zero `[FEL-SPAWN]`, zero unexpected 404s.
2. DOM census on two modes: exactly one control deck.
3. 60s recorded run of karate + dunk + one ride mode + one precision mode:
   characters on the floor plane, no T-pose, hero framed, world visible.
4. HUD readout check on every mode: no doubled words ("RD RD", "YD · N EVA
   YD · N EVA") in any field.
5. Camera-in-geometry check: stand a fighter next to every dojo wall/pillar —
   camera never fills the frame with a blank surface at point-blank range.
6. Ride-mode floor check: skate/snowboard/surf for 60s each — the rider's Y
   position never drifts below the venue floor.
7. Smoke test (M31) green across every mode id.
8. Secret scanner green.

## CONTENT GAP (not a code defect — flagged for the content workstream)
The live hero rig ships nine generic clips (`guard, high_kick, hook, jab,
jumpshot, roundhouse, run, uppercut, walk`) plus sixteen procedurally-authored
ones (idle/strafe/jump/dunk*/football*/karate_hit_react/karate_knockdown).
E16's fix (clipRegistry) makes every mode ANIMATED and never bind-posed by
aliasing sport gestures onto these clips, but a golf swing playing 'roundhouse'
or a tennis forehand playing 'jab' is a stand-in, not a correct sport-specific
animation. Closing this gap for real requires either commissioning/importing
actual golf/tennis/board/soccer mocap clips, or authoring more procedural
clips the M24 way (as was done for the basketball Eastbay dunk and the
football evasions). Recommend prioritizing by mode traffic once M42 ships.

Diagnostics stay loud in production (`[FEL-ANIM]`, `[FEL-WATCHDOG]`,
`[FEL-FRAME]`, `[FEL-SPAWN]`, `[FEL-DUNK]`) — they are how each live audit
finds the next bug in minutes. Never strip them.
