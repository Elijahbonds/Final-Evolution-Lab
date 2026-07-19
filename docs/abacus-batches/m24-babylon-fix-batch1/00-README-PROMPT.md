# M24 · BATCH 1 — BABYLON ANIMATION CORE (drag-and-drop, 16 files)

Drop this batch into Abacus (all files ≤ ~150 lines; one batch ≤ 25 files).

---

## PROMPT FOR ABACUS

Apply this Babylon.js fix batch. It solves the animation crisis with verified
forensics from the live build (July 2026):

**DIAGNOSIS (exact, from downloading the live bundle + models):**
- The clip registry expects ~60 clip names (`idle_stand`, `run_forward`,
  `karate_punch_light`, `dunk_360_eastbay`, …).
- The shipped model `/models/elijah-hero.glb` contains **9 clips**:
  `guard, high_kick, hook, jab, jumpshot, roundhouse, run, walk, uppercut`.
- **Zero names match → every play() misses → silent null → bind pose.** That is
  the T-pose, the penguin walk, the guard-pose "dunk", the stalled SHOWTIME.
- The skeleton is Mixamo-style without prefix: Hips, Spine/1/2, Neck, Head,
  L/R Shoulder-Arm-ForeArm-Hand, L/R UpLeg-Leg-Foot-ToeBase (52 joints).

**STACK NOTE:** the live bundle currently runs three.js. If you are keeping
three.js, request the M23 batch (same fixes, three.js idioms). THIS batch is the
Babylon implementation for the Babylon build path. Do not mix the two in one scene.

**THE FIX (this batch):**
1. `clipAliases` + `clipResolver` — every registry name resolves to a real clip
   (alias w/ speed) or a loud `[FEL-ANIM] MISSING CLIP` error + fallback. Silent
   misses become impossible.
2. `CharacterAnimator` — one Babylon controller: AnimationGroup map, weighted
   cross-fades (old→0, new→1), onEnd, never bind pose.
3. `clipBuilder` + authored clips — programmatic Babylon AnimationGroups built
   against the real bone names, covering what the asset lacks: idle, the full
   dunk suite (**including the eastbay**: ball hand under the raised knee,
   hand-to-hand, off-hand flush), football jukes/spin/tackled, karate
   hit-react/knockdown.
4. `ballRig` — ball attached to hand bones (`attachToBone`), eastbay hand-to-hand
   path synced to the clip's timestamps, rim flush on make, clank on miss.
5. `LightRig` — hemisphere+sun+ACES pipeline per venue mood + `liftBlackMaterials`
   (fixes black skatepark/football/mid-dunk blackout). `scene.fogMode = NONE`.
6. `DunkReplayCam` — records last 4 s of transforms, auto-replays every made dunk
   at 0.5× from two angles (low baseline → rim-side), tap to skip.

## FILES (16)
| File | Purpose |
|---|---|
| `files/anim/clipAliases.ts` | Registry→asset alias table (+speed) |
| `files/anim/clipResolver.ts` | Resolution + loud missing-clip logging |
| `files/anim/CharacterAnimator.ts` | Cross-fade AnimationGroup controller |
| `files/anim/clipBuilder.ts` | Keyframe data → Babylon AnimationGroup |
| `files/anim/authored/timing.ts` | Shared timings (EASTBAY beats) |
| `files/anim/authored/locomotion.ts` | idle_stand, strafes, jump/land |
| `files/anim/authored/dunkSuite.ts` | charge, launch, score hang, land crouch |
| `files/anim/authored/eastbay.ts` | dunk_360_eastbay choreography |
| `files/anim/authored/football.ts` | jukes L/R, spin, tackled fall |
| `files/anim/authored/karate.ts` | hit react, knockdown |
| `files/anim/authored/index.ts` | registerAuthoredClips() |
| `files/anim/ballRig.ts` | Hand attach, eastbay path, flush/clank |
| `files/scene/LightRig.ts` | Venue lighting + ACES + black-material rescue |
| `files/scene/DunkReplayCam.ts` | Two-angle transform replay |
| `files/scene/moods.ts` | Venue mood presets |
| `files/index.ts` | Barrel export + wiring cheat-sheet |

## WIRING
1. On character load: build `CharacterAnimator(scene, animationGroups)` then
   `registerAuthoredClips(animator, skeleton)` — authored clips register by their
   REGISTRY names, so exact hits replace aliases automatically.
2. Replace every direct `group.play()`/scrub path with `animator.play(name, opts)`.
   Delete the dunk subclip-scrub of `animations[0]` — the dunk phases now play:
   charge→`dunk_charge_gather`, launch→`dunk_launch`, airborne(style)→
   `dunk_360_eastbay` (etc.), scored→`dunk_score_hang`, land→`dunk_land_crouch`.
3. Ball: on possession `attachBallToHand(ball, skeleton, characterMesh, 'RightHand')`;
   during eastbay call `runEastbayPath` each frame with the clip time; on slam
   `flushThroughRim`; on miss `clankOffRim`. The ball must never sit on the floor
   during a dunk sequence again.
4. Every mode scene: `mountLightRig(scene, '<mood>')` (moods per venue in
   `moods.ts`) after venue load, then `liftBlackMaterials(scene)`.
5. Dunk mode: create `DunkReplayRecorder`, call `record()` per frame, and on a
   made dunk `await replay.play(rimCenter)` before the result flow.
6. Fix the SHOWTIME stall: the QTE arm path must trigger when a style was
   pre-selected during charge (verify `qteActive` becomes true in the airborne
   phase in all style branches).

## ACCEPTANCE
1. Console: ZERO `[FEL-ANIM] MISSING CLIP` across dunk/karate/football/skate
   sessions.
2. Recorded eastbay end-to-end: ball in hand → under the knee hand-to-hand →
   flush → auto replay (two angles) → score. No stall, no floor ball.
3. Karate strikes visibly play (jab/hook/roundhouse via aliases) + hit reacts.
4. No black frames in any mode; skatepark surfaces visible at speed.
5. All files compile as-is (no `any` leaks, Babylon ≥ 6.x imports only).
