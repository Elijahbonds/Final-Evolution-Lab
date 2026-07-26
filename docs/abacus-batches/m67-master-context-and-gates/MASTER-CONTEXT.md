# FINAL EVOLUTION LAB — Master Context & Build Brief (canonical)

**This is the repo copy. It is the version agents should read.** It carries
the incoming master brief's strategy, standards, and execution order intact,
with three corrections applied where the brief conflicts with the shipped
codebase. The corrections are marked ⚠ and explained — they are not
preferences, they are facts about the live build.

---

## ⚠ CORRECTION 1 — THE SKELETON SPEC (third time raised)

The brief's Section 4.1 states:

> `Root bone: mixamorig:Hips` · `Naming: preserve mixamorig: prefix throughout`

**This is factually wrong for FEL and adopting it breaks the live build.**
The brief says it "supersedes prior framing where in conflict" — but a
document cannot supersede a property of the deployed rig.

### The evidence (all shipped, all live)

| Source | What it proves |
|---|---|
| `anim/clipBuilder.ts` | Resolves every animation target with `skeleton.bones.find(b => b.name === boneName)` against `Hips`, `Spine`, `LeftArm`. A prefixed rig resolves **zero** bones. |
| `anim/authored/eastbay.ts`, `dunkSuite.ts`, `locomotion.ts` | Every authored dunk clip on the live build keys unprefixed names. |
| `anim/mirroredClips.ts` (M28) | Contains a written correction of this exact error: *"the shipped skeleton's bones are UNPREFIXED (LeftArm, RightUpLeg, … — verified from elijah-hero.glb). The draft's `mixamorig:`-prefixed pairs would match nothing."* |
| `anim/importSanitizer.ts` (GroundLock) | Looks up `'Hips'` unprefixed to keep characters on the floor. |
| M64 `restPose.ts` | The idle-pose solver resolves `LeftArm`/`RightArm` unprefixed. |

### What happens if the brief's version is adopted
Every authored clip silently no-ops. Characters freeze at bind pose across
all 23 modes. GroundLock stops clamping. It is **indistinguishable from the
T-pose bug that took several diagnostic cycles to find** — and this exact
mistake has already been made once and caught once (M28).

### The correct spec

```
Skeleton:   Mixamo-standard humanoid hierarchy
Naming:     UNPREFIXED — Hips, Spine, LeftArm, RightUpLeg
Bind pose:  T-pose
Up axis:    Y          Forward: -Z          Units: meters
Root bone:  Hips       (height scaling)
Validation: the REQUIRED-NAME set, NOT a bone count
```

Required: `Hips, Spine, Spine1, Spine2, Neck, Head, LeftShoulder, LeftArm,
LeftForeArm, LeftHand, RightShoulder, RightArm, RightForeArm, RightHand,
LeftUpLeg, LeftLeg, LeftFoot, LeftToeBase, RightUpLeg, RightLeg, RightFoot,
RightToeBase`. Extra bones (twist, fingers) are fine and must not be rejected.

**On "65 bones":** counting is the wrong check. It rejects a good rig
carrying extra twist bones and accepts a 65-bone rig whose names nothing can
resolve. Names are what the engine resolves; names are what we validate.

**Importers strip the prefix** (`tools/fel_conform.py`, M65). **The asset
gate rejects it** (`tools/validate_assets.py`, M66). If Meshy or DeepMotion
hands you `mixamorig:`, that is expected and handled at ingest — it just
must never reach the runtime.

---

## ⚠ CORRECTION 2 — THE MODE CONTRACT IS `ModeDefinition`, NOT `IGameMode`

Brief §4.3 says *"Every mode implements the IGameMode contract."* No such
interface exists in FEL. The shipped contract, implemented by all ~23 modes:

```ts
interface ModeDefinition {
  modeId: string;
  mood: string;          // drives LightRig + RenderPipeline + Backdrops
  camPreset: string;     // CameraDirector preset key
  load(ctx: ModeContext): Promise<void>;
  onInput(ctx: ModeContext, e: FelInput): void;
  update(ctx: ModeContext, dt: number): void;
  dispose(): void;
}
```

An agent that writes `IGameMode` produces a mode the harness cannot load.
The *rule* the brief states — adding a mode never edits another mode — is
correct and stands.

---

## ⚠ CORRECTION 3 — THE DEPLOY TOPOLOGY

Brief §5A treats `deploy.mjs` as a stub needing "the real Abacus publish
call." Verified against the repo (M66): **there is no Babylon dependency
anywhere in git and no game source outside `docs/`.** The live app is
Next.js served by Abacus; `frontend/` is a separate Create React App.

Abacus owns the build and the deploy. There is no public Abacus deploy API
I can find, and inventing one produces a script that cannot work. So
`deploy.mjs` ships as a **packager + verifier with a marked adapter seam**:
it assembles a drop-ready bundle, runs the gates, and hands you a verified
folder. The publish step is a one-function adapter to fill when/if an API
exists. Everything upstream of the drop is automated; the live link is
verified after it by `smoke.mjs`.

---

## 1 · STRATEGY (unchanged from the brief — this part is right)

**Prime directive:** FEL ships first. Nexus/Cell is *extracted* from FEL
after v1 — never built before it, never instead of it. If a task doesn't
move the dunk core loop forward, it waits.

**The corrected competitive framing:** go vertical, rent the horizontal,
keep the marketplace flat, never subtract the game.

| Trap | Corrected move |
|---|---|
| Clone Seele | Seele is horizontal and can't make a dunk feel real. Build the vertical it will never go deep on. |
| Rebuild Higgsfield | Rent it (~$9/mo) for intro video, cut-scenes, marketing. |
| Clone Abacus | Use it. It already deploys FEL. |
| Subtract the game | FEL is the seed the platform is extracted from. |
| MLM / downline | Flat marketplace only (make → sell → revenue share). Recruit-a-downline imports FTC/pyramid risk. |

### The firewall (non-negotiable)
1. `[SHIP]` and `[NEXUS]` never merge.
2. FEL ships before Nexus is built.
3. Cell is built last — an agent needs a definition of "better", which only
   a shipped game provides.
4. One mode at a time; the dunk loop is the current gate.
5. Real-money features need legal review **before** any build.
6. **Server-authoritative wallet precedes any payment or ownership.**
7. Nothing deploys that skips a gate. The pipeline fails closed.

---

## 2 · ASSET BUDGETS (as briefed — enforced by `tools/validate_assets.py`)

| Class | Triangles | Textures |
|---|---|---|
| Avatar part | < 8,000 | albedo 1024, normal 512, ORM 512 |
| Avatar (full) | < 25,000 | all slots combined |
| Prop | < 5,000 | 1024 max, KTX2 |
| Environment | < 150,000 | baked lightmaps, KTX2 |
| Animation file | **0 meshes** | none — skeleton + animation only |

KTX2/Basis, power-of-two, ORM packed (O=R, R=G, M=B). Y-up, meters, -Z
forward, root at origin. Tintable assets carry an RGB mask
(R/G/B = primary/secondary/accent). **Meshy FREE tier is CC BY — not
commercially shippable. Paid tier only.**

Runtime: `LoadAssetContainerAsync` + `instantiateModelsToScene()`. Never
`MergeMeshes` on a swappable avatar. One registry is the only load entry
point. Art direction: stylized-athletic, not photoreal.

---

## 3 · EXECUTION ORDER

| Wave | Ship lane | Cash lane | Platform lane |
|---|---|---|---|
| NOW | Rig validation → dunk loop. Pipeline + asset gate. Repo cleanup. | Ship the book. Reprice coaching. Owned content. | dark |
| W1 | Frame monitor, animation bridge, **wallet + Lab Credits**, avatar builder v1. | Certification. Higgsfield content. Interviews. | dark |
| W2 | Karate. Ride/Carve + racetrack. Env loader + adaptive quality. | Nutrition cert. Brand funnel. | Generation-service **seam only**. |
| v1 | Ship FEL v1. | Scale what works. | — |
| POST | — | Physical ventures (+ CPA). | Extract Nexus → then Cell. |

Two lanes in parallel is **not** scope drift — they use different hours and
different muscles, and the cash lane funds the runway. Starting the platform
lane early *would* be drift, so it stays gated.

---

## 4 · COMPLIANCE REGISTER (blocks shipping, not starting)

| Flag | Applies to | Rule |
|---|---|---|
| Meshy Free = CC BY | All Meshy assets | Paid tier before ship |
| Server-authoritative wallet | Economy | Must exist before any payment/ownership |
| Real-money / skill-game law | IRL Dunking $ | Legal review before any build |
| EU AI Act disclosure | User-facing AI content | Obligations from Aug 2, 2026 |
| Affiliate disclosure | Brand funnel | Required per region |
| Content provider firewall | Who Scene It, Music, Brain Brawl | No scraped clips/likenesses/IMDb |
| NEEDS-VERIFY physics numbers | Book, certification | Fake-precise figures must not be republished as fact |
| Flat marketplace, not MLM | Creator Cards | Keep revenue-share flat |
| Closed-loop tax structures | Any "wrapper" venture | CPA review before forming entities. *(Previously declined as a build task — this remains a CPA/attorney matter, not a coding one.)* |

---

## 5 · WHAT IS ACTUALLY BUILT (status, not aspiration)

| System | State |
|---|---|
| Dev/deploy + batch gate + asset gate | **Built** (M66), tools executed and verified |
| Asset conform/probe (Blender) | **Built** (M65), written against Blender 4.x, not executed here |
| Avatar system code + Phase 0 rig harness | **Built** (M65). 3D assets themselves: not possible here |
| Animation bridge | Spec'd, not built |
| Wallet + Lab Credits ledger | **Built in this batch** (M67) |
| Frame/perf monitor | **Built in this batch** (M67) |
| Generation-service seam | **Built in this batch** (M67) |
| ~23 game modes, visual/audio stack | **Built and live** (M13–M64) |
| Nexus / Cell | Correctly dark |
