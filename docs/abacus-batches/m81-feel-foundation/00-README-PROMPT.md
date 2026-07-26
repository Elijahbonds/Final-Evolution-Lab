# M81 — the feel foundation: movement, engine lifecycle, PRQ, canvas

**This batch touches all 19 3-D modes at once.** It is not a mode; it is the
four layers underneath every mode, three of which were broken and one of which
never existed.

Depends on nothing. Replaces `core/InputBus.ts` and `core/ModeHarness.ts`.

**157 tests pass by execution** — 61 on the motion model, 96 on DDA, teardown
and the input rules.

---

## WHAT THIS FIXES, AND HOW IT WAS FOUND

Every root cause below came from reading the code this repo has actually
shipped. None of it is a guess about what *might* be wrong.

### 1. "The movement systems are broken. I should feel in control."

Nine defects, stacked. The headline one, from `PlayerSlot.ts`:

```ts
sprint: Math.hypot(this.moveX, this.moveY) > 0.85,
```

Keyboard WASD emits `x, y ∈ {-1, 0, 1}`. One key held is magnitude **1.0**,
which is `> 0.85`. **On keyboard the player has been sprinting 100% of the
time they move. There is no walk speed anywhere.** That single line is most of
what "I don't feel in control" means.

The rest: diagonals 41% faster (no normalization), a digital unsmoothed stick,
keys that stick on blur, no `preventDefault` so the page scrolls under the
game, space emitting both a charge-release and a jump on every release, a
gamepad deadzone that jumps from 0 to 0.151 with nothing in between, 240
events/sec of gamepad spam, no turn rate, no coyote time, no input buffer.

**`core/MotionModel.ts`** is the layer that was never written. Pure — no
Babylon, no DOM, no clock. Sprint is an explicit decision, never inferred from
a digital key. Every number is named and tested:

| | |
|---|---|
| deadzone | 0.12, **rescaled** so motion grows from zero |
| accel / decel | 120ms / 90ms — decel is shorter so stopping feels crisp |
| turn rate | 540°/s ground, 180°/s air |
| coyote / buffer | 100ms / 130ms |
| walk | 45% of top speed |
| response budget | **66ms** (4 frames), asserted in a test |

### 2. "You need to refresh the page for the games to load each time."

`runMode()` allocates the WebGL context on its **first** line and returns the
only thing that can free it on its **last** — after `await def.load(ctx)`,
which is 2–5 seconds, or up to 20 with M29's watchdog. In that window the
caller has no way to clean up. A route change, a back button, or React 18
StrictMode's deliberate double-invoke and the engine, its render loop and its
context leak permanently.

Browsers cap live contexts (Chrome ~16, Safari ~8). Past the cap `new Engine()`
gives a black canvas **with no exception**. A full reload is the only thing
that frees them — which is the symptom exactly, including "each time", because
the count only grows within a session.

`core/ModeHarness.ts` v3:
- returns its handle **synchronously**, so dispose works from millisecond one
- makes loading cancellable — `ctx.cancelled()` after any `await` in `load()`
- one engine per canvas, enforced by a `WeakMap`
- `core/Teardown.ts` runs cleanup in reverse, exactly once, and **survives a
  throwing step**. Previously one bad disposer stranded everything after it —
  and `engine.dispose()` was last.
- publishes `window.__FEL_ENGINES__` and warns past 2 live contexts

### 3. PRQ affects zero frames of gameplay

The web app reports PRQ *out* (`SessionResult`) and never reads it *in*. The
logic that makes PRQ mean something — `PRQDrivenDDA` in
`FinalEvolutionLab/Models/DynamicDifficulty.swift` — is stranded in the iOS app
that is no longer the product.

`core/DDA.ts` is a faithful port: same constants, same curves, same clamps,
asserted as a **parity check** so the two platforms can never quietly diverge.
High PRQ → the opponent presses harder, reacts faster, blocks more, and your
own timing windows tighten by up to 15%. Not because you picked "Hard" —
because you showed up ready. **No commercial sports game can do this.**

`loadDDA()` never blocks and never throws. A guest with no account still gets
a game; they get the neutral one.

### 4. Canvas at 27% of the viewport

Measured at 390×844: canvas 372×232, parent 374×234. The canvas already fills
its parent, so **the container chain is the bug and `engine.resize()` cannot
help.** `styles/game-surface.css` fixes the chain — `100dvh` (not `vh`, which
iOS measures against the toolbar-hidden viewport), `min-height: 0` on flex
items, HUD absolutely positioned instead of stacking in flow.

---

## ONE FINDING YOU SHOULD DECIDE ON

Swift's tier band is `0.75..<0.9 → ELITE`. `PRQ.default` is **75**. So a
brand-new account starts at **ELITE** and meets elite AI on its first match.

The port matches Swift exactly and there is a test pinning it, because the two
platforms must agree before anyone changes it. But it looks like an accident,
and it is a product decision, not a code one.

---

## FILES

| File | Goes where | Note |
|---|---|---|
| `files/core/MotionModel.ts` | `core/` | **new** |
| `files/core/inputCore.ts` | `core/` | **new** — pure input rules |
| `files/core/InputBus.ts` | `core/` | **replaces** M26 |
| `files/core/Teardown.ts` | `core/` | **new** |
| `files/core/ModeHarness.ts` | `core/` | **replaces** M26/M29 |
| `files/core/DDA.ts` | `core/` | **new** |
| `files/styles/game-surface.css` | `styles/` | **new** |
| `files/tests/motion_test.ts` | `tests/` | 61 tests |
| `files/tests/foundation_test.ts` | `tests/` | 96 tests |

## WIRING

**1. Harness — the one breaking change.** `runMode` is no longer `async`:

```ts
// before
const stop = await runMode(def, { canvas });
useEffect(() => () => stop(), []);

// after
useEffect(() => {
  const handle = runMode(def, { canvas });
  return () => handle.dispose();     // reachable immediately — this is the fix
}, []);
```

`runModeLegacy()` restores the old signature so migration can be staged. It
warns every time, because it also restores the bug.

**2. Movement.** In each mode's `update`, replace direct intent→position with:

```ts
this.motion = step(this.motion, {
  x: intent.moveX, y: intent.moveY,
  sprint: intent.sprint,                       // now L1/Shift, not magnitude
  jumpPressed: intent.action,
  grounded: this.grounded,
  cameraYawDeg: ctx.camDirector.yawDeg,        // <- camera-relative
}, dt);
hero.position.addInPlace(new Vector3(
  this.motion.dirX, 0, this.motion.dirZ).scale(this.motion.speed * TOP_SPEED * dt));
hero.rotation.y = this.motion.facingDeg * Math.PI / 180;
```

**`PlayerSlot.LocalInputSource` must stop deriving `sprint` from stick
magnitude.** Bind it to L1 (Shift). Leaving that line in place cancels most of
this batch.

**3. PRQ.** At mode boot: `this.dda = await loadDDA(def.modeId)`. Never block
the mode on it — start with `PRQDrivenDDA.neutral(modeId)` and swap when it
lands. Then feed AI difficulty from it, and put a PRQ meter in the HUD. **PRQ
that only appears on a results screen is a stat; PRQ that changes how the
opponent plays is a mechanic.**

**4. Canvas.** Import the CSS, put `.fel-stage` on the canvas wrapper,
`.fel-canvas` on the canvas, `.fel-hud` on the overlay.

## ACCEPTANCE

Nine checks. The first four are the ones that decide whether this worked.

1. **Hold W in any 3-D mode: the character WALKS.** Shift makes it run. If it
   still sprints, `LocalInputSource` wasn't updated.
2. **Hold W+D: same speed as W alone** (±2%).
3. **Hold W, switch apps, come back: the character has stopped.**
4. **Navigate 20 modes without reloading.** The 20th boots as fast as the
   first; `window.__FEL_ENGINES__.live` never exceeds 2.
5. Swing the camera 180° while holding forward — the character runs toward the
   new screen-forward.
6. Canvas ≥ 85% of viewport height on iPhone portrait, no page scroll.
7. Console shows `[FEL-DDA] <mode>: PRQ nn → TIER` on every mode boot.
8. Kill the network, load a mode: it plays at neutral difficulty, no error.
9. `node --experimental-strip-types tests/motion_test.ts` → 61 passed;
   `tests/foundation_test.ts` → 96 passed.

## LIMITS — what is NOT verified

- **None of this has run against a real Babylon scene.** This repo has no copy
  of the app (`docs/ACCESS-SETUP.md`). The pure logic is tested by execution;
  every Babylon and DOM call is written against the API and unexercised.
- `ctx.camDirector.yawDeg` is **assumed** to exist. If `CameraDirector` exposes
  the camera yaw under another name, wire it — camera-relative movement is the
  single most important line in the movement fix.
- The engine-leak diagnosis is **inferred**, not observed. `docs/BLUEPRINT.md`
  §1.1 has a console snippet that confirms or refutes it in a minute. **Run it
  first.** If contexts stay at 1–2, the cause is a Next.js remount instead and
  this part of the batch is insurance rather than the fix.
- `MotionModel`'s constants are industry-standard starting points, not values
  tuned against this game. Expect to move them once it is playable — that is
  what they are named and centralised for.
