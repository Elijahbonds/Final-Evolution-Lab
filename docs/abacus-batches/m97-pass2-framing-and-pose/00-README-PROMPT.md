# M97 — Pass 2, Phase 4: the camera is why nothing is readable

**31 tests pass by execution. Every number here was measured inside the running
game on the deployed build.**

---

## FIRST: I WAS WRONG ABOUT THE T-POSE, TWICE

I reported in M95 and again in M96 that the characters are T-posed, on the
strength of screenshots. **They are not.**

Measured inside the live scene:

| | |
|---|---|
| `idle_stand` | **playing**, looping, on both characters |
| rest pose | **solved and applied** — bone and transform node agree |
| bind pose, this rig | arm at **90°** from vertical (a true T) |
| actual pose | arm at **20°** from vertical, hand at hip height |
| the solver's effect | drops the hand **0.61 m** on a 0.65 m arm |

M64 and M69 work. The arms hang. **The character is 60 pixels tall on a 1280×800
desktop, and at 60 pixels a 20° arm and a 90° arm are the same picture.**

I read a framing bug as a rigging bug, and I did it twice, because a screenshot
was the only instrument I had. `tools/pose_probe.mjs` is the instrument.

## THE FINDING

`tools/pose_probe.mjs`, deployed build, 2026-07-27:

| mode | char px | % of frame | camera |
|---|--:|--:|--:|
| tennis | 36 | **4.9%** | 33.5 m |
| skateboard | 46 | **6.3%** | — |
| football | 55 | **7.6%** | — |
| dunk | 60 | **8.3%** | 18.4 m |
| onevone | 62 | **8.5%** | — |
| karate | 65 | **8.9%** | — |
| karate-vs | 250 | 34.4% | 3.9 m |
| baseball | 958 | 131.6% | — |

**Six of eight modes render the player at 5–9% of the screen.** A 1.72 m
athlete, sixty pixels tall — and before M95's canvas fix, **nineteen CSS pixels
on an iPhone.**

`tennis` puts the camera **33.5 metres** from a 1.7 metre player.

### Why this is the headline

**It cancels M92.** Eleven tells are specified, six anchored to the subject. A
tell on a 19-pixel character is about six pixels. Every mechanic from phases
2–8 is invisible for this reason alone, and drawing the tells changes nothing
until the camera comes in.

**And M95 is not enough on its own.** There is a test for this, because it is
the counter-intuitive part:

| | tell size | readable? |
|---|--:|:-:|
| phone before M95 | 6 px | no |
| **phone after M95** | **15 px** | **still no** |
| full desktop canvas | 20 px | still no |
| M95 **+** target framing | 41 px | **yes** |

Quadrupling the canvas is not enough. Moving the camera is not enough on the
old canvas. **The two multiply**, and that is the recommendation.

### Why it is cheap

It is a distance per mode. No art, no rig, no Blender, no mocap. `dunk` needs
to come from 18.4 m to **6.9 m** — 2.7× closer. `tennis` needs more than 4×.
`karate-vs` is already right and must not be touched by a blanket rule; there
is a test for that too.

---

## FILES

| File | Goes where |
|---|---|
| `files/core/CameraFraming.ts` | `core/` |
| `files/tests/camera_framing_test.ts` | `tests/` — 31 tests |

Repo tool: **`tools/pose_probe.mjs`** — the first tool in this project that can
see *inside* the running game. Babylon does not put its `Engine` on `window`,
but it binds its render loop to itself, so hooking `Function.prototype.bind`
before any page script captures it. From there: scenes, skeletons, bone world
matrices, camera projection. **It reads and never writes** — an observation
tool that can change what it observes is one whose findings you cannot trust.

This is also the answer to Phase 4's `?probe=1` gate. M80's `PoseProbe` needs
the app to cooperate and has never been wired. This needs nothing from anyone.

## PREREQUISITES

None. Pairs with M95 — see the table above for why they are not alternatives.

## WIRING

`CameraDirector` and `FOLLOW_PRESETS` already own camera distance; this is the
arithmetic for what to put in them.

```ts
import { distanceForFraction, gradeFraming, TARGET_FRACTION } from '../core/CameraFraming';

const distance = distanceForFraction({
  heightM: 1.72, fovRad: camera.fov, fraction: TARGET_FRACTION, pitchRad: cameraPitch,
});
```

Or take the measured recommendation directly — `recommend(MEASURED[i])` solves
back through the probe's own numbers, which already contain this camera's pitch
and framing, and is more accurate than recomputing from an ideal model.

**Do not apply a single global distance.** `karate-vs` is correctly framed and
`baseball` is too close, not too far; a blanket change breaks both.

## ACCEPTANCE

1. `node tools/pose_probe.mjs` → **0 of 8 modes below 15%.** It currently
   reports six.
2. `node tools/pose_probe.mjs --phone` → the same, and `char css px` above 100
   on every mode.
3. `karate-vs` still measures between 0.22 and 0.45. If it moved much, the
   change was applied globally and it should not have been.

## LIMITS

- **The framing model is a thin-lens approximation.** It agrees with the probe
  within 20% and always overestimates, because camera pitch foreshortens a
  standing figure and the pitch is not known per mode. `recommend()` scales the
  measured value instead of using the model, for exactly this reason.
- **`TARGET_FRACTION = 0.22` is a judgement, not a measurement.** It is chosen
  so a subject-anchored tell clears 24 CSS px on a post-M95 phone, and 24 px is
  itself the smallest size that carries shape *and* colour. Both are defensible
  and neither is empirical. The founder playing it is what settles them.
- **Only eight of twenty-five modes are measured.** The probe takes about a
  minute per mode and the other seventeen have not been run.
- **Nothing here has been applied.** `CameraFraming` is arithmetic and tests;
  no camera in the product has moved.
- **Phase 4's actual gate — mocap — is still blocked.** `conform_clips.sh`
  needs Blender on the Mini. What this batch establishes is that mocap was
  never the reason the characters looked wrong: **the rest pose was already
  correct and too small to see.** That reorders the work rather than finishing
  it.
