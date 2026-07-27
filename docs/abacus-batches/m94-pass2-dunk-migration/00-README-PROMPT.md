# M94 — Pass 2, Phase 1: `dunk` migrated end to end

Depends on M63 (the mode being replaced), M83, M84, M85, M91, M92.
**92 tests pass by execution.**

This is the first batch in fourteen that integrates instead of authors.

---

## WHAT THIS IS

Pass 1 built `ModeKit`, `SimulatableMode`, `DunkTiers`, `Legibility` and
twenty more modules, and integrated **none** of them. `docs/GAP-AND-PASS-2.md`
called that the defining property of the work: 1,353 passing assertions, zero
modes shippable.

M94 is one mode through all of it, and it exists to answer one question before
anything else is built on those contracts:

> **Does the shape work?**

If it doesn't, that costs one mode instead of twenty-five.

## THE ANSWER: MOSTLY, WITH TWO CORRECTIONS

M63's `modes/DunkMode.ts` is 521 lines with the phase machine, charge, QTE,
judging, scoring, meshes, camera cuts and HUD interleaved. Nothing in it could
be tested, replayed, ghosted or verified, because reading a score required a
`Scene`. It becomes two files:

| | lines | code lines | what it owns |
|---|--:|--:|---|
| M63 `DunkMode.ts` | 521 | **427** | everything, untestable |
| `dunk/DunkSim.ts` | 404 | 240 | what the game **is** — pure |
| `dunk/DunkMode.ts` | 304 | 188 | what it **looks like** |
| | | **428** | |

**427 code lines became 428.** M84's gate was "if it isn't a net line
reduction, the kit has the wrong shape." It is a net *wash* — and the same
volume of code now also carries deterministic ticks, seeded rivals, ghost
recording, server-side verification, PRQ-scaled judging, an accessible QTE
window, vertical-gated dunk tiers and two drawn tells. **None of those existed
in the 427.**

So: the kit does not pay for itself in lines. It pays for itself in what the
lines can now do. Adopting it costs **18 lines** in the render half — M84
promised ~20, and there is a test that counts them.

## THE TWO CORRECTIONS

**1. `MIGRATION_MARKERS` is wrong as a flat list.** M84 published five markers
every integrated mode must show. `kit.move` does not apply to a dunk contest —
there is no locomotion; the approach phase selects a style. Calling it anyway
to turn a checklist green is exactly the `CameraStandoff` failure: a marker
present in the source, doing nothing, for six batches. The exemption is
**declared in the test with a reason** instead. M84 needs per-mode
applicability. Not fixed here — pass 2 forbids restructuring a subsystem
mid-phase.

**2. The QTE window was not reaching the accessibility assist.** M63 kept it
as a raw constant, and so did the first draft of the sim. An assist player got
the same 4-frame window as everyone else, which is M82's entire argument
failing at the mode boundary. It now goes through `kit.window()` — once, at
load, into `DunkConfig.qteWindowScale`.

That last detail is load-bearing. **The scale is config, not a call-site
multiplier**, because `SimulatableMode.tick` takes no config: a window that
varied with a setting the replay never captured would desync on the server for
exactly the players who need the assist. As config it is recorded, replayed and
verifiable. Accessibility and prize money stop being in tension.

## THREE BUGS THE MIGRATION CAUGHT

Each one runs, unit-tests clean, and does nothing — the shape pass 1 kept
producing.

| bug | consequence if shipped |
|---|---|
| `tick()` fell back to `DEFAULT_CONFIG` while `init()` accepted one | every match at a non-default PRQ fails verification — **only for players whose readiness isn't exactly average** |
| the tick stepped from a second `intent()` call while `SimLoop` recorded the first | simulate one input, record another — the M91 shape, Cash Arena rejects honest players |
| the drawn QTE window ignored the assist scale that scored it | teaches a timing that loses, and misleads assist players specifically |

The first two are the same failure as M91's quantisation bug, found twice more
in one file. The pattern is worth naming: **anything the simulation reads that
the replay does not carry will reject the honest player.**

## SCORING PARITY IS DELIBERATE

The three judges, their weights, the 6–10 clamp, `CHAIN_THRESHOLD = 24` and
the 0.8 freshness rule are copied **exactly** from M63, and the test recomputes
M63's formula independently and compares. A migration that also changes balance
is two changes wearing one commit, and when the scores come out different
nobody can tell which half did it.

Two things did change, both additive and both off at their defaults:
`judgeStrictness` (1.0 = exactly M63) and M85's `scoreCeiling`, which is where
the player's **real vertical** finally enters the score.

And one thing was fixed: M63 rolled the rival with `Math.random()`. That single
call is why no dunk contest could ever be verified for the Cash Arena it was
built for. It is now seeded.

---

## FILES

| File | Goes where |
|---|---|
| `files/modes/dunk/DunkSim.ts` | `modes/dunk/` — **new** |
| `files/modes/dunk/DunkMode.ts` | `modes/dunk/` — **replaces `modes/DunkMode.ts`** |
| `files/tests/dunk_migration_test.ts` | `tests/` — 92 tests |

**Delete `modes/DunkMode.ts` after routing `dunk` to `modes/dunk/DunkMode.ts`.**
Leaving both is how two copies of the scoring rules drift apart, which is the
bug M82 spent a batch fixing in the PRQ weight tables.

## PREREQUISITES

| Module | From | Used for |
|---|---|---|
| `ModeKit` | M84 | the whole adoption |
| `Rng`, `FixedStep`, `Replay`, `SimLoop` | M83 | determinism, ghosts |
| `DunkTiers` | M85 | `availableDunks`, `scoreCeiling`, `rimClearanceCm` |
| `HeadlessSim` | M91 | `SimulatableMode`, `proveDeterministic`, `verifyMatch` |
| `Legibility` | M92 | the two tells |
| `PlayerSlot` | M48/M50 | `Intent` |

`ModeHarness` must be the M81 version — `runMode()` synchronous, `ModeContext`
carrying `onDispose` and `cancelled()`.

## WIRING

1. Route `dunk` to the new `modes/dunk/DunkMode.ts` (`core/modeRoutes.ts`).
2. **`PlayerSlot.LocalInputSource` must stop deriving `sprint` from stick
   magnitude.** Still true, still one line, still cancels most of M81.
3. Draw the two tells for real. `dunk_tier_reach` is a world-space torus at
   the athlete's actual reach; the code is here but nobody has seen it render.
4. Run `node tools/integration_audit.mjs` against the deployed build **after**.
   That is the artifact this phase is missing and it is the one that counts.

## ACCEPTANCE

1. The test runs green — 92 assertions, including 5 independent recomputations
   of M63's judging formula.
2. `proveDeterministic(DunkSim, …)` green: a full contest replays identically.
3. `verifyMatch` accepts a real dunk run and rejects the same replay with an
   inflated score, **naming the score rather than reporting a desync.**
4. The sim source contains no `@babylonjs`, no `Math.random`, no wall clock,
   no DOM. Asserted against the file text, because that text is what makes a
   match verifiable.

## LIMITS

- **The render half has not been executed.** Babylon does not run in the test
  harness and the app source is still not in this repo. Everything below the
  sim boundary is tested by execution; everything above it is reviewed code,
  checked against its own source text the way `integration_audit.mjs` checks
  the deployed bundle. That is a weaker test, and it is the strongest one
  available until `nextjs_space/` lands.
- **Import paths are guesses.** `CharacterLibrary`, `ballRig`, `SoundKit`,
  `clipRegistry` and `modeConfigs` are imported at the paths M63 used. If the
  live tree differs, these are the lines to fix, and they are all at the top.
- **Phase 1's stated gate was `nextjs_space/` in the repo, `dunk` on
  `ModeKit`, and a real `tsc`.** One of three. The sync has not happened, so
  no `tsc` has run. This is the half that was mine to do.
- **`SPORT_CLIP.dunkPower` / `dunkFlashy` / `dunkSignature` may not exist.**
  M63 referenced clip keys; whether they resolve depends on `conform_clips.sh`
  having been run, which it has not.
