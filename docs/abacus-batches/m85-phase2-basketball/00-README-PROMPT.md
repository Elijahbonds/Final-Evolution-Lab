# M85 — Phase 2 of 10: basketball

Depends on M81 (`DDA`), M83 (`Rng`), M84 (`ModeKit`).
**56 tests pass by execution.**

I checked what already existed before writing anything — `BasketballCore` v3
(M63) already ships `DribbleController`, `ShotMeter`, `TurboMeter`, `ShotArc`,
`checkDriveDunk`, `checkBlock` and ankle-breaks, and `DunkMode` already has a
three-judge scorecard with props, styles and freshness scoring. **None of that
is re-shipped.** M74 shipped duplicate tennis and volleyball modes by skipping
this step.

Two things were genuinely missing.

---

## §1 — THE PRODUCT THESIS WAS NEVER WIRED UP

Two halves have existed for months and were never connected:

- **`irl/irlDunkJudging.ts` (M33)** measures `jumpHeightCm` and `hangTimeMs`
  from phone video, calibrated against real stature.
- **`modes/DunkMode.ts` (M63)** scores a dunk on difficulty, execution, style.

**Nothing joins them.** Your actual vertical has *zero* effect on what you can
do in the 3-D dunk contest. Strip that out and FEL's flagship is a timing
minigame any studio could ship — the entire differentiator is that this one
knows your vertical.

`core/DunkTiers.ts` is that bridge.

### The physics, which is real

A dunk needs two different things, and conflating them is why arcade
basketball feels arbitrary:

- **Clearance** — how far your hand gets above the rim. Decides whether the
  ball can come down through the hoop at all.
- **Hang time** — how long you're airborne. Decides whether there's *time* to
  complete the motion.

A 360 needs **less clearance than a windmill but far more hang.** That's not a
typo — a 360 is a rotation problem, a windmill is a reach problem. So a tall
player with a modest vertical and a shorter explosive player unlock **different
dunks**, which is both true to the sport and more interesting than one number.
There's a test asserting they get different libraries.

### The product risk, handled rather than ignored

An average adult cannot dunk. If real gating were the only mode, the flagship
would be unplayable for most people who install it.

So gating has three settings and **the default is the inclusive one**:

| mode | behaviour |
|---|---|
| **`arcade`** ← default | everyone attempts everything; your vertical raises your **scoring ceiling** instead of restricting access |
| `assisted` | withholds only the elite tier until you're within 5cm / 100ms |
| `true` | honest gating — opt-in, because being told you can't dunk is a choice a player should make deliberately |

`scoreCeiling()` is what keeps arcade honest: everyone can throw a windmill,
but a body that genuinely supports it scores 1.15× where a borrowed one scores
0.7×. Real athleticism is rewarded without locking anyone out.

### The retention loop

`nextUnlock()` returns the nearest locked dunk and the exact gap:

> **Finger Roll: 14cm more vertical**

That's a reason to train tomorrow. "Locked" is a reason to stop playing. It's
also the only honest argument for health data in a game — not as a badge, **as
a key.**

### What the tests caught

My first fixtures had a 188cm player with a 76cm (30″) vertical expected to
windmill. The model said one-hand — and **the model was right.** A 30″ vertical
at 6'2" is a one-hand dunker. The fixture moved, not the model; that honesty is
the entire point.

The `rim_touch` message also got fixed: the first draft only reassured players
in the `no_rim` band, so the player *closest* to dunking — most likely to keep
training — got the bluntest message with no way forward. Exactly backwards.

---

## §2 — A DEFENDER THAT CAN BE BEATEN BY A MOVE

`BasketballCore.DefenderBrain` lerps toward a point 35% of the way from ball to
hoop and pokes for steals with `Math.random() < aggression * 0.02` per frame.
That's a chase, not a defender:

- **You can't beat it with a move, only with speed.** It never commits to
  anything, so there's nothing to fake.
- **It never punishes you.** Drive right nine times and the tenth is identical.
- **It breaks replays.** Per-frame `Math.random()` means M83's ghosts can't
  reproduce a possession and Cash Arena can't audit one.

`core/DefenseRead.ts` watches your hips, **guesses, and commits** — 420ms at
1.35× speed toward the guess and 0.55× away from it. A crossover inverts the
guess if it lands inside the reaction window. That's the mechanic: a fake works
because the defender genuinely committed to the wrong thing, and pays 380ms of
recovery for it.

`TendencyTracker` reads a habit over 8 possessions — and deliberately returns
**no read until 3 samples**. Being read in the first ten seconds is what makes
people quit a mode. When you are predictable, `scoutingReport` tells you:

> *"The defender has your right hand. Go left."*

Being read becomes a lesson instead of a mystery.

**Every draw comes from an injected `Rng`**, so a possession replays exactly.
A test runs 200 ticks twice on one seed and asserts identical output.

And a maximally skilled defender still caps at a **0.92** correct-guess rate.
There is a test asserting it does *not* read correctly every time — a perfect
read is unbeatable, and unbeatable is not a game.

### PRQ reaches the court

`defenderFor(rng, dda)` — a high-readiness player faces a defender that reacts
faster and reads better. Not because they picked "Hard". Because they showed up
ready.

---

## FILES

| File | Goes where |
|---|---|
| `files/core/DunkTiers.ts` | `core/` |
| `files/core/DefenseRead.ts` | `core/` |
| `files/tests/basketball_test.ts` | `tests/` — 56 tests |

## PREREQUISITES

| Module | From | Used for |
|---|---|---|
| `Rng` | M83 | deterministic defender decisions |
| `DDA` | M81 | PRQ → defender skill |
| `ModeKit` | M84 | the mode-side wiring |
| `BasketballCore` | M63 | dribble, shot meter, turbo — **not re-shipped** |
| `irlDunkJudging` | M33 | supplies the measured vertical |

## WIRING

1. **Dunk contest boot:** build an `AthleteProfile` — from
   `profileFromIrl(metrics, heightCm)` if they've done an IRL scan, otherwise
   the arcade default. Show `athleteSummary()` on the ready screen and
   `nextUnlock().summary` on the results screen.
2. **Dunk selection:** offer `availableDunks(profile, gate)`. Default `gate` to
   `'arcade'`. Put the gate in settings, not in the flow.
3. **Scoring:** multiply the existing judge total by
   `scoreCeiling(profile, dunk)`. That is the only change to `DunkMode`'s
   scoring — the three-judge card stays exactly as it is.
4. **1v1 / 3v3:** replace `DefenderBrain` with `defenderFor(rng(), kit.dda)`.
   Feed `HandlerState` each fixed tick from the ball-handler's lateral offset
   and velocity. Use `beaten` to open the drive lane and `contest` for the shot
   contest. Surface `scoutingReport` in the HUD.
5. **`DUNK_LIBRARY` clip ids** are `anim/clipManifest.ts` ids. Six of them
   (`dunk_tomahawk`, `dunk_windmill`, `dunk_eastbay`, `finger_roll`,
   `dunk_one_hand`, `dunk_two_hand`) **do not exist yet** — see LIMITS.

## ACCEPTANCE

1. Tests: **56 passed**.
2. A player with no IRL scan can play the dunk contest and throw every dunk.
3. A player with a scanned 45cm vertical sees "about 14cm from a one-hander",
   not "locked".
4. Switch to True Vertical: the library visibly shrinks and the summary
   explains why.
5. In 1v1, a crossover inside the reaction window opens a drive lane. Drive the
   same way five times and the defender starts winning the read.
6. Record a 1v1 possession and replay it: the defender makes identical
   decisions.

## LIMITS

- **Six of the nine dunk clips do not exist.** `DUNK_LIBRARY` names them, and
  M80's loader will report each as missing and fall back to procedural. The
  tier system works today; the *animations* need
  `tools/conform_clips.sh`, which needs Blender, which is on the Mini and
  nowhere else. **Phase 2 unlocks dunks the game cannot yet show you.**
- **The reach estimate is 1.325× height.** Real proportions vary by several
  centimetres, which is a whole tier at the margins. `standingReachCm` always
  wins when supplied — the app should ask for it.
- **`HandlerState` must be fed from real court positions** and I cannot see how
  `OneVOneMode` tracks them. If `lateralOffset` is measured in the wrong basis,
  the defender commits sideways.
- The `clearanceCm`/`hangMs` numbers are physically grounded but **not tuned
  against this game's jump animations**. Expect to move them once it is
  playable; that is why they sit in one table.
- Not type-checked against the live source. `docs/ACCESS-SETUP.md`.
