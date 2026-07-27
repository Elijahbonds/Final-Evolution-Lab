# M88 — Phase 5 of 10: board sports

Depends on M83 (`Rng`), M84 (`ModeKit`).
**104 tests pass by execution.**

Not re-shipped: `boardCore` (M39), `rideWorlds`, `SkateRunMode`,
`SnowboardSlalomMode`, `SurfBreakMode` (M55).

---

## §1 — SKATE: a line you can lose

`boardCore.TrickMachine` has five tricks and a combo counter that increments on
each landing. Nothing links one trick to the next except that you happened to
land both, and **nothing is lost by stopping.**

So the optimal play is to find one high-value trick and repeat it in the safest
spot in the park. That's a score attack with extra steps.

`TrickLine.ts` makes a run a **line**:

- **Links** — grind, manual, transfer. They score modestly; their value is
  keeping a chain alive over ground where you'd otherwise touch down neutral.
- **The multiplier grows superlinearly**, so a six-trick line beats two
  three-trick lines. Capped at 8× so one line can't decide a run.
- **Repetition pays a fraction** — spamming one trick drops to 20%. The live
  combo counter rewards exactly what this now punishes.
- **Balance drains while you hold**, and drains *faster* deeper in a line. The
  pressure of a big line is modelled directly.
- **A bail loses everything banked.**

That last point is the whole design. A combo counter with no bail risk is a
number going up; a line you can lose is tension. Every extra trick becomes a
real decision, and `cashAdvice()` puts it on screen: *"800 banked — that next
trick lands 32% of the time."*

Balance correction is a **nudge, not a reset** — perfect correction would make
every line infinite.

---

## §2 — SNOWBOARD: speed from a line, not a button

`SnowboardSlalomMode` steers laterally and gates a boost. Turning is free — it
costs nothing and buys nothing — so the fastest line is a straight one with the
button held.

A board has a **sidecut**: its edges are arcs. Tip it on edge and it bends into
the snow and traces a circle:

> **R = sidecutRadius × cos(edgeAngle)**

Real geometry, not invented. An 11 m board at 45° carves 7.8 m; at 70° it
carves 3.8 m. You steer by choosing an edge angle and the turn shape follows.

The trade: a **carve** barely scrubs speed, a **skid** dumps it hard, and the
**fall line** is where the free speed is but also where gates get missed. So
the fast line is neither the straight one nor the safe one — finding it is a
skill rather than a button.

**One property fell out of the physics rather than being tuned in:** grip
saturates with edge angle while the radius keeps shrinking, so the speed limit
**peaks around 45°** and falls away either side. That happens to match the
"best carving angle" riders actually talk about. `edgeForRadius()` returns
`null` when a turn isn't carvable at your speed — telling a player "you're
going too fast for that line" is far more useful than letting them wash out and
wonder why.

### A third constant bug, same shape as the last two

The first model used an 8 m sidecut and capped grip at 1.4 g, giving carve
limits of **6–8 m/s (about 25 km/h)**. Every realistic riding speed was
therefore a **skid** — the carve state was unreachable and the entire mechanic
was dead while every function looked correct.

Recalibrated to a real 2.6 g peak grip and 11 m sidecut → limits land near
40 km/h. Asserted in tests in km/h so it can't drift back.

> **This is now three phases running.** Phase 3: reaction frames longer than
> the window they had to fit in. Phase 4: a court crossed in 0.83 s. Phase 5:
> a carve nobody could ever reach. **A merely-wrong constant produces a system
> that runs, tests clean at the unit level, and does nothing.** The only thing
> that catches it is asserting the *consequence* — "is this state reachable at
> a realistic input?" — not the value.

---

## §3 — SURF: the wave is the level

`rideWorlds.buildSurfBreak()` returns `waveLipAt(tSec)` — a lip travelling
shoreward **on a loop**. One wave. The same wave. Forever. Once you've learned
the loop there's nothing left, which is the opposite of the sport.

`WaveModel.ts` generates waves as a **sequence of sections** — shoulder,
pocket, barrel, section, closeout — that break in order as the wave moves along
the reef. A ride becomes a sequence of decisions: can I make that section, and
is the barrel worth being caught behind?

**Deterministic by seed.** Infinitely varied and perfectly reproducible —
which is what makes a surf ghost possible at all. Procedural and replayable are
usually in tension; seeding resolves it.

Three things the tests pin:

- **A wave must be rideable.** 300 waves across every quality: none opens on a
  closeout, all are multi-section. A generator that can produce an unplayable
  level hasn't finished being written.
- **A poor day has zero barrels; a good day has plenty.** That's what makes a
  good day *feel* like one. (An earlier version added a flat size bonus, so a
  big gutless wave still barrelled — caught by test.)
- **The pocket is a narrow ~3 m window** you actively hold, not a place you end
  up.

`generateSet()` gives five waves with a lull between, and the best one is
rarely the first — so letting a wave go is a real decision, which a single
looping wave cannot offer at all.

---

## FILES

| File | Goes where |
|---|---|
| `files/core/TrickLine.ts` | `core/` |
| `files/core/CarveModel.ts` | `core/` |
| `files/core/WaveModel.ts` | `core/` |
| `files/tests/board_test.ts` | `tests/` — 104 tests |

## PREREQUISITES

| Module | From | Used for |
|---|---|---|
| `Rng` | M83 | trick outcomes, wave generation |
| `ModeKit` | M84 | mode-side wiring |
| `boardCore` | M39 | rig, rider physics — **not re-shipped** |
| `rideWorlds` | M39 | park and slope geometry — **not re-shipped** |

## WIRING

**Skate.** Replace `TrickMachine`'s combo counter with a `LineState`. Call
`tickLine()` per fixed tick while holding, `recoverBalance()` otherwise,
`correctBalance()` from the stick. `hasBailed()` ends the line. Cash on landing
back to neutral. **Show the banked total and the multiplier live** — the
tension only exists if the player can see what's at stake.

**Snowboard.** Replace lateral steering with an edge-angle input (stick
deflection → 0–80°). Call `stepRide()` per fixed tick. Render `edge` state
distinctly — a carve and a skid must *look* different or the player can't learn
the difference. Use `gateSolution()` for a training overlay.

**Surf.** Replace `waveLipAt` with `generateSet(seed, 5, conditions)` and let
the player choose. `riderZone()` each tick for scoring, `canMakeSection()` for
the warning. **Show the section ahead and its timing** — the decision is only
fair if it's visible.

## ACCEPTANCE

1. Tests: **104 passed**.
2. Land a five-trick line, then bail on the sixth: you lose all of it, and the
   HUD said what you were risking.
3. Repeat one trick five times: the fifth scores ~20% of the first.
4. Hold a hard edge at speed: the board washes and you lose speed. Set the same
   edge earlier at lower speed: it carves and you keep it.
5. Ride the same seed twice: identical wave, identical sections.
6. Surf on `conditions = 0.1`: no barrels appear at all.

## LIMITS

- **Six clips do not exist:** `board_kickflip`, `board_heelflip`, `board_360`,
  `board_grind`, `board_manual`, plus `board_grab` (which does). M80's loader
  reports each missing and falls back to procedural. **Blender is now blocking
  five phases.**
- **The carve model is 2-D.** No terrain camber, no moguls, no edge-to-edge
  transition time. Transitions are where a lot of snowboarding's feel lives and
  this doesn't model them — `pump` is a stand-in, not the real thing.
- **`WaveModel` describes the wave, it does not render it.** Something has to
  build a mesh whose shape matches `sections[]`, or the player is reading a HUD
  instead of a wave. Same class of risk as Phase 4's pitch tells, and it is the
  highest-risk item here.
- **Golf, gymnastics and soccer remain untouched** from Phase 4.
- Not type-checked against the live source. `docs/ACCESS-SETUP.md`.
