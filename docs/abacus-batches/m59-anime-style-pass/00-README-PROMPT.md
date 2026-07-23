# M59 — ANIME STYLE PASS: lighting, color grade & ink lines for ALL modes

Copy this into Abacus with every file in `files/`. Prerequisite: M44
deployed (LightRig/RenderPipeline already mounted per mode — both files
here REPLACE the M44 versions by filename; AnimeInk is NEW with one line of
wiring). Applies to EVERY 3D mode automatically.

---

## PROMPT FOR ABACUS

### The direction: "anime-ish lighting, color and art style for all modes"
Anime look, decomposed into the three things that actually create it —
each mapped onto infrastructure already live since M44, so the whole
restyle is two file replacements + one wiring line:

1. **LIGHT like a cel** (`LightRig.ts` v2) — flatter shading (fill raised
   against the key so faces hold one bright tone with a soft shadow side),
   bold complementary shadow tints, and the signature **RIM BACKLIGHT** —
   a per-mood tinted halo that pops characters off the background:
   golden hour gets a cool cyan edge, the dojo an ember-orange edge,
   the alpine slope an ice-blue crest, stadium night a neon magenta edge.
2. **GRADE like a key frame** (`RenderPipeline.ts` v2) — saturation pushed
   hard via color curves (+28…+45 per mood), contrast up, bloom threshold
   dropped so tinted light HALATES (the neon/sunset glow of every anime
   establishing shot), bolder vignettes framing the shot. flashBeat kept.
3. **INK the characters** (`AnimeInk.ts`, new) — Babylon's outline renderer
   draws a contour line (deep indigo, not dead black) around every SKINNED
   mesh, and a cel-flattening pass kills photoreal specular so glints come
   from the rim light only. `autoInk(scene)` inks every character that ever
   spawns — hero, rivals, mobs, the Yeti — automatically; painted venues
   stay painterly. Cel characters over painterly backgrounds is exactly
   the classic anime contrast.

All procedural, zero new assets, zero per-mode changes.

### FILES
| File | What it does |
|---|---|
| `files/visual/LightRig.ts` | v2 — rim backlight + cel-balanced fills per mood. Same class/API; REPLACES M44's. |
| `files/visual/RenderPipeline.ts` | v2 — saturation curves + halation bloom + bolder vignettes per mood. Same class/API; REPLACES M44's. |
| `files/visual/AnimeInk.ts` | **New.** Ink outlines + cel material flattening; `autoInk(scene)` needs one wiring line. |

### WIRING
1. Drop the two replacements in — LightRig/RenderPipeline mount exactly as
   they already do (constructors unchanged), so every mode restyles with no
   further changes.
2. ModeHarness, once per mode load: `const uninke = autoInk(scene);` and
   call the returned disposer on mode dispose. (Alternative: call
   `inkCharacter(spawn.meshes)` after each CharacterLibrary.spawn.)
3. Run the KNOWN-ERRORS regression sweep — visual pass only, but confirm
   framerate holds on the 6-character modes (3v3, Agent Waves); if a
   low-end profile is ever needed the M44 quality note still applies, and
   ink can be skipped per-character by not calling autoInk.

## ACCEPTANCE
1. Every 3D mode shows characters with a visible tinted rim/backlight edge
   and a drawn outline; no character reads as an unlit flat cutout.
2. Colors are noticeably bolder in every mood; stadium-night neon and
   golden-hour sky visibly bloom/halate.
3. Venues keep their painted look (no outlines on floors/props) —
   characters pop against them.
4. No mode's framerate visibly degrades vs. M44 baseline; all KNOWN-ERRORS
   sweeps stay green (this batch touches no gameplay logic).
