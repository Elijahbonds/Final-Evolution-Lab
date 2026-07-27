# M95 — Pass 2, Phase 2: the canvas fix, measured on the live build

**24 tests pass by execution. The CSS was verified against the deployed app on
eight modes before it was written down.**

Read `docs/BASELINE-2026-07-27.md` alongside this — it is the full baseline
this batch came out of.

---

## THIS IS THE FIRST BATCH WITH EVIDENCE IN IT

Ninety-four batches shipped on "the tests pass". This one shipped on
measurement against `finalevolution.abacusai.app`, and the before/after
screenshots are in `evidence/`.

## THE FINDING

`dunk` fills **26–33% of an iPhone 13** and **92% of a desktop**. Measured
identically — to the decimal — on `dunk`, `onevone`, `karate`, `skateboard`,
`tennis`, `surf`, `football` and `baseball`.

That decimal agreement is the whole diagnosis: **one shared wrapper, not
twenty-five mode bugs.**

```html
<div class="relative aspect-[16/10] w-full overflow-hidden rounded-xl ...">
```

A 16:10 box across a 390px portrait phone is 244px tall. The canvas inside is
`absolute inset-0` and does exactly what it is told. **This is why every
`engine.resize()` theory failed** — the canvas was never wrong, its container
was, and the container is correct on the desktop where it was designed.

The bottom third of the phone is empty black. `evidence/phone-before-33pct.png`.

## THE RESULT

| | coverage | controls |
|---|--:|---|
| before | 33.3% | all visible |
| **after** | **79.8%** | **all visible, nothing clipped** |

On **eight of eight modes**, zero buttons pushed off-screen.
`evidence/phone-after-80pct.png`.

The stage goes full-bleed and the joystick, action button, style chips and
coach caption float over it — which is how a phone game is laid out, and which
also reclaims the dead band the letterbox created.

### Three things that had to be got right

1. **`svh`, not `vh`.** On iOS Safari `100vh` excludes the browser chrome, so a
   `100vh` column is taller than the screen and the DUNK button ends up under
   the address bar.
2. **Two overlays had to be lifted.** The chips (`bottom-6 right-4`) and the
   coach caption (`bottom-10 inset-x-0`) are pinned to the *stage*. Full-bleed
   puts them under the control band. The first version of this fix silently
   hid the STYLE button — the only way to change dunk style on a phone —
   which would have traded a layout bug for a lost mechanic.
3. **Portrait phones only.** Landscape and tablet keep 16:10 deliberately. The
   entire failure was one shape applied to every screen; fixing it by applying
   a different shape to every screen is the same mistake.

## THE SECOND HALF: NINE PIXELS PER PIXEL

| | |
|---|---|
| canvas CSS box | 372 × 232 |
| backing buffer | 1116 × 696 |
| **backing pixels per CSS pixel** | **9.01** |

`devicePixelRatio` 3, taken literally. The phone fills 776,736 pixels to light
86,304, and the extra eight are invisible at 6 inches. Capping at 2 removes
**56% of the fill rate** for no perceptible change.

Fill rate dominates on mobile GPUs, so this is the largest framerate item found
so far — and it gets *more* important after the CSS fix, because the canvas is
now four times bigger. `fitCanvas()` handles both: cap the ratio, then cap
total backing pixels, never go below 1:1.

**`MAX_DEVICE_PIXEL_RATIO = 2` is not new** — it is already inside M81's
`ModeHarness`. It is extracted here so the cap can land without waiting on a
full harness migration. When the app is on ModeHarness v3, delete
`canvasFit.ts`.

---

## FILES

| File | Goes where |
|---|---|
| `files/styles/game-surface.css` | `styles/` — **replaces the M81 file of this name** |
| `files/core/canvasFit.ts` | `core/` |
| `files/tests/canvas_fit_test.ts` | `tests/` — 24 tests |
| `evidence/*.png`, `evidence/*.json` | reference only, do not deploy |

## PREREQUISITES

None. This batch deliberately depends on nothing, so it can ship ahead of the
fourteen batches queued behind it.

## WIRING

1. **Import `styles/game-surface.css`** in the root layout. That is the entire
   canvas fix and it needs no component changes.
2. **Call `applyCanvasFit(engine, canvas)`** immediately after the engine is
   constructed, and again in the resize handler. One line each.
3. Confirm with `node tools/integration_audit.mjs --viewport phone`. Coverage
   should read ~80% and `[FEL-CANVAS]` should appear in the console.

### The proper fix, for when the app source is available

The CSS overrides match the deployed markup because the source is not in this
repo. They are a delivery mechanism, not the design. In the component:

```diff
- <div className="relative aspect-[16/10] w-full overflow-hidden rounded-xl ...">
+ <div className="relative w-full flex-1 min-h-[84svh] overflow-hidden rounded-xl
+                 sm:aspect-[16/10] sm:min-h-0 sm:flex-none ...">
```

Then delete `game-surface.css`. An override file that outlives its reason
becomes the next thing nobody can explain.

## ACCEPTANCE

1. `node tools/integration_audit.mjs --viewport phone --modes dunk,karate,surf`
   → coverage ≥ 55% on every mode (it was 26.2%).
2. Every button still on screen. The audit reports canvas geometry; the
   screenshots are the check that matters.
3. `[FEL-CANVAS] dpr 3 → 2.00` on a phone; **absent on a 1× desktop**, which
   is correct — there is nothing to cap.
4. Desktop unchanged at 92%.

## LIMITS

- **The DPR cap is not verified live.** The CSS is — I injected it into the
  deployed app and re-measured. `applyCanvasFit` needs the engine, which is
  inside the bundle and unreachable from outside. It is tested by execution and
  unobserved in the product; that is a weaker claim than the CSS half and the
  two should not be quoted together.
- **The selectors are coupled to Tailwind's emitted class names.** If the
  wrapper's classes change, these rules stop matching and stop working —
  silently. The acceptance check above is the only thing that catches it, which
  is a reason to make the component change and delete this file.
- **`aspect-[16/10]` may not be the only starved container.** I measured eight
  modes; there are twenty-five. The audit is the way to check the rest and it
  takes about a minute per mode.
- **Framerate is still unmeasured.** This fix is predicted to help
  substantially and that prediction has not been tested on real hardware. The
  container renders through SwiftShader.
