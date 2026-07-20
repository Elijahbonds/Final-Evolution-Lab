# M26 · BABYLON BATCH 2 — SHARED GAME FRAMEWORK (10 files)

Drop into Abacus AFTER M24 Batch 1 (animation core). This is the framework that
makes every mode a thin config: P1/P2 of your phased plan. Batch 3 (M27) contains
the modes themselves.

---

## PROMPT FOR ABACUS

Install this batch as the shared Babylon game framework, exactly per your phased
plan ("P1 shared cores, P2 CharacterLibrary"). It depends on M24 Batch 1
(CharacterAnimator, clipResolver, authored clips, LightRig, ballRig,
DunkReplayCam). Nothing here touches live three.js modes — it stands up alongside
them (your P8 strategy).

## FILES
| File | Purpose |
|---|---|
| `files/core/CharacterLibrary.ts` | Load/cache baked-clip GLBs; spawn characters w/ animator + look layers |
| `files/core/ModeHarness.ts` | Scene boot, READY gate + 3-2-1, pause, session lifecycle → SessionResult |
| `files/core/CameraDirector.ts` | Follow / Cinematic / Fixed cams with framing + occlusion constraints |
| `files/core/InputBus.ts` | Normalized FelInput events: keyboard + touch overlay + Gamepad API |
| `files/core/BallPhysics.ts` | Shared ball: gravity, bounce, swept-sphere collision (tennis fix) |
| `files/core/Pickups.ts` | Coin lines/arcs, magnet radius, server-capped collection |
| `files/core/MobSteering.ts` | Pursuit/containment steering + chase AI (defenders, yeti) |
| `files/core/GroundRide.ts` | Board-sport ground snap, carve physics, air detection, grind lines |
| `files/core/sessionResult.ts` | SessionResult contract + reporter (raw stats only — server mints rewards) |
| `files/index.ts` | Barrel + wiring cheat-sheet |

## WIRING
1. Both batches live under one module root (e.g. `src/fel3d/`): batch 1 `anim/` +
   `scene/`, batch 2 `core/`.
2. `CharacterLibrary.load(scene, url)` per character asset; `spawn()` returns
   `{ root, skeleton, animator }` with authored clips registered — the ONLY way
   modes create characters. Register every humanoid asset here (hero, enemy
   variants, defenders, yeti when its GLB lands; library falls back to tinted
   hero variants until then — never capsules).
3. `ModeHarness.run(config)` is the entry every Babylon mode uses: it mounts
   LightRig (mood), builds the InputBus, enforces the READY gate, runs the mode's
   `update(dt)`, and emits SessionResult to the existing result-screen flow.
4. `InputBus`: game logic subscribes to events only — no direct key/touch reads
   (M13-02/console-shell rule). Gamepad hot-plug auto-hides touch overlay.
5. `BallPhysics.sweptHit()` is the tennis/racket fix — use it for EVERY fast
   projectile vs thin collider.
6. Keep all of batch-1's acceptance (zero MISSING CLIP, no black frames).

## ACCEPTANCE (this batch alone)
- A test scene spawns 3 library characters (different tints), each playing
  different clips simultaneously, lit by LightRig, at 60fps.
- READY gate blocks input, 3-2-1 runs, pause/resume works, quitting emits a
  SessionResult with zero rewards minted client-side.
- Keyboard, touch overlay stub, and a physical gamepad all drive the same
  FelInput events (log inspector proof).
