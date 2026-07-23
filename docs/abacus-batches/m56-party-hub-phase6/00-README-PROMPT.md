# M56 — PHASE 6: party hub & assessments (2 new Carnival events, random draw, Dunk Duel, audits, Story Mode design)

Copy this into Abacus with every file in `files/`. Prerequisites: M42, M45
(Pickups), M49 (Carnival), M54 (this batch's `modeVerbs.ts` replaces
M54's). Files REPLACE predecessors by filename; DunkDuelMode is NEW.

---

## PROMPT FOR ABACUS

### 1. Court Carnival — six events, random four per night
- `carnivalEvents.ts` v2 adds **COIN STORM** (pickup frenzy on the street
  court — clear the pattern and a fresh one drops, alternating cross/ring
  routes) and **COUNTER STRIKE** (pure parry timing: the rival visibly
  winds up ~0.5s, tap GUARD/X inside the window to counter; too early is
  called out, getting hit is punished). Both built entirely from owned
  systems (CoinField, character pipeline, dojo venue).
- `CourtCarnivalMode.ts` v2 draws a **random 4 of the 6** each session
  (Fisher-Yates) — two sessions no longer see the identical night, which is
  the party-game replay hook. Everything else byte-identical to M49.

### 2. DUNK DUEL — NEW mode (`modeId: 'dunkduel'`) — real head-to-head
Two HUMANS, one device, pass-and-play: P1 dunks, hands the device over, P2
answers — two dunks each, the same three judges score every attempt, higher
total takes the duel ("DEAD HEAT!" on a tie). The attempt flow is the
proven Dunk Contest loop (charge → cinematic → SLAM QTE → judged reveal,
rim-cam cut included), trimmed of props so both players get the identical
test. A "PASS TO P2" handoff card runs between turns (any button skips it;
watchdog-bounded like every phase).
**Honest scope:** this is real local multiplayer — the strongest 2-player
experience shippable without the networking infra this repo can't see. A
remote/IRL-video variant would ride on the M36 cash-arena ghost/recording
pipeline — flagged, not faked.

### 3. AUDITS (the Phase 6 assessment items — findings, no code needed)
- **Who Scene It** ✅ healthy live: the IP-safe "Free-Use Legends" question
  format is running (streak/score, 15-question sessions, public-domain
  framing). No console errors, no defects. Leave as-is.
- **Brain Brawl** ✅ healthy live: timed category questions (VOCABULARY
  shown), per-question countdown, score/clock/accuracy/difficulty HUD all
  working. No console errors. Leave as-is.
- **Art / Music / Dance — ⚠ FINDING: all three 404 on the live app**
  (`/play/art`, `/play/music`, `/play/dance`). The M28 batch shipped
  `ArtMode.tsx`, `MusicMode.tsx` + `AudioEngine.ts`, and
  `ChoreographyEngine.ts`, but no routes exist for them today. Either the
  M28 files were never wired to routes, or they live under different paths
  I couldn't discover from the hub. **Action for Abacus: wire the M28
  creative modes to their routes (or tell me the actual paths so I can
  audit them).** The Phase 7 music-studio batch will build on MusicMode/
  AudioEngine, so this wiring matters beyond cosmetics.

### 4. STORY MODE — the design pass (see `STORY-MODE-DESIGN.md`)
Per the plan, Story Mode gets a design-before-code deliverable: **"THE
RUN"** — a 10-chapter season using ONLY existing modes with chapter win
conditions, an original cast (Coach Rhea; rivals Vex/Kite/Mara Sensei; the
existing judge trio as color), dialogue-card cutscenes + venue establishing
sweeps (all procedural, no video/new assets), Shards/XP/tint-unlock
rewards through the existing pipeline. Full chapter table in the doc.
Approve it and the build lands as one focused batch in a later phase.

### FILES
| File | What it does |
|---|---|
| `files/modes/carnivalEvents.ts` | v2 — adds COIN STORM + COUNTER STRIKE (pool of 6). |
| `files/modes/CourtCarnivalMode.ts` | v2 — random 4-of-6 draw per session. |
| `files/modes/DunkDuelMode.ts` | **New mode** `dunkduel` — pass-and-play judged head-to-head. |
| `files/ui/modeVerbs.ts` | v5 — adds the `dunkduel` deck. REPLACES M54's file. |
| `STORY-MODE-DESIGN.md` | The Story Mode design for approval (no code yet). |

### WIRING
1. Drop every file in — carnival files and modeVerbs REPLACE by filename.
2. Add a hub card for Dunk Duel → `modeId: 'dunkduel'`, route
   `/play/dunkduel` (existing card pattern). Suggested copy: "Two players,
   one device — settle it at the rim."
3. Bezel: DunkDuelMode reuses Dunk Contest's HUD contract plus
   `activePlayer` ('P1'/'P2') and `p1Score`/`p2Score` (bare values).
4. **Wire the M28 creative-mode routes** (finding #3 above).
5. Run the KNOWN-ERRORS regression sweep.

## ACCEPTANCE
1. Two Carnival sessions in a row show different event line-ups (4 drawn
   from 6); COIN STORM lays a fresh pattern when cleared; COUNTER STRIKE
   pays only inside the parry window and punishes early taps.
2. Dunk Duel: full duel completes — handoff cards between every turn, both
   players judged by the same trio, winner declared (or DEAD HEAT), no
   phase able to stall past its watchdog.
3. Who Scene It and Brain Brawl unchanged and healthy.
4. `/play/art`, `/play/music`, `/play/dance` resolve after wiring (or the
   real routes are reported back for the next audit).
