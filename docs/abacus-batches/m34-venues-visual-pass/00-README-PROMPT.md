# M34 — UNBREAK ALL MODES + VISUAL ENHANCEMENT PASS + COACH DEMOS

Copy this document into Abacus with every file in `files/`. Live-audited fix:
per-mode diagnosis below, code fixes included for all of it.

---

## PROMPT FOR ABACUS

### LIVE DIAGNOSIS (July 2026, all modes tested on the deployed link)
Every mode boots to TAP TO START and then loops: console shows
`[FEL-WATCHDOG] still black after rescue — surfacing error` on dunk, karate,
football, skateboard. Two compounding causes, both fixed here:

1. **Watchdog false-positive path:** `engine.readPixels` on an interval reads
   the framebuffer mid-pipeline (with DefaultRenderingPipeline active it can
   sample a cleared/intermediate buffer) → black verdicts even when the final
   composite isn't black → error/retry loop that makes every mode unplayable.
   → `files/hotfix/RenderWatchdog.ts` (v2): samples the FINAL composited
   output via a 64×64 `Tools.CreateScreenshot` (post-processing-aware), and
   only arms during the `playing` phase (never during splash/ready).
2. **The scenes are genuinely near-black anyway:** the current Babylon modes
   load characters but NO environment — no ground, no walls, no props. The
   camera frames characters floating in clear-color void.
   → `files/visual/VenueKit.ts`: procedural venues for every mode family —
   real ground, venue-box walls, and signature props, built from dynamic
   textures (zero external assets, so it ships today and GLB venues can
   replace pieces later without code changes).

### PER-MODE FIX LIST (wire `load()` in each ModeDefinition)
| Mode | Fix |
|---|---|
| Dunk | `VenueKit.buildCourt(scene,'venice')` — blacktop + painted key/arc, hoop w/ backboard+rim+net, boardwalk wall, bleacher wall, palm silhouettes, ocean horizon plane |
| Karate | `VenueKit.buildDojo(scene)` — tatami floor grid, 4 walls w/ beams, lanterns (emissive), OFF-CENTER pillars (never between cam and mat) |
| Football | `VenueKit.buildGridiron(scene)` — turf + yard lines every 10 + numbers, end zone, floodlight glow quads, bleacher walls |
| Skate | `VenueKit.buildPark(scene)` — concrete + painted lines, ramps/rails from the config's GrindLine data, graffiti wall panels |
| Snowboard | `VenueKit.buildSlope(scene)` — snow gradient ground, tree silhouette rows, gate flags, lift pylon+cable line (matches the grindable cable) |
| Tennis/Golf/Derby/Penalty | `VenueKit.buildField(scene, preset)` — surface color + boundary lines + venue box per preset |
| ALL | Watchdog v2 replaces v1; `EffectsKit.ambient(scene, family)` adds the living layer |

### VISUAL ENHANCEMENT PASS (`files/visual/EffectsKit.ts`)
Graphics/effects/variety on top of the venues:
- **Ambient motion per family:** drifting petals (dojo), seagull sprites +
  ocean shimmer (venice), snowfall (slope), floodlight moths (gridiron) —
  billboarded particles, pooled, <1ms.
- **Gameplay FX:** ball comet trail, landing dust bursts, grind sparks, net
  splash, confetti burst for wins — one-call helpers wired from mode events.
- **Material variety:** `varyCrowd()` tints bleacher crowd quads in 6-color
  batches so venues never look flat-cloned.

### COACH SECTION — EXERCISE DEMOS (`files/coach/ExerciseDemo.tsx`)
Every exercise in the Coach/plan views must SHOW the movement:
- **AVATAR tab (default):** the user's own avatar performs the exercise —
  reuses M17 `ExerciseMoviePlayer` + the character pipeline (M31), so demos
  show THEIR look.
- **VIDEO tab:** plays `videoUrl` when the exercise has one (founder-recorded
  clips — the `exerciseLibrary` entries gain an optional `videoUrl`; drop files
  in `/videos/exercises/{id}.mp4` and they light up automatically).
- Both present = tab toggle; neither missing state ever blank: falls back to
  cue-card view with the animated diagram strip.
Wire into: plan viewer (M17), Coach tab exercise lists, seminar/class detail
pages.

## ACCEPTANCE
1. All four audited modes reach PLAYING and stay there ≥60s with zero
   `[FEL-WATCHDOG]` errors and zero `[FEL-ANIM] MISSING CLIP` (M30 must also
   be deployed).
2. Recorded clips per mode showing the venue: dunk (hoop/court/boardwalk),
   karate (tatami/lanterns, pillars never occlude), football (yard lines/
   end zone), skate (ramps+rails visible), snowboard (slope/gates/lift line).
3. Ambient layer visibly alive in dunk + dojo + slope; ball trail in dunk;
   dust on landings.
4. Coach: an exercise with video shows AVATAR/VIDEO tabs (both work); one
   without video shows the avatar demo; network log confirms avatar demos
   render locally.
5. Forced-black test (kill all lights in dev console): watchdog v2 rescues or
   errors WITHOUT ever looping a playable scene.
