# M23 — ANIMATION CODE FIXES (from live-build forensics)

Copy this document into Abacus together with every file in `files/`.

---

## PROMPT FOR ABACUS

Apply the code fixes in this package. They are written against YOUR ACTUAL CODE —
we downloaded and read the live bundle (`app/play/dunk/page-*.js`, the animation
hook in chunk 5954, the clip registry in chunk 9595) and the shipped model
(`/models/elijah-hero.glb`). The diagnosis below is exact, not a hypothesis.

## THE DEFINITIVE DIAGNOSIS (verified July 2026)

1. **Your clip registry (chunk 9595, `l.ZU`) defines ~60 clip names** —
   `idle_stand`, `run_forward`, `sprint_forward`, `strafe_left`,
   `karate_punch_light`, `bball_shoot_jumper`, `dunk_360_eastbay`, all the
   football/soccer/golf/baseball/board names. The per-mode mapping function is
   complete and correct.
2. **Your shipped model `elijah-hero.glb` contains exactly 9 clips:**
   `guard, high_kick, hook, jab, jumpshot, roundhouse, run, walk, uppercut`.
3. **ZERO names match.** Registry asks `run_forward`; asset has `run`. Registry
   asks `karate_punch_light`; asset has `jab`. Registry asks `dunk_360_eastbay`;
   asset has nothing. Your animation hook's `play()` does
   `actionMap.get(name)` and **returns null silently on a miss — so every
   animation request in every mode fails.** That is the T-pose, the penguin walk,
   the strikes that never fire, the guard-pose "dunk".
4. The dunk path compounds it: `useCharacter({ clipName: "dunk", subStartFrame,
   subEndFrame })` sub-clips `animations[0]` — which is **`guard`** — and scrubs
   it through the flight. The "SHOWTIME" dunk is literally scrubbing a karate
   guard pose.
5. Your animation hook itself (mixer, actionMap, cross-fade `play()`, `bone()`
   accessor, finished-events) is **well built — keep it.** The perf HUD and
   budget config (60fps/120 draws/180k tris) are also good — keep them.
6. Lighting: karate/skate/football scenes render near-black (verified again this
   session); dunk scene loses its sky mid-attempt. The venue GLB is a single
   unlit-looking mesh (`venice-blue-court.glb` — the court is literally blue).

## THE FIX (three layers, all included as code)

### Layer 1 — `clipResolver.ts`: make every play() resolve TODAY
An alias table maps every registry name to the best existing GLB clip (+ timeScale),
e.g. `run_forward→run`, `sprint_forward→run@1.4`, `karate_punch_light→jab`,
`karate_punch_heavy→hook`, `karate_kick_roundhouse→roundhouse`,
`bball_shoot_jumper→jumpshot`, `idle_stand→guard@0.45`. Unresolvable names fall
back to a designated clip AND log `[FEL-ANIM] MISSING CLIP` with the full wanted
list — misses become impossible to ship silently. Wire it INSIDE the existing
hook's `play()` (one-line change: `resolveClip(name, clipNames)` before the map
lookup).

### Layer 2 — `authoredClips.ts`: real keyframe clips for the missing actions
Programmatically-built `THREE.AnimationClip`s using YOUR skeleton's actual bone
names (Hips/Spine/Spine1/Spine2/Neck/Head/L-R Shoulder-Arm-ForeArm-Hand/
L-R UpLeg-Leg-Foot — verified from the GLB). Because they're built against the
loaded skeleton at runtime, name-mismatch is impossible. Included:
- `idle_stand` (breathing sway), `strafe_left/right` (walk + lateral lean),
- the full dunk suite: `dunk_charge_gather`, `dunk_launch`,
  **`dunk_360_eastbay`** (the reference dunk: gather → rise → ball hand under the
  raised knee → hand-to-hand → off-hand carry → one-hand extension), 
  `dunk_score_hang`, `dunk_land_crouch`,
- `football_juke_left/right`, `football_spin_move`, `football_tackled_fall`,
- `karate_hit_react`, `karate_knockdown`, `jump_up`, `jump_land`.
Register them into the mixer's actionMap at load (`registerAuthoredClips(mixer,
actionMap, skeletonRoot)`). Replace the dunk's subclip-scrub with phase-driven
`play()` of these clips (the state machine hooks already exist — `charging`,
`launch`, `airborne`, `scored` states in your mode→clip function).

### Layer 3 — `ballRig.ts`: the ball lives in the hands
Uses the hook's existing `bone()` accessor. `attachBall(ball, 'RightHand')`
parents with a palm offset; `runEastbayPath(ball, bones, t)` drives the
hand→under-knee→hand→rim timeline in sync with the authored eastbay clip;
`flushThroughRim(ball, rim)` + `clankOffRim(ball, rim)` finish makes and misses.
The floor-ball and invisible-flight bugs end here.

### Also included
- `LightRig.tsx` — drop-in scene lighting (hemisphere + key directional + ACES
  tone mapping + exposure) and `liftBlackMaterials(scene)` which walks materials
  and floors pure-black/unlit PBR values — fixes the black skate park, the dark
  football field, and the mid-dunk blackout. Mount in EVERY mode scene.
- `DunkReplayCam.tsx` — records the last 4 s of bone/ball transforms and replays
  at 0.5× from two authored angles after every made dunk (skippable). Uses
  recorded transforms, not video.

## LIVE PLAYTEST FINDINGS THIS SESSION (regression list to also fix)
- Dunk: sequence stalls in "SHOWTIME…" — ball on floor, no slam fired, no score,
  no replay (state machine waits on a QTE that never arms; verify `qteActive`
  path when a style was pre-selected during charge).
- Dunk scene: sky/lighting collapses to near-black on the rise (light or fog
  culling tied to camera height — LightRig replaces it).
- Karate: dojo present behind the new wave LAB SHOP (good), but
  "WAVE 1 CLEAR · 0 KO" still fires with zero kills — wave-clear still not
  KO-gated (M22 §2 stands).
- Skate: park still renders black; rider still glides in bind pose.
- Football: bleacher venue walls appeared (progress) but scene near-black and
  defenders invisible again; run still auto-starts with no ready gate.
- New ARC approach selector (STRAIGHT/ARC/OFF GLASS) is a good addition — keep.

## ACCEPTANCE
1. Console shows ZERO `[FEL-ANIM] MISSING CLIP` errors across a full session of
   dunk, karate, football, skate (the resolver makes hits; authored clips cover
   the rest).
2. Recorded eastbay: gather→launch→under-the-knee hand-to-hand→flush, ball in
   hand/on path every frame, then the two-angle replay plays automatically.
3. Karate strikes visibly fire (jab/hook/roundhouse via resolver) with hit-reacts.
4. All scenes lit: no black frames in skate/football/karate/dunk at any phase.
5. Dunk never stalls in SHOWTIME; every attempt reaches slam-or-miss and scores.
