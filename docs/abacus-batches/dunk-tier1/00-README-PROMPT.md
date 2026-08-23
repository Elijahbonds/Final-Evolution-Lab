# DUNK TIER 1 — the whole remaining fix, in one folder

**8 files. 1,042 lines. Zero external dependencies** — four of the five modules
import nothing at all.

This replaces the 24-zip integration order for the dunk contest. Read
`docs/DUNK-FIRST.md` for why.

---

## THREE CHANGES. THAT IS ALL.

`node tools/dunk_gate.mjs` currently reports **3/7** against the deployed
build. These take it to 7/7:

| # | change | effort |
|---|---|---|
| 1 | Set the dunk camera's `radius` to **3.0** (it is 14) | one number |
| 2 | Mount `<CaptionRegion />` once inside the game surface | two files |
| 3 | Re-export the character mesh with correct skin weights | one Blender session |

Everything else in this folder supports those three or guards against
regression.

## 1 — THE CAMERA

```ts
import { planFor } from '../core/cameraPresets';

const plan = planFor('dunk');
if (plan.applied) camera.radius = plan.radius;      // 3.0
else console.warn(`[FEL-CAM] dunk: ${plan.reason}`);
```

Converged against the live build and then measured: the character goes from
**8.2% of the screen (46 CSS px) to ~21% (~150 px)**. Do not compute this
number — `radius` is measured from the camera's *target*, not the character,
and arithmetic undershoots by a third.

Keep the `else` branch. It is what turns "the preset silently did nothing" into
a line someone can read.

`cameraPresets.json` carries all twelve modes. **Apply the `dunk` row only.**
`karate-vs` is already correctly framed and `baseball` is too *close*; a
fleet-wide change breaks both, and `planFor` refuses them with a reason.

## 2 — THE CAPTIONS

```tsx
import { CaptionRegion } from '../ui/CaptionRegion';

<CaptionRegion />        // once, inside the game surface, above the canvas
```

Add `SR_ONLY_CSS` to the global stylesheet if Tailwind's `sr-only` is not
available. Getting `sr-only` wrong looks identical to getting it right.

Measured: **0 `aria-live` regions in four modes today.** The caption bus
(`captions.ts`) has existed since M82 and renders nowhere. This is forty lines
and it is the entire gap — the accessibility work here is not missing, it is
unplugged.

## 3 — THE MESH

**This is the one that matters most and the only one that is not a code
change.**

Measured: **77% of the character mesh is dominated by the `Head` bone.** The
hands are weighted `Head` at 0.78, the chest at 0.97. The upper body is a rigid
lump welded to the head — the arms cannot move whatever the skeleton does.

**Before opening Blender, read this.** M104 downloaded the raw source asset
(`male_athlete_base_model_fbx`) and checked it directly. The one region that
would actually show this bug — the jacket sleeve, which runs the full arm to
the wrist — was **already 100% correctly bound to arm bones**, before any
repair. The raw download's vertex count (20,431 across 4 meshes) also does not
match the deployed character's (18,409, one merged mesh) that M98 measured
live. Something between "raw download" and "what the game renders" changes
the mesh, and it is not reproducible from the raw source alone.

**So: extract the actual deployed `.glb` first** (browser dev tools → Network
tab, while playing any mode with this character — dunk, karate, onevone all
use it), and run `node tools/glb_reskin.mjs inspect <file.glb>` on THAT file
before assuming the raw Mixamo download is what needs fixing. It gives the
same per-mesh weight measurement M98 took live, offline, in about a second —
confirm the 77%/Head number reproduces on the real deployed file before
spending a Blender session on the wrong one.

Once the right file is confirmed broken, in Blender:

1. Confirm the mesh is parented to the armature with **automatic weights**,
   not to a single bone.
2. Weight-paint or auto-weight the arms, hands and torso to their own bones.
3. Export glTF with skinning, **unprefixed bone names** (`Hips`, `LeftArm` —
   never `mixamorig:` — check for `mixamorig10:` too, see M104: the digit is
   never fixed, it increments on every Mixamo re-download).
4. `node --experimental-strip-types tools/skin_audit.mjs` → **0 broken**. It
   currently reports 5/5.

**Do the camera and the mesh together.** At 46 pixels a correct arm and a
welded one are the same picture — that is what made the T-pose get
misdiagnosed twice. Camera without mesh gives you a large broken character;
mesh without camera gives you a correct one nobody can see.

---

## FILES

| File | Goes where | Why |
|---|---|---|
| `files/core/cameraPresets.ts` | `core/` | change 1 |
| `files/config/cameraPresets.json` | `config/` | change 1 — measured values |
| `files/ui/CaptionRegion.tsx` | `ui/` | change 2 |
| `files/core/captions.ts` | `core/` | change 2 — the bus it renders |
| `files/anim/SkinWeightAudit.ts` | `anim/` | change 3 — the regression guard |
| `files/styles/game-surface.css` | `styles/` | **already shipped** — included so a redeploy cannot lose it |
| `files/core/canvasFit.ts` | `core/` | the DPR cap; verify `[FEL-CANVAS]` appears |
| `files/core/scoreScale.ts` | `core/` | PRQ input — see the note below |

### The one that needs a decision, not a paste

`scoreScale.ts` fixes PRQ being fed a raw per-mode score — karate submits 1250
and pays **39× the XP** of a dunk contest submitting 25, because karate counts
in thousands and dunk counts in tens.

It **throws** on any mode without a cited scale, and only two of twenty-five
have one. Wire it behind `isScaled(mode)` so an unscaled mode pays nothing
rather than paying an arbitrary amount, or leave it out of tier 1 entirely.
Both are defensible; silently defaulting is not.

## WIRING ORDER

1. `SkinWeightAudit` into `CharacterLibrary.spawn()` — silent on a healthy
   character by design. Do this **first** so the mesh re-export can be verified
   the moment it lands.
2. The camera preset.
3. `<CaptionRegion />`.
4. The mesh, from Blender.

## ACCEPTANCE

```bash
node tools/dunk_gate.mjs        # 7/7
```

Then the part no tool can measure: **twenty strangers, ten minutes, their own
phones.** Dunk is done when more than half start a second contest without being
asked.

## WHAT IS DELIBERATELY NOT HERE

`DunkSim`, `ModeKit`, replays, determinism, server-side verification — about
700 lines that drag in six more batches. It is good work and it buys exactly
one thing, prize money, which is worthless until people want to play twice.

It waits for the twenty strangers.
