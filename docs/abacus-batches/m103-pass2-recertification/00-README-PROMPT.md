# M103 — Pass 2, Phase 10: the honest scorecard, re-measured

**30 tests pass by execution.** Read `docs/PASS-2-RESULTS.md` alongside this —
it is the full closing assessment.

---

## WHAT PASS 1 GUESSED, AGAINST WHAT PASS 2 MEASURED

| criterion | pass 1 | pass 2 | measured |
|---|---|---|---|
| boot | UNKNOWN | **PASS** | 1.2–2.5 s; 8/8 modes reach `playing` |
| lifecycle | BUILT | **PASS** | 20 route changes, 1 context, 0 errors |
| procedural | PASS | PASS | unchanged |
| tested | PASS | PASS | 1,670 assertions |
| canvas | SPECIFIED | **FAIL** | 26–33% of an iPhone, 8/8 modes |
| no_tpose | BUILT | **FAIL** | 77% of the mesh welded to `Head` |
| prq | BUILT | **FAIL** | karate paid 39× dunk |
| a11y_audio | BUILT | **FAIL** | 0 `aria-live` regions |
| legibility | BUILT | **FAIL** | player is 5–9% of screen |
| simulatable | BUILT | **FAIL** | 4 of 5 cash modes roll a decision |
| response | BUILT | UNKNOWN | needs a real GPU |
| framerate | BUILT | UNKNOWN | needs a real phone |
| fun | UNKNOWN | UNKNOWN | needs the founder |

**2 demonstrated → 4. Six measured broken. Three still unmeasurable.**

## THE FINDING: BUILT WAS NOISE IN BOTH DIRECTIONS

M93 wrote that *"BUILT reads like progress and means a player benefits in no
way at all."* That was right, and worse than it sounded: **four BUILT criteria
are FAIL.**

But **two things that were worried about are fine** — `boot` and `lifecycle`,
both of which had batches built for them. Being wrong in both directions is the
useful part: the register was **noise, not a consistent optimism that could be
corrected for.** The fix is not "discount BUILT by 30%", it is *stop scoring
things you have not measured.*

There is a test asserting both columns are non-empty, because a scorecard that
only ever moved one way would be a scorecard measuring its author's mood.

## EVERY CLAIM CARRIES A NUMBER AND A BATCH

Each entry names the evidence and the batch that produced it, so any line can
be re-run. Tests assert:

- every criterion has evidence longer than a sentence fragment;
- every PASS and FAIL contains a **number** — with exactly one exemption,
  `procedural`, which is a design property with nothing to count, and the test
  asserts it is the *only* exemption;
- nothing is PASS without a source, and the one entry with no source is the one
  nobody has measured.

`baselineToday()` in M93 was explicitly "my judgement, not measurement".
`MEASURED` here is the opposite, and the type system does not distinguish them
— so the tests do.

---

## FILES

| File | Goes where |
|---|---|
| `files/core/CertificationPass2.ts` | `core/` |
| `files/tests/certification_pass2_test.ts` | `tests/` — 30 tests |

Repo doc: **`docs/PASS-2-RESULTS.md`** — the closing assessment, including the
three bugs pass 2 found in pass 1's own output and the instrument that made the
difference.

## PREREQUISITES

| Module | From | Used for |
|---|---|---|
| `Certification` | M93 | `CriterionState`, so both passes score on one scale |

## WIRING

This is a record, not a runtime dependency. Put it in CI next to
`tools/certify.mjs` so a criterion cannot be promoted without evidence, and
update it when something is measured — **not when something is built.**

## ACCEPTANCE

1. `node tools/certify.mjs` → 32/32 suites green.
2. Every criterion promoted to PASS in a future pass carries a number and a
   batch id, and the tests here enforce it.

## LIMITS

- **This scores the fleet, not a mode.** Per-mode certification still needs a
  mode to have been integrated, and none has.
- **Six criteria are FAIL with fixes already written and not deployed** —
  canvas (M95), grounding (M96), camera (M99), captions (M100), verification
  (M102). FAIL here means *measured in the product*, and shipping the batches
  is what changes it.
- **`fun` is still UNKNOWN and it is the one that decides everything.** Nobody
  but the founder can score it, and he has not played it since the camera and
  skin-weight findings — both of which change what he would be looking at.
