# M96 — Pass 2, Phase 3: lifecycle proven, three modes losing the player

**25 tests pass by execution. The bug this fixes was measured on the deployed
build with zero player input.**

---

## LIFECYCLE: PASS

Phase 3's stated gate was *"20 route changes, no reload."* **That gate was
written against an app this build is not.** There are no in-app `/play/` links;
every route change is a full page load. So the honest version is: twenty route
changes, one page, and measure what degrades.

| | |
|---|---|
| routes loaded | **20 / 20** |
| boot, first five | 1519 ms avg |
| boot, last five | **1321 ms avg** (−198 ms — it got *faster*) |
| live WebGL contexts | **1, every single time** |
| page errors | **0** |

Nothing degrades. `lifecycle` moves to **PASS**, and it does so without M81
being integrated — because, as M95 found, the browser tears the context down
on every navigation and there is nothing to leak.

**That is a real result and it means M81's engine-lifecycle work is not
urgent.** It becomes urgent the day the app becomes a true SPA. Not before.

## THE BUG: THREE MODES LOSE THE PLAYER, UNATTENDED

Fourteen modes, started and then **left completely alone** for eleven seconds:

| mode | grounding faults | worst y |
|---|--:|--:|
| skateboard | **24** | −2.02 |
| snowboard | **25** | −2.29 |
| surf | **23** | −2.41 |
| *the other eleven* | 0 | — |

```
[FEL-SPAWN] Rider: 1 missed raycasts (y=-1.93) — hard-clamping to floor
```

The rider spawns at y = 0.93, and within a few seconds it is two units under
the floor, being clamped there, forever. The camera follows it into an empty
void — `skateboard` is unplayable, with no input required to break it.

**This class of bug was invisible to every check this project has ever had,
because every check drove the game.** Nobody watched a mode do nothing.

### The cause, from the shape of the data

The depth is **roughly constant** at about −2. That is the tell. Something
falling gets deeper; something at a fixed depth is being reset to the same
place every frame and re-penetrating by the same amount.

So: **position is corrected and velocity is not.** Gravity keeps integrating
into `vy` while the actor sits exactly on the floor, so the very next frame it
is below again. The clamp fights gravity once per frame and loses once per
frame. A clamp that has to keep firing is not holding.

`legacyClampOnly()` reconstructs that behaviour and a test drives both:

| | clamps in 11 s | settles? |
|---|--:|---|
| clamp-only (today) | **635** | never |
| `groundStep` | **1** | yes, and stays settled |

### The fix is three things, and all three are required

1. Put the actor on the floor.
2. **Zero the downward velocity.**
3. **Mark it grounded and stop integrating gravity while it rests.**

The first draft of this file did 1 and 2 and still failed its own test — a
resting actor accumulated gravity, dipped below the floor, and was corrected
143 times. It reproduced the bug it was written to fix. Point 3 is not a
refinement; it is the fix.

Plus a guard for the case a clamp cannot fix at all: **when the ground query
misses, re-seat instead of clamping to an imaginary floor.** Clamping to a
floor you cannot find is precisely how you get a camera following an actor
through an empty void, which is what the screenshots showed.

### What the tests protect

- **A jump from rest still leaves the ground.** The resting branch skips
  gravity, so it has to yield to upward velocity — otherwise the fix for
  falling through the floor becomes a bug where you cannot jump, which is a
  worse trade.
- **A normal landing is never mistaken for a fault.** Every landing penetrates
  a little; a fault counter that fires on those would re-seat players at random.
- **It behaves identically at 60, 20 and 3 fps.** The container this bug was
  found in renders at ~3 fps. A guard that behaved differently there would make
  every future measurement from this machine untrustworthy, including the one
  that found this.

---

## FILES

| File | Goes where |
|---|---|
| `files/core/groundGuard.ts` | `core/` |
| `files/tests/ground_guard_test.ts` | `tests/` — 25 tests |
| `evidence/fleet-idle.json` | reference only |

Repo tool: `tools/integration_audit.mjs` now runs an **unattended health
check** — grounding faults and page errors while the player does nothing — and
reports the modes that fail it.

## PREREQUISITES

None.

## WIRING

`groundGuard` is a pure function; it does not own the actor. In whatever
per-frame code currently prints `hard-clamping to floor`:

```ts
const r = groundStep(
  { y: rider.position.y, vy: rider.vy, grounded: rider.grounded, clampedFrames: rider.clampedFrames },
  { groundY: raycastHit ? hit.y : null, safeY: lastSafePoint.y },
  dt,
);
rider.position.y = r.y;
rider.vy = r.vy;
rider.grounded = r.grounded;
rider.clampedFrames = r.clampedFrames;
if (r.action === 'reseated') console.warn(`[FEL-GROUND] ${r.reason}`);
```

The `grounded` and `clampedFrames` fields have to persist on the actor between
frames. If they are recreated each frame the guard has no memory and **the bug
comes straight back** — that is exactly the failure mode of the first draft.

`safeY` should be the last point the rider was genuinely on the course, not the
spawn. Re-seating a skater to the start of the run mid-line is a different bad
experience from falling through the floor, but it is still a bad one.

## ACCEPTANCE

1. `node tools/integration_audit.mjs --modes skateboard,snowboard,surf --play 11000`
   → **0 grounding faults**. It currently reports 23–37 each.
2. `[FEL-GROUND]` appears only when the ground query genuinely misses, and
   never in a normal run.
3. Jumping, dropping in, and landing all still work. The tests cover the
   physics; only a human covers whether it *feels* right.

## LIMITS

- **The cause is inferred, not read.** I do not have the app source; the
  diagnosis comes from the constant −2 depth, the repeat rate, and the fact
  that reconstructing "clamp position, ignore velocity" reproduces the
  observed behaviour exactly. It is a strong inference and it is still an
  inference. If the real code already zeroes velocity, the cause is elsewhere
  and this batch is wrong — the acceptance check above is what settles it.
- **`groundStep` has not run in the app.** Tested by execution, unobserved in
  the product. Same caveat as everything else here.
- **Movement input is only partly measured.** Keyboard *and gamepad* listeners
  are attached — confirmed by enumerating real listeners over CDP — so
  keyboard is wired. But holding W/A/S/D or the arrows for two seconds each in
  `onevone` produced no visible player displacement, while the on-screen
  joystick moved the player in both modes I tried. I could not determine why
  from outside the bundle, and I am **not** reporting keyboard movement as
  broken on that evidence.
- **The always-sprinting bug is still unmeasured.** Distinguishing a walk from
  a sprint needs frame-accurate displacement, and this container renders at
  ~3 fps through a software rasteriser. It needs a real device.
