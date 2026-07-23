# M53 — PHASE 3: combat modes (FightCore, Karate VS rebuild, NEW Mixed Combat ring-out duel)

Copy this into Abacus with every file in `files/`. Prerequisites: M42
(clipRegistry etc.), M52 (this batch's `modeVerbs.ts` replaces M52's).
Files REPLACE predecessors by filename; the two mode files replace/add
routes as noted.

---

## PROMPT FOR ABACUS

### Phase 3 audit result first: M50 "Agent Waves" is CONFIRMED LIVE ✅
This cycle's live check of `/play/karate` shows the M50 rebuild deployed and
working: over-the-shoulder camera locked behind the player, the cyan co-op
ally fighting alongside, "WAVE 1 · 0 KO" HUD. No pacing changes shipped for
it in this batch — it just landed and deserves real play data before tuning.
(The fighters still show the E25 bind-pose in my sandbox capture — that's
the open M51 skinning question, pending your real-device check; camera,
ally, waves, and HUD are all verifiably correct regardless.)

### 1. FightCore — the shared 1v1 dueling engine (new)
One core owns strikes/guard/parry/combos for both duel modes (the same
pattern BasketballCore uses for the two hoops modes):
- **Data-driven attacks** — per-move range/startup/stun/knockback tables.
  Karate set (fast, short) + STAFF set (long, slow, heavy knockback).
- **Hit-stun chains** — clean hits stun; follow-ups inside a 1.1s window
  chain into COMBO xN with per-link damage scaling (floor 40%), so combos
  are strong but never one-touch kills.
- **Guard-break rhythm** — blocking absorbs hits but chips a guard gauge;
  emptied, it SHATTERS into a 1.4s stagger. Guard only regenerates while
  NOT held. Turtling is a priced choice.
- **160ms parry** — tap block at the last instant: attacker staggers, you
  gain chi, brief scoped slow-mo beat (M50's pattern — never a global
  engine hijack).
- **Chi special** — hits build chi; at full chi HEAVY becomes the DRAGON
  (big damage, guard-shattering, huge knockback).
- **RivalFightBrain** — the AI duelist: approaches to ITS weapon's range,
  circles at range, blocks reactively when it sees your wind-up, attacks on
  a difficulty-scaled cooldown, spends full chi on its special.

### 2. Karate VS — complete rebuild (`/play/karate-vs`)
Same honest scope note as M48's basketball rebuilds: this repo has never
seen the existing Karate VS source (M46 documented that), only its live
behavior — best-of-3 vs "Rival Sensei", HP bars, chi→Dragon. So this is a
complete, self-contained replacement matched to that observed contract,
built on FightCore + the standard reliability stack (installSafePlay,
watchdogs on every phase, groundLock, fight-cam framing). Design reference
for feel: arena anime fighters' stun-chain/guard-break rhythm — mechanics
only, all-original implementation.

### 3. Mixed Combat — NEW mode (`modeId: 'mixedcombat'`)
The weapon-duel you asked for, with the classic 3D-weapon-fighter spacing
game (mechanics reference only):
- **RING-OUTS** — a raised octagonal platform with a glowing edge ring.
  Knocked (or walked) past it = instant round loss regardless of HP. Every
  knockback move is also a positional weapon; the full-chi special's huge
  knockback is THE ring-out tool. The AI never walks itself off — only
  knockback can send it over.
- **Reach-vs-speed matchups** — d-pad before each round picks FISTS (fast,
  short) or STAFF (long, slow, procedural bo-staff mesh in hand — zero new
  assets); the rival always takes the OPPOSITE loadout, so no mirror
  matches.
- Everything FightCore gives Karate VS (combos, guard breaks, parry,
  special) is in force on the ring.

### FILES
| File | What it does |
|---|---|
| `files/core/FightCore.ts` | **New.** Shared duel systems: attack tables (karate/staff/special), FighterState, resolveStrike (whiff/parry/block/guard-break/hit), applyHit combo scaling, RivalFightBrain. |
| `files/modes/KarateVSMode.ts` | Complete rebuild of `/play/karate-vs` (best-of-3, chi/Dragon, parry, guard gauge). REPLACES the unseen incumbent by route. |
| `files/modes/MixedCombatMode.ts` | **New mode** `mixedcombat` — ring-out octagon, FISTS/STAFF loadouts, best-of-3. |
| `files/ui/modeVerbs.ts` | v3 — adds `karate-vs` + `mixedcombat` touch decks. REPLACES M52's file (everything else identical). |

### WIRING
1. Drop every file in.
2. Add a hub card for Mixed Combat pointing at `modeId: 'mixedcombat'`
   (route `/play/mixedcombat`, same pattern as every other card). Karate VS
   keeps its existing card/route.
3. Bezel: both duels share one HUD contract (bare values): `hp`/`foeHp`,
   `guard`/`foeGuard`, `chi`/`foeChi`, `round`, `wins`/`foeWins`, `banner`,
   `hint`, plus `loadout` (string) in Mixed Combat. Render hp as the two
   bars Karate VS already shows; guard/chi as thin sub-bars if possible.
4. Run the KNOWN-ERRORS regression sweep.

## ACCEPTANCE
1. Karate VS: best-of-3 completes with a real result either way; no phase
   can stall past its watchdog budget.
2. Land 3 quick hits — "COMBO x3" shows and the third hit visibly deals
   less than the first (scaling).
3. Hold BLOCK against repeated heavies — guard bar visibly drains, then
   SHATTERS with a stagger long enough for the rival to punish. Guard
   refills only after you release block.
4. Tap BLOCK right as a hit lands — "PERFECT PARRY!" fires, the rival
   staggers, and a brief slow-mo beat plays and ends on schedule.
5. Fill chi, press HEAVY — "DRAGON!" fires with clearly bigger impact.
6. Mixed Combat: pick STAFF — a staff appears in your fighter's hand, your
   strikes visibly reach further, and the rival fights unarmed (and vice
   versa).
7. Knock the rival past the glowing edge — they fall off the platform and
   the round ends "RING OUT!" immediately, regardless of remaining HP.
   Walk yourself off — same, against you.
