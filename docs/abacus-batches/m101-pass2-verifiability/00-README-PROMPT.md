# M101 — Pass 2, Phase 8: which modes could actually carry prize money

**22 tests pass by execution. The verdicts come from hooking `Math.random`
before any page script and recording the stack of every call during play.**

---

## PHASE 8'S GATE, ANSWERED BY MEASUREMENT

The plan said *"`proveDeterministic` green on 8 modes"* — which is authoring
eight `SimulatableMode` implementations against a codebase I cannot see. That
is what pass 1 did wrong. The question underneath it is answerable directly:

> **Does the deployed mode make a random decision the server cannot reproduce?**

| mode | random calls | verdict | disqualifying site |
|---|--:|---|---|
| **dunk** | 2,412 | **VERIFIABLE** — cosmetic only | — |
| onevone | 2,246 | UNVERIFIABLE | `e4.decide < er.poll < es.poll` |
| threevthree | 3,028 | UNVERIFIABLE | `e4.decide < er.poll < es.poll` |
| tennis | 467 | UNVERIFIABLE | `<chunk>:149097 < Object.up` |
| karate-vs | 81,200 | UNVERIFIABLE | `tm.decide < Object.update` |

## `dunk` IS CLEAN, AND THAT CORRECTS ME

Over a **full 40-second contest**, every one of **24,558** `Math.random()`
calls resolved to Babylon's particle system:

```
12279  s < m0._update < m0.animate
12279  s < mS.startPositionFunction < m0._update
```

**Zero calls from game logic.** M94's README states that M63 rolled the rival
with `Math.random()` and that this is "the single call that made every dunk
contest unverifiable." **The deployed dunk contest does not do that.** I
carried that assumption from reading M63's source and never checked the build.

The flagship cash mode is closer to verifiable than anyone thought.

## THE OTHER FOUR ROLL A DECISION

`e4.decide < er.poll < es.poll` is an AI opponent deciding what to do, called
from an input-source poll — 107 times in `onevone`, 85 in `threevthree`. Tennis
rolls inside a **key-up handler**, so a shot's outcome depends on an
unreproducible number at the moment of release.

Each is one call site. The fix is the same shape every time: draw from M83's
seeded `Rng` and record the seed with the replay.

## THE RULE, AND THE THRESHOLD THAT GOT IT WRONG

`onevone` makes **107 AI-decision calls against 13,794 particle calls** — a
**0.9% share**. The first version of this probe used a 20% threshold and
**passed it**.

**One unreproducible decision invalidates the whole match.** Share is the wrong
metric, and a threshold would have cleared exactly the mode that fails. There
is a test asserting the 0.9% case is disqualifying.

### Three ways this probe was wrong before it was right

1. **Counting calls.** The first run reported *8 of 8 modes unverifiable* —
   and the top call site was `startPositionFunction`. Particles. That would
   have been a false alarm on every mode in the product.
2. **Classifying on one stack frame.** The immediate caller is a shared
   minified helper (`s` is Babylon's `RandomRange`); the frame above it
   identifies the subsystem.
3. **Sampling.** 1-in-97 sampling cannot find an AI roll that happens four
   times a match — which is precisely what is being looked for. The probe now
   captures **every** call up to 60,000, and a mode that needed sampling can
   only ever be reported `inconclusive`, never clean.

---

## FILES

| File | Goes where |
|---|---|
| `files/core/verifiability.ts` | `core/` |
| `files/tests/verifiability_test.ts` | `tests/` — 22 tests |
| `evidence/determinism.json` | reference only |

Repo tool: **`tools/determinism_probe.mjs`** — hooks `Math.random`, `Date.now`
and `performance.now` before any page script, arms only once play begins (load
and shader compilation use randomness legitimately), and records call sites.
**It reads and counts; it never substitutes a value** — a probe that returned
seeded randomness would make an unverifiable mode look verifiable.

## PREREQUISITES

None to run. The remediation points at `Rng` and `Replay` from M83.

## WIRING

For each named site:

```ts
// before
const choice = Math.random();
// after — the session Rng, recorded with the replay
const choice = kit.sim.rng.next();
```

Then re-run the probe. A mode reaching `cosmetic-only` on a **complete**
capture is the gate; anything `inconclusive` has not been cleared.

## ACCEPTANCE

1. `node tools/determinism_probe.mjs --play 40000` → `onevone`,
   `threevthree`, `tennis` and `karate-vs` report `cosmetic-only`.
2. `dunk` stays clean. It is clean today and it is the one to regress.
3. `karate-vs` needs a longer run or a quieter audio path to get a complete
   capture — 81,200 calls in 20 seconds forced sampling.

## LIMITS

- **Clean does not mean verifiable.** No `Math.random` is necessary, not
  sufficient. A mode also needs a seeded, recorded simulation
  (`SimulatableMode`, M91/M94) and server-side re-simulation. `dunk` clears
  this bar and is still not deployed against a verifier.
- **`Date.now`/`performance.now` were counted but not attributed.** `dunk`
  shows zero `Date.now` and 3,864 `performance.now` over a contest, which is
  consistent with a render loop and not with wall-clock-driven simulation —
  but that is inference, not proof.
- **Minified names.** `e4.decide` and `Object.up` are unambiguous enough to act
  on, and `<chunk>:8:149097` is not a filename anyone can open. Source maps
  would turn these into exact lines.
- **Five modes of twenty-five.** These were the plausible cash modes; the rest
  take about a minute each.
- **`karate-vs` is an incomplete capture.** Its 81,200 calls are dominated by
  an audio noise buffer, and it is flagged rather than trusted.
