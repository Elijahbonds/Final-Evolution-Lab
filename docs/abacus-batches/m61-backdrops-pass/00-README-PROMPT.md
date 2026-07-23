# M61 — BACKDROPS PASS: painted skies, horizons & living backgrounds for every mode

Copy this into Abacus with the file in `files/`. Prerequisite: M44 (mounts
alongside LightRig/RenderPipeline in the harness), pairs with M59's anime
grade. One NEW file, one wiring line.

---

## PROMPT FOR ABACUS

### The request: "enhance the backgrounds for each mode — visuals, views, wallpapers"
Today most modes end at the venue walls or a flat clear color. This batch
gives every mode a real painted WORLD beyond the playfield — all
procedural (DynamicTexture painting, zero image assets), styled to sit
under M59's anime grade like background art under cels:

| Family | Sky dome | Horizon ring |
|---|---|---|
| `venice` (golden hour) | indigo→magenta→orange sunset, sun disc + glow, pink clouds | lit-window city skyline behind palm silhouettes |
| `ocean` (surf) | blue day sky, white clouds | headland, whitecaps, sailboat silhouettes |
| `dojo` | deep night blues, moon, 130 stars | twin mountain ridges + pagoda silhouettes with lit windows |
| `alpine` | crisp blue noon, big clouds | snow-capped far peaks, nearer ridge, pine treeline |
| `stadium` (night) | near-black violet, 170 stars | upper-bowl silhouette with shimmering crowd rows + six glowing light towers |
| `park` (default) | violet→coral dusk | skyline + round treeline |

Each backdrop is three layers: a painted SKY DOME (inside-out sphere), a
silhouette HORIZON RING (windows/snow/glow painted in), and DRIFT — the
dome slow-rotates so clouds and stars visibly live. Unlit/emissive
throughout: immune to scene lights, can't catch shadows, adds exactly two
meshes and one rotation per frame.

### FILES
| File | What it does |
|---|---|
| `files/visual/Backdrops.ts` | **New.** `mountBackdrop(scene, family)` + `MOOD_TO_FAMILY` map + all six painted families. |

### WIRING
1. ModeHarness, right after the venue builds:
   `const backdrop = mountBackdrop(scene, MOOD_TO_FAMILY[modeConfig.mood] ?? 'park');`
   and `backdrop.dispose()` on mode dispose.
2. Recommended per-venue overrides (mood is broader than the place):
   surf → `'ocean'`, snowboard/big-air → `'alpine'`, karate modes →
   `'dojo'`, football → `'stadium'`.
3. Run the KNOWN-ERRORS sweep — visual-only, but confirm FrameGuard mesh
   counts still pass (backdrop adds 2 meshes before the venue's minimums).

## ACCEPTANCE
1. Every 3D mode shows a painted sky and horizon in every camera direction
   — no flat clear-color void anywhere, including when the camera whips
   during dodges/replays.
2. Venice modes: sunset + skyline + palms. Surf: open sea + sailboats.
   Dojo: stars + pagodas with lit windows. Alpine: snow-capped peaks.
   Football: stadium bowl + six blazing light towers. Clouds/stars drift
   visibly over ~60s.
3. Backdrop never occludes gameplay (radius 470-560 sits outside every
   venue), never catches shadows, and frame rate holds vs. M59 baseline.
