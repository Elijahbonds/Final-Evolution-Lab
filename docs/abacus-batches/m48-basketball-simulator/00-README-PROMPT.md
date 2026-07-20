# M48 — BASKETBALL SIMULATOR: 1v1 Hoops & 3v3 Streetball, optimized movement/camera/control/multiplayer core

Copy this into Abacus with every file in `files/`. Prerequisite: M42, M45,
M47 deployed (this batch's modes import `clipRegistry` and `CameraDirector`
at their M47/current versions and doesn't re-ship them unchanged — only
`CameraDirector.ts` here has real changes, two new presets, additive only).

---

## PROMPT FOR ABACUS

### THE ASK, AND THE HONEST SCOPING DECISION BEHIND HOW IT WAS BUILT
Make 1v1 Hoops and 3v3 Streetball excellent, with an optimized movement/
camera/control system, and an optimized multiplayer system. Two things had
to be decided honestly before writing code:

1. **This repo has never seen the existing 1v1/3v3 source** (established in
   M46's live audit — those routes run different code than everything M35–
   M47 rebuilt). Patching unknown files blind isn't credible. So these are
   **complete new implementations**, built on the same proven core
   (CharacterLibrary, clipRegistry, CameraDirector, GroundLock, gameFeel,
   SoundKit, EffectsKit) every other mode in this project already runs on —
   matched to the live HUD contract actually observed (`MOMENTUM`,
   `CAM FOLLOW`, `FIRST TO 11` for 1v1; `AST`, `TO 21`, a shot clock for
   3v3), so they should slot into the existing cards/routes.
2. **"Optimized multiplayer system" cannot mean real networked PvP here** —
   this repo has zero visibility into whatever backend Abacus runs (is there
   a WebSocket layer? a room/matchmaking model?), and shipping guessed
   netcode against unknown infrastructure would be worse than not shipping
   it. What's built instead, and is most of the actual engineering effort
   regardless of transport: **every body on the court is driven by a
   swappable `ControlSource`** (`PlayerSlot.ts`) — local input, AI, or a
   `NetworkInputSource` stub. Wiring a second real human into a slot later
   is "implement the stub against your transport," not "rewrite the game."
   This is the same honesty standard M46 already set for the T-pose fix on
   these modes — real engineering, clearly scoped, nothing oversold.

### FILES
| File | What it is |
|---|---|
| `files/core/PlayerSlot.ts` | **New.** The multiplayer-ready input abstraction — `Intent` (the one shape every control source produces), `LocalInputSource`, `AISource` + `AIBehavior`, `NetworkInputSource` (the transport integration seam, inert until wired). |
| `files/core/BasketballCore.ts` | **New.** The optimized movement/shooting/defense systems: `DribbleController` (momentum movement with a real crossover — a hard stick reversal within the reaction window snaps your turn and pops a speed burst), `ShotMeter` (a real green-window release timer that a defender's contest narrows and speeds up), `DefenderBrain` (denies the passing lane, occasional steal attempts), `TeammateBrain` (holds spacing, cuts to the rim when the lane clears — reads as team basketball without a full playbook system), `contestLevel()`. |
| `files/core/CameraDirector.ts` | v2.3 — adds `hoops` (tight isolation framing for 1v1) and `team` (wide full-flow framing so all six 3v3 bodies stay legible) presets. Everything else byte-identical to M42. |
| `files/modes/OneVOneMode.ts` | Full 1v1 Hoops: momentum meter with a real payoff (hot hand nudges make% up, small and capped), make-it-take-it possession, steal-to-turnover (possession reset, not a hard loss — arcade-fair), rebounds go to whoever's closer to the loose ball. First to 11. |
| `files/modes/ThreeVThreeMode.ts` | Full 3v3 Streetball: 2 AI teammates hold spacing/cut, pass to the most-open man, assists tracked when a pass immediately precedes a make. Defense on the other team's possession is a simulated, position-affected drive (your spacing measurably changes their make%) — see the scope note below. First to 21, 90-second shot clock. |

### WHAT "OPTIMIZED MOVEMENT/CAMERA/CONTROL" MEANS CONCRETELY HERE
- **Movement**: acceleration/deceleration curves instead of instant-velocity
  snapping, a turn-rate clamp so direction changes read as a body turning
  (not a mesh teleporting), and a genuine skill move — the crossover — that
  rewards a sharp, correctly-timed stick reversal with an instant reversal +
  speed pop, at the cost of the timing being real (mistime it, you just
  decelerate like normal).
- **Camera**: two new presets purpose-built for the two formats — tight and
  low for 1v1 isolation (broadcast iso-cam framing), wide and high for 3v3
  so a fast, spread-out possession never loses a body off-frame. Both
  inherit M42's occlusion handling and pitch clamps — no camera-in-wall
  regressions on the same court venue as Dunk Contest.
- **Controls**: the shot meter is a real timing skill (not a random-chance
  charge bar) with visible risk/reward — a tighter contest narrows the green
  zone AND speeds the marker up, so good defense makes shooting measurably
  harder, not just a lower hidden percentage.

### 3v3 SCOPE NOTE (said plainly, not buried)
A fully manual opposing offense — the AI team dribbling, passing among
themselves, and choosing shots the same way your team does — is a
substantially larger system than fits honestly alongside everything else in
this pass. What's shipped is a simulated possession where your team's
positioning at the moment of the "shot" measurably changes the outcome
(tighter defense = lower opponent make%), which reads as real defense
mattering without pretending to be a second full AI offense it isn't. If a
fully manual mirrored 3v3 AI offense is wanted, that's a clean, well-scoped
follow-up now that `TeammateBrain`/`DefenderBrain` exist as the building
blocks.

## ACCEPTANCE
1. **1v1**: dribble with momentum (no instant-velocity snapping), pull off a
   crossover with a sharp stick reversal, hold-and-release a shot inside the
   green zone for a clean make; a tightly contested shot visibly has a
   smaller, faster window than an open one. Momentum climbs on makes, drops
   on misses/turnovers. First to 11 ends the game with a result.
2. **3v3**: pass to an open teammate, watch them cut/shoot; assists tick up
   on an assisted bucket; the opposing possession resolves in a few seconds
   and your team's spacing visibly affects whether they score. First to 21
   or the shot clock expiring ends the game.
3. Both modes: zero T-pose (clipRegistry/`installSafePlay` throughout), hero
   always framed (`hoops`/`team` camera presets), no stalls on any phase.
4. `PlayerSlot`/`NetworkInputSource` compile and are wired into every body
   on both courts today via `LocalInputSource`/`AISource` — confirms the
   abstraction is real, not decorative, ahead of any future transport work.
