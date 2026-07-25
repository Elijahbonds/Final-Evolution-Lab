# CLAUDE.md — FEL working standards

Read this every session. These are the rules that travel with the code.

---

## THE SKELETON SPEC (locked — this is the ABI)

**Bone names are UNPREFIXED.** `Hips`, `Spine`, `LeftArm`, `RightUpLeg`.

**NOT `mixamorig:`-prefixed.** Every authored clip, the mirroring system,
GroundLock, and the rest-pose solver resolve bones by exact name at runtime.
A prefixed rig resolves *zero* bones — every clip silently no-ops and
characters freeze at bind pose across all 23 modes. This mistake has already
been made once (see the correction inside `anim/mirroredClips.ts`) and would
look exactly like the T-pose bug that took several cycles to diagnose.
Importers strip the prefix; the asset gate rejects it.

| Property | Value |
|---|---|
| Hierarchy | Mixamo-standard humanoid |
| Naming | UNPREFIXED |
| Bind pose | T-pose |
| Axes / units | Y-up, -Z forward, meters |
| Root | `Hips` (height scaling) |
| Validation | the REQUIRED-NAME set, **not** a bone count |

Required names: `Hips, Spine, Spine1, Spine2, Neck, Head, LeftShoulder,
LeftArm, LeftForeArm, LeftHand, RightShoulder, RightArm, RightForeArm,
RightHand, LeftUpLeg, LeftLeg, LeftFoot, LeftToeBase, RightUpLeg, RightLeg,
RightFoot, RightToeBase`. Extra bones (twist, fingers) are fine.

Full rationale: `docs/abacus-batches/m65-avatar-system-phase0/AvatarSkeletonSpec.md`.

## ASSET BUDGETS (enforced by `tools/validate_assets.py`)

| Class | Triangles | Notes |
|---|---|---|
| avatar (full) | 25,000 | all slots combined |
| avatar part | 8,000 | one slot item |
| prop | 5,000 | |
| environment | 150,000 | |
| animation | **0 meshes** | skeleton + animation only |

Textures: KTX2/Basis only, power-of-two, albedo ≤1024, normal/ORM ≤512,
ORM packed (occlusion=R, roughness=G, metallic=B). Tintable assets carry an
RGB mask (R=primary, G=secondary, B=accent).

## HOW THIS PROJECT ACTUALLY SHIPS

The Babylon game source is **not in this repo** — it lives in Abacus, which
owns the build and deploy. This repo holds drag-and-drop batches under
`docs/abacus-batches/`, plus tooling.

So the loop is: write a batch → `node tools/verify_batch.mjs <batch>` →
drag into Abacus → `node tools/smoke.mjs` against the live link.
Never claim something is "deployed" without the smoke test or a screenshot.

## BATCH RULES

- One batch = one `00-README-PROMPT.md` + a `files/` tree mirroring the real
  source layout.
- The README's FILES table must list every shipped file, and every shipped
  file must appear in the README. `verify_batch.mjs` enforces both.
- A file that REPLACES an earlier version must say so explicitly, by filename.
- Re-ship unchanged dependencies when it makes a batch self-contained; say so.
- Never ship a partial file. A truncated paste is worse than no batch.

## MODE CONTRACT

Every mode implements `ModeDefinition`:
`{ modeId, mood, camPreset, load(ctx), onInput(ctx, e), update(ctx, dt), dispose() }`.

- Never edit another mode to make yours work — extract to a shared module.
- Every phase needs a watchdog budget. A mode that can stall will stall.
- Clip names come from `clipRegistry` (`SPORT_CLIP` / `installSafePlay`)
  only. A raw string clip name is a bug.
- HUD fields are bare values; the bezel does the labelling.

## WORKING RULES

- **One scoped task per session.** "Build the dunk approach blend tree", not
  "build the game".
- **Measure before optimizing.** Frame monitor first, guesses never.
- **Verify before claiming.** Screenshots and console logs, or it didn't
  happen. This is how every real bug in this project was found.
- **Fail closed.** If a gate is unsure, it rejects. Rejecting a good asset
  costs a minute; shipping a bad one costs a deploy cycle.
- **Don't invent APIs.** If a backend/credential/service isn't visibly
  available, build the seam and say so — never fake the integration.

## SECURITY

Never commit: `MONGO_URL`, `DB_NAME`, `EMERGENT_LLM_KEY`, PayPal/Stripe
secrets, Firebase service accounts, `GoogleService-Info.plist`. Real-money
paths need age/geo gates and a legal review before shipping. UGC audio and
likenesses go through the existing `pending_review` moderation flow.
