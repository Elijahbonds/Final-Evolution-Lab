# M42 — ANIMATION RELIABILITY & STABILITY PASS
### The single highest-leverage fix available: characters stop T-posing, everywhere.

Copy this document into Abacus with every file in `files/` plus the updated
`KNOWN-ERRORS.md` (also in this batch — it now has entries E16–E20 from this
audit). Prerequisites: M35, M37, M38, M39, M40, M41 all deployed (confirmed
live in this re-audit — see below).

---

## PROMPT FOR ABACUS

### RE-AUDIT RESULT (July 20, live build, full 10-mode sweep + console capture)

**The good news first — M35 through M41 are genuinely live and working:**
basketball, karate, and football now show a real player on screen with a
single working control deck; all three board sports render full worlds
(skatepark, slope, wave); all four precision sports spawn a real athlete plus
the correct furniture (net, flag+green, plate+mound, goal+keeper). This is a
massive improvement over the prior audit and confirms the M37 foundation
(camera, guards, single input path) is doing its job — FrameGuard and
SpawnGuard both fired exactly as designed and caught the five defects below
instead of letting them ship silently.

**Five new/newly-visible defects, each root-caused via full console capture:**

1. **T-pose in nearly every mode (E16, the big one).** Full `[FEL-ANIM]` log
   capture proves the live hero rig only ships nine real clips — `guard,
   high_kick, hook, jab, jumpshot, roundhouse, run, uppercut, walk` — plus
   the sixteen procedurally-authored ones. Every sport-specific name written
   across the mode codebase (`golf_address`, `tennis_forehand`,
   `board_ride_idle`, `run_forward`, `derby_swing`, `karate_punch_light`,
   `penalty_strike`, `keeper_dive_left`, …) matches nothing, and the old
   "loud MISSING CLIP" behavior never fires for a name that was never
   registered at all — so every one of those calls was a **silent no-op**,
   leaving the rig at bind pose. This is why almost every athlete in almost
   every mode has been standing with arms out in a T since the last audit.
2. **Camera pressed against a dojo wall (E17).** Karate's camera can end up
   flat against a wall panel, filling the whole frame with a blank texture.
3. **Skater falls through the floor forever (E18).** Confirmed live: y
   dropped from 0 to −151 and was still falling when the sweep ended.
4. **Football field vanishes mid-drive (E19).** Around a tackle/first-down
   transition the field disappears and the runner floats in an empty void
   for about a second.
5. **Duplicated HUD labels (E20).** `"RD RD 1/7"`, `"5 YD · 0 EVA YD · 0
   EVA"`, `"1 GOALS PTS"` — mode code was embedding its own label text into a
   field name the live bezel already decorates.

### FILES
| File | Fixes |
|---|---|
| `files/anim/clipRegistry.ts` | **New.** `REAL_CLIPS` (the true clip inventory), `SPORT_CLIP` (semantic gesture → real clip alias table), `installSafePlay()` (wraps every animator so an unresolved name is IMPOSSIBLE to reach silently — logs loudly and substitutes a real clip instead of bind pose). |
| `files/core/CameraDirector.ts` | v2.2. Minimum safe camera distance, larger occlusion margin, two alternate-angle retries, guaranteed-clear overhead fallback if boxed in on all three. Fight preset pulled from 5.2u to 4.2u for the dojo's actual room size. |
| `files/core/GroundRide.ts` | v3. Hard floor clamp: after several consecutive missed ground-raycasts (or any position below the floor), the rider is force-clamped and re-grounded. Falling through the world becomes categorically impossible. |
| `files/modes/rideWorlds.ts` | Surf world enriched (horizon backdrop + distant swell line) to clear the "world did not build" spawn-guard warning and read as a real place, not a void. Skatepark/slope grounds now explicitly `checkCollisions`/`isPickable`. |
| `files/modes/boardCore.ts` | Wires `installSafePlay`; trick-machine grab clip now points at a real clip via `SPORT_CLIP.boardGrab`. |
| `files/modes/SkateRunMode.ts`, `SnowboardSlalomMode.ts`, `SurfBreakMode.ts` | Clip names routed through `SPORT_CLIP`. Surf also gets a speed cap (was unbounded, sent the rider 50–80m downfield in seconds and outran the camera) and a lead-the-subject camera adjustment. |
| `files/modes/aimSwingCore.ts` | Wires `installSafePlay` into `spawnAthlete` — defense-in-depth for all four precision modes. |
| `files/modes/precisionModes.ts` | Clip names routed through `SPORT_CLIP` across tennis/golf/baseball/soccer. HUD `round` fields now pass the bare fraction (`'1/7'` not `'RD 1/7'`); soccer's `score` field passes a bare number instead of `'N GOALS'`. |
| `files/modes/FootballRushMode.ts` | Clip names routed through `SPORT_CLIP`. Defense respawn now owns and disposes exactly its own defender list instead of calling `MobPool.disposeAll()` — removes the suspected cause of the field-vanishing defect. HUD `yards`/`evades` now pass bare numbers instead of a pre-formatted string. |
| `files/modes/DunkMode.ts` | Clip names routed through `SPORT_CLIP` — fixes `'run_forward'` (never existed; real clip is `'run'`), meaning the player was T-posing on every approach run. |
| `files/modes/KarateEndlessMode.ts` | Clip names routed through `SPORT_CLIP` (strikes now play real jab/high_kick/uppercut clips instead of no-op names). Adds a `camDirector.snapTo()` on load for correct frame-one framing. |
| `KNOWN-ERRORS.md` | Updated ledger — E16 through E20 added, with a new "CONTENT GAP" section explaining what E16's alias fix does and doesn't solve (see below). |

### WIRING
1. Drop every file in — each REPLACES its predecessor by filename.
2. In `CharacterLibrary.spawn` (or wherever characters are constructed), no
   changes needed — `installSafePlay` is called per-mode, per-character, as
   shown in each updated mode file. If any OTHER mode file not in this batch
   spawns a character and plays clips by hand-written string, add
   `installSafePlay(animator, 'modeId')` right after its `neverBindPose()`
   call — it's a one-line addition and makes that mode's bind-pose risk
   disappear too.
3. No new ModeContext fields required — this batch only consumes
   `heroRef`/`objectiveRef`/`groundLock`/`feel` that M37–M41 already added.
4. Run the KNOWN-ERRORS regression sweep (now includes E16–E20 checks).

### IMPORTANT — read before reporting this "done"
E16's fix makes every mode **animated and never bind-posed**, which is the
single biggest visible-quality jump available right now. It does **not**
give golf a real golf swing or tennis a real forehand — those gestures are
currently aliased to the closest clip that actually exists (a golf swing
plays `'roundhouse'`, a tennis forehand plays `'jab'`). That is a genuine
readability and premium-feel improvement over a T-pose, but it is a content
gap, not a code gap: closing it for real needs either real sport-specific
animation clips imported for the hero rig, or more procedurally-authored
clips built the way the basketball Eastbay dunk and the football evasions
were. `KNOWN-ERRORS.md`'s new "CONTENT GAP" section has the full clip
inventory so this can be scoped as its own workstream.

## ACCEPTANCE
1. **Console sweep, all 10 modes**: zero `MISSING CLIP` warnings that aren't
   immediately followed by a safe substitution; zero unlogged bind-pose.
2. **60s recorded runs — karate near a wall, dunk, football through a full
   drive, skate for the full 90s**: no blank-wall camera frame, no falling
   through the floor, no field-vanish around a tackle, hero framed
   throughout.
3. **HUD spot-check, all four precision modes + football**: no doubled words
   in any readout.
4. **Visual bar**: every athlete, in every mode, is doing SOMETHING with
   their arms and legs at all times — walking, swinging, striking, riding —
   never standing bolt upright with arms out to the sides.
