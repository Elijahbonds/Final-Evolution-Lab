# M98 — Pass 2, Phase 5: 77% of the character is welded to its own head

**23 tests pass by execution. The defect was measured in the deployed build,
in five of five rigs across every mode checked.**

---

## THE FINDING

Pulled the real vertex buffers out of the running game:

| vertex (bind pose) | weighted to | weight |
|---|---|--:|
| left hand `x=+0.91, y=0.62` | **`Head`** (index 5) | 0.78 |
| right hand `x=-0.91, y=0.57` | **`Head`** | 0.68 |
| left forearm `x=+0.42, y=0.62` | **`Head`** | 0.90 |
| chest `x=-0.06, y=0.88` | **`Head`** | 0.97 |
| left foot `x=+0.11, y=-0.84` | `LeftUpLeg` (44) | 0.48 |

**14,128 of 18,409 vertices — 77% of the character — are dominated by the
`Head` bone.** 80% of vertices are bound to a bone that cannot anatomically own
them. `tools/skin_audit.mjs` reports **5 of 5 rigs BROKEN**, in `dunk`,
`karate` and `skateboard` — it is one shared character asset.

The entire upper body is a rigid lump welded to the head. The arms cannot move,
because nothing about the arms is bound to the arm bones.

## WHAT IT EXPLAINS

Everything, and it retires a question that has been open since M24.

M97 established that the **skeleton has been correct the whole time**: the arm
bones sit at 20° from vertical, exactly where M64's solver put them, with the
transform nodes and the bone matrices in agreement, and `idle_stand` playing on
every character. And the mesh renders a T-pose regardless — because the mesh is
not listening to those bones.

**M24, M42, M51, M64, M69 and M80 all worked on the skeleton, the clips, or the
pose. Not one of them could have fixed this.**

Nor could mocap. **Phase 4's entire premise was that conformed clips would fix
the arms**, and conformed clips drive the same bones the mesh ignores. Running
`conform_clips.sh` on the Mini would have produced a perfect `walk` cycle and
changed nothing on screen. That is worth knowing before someone spends a day on
it.

## HOW IT SURVIVED SIX BATCHES

The same way every other bug in this project survived: **every check looked at
the skeleton.** `restPose solved` logs a truth. `restPose applied to skeleton`
logs a truth. Both are about bones. Nothing had ever asked the *mesh* whether it
was listening, and a screenshot at 60 pixels cannot tell you.

It took getting inside the running scene — M97's `Function.prototype.bind` hook
— and then reading vertex buffers. That is three levels below where anyone had
looked.

## WHAT THIS BATCH IS AND IS NOT

**It is not the fix.** The fix is an asset re-export with correct skin weights,
which happens in Blender on a machine I do not have. I cannot repair vertex
weights from here and shipping code that tried would be worse than useless.

**It is the gate.** `auditSkin()` is a pure function — positions, indices,
weights and bone names in, a verdict out — designed to run at spawn and refuse
to let this ship quietly again. Because the fix is manual, done by hand, on
someone's machine, and can silently regress on the very next character.

The audit deliberately reports **only what it can prove**. A left/right weight
swap is a real export bug and it is explicitly *out of scope* — there is a test
asserting the audit stays quiet on one — because a check that cries wolf is a
check people turn off.

---

## FILES

| File | Goes where |
|---|---|
| `files/anim/SkinWeightAudit.ts` | `anim/` |
| `files/tests/skin_weight_audit_test.ts` | `tests/` — 23 tests |
| `evidence/skin-audit.json` | reference only |

Repo tool: **`tools/skin_audit.mjs`** — runs the *same* `auditSkin` against the
deployed build. It does not reimplement the thresholds; two copies of a rule is
how the PRQ weight tables drifted 57% apart between Swift and Python.

```
node --experimental-strip-types tools/skin_audit.mjs
```

## PREREQUISITES

None.

## WIRING

In `CharacterLibrary.spawn()`, after the mesh and skeleton are loaded:

```ts
import { auditSkin, verticesFromBuffers, reportSkin } from '../anim/SkinWeightAudit';

const r = auditSkin(verticesFromBuffers(
  mesh.getVerticesData('position'),
  mesh.getVerticesData('matricesIndices'),
  mesh.getVerticesData('matricesWeights'),
  skeleton.bones.map((b) => b.name),
));
reportSkin(mesh.name, r);      // silent unless something is wrong
```

`reportSkin` says nothing on a healthy character on purpose. A check that logs
on every spawn becomes noise people filter out, which is the mechanism that let
a 77% weight collapse past six animation batches.

Sampling stride is 7 by default — 18,409 vertices is far more than needed to
detect a 77% collapse, and a load check that costs a visible hitch is a check
someone disables.

## THE ACTUAL FIX, FOR WHOEVER HAS BLENDER

1. Open the source character. Confirm the mesh is parented to the armature with
   **automatic weights**, not to a single bone.
2. Weight-paint or auto-weight the arms, hands and torso to their own bones.
3. Re-export glTF with skinning, unprefixed bone names
   (`Hips`, `LeftArm` — never `mixamorig:`).
4. `node --experimental-strip-types tools/skin_audit.mjs` → **0 broken**.

Step 4 is the acceptance test, and it can be run by anyone, on the deployed
build, in about a minute per mode.

## ACCEPTANCE

1. `tools/skin_audit.mjs` reports **0/N broken**. It currently reports 5/5.
2. `[FEL-SKIN]` never appears in the console on a healthy character.
3. Forcing `LeftArm.rotationQuaternion` to a 90° rotation visibly moves the
   arm. It currently does not move it at all — that is the one-line manual
   check for this bug.

## LIMITS

- **This diagnoses; it does not repair.** No code can rebind a mesh correctly.
- **The classifier assumes a T-pose bind.** It reads lateral extent as
  arm-ness, which is true of this rig and of every Mixamo-derived rig, and
  false for an A-pose or a crouched bind. `regionOf` is where that assumption
  lives, in one function, deliberately.
- **It cannot detect left/right swaps, mirrored weights, or subtly wrong
  falloff.** It catches gross misbinding — which is what is wrong here — and
  claims nothing more.
- **Only `dunk`, `karate` and `skateboard` were audited.** They share one asset
  and all failed identically; the other twenty-two modes almost certainly do
  too, and that takes a minute each to confirm.
- **`Head` at index 5 is suggestive of a joint-order mismatch** between the
  glTF skin's `joints` array and the loaded skeleton, but I could not confirm
  it from outside the bundle, and the fix is the same either way.
