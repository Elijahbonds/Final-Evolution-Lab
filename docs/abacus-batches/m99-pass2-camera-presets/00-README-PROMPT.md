# M99 — Pass 2, Phase 6: the camera distances, measured on the live build

**43 tests pass by execution. Four modes were applied to the deployed app and
measured after; the other eight are reported as blocked, with the reason each.**

---

## PHASE 6 WAS "TELLS, WAVE TWO". IT ISN'T.

M98 found that 77% of the character mesh is welded to the `Head` bone, so no
character can animate. M97 found six of eight modes render the player at 5–9%
of the screen. **A tell drawn on a character that cannot move, at six pixels,
is not a tell.** The order is skin weights → camera → tells, and the camera is
the half of it that is mine.

## WHAT WAS APPLIED AND MEASURED

Each camera was converged on the deployed build until the character hit 22% of
frame height, then read back:

| mode | radius | frame % | character | bigger by |
|---|---|---|---|--:|
| dunk | 14 → **3.0** | 8.3% → **21.2%** | 60px → **154px** | 2.6× |
| onevone | 17 → **4.52** | 8.5% → **21.5%** | 62px → **156px** | 2.5× |
| threevthree | 24 → **3.41** | 5.7% → **21.0%** | 42px → **153px** | **3.6×** |
| karate | 13 → **3.71** | 8.3% → **21.1%** | 61px → **154px** | 2.5× |

**Four modes are a one-number change each**, and the number is not calculated —
it was applied and measured.

### Why the numbers had to be measured

`radius` is the distance from the camera's **target**, not from the character.
`dunk` sits at radius 14 and **18.4 m** from the hips. So scaling radius by the
ratio of measured-to-target undershoots: a one-step arithmetic estimate landed
six modes at **13–17%** instead of 22%. Converging on the measurement is the
only honest method, and it is why this batch exists rather than a formula.

## THE TWO BLOCKERS, BOTH CONFIRMED

### 1. `lowerRadiusLimit = 3` on every ArcRotateCamera

`tennis` and `volleyball` need radius ≈ 2.51 and stall at **18.4%**. Setting a
smaller radius is *accepted* and then silently clamped back to exactly 3 on the
next frame — I set tennis to 0.5 and found it at 3.0 two seconds later.

**A preset that gets clamped and never mentioned again is indistinguishable
from a preset nobody wired.** That is exactly how `CameraStandoff` went six
batches unnoticed, so `planFor()` refuses these two and says why, instead of
returning a number that would do nothing.

Lower the limit to 2.5 on those two cameras first.

### 2. Five modes have a follow controller that owns the position

`football`, `baseball`, `skateboard`, `snowboard` and `surf` use a
`TargetCamera` whose position is rewritten every frame. An external write
survives about one frame — I moved football's camera to y=1.64 and found it at
y=6.35 two seconds later, and the convergence loop just oscillated:
`[8 10 6 11 7 12]` percent, going nowhere.

**No value in this file can fix those five.** They need a distance parameter
changed inside their controller, and `planFor()` says so rather than handing
over a number that will be overwritten.

### And one mode that must not be touched

`karate-vs` is already correctly framed at **35.7%**. It is marked `leaveAlone`
and there is a test asserting it never appears in the work list. `baseball` is
**too close** at 84.8%, not too far. A fleet-wide "move all cameras in" would
break both.

---

## FILES

| File | Goes where |
|---|---|
| `files/config/cameraPresets.json` | `config/` |
| `files/core/cameraPresets.ts` | `core/` |
| `files/tests/camera_presets_test.ts` | `tests/` — 43 tests |
| `evidence/camsweep.json` | reference only |

Data lives in JSON, matching `config/prqWeights.json` from M82, so a value can
be corrected without a code change and without two copies drifting apart.

## PREREQUISITES

| Module | From | Used for |
|---|---|---|
| `CameraFraming` | M97 | the target fraction and the grading it came from |

Not a hard import — this batch stands alone — but the reasoning is there.

## WIRING

```ts
import { planFor } from '../core/cameraPresets';

const plan = planFor(modeId);
if (plan.applied) camera.radius = plan.radius;
else console.warn(`[FEL-CAM] ${modeId}: ${plan.reason}`);
```

That `else` is the load-bearing half. It is what turns "the preset silently did
nothing" into a line someone can read.

For the two clamped modes, also set `camera.lowerRadiusLimit = 2.5` **before**
assigning the radius, or the assignment is undone on the next frame.

## ACCEPTANCE

1. `node tools/pose_probe.mjs` → `dunk`, `onevone`, `threevthree` and `karate`
   all report between 20% and 24%. They currently report 5.7–8.5%.
2. `karate-vs` still reports ~35%. If it moved, the change was applied globally.
3. `[FEL-CAM]` warns for the seven blocked modes and is silent for the four.

## LIMITS

- **This is framing, not composition.** 22% of frame height is a readability
  floor derived in M97 from tell size; it is not a claim that these are good
  shots. Where the camera sits, what it looks at, and how it moves during a
  dunk are design decisions nobody has made yet.
- **Measured at one moment, on a desktop viewport.** Characters move; a camera
  correct at tip-off may be wrong mid-drive. The follow behaviour was not
  measured, only the resting distance.
- **The four verified values were applied from OUTSIDE the app** and have not
  been shipped through the app's own camera code. If `CameraDirector` overrides
  radius on a cut, these values will not survive it — and that is the same
  class of problem as the five blocked modes, just not yet observed.
- **Nothing here helps until the skin weights are fixed** (M98). A perfectly
  framed 154-pixel character whose upper body is welded to its head is a
  clearer view of the bug, not a better game.
