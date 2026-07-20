# M39 — BOARD SPORTS COMPLETE · skate / snowboard / surf rebuilt from zero

Copy this into Abacus with `files/` + `KNOWN-ERRORS.md`. Prerequisites: M35 +
M37 deployed. These three modes currently render **NOTHING** (E10 — flat
clear-color screen with a ticking HUD). This batch is a full rebuild.

---

## PROMPT FOR ABACUS

### LIVE AUDIT (July 2026, screenshots on file)
`/play/skateboard`, `/play/snowboard`, `/play/surf`: timer counts, score chip
renders, buttons draw — and the 3D view is a blank purple/gray void. No
terrain, no rider, no props ever spawn. These modes need their worlds, riders,
and gameplay built, not patched.

### FILES
| File | What it builds |
|---|---|
| `modes/rideWorlds.ts` | The missing worlds, fully procedural: skatepark (painted concrete, quarter pipes, funbox, two grindable rails), slope run (inclined piste with groomer lines, 12 slalom gates, 22 trees), surf break (painted water, travelling wave lip, shore). Zero external assets. |
| `modes/boardCore.ts` | Shared rider assembly (character + board mesh + M26 Rider physics on the world's ground meshes) and the TrickMachine: air tricks with spin tracking, clean-landing detection, bails, combo multipliers, grind banking. Refuses to build without ground meshes — E10 cannot silently recur. |
| `modes/SkateRunMode.ts` | 90s park runs: PUMP speed, POP ollies, KICKFLIP/HEELFLIP/GRAB airs, rail grinds, combo banking on clean landings. |
| `modes/SnowboardSlalomMode.ts` | Gravity-fed downhill through 12 gates: TUCK for speed, gate hits scored, JUMP/SPIN/GRAB airs, time bonus at the finish. |
| `modes/SurfBreakMode.ts` | Pocket-riding on a travelling wave: FLOW builds in the pocket, CUTBACK snap turns, AIR off the lip, wipeout + paddle-back when the lip catches you. |

### WIRING
1. `modeConfigs.ts`: add `export const RIDE_CONFIG = { heroUrl: HERO_URL };`
2. `modeVerbs.ts` (M35): keys must match live slugs — `skateboard`, rename
   `snowboard_slalom` → `snowboard`, `surf` (verb lists in each file footer).
3. Animation aliases: `board_ride_idle`, `board_air`, `board_tuck`,
   `board_grab`, `board_grind` — map to the closest real GLB clips in the M24
   alias table (fallback chain ends at `idle_stand`; the resolver logs any
   gap loudly — fix aliases, never ship a MISSING CLIP).
4. Modes register heroRef/objectiveRef (in the files) — FrameGuard + camera v2
   do the rest.
5. KNOWN-ERRORS regression sweep before promote.

## ACCEPTANCE (record each)
1. All three modes show a WORLD on frame one (park/piste/ocean) — E10 checks:
   `[FEL-SPAWN] <mode>: OK` in console for all three, zero blank frames.
2. Skate: PUMP → POP → KICKFLIP → clean landing banks a combo; a rail grind
   scores; bailed flip resets combo. 90s run ends with a score screen.
3. Snowboard: full descent — gates tick `n/12`, missed gate shows the banner,
   finish shows score + time bonus. Rider never floats or sinks (E5 family).
4. Surf: flow builds in the pocket, CUTBACK scores, lip catch = WIPEOUT +
   paddle-back reset, session ends at 0:00 with the score.
5. Hero framed throughout on all three (zero `[FEL-FRAME]`); touch overlay,
   keyboard, and gamepad all drive every verb.
