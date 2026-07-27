# M82 — accessibility, and PRQ that a player can see

Wave 2 of `docs/BLUEPRINT.md`. Depends on M81 (`core/DDA.ts`).

**92 tests pass by execution** — 26 on the PRQ weight parity, 66 on
accessibility, captions and colour.

**One live bug is already fixed in this repo:** `backend/routers/games.py` has
been patched. See §1.

---

## §1 — THE SCORING BUG, AND IT WAS REAL

There were two PRQ mode-weight tables and they had silently diverged. **The
same session earned a different PRQ delta depending on which platform scored
it.**

| mode | `PRQScoring.swift` | `backend/routers/games.py` | gap |
|---|---|---|---|
| `skateboarding` | 1.05 | 1.0 | 5% |
| `snowboarding` | 1.05 | 1.0 | 5% |
| `court_carnival` | 1.15 | 0.9 | **28%** |
| `brain_brawl` | 1.1 | 0.8 | **37%** |
| `who_scene_it` | 1.1 | 0.7 | **57%** |
| `market_browse` | 0.0 | *absent → 1.0* | **a shop visit scored like a match** |

That last row is the worst one. The Module Library is a store. It was missing
from the backend table entirely, so it fell through to the 1.0 default and
browsing minted PRQ at the same rate as playing baseball.

**Nothing could have caught this.** There were two tables and no third thing to
check either against. `config/prqWeights.json` is that third thing, and
`tests/prq_weights_test.ts` **parses the real Swift and the real Python off
disk** and fails if either drifts. It is the only shape of test that would have
worked: two tables in two languages, months apart, with no test in either able
to see the other.

I converged on the Swift values and **patched `backend/routers/games.py` in
this repo.** Every change is an increase; nothing is nerfed. The cognitive
modes carry the Mental Resiliency thesis and 0.8/0.7 read as placeholders
nobody revisited. **If you disagree, edit `config/prqWeights.json` and the two
mirrors it names** — the test will tell you if you miss one.

---

## §2 — Accessibility, from nothing

Coverage across the whole product was **one line about text contrast** in a
distribution doc. No reduced motion, no remapping, no captions, no colourblind
support — in a product whose premise is athletic identity for everyone.

This lands in `core/`, read by `ModeHarness` and `InputBus`, so it applies once
across all 25 modes. Retrofitting it mode by mode later costs several times
more, and that cost only goes up.

**`core/a11y.ts`** — settings, persistence, and OS-preference detection.
Two decisions worth stating:

- **The assist slider is the same machinery as DDA.** `qteWindowScale` already
  widens timing windows when a player is losing. An accessibility assist widens
  them because the player asked. Same multiplier, different reason — built
  once, exposed twice. `finalWindow(base, ddaScale, settings)` composes them,
  so the two can never fight over the same number.
- **OS preferences are defaults, not locks.** `prefers-reduced-motion` seeds
  the setting; the player can still override it. Someone who turned it on
  system-wide for scrolling may still want camera shake in a dunk contest, and
  refusing them that is paternalism dressed as accessibility.

`noFlashing` is deliberately independent of `reducedMotion`: photosensitive
epilepsy is a seizure risk, motion sickness is not. Anything above 3 Hz is
blocked, hard-gated rather than scaled — it is the one setting where getting it
wrong can hurt somebody.

**`core/captions.ts`** — every gameplay-relevant sound gets a visual.
Dance and Music are literally unplayable without hearing; karate's parry cue,
the pitch tell and the shot-clock buzzer all carry information a player is
expected to act on.

The mechanism is the point: `playCued(play, caption, importance)` takes the
caption as a **required argument**. You cannot add a gameplay sound to this
codebase without saying what it means, because the compiler will not let you.
That is the only version of this that survives 25 modes and a deadline.

The queue caps at 3 and evicts by importance, not FIFO — **a plain queue would
drop the parry cue for crowd noise at the exact worst moment.** There is a test
for that.

**`core/palette.ts`** — the default success/failure pair is **blue/orange, not
red/green**. Red/green is the single worst available choice because it is
precisely the axis ~6% of men cannot separate. Changing it at the source costs
nothing and removes the problem for everyone instead of patching it per user.

But the palette is the smaller half. **`signalFor()` returns colour, glyph,
shape and label together** so a call site cannot take the colour and forget the
rest. Under high-contrast mode every signal is the same white — and the test
asserts glyph and shape still distinguish them, which is what proves colour was
never load-bearing.

---

## §3 — PRQ you can see

`ui/PrqMeter.tsx` puts PRQ on screen during play, with the line that matters:

> **ELITE · opponent reacts 0.22s faster**

Stated against a *neutral* player, not against zero, because that is a claim a
player can check against their own experience. Without that line the meter is
decoration and nobody ever learns that showing up rested changed the match.

`PrqBriefing` shows it on the READY gate, before the countdown — the moment
readiness should land, rather than in a post-match summary.

---

## FILES

| File | Goes where |
|---|---|
| `files/config/prqWeights.json` | repo root `config/` — **canonical** |
| `files/core/prqWeights.ts` | `core/` |
| `files/core/a11y.ts` | `core/` |
| `files/core/captions.ts` | `core/` |
| `files/core/palette.ts` | `core/` |
| `files/ui/AccessibilityPanel.tsx` | `ui/` or `components/` |
| `files/ui/PrqMeter.tsx` | `ui/` or `components/` |
| `files/tests/prq_weights_test.ts` | `tests/` — 26 tests |
| `files/tests/a11y_test.ts` | `tests/` — 66 tests |

**Backend:** already patched in this repo at `backend/routers/games.py`. If
your deployed backend is a different copy, replace `PRQ_MODE_WEIGHTS` with the
`weights` block from `config/prqWeights.json` — including `market_browse: 0.0`,
which is the row that stops a shop minting PRQ.

## WIRING

1. **Boot:** `a11y.load()` once at app start, then
   `captions.setEnabled(a11y.get().captions)`.
2. **Pause menu:** add `<AccessibilityPanel />`. Not a profile page — someone
   discovers they need the assist slider in the middle of the mode beating
   them.
3. **Timing windows:** every mode that has one calls
   `finalWindow(baseMs, dda.qteWindowScale(...), a11y.get())` instead of using
   its raw constant.
4. **Camera shake:** `shakeAmount(base)`. **Flashes:** gate on `allowFlash(hz)`.
5. **Sound:** replace bare `sound.play()` with `playCued(() => sound.play(),
   'BUZZER', 'critical')`. Call `captions.tick()` from the mode update loop and
   render `captions.visible()` in the HUD.
6. **Colour:** replace any hard-coded success/fail colour with
   `signalFor(sig, a11y.get().colorMode)` and render `glyph` and `shape`
   alongside it. **Rendering only `.color` reintroduces the bug.**
7. **HUD:** `<PrqMeter dda={dda} … />`, and `<PrqBriefing dda={dda} />` on the
   READY gate.
8. **InputBus:** pass `{ holdToToggle: a11y.get().holdToToggle, bindings:
   a11y.get().bindings }` — M81 already accepts both.

## ACCEPTANCE

1. `node --experimental-strip-types tests/prq_weights_test.ts` → **26 passed,
   0 failed**. If BACKEND PARITY fails, the backend patch was not applied.
2. `node --experimental-strip-types tests/a11y_test.ts` → **66 passed**.
3. Play `who_scene_it` and confirm the receipt now uses weight 1.1.
4. Browse the Module Library: **PRQ must not move.**
5. Turn on captions, play karate: every audio cue has a caption, never more
   than 3 at once, and the parry cue is never the one dropped.
6. Set assist to Full: timing windows visibly widen; the panel reads
   "A 100 ms window becomes 160 ms".
7. Set colour mode to high contrast: success and failure are both white and
   still distinguishable by glyph and shape.
8. Enable OS reduced-motion, reload: the setting is pre-checked, and can still
   be turned off.
9. Corrupt `localStorage['fel.a11y.v1']` to `{{{`: the game still boots.

## LIMITS

- **The two `.tsx` files are not tested and not type-checked** against the
  app's React version or its class names. They are structurally complete and
  cosmetically unstyled — the CSS class names are declared, not defined.
- **The parity test's Swift and Python parsing is regex-based.** It is exercised
  against the real files and passes, but a large refactor of either table's
  formatting could make it silently find nothing. It asserts a minimum entry
  count to catch that, which is a guard rather than a guarantee.
- I **cannot confirm `backend/routers/games.py` in this repo is what your
  deployed backend runs.** That is open question 3 in `docs/BLUEPRINT.md` §9.
  If it is a different copy, the patch has to be applied there too — and until
  it is, the divergence persists in the direction that matters.
- Screen-reader coverage of menus, the one-handed touch layout, and the
  200% OS text-size path are **specified but not built**. They need the real
  component tree.
