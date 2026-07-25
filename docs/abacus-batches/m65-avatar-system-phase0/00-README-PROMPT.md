# M65 — AVATAR SYSTEM: Phase 0 rig gate + core builder (spec, tint, registry, conform tool)

Copy this into Abacus with every file in `files/`. All files NEW — this adds
a system, it replaces nothing. **Read the ⚠ correction below before wiring
anything.**

---

## ⚠ THE CORRECTION THAT CHANGES THE BRIEF

The incoming brief locks the skeleton as *"preserve `mixamorig:` prefix
throughout."* **That is wrong for FEL and would break the entire shipped
animation library.**

The live FEL rig uses **UNPREFIXED** bone names — `Hips`, `LeftArm`,
`RightUpLeg`. Evidence, all from shipped code:

- `anim/clipBuilder.ts` resolves targets by exact name against `Spine`,
  `LeftUpLeg`, `Hips`… A prefixed rig resolves **zero** bones.
- Every authored dunk clip (`eastbay.ts`, `dunkSuite.ts`) keys unprefixed
  names. These are the clips on the live build right now.
- `anim/mirroredClips.ts` carries an explicit correction of this exact
  mistake: *"the shipped skeleton's bones are UNPREFIXED … the draft's
  `mixamorig:`-prefixed pairs would match nothing."* **It has already been
  made once and caught once.**
- `GroundLock` looks up `'Hips'` unprefixed to keep characters on the floor.

Adopting the prefixed convention would make every clip silently no-op and
freeze characters at bind pose across all 23 modes — indistinguishable from
the "T-pose bug" that just took several cycles to diagnose. `fel_conform.py`
therefore **strips the prefix on import**, and `RigValidator` **rejects** a
prefixed rig with a specific error. Full rationale in
`AvatarSkeletonSpec.md`, which is the authoritative version of the spec.

Everything else in the brief I agree with and have built to: attachment
slots over morph targets, RGB-mask tinting, no `MergeMeshes`, no SSAO,
preset heads over face sliders, server-authoritative ownership.

---

## PHASE 0 FIRST — THE GATE

`RigValidationScene.ts` is the harness the brief asks for, and it is the
only thing that should be run until it passes. Route it at `/dev/rig`:

```ts
const rig = await createRigValidationScene(canvas, '/models/candidate.glb', '/anim/dunk.glb');
rig.inspect('LeftArm');   // then RightArm, LeftUpLeg, RightUpLeg
rig.scrub(0.62);          // park on max extension
rig.measure();            // limb-length retention report
rig.toggleSkeleton();
```

It gives you: a conformance audit (bone names, bind pose, tri count), the
four joint camera presets, timeline scrub/step, skeleton and wireframe
overlays, and a **limb-length retention** measurement — if a limb keeps
<85% of its length at full extension, the weights are collapsing.

**Retention is a proxy, not a verdict.** The deltoid at overhead extension
and the hip crease at deep flexion still need eyes on them. The harness
frames the shot and prints the numbers; you make the call. If it fails,
stop — the asset source changes and the rest of the system's assumptions
change with it.

## WHAT I CAN AND CANNOT DELIVER HERE

**Built and shipped in this batch:** the whole code layer — skeleton spec,
types, the Phase-0 harness, the RGB-mask tint plugin, the AvatarBuilder
core, the AssetRegistry, and the Blender conform/probe tool.

**NOT in this batch, honestly:** the actual 3D assets. I cannot generate
meshes, textures, or rigs — no Meshy, no Blender, no image generation in
this environment. The body archetypes, heads, hair, garments and their mask
textures have to come from Meshy (paid tier — free tier is CC BY and not
commercially shippable) and go through `fel_conform.py`. The code is written
to accept them the moment they exist.

`fel_conform.py` is written against the Blender 4.x API but **has not been
executed** here — no Blender available. Run `--probe` first; it changes
nothing, so it is a safe smoke test.

## FILES
| File | What it does |
|---|---|
| `AvatarSkeletonSpec.md` | The locked spec + the full prefix correction. Read first. |
| `files/types/avatar.ts` | AvatarConfig, SlotItem, manifest, `REQUIRED_BONES`. |
| `files/avatar/RigValidator.ts` | Conformance audit + joint sampling + inspection framing. |
| `files/scenes/RigValidationScene.ts` | **Phase 0 harness.** Standalone, no ModeHarness dependency. |
| `files/avatar/TintMaterialPlugin.ts` | RGB-mask zone tinting as a PBR material plugin. |
| `files/avatar/AvatarBuilder.ts` | Core: archetype, slots, tint, height, decals, serialize. |
| `files/avatar/AssetRegistry.ts` | Single load path, container cache, IndexedDB, dedup. |
| `files/tools/fel_conform.py` | Blender probe + conform (strips the prefix, decimates, ledger). |

## WIRING
1. Drop the files in. Add a dev-only route rendering `RigValidationScene`.
2. Run Phase 0 against a candidate avatar + your most extreme dunk clip.
   **Stop there and report the result.**
3. Only after it passes: author `avatar-manifest.json` (bodies + items),
   then `new AvatarBuilder(scene, registry, manifest)`.
4. Ownership: fetch the owned-item list from the server and call
   `setOwnership()`. `equip()` refuses unowned items — but the server must
   validate again on save. Client state is display only.
5. Decals: call `toBindPose()` before `addDecal()`, always. Projecting
   mid-animation makes the decal swim across the skin.

## ACCEPTANCE
1. Phase 0 loads a rigged GLB and prints `[FEL-RIG] ===== PHASE 0 RIG AUDIT`
   with bone count, bind pose, tri count, and any missing bones.
2. A `mixamorig:`-prefixed rig FAILS with the specific prefix error, not a
   vague one.
3. The four joint presets frame tight on each shoulder and hip; scrub +
   step work; `measure()` prints length retention per limb.
4. `fel_conform.py --probe` on a real Meshy/DeepMotion file prints a report
   and exits non-zero when the rig doesn't conform.
5. After conform, the same file passes the in-engine audit — the two agree.
