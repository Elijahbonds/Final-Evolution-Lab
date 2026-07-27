# Journal — Claude Code (cloud)

Append-only. Only this agent writes here. Newest entries at the BOTTOM.
Format is defined in `docs/AGENT-ACCESS-AND-PROTOCOL.md` Rule 3.

---

## 2026-07-26T21:10Z · claude-cloud
DID: M80 external animation pipeline — ExternalClipLoader, clipManifest, PoseProbe, boneNames, clip_check.mjs, conform_clips.sh
TOUCHED: docs/abacus-batches/m80-external-animation/**
FOUND: VERIFIED zero character/animation assets in the project; no code path could load one. Prefixed bone names animate nothing and look identical to a T-pose.
NEEDS: claude-mini — install Blender and run tools/conform_clips.sh on one DeepMotion export. Nothing else in the fleet can do this.
NEEDS: abacus — serve assets/ready/anim/ at /assets/ready/anim and call loadClipPack() after clip registration.
NEXT: movement and route-teardown diagnosis

## 2026-07-26T22:05Z · claude-cloud
DID: docs/BLUEPRINT.md and docs/AGENT-ACCESS-AND-PROTOCOL.md — root-caused all five open defects, per-mode vision for 25 modes, PRQ/multiplayer/accessibility plans, build order
TOUCHED: docs/BLUEPRINT.md, docs/AGENT-ACCESS-AND-PROTOCOL.md, docs/agents/**, tools/agent_sync.mjs
FOUND: VERIFIED LocalInputSource sets sprint from hypot(moveX,moveY) > 0.85 while keyboard WASD emits magnitude 1.0 — the player is always sprinting, there is no walk. Diagonals are 41% faster (no normalization). held-key set is never cleared on blur, so alt-tabbing while moving runs the character forever.
FOUND: INFERRED runMode() awaits def.load() before returning its disposer, so a route change during load leaks the engine and its WebGL context. Browsers cap contexts at ~8-16; only a page reload frees them. This matches "refresh to load each time" exactly.
FOUND: VERIFIED the web app writes PRQ (SessionResult POST) but never reads it. PRQDrivenDDA exists only in the retired Swift app, so PRQ affects zero frames of gameplay.
FOUND: VERIFIED accessibility coverage is one line about contrast. No reduced-motion, remapping, captions, or colorblind support anywhere.
NEEDS: elijah — send docs/ACCESS-SETUP.md's paste block to Abacus. Two of three agents cannot see the app source.
NEEDS: abacus — confirm which Babylon major version the app is on (LoadAssetContainerAsync moved between 7 and 8).
NEEDS: claude-mini — grep the live app source for whether movement is camera-relative (BLUEPRINT §1.2i). May outrank every other movement fix.
NEXT: awaiting direction — build MotionModel (§1.2) or the route-teardown fix (§1.1)

## 2026-07-26T23:30Z · claude-cloud
DID: M81 feel foundation — MotionModel, inputCore, InputBus v3, Teardown, ModeHarness v3, DDA, game-surface.css. 157 tests pass by execution (61 motion + 96 foundation).
DID: docs/ONE-SHOT-BUILD.md — paste-ready prompts for claude-mini and abacus
TOUCHED: docs/abacus-batches/m81-feel-foundation/**, docs/ONE-SHOT-BUILD.md, tools/verify_batch.mjs
FOUND: VERIFIED Swift's tier band is 0.75..<0.9 -> ELITE and PRQ.default is 75, so a brand-new account starts at ELITE and meets elite AI on its first match. Ported faithfully and pinned by test; it is a product decision, not a code one.
FOUND: VERIFIED M29's harness has the same engine-leak shape as M26, and its 20s load watchdog makes the unguarded window LONGER, not shorter.
NEEDS: claude-mini — run the WebGL context-count snippet (BLUEPRINT §1.1) on the live app before applying M81's harness change. The leak diagnosis is INFERRED and must be confirmed or refuted.
NEEDS: claude-mini — review M81 for three specific assumptions: ctx.camDirector.yawDeg exists, the Babylon major version, and that PlayerSlot no longer derives sprint from stick magnitude.
NEEDS: abacus — M81 has one breaking change: runMode() is no longer async. runModeLegacy() stages the migration.
NEXT: awaiting playtest results before tuning MotionModel constants

## 2026-07-27T01:15Z · claude-cloud
DID: M82 accessibility and PRQ visibility — prqWeights (canonical JSON + 4-way parity test), a11y settings store, caption bus, colourblind-safe palette, AccessibilityPanel, PrqMeter. 92 tests pass (26 parity + 66 a11y).
DID: patched backend/routers/games.py PRQ_MODE_WEIGHTS to the canonical table
TOUCHED: docs/abacus-batches/m82-accessibility-and-prq/**, backend/routers/games.py
FOUND: VERIFIED the Swift and Python PRQ weight tables had silently diverged on five modes. Same session, different PRQ delta depending on which platform scored it: who_scene_it 0.7 vs 1.1 (57%), brain_brawl 0.8 vs 1.1 (37%), court_carnival 0.9 vs 1.15 (28%), skateboarding and snowboarding 1.0 vs 1.05.
FOUND: VERIFIED market_browse was absent from the backend table entirely, so it fell through to the 1.0 default — browsing the shop minted PRQ at the same rate as playing baseball. Now pinned at exactly 0.0 with a test.
FOUND: VERIFIED accessibility coverage across the product was one line about contrast. No reduced motion, remapping, captions, or colourblind support anywhere.
NEEDS: elijah — the five weight changes are all increases, no nerfs, but which direction to converge is a product call. Edit config/prqWeights.json to override.
NEEDS: abacus — confirm whether backend/routers/games.py in this repo is what you actually deploy. If not, the weight patch must be applied there too or the divergence persists.
NEXT: Wave 3 — deterministic fixed timestep, then ghost replay (BLUEPRINT §4 Phase A)

## 2026-07-27T03:40Z · claude-cloud
DID: M83 determinism and ghosts — FixedStep, Rng, Replay, GhostSource, SimLoop. 110 tests pass including a full record-replay round trip asserting bit-identical reproduction.
DID: tools/ts_resolve.mjs — resolve hook so executable tests can import batch source using the app's extensionless convention
TOUCHED: docs/abacus-batches/m83-determinism-and-ghosts/**, tools/ts_resolve.mjs
FOUND: VERIFIED a real desync in my own first FixedStep. 288 frames at 144Hz accumulate to 1.999999999999994 because 1/144 is not representable in binary float, so the 120th tick never fires. A 144Hz player drifts ~30 ticks per minute from a 60Hz player and any ghost recorded on one desyncs on the other. Fixed with a measured relative epsilon.
FOUND: three previous batches bent code to suit the Node ESM resolver (split a module, inlined a table, dropped an import). The resolver was the right place to fix it; ts_resolve.mjs removes the whole class of problem.
NEEDS: abacus — M83 machinery does nothing until modes migrate off variable dt and Math.random(). verifyDeterminism() is EXPECTED to fail on first run per mode; that is the tool working.
NEXT: 10-phase AAA pass, phase 1

## 2026-07-27T05:00Z · claude-cloud
DID: M84 Phase 1 of 10 — ModeKit (five subsystems, one object), tools/integration_audit.mjs, tools/fel_batch_alias.mjs, docs/TEN-PHASE-PLAN.md. 41 tests pass, testing the WIRING itself.
DID: fixed a real bug in tools/verify_batch.mjs — it compared an import of `FixedStep.ts` against a README declaring `FixedStep` and warned about prerequisites that were declared
TOUCHED: docs/abacus-batches/m84-phase1-integration-kit/**, tools/integration_audit.mjs, tools/fel_batch_alias.mjs, tools/verify_batch.mjs, docs/TEN-PHASE-PLAN.md
FOUND: VERIFIED the repo holds 49,400 lines of batch code across 84 batches, 98 mode files, 42 core modules — and zero of it has been observed executing in the real app. Authoring is not the bottleneck; integration verification is. Nine more phases at that rate produces 100k unverified lines instead of 50k.
NEEDS: claude-mini or abacus — run `node tools/integration_audit.mjs` against the live build and report how many subsystems are observably running. That number is worth more than the next phase of code.
NEEDS: abacus — migrate ONE mode (dunk) to ModeKit before phase 2. If it is not a net line REDUCTION the kit has the wrong shape and phases 2-6 are planned against a bad API.
NEXT: phase 2 — basketball, pending the dunk migration result

## 2026-07-27T06:30Z · claude-cloud
DID: M85 Phase 2 of 10 — basketball. DunkTiers (real vertical -> reachable dunks) and DefenseRead (a defender that commits and can be faked). 56 tests pass.
TOUCHED: docs/abacus-batches/m85-phase2-basketball/**
FOUND: VERIFIED the product thesis was never wired. irlDunkJudging (M33) measures jumpHeightCm from video and DunkMode (M63) scores difficulty/execution/style, and nothing connects them. A player's real vertical had zero effect on the flagship mode.
FOUND: VERIFIED BasketballCore.DefenderBrain calls Math.random() per frame, so no 1v1 possession can ever be replayed or audited. It also never commits, so it cannot be beaten by a move — only by speed.
FOUND: my own first test fixtures were physically wrong — a 188cm player with a 30-inch vertical expected to windmill. The model correctly said one-hand. Moved the fixture, not the model.
NEEDS: claude-mini — six of nine dunk clips do not exist (dunk_tomahawk, dunk_windmill, dunk_eastbay, finger_roll, dunk_one_hand, dunk_two_hand). Phase 2 unlocks dunks the game cannot yet show. Blender is on the Mini and nowhere else.
NEEDS: abacus — confirm how OneVOneMode tracks ball-handler lateral offset. If HandlerState is fed in the wrong basis the defender commits sideways.
NEXT: phase 3 — combat
