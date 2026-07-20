# M44 — VISUAL & LIGHTING PASS + MAP-SIZE FIXES

Copy this into Abacus with every file in `files/`. Prerequisite: M42 and M43
deployed (this batch's mode files are the M43 versions with lighting/effects/
map-size changes layered in — each still REPLACES its predecessor by
filename).

---

## PROMPT FOR ABACUS

### WHAT "VISUALS AND GRAPHICS" AUDIT FOUND
Every mode's geometry, colors, and shapes are deliberate and thematically
right (Venice sunset court, dojo tatami, snowy piste) — but the RENDERING is
flat: no directional light or shadows (characters read as stickers pasted on
the ground, not objects standing in a lit space), no anti-aliasing, no bloom
on the obvious highlight surfaces (backboard, floodlights, lanterns), and no
color grading — the "golden hour" mood is currently just a sky-gradient
texture, not something the whole frame is graded toward. Separately, a
dimension audit against the actual gameplay mechanics found two real
map-size bugs (below) — not visual, but found in the same pass and fixed
here since they compound with visual polish (a great-looking field you can
outrun the boundaries of isn't actually fixed).

### FILES
| File | What it does |
|---|---|
| `files/visual/LightRig.ts` | **New.** A real light rig per scene: hemispheric ambient fill + a shadow-casting directional key light, mood-matched to the mood strings every mode already declares (goldenHour/dojoWarm/alpineNoon/stadiumNight). Casters/receivers are auto-classified by mesh name (ground/floor/court/etc. → receiver, everything else → caster) so **no mode file needs to change** for shadows to appear. |
| `files/visual/RenderPipeline.ts` | **New.** Babylon's `DefaultRenderingPipeline`: bloom on bright surfaces, FXAA anti-aliasing, a sharpen pass, and mood-tuned exposure/contrast/vignette so each venue's mood is a real grade, not just a sky color. Includes an optional `flashBeat()` for highlight moments. |
| `files/modes/*.ts` (8 files) | The M43 versions with `EffectsKit` wired at each mode's signature payoff moment — dunk flush/streak, karate finisher/KO, football tackle/touchdown, board-sport trick landings/bails/grinds, snowboard gates, surf wipeouts, golf hole-outs, baseball dingers, soccer goals — plus ambient particles per venue family (petals in the dojo, snowfall on the slope, gulls over the water) using the M34 `EffectsKit`/`ambient()`/`burst()` API that was built but never called from any mode. Also contains the two map-size fixes below. |

### MAP-SIZE FIXES (found auditing venue dimensions against gameplay)
1. **Football (`FootballRushMode.ts`)**: `VenueKit.buildGridiron`'s field is
   90 units long (z ∈ [-45, 45]), but the touchdown trigger required running
   91.44 units (a literal 100-yard field) from spawn — the runner would hit
   the back wall and run out of visible field at less than half that
   distance. Defenders could also spawn up to 61 units ahead — past the wall,
   off the rendered field entirely. Fixed: touchdown now fires at 40 units
   (≈43.7 yards, inside the real field with margin), defender spawn depth is
   capped to whatever field actually remains, and defender COUNT now scales
   with total drive progress instead of the per-down yardage counter (which
   reset every first down and effectively never escalated).
2. **Surf (`SurfBreakMode.ts`)**: the wave's z-position wraps every 140 units
   of travel, but the rider's own position never did — a player skilled
   enough to never wipe out (the only thing that used to re-anchor position)
   would ride straight off the edge of the 220-unit water plane and spend
   the rest of the session coasting over empty space. Fixed: the rider now
   wraps by the same 140 units at the exact moment the wave does, keeping
   the rider↔wave distance (the only thing gameplay/scoring reads) perfectly
   continuous while bounding world-space position.

### WIRING
1. Drop every file in — mode files REPLACE their M43 predecessors by
   filename; `LightRig.ts`/`RenderPipeline.ts` are new.
2. ModeHarness, once per mode load (after the venue/world is built and the
   camera exists):
   ```
   const lightRig = new LightRig(scene, modeConfig.mood);
   const renderFx = new RenderPipeline(scene, [camera], modeConfig.mood);
   ```
   and on mode dispose: `lightRig.dispose(); renderFx.dispose();`
3. No other mode-file changes required for lighting/post-processing — the
   name-based auto-classification and the pipeline both work off what's
   already in the scene.
4. Run the KNOWN-ERRORS regression sweep.

## ACCEPTANCE
1. **Shadow check**: every mode shows a visible ground shadow under the
   hero character, moving/rotating correctly as they move.
2. **Grade check**: karate reads visibly warmer/darker than golf's bright
   alpine noon; stadium-night modes (football/soccer) show visible bloom on
   floodlights.
3. **Effects check**: a made dunk shows a net burst; a karate KO puffs dust;
   a football tackle puffs dust and a touchdown bursts confetti; a clean
   board-sport trick landing puffs dust at the feet, a bail does too; a
   snowboard gate sparks; golf/baseball/soccer show confetti/sparks on their
   best outcomes.
3. **Football map check**: play a full drive to a touchdown — it fires well
   before the runner reaches the back wall, and defenders are always visible
   on the rendered field, never spawning past it.
4. **Surf map check**: ride in the pocket without wiping out for the full
   90 seconds — the rider stays visually near the wave and the world the
   entire time, no drifting into empty space.
