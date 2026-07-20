# M43 — CONSOLE DEPTH & SOUND PASS
### Closes the silence gap and gives every mode the one mechanic real console games in its genre lean on.

Copy this into Abacus with every file in `files/` plus the updated
`KNOWN-ERRORS.md`. **Prerequisite: M42 must already be deployed** — this
batch imports `clipRegistry`, `CameraDirector`, `GroundRide`, `rideWorlds`,
and `aimSwingCore` from M42 unchanged; it does not re-ship them.

---

## PROMPT FOR ABACUS

### WHY THIS BATCH EXISTS
Two things were checked directly on the live build, beyond the M42 audit:
1. **Audio: confirmed zero.** No `<audio>` or `<video>` elements on the page,
   no audio network requests, on any mode. The game has never made a sound.
   Every real console game — sports or fighting — uses audio as primary
   feedback (impact, crowd, score); silence is one of the biggest tells that
   something is "a tech demo" rather than "a game."
2. **Depth: every mode is a single mechanical loop with no escalation.**
   Karate tracks a chi meter that does nothing. Dunk has no reason to chain
   makes. Football's evasions don't compound. Board sports bank a combo the
   instant you touch down. Precision sports treat every round identically,
   win or lose. Real console games in each of these genres (fighting games'
   super meters, NBA Jam's heat mechanic, Madden's breakaway runs, Tony
   Hawk's manual, any sports game's final-round stakes) all have this kind of
   escalation — it's a large part of what makes them feel like games and not
   demos.

This batch fixes both at once, because they compound: a made shot with a
rising chime AND a growing streak multiplier reads completely differently
than a made shot with silence and a flat "+1.5".

### FILES
| File | What it does |
|---|---|
| `files/audio/SoundKit.ts` | **New.** A complete sound system with ZERO external audio files — every sound (whoosh, impact, score chime, miss buzz, whistle, UI tick, crowd cheer/groan, power-up jingle) and the ambient crowd/wind bed is synthesized live with the Web Audio API, the same "procedural, no assets" approach the venues already use for visuals. `unlock()` on first input (autoplay-policy safe), `setEnabled()` for a future mute toggle. |
| `files/core/gameFeel.ts` | v2. One change from M37: `impact()` (the shared hit-stop+shake+haptic bundle every mode already calls) now also plays a sound — every mode gets audio feedback on impacts for free. |
| `files/modes/KarateEndlessMode.ts` | v4. **CHI FINISHER**: at full chi, the HEAVY input becomes a screen-shaking special that hits every nearby enemy and resets the meter — the payoff the meter never had. Dojo ambient bed, whoosh/impact/crowd cheer throughout. |
| `files/modes/DunkMode.ts` | v2.3. **HOT STREAK**: consecutive makes build a scoring multiplier (up to 2×) and crowd energy; a miss resets it instantly. Rising-pitch score chime, crowd cheer at 3+ streak, stadium ambient bed. |
| `files/modes/FootballRushMode.ts` | v4. **BREAKAWAY**: 3 evasions in one drive without a tackle grants a temporary speed boost and a 2×/1.5× score multiplier on the next evade/score. Whoosh on jukes, impact on tackles, crowd cheer on touchdowns. |
| `files/modes/boardCore.ts` | v3. **MANUAL**: landing a trick opens a 1.4s window to start another before the combo banks — chains grow across multiple separate airs, not just one, the same tension Tony Hawk's manual creates. Rising-pitch landing chime, tick as the window closes. |
| `files/modes/SkateRunMode.ts`, `SnowboardSlalomMode.ts`, `SurfBreakMode.ts` | v4. Sound wiring for pops/grinds/gates/cutbacks/wipeouts + venue-appropriate ambient beds (crowd for park/wave, quiet wind for the mountain). |
| `files/modes/precisionModes.ts` | v4. **CLUTCH**: the final round/shot/pitch/kick of every precision mode is flagged as pressure — succeeding on it pays 1.5× with a distinct "CLUTCH!" banner and sound. Swing whoosh, make/goal chime, miss/save buzz, venue ambient beds. |
| `KNOWN-ERRORS.md` | Adds E21 (the audio gap) to the regression ledger. |

### WIRING
1. Drop every file in — each REPLACES its M42 predecessor by filename.
2. **Audio unlock**: every mode file in this batch already calls
   `SoundKit.unlock()` on its first `onInput` — no separate harness wiring
   needed, but if any OTHER mode/screen plays sound before first input, add
   one `SoundKit.unlock()` call to its earliest input handler too.
3. No new `ModeContext` fields — this batch only uses what M37–M42 already
   added (`heroRef`, `objectiveRef`, `groundLock`, `feel`).
4. Run the KNOWN-ERRORS regression sweep (now includes E21).

### HONEST SCOPE NOTE
"Compete with console emulator gameplay" is a large, ongoing target — this
batch is a real, concrete step (sound where there was none; a genre-
appropriate depth mechanic in every mode), not a claim that any mode now
matches a specific beloved console game beat for beat. The two biggest
remaining levers, in order of impact, are still: (1) the content gap
`KNOWN-ERRORS.md` already flags — real sport-specific animation clips instead
of the fighter-rig aliases — and (2) real composed music/licensed or
custom-recorded SFX layered on top of (not replacing) this synthesized system
once the budget/pipeline exists for it. Both are natural next investments,
not blockers to shipping this batch.

## ACCEPTANCE
1. **Sound sweep, all 10 modes**: within the first 10 seconds of play, each
   mode produces audible feedback on its core action (swing/strike/pop/
   charge) with no console errors from the audio system.
2. **Karate**: land hits until chi hits 100, HUD reads "FINISHER READY,"
   HEAVY triggers a multi-enemy special with screen shake + crowd cheer, chi
   resets to 0.
3. **Dunk**: 3 makes in a row shows a streak banner and an audibly rising
   score chime; the next miss silently resets it back to no streak.
4. **Football**: string 3 evasions in one drive without a tackle → BREAKAWAY
   banner, speed visibly increases, next score/evade pays extra.
5. **Any board sport**: land a trick, immediately start another within ~1
   second — combo keeps growing across both airs instead of banking after
   the first landing; wait past the window (or bail) and it banks/resets.
6. **Any precision sport**: reach the final round/shot/kick — hint text
   flags it, and a success pays visibly more with a "CLUTCH" banner.
