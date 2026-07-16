# FEL — Nexus Working Context (read before every task)

**Status: SUPREME governance doc as of 2026-07-15.** Where this conflicts with
NEXUS_HANDOFF_FOR_ABACUS.md, NEXUS_MONETIZATION_TRACK.md, NEXUS_COST_DOCTRINE.md,
or NEXUS_STUDIO_VISION.md, THIS DOC WINS. (See "Reconciliation" at bottom.)

## Stack (LOCKED — do not substitute)
- Runtime: Babylon.js in the browser (TypeScript). NOT a custom C++ engine.
  Ignore any instruction referencing C++20, custom memory pools, .cpp files,
  or manual cache-line/DOD memory layout — those do not apply to this repo.
- Physics: Havok plugin for Babylon.js.
- Assets: glTF/GLB only (Meshy → Blender). Animations via Babylon
  AnimationGroups + skeleton blend weighting.
- Deploy: Vercel CD from GitHub (github.com/Elijahbonds/Final-Evolution-Lab).
  ML endpoints: Abacus AI (never blocks the play loop).
- Shipping form: PWA now, native wrapper later.

## Nexus = orchestration layer, not a from-scratch engine
Nexus is a prompt-to-scene / mode-orchestration layer ON TOP of Babylon.js.
Do not rebuild rendering, physics, or skinning. Compose Babylon primitives.

## The one architectural rule
Every mode is the SAME core loop with different rules. Build the spine once;
each mode is a thin module implementing IGameMode:
  init() · update(dt, input) · onScore() · onFail() · getState() · teardown()
ModeManager swaps modes without touching the loop. Adding a mode NEVER edits
another mode. Reject any change that puts mode-specific logic in the core loop.

## Folder ownership (respect boundaries)
/core    loop · input · camera · loader · ModeManager   ← never mode-specific
/systems stateMachine · animationSelector · scoring · gamebreaker · judge
         · sensoryBus · feelConfig                        ← shared, mode-agnostic
/modes   one file per mode, implements IGameMode
/net     matchmaking · leaderboard · presence
/shop    marketplace · inventory · entitlements

## The 4 movement archetypes (why 23 modes isn't 23 engines)
1. Court/free-3D — dunk, basketball, karate, football, story
2. Ride/carve   — skateboarding, surfing, snowboarding
3. Court-rally  — tennis, volleyball, soccer
4. Rhythm/UI    — music, dance, art, brain brawl, who scene it, carnival
Build a core once per archetype; modes are skins on top.

## Current priority (FIREWALL — do not drift)
- ✅ 2026-07-15: Dunk feel gate CALLED by Elijah — feel work STOPPED per DoD
  (6 systems + standing test suite shipped, commits 187f0d8..d507fda).
- CURRENT: IRL H2H slice — video dunk runs, Mirror Triumph (beat your own
  verified best), same-device couch H2H. LOCAL-ONLY v1 (likeness video never
  leaves the device), zero money (REAL_MONEY_COMPETITION stays off), server
  seams typed to the Abacus competition API for later connection.
- Still true: no animation retarget spend or visual polish; Nexus/Cell
  productization POST-FEL; one slice at a time — grows past IRL H2H → STOP.

## Feel philosophy (this is the real target)
"Console feel" here = perceived responsiveness + weight, achieved with
web-appropriate techniques: fixed-timestep physics, input buffering,
hybrid animation/physics blending, variable gravity, and a frame-synced
sensory (visual/audio/haptic) event bus. NOT native-memory tricks.

## Determinism & loop
- Physics on a FIXED timestep (start 60 Hz) via an accumulator, decoupled
  from render; interpolate render state between physics steps.
- No object allocation inside the per-frame update loop (GC spikes = jank).
  Pool reusable objects; hoist allocations out of update().
- Use Babylon InstancedMesh + thin instances for repeated geometry.

## Compliance (carry across every task)
- Assets: original/placeholder only for any real likeness; commercial-safe
  licenses (paid-tier Meshy, not CC BY Free) — flag unconfirmed licenses.
- Soft currency ONLY in v1 ship track (LC earned, never purchased). Real-money
  rails exist but stay flag-dormant (see Reconciliation).

## Definition of Done — Dunk Contest core loop
Proven with PLACEHOLDER assets (capsules/cubes) when ALL are true:
- Jump fires within 1 physics step, every time, even mid-animation (buffer).
- Same input → same arc at 30/60/144 fps (fixed timestep confirmed).
- Zero allocations inside update() during a full dunk.
- Ascent light, peak hangs, descent snaps (variable gravity FELT).
- Landing thud: camera shake + audio + hit-stop on the SAME contact frame.
- Never floaty AND never jerky at animation→physics handback.
- Approach angle/side/distance/charge predictably select different dunks.
- Full loop repeatable 10x with no state leak.
- Judge score deterministic locally; Abacus style-multiplier optional,
  never blocks.
- THE GATE: Elijah does 10 dunks and wants an 11th. Then STOP feel work.
Out of scope for the gate: final models, retargets, textured environments,
crowd/lighting/VFX/menu polish, any other mode.

## Reconciliation with earlier docs (what this supersedes)
1. RUNTIME SPLIT: the GitHub repo's Babylon slice (frontend/src/game,
   /play/dunk) is the PRIMARY product line under this context. The Abacus
   platform app (three.js/R3F, abacus-app/ sync) remains the deployed demo
   + money-rails testbed; tasks sent to Abacus must be written for R3F —
   never tell Abacus "Babylon/Havok".
2. MONETIZATION: v1 ship = Creator Card soft-currency economy (LC). The
   Stripe/real-money Tracks A–C code in abacus-app stays built but DORMANT;
   no real-money path ships in v1. REAL_MONEY_COMPETITION stays off.
3. NEXUS/CELL PRODUCTIZATION: post-FEL. No new scaffolding. Existing studio/
   CELL code is inventory, not an active track.
4. C++ ENGINE TREES (app/gameplay, engine/): donor/spec material only.
   No new C++ work. The cmake gate remains only to keep existing tests green
   if those trees are touched.
5. COST DOCTRINE still applies (deterministic runtime, budget caps, denylist,
   ML never in the play loop).
