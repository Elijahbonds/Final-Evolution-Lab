# M63 — BASKETBALL & DUNK CONTEST v3: the comprehensive upgrade (real ball flight, drive dunks, real defense, contest craft)

Copy this into Abacus with every file in `files/`. Prerequisites: M42, M52
deployed (files here REPLACE the M52 versions by filename; `modeVerbs.ts`
replaces M56's). Everything from M47/M48/M52 is preserved — this stacks.

---

## PROMPT FOR ABACUS

### BasketballCore v3 — four new systems (everything v2 kept)
- **TurboMeter** — sprint is fuel: drains while sprinting, regens while
  not, re-arms at 25% after emptying (no flutter). Ends sprint-spam and
  gates the new dunks so they're earned.
- **ShotArc** — THE BALL ACTUALLY FLIES: a real parabolic arc from the
  release hand to the rim (~0.4-0.9s by distance; floaters arc higher,
  layups dart). Makes drop through the net; misses clang off a front-rim
  point and go live off the iron. The result is still decided at release —
  the arc is the honest visual sell, not hidden dice.
- **Drive dunks** — `checkDriveDunk()`: attacking the rim at speed
  (<2.8u, >3.4 m/s, toward the hoop, turbo ≥25%) converts the shot button
  into a DUNK; a defender inside 1.5u makes it a POSTERIZE attempt.
- **Shot blocking** — `checkBlock()`: a contest jump erases the shot when
  the blocker is within 1.5u AND jumped within 0.4s before the release.

### 1v1 Hoops v3 — a full TWO-WAY game
- Jumpers fly on the arc; misses rebound live and the closer body wins
  the board — lose it and you're DEFENDING.
- **Real defense**: the rival drives (weaving, watchdog-bounded); you
  poke STEAL in tight ("PICKED THEIR POCKET!") or time a BLOCK jump at
  their release ("REJECTED!"). No block/steal → your closeout distance
  sets their make% — the same rule yours obeys.
- **Drive dunks**: hot drive + shot = throw it down ("THROWN DOWN!");
  through a parked defender = "POSTERIZED!" — they hit the floor, +30
  momentum. Miss a contested one and it's "STUFFED AT THE RIM!" and a
  live ball. Dunks spend 30% turbo.
- Turbo HUD (fuel bar). The debug camFollowM readout is retired.

### 3v3 Streetball v3 — same systems, team game
My shots fly on the arc; drive dunks with posterize on the nearest
defender; turbo; and opponent possessions are now CONTESTABLE — the
positional make% your D already set remains, but a timed BLOCK jump at
the release erases the shot outright. Teammate play, passing, assists,
15-pair collision all preserved.

### Dunk Contest v5 — contest craft (all E25/M51-safe, animation-independent)
- **STYLE TAPS** — mid-air B taps (max 2) before the SLAM window: +1.2
  difficulty and +0.8 style each, but the SLAM window shrinks 25% per
  tap. Showboating is real risk for real reward.
- **VARIETY MEMORY** — the judges remember every style+prop combo thrown
  this contest: repeats score ×0.8 difficulty ("THE JUDGES HAVE SEEN THAT
  ONE…"), fresh combos get +0.5. Four dunks now demand four ideas.
- **THE NEED** — final-round attempts show the judge total required to
  hold off the rival's pace (HUD `need` + a "down N" hint) — walk-off
  pressure, live.
- **RIM HANG** — keep SLAM held through the flush to hang on the iron;
  ≥0.5s pays +1 style ("HANG TIME!") before the reveal.
- Chain meter, rim-cam cut, props, judges, hype — all kept from v4.

### FILES
| File | What it does |
|---|---|
| `files/core/BasketballCore.ts` | v3 — TurboMeter, ShotArc, drive dunks, blocking (all of v2 kept). |
| `files/modes/OneVOneMode.ts` | v3 — two-way 1v1: arc, dunks/posterize, turbo, real defense. |
| `files/modes/ThreeVThreeMode.ts` | v3 — arc, dunks/posterize, turbo, block-able opponent possessions. |
| `files/modes/DunkMode.ts` | v5 — style taps, variety memory, THE NEED, rim hang (v4 kept). |
| `files/ui/modeVerbs.ts` | v6 — 1v1 gains BLOCK+STEAL chips; 3v3 gains BLOCK. REPLACES M56's. |

### WIRING
1. Drop every file in — each REPLACES its predecessor by filename.
2. Bezel: render `turbo` (0-100) as a small fuel bar in both hoops modes,
   and `need` as a "NEED N" chip in Dunk Contest when > 0.
3. Run the KNOWN-ERRORS regression sweep.

## ACCEPTANCE
1. 1v1: every jumper visibly arcs to the rim — makes drop through, misses
   clang and bounce; no result ever teleports.
2. 1v1: sprint drains the turbo bar and stops working empty until it
   refills to 25%; a fast drive at the rim with fuel dunks instead of
   metering, and through a close defender triggers "POSTERIZED!" with the
   defender on the floor.
3. 1v1: after a strip or their rebound, the rival visibly drives on YOU —
   a tight steal poke or a release-timed A jump ends it ("PICKED THEIR
   POCKET!" / "REJECTED!"); mistimed jumps do nothing and their shot
   flies the same arc yours does.
4. 3v3: same arc/dunk/turbo behaviors; a release-timed block on an
   opponent possession shows "REJECTED!" and returns the ball.
5. Dunk Contest: two mid-air B taps visibly shrink the SLAM window and
   raise the judge numbers when landed; repeating the same style+prop
   scores visibly lower with the "seen it" banner; the final round shows
   NEED; holding SLAM through a flush pays "HANG TIME!".
6. Touch: 1v1 shows SHOOT/BLOCK/STEAL chips, 3v3 shows all four — every
   verb acts.
