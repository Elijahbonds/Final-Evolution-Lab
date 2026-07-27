# M89 — Phase 6 of 10: creative & cognitive

Depends on M84 (`ModeKit`), M76 (`CardBridge`).
**87 tests pass by execution.**

Not re-shipped: `QuizCore` (M78), `DanceCore` (M75), `ActingCore` (M78),
`IRLCore` (M78), `CardBridge` (M76), `applyArtCard` (M76 v2).

Those six cores are **finished code**. Phase 6 is not about writing more of
them — it's about the two things that make them matter.

---

## §1 — THE MRI HAS NEVER MEASURED ANYTHING

`backend/app/services/mri_engine.py` computes the Mental Resiliency Index:

```
MRI = 0.30·ARV + 0.45·ESI + 0.25·Pacing
```

graded VULNERABLE / ADAPTING / RESILIENT / UNBREAKABLE. Weights in
`constants.py`, grading in `formulas.py`, all three inputs typed in the session
receipt schema.

**Nothing produces ARV, ESI or Pacing.** The receipt schema defaults `arv` and
`esi` to **50**, and no mode overwrites them.

> **Every player has an MRI of about 50. Forever.**

Same shape as the PRQ bug in M82 — a formula, weights, grading thresholds and a
UI, all correct, all fed by a constant. The Mental Resiliency thesis is one of
the two things this product is actually about, and it has never measured
anything.

`MentalResilience.ts` is the source. Each number is measurable from a stream of
samples any mode already produces:

| | measures |
|---|---|
| **ARV** | how you perform *after* a setback. Tilt or reset. |
| **ESI** | does accuracy *hold* as load rises. |
| **Pacing** | do you sustain, or spike early and fade. |

All three are about performance **under changing conditions**, not performance.
That's what makes them resilience rather than skill — and why Brain Brawl
belongs in a fitness product at all. The interesting question isn't whether you
know the answer; it's whether you still know it on the ninth question with your
heart rate at 160.

### The ordering that makes it resilience

A test asserts that **60% throughout beats 95%-then-60%.** A resilience metric
measures the *drop*, not the level — even though the second player answered
more questions right. Same principle in ARV: it's measured against the player's
own form, so a weak player who holds their level beats a strong one who falls
apart.

### Two model corrections the tests forced

- **ARV's baseline was the whole session** — which includes the tilt it's
  trying to detect, so it dragged itself down. A badly tilting player scored
  46.7 instead of the ~0 the behaviour deserves. Now measured against the
  window *before* the mistake.
- **That still scored everyone 50** on any repeating pattern, because the
  before- and after-windows contained the same samples. The recovery window is
  now weighted 3:2:1 toward the first sample after the mistake — which is both
  what "recovery" means and what lets the metric discriminate at all.

Also: **a session with no failures scores 60, not 100.** No adversity is an
*untested* resilience, not a perfect one — otherwise an easy session mints an
UNBREAKABLE grade.

And `loadCurve()` matters more than it looks: **without escalation, ESI is 50
by construction.** A quiz that asks ten questions at one difficulty cannot
measure stability under load. There's a test asserting exactly that.

---

## §2 — WHAT YOU MAKE BECOMES WHAT YOU PLAY WITH

FEL has four creative modes. All four produce something. **None of it goes
anywhere.** `CardBridge` can mint a card and pay royalties; `applyArtCard` can
skin a venue; nothing connects "I made a track in Music" to "that track plays
in my dunk contest."

So the creative modes are a separate app that happens to share a login. That
connection is the difference between four minigames and an ecosystem — and it's
what makes Music matter to someone who came here to play basketball. *A track
you made scoring your own dunk run is a reason to open Music. A track that
lives in Music is not.*

### The rule that keeps it honest, enforced in code

**Equipping something you made must never make you better.** The moment
expression affects outcomes, players who don't create are punished and the
marketplace becomes pay-to-win.

`assertCosmetic()` walks a payload and **throws** on any gameplay field —
`speed`, `damage`, `multiplier`, `prq`, nested or not. That's deliberately a
throwing function rather than a style-guide note, because a review comment is
forgettable and this constraint has to survive a future feature that would very
much like to give a legendary track a 2% shot bonus.

Three smaller decisions:

- **A wrong equip throws** rather than silently doing nothing — which is
  exactly what `applyArtCard` did for months while looking for a mesh name no
  venue built.
- **`activeIn()` reports inactive slots** so a UI can explain why your court
  skin isn't showing in tennis, instead of looking broken.
- **`creationFrom()` returns the slot to equip into**, immediately. A player
  who has to find a loadout screen never discovers the loop exists.

`attributionFor()` credits **one hop only** — the author, nobody above them.
That keeps this a flat marketplace rather than a recruitment scheme, and it's
load-bearing legally, not just structurally.

---

## FILES

| File | Goes where |
|---|---|
| `files/core/MentalResilience.ts` | `core/` |
| `files/core/CreatorLoop.ts` | `core/` |
| `files/tests/creative_test.ts` | `tests/` — 87 tests |

## PREREQUISITES

| Module | From | Used for |
|---|---|---|
| `ModeKit` | M84 | mode-side wiring |
| `CardBridge` | M76 | minting cards, `royaltiesFor()` — **not re-shipped** |
| `QuizCore` | M78 | the quiz itself — **not re-shipped** |
| `FixedStep` | M83 | the tick that `PerfSample.tick` refers to |

## WIRING

1. **Every mode** gets a `ResilienceTracker`. One `record()` per meaningful
   moment — a quiz answer, a rally shot, a dodge, a pitch. It's deliberately
   mode-agnostic, which is what lets MRI be measured product-wide rather than
   only in quizzes.
2. **On session end**, spread `tracker.receiptFields()` into the session
   receipt. That is the one line that makes MRI stop being 50.
3. **Brain Brawl / Who Scene It:** drive question difficulty from
   `loadCurve(i, total)` and the answer timer from `timeAllowedMs()`. Without
   escalation ESI cannot read anything.
4. **Creative modes:** on completion call `creationFrom(modeId, userId, title,
   payload)` and offer `equipNow` **in that moment**.
5. **Every mode boot:** `activeIn(loadout, modeId, library)` → apply the
   soundtrack, skin, victory emote. Render `inactive` as an explanation.
6. **Route the six modes.** `dance`, `art`, `acting`, `irl`, `brain_brawl`,
   `who_scene_it` are still six strings in `core/modeRoutes.ts` (M79). This
   remains the cheapest quality win in the project.

## ACCEPTANCE

1. Tests: **87 passed**.
2. Play Brain Brawl badly early and well late: pacing rises, ESI reflects the
   drop, and the receipt no longer reports `arv: 50, esi: 50`.
3. The results screen names your *weakest* axis in a sentence you can act on.
4. Make a track in Music, accept the prompt, start a dunk contest: it plays.
5. Equip a court skin, start tennis: it doesn't apply, **and the UI says why.**
6. Attempt to publish a card whose payload contains `damage`: refused, with the
   reason.

## LIMITS

- **The 48 Brain Brawl questions are still unported** from
  `BrainBrawlQuestionBank.swift`. I parsed them successfully months ago; 8
  reference real companies and public figures. Factual trivia is legally
  distinct from asset or likeness use, but it's a brand decision and it's
  yours. Until they're ported, Brain Brawl has thin content and MRI has little
  to read.
- **`exertion` has no source.** ESI's heart-rate term is the part that most
  directly delivers the thesis, and nothing currently supplies it. It needs the
  HealthKit/band bridge — which exists on the Swift side and not on the web.
  **The web app can measure cognitive resilience but not yet the "under
  physical fatigue" half.**
- **IRL remains the highest-risk mode in the product** and is untouched here.
  `IRLCore` has 40 tests; what it lacks is the camera pipeline and a real
  calibration pass on real bodies.
- **`CreatorLoop` stores nothing.** The loadout and library need persistence
  and a server-side authority, which is Phase 7.
- Not type-checked against the live source. `docs/ACCESS-SETUP.md`.
