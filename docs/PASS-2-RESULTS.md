# Pass 2 — what measuring the product actually found

**Written after Phase 10 of pass 2.** Companion to `docs/GAP-AND-PASS-2.md`
(which set the plan) and `docs/BASELINE-2026-07-27.md` (the first measurement).

---

## The one sentence

> **Pass 1 wrote 60,000 lines against a codebase it could not see. Pass 2
> looked at the product, and four of the things pass 1 called BUILT are broken
> in ways no amount of new code would have fixed.**

## The scorecard

| criterion | pass 1 | pass 2 | what was measured |
|---|---|---|---|
| boot | UNKNOWN | **PASS** | 1.2–2.5 s to canvas; 8/8 modes reach `playing` |
| lifecycle | BUILT | **PASS** | 20 route changes: 20/20 loaded, 1 context, 0 errors |
| procedural | PASS | PASS | unchanged |
| tested | PASS | PASS | 1,670 assertions, 31 suites |
| canvas | SPECIFIED | **FAIL** | 26–33% of an iPhone in 8/8 modes |
| no_tpose | BUILT | **FAIL** | 77% of the mesh welded to the `Head` bone |
| prq | BUILT | **FAIL** | karate paid 39× dunk for a comparable run |
| a11y_audio | BUILT | **FAIL** | 0 `aria-live` regions in 4 modes |
| legibility | BUILT | **FAIL** | player is 5–9% of the screen |
| simulatable | BUILT | **FAIL** | 4 of 5 cash modes roll a gameplay decision |
| response | BUILT | UNKNOWN | needs a real GPU |
| framerate | BUILT | UNKNOWN | needs a real phone |
| fun | UNKNOWN | UNKNOWN | needs the founder |

**2 demonstrated → 4. Six measured broken. Three still unmeasurable.**

## BUILT was noise in both directions

M93 wrote that "BUILT reads like progress and means a player benefits in no way
at all." That was right, and it was worse than it sounded: **four BUILT
criteria are FAIL**, and **two things that were worried about are fine.**

Being wrong in both directions is the useful part. It means the register was
noise rather than a consistent optimism that could have been corrected for —
so the fix is not "discount BUILT by 30%", it is **stop scoring things you have
not measured.**

The two false alarms are worth naming, because both had batches built for them:

- **The WebGL context leak does not reproduce.** One context per route, zero
  lost, across six route changes — every route change is a full page load, so
  the browser tears it down. M81's engine-lifecycle work targets a defect this
  build's routing already prevents.
- **Boot is not a problem.** 1.2–2.5 s, and every mode reaches `playing`. It
  had been on the worry list since M74.

## What was actually wrong

Ranked by how much they explain:

**1. 77% of the character mesh is bound to the `Head` bone.** Hands weighted
`Head` at 0.78. Chest at 0.97. The upper body is a rigid lump welded to the
head; the arms cannot move whatever the skeleton does. This retires a question
open since M24 and it invalidates Phase 4's premise — **conformed mocap would
have produced a perfect walk cycle and changed nothing on screen.**

**2. The player is 5–9% of the screen.** Six of eight modes. A 1.72 m athlete,
60 pixels on a desktop and 19 on a phone. This is why I read the framing bug as
a rigging bug twice: at 60 pixels a 20° arm and a 90° arm are the same picture.
It also cancels M92 — a subject-anchored tell is about six pixels.

**3. The canvas is a 16:10 letterbox on a portrait phone.** One shared wrapper,
identical to the decimal in eight modes. Fixed and verified at 79.8%, not
deployed.

**4. PRQ is fed a raw per-mode score.** Karate counts in thousands, a dunk
contest in tens; a player optimising for PRQ should play karate and never dunk.

**5. Nothing is captioned.** Zero live regions. The accessibility work is not
missing — it is unplugged.

**6. Three board modes lose the player through the floor** with no input at all.

## The three bugs in my own work

Pass 2 found as many defects in pass 1's output as in the product:

| batch | bug | consequence |
|---|---|---|
| M94 | `tick()` fell back to `DEFAULT_CONFIG` | every non-average-PRQ match fails verification |
| M94 | stepped from a second `intent()` while `SimLoop` recorded the first | simulate one input, record another |
| M94 | no `captureHashes` | **every recorded replay is unverifiable while looking well-formed** |

All three are the same shape — runs, tests clean, does nothing — and the third
was only findable by building the *other end* and running a real match through
it. That is the strongest argument in this document for building both halves of
anything before believing either.

## What changed about how I work

The instrument that made pass 2 different is four lines:

```js
const realBind = Function.prototype.bind;
Function.prototype.bind = function (thisArg, ...rest) {
  if (thisArg?.scenes && thisArg.getRenderingCanvas) captured.push(thisArg);
  return realBind.call(this, thisArg, ...rest);
};
```

Babylon does not put its engine on `window`, but it binds its render loop to
itself. That hook gave access to scenes, skeletons, bone matrices, vertex
buffers and the camera — and everything in the "what was actually wrong" list
above came from it, or from watching the network.

**Four batches of diagnosis were wrong because a screenshot was the only
instrument available.** The lesson is not "measure more", it is *build the
instrument first*.

## What is left, and who can do it

| # | blocker | who |
|---|---|---|
| 1 | **Re-export the character with correct skin weights** | **Blender, on the Mini** |
| 2 | Ship M95 (canvas) and M96 (grounding) — no prerequisites | Abacus |
| 3 | Apply M99's four camera radii | Abacus |
| 4 | Enable the nexus flag — PRQ cannot move without it | Elijah/Abacus |
| 5 | Mount `<CaptionRegion />` | Abacus |
| 6 | Route four AI call sites through the seeded `Rng` | Abacus |
| 7 | Send `replay` alongside `score`; verify on Node | Abacus |
| 8 | **Play all 25 modes** | Elijah |

**Blocker 1 gates the most.** Nothing about how the game looks improves until
the mesh is bound to its skeleton — not the camera, not the tells, not mocap.

## Was pass 2 worth it?

Pass 1 produced 60,000 lines and 2 demonstrated criteria. Pass 2 produced about
1,500 lines and moved 2 more to PASS, found 6 measured failures including one
that had defeated six previous batches, and found 3 bugs in pass 1's own output.

The honest comparison is not lines. It is that **pass 1 could not have found
any of this**, because every check it had looked at the repo, and every problem
worth finding was in the product.

The right shape for pass 3 is neither: **fix the six known failures, ship them,
and re-measure.** Everything on the blocker list above is small, specified, and
has an acceptance test that anyone can run.
