# M84 — Phase 1 of 10: the integration kit

**Plan:** `docs/TEN-PHASE-PLAN.md`. Depends on M81, M82, M83.
**41 tests pass by execution**, and — the part that matters — they test the
*wiring*, which nothing in this project ever has.

---

## Why Phase 1 is not "start on basketball"

I scanned the repo before planning. The numbers decided the shape of this:

| | |
|---|---|
| Batch code authored | **49,400 lines**, 84 batches |
| Mode files | 98 |
| Core modules | 42 |
| Lines I have watched execute in the real app | **0** |

**Authoring is not the bottleneck. Integration verification is.** And that is
not a theoretical worry:

> M69 shipped `groundSnap` and `CameraStandoff` in one batch. `groundSnap` runs
> in production. `CameraStandoff` shows no evidence of ever having run — no
> `[FEL-CAM]` line, camera still 0.75m from the hero in karate-vs against a
> 1.8m minimum. **Nobody knew for six batches.**

Nine more phases of authoring at that rate produces 100,000 unverified lines
instead of 50,000. So Phase 1 closes the loop instead of widening it.

---

## 1. `core/ModeKit.ts` — five subsystems, one object

M81–M83 shipped five things every mode needs: deterministic ticks, movement
that feels controlled, PRQ-driven difficulty, accessibility, captions. Wired by
hand that is **5 × 25 = 125 integrations**, and the evidence says a meaningful
share simply would not happen.

So the unit of integration is one object:

```ts
const kit = await ModeKit.create({ modeId: 'dunk', record: isRanked });

// render loop
kit.frame(engine.getDeltaTime() / 1000,
  (dt) => this.tick(dt),                 // dt is ALWAYS 1/60
  () => localSource.poll(0));            // recorded for the ghost

// movement
kit.move(intent, ctx.camDirector.yawDeg);
hero.position.addInPlace(new Vector3(kit.velocity(8).x, 0, kit.velocity(8).z));
hero.rotation.y = kit.facingRad;

// difficulty + assist, composed in one call
const windowMs = kit.window(100, score, aiScore, target);

// captioned audio
kit.sound(() => whistle.play(), 'WHISTLE', 'critical');

const replay = kit.finish(score, 'WIN');
```

That is the whole surface. Phases 2–6 write mode logic instead of re-wiring
five subsystems twenty-five times.

**`ModeKit` imports no Babylon.** It takes plain numbers and returns plain
numbers. That is not tidiness — it is what makes the integration layer itself
testable, and the integration layer is exactly where this project keeps losing
work. A wiring harness nobody can test is how you get a `CameraStandoff`.

### What the tests pin

- **The always-sprinting bug cannot come back.** Full stick with no sprint
  button walks at 0.45; there is an assertion.
- **Assist composes with DDA rather than replacing it** — exactly 1.6×, in the
  right order.
- **An accessibility change applies without restarting the mode.**
- **A guest, offline, still gets a match** at neutral difficulty.
- **Double-finish is a no-op** — a mode ending on both a timer and a score
  condition must not double-report.

---

## 2. `tools/integration_audit.mjs` — audit the deployed app

`verify_batch.mjs` proves a drop is well-formed. `smoke.mjs` proves a mode
loads and plays. **Neither can tell you whether the code inside that mode is
the code you shipped.**

This can, because every subsystem M80–M84 announces itself on the console. It
drives the live app with `?probe=1`, clears the start gate, plays, and reports:

```
┌─ SUBSYSTEM ─────────────────────────────────────────────────
│ M69  RUNNING     groundSnap
│              seen in: dunk, karate, onevone
│ M69  NO EVIDENCE CameraStandoff
│              → KNOWN NOT INTEGRATED as of 2026-07-26…
│ M83  NO EVIDENCE seeded RNG
│              → the match is unreplayable: no ghost can reproduce it
└─────────────────────────────────────────────────────────────
[AUDIT] dunk: WebGL contexts live=7 created=7 peak=7  ← LEAKING
```

**"NO EVIDENCE" is reported as absence of proof, never as "broken."** A mode
may not reach that code path. That distinction is not pedantry — reporting
absence as failure is precisely the mistake that had me declare six working
routes broken in M77.

It exits 0 even with absences. Gating on it would make it something people
route around rather than read.

---

## 3. `tools/fel_batch_alias.mjs` — no duplicate files

The test suite needs M81–M83's modules; the obvious move is to copy them into
this batch. **That is how the PRQ weight tables drifted** — two copies, months
apart, five modes disagreeing.

So instead the resolver flattens the batches the way the app will see them once
integrated, and the shipped source keeps the convention it will actually run
under. As a side effect the test suite proves the four batches **compose**,
which is the real claim of Phase 1.

---

## FILES

| File | Goes where |
|---|---|
| `files/core/ModeKit.ts` | `core/` |
| `files/tests/modekit_test.ts` | `tests/` — 41 tests |

Repo tools (not part of the Abacus drop): `tools/integration_audit.mjs`,
`tools/fel_batch_alias.mjs`, `docs/TEN-PHASE-PLAN.md`.

## PREREQUISITES

`ModeKit` is an adapter, so by definition it ships none of what it adapts.
Every module below comes from an earlier batch and **must already be
integrated** — the kit is the thinnest possible layer over them, which is the
point.

| Module | From | Provides |
|---|---|---|
| `SimLoop` | M83 | deterministic frame → fixed ticks |
| `FixedStep` | M83 | `FIXED_DT`, the 60 Hz clock |
| `Replay` | M83 | `ReplayData`, the ghost recording |
| `GhostSource` | M83 | recorded opponent (tests only) |
| `MotionModel` | M81 | movement, sprint, turn rate, coyote/buffer |
| `DDA` | M81 | PRQ → difficulty |
| `a11y` | M82 | assist, reduced motion, flash gate |
| `captions` | M82 | the caption bus |
| `prqWeights` | M82 | canonical mode weights |
| `PlayerSlot` | M48 | the `Intent` shape (type-only import) |

The two `../../../m8*/files/core/*.ts` imports in `tests/modekit_test.ts` reach
into the sibling batches **on purpose**. Copying those modules here would hand
Abacus two versions that then drift apart — which is exactly the bug M82 had to
fix in the PRQ weight tables. `tools/fel_batch_alias.mjs` does the flattening
instead, so the shipped source keeps the convention it will run under and the
test still proves all four batches compose.

## INTEGRATION ORDER

Strict. Later batches replace files from earlier ones.

1. **M80** — `anim/` additions. Nothing replaced.
2. **M81** — replaces `core/InputBus.ts` and `core/ModeHarness.ts`.
   **Breaking:** `runMode()` is no longer `async`.
   **Also required:** `PlayerSlot.LocalInputSource` must stop deriving `sprint`
   from stick magnitude, or most of M81 does nothing.
3. **M82** — additive, plus the backend `PRQ_MODE_WEIGHTS` replacement.
4. **M83** — additive.
5. **M84** — additive. Needs 1–4.

Then run the audit and tell me what it says. That single number — how many
subsystems are observably running — is worth more than the next phase of code.

## ACCEPTANCE

1. `node --experimental-strip-types --import ./tools/ts_resolve.mjs --import ./tools/fel_batch_alias.mjs docs/abacus-batches/m84-phase1-integration-kit/files/tests/modekit_test.ts`
   → **41 passed**.
2. Migrate ONE mode to `ModeKit` — `dunk` is the right first one. It should be
   a net *reduction* in lines. If it is not, the kit has the wrong shape and I
   want to know before phase 2 builds on it.
3. `node tools/integration_audit.mjs` against the live build. Expect several
   "NO EVIDENCE" rows until the batches land — that is the tool working, and
   the baseline everything after this is measured against.

## LIMITS

- **`ctx.camDirector.yawDeg` is still assumed to exist.** It is the input to
  camera-relative movement and I have never seen `CameraDirector`'s real
  interface. If the property has another name, `kit.move()` gets the wrong
  basis and movement stays world-relative — the single most important unknown
  in the whole migration.
- **The audit's markers assume my own console strings ship unchanged.** If
  Abacus rewrites a log line, the audit reports a false absence. That is the
  right failure direction, but it is a failure.
- **No mode is migrated.** Phase 1 is the kit, not its adoption. Until one mode
  proves the shape, phases 2–6 are planned against an untested API.
- Still not type-checked against the live source. `docs/ACCESS-SETUP.md`.
