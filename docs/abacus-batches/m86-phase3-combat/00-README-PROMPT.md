# M86 — Phase 3 of 10: combat

Depends on M81 (`DDA`), M83 (`Rng`, `FixedStep`), M84 (`ModeKit`).
**76 tests pass by execution.**

`FightCore` (M53) already ships attacks with startup/range/damage, a guard
gauge, chi, a 160ms parry window and `resolveStrike()`. **None of it is
re-shipped.**

---

## §1 — WHIFFING WAS FREE, AND THAT DELETED THE ENTIRE NEUTRAL GAME

`resolveStrike()` returns `'whiff'` — and **there are no recovery frames.**
Miss a heavy from full range and you are immediately ready to act again.

That one absence removes the whole game underneath the game:

- **Spacing is pointless.** There's no reward for making someone miss.
- **Throwing your longest attack constantly is optimal.**
- **The winner is whoever mashes fastest** — which is why every arcade fighter
  that skips this feels like a button-mashing contest.

Combat had no depth to *find*, however good the animations get.

`core/NeutralGame.ts` adds the three concepts that are the whole genre:

| | |
|---|---|
| **Frame data** | every attack is startup / active / recovery |
| **Frame advantage** | after a block, one fighter acts first — and by how much |
| **Whiff punish** | recovery is a window where you cannot defend |

Master those and you have footsies: hover just outside their range, bait the
swing, punish the recovery. That's a ceiling that rewards *reading a human* —
which is what "better than the benchmark" has to mean here, not more combo
strings to memorise.

### This is a direct payoff of M83

Frame data is measured in **frames**. Before M83 the loop ran on
`engine.getDeltaTime()`, so "15 frames of startup" meant 250ms on a good frame
and 500ms on a bad one — **the same attack was a different move depending on
your phone.** Fixed 60Hz ticks are what make frame data mean anything at all.

### The design, asserted rather than hoped for

A fighting game's depth lives in relationships between numbers, and those are
invisible to playtesting until someone has already found the degenerate
strategy. So the tests pin them:

- **The safety ladder** — jab is +2 on block, kick is −3, heavy is −12.
- **No attack is always correct** — the heavy reaches *no further* than the
  kick. If the biggest attack also had the most reach, nothing else would ever
  be thrown.
- **A whiffed jab is only punishable by a jab.** Choosing the wrong punish
  means *you* whiff and get punished back.
- **A parry is worth 3× a block.** Otherwise blocking is the safe default and
  the parry window is decoration.
- **Staff outranges karate at every tool and pays in startup and recovery.**
  Karate has *no* tip against staff and must get inside — that asymmetry **is**
  the matchup.

---

## §2 — A BUG THE TESTS CAUGHT, WHICH WOULD HAVE SHIPPED SILENTLY

`rivalFor()` first mapped `dda.aiReactionSpeed()` straight to frames. That
returns 0.5–0.8s → **31–44 frames.** A whiffed heavy opens **24 frames.**

**No rival at any PRQ could ever punish anything.** The entire mechanic this
batch exists to add would have been dead on arrival, and it would have looked
like "the AI is a bit passive" rather than like a broken connection.

The two numbers measure different things. DDA's delay is a **decision** latency
for basketball-scale actions — where to move, whether to contest. Combat needs
a **perception** latency: how fast you see a wind-up. Human visual reaction is
~200ms trained, ~270ms untrained, so `COMBAT_REACTION_FACTOR = 0.35` maps the
DDA range onto **11–16 frames**. Both sit inside a heavy's recovery, so both
tiers can punish — the legend just does it more reliably, because `skill` gates
the attempt separately.

There is a regression guard asserting every tier reacts inside the window.

**The general lesson, worth carrying into phases 4–10:** two subsystems tuned
on different time scales can be wired together correctly and still produce
nothing. PRQ→combat needed a translation, not a connection.

---

## §3 — A RIVAL THAT PLAYS NEUTRAL

`FightCore.RivalFightBrain` circles, blocks on a random roll, and attacks on a
cooldown whenever you're in range. It has no concept of whiff punish, so it
can't be outspaced and can't outspace you — its only lever is speed. It also
calls `Math.random()` **four times a frame**, so no round can be replayed, no
ghost reproduced, no Cash Arena result audited.

`NeutralBrain`:

- holds `idealSpacing()` — the distance where its reach beats yours
- **punishes recovery only with an attack whose startup actually fits.** A
  punish that whiffs is a free punish for you.
- bakes the reaction delay in, so a whiff at the edge of its vision is
  genuinely safe
- draws from an injected `Rng`, so a round replays exactly

**What the tests establish about fairness:** a whiff thrown *inside* their range
is reliably punished by an elite rival — that's correct, that's what elite play
looks like, and it's exactly what makes spacing matter. The same whiff at 4.5m
is punished **zero times out of sixty**. Distance, not luck, is what makes a
whiff safe. That's the lesson the mode teaches.

### Coaching

Combat's depth is invisible until someone names it. A player who loses to
spacing without being told they were outspaced concludes the game is unfair and
stops. `coachingNote()` returns one line — *"You are swinging from too far out.
Every miss is free damage for them"* — and returns **null** for a clean round,
because a coach that always has notes is one people stop reading.

---

## FILES

| File | Goes where |
|---|---|
| `files/core/NeutralGame.ts` | `core/` |
| `files/tests/combat_test.ts` | `tests/` — 76 tests |

## PREREQUISITES

| Module | From | Used for |
|---|---|---|
| `Rng` | M83 | deterministic rival decisions |
| `FixedStep` | M83 | the 60Hz tick that makes frame data meaningful |
| `DDA` | M81 | PRQ → rival skill and perception |
| `ModeKit` | M84 | mode-side wiring |
| `FightCore` | M53 | damage, guard, chi, parry — **not re-shipped** |

## WIRING

1. Give each fighter an `AttackState`. Call `tickAttack()` once per **fixed**
   tick from `kit.frame()`, never from the render loop.
2. On the `onActive` callback, run the existing `FightCore.resolveStrike()` to
   get an outcome, then `resolveExchange()` to convert it into frame advantage
   for both fighters. `FightCore` keeps owning damage, guard and chi — this
   layer owns *time*.
3. Gate all input on `canAct(state)`. That is what makes recovery real.
4. Replace `RivalFightBrain` with `rivalFor(rng(), kit.dda, frames)`.
5. HUD: show `spacingZone()` as a range indicator. **The tip zone should be
   visible** — a player cannot learn footsies from a mechanic they cannot see.
6. Round end: `coachingNote(stats)`.

## ACCEPTANCE

1. Tests: **76 passed**.
2. Whiff a heavy in range against an elite rival: you get punished, every time.
3. Whiff the same heavy from 4.5m: nothing happens. Spacing is the difference.
4. Block a heavy: you are free 12 frames before they are, and a jab lands
   guaranteed.
5. Block a jab: *they* are still plus, and pressure continues.
6. Parry anything: a full heavy punish is guaranteed.
7. Play staff vs karate: staff wins at range, karate wins inside.
8. Record a round and replay it: the rival makes identical decisions.

## LIMITS

- **The frame data is genre-shaped, not tuned against this game's animations.**
  If `jab` visually takes 200ms but is 4 frames of startup, the numbers and the
  picture disagree and players will trust the picture. Tuning needs the real
  clips, and six of them are still missing (see M85's limits).
- **`FightCore` still owns `resolveStrike()`,** which has no notion of active
  frames. Until the two are joined, an attack can connect during startup. The
  wiring in step 2 is where that gets fixed, and I cannot do it without the
  mode source.
- **Nothing enforces `canAct()`.** If the mode lets a player attack during
  recovery, every guarantee here evaporates. That is one `if`, and it is the
  single most important line of the integration.
- Not type-checked against the live source. `docs/ACCESS-SETUP.md`.
