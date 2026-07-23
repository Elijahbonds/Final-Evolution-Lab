# M52 — PHASE 2: basketball ecosystem (Blacktop-feel core, touch-shooting fix, broadcast dunk polish)

Copy this into Abacus with every file in `files/`. Prerequisite: M42, M47,
M48 deployed (all confirmed live in this cycle's audit — 1v1 Hoops shows
M48's "TO 11" target, Court Carnival spawns M49's world). Files here REPLACE
their predecessors by filename.

---

## PROMPT FOR ABACUS

### 1. CRITICAL FIX — touch players cannot shoot in 1v1/3v3 (live-confirmed)
The M48 basketball modes read shooting from a HELD TRIGGER (the shot meter
charges while held, resolves on release). But `modeVerbs.ts` never got
entries for `onevone`/`threevthree`/`carnival`, so they fall back to
`default` — a single ACTION button that emits a plain A press and **never
emits the trigger stream**. Confirmed on the live build: 1v1 Hoops renders
one generic "ACTION" chip, so on a phone there is no way to shoot at all.
Keyboard players were unaffected (Space maps to the trigger), which is why
this survived earlier sweeps. `files/ui/modeVerbs.ts` v2 adds all three
entries: SHOOT (hold) for 1v1; SHOOT/PASS/STEAL for 3v3; CHARGE/GO/TRICK/
POWER for Carnival (its four events share one deck; the Trick Gauntlet's X
spin was the one verb that didn't fit the 4-button budget — B/Y still give
two distinct tricks so variety scoring works).

### 2. BasketballCore v2 — the 2K-Blacktop feel systems
Reference: the pick-up-basketball feel of 2K's Blacktop mode — as a
mechanics target, entirely original implementation.
- **Body collision** — `resolveBodyCollision()`: players occupy physical
  space; driving into a defender bumps both apart (with a bump sound on
  hard contact) instead of ghosting through. All 15 body pairs resolve
  every frame in 3v3.
- **Ankle-breaker** — throw a crossover (fast stick reversal, mechanic
  shipped in M48) right in a tight defender's face (<1.6u) and they now
  STAGGER for 0.7s: stagger clip, dust burst, crowd pop, "ANKLES!" banner,
  momentum bonus in 1v1, and a genuinely open lane. This is the 1v1
  mind-game loop: bait them close, then shake them.
- **Shot variety** — `classifyShot()` types every attempt from real context:
  LAYUP (<2.2u, forgiving meter, +18% make), FLOATER (short midrange),
  JUMPER, or FADEAWAY (moving away from the hoop under contest — tighter
  meter, -18% make, but legal offense against tight D). The HUD shows the
  shot type while the meter runs; jumpers/fadeaways release with the real
  `jumpshot` clip instead of the dunk launch.

### 3. Modes rebuilt on the v2 core
`OneVOneMode.ts` and `ThreeVThreeMode.ts` wire all three systems in.
Everything else from M48 is preserved exactly (momentum, make-it-take-it,
pass-to-open-man, assists, simulated opponent possessions with
defense-affected make%, watchdogs, HUD contracts). One new HUD field on
both: `shotType` (bare string label, e.g. "FADEAWAY").

### 4. Dunk Contest broadcast polish (v4)
Two animation-INDEPENDENT additions (they land regardless of how the M51/E25
skinning question resolves on real hardware):
- **Rim-cam cut** — as the dunk rise crests, the camera hard-cuts to a
  baseline angle under the rim for the flush, then resumes the normal follow
  on resolve — the wide→under-basket cut every televised contest uses. Uses
  the existing `camDirector.snapTo` API; no new camera code.
- **Chain meter** — back-to-back judge totals of 24+ build "CHAIN xN"; every
  link pumps extra hype, and hype already feeds the judges' style score, so
  chains have real scoring teeth (THPS-combo energy, original system). A
  miss breaks the chain. New HUD field: `chain` (number; show "CHAIN xN"
  when ≥2).

### FILES
| File | What it does |
|---|---|
| `files/ui/modeVerbs.ts` | v2 — adds `onevone`/`threevthree`/`carnival` touch decks (fixes shoot-impossible-on-touch). Everything else byte-identical to M35. |
| `files/core/BasketballCore.ts` | v2 — adds `resolveBodyCollision`, `checkAnkleBreak` (+constants), `classifyShot`/`ShotContext`, style-aware `ShotMeter.start`. All M48 exports kept. |
| `files/modes/OneVOneMode.ts` | v2 — collision, ankle-breaker (stun + momentum), shot variety wired in. |
| `files/modes/ThreeVThreeMode.ts` | v2 — same three systems across all six bodies. |
| `files/modes/DunkMode.ts` | v4 — rim-cam broadcast cut + chain meter on top of M47's judged contest. |

### WIRING
1. Drop every file in — each REPLACES its predecessor by filename.
2. Bezel: render the new `shotType` field near the shot meter, and `chain`
   as "CHAIN xN" when ≥ 2 (both bare values — bezel decorates).
3. Run the KNOWN-ERRORS regression sweep.

## ACCEPTANCE
1. **On a touch device**: 1v1 Hoops shows a SHOOT hold-button; holding it
   charges the meter and releasing resolves the shot. 3v3 shows SHOOT/PASS/
   STEAL. Carnival shows CHARGE/GO/TRICK/POWER and every event responds.
2. Drive straight at the defender — you bump off them, never pass through.
3. Sprint one way, snap the stick the opposite way within arm's reach of the
   defender — they stagger visibly for ~0.7s, "ANKLES!" banner fires, and
   you can drive past for an uncontested layup labeled LAYUP.
4. Shoot while backing away from the hoop with the defender tight — the HUD
   reads FADEAWAY and the green window is visibly tighter.
5. In Dunk Contest, the camera cuts to a low baseline angle for the flush
   and returns to the follow cam afterward; two straight 24+ dunks show
   "CHAIN x2" and hype visibly jumps.
