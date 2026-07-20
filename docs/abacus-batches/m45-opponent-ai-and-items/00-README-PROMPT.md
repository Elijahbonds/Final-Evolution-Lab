# M45 — OPPONENT AI, BEHAVIOR VARIETY & ITEMS

Copy this into Abacus with every file in `files/`. Prerequisite: M42, M43,
M44 deployed (the mode files here are the M44 versions with these changes
layered in — REPLACE their predecessors by filename).

---

## PROMPT FOR ABACUS

### AUDIT: mobs / NPCs / opponents / behaviors / items / hitboxes / pacing
Direct read of `MobSteering.ts` and `Pickups.ts` (both live since M26) found:

1. **Every pursuing enemy has likely been T-posing.** `Mob.startPursuit()`
   plays a clip named `'run_forward'` — the exact non-existent clip name
   fixed in `DunkMode` back in M42 (E16), except this copy lives in the
   SHARED mob-steering class every karate opponent and football defender
   uses. M42's sweep only patched mode files directly, so this shared root
   cause was never touched — meaning it likely regressed straight back in
   for every enemy in the game. Fixed here the same way: routed through
   `clipRegistry`.
2. **Football was using the wrong opponents entirely.** `STEERING_PRESETS`
   has a `defender` preset purpose-built for football (cuts off the runner's
   lane) that no football code ever called — it was reusing karate's
   `striker`/`rusher` presets instead. Fixed, plus a new `flanker` preset
   mixed in so the defense doesn't read as a single-file straight-line chase.
3. **Items exist and were wired into zero modes.** `Pickups.ts`'s `CoinField`
   (line/arc placement, magnet radius, server-validated collection cap) has
   been sitting unused since M26. Wired into football (a coin line down the
   lane — rewards weaving, not just sprinting straight) and skateboard (an
   X-pattern across the park plus a risk arc off the funbox).

### ON THE OTHER TOPICS ASKED ABOUT (pacing/timing/flow/sequencing/hitboxes)
Honest status rather than re-litigating what's already shipped:
- **Pacing/escalation** is substantially covered by M43's mechanics (hot
  streak, breakaway, chi finisher, manual window, clutch rounds) and M44's
  fix to football's defender-count scaling (it was keyed to a per-down
  counter that reset every first down and never actually ramped).
- **Sequencing/inputs/flow** — one control deck, one keyboard map, one input
  bus, anti-stall watchdogs on every multi-phase mode — covered by M35/M37.
- **Hitboxes** are simple radius/distance checks today (a mob's
  `contactRadius`, a strike's `range`), not oriented hurtboxes tied to
  animation frames. Combat already has an approximate hit-timing window (the
  150ms delay between a strike's animation start and its damage check), but
  a real hitbox system — separate collision volumes per attack, timed to the
  actual swing frame — is a genuinely bigger engineering lift than fits in
  this batch alongside the AI/items work above. Flagging it as the next
  scoped unit if combat precision is the priority.

### FILES
| File | Fixes |
|---|---|
| `files/core/MobSteering.ts` | v2. Routes every clip through `clipRegistry`/`installSafePlay` (fixes E22 — the T-posing mobs). Adds a `flanker` preset (angled cut-off instead of straight chase) and a short reaction delay before a freshly-triggered mob starts moving (reads as "noticed you," not psychic). |
| `files/modes/FootballRushMode.ts` | Defenders now spawn as a `defender`/`flanker` mix instead of reused karate presets. Adds a `CoinField` coin line down the lane, reporting through the existing `SessionResult.stats.coinsCollected` contract. |
| `files/modes/KarateEndlessMode.ts` | Enemy archetype rotation now includes `flanker` for ring variety. |
| `files/modes/SkateRunMode.ts` | Adds a scattered `CoinField` across the park plus a risk arc off the funbox. |

### WIRING
1. Drop every file in — each REPLACES its M44 predecessor by filename.
2. No `ModeContext` or HUD contract changes — `coins`/`score` fields use the
   same `setHud` bridge every other field already uses.
3. Run the KNOWN-ERRORS regression sweep (now includes E22–E24).

## ACCEPTANCE
1. **Mob animation check**: in karate and football, a pursuing enemy/
   defender is visibly running (arms/legs moving), never bind-posed, from
   the moment it starts chasing.
2. **Football defense check**: watch a full drive — not every defender
   converges in a straight line; at least one visibly cuts an angle to
   intercept.
3. **Items check**: football run picks up coins along the lane with a
   audible tick and a HUD coin count; skate run picks up coins scattered
   across the park and via the funbox air arc.
4. Existing acceptance from M42–M44 still holds (no regressions).
