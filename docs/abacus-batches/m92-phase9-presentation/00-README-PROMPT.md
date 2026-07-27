# M92 — Phase 9 of 10: presentation

Depends on M82 (`a11y`, `captions`, `palette`), M84 (`ModeKit`).
**79 tests pass by execution.**

Not re-shipped: `gameFeel` (M26), `PerfMonitor`, `EffectsKit`, `SoundKit`,
`LightRig`, `RenderPipeline`.

---

## §1 — THIS IS NOT A POLISH PASS. IT IS THE OTHER HALF OF SIX PHASES.

I flagged the same risk three times and did not fix it:

> **Phase 3** — *"the tip zone should be visible; a player cannot learn footsies
> from a mechanic they cannot see"*
> **Phase 4** — *"`recognitionAt()` returns a number; without something showing
> it the mode is GUESSING, not reading, which is strictly worse than the timing
> bar it replaces"*
> **Phase 5** — *"`WaveModel` describes a wave, it does not render one; the
> player reads a HUD instead of a wave"*

Every one shipped as **half a mechanic.** The model was right, tested, and
invisible. A defender that commits and can be baited is indistinguishable from
a random defender unless the commitment **reads**.

`Legibility.ts` specifies the missing half — eleven tells covering every
mechanic phases 2–8 added, declared as data so the question "what needs
drawing?" has an answer.

### Three properties enforced by test

**Every tell has a caption.** Silent to a deaf player is not shipped.

**No tell relies on colour alone.** Same argument M82 made about success/fail
icons, one level up. Outlines, markers and icons all carry a glyph.

**Spatial mechanics anchor to the world or the subject.** A defender's
commitment reads *on the defender*. **A HUD readout for a spatial mechanic is a
stat, not a tell** — and urgent tells are never in the HUD at all, because a
player watching their own character will miss them.

### The audit caught my own registry

`auditTell()` failed on first run: `prq_effect` shipped as an icon with **no
glyph** — colour-only. That's exactly the failure M82 spent a whole batch
arguing against, reappearing one level up in my own data. The audit has tests
proving it can fail, which is why it caught it.

---

## §2 — QUALITY MOVES, AND A TELL IS NEVER WHAT GETS SHED

`docs/BLUEPRINT.md` §7 requires 60fps held. FEL runs on everything from a
current flagship to a four-year-old Android, so quality has to adapt.

**The rule that makes this Phase 9 rather than a graphics setting:**

> A naive quality scaler kills particles, then post-processing, then "minor
> overlays" — and somewhere in that list is the ground marker showing which way
> the defender committed. The player's frame rate improves and **a mechanic
> silently disappears.** They don't experience lower graphics settings; they
> experience a game that became random.

That's the same failure this pass has found five times in different clothes —
something looks fine, runs fine, and quietly does nothing. Here it would be
self-inflicted, so `SHED_ORDER` is data, `assertSheddable()` **throws** on
anything protected, and a test asserts no tell id appears in the shed list.

Two design details:

- **Median, not mean.** A single 400 ms GC pause must not drop quality; a mean
  would be dragged straight over the threshold. There's a test.
- **Hysteresis and asymmetric cooldowns.** Shed quickly, restore cautiously —
  visible oscillation on a borderline device is worse than staying one notch
  low.

**Why drop quality rather than frames:** a dropped frame is a missed input. M81
set a 66 ms input-to-response budget; at 30fps two bad frames blow it. Every
mechanic in phases 2–8 assumes the player can react. **Frame rate is a gameplay
concern in this product, not a graphics one** — and `verdict` says so plainly
when a device can't cope, rather than leaving the player to conclude the game
is bad.

---

## §3 — THE a11y GATE `gameFeel` NEVER GOT

`core/gameFeel.ts` (M26) predates M82's accessibility layer:

```ts
kick(strength) { this.amp = Math.min(0.22, ...); }   // no a11y check
export function haptic(pattern) { navigator.vibrate?.(pattern); }
```

`Shaker.kick()` shakes the camera and `haptic()` vibrates the phone regardless
of what the player asked for. **`reducedMotion` is honoured by the HUD's CSS
and ignored by the thing that actually moves the camera** — which is the one
that makes people ill.

The gates wrap rather than replace, so it's a call-site change instead of a
rewrite of a file every mode depends on. And they're deliberately *not* blunt:

- **Reduced motion zeroes shake** — that's the mechanism that causes nausea.
- **It shortens hit-stop rather than removing it.** Hit-stop is a *pause*, not
  movement. Blanket-disabling everything under one flag is how accessibility
  settings end up feeling like a punishment.
- **Haptics toggle independently.** Some players want the shake and not the
  buzz.
- **Above 3 Hz a flash is a hard zero,** not a scale — the one presentation
  decision where being wrong can hurt somebody.

With *everything* turned off, `impactPlan` still returns hit-stop. **Something
still lands.** Accessibility should change how a hit reads, not delete it.

---

## FILES

| File | Goes where |
|---|---|
| `files/core/Legibility.ts` | `core/` |
| `files/core/AdaptiveQuality.ts` | `core/` |
| `files/tests/presentation_test.ts` | `tests/` — 79 tests |

## PREREQUISITES

| Module | From | Used for |
|---|---|---|
| `a11y` | M82 | the settings `FeelSettings` mirrors |
| `captions` | M82 | every tell's caption goes to the bus |
| `palette` | M82 | glyph + shape, never colour alone |
| `gameFeel` | M26 | the functions these gate — **not re-shipped** |
| `ModeKit` | M84 | mode-side wiring |

## WIRING

1. **Per mode, draw its `loadBearingTells()`.** This is the actual work of
   Phase 9 and it is art and shader work, not TypeScript. The registry says
   what and where; someone has to make it exist.
2. **Run `legibilityReport(modeId, implemented)` in CI.** A mode that fails is
   a mode whose depth is unreachable — that report is the honest measure of how
   much of phases 2–8 a player can actually use.
3. **Replace `gameFeel.impact()` with `impactPlan()`** and apply the returned
   plan. One call site per mode.
4. **Feed `QualityGovernor.sample(engine.getDeltaTime())`** each frame; apply
   `current.shed` to the render pipeline and `renderScale` via
   `engine.setHardwareScalingLevel`.
5. **Never add a tell to `SHED_ORDER`.** `assertSheddable` will throw, and the
   throw is the design.

## ACCEPTANCE

1. Tests: **79 passed**.
2. `legibilityReport` returns ready for every mode with mechanics.
3. On a throttled device: quality steps down, 60fps holds, **and every ground
   marker, outline and trail is still drawn.**
4. Turn on reduced motion: camera shake stops, hit-stop shortens, hits still
   land.
5. Turn on captions: every tell speaks.
6. Colour-blind mode: every tell is still distinguishable by glyph and shape.
7. A single 400 ms hitch does not change quality.

## LIMITS

- **Nothing here draws anything.** `Legibility` is a specification and the
  renderers do not exist. This closes the "nobody knows what to draw" gap, not
  the "someone has to draw it" one — and that second gap is the real remaining
  cost of phases 2–8.
- **`gameFeel.Shaker` accumulates into `camera.position`** rather than
  offsetting from a base each frame. If `CameraDirector` reassigns position
  every frame this is harmless; if it doesn't, the camera random-walks away
  over a session. I cannot tell which from here — **worth a look, stated as a
  suspicion rather than a finding.**
- **`QualityGovernor` doesn't know what each layer costs.** It sheds in a fixed
  order rather than by measured saving. Fine to start; a device where shadows
  are cheap and particles are expensive will shed the wrong thing first.
- **No audio work.** `SoundKit` exists and Phase 9's audio half — mix, ducking,
  spatialisation, the audio channel of every tell — is untouched.
- Not type-checked against the live source. `docs/ACCESS-SETUP.md`.
