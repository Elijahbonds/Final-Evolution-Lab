# M55 — PHASE 5: board & action sports (barreling surf, yeti slope, expanded skatepark) + gymnastics audit

Copy this into Abacus with every file in `files/`. Prerequisites: M42
(GroundRide/clipRegistry), M45 (MobSteering, Pickups). Files REPLACE their
predecessors by filename. `boardCore.ts` and `GroundRide.ts` are untouched.

---

## PROMPT FOR ABACUS

### rideWorlds v3 — all three worlds built out (all procedural, zero assets)
- **Skatepark v2** — grows 46→70 units: a BOWL (octagon of inward-tilted
  banks you can carve and drop into), a DOWNHILL STRAIGHT (long descending
  lane that builds real speed), two quarter-pipes, a second funbox, five
  rails (was two) with escalating bonuses (180/180/220/260/300 — the
  kinked transfer pair pays most).
- **Slope v2** — ROCKS on the piste (real obstacles), three down-slope
  RAILS (snowboarding finally grinds), two KICKERS, and a SKI-LIFT: pylons,
  hanging chairs, and a cable that is itself a 400-point grind line —
  launch off the second kicker to reach it.
- **Surf v3** — the wave CURLS: a translucent funnel shell arcs over the
  pocket and breathes on an 18s cycle (8s open) — you can see when the
  wave is hollow. Four BUOYS dot the lineup as obstacles.
- Contract addition: `RideWorld.obstacles` (pos+radius list).

### SnowboardSlalomMode v5 — obstacles, grinds, the lift, and THE YETI
- Rocks: grounded contact = stumble (-50, hard speed cut, brief i-frames);
  JUMP clears them clean.
- Rails + lift cable: JUMP in the air near a line locks a grind (same flow
  as Skate Run); the cable pays 400 with its own "LIFT CABLE GRIND!" call.
- **The Yeti** — an original FEL creature (oversized frost-tinted pursuer,
  no franchise likeness): after gate 5 it bursts from the treeline with a
  roar and chases for up to 8s. Airborne/grinding when it lunges = +150
  "CLEARED THE YETI"; caught grounded = tumble, -100. One appearance per
  run, chase window watchdog-bounded, always despawns clean.

### SurfBreakMode v5 — barrel scoring + buoys
- Pocket riding while the tube is open: flow gain and score trickle both
  ×2, "IN THE BARREL". Hold it ≥1.5s and exiting (tube closes, you drift
  out, or even a wipeout after earning it) banks +250 "BARRELED!".
- Buoy contact = wipeout (same recovery flow as falling behind the wave).
- `barrels` count added to end-of-session stats.

### SkateRunMode v5 — riding the expanded park
- Bounds widened to the new park; coin lines routed down the downhill
  straight and arced over the bowl rim (the risk lines pay).
- Fixed a real M45 bug: grinds always credited rail #1's 180 bonus
  regardless of which rail you locked — credit now goes to the nearest
  line, so the 260/300 transfer rails and the downhill rail actually pay.

### GYMNASTICS AUDIT (the Phase 5 assessment item — no code shipped)
Live check of `/play/gymnastics`: it's **The Vault** (Pacifica Gymnastics) —
a self-contained rhythm minigame: alternate ←/→ to sprint the run-up, ↑ to
flip, ↓ to stick the landing, two vaults, 800+ for gold. Clean intro card,
clear instructions, no console errors, no visible defects. Its source is in
the unseen-variant category (M46), and as a short-burst rhythm game it's
exactly the Court Carnival event shape. Verdict: leave as-is; candidate for
a future Carnival event slot rather than a rebuild.

### FILES
| File | What it does |
|---|---|
| `files/modes/rideWorlds.ts` | v3 — all three world builders upgraded + `obstacles` contract. |
| `files/modes/SnowboardSlalomMode.ts` | v5 — rocks, rail/cable grinds, the Yeti. |
| `files/modes/SurfBreakMode.ts` | v5 — barrel cycle scoring, buoy wipeouts. |
| `files/modes/SkateRunMode.ts` | v5 — expanded-park bounds/coins, correct per-rail grind credit. |

### WIRING
1. Drop every file in — each REPLACES its predecessor by filename.
2. No modeVerbs/TouchOverlay changes — every new action reuses existing
   bindings (JUMP grinds, trigger tucks/pumps).
3. Run the KNOWN-ERRORS regression sweep — especially sweep #6 (ride-mode
   floor check) since all three worlds changed geometry.

## ACCEPTANCE
1. Skate: bomb the downhill lane — visible speed gain; grind the kinked
   transfer — banner shows its 260/300 bonus, not 180. Carve the bowl banks.
2. Snowboard: hit a rock grounded — stumble, -50; jump the same rock —
   clean. Grind a piste rail. Launch the second kicker into the lift cable —
   "LIFT CABLE GRIND!" +400.
3. Snowboard: after gate 5, the Yeti bursts out with a roar and chases;
   jumping its lunge pays +150; getting caught grounded costs 100 and cuts
   your speed. It never appears twice and never outstays 8 seconds.
4. Surf: the funnel shell visibly opens/closes on a cycle; riding the
   pocket while open shows "IN THE BARREL" and doubles flow gain; holding
   1.5s+ then exiting banks "BARRELED! +250". Hitting a buoy wipes out.
5. All three modes: 60s floor-check sweep — no rider ever below the venue
   floor (GroundRide v3 guarantees hold on the new geometry).
