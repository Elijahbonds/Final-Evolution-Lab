# M104 — the `mixamorig10:` landmine, and an offline re-skin tool

**26 tests pass by execution, fully offline (a synthetic GLB, no network).**
One confirmed fix shipped. One investigation redirected, honestly, rather than
oversold.

Follows M98 (found 77% of the *deployed* character welded to `Head`, by
reading a live Babylon scene) and M99 (the camera). This batch went looking
for a Blender-free way to actually repair the mesh — and downloaded the real
production asset to do it.

---

## 1 — CONFIRMED AND FIXED: the `mixamorig10:` prefix

FEL resolves bones by unprefixed name (`Hips`, `LeftArm`). Meshy/Mixamo/
DeepMotion export `mixamorig:`-prefixed, so three copies of a strip-prefix rule
exist — `anim/boneNames.ts` (runtime), `tools/clip_check.mjs` (offline
checker), `tools/fel_conform.py` (the Blender script, source of truth) — with
a comment on the TS file saying explicitly: *if you change this list, change
all three.*

**All three carried the same blind spot.** `KNOWN_PREFIXES` was an enumerated
literal list — `['mixamorig:', 'mixamorig1:', 'Armature|', 'root|']` — and the
Python copy didn't even go that far, hardcoding the bare string `"mixamorig:"`
four separate times with zero digit tolerance.

I downloaded FEL's own production base mesh —
`male_athlete_base_model_fbx`, the character behind `dunk` and eleven other
modes — straight from its source URL (still live, 50MB) and converted it with
`assimp` to read its real bone names. Every one of its 65 joints is prefixed
**`mixamorig10:`** — not `mixamorig:`, not `mixamorig1:`. Mixamo appends an
incrementing suffix each time an asset is re-downloaded through its
auto-rigger; there is no reason to expect "1" specifically, and this asset
proves it.

Against that prefix, all three copies fail silently:

- `boneNames.ts` / `clip_check.mjs`: `'mixamorig10:Head'.startsWith('mixamorig1:')`
  is `false` (the 11th character is `0`, not `:`) — falls through, returns the
  prefixed name unchanged.
- `fel_conform.py`: **worse.** `probe()`'s `prefixed = [n for n in names if
  n.startswith("mixamorig:")]` finds **zero** prefixed bones on this asset and
  reports `conforms: True` — the one tool built to catch this bug would tell
  whoever ran it that the rig is fine, on the exact rig that is not.

Fixed in all three files with one rule — `/^mixamorig\d*[:_](.+)$/i` — instead
of an enumerated list that is always one export behind. `anim_test.ts` gained
two permanent regression cases using the real prefix. Full repo suite: **32/32
green, 1702 assertions, zero regressions.**

## 2 — INVESTIGATED, HONESTLY INCONCLUSIVE: repairing the skin weights offline

Blender isn't available in this environment. Rather than stop at "someone
needs Blender," I built a **dependency-free GLB reader/writer in plain Node**
(`tools/glb_reskin.mjs` — parses the binary container and glTF JSON by hand,
no npm packages) and a proximity-based re-skinning algorithm: for every
vertex, build a bone segment for each parent→child joint pair, find the
closest segments in bind-pose space, weight by inverse distance, write back
`JOINTS_0`/`WEIGHTS_0`. It is the plain version of what Blender's "Automatic
Weights" does with heat diffusion.

**What it found, measuring the real downloaded asset directly:**

| mesh | vertices | dominant bone | share |
|---|--:|---|--:|
| `Ch28_Body` | 9,466 | `Head` | **59.4%** |
| `Ch28_Hoody` (the jacket — has full sleeves to the wrist) | 4,218 | `Spine2` | 25.7% |
| `Ch28_Pants` | 4,332 | `LeftUpLeg` | 23.7% |
| `Ch28_Sneakers` | 2,415 | `LeftFoot` | 42.2% |
| `Ch28_Hair` / `Ch28_Eyelashes` | 15,541 / 753 | `Head` | 100% (correct) |

`Ch28_Body`'s 59.4% Head-share looked, at first glance, like the same bug M98
found live. **It probably isn't**, and the reason matters: `Body`'s vertices
cluster almost entirely between y=130 and y=176 (head, face, neck) with
essentially nothing between y=20 and y=130 — this is not a full nude body
mesh, it's the small amount of *exposed skin* (face, neck, hands) on a
character wearing a full hoodie and pants. Being Head-dominant is largely
**correct** for that geometry.

So I checked the mesh that actually has sleeve geometry running the full
length of the arm — `Ch28_Hoody`, which extends to `x=±70.1`, matching
`LeftHand` at `x=68.5`. If a jacket sleeve is bound to the wrong bone, that's
what would visibly fail to bend.

**It was already correct.** Restricting to sleeve vertices past the shoulder
(`|x| > 35`): **734 of 734 — 100% — bound to an arm-family bone**, before any
repair and after. Re-skinning changed the whole-mesh dominant-bone tally
(`Spine2` at 25.7% dropped out of the top three; `Neck`, `LeftShoulder`,
`RightShoulder` newly appeared) but the part I could actually verify —
does the sleeve know it's a sleeve — was already true in the raw source.

**And the vertex counts don't match.** This raw asset's four pieces sum to
20,431 vertices. M98 measured the *deployed* character's single mesh
(`Body_c5`) at **18,409**. Those are not the same number, which means some
transformation happens between "raw Mixamo download" and "what the live game
actually renders" that I cannot see or reproduce from here — no merge/combine
step exists anywhere in this repo's batch code, and I could not re-authenticate
to the live app in this session to capture the actual asset URL from the
network tab and compare directly.

**So I am not claiming to have fixed the live T-pose.** I could ship the
repaired GLB, but pointing it at the wrong file and calling it fixed would be
the same mistake this project has made before — reading a proxy for the thing
instead of the thing. What I can respectably claim:

1. The prefix bug is real, confirmed against the actual production asset, and
   fixed.
2. The raw source asset, at least in the one region I could directly verify
   (the jacket sleeve), does **not** show the defect M98 found live. That
   redirects the investigation: **whoever has Blender should not assume the
   raw downloaded asset is broken and start "fixing" it** — the more likely
   place to look is whatever export/merge/optimize step turns this multi-mesh
   source into the single 18,409-vertex asset actually deployed.
3. A tested, reusable, dependency-free tool now exists to answer this
   precisely, the moment someone can extract the *actual* deployed `.glb` —
   `node tools/glb_reskin.mjs inspect <file>` gives the same measurement M98
   took live, offline, in about a second.

---

## FILES

| File | Goes where |
|---|---|
| `files/tools/glb_reskin.mjs` | `tools/` — `inspect` and `reskin` subcommands |
| `files/tests/glb_reskin_test.ts` | `tests/` — 26 tests, fully offline |
| `evidence/male_athlete_base-inspect.txt` | the real asset's per-mesh weight tally |
| `evidence/hoody-sleeve-check.txt` | the sleeve-specific before/after check |

**Also modifies, in place** (no new batch folder — these are existing files
gaining a fix):

- `m80-external-animation/files/anim/boneNames.ts` — regex-based prefix strip
- `m80-external-animation/files/anim/boneNames.ts` test additions
- `m80-external-animation/files/tools/clip_check.mjs` — mirrored exactly
- `m65-avatar-system-phase0/files/tools/fel_conform.py` — same rule, `re`-based

## WIRING

The prefix fix needs no wiring — it's already in the files those batches ship.
If M80's `boneNames.ts` has already been integrated into the live app, this
one-file diff should go out on its own; it is small, self-contained, and every
day it isn't shipped is a day this exact asset would silently fail to conform.

`glb_reskin.mjs` is a diagnostic/repair CLI, not app code:

```bash
node tools/glb_reskin.mjs inspect  path/to/character.glb
node tools/glb_reskin.mjs reskin   path/to/character.glb out.glb [meshName]
```

## ACCEPTANCE

1. `node --experimental-strip-types [...] tests/anim_test.ts` → includes
   `mixamorig10: stripped` passing, 48/48 total.
2. Repo-wide: `node tools/certify.mjs` → 32/32 suites, 1702 assertions.
3. `node tools/glb_reskin.mjs inspect <any .glb>` runs with no npm install.

## LIMITS

- **The prefix fix is unconditionally solid.** The re-skin investigation is
  not — see the section above. Do not read "M104" as "the T-pose is fixed."
  It is not, and this batch says so on purpose.
- **`reskin` has not been run against the actual deployed asset**, because
  that asset could not be obtained in this session (no cached login; a fresh
  authentication requires interactive credentials this project has
  deliberately not handed to the agent). The tool is ready the moment someone
  can extract it.
- **The algorithm is geometric, not anatomical.** It cannot know a sleeve
  should stay slightly looser than skin, or that a shoulder seam has a design
  intent beyond nearest-bone. It repairs *bone-vs-geometry mismatches*; it
  cannot improve on a mesh whose weights were already deliberately authored,
  only on ones that are simply wrong.
- **One skin, one character.** The FBX had exactly one `skins[0]`; a rig with
  multiple skins or a mesh with more than 4 joint influences per vertex
  (glTF's `JOINTS_0`/`WEIGHTS_0` limit) is untested.
