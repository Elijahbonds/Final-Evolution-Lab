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
