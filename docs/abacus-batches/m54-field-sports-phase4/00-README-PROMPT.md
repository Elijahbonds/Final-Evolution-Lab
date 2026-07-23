# M54 — PHASE 4: field & court sports (truck/style football, tennis rallies, 3-click golf + hole preview, penalty feints)

Copy this into Abacus with every file in `files/`. Prerequisites: M42/M43
(shared cores), M53 (this batch's `modeVerbs.ts` replaces M53's). Files
REPLACE their predecessors by filename. `aimSwingCore.ts` is untouched —
the M40 version stays as-is.

---

## PROMPT FOR ABACUS

All four named games below are informal mechanics references only —
all-original implementations, no assets/names/content from any of them.

### FOOTBALL — the street-football power game (`FootballRushMode.ts` v5)
Everything from M45 kept (breakaway, coins, flanker AI, map-size fixes).
Two additions:
- **TRUCK** — hold the trigger to lower the shoulder (0.5s window, 2.5s
  cooldown). Contact during the window knocks the DEFENDER down instead of
  you: they take the fall clip with a dust burst, you barrel through
  (+30 pts). While trucking you steer badly — it's a committed line, the
  power answer next to the finesse answers (jukes/spin/hurdle).
- **STYLE CHAIN** — using DIFFERENT evade types in one drive (juke → spin →
  hurdle → truck) pays a stacking bonus per new type. Spamming one move
  pays base; variety pays big — street-football scoring philosophy.
- Touch deck: TRUCK takes SPIN's slot (4-button budget); SPIN stays on
  keyboard B. New HUD fields: `truckReady` (bool — dim the TRUCK chip when
  false), `trucks` in end stats.

### TENNIS — real rallies + motion-style swings (`precisionModes.ts` v5)
The old loop was serve → one swing → next serve. Now it's actual tennis:
- **The opponent returns the ball.** A second athlete on the far side
  shuffles to the ball and gets it back — each exchange raises a RALLY
  multiplier. Your point banks only when they finally can't reach it, at
  (10 + quality×15) × rally. Let it past you and the whole rally's value
  is gone. Deep rallies are now the whole game.
- **The stick is the swing** (motion-tennis feel): X at contact steers the
  return; stick UP = TOPSPIN (flat, fast, harder for the opponent, but a
  bit riskier), stick DOWN = LOB (safe, slow, easier for them). New HUD
  fields: `rally` (number), `shotShape` (string).

### GOLF — hole preview + the classic 3-click swing
- **HOLE PREVIEW** — before every shot the camera flies to the green and
  looks back at the tee for ~2s (skippable with SWING) — you finally SEE
  what you're aiming at. Pure `camDirector.snapTo`, timer-bounded, cannot
  stall.
- **3-CLICK SWING** — click to start the meter, click at the top for
  POWER, click again in the ACCURACY band on the way down. Missing the
  accuracy click hooks/slices the ball proportionally ("PURE" /
  "DRIFTED" / "SHANKED"). New HUD field: `accuracy` (string).

### PENALTY (soccer) — street feints
- **FEINTS** — during aim, snap the stick hard left↔right (within 450ms)
  to feint, up to 2. Each feint makes the keeper guess WRONG more often
  (62% correct → 50% → 38%) and banks style points paid only on a goal —
  but each also adds shot wobble. Commitment tradeoff, not a free win.
  New HUD fields: `feints` (number), `stylePts` in end stats.

### FILES
| File | What it does |
|---|---|
| `files/modes/FootballRushMode.ts` | v5 — TRUCK + STYLE CHAIN on top of M45. |
| `files/modes/precisionModes.ts` | v5 — tennis rallies/stick-swing, golf preview/3-click, penalty feints. Derby unchanged, rides along. |
| `files/ui/modeVerbs.ts` | v4 — football deck: SPIN → TRUCK (hold). REPLACES M53's file; everything else identical. |

### WIRING
1. Drop every file in — each REPLACES its predecessor by filename.
2. Bezel: render `rally` near the score in tennis, `accuracy` after a golf
   swing, `feints` during soccer aim, and dim football's TRUCK chip while
   `truckReady` is false. All bare values.
3. Run the KNOWN-ERRORS regression sweep.

## ACCEPTANCE
1. Football: hold TRUCK and run into a defender — THEY fall, you continue,
   "TRUCKED!" banner, +30. Do juke → hurdle → truck in one drive — "STYLE
   CHAIN x2" then "x3" banners with stacking bonuses. TRUCK chip dims for
   ~2.5s after each use.
2. Tennis: return a serve — the far-side opponent visibly runs to the ball
   and hits it BACK; survive 3+ exchanges and the winner banner reads
   "WINNER — RALLY x3!" with a visibly bigger score jump. Stick up at
   contact shows TOPSPIN; stick down shows LOB.
3. Golf: every shot starts with a ~2s camera view from the green looking
   back (SWING skips it). The swing needs THREE clicks; deliberately
   missing the third click sends the ball visibly wide with "SHANKED".
4. Soccer: two quick stick snaps show "FEINT!" then "FEINT x2"; across
   several kicks the keeper visibly dives the wrong way more often after
   feints, and goals after feints show "+N style".
5. Derby unchanged; no regression in any of the four (KNOWN-ERRORS sweep).
