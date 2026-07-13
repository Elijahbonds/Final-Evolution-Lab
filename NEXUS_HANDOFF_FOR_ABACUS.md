# NEXUS — Handoff for Abacus (platform track)

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
