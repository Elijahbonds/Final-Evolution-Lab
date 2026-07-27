# M100 — Pass 2, Phase 7: PRQ is fed an arbitrary number, and nothing is captioned

**28 tests pass by execution. Both findings come from watching the deployed app
play a session and reading what it sent.**

Phase 7 is the one part of the plan **not** blocked by the skin weights (M98).
PRQ and captions are HUD and audio, not character animation.

---

## FINDING 1: PRQ MEASURES WHICH MODE YOU PICKED

Two mediocre sessions on the deployed build:

| mode | score sent | XP | shards | PRQ Δ |
|---|--:|--:|--:|--:|
| `dunkContest` | **25** | 48 | 1 | **0.0** |
| `karateEndless` | **1250** | 1885 | 62 | **+0.5** |

Karate paid **39× the XP and 62× the shards**, and moved PRQ while the dunk
contest did not. Not because it was more of a workout — because **karate counts
in thousands and a dunk contest counts in tens.**

A dunk contest's theoretical maximum is **120** (M94's `DunkSim`: 2 rounds × 2
dunks × 3 judges × 10). A middling karate run scored 1250. Nothing anywhere
converts between the two.

**This is not a balance tweak.** PRQ is the product — the number the app is
named around, the input to difficulty, the reading a player is supposed to
trust. Feeding it a raw per-mode score means a player optimising for PRQ should
play karate and never dunk. That is a worse failure than the weight-table drift
M82 fixed, because the weights are at least applied to a quantity that means
something.

### And the number is client-supplied

Observed payloads, verbatim:

```
POST /api/sessions        {"mode":"dunkContest","score":25,"won":false,"duration":40}
POST /api/v1/wallet/earn  {...,"payload":{"score":25}}   →  granted 53 coins
```

The client states its own score and currency is minted from it. **I did not
test whether a forged value is accepted** — that would be an attack on
production, and the payload shape is enough to act on.

Normalising does not fix that. A normalised client-supplied number is still
client-supplied. What it does is make the ceiling checkable: `normalise()`
**clamps at 1**, so `score: 999999` is worth exactly the same as a perfect
game. That is the first step toward computing the reward instead of accepting
it.

### `scoreScale.ts` refuses to guess

Only **two** modes have a cited scale, and that is the honest count of modes
whose scoring anyone has established. Four of the six mode ids observed in the
wild have none, and `normalise()` **throws** for them rather than returning a
plausible number. Inventing a scale would recreate the exact defect: a figure
that looks authoritative and means nothing.

`karateEndless`'s entry says in its own `basis` field that it is a placeholder
needing a real high-score sample. There is a test asserting it says so.

### One more thing the traffic showed

`POST /api/nexus/session-result` → `{"ok":false,"reason":"nexus_disabled"}`.
The nexus pipeline is **switched off server-side**. That is very likely why
`[FEL-DDA]` has never appeared in any console log, and it is not something any
batch can fix — it is a deployment flag.

The `/api/sessions` response *does* carry a difficulty grade
(`{"key":"READY","speedMult":1,"hangBonus":0}`). **The server computes DDA and
no mode reads it.**

## FINDING 2: THERE ARE NO CAPTIONS. AT ALL.

Measured in `dunk`, `karate`, `onevone` and `tennis`:

| | |
|---|--:|
| `aria-live` regions | **0** |
| `role="status"` / `role="alert"` | **0** |
| `.sr-only` elements | **0** |

Zero, in every mode. M82 built `captions.cue()`. M94 wired `kit.sound()` so
every sound carries its caption. M92 gave all eleven tells a caption string.
**None of it can reach a player, because nothing renders it.**

`CaptionRegion.tsx` is about forty lines and it is the entire gap. **The
accessibility work in this project is not missing — it is unplugged.**

Three things in it that are easy to get wrong and silently useless:

1. **Only `critical` cues are `assertive`.** Assertive interrupts the screen
   reader mid-sentence; using it for routine feedback makes the game unusable.
2. **The regions are always mounted.** A live region created in the same tick
   as its text is not announced by most screen readers.
3. **`slice(0, maxLines)`, not `slice(-maxLines)`.** `CaptionBus.visible()`
   returns critical first, so taking the tail drops exactly the cues a player
   must act on. My first draft had this backwards.

---

## FILES

| File | Goes where |
|---|---|
| `files/core/scoreScale.ts` | `core/` |
| `files/ui/CaptionRegion.tsx` | `ui/` |
| `files/tests/score_scale_test.ts` | `tests/` — 28 tests |
| `evidence/net.json` | the captured traffic |

## PREREQUISITES

| Module | From | Used for |
|---|---|---|
| `captions` | M82 | the bus `CaptionRegion` renders |
| `prqWeights` | M82 | the weight `sessionValue()` applies after normalising |

## WIRING

1. **Mount `<CaptionRegion />` once**, inside the game surface, above the
   canvas. It is always-on; it renders nothing when there are no cues.
2. Add `SR_ONLY_CSS` to the global stylesheet if Tailwind's `sr-only` is not
   available. Getting `sr-only` wrong looks identical to getting it right.
3. **Normalise before rewarding.** Wherever `score` reaches PRQ or the wallet:
   ```ts
   const value = sessionValue(mode, rawScore, prqWeight(mode));
   ```
   Let it throw on an unscaled mode in development. In production, gate on
   `isScaled(mode)` and pay nothing rather than paying an arbitrary amount.
4. **Read the grade the server already returns.** `/api/sessions` responds with
   `speedMult` and `hangBonus`. Nothing consumes them.

## ACCEPTANCE

1. A screen reader announces scoring cues; `document.querySelectorAll('[aria-live]').length` is 2, not 0.
2. A dunk contest and a karate run of comparable quality produce PRQ deltas
   within a factor of two. They currently differ by 50×.
3. `[FEL-DDA]` appears on boot — **requires the nexus flag to be enabled
   server-side first.**

## LIMITS

- **`karateEndless: 4000` is a placeholder.** I have one sample: a mediocre
  106-second run scoring 1250. A real scale needs real high scores, and the
  field says so.
- **Twenty-three modes still have no scale.** They will throw. That is the
  intended behaviour and it means this cannot ship to production until either
  the scales exist or the caller gates on `isScaled`.
- **`CaptionRegion` has not been rendered.** React does not run in this test
  harness, so it is checked against its own source the way M94 checks the dunk
  renderer. The `sr-only` technique and the live-region semantics are
  standards-correct; whether a real screen reader announces them on this app
  has not been observed.
- **Normalising does not make the score trustworthy.** The client still states
  it. Server-side computation is M91's `verifyMatch`, which needs a mode
  implementing `SimulatableMode` — `dunk` does, since M94, and it is not
  deployed.
- **`nexus_disabled` is a deployment flag I cannot see or change.** Everything
  about PRQ actually moving depends on it.
