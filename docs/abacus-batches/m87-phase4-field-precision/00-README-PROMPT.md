# M87 — Phase 4 of 10: field & precision

Depends on M83 (`Rng`), M84 (`ModeKit`).
**94 tests pass by execution.**

Existing work not re-shipped: `RallyCore` (M74, 37 tests), `precisionModes`
(M40), `FootballRushMode` (M54).

---

## §1 — FOOTBALL: an evade that can be WRONG

Football carries the **highest PRQ weight in the product (1.5)**. It should be
the deepest mode. Today it's the most reflexive one.

`FootballRushMode` gives juke, spin, hurdle and truck. Each grants
**invincibility frames on a cooldown**. Press the button inside the window and
you're untouchable; the defender's pursuit angle is irrelevant.

So there is nothing to read. The skill is reaction time and nothing else, the
optimal strategy is to mash an evade whenever anyone is close, and once a
player notices that, the mode is solved.

### The fix is the same insight as phases 2 and 3

> Phase 2 — the defender **commits** to a side, so a crossover can beat it.
> Phase 3 — an attack **commits** to recovery frames, so a whiff can be punished.
> Phase 4 — an evade **commits** to a direction, so it can be wrong.

A juke left against a defender already flowing left is a tackle. The same juke
against a defender flowing right is six yards. **Same input, same timing,
opposite outcome** — because you're reading a person instead of a clock.

Each evade answers a different pursuit angle, and the tests assert the design
rule that makes it a real choice: **no evade beats every angle, and every angle
has some answer.** An unanswerable situation is a cheap shot, not difficulty.

Two smaller corrections:

- **Baiting pays.** A defender that has already committed (Phase 2's
  `DefenseRead` exposes exactly this) is beaten by a wider band and pays more
  yards and style. The two systems reward the same skill.
- **Variety is only paid on success.** The live `StyleChain` pays for using a
  new evade *type* per drive, which rewards cycling buttons regardless of
  whether each was the right read. Now variety is a consequence of reading
  different situations.

---

## §2 — BASEBALL: identifying, not timing

`DerbyMode` throws ten pitches and asks you to "STRIKE on time". That's a
rhythm game in a baseball uniform — which is what almost every arcade baseball
mode ships, because it's easy to build and readable in one screenshot.

**Hitting is not a timing problem.** A 150 kph fastball reaches the plate in
~440 ms. Simple human reaction is ~200 ms and a swing takes ~150 ms to execute,
leaving a **290 ms decision window** for what is a four-way classification, not
a simple stimulus. There is no time to watch the ball and then decide.

Real hitters read **release and early flight** — arm slot, spin, apparent
velocity — and commit based on what they think it is. Hitting is a
classification problem solved under a deadline. The timing is the easy part.

`PitchRecognition.ts` models that, and the scoring principle is:

> **Being right about what it was matters more than being on time.**

A hitter who reads a curveball and swings slightly late still squares it up. A
hitter who sits fastball on a changeup is out in front **however good their
timing was** — which is exactly what happens in the sport, and exactly what a
timing bar cannot express. There's a test asserting that ordering directly.

**The changeup is the hardest pitch in baseball, and it falls out of the model
rather than being asserted:** its `apparentSpeed` tell is within 0.04 of a
fastball's, so recognition stays low through the window where you still had
time to act. A curveball gives itself away out of the hand and is
correspondingly easier.

`PitchSelector` sequences rather than rolling dice — no pitch three times
running, and **a hitter who sits fastball gets fed off-speed**. Same
read/be-read loop as the basketball defender, and deterministic, so a replayed
at-bat is the same at-bat.

**This also makes baseball a cognitive mode**, which matters for the product:
the Mental Resiliency thesis wants perception under pressure, and this is
literally that. Unlike a timing bar, it's a skill that transfers.

---

## §3 — RALLY: a duel, not an exchange

`RallyCore` is solid — timing bands, ballistic shots, faults, scoring, two
sports from one core. What it lacks is **a reason to aim.** `planShot()` takes
a target, but nothing makes one target better than another. Hit it back, hit it
back, hit it back. That's Pong with animation.

A rally isn't about hitting winners. It's about making the *next* ball harder
than the last until they give you one you can end. **The winner is usually
struck two shots after the shot that actually won the point.**

`RallyPressure.ts` models that loop with one number: placement moves an
opponent → movement costs recovery → an unrecovered opponent hits a worse ball.

Two design decisions worth naming:

- **Degradation is toward the centre and short, not random.** Random error
  feels unfair. A readable weak reply is a mechanic — the attacker can
  anticipate it and step in.
- **The AI builds rather than winner-hunts.** Against a set opponent it works
  them; only when they're stretched does it go for the line. Going for a winner
  off a neutral ball is the most common way club players lose points, and an AI
  that models that is both more beatable and more instructive.

### A calibration bug the tests caught

The first `movementCost` used 2.4 court-units/sec — **a player crossing a full
singles court (8.23 m) in 0.83 seconds.** Nothing was ever out of position, so
no shot cost anything and pressure never accumulated. **The entire model was
inert**, and it looked fine.

Recalibrated against reality: 4.1 m half-width, comfortable ≈ 2.7 m/s,
full sprint ≈ 4.7 m/s. Asserted in tests so it can't drift back.

That's the second phase running where a plausible-looking constant silently
deleted a whole mechanic. **The pattern is worth naming: a number that is
merely wrong, rather than absent, produces a system that runs and does
nothing.**

---

## FILES

| File | Goes where |
|---|---|
| `files/core/EvasionCore.ts` | `core/` |
| `files/core/PitchRecognition.ts` | `core/` |
| `files/core/RallyPressure.ts` | `core/` |
| `files/tests/field_test.ts` | `tests/` — 94 tests |

## PREREQUISITES

| Module | From | Used for |
|---|---|---|
| `Rng` | M83 | deterministic evades and pitch sequencing |
| `ModeKit` | M84 | mode-side wiring |
| `DefenseRead` | M85 | supplies `Pursuit.committed` |
| `RallyCore` | M74 | timing, ballistics, scoring — **not re-shipped** |
| `FightCore` | M53 | unchanged |

## WIRING

**Football.** Replace the i-frame check with `resolveEvade(type, direction,
pursuit, rng())`. `direction` comes from the stick at the moment of input —
**that is the commitment.** Feed `Pursuit` from the nearest defender's angle
relative to the runner's facing. Surface `result.reason` in the HUD: the
mechanic is invisible unless the game names it.

**Baseball.** Replace the timing bar with a guess input — four buttons, or a
stick direction per pitch type. Record `committedAtMs` from the fixed tick.
Show `recognitionAt()` as a visual tell that resolves over flight, so the
player learns to read rather than to guess. `resolvePlateAppearance()` returns
the outcome and the note.

**Tennis / volleyball.** Track a `PlayerCourtState` per side. After each shot
call `receiveShot()`. Before the reply, run the intended target through
`degradePlacement(aim, shotQualityUnderPressure(state))`. Use `chooseTarget()`
for the AI. Show `pressure` in the HUD — a bar that fills as they're worked.

## ACCEPTANCE

1. Tests: **94 passed**.
2. Juke into a defender's pursuit: tackled, with the reason on screen. Juke
   away: six yards. Same button, same timing.
3. Truck a head-on defender: through them. Truck at 45°: nothing there.
4. Sit fastball, get a changeup: out in front regardless of timing.
5. Read a curveball and swing late: still solid contact.
6. Guess fastball four times: the pitcher stops throwing it.
7. Hit two balls into opposite corners: the reply comes back short and central.
8. Replay a drive and an at-bat: identical outcomes.

## LIMITS

- **`football_hurdle` and `football_truck` clips do not exist.** `EVADES` names
  them; M80's loader will report them missing and fall back to procedural. Add
  them to `anim/clipManifest.ts` when they're conformed. Blender is still on
  the Mini and nowhere else — this is now blocking four phases.
- **Pitch tells need a visual.** `recognitionAt()` returns a number; something
  has to *show* it — spin trail, seam colour, release-point marker. Without a
  visible tell the mode is guessing, not reading, and that is strictly worse
  than the timing bar it replaces. **This is the highest-risk item in Phase 4.**
- **`Pursuit.angleDeg` must be measured in the runner's basis**, not world
  space. Same class of unknown as `HandlerState` in M85 — if the basis is
  wrong, every evade reads backwards.
- Gymnastics, golf and soccer are **untouched**. Their blueprint
  differentiators (routine composition, wind and lie, keeper tendency memory)
  are real but lower leverage than the three here, and I'd rather ship three
  deep than six shallow. They carry into Phase 9 or a later pass.
- Not type-checked against the live source. `docs/ACCESS-SETUP.md`.
