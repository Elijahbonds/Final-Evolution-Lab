# M47 — DUNK CONTEST: JUDGED SLAM DUNK CONTEST OVERHAUL

Copy this into Abacus with every file in `files/`. Prerequisite: M42–M45
deployed (this replaces the M44 `DunkMode.ts` and ships a superset
`clipRegistry.ts`).

---

## PROMPT FOR ABACUS

### THE ASK
Make Dunk Contest better than NBA Live 07's dunk contest. The honest read on
what that means concretely: FEL's version was a head-to-head race to 21
points — functional, but not a *contest*. NBA-style dunk contests have three
things that make them a contest rather than a scoreboard race: judges,
props, and stakes that build (a hot streak visibly raising the next score).
All three are now built.

### WHAT CHANGED
**Structure.** Dunk Contest is now 2 rounds, 2 dunks per round, against a
rival who also gets judged rounds — not an infinite race. Total judged score
after round 2 decides the contest.

**Judges.** Every made dunk gets scored live by 3 AI judges (Silk/Doc/Prime —
the same persona trio built for the Cash Arena) on difficulty, execution,
and style, 6–10 each, with a one-line personality reaction. The scorecard is
computed from real telemetry: difficulty from style tier + prop + charge
level, execution from how close the SLAM tap landed to the perfect center of
the QTE window, style from the move plus the crowd's hype level.

**Props.** D-pad (repurposed — no new input plumbing) cycles NONE /
ALLEY-OOP / OBSTACLE before you charge:
- *Alley-oop*: a teammate spawns, tosses the ball on a deterministic arc
  timed to land in your hand mid-rise — you never carry the ball into the
  air, it's actually thrown to you.
- *Obstacle*: a box prop sits under the dunk path; clear it at the apex for
  the full difficulty bonus, clip it for a reduced bonus — you're never
  hard-failed, the dunk always completes.

**Hype meter.** A crowd energy value that builds with big scores and decays
between dunks, folded directly into the next dunk's style score — a hot
streak measurably raises what the judges give you next, the same feedback
loop a loud arena creates in a real contest broadcast.

Everything from the reliability work stays: clipRegistry/`installSafePlay`
(no bind pose, ever), a watchdog on every phase including the two new ones
(`judging`, `rivalTurn` — a judging reveal or a rival's turn can never hang
the mode), camera framing, SoundKit/EffectsKit, hit-stop/shake.

### FILES
| File | What it does |
|---|---|
| `files/anim/clipRegistry.ts` | Superset of M45's registry — adds `teammateToss`/`teammateIdle` gestures for the alley-oop, both mapped to real, already-available clips. |
| `files/modes/DunkMode.ts` | The full rebuild described above. |

## ACCEPTANCE
1. Play a full contest (2 rounds × 2 dunks, both you and the rival): every
   made dunk shows a 3-judge scorecard with distinct scores and personality
   lines; a missed dunk shows 0 and moves on without stalling.
2. Cycle all three props before a dunk — alley-oop visibly shows the
   teammate tossing the ball to you mid-air; obstacle visibly sits under the
   rim and a cleared vs. clipped attempt reads differently in the score.
3. String two big-scoring dunks in a row — the HUD hype value climbs and a
   third dunk with identical inputs scores a visibly higher style component
   than the first did.
4. Contest ends after round 2 with a clear WON/LOST result comparing your
   total to the rival's.
5. No phase — including judging and the rival's turn — can hang; deliberately
   stalling input at any point still resolves via the watchdog within its
   budget.
