# M73 — Nexus Web: all 20 venues as Babylon scenes, rendered and verified

Drop `files/nexus/` into the game source. `files/tools/render_check.mjs` goes
in the repo.

---

## THE PIVOT

You asked for high-quality **web** games — Babylon/Three — and said iOS isn't
required. That changes what is worth building *and*, more importantly, what
can be **proven**.

The Swift engine could never be run here: 74% of it needs Apple frameworks, so
the strongest available check was a type-check of a subset (M71). A Babylon
scene has no such limit. Chromium with SwiftShader renders it headlessly on
any Linux box, which means a venue can be **built, rendered, and looked at**
in CI.

That is a categorically better guarantee than "it compiles", and it paid off
within the first run.

```
Nexus Web — rendering 20 venue(s) headlessly (SwiftShader)
  PASS basketball_h2h   meshes= 30 lights=2 colors= 125 lum=130
  PASS basketball_3v3   meshes= 54 lights=2 colors= 140 lum=140
  …
  20/20 venues render
```

---

## WHAT SHIPPED

### `NexusWebScene.ts` — a 3-D, web-native scene system

**Not a port of the Swift descriptors.** Those describe a 2-D SwiftUI Canvas:
normalised `{x, y}` with no depth, and `sprite` meaning an SF Symbol. Correct
for what they were built for, and actively wrong for a 3-D Babylon game —
force-fitting them would mean inventing a Z for every entity and pretending SF
Symbols exist in a browser. This keeps what carried over (the 20-mode
taxonomy, the venue/actor/prop split, per-mode palettes) and drops what didn't.

Everything is procedural — `MeshBuilder` primitives and `DynamicTexture`-painted
court lines. Same constraint the rest of FEL runs under: nothing to download,
nothing to 404, and 20 venues cost kilobytes instead of hundreds of megabytes.

Quality comes from the parts that are nearly free and usually skipped:

- a **gradient sky dome** rather than a flat clear colour — one extra mesh, and
  most of why a scene reads as a place instead of a background
- a real **lighting rig**: hemispheric fill tinted to the sky, directional key
  with exponential shadow maps
- **tone mapping, exposure, contrast, vignette** per venue — the single biggest
  quality lever in Babylon and it costs nothing
- **painted markings** per sport (basketball, tennis, soccer, volleyball) and
  painted swell for water/snow/sand — the M64 ocean court, generalised

### `venueSpecs.ts` — 20 venues as **typed values, not JSON**

M72's Swift descriptors shipped broken because hand-written JSON drifted from
what the type actually decoded, and nothing compared them. The fix there was to
generate the JSON from the types. On the web there's a stronger option:
**delete the boundary.** These are TypeScript values — a typo is a compile
error, a renamed field breaks the build, and there is no serialised copy to
drift. `tsc` is the validator.

Each venue owns a palette so 20 modes don't blur together: Venice dusk pink
over deep blue, the dojo's maroon-on-near-black, Neuro Arena's indigo, Alpine
white-out. `market_browse` gets display plinths and **no competitors** —
it's a browsing surface, not a match.

### `render_check.mjs` — the check that made the difference

Renders each venue and inspects the actual frame: mesh/light/material counts,
distinct colours, luminance spread. Counts matter because **a spec that
silently builds nothing still renders a clean empty sky** — and FEL has
already shipped a mode that "passed" while showing a loading screen (M69).

---

## TWO BUGS IT CAUGHT — INCLUDING ONE IN ITSELF

### 1. E26 reproduced in the new engine, caught automatically

`karate_h2h` rendered as **a solid maroon rectangle**: the camera's resting
position (radius 11, beta 1.15) resolved to `z ≈ -8.6`, behind the dojo wall at
`z = -8`, filling the frame with flat paint.

This is the same bug that cost **three cycles** on the live FEL build and was
only ever found by a human looking at screenshots. Here it was flagged on the
first automated run.

Fixed twice over — the specs moved, **and** the loader now carries a framing
guard. It's exact rather than heuristic: a wall is a plane, so compare which
*side* of it the camera and target fall on. Different sides means the wall is
between them.

```
[NEXUS] framing: camera for "karate_h2h" sits behind the wall at [0, 0, -8]
        — it will fill the frame with flat colour.
```

### 2. My own gate was measuring the wrong pixels ⚠️

The first run failed **12 of 20** venues as "effectively blank". They were
fine — the screenshots showed fully composed scenes.

`readPixels` reads from WebGL's **bottom-left origin**, so my 128×80 sample
only ever looked at the dark foreground corner of the frame, which on a
dusk-lit venue is near-uniform. It now reads the whole drawing buffer with a
stride.

A metric that samples an unrepresentative region is worse than no metric: it
manufactures failures and buries the real ones. It would have condemned 12
good venues and hidden the one genuine defect among them.

**The screenshots are why this was caught.** Assertions alone would have said
"12 venues broken" and been believed.

### 3. A quality fix the render surfaced

Crowd tiers sat 4.5 units behind the hoop and read as a **bar across the
backboard**. Pushed back in 3v3, soccer, football, tennis and baseball. Not a
crash, not an assertion failure — just visibly wrong, and only findable by
looking.

---

## FILES

| File | Goes where |
|---|---|
| `files/nexus/NexusWebScene.ts` | game source `nexus/` |
| `files/nexus/venueSpecs.ts` | game source `nexus/` |
| `files/tools/render_check.mjs` | repo `tools/` |

## WIRING

```ts
import { buildNexusScene } from '../nexus/NexusWebScene';
import { specFor } from '../nexus/venueSpecs';

// inside a ModeDefinition.load(ctx):
const spec = specFor('basketball_h2h');
if (spec) this.venue = buildNexusScene(ctx.scene, spec, ctx.canvas);
// …then spawn real characters from CharacterLibrary as usual.
// this.venue.dispose() in dispose() — everything is under one root.
```

The placeholder actors are deliberately **not** a character rig: real avatars
still come from `CharacterLibrary`. They exist so a venue can be composed,
framed and reviewed before any rig loads — and so a mode that fails to spawn
characters shows a readable scene instead of an empty court. Their arms hang at
their sides, because the E25 lesson is that a default pose resembling a T-pose
reads as a broken rig even on a placeholder.

## ACCEPTANCE

1. `npm install --no-save @babylonjs/core esbuild`
2. `node tools/render_check.mjs` → **20/20 venues render**.
3. `node tools/render_check.mjs --shots out/` → open the PNGs. Every venue
   should be recognisable as its sport, with legible markings, a lit subject
   and no wall filling the frame.
4. `bash tools/green_check.sh --fel` → venue render **PASS**.

## HONEST LIMITS

- **These are venues, not gameplay.** Ground, props, lighting, camera and
  placeholder bodies. The existing mode logic — `BasketballCore`, `FightCore`,
  `ControlSource` — is untouched and still drives play.
- **Rendered under SwiftShader**, software rasterisation. Composition, framing
  and lighting are verified; real-GPU frame timing is not. Run `PerfMonitor`
  (M67) on a device before trusting the budget.
- **Entity placement is principled, not playtested.** Camera framings are
  derived from venue geometry and checked against the wall guard; they need a
  play pass to become *good* rather than correct.
- **Three.js was mentioned; this is Babylon.** FEL is already a Babylon app —
  introducing a second 3-D engine would fork the renderer for no gain. Say the
  word if you want a Three.js path instead and I'll scope it honestly.
