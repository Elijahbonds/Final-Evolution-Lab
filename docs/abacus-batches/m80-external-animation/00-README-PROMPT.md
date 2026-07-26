# M80 — external animation: making Meshy and DeepMotion clips actually fire

Answering the question directly: **yes, there is something to build, and this
is it.** Not a setting, not a toggle — a missing link in the chain.

---

## WHY YOUR MOCAP ISN'T THERE

I traced the whole path on the live build before writing anything.

**The animation system is not broken.** Clips load, sanitise and play; the
console shows `restPose solved`, `restPose applied to skeleton`,
`authored clips registered` and `groundSnap` on every load, with no
`MISSING CLIP` and no `SKINNING STALL`. That part works.

The problem is simpler and worse: **there is no path for an external animation
to reach it.**

What the game animates with today, in full:

1. **~9 clips riding inside the character GLB** — `guard`, `jab`, `hook`,
   `high_kick`, `roundhouse`, `jumpshot`, `run`, `walk`, `uppercut`.
2. **Hand-authored quaternion keyframes in code** — `dunk_charge_gather`,
   `dunk_launch`, `dunk_360_eastbay`, `idle_stand`, the football moves, the
   rest. A programmer typed those angles in. That is why the dunk reads stiff.

`HERO_URL` is `/models/elijah-hero.glb` — one character file. `assets/` holds
13 Luma FBX **environments** and 19 JSON manifests. **Zero character files and
zero animation files.** There is no Meshy animation and no DeepMotion mocap
anywhere in the project, and nothing in the code that could load one if it
were there.

So the honest answer to "why aren't my Meshy/DeepMotion animations firing" is:
they were never wired to anything. It isn't a bug — the feature doesn't exist
yet.

---

## THE CHAIN, AND WHAT WAS MISSING

| # | Step | Status before M80 |
|---|---|---|
| 1 | Export from Meshy / DeepMotion (`.glb` / `.fbx`) | you do this |
| 2 | **Conform** — strip `mixamorig:`, animation-only export | `tools/fel_conform.py` **exists since M65, never run** |
| 3 | Drop in `assets/ready/anim/` | folder does not exist |
| 4 | **Load at runtime and retarget onto the live skeleton** | ❌ **did not exist** |
| 5 | Register under a clip id so modes can play it | ❌ **did not exist** |

M80 builds 4 and 5, and makes 2 runnable and checkable.

### Step 2 is the one that silently kills everything

FEL resolves bones by **UNPREFIXED** name — `Hips`, `LeftArm`. Meshy, Mixamo
and DeepMotion nearly all export `mixamorig:Hips`.

A prefixed clip targets bones that do not exist. It does not error. It does not
404. It animates **nothing**, and the character sits in bind pose — which on
this rig is arms-out, i.e. **it looks exactly like a T-pose and exactly like
"the animation didn't fire."**

That is worth stating plainly because it is the single most likely thing to
happen the first time you drop a file in, and nothing in the old pipeline would
have told you.

---

## A CORRECTION I OWE YOU, ON THE T-POSE

I previously told you the T-pose came from `idle_stand` keying the arms only
8–10° off the arms-out bind pose. **That was true of the M24 version and it was
already fixed** — M64 rebuilt `idle_stand` on a measured arms-down pose
(`solveArmsDown`), and the live console confirms `restPose solved` on every
load. So that is not the remaining cause.

I don't know what the remaining cause is, and I'm not going to guess a third
time. `anim/PoseProbe.ts` measures it instead.

It computes the angle between the shoulder→hand vector and straight down:
**0° = arms at the sides, 90° = T-pose.** When that stays above 55° for more
than 2.5s it prints what was playing at that moment, which separates three
causes that look identical on screen and need completely different fixes:

| What the probe sees | What it means | What to do |
|---|---|---|
| nothing playing | the mode never started a clip | mode-logic bug — check `neverBindPose()` |
| playing, **0 bones bound** | clip resolved nothing | prefixed bone names → run `clip_check.mjs` |
| playing, bones bound | the clip IS driving the rig | its keys sit too close to bind — needs real data |

Run any mode with **`?probe=1`** and read `[FEL-POSE]`. That turns "I'm
T-posing" into one line naming the cause.

---

## `tools/clip_check.mjs` — check a file before it costs you a deploy

Reads the glTF JSON chunk directly. **No Blender, no Babylon, no npm install,
no network.** It tells you whether a file will work *before* it goes anywhere.

```
$ node tools/clip_check.mjs assets/ready/anim/

[CLIP] FAIL  assets/ready/anim/deepmotion_raw.glb
       "Armature|mixamo.com|Layer0" · 14 channels · 7 bones · rotation+position
       6/22 canonical bones driven
       ✗ 7/7 animated bones are PREFIXED (e.g. "mixamorig:Hips"). FEL resolves
         bones by unprefixed name, so this clip would animate NOTHING and the
         character would stay in bind pose.
      FIX:  blender --background --python tools/fel_conform.py -- \
              --input <this file> --output <same>.glb --strip-mesh
```

It also catches the failure that has **no symptom at all**: a file named
`run_cycle.glb` when the clip id is `run`. The loader builds its URLs from the
manifest, so that file is never requested — no error, no 404, it just sits
there while the game keeps playing the procedural clip.

---

## WHAT IS AND ISN'T VERIFIED

**Verified — run here, in this environment:**

- `tests/clip_check_test.mjs` — **21 passing**. Builds real GLB byte streams
  (correct header, correct 4-byte chunk padding) and parses them back. Not
  mocks: if the container parser is wrong, these fail.
- `tests/anim_test.ts` — **46 passing**. The T-pose maths, the three-way
  diagnosis, the manifest, prefix stripping.
- **A drift guard.** The bone-naming rule has to hold in three files that
  can't import each other (TypeScript runtime, plain-Node checker, Python
  conform script). The test fails if the first two disagree.
- End-to-end: synthetic Meshy-style and DeepMotion-style exports pushed
  through `clip_check.mjs` → correct PASS/FAIL, correct reasons.
- `conform_clips.sh` — syntax-checked, and the loop exercised with a stub
  Blender. Filename normalisation confirmed: `Dunk Launch (1).fbx` →
  `dunk_launch_1.glb`, which then correctly **fails** the name check.

**Not verified:**

- `ExternalClipLoader.ts` and `PoseProbe.ts` have not run against a real
  Babylon scene — this repo has no copy of the app (see
  `docs/ACCESS-SETUP.md`). Their pure logic is tested; their Babylon calls are
  not.
- `fel_conform.py` still has not been run. There is no Blender here. It needs
  one real file put through it on your machine.
- `LoadAssetContainerAsync` is the Babylon 8 top-level import. On Babylon 7
  it's `SceneLoader.LoadAssetContainerAsync(rootUrl, file, scene)` — check
  which one the app is on.

---

## FILES

| File | Goes where |
|---|---|
| `files/anim/boneNames.ts` | game source `anim/` — **new, others import it** |
| `files/anim/ExternalClipLoader.ts` | game source `anim/` |
| `files/anim/clipManifest.ts` | game source `anim/` |
| `files/anim/PoseProbe.ts` | game source `anim/` |
| `files/tools/clip_check.mjs` | repo `tools/` |
| `files/tools/conform_clips.sh` | repo `tools/` |
| `files/tests/anim_test.ts` | repo `tests/` |
| `files/tests/clip_check_test.mjs` | repo `tests/` |

## WIRING

1. Serve `assets/ready/anim/` as a static path at **`/assets/ready/anim`**
   (matches `ANIM_ROOT`). Create the folder even while empty.
2. In character setup, after the skeleton exists and authored clips are
   registered, call `loadClipPack(scene, skeleton, sourcesPresent(available), register)`
   where `register` is the existing `clipRegistry` add. External clips must
   register **after** the procedural ones so they override rather than lose.
3. In `ModeHarness`, call `attachPoseProbe(scene, skeleton, modeId)` after
   load and its returned stop function in `dispose()`. It self-disables
   without `?probe=1`, so this costs nothing in normal play.
4. Optionally expose `poseReport()` on the agent bridge so the smoke test can
   see a T-pose. It currently proves a mode reaches `playing` — it cannot see
   a character standing in bind pose the entire time, which is exactly the bug
   that has survived every green run.

## ACCEPTANCE

1. `node tests/clip_check_test.mjs` → 21 passed.
2. `node --experimental-strip-types tests/anim_test.ts` → 46 passed.
3. With an empty `assets/ready/anim/`: every mode plays exactly as it does
   today, and the console shows the procedural-fallback list. **No mode may
   regress because a folder is empty.** This is the one that matters most.
4. Drop one conformed clip named `run.glb`. Expect
   `[FEL-ANIM] external clip "run": N bones bound, clean.` and visibly
   different running.
5. Drop the same clip **without** conforming. Expect `bound ZERO bones` and
   the message naming `fel_conform.py` — the failure must be loud.

---

## WHAT TO ACTUALLY DO, IN ORDER

1. Install Blender once (`brew install --cask blender`).
2. Take **one** DeepMotion export. `node tools/clip_check.mjs <file>` first —
   it will almost certainly say PREFIXED. That confirms the diagnosis on your
   own file rather than on my say-so.
3. `bash tools/conform_clips.sh assets/incoming assets/ready/anim`
4. Re-run `clip_check.mjs`. Rename to a clip id from `anim/clipManifest.ts`.
5. Drop it and play.

`priorityOrder()` in the manifest says what to buy or record first: the
universal clips (`idle_stand`, `run`, `walk`, the strafes) come before the
spectacular ones, because they play in **every** mode. One good run cycle
changes the whole product; one good dunk changes one screen.

---

## WHAT THIS BATCH DOES NOT ADDRESS

You raised four things. This handles two of them (mocap, and measuring the
T-pose). The other two are real and I have not diagnosed them yet — I'd rather
say so than fold a guess into a batch:

- **"You need to refresh the page for the games to load each time."** Sounds
  like client-side navigation into `/play/*` not re-initialising the engine —
  a stale canvas or a `dispose()` that doesn't run on route change. Needs its
  own pass driving route→route transitions, not a cold load, which is all the
  smoke test has ever done.
- **"The movement systems are broken. I should feel in control."** Deliberately
  not guessed at. This is input latency, acceleration curves and camera-relative
  direction, and it needs measurement per mode, not a theory.

Both deserve their own batch. Say the word and they're next.
