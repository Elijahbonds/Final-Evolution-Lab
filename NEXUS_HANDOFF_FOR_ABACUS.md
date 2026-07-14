# NEXUS — Handoff for Abacus (platform track)

---

## 🏀 WEB GAME TRACK — Dunk slice (updated 2026-07-14, commit 698d2eb)

**The playable dunk slice is now real.** Route `/play/dunk` mounts the Babylon.js
DunkingScene + premium HUD + virtual gamepad. Production build green, browser
smoke-tested. This is the v1 hero loop — protect it.

### What was just fixed (don't regress these)
1. **Duplicate-class corruption**: `DunkingMode.js`, `DunkingHUD.js`, `KarateMode.js`
   each contained TWO complete implementations (a "premium" pass was appended instead
   of replacing the baseline → duplicate `export default` = unparseable). Deduped to
   the premium versions with baseline compat hooks grafted back
   (`payload.position`, `payload.nearHoop`/`distanceToHoop`, `strikeType`/`damage`).
   **Rule: a rework REPLACES code, never appends beside it. Gate: no duplicate
   top-level exports (eslint-plugin-import catches this; `esbuild --bundle
   src/game/index.js` catches it too).**
2. **Orphaned game tree** (web twin of the recurring C++ orphan-source bug below):
   `frontend/src/game/` was imported by nothing, so Vercel builds passed while the
   game was unreachable and unparseable. Now mounted via `/play/dunk`
   (`components/PlayDunkPage.js`). **Rule: every new module must be reachable from
   an entry point; "builds green" proves nothing for unreachable code.**
3. **Babylon never loaded**: scenes imported `@babylonjs/core` via
   `new Function('return import(...)')` — invisible to webpack, silently fell back
   to a null engine. Now a real `import('@babylonjs/core')` in all 8 scenes.
4. **Dunks could never miss**: `_executeDunk` near-hoop check had
   `|| timeRemaining > 0` (always true mid-match). Real proximity gating restored
   (hoop at z=-13.23, threshold 2.5).
5. **Registry honesty**: `LIVE_MODE_IDS` = `basketball_dunk`, `karate` only. The 6
   other sport modes exist but are gated stubs until the dunk loop is proven fun.
   Re-add ids only as modes graduate.

### Current gaps (next work, in order)
- Player spawns at center court; scoring a dunk requires stick-walking to the hoop.
  Movement feel / spawn position / approach mechanics are the core "is it fun" work.
  **Timing-feel constants and fun-tuning are reserved for Elijah** — build the
  scaffolding, don't tune the numbers.
- No tests on `frontend/src/game/`. Minimum bar: headless smoke (instantiate
  DunkingMode with a stub scene, drive jump→move→dunk, assert score>0 near hoop and
  miss far away) + the esbuild bundle-check in CI.
- Karate mode is deduped and gated live but has no mounted route yet (`/play/karate`
  is the natural next slice once dunk is proven).
- HUD occupies a large corner on mobile; responsive pass pending.

### Scope guard (this branch drifted badly before repair)
Work that does NOT advance the playable dunk slice — new sport modes, C++
simulators, CELL/agent subsystems, marketplace lanes — goes to its own branch, not
here. The scope test for any commit on the game track: "does this make the dunk
loop more playable, more testable, or more fun?"

---

## 🤖 COPILOT BRANCH AUDIT — `copilot/improve-engine-and-app` (audited 2026-07-14)

13 commits, all authored 2026-07-14 by copilot-swe-agent, **forked from stale main
(`b5e1c0d`, Jul 6)** — it contains NONE of the platform-core repairs and none of the
web dunk-slice fixes above. Treat it as a donor branch to cherry-pick from, never a
merge source.

### Verified (I built it — headless cmake + ctest on the branch tip `70ffc30`)
- **C++ gate: 14/14 tests green**, including the new 331-line `nexus_net_test`.
- All 12 new `.cpp` files (engine/net + gameplay) ARE wired into CMakeLists this
  time — Copilot hit its own linker errors and fixed them (`0e16e25`). The orphan
  lesson finally stuck; keep enforcing it.

### What's on it (by value, highest first)
1. **Security fixes** (`d27781e`): timing-attack fix + PBKDF2 iterations in
   `backend/server.py`, strict-equality fixes in frontend. Small, real, wanted.
2. **Multiplayer architecture** (`engine/net`: NetSession / NetMessageBus /
   LocalMultiplayerRouter + gameplay matchmaking_client, remote_player_state,
   with tests). Honest framing: `useStubTransport{true}` — this is local/loopback
   architecture, NOT online play. Good foundation if multiplayer is on the roadmap.
3. **Gameplay C++**: collision engine, dribble engine wired into 3v3, PRQ
   defense/steal, BUMP button, character anim state machine, soccer/football-return
   modes, flight + rail-grind systems.
4. **Frontend**: dashboard overhaul, arena UX, education persistence, social
   improvements — on the main lineage, so `App.js` diverges ~479 lines from the
   repaired version here (which added `/play/dunk`). Conflicts are guaranteed;
   resolve toward THIS branch's App.js and re-apply their component changes.
5. **Story Mode + 3D board-game engine**, "Legends of the Boardwalk": scope drift —
   park it, don't port it.
6. `70ffc30` "fix dunk animation rig": regenerates Seeles FBX stubs as
   `nexusanim.json` keyframes for the **iOS/C++ asset pipeline** — it does NOT
   touch the web Babylon dunk slice.

### ⚠ Do not merge as-is
- **~300k of the 407k inserted lines are committed build artifacts**: complete
  `build-headless/` AND `build-story/` trees — CMakeCache with machine paths,
  third-party `_deps` sources, and compiled test BINARIES. Strip these entirely and
  add `build-*/` to `.gitignore` (only `NexusPrebuilt/` is ignored today).
- 102k lines of generated animation JSON are committed twice (`seeles_work/` and
  `seeles_unzipped/` duplicate trees).
- It removes the conflicting `ajv` override in `frontend/package.json` (same intent
  as the earlier Vercel fix `b947e83`) — fine, but verify the Vercel build after
  any port.

### Cherry-pick order for Abacus
1. `d27781e` security fixes (near-zero conflict risk).
2. `engine/net` library + `nexus_net_test` + CMake block, IF multiplayer is
   prioritized — as one clean commit, no build artifacts.
3. Education persistence + dashboard component changes, resolving App.js against
   this branch (preserve the `/play/dunk` route and PlayDunkPage import).
4. Gameplay C++ mechanics only when a mode that uses them is being proven —
   otherwise they're inventory, not progress.
Everything else (story mode, board game, committed artifacts): leave on the branch.

---


**Branch to work on:** `nexus/platform-core` (repo `Elijahbonds/Final-Evolution-Lab`).
Built on Copilot PR #166's lineage, **with the build repaired** — treat this branch
(not Copilot's) as canonical. Same arrangement as the web app: bulk development lands
here; you refine, extend, and keep it green.

## What Nexus is (scope)
The platform layer above the FEL game per the Education/CreatorCard spec's [NEXUS]
sections: **adaptive sequencing** (PRQ + mastery + readiness → per-session lesson
queue), **authoring pipeline** (versioned course builder with review gates),
**marketplace completion** (real-DB listings/orders/ratings + creator payout
ACCRUAL — no real money; provider stubbed), all fronted by a **versioned gateway**
(`/nexus/v1/*`) that the web app consumes, plus the C++ **CELL** learning subsystem
feeding the sequencer (curriculum advisor seam).

## Current state (honest)
- **Gate: full headless C++ build + ctest 14/14 green** (`cmake -S . -B build-gate
  -DNEXUS_HEADLESS=ON && cmake --build build-gate -j8 && ctest --test-dir build-gate`).
- Backend: FastAPI at `backend/app` (8 routers, Alembic 001 = 11 real tables,
  JWT+Firebase). `backend/routers/` is a LEGACY MOCK_DB tree being ported — don't
  build on it.
- CELL (`engine/cell`): real algorithms (SGD trainer, correlation research loop,
  decaying wisdom store, behavioral tests) — advanced scaffolding, hardening in
  progress.
- In flight (landing next on this branch): sequencer service + migration 002,
  authoring pipeline + 003, marketplace port + accrual + 004, CELL hardening +
  `curriculum_advisor` (cell.advisor.focus command), gateway façade +
  `docs/NEXUS_GATEWAY.md` (your API contract), `docs/NEXUS_PLATFORM_STATUS.md`
  (per-lane status + test counts).

## ⚠ The recurring bug that keeps breaking this repo
**Orphaned sources.** Three times now, commits added `.cpp` files referenced by
compiled code without listing them in a `CMakeLists.txt` target → undefined
symbols, test binaries can't link (fixed for: geval_scorer/web_auditor/doc_ingester;
movement_lab_mode; agent_executor/agent_swarm/agent_tool). **Every new C++ file must
be added to its target and the full gate run before commit.** Also: new gameplay
command prefixes must be added to the dispatch allowlist in
`app/gameplay/src/gameplay_application.cpp` (movement_lab was handled but unrouted),
and registry-size assertions in tests must move with the registry.

## Rules of engagement (same as the app)
1. Never leave the branch non-building — run the full gate (C++ above + `python3 -m
   pytest backend -q`) before every commit.
2. Real money stays out: payout = accrual ledger + config splits; provider behind a
   stubbed interface.
3. Server-authoritative everything; migrations chain properly (check down_revision).
4. Web-app integration goes through `/nexus/v1/*` ONLY (contract in
   docs/NEXUS_GATEWAY.md once landed) — no reaching into internal routers.
5. Who-Scene-It IP screen stays in the authoring review checks.

## Suggested first moves for you
1. Pull `nexus/platform-core`, run the full gate, confirm green.
2. Read `docs/NEXUS_PLATFORM_STATUS.md` + lane `LANE_NOTES.md` files (landing with
   the build) for per-module integration points.
3. Wire the web app to `/nexus/v1/queue` + `/nexus/v1/session-result` behind a
   feature flag — that closes the loop: game sessions feed mastery, mastery drives
   the next-lesson queue, education view consumes it.
