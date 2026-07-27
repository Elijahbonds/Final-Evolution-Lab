# M93 — Phase 10 of 10: certification

Depends on M92 (`Legibility`). **45 tests pass by execution.**

---

## THE NUMBER, AND WHAT IT IS NOT

```
$ node tools/certify.mjs

  test suites     21/21 green
  assertions      1308 passed, 0 failed
  batch gate      clean
  agent protocol  intact
```

**1,308 passing assertions across ten phases. Zero modes shippable.**

Both of those are true, and a certification pass that reported the first
without the second would be actively misleading. So a criterion here has four
states, not two:

| | |
|---|---|
| **PASS** | demonstrated, with evidence anyone can re-run |
| **BUILT** | the code exists and is tested — **nothing has integrated it** |
| **SPECIFIED** | the design exists, the code does not |
| **UNKNOWN** | nobody has checked |

**Only PASS counts.** A test asserts that a mode with all twelve criteria at
BUILT is *not* shippable and scores **zero**, and that the summary refuses to
flatter: *"BUILT is not a soft PASS."*

That's the whole design of the file. `BUILT` reads like progress and means a
player benefits in no way at all.

## Where the product actually is

`baselineToday()` is deliberately pessimistic and deliberately uniform — the
shared layers from M81–M92 are BUILT for every mode because they're the *same
code*, and none has been observed running:

| criterion | state | why |
|---|---|---|
| procedural | **PASS** | always been true |
| tested | **PASS** | 1,308 assertions |
| response, framerate, no_tpose, a11y×2, prq, lifecycle | BUILT | written, tested, unintegrated |
| canvas | SPECIFIED | CSS written, container chain unverified |
| boot, fun | UNKNOWN | nobody has measured or played it |

**2 of 12.** That's the honest score, and it's the baseline the next pass gets
measured against. If it's wrong it's wrong in the direction of *understating*
progress, which is the safe direction for a document that decides what ships.

## Legibility is a gate

A mode with every criterion PASSED but zero tells drawn is **not shippable** —
its mechanics are unreachable however green the tests are. There's a test.

## The output that actually matters

`certifyFleet()` ranks blockers by **how many modes they hold back**, and
`leverage()` separates shared-layer work from per-mode work.

> If one criterion blocks 23 modes, that's one piece of work worth more than
> any per-mode effort. **Confusing shared work with per-mode work is how a
> roadmap spends a month on the wrong thing.**

Across the fleet today, every top blocker is shared. Integrating `ModeKit`
once moves nine criteria on twenty-five modes. That is the entire finding of
Phase 10.

---

## FILES

| File | Goes where |
|---|---|
| `files/core/Certification.ts` | `core/` |
| `files/tests/certification_test.ts` | `tests/` — 45 tests |

Repo tool: `tools/certify.mjs` — runs every suite and the batch gate, prints
what is proven **and what is not**, writes `artifacts/certification.json`.

## PREREQUISITES

| Module | From | Used for |
|---|---|---|
| `Legibility` | M92 | `loadBearingTells()` for the legibility gate |

## WIRING

1. `node tools/certify.mjs` in CI. It exits 1 on any failing suite or batch
   error.
2. As each criterion is genuinely demonstrated, move it from BUILT to PASS —
   **with the evidence artifact attached.** A state change with no evidence is
   how BUILT becomes PASS by wishful thinking.
3. Pair it with `node tools/integration_audit.mjs` against the live build. That
   is the other half and it is the harder one.

## ACCEPTANCE

1. `node tools/certify.mjs` → 21/21 suites, 1308 assertions, gate clean.
2. `certifyFleet` on today's baseline → **0 shippable**, and the top blocker is
   shared.
3. Nothing reports PASS without an evidence artifact.

## LIMITS

- **This measures the repo, not the product.** Everything it proves is about
  logic. `integration_audit.mjs` measures the deployed app and needs a session
  cookie nobody has captured yet.
- **`baselineToday()` is my judgement, not measurement.** Every BUILT could be
  a FAIL — nobody has looked.
- **No mode has been certified individually** because no mode has been
  integrated. Per-mode differences only appear after integration.
