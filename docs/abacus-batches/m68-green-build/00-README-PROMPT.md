# M68 — GREEN BUILD: playtest audit of both products + every fix needed to get there

Most of this batch belongs in the **git repo** (backend, tools, workflow);
one file (`files/anim/SkinningGuard.ts`) goes into the **game source** in
Abacus. Paths in WIRING.

---

## THE AUDIT — WHAT I FOUND BY ACTUALLY RUNNING BOTH

I playtested FEL live and executed the Nexus build checks rather than reading
them. Seven real defects, all now fixed and verified.

### NEXUS (this repo) — was structurally red, could never go green

| # | Defect | Evidence | Impact |
|---|---|---|---|
| 1 | **CI required a `.uproject` that does not exist** | `fel-prebuild-ci.yml` exports `UPROJECT=./UnrealStarter/BasketballGame/FinalEvolutionLab.uproject`; `find . -name '*.uproject'` returns **nothing**. Unreal was replaced by Nexus (`NexusProject.json`: *"Replaces UE5 embedded runtime"*). | Every push red, forever, regardless of the change. |
| 2 | **`server.py` could not be imported at all** | Hard `from emergentintegrations...` — a private package not on any public index, pinned in requirements but uninstallable on a clean runner. | The entire backend unimportable in CI. |
| 3 | **`core.py` crashed on import without a DB** | `os.environ['MONGO_URL']` at module scope. | Import failed on every runner and every fresh checkout. |
| 4 | **`games.py` used `BaseModel` without importing pydantic** | Line 1322 `class TrajectoryRequest(BaseModel)`, no pydantic import anywhere. | Latent `NameError` — masked because #2 killed the module first. |
| 5 | **One test aborted the entire suite at collection** | `test_iteration8` opened a hardcoded `/app/frontend/.env` at import time. | pytest exited during collection: **225 tests never ran**. |
| 6 | **180 integration tests counted as failures** | They call `requests.get(BASE_URL/...)` against a live server + MongoDB. | 137 failed + 43 errored on any runner without those services — noise burying real regressions. |
| 7 | **`modes_unlocked` always empty in production** | `system_scan.py` projected only `mode_id`, but `games.py:271` writes session docs with `"mode"`. Both spellings exist in the live data. | Real user-facing data bug, found by the one unit test that was failing. |

**Result — verified by running it:**

```
before:  pytest aborts at collection · 0 tests run · server.py unimportable
after:   44 passed, 0 failed, 182 correctly skipped
         server.py imports with no DB configured
         5 passed / 0 failed / 2 skipped   ← tools/green_check.sh --nexus
```

### FEL (live app) — healthy, but the tooling was lying about it

| # | Defect | Evidence | Impact |
|---|---|---|---|
| 8 | **The smoke test reported all six modes broken** | Every route returned "no `<canvas>`". The screenshot showed the **sign-in wall** — a fresh browser context has no session. | A false failure on every gated route: the worst thing a gate can do. |
| 9 | **`SkinningGuard` v1 is crying wolf on Karate** | Live console: four simultaneous `SKINNING STALL` reports (`char_198/264/330/396`), all forcing CPU skinning. The screenshot shows characters clearly mid-animation. | v1 samples ONE bone (`Spine`); karate's `guard` stance holds the spine still, so healthy characters read as stalled — and each false positive costs real frame time on the CPU-skinning fallback. |

**With a session loaded: 4/5 modes PASS** (dunk, onevone, threevthree,
carnival). The only red is #9, which this batch fixes.

## THE FIXES

- **`SkinningGuard` v2** — samples six bones across limbs instead of one,
  waits 45 frames instead of 20, requires a genuinely playing clip, and
  distinguishes SUSPECT (partial freeze → log only, no action) from STALL
  (every sampled bone frozen → act). A guard that fires on healthy
  characters gets ignored, which defeats its purpose.
- **`smoke.mjs` v2** — loads a saved session, and if it still lands on a
  login screen it reports **AUTH WALL** explicitly rather than blaming the
  game. `--login` captures a session once.
- **Backend** — optional private import, import-safe env handling (secrets
  are still never committed or defaulted in production; the fallbacks only
  make the module importable), the missing pydantic import, and the mode-key
  fix.
- **`conftest.py`** — classifies integration tests **by what a module does**
  (`imports requests` and no `TestClient`), not by a hardcoded name list that
  drifts. They skip with a clear reason when no backend is reachable and run
  normally when one is. `FEL_REQUIRE_INTEGRATION=1` makes them fail instead.
- **`green_check.sh`** — one command, both products, honest verdict.
  **A check that cannot run here is SKIPPED with its reason, never silently
  passed.** Swift is the honest example: 1425 sources that need macOS+Xcode.

## ⚠ WHAT "100% GREEN" HONESTLY MEANS RIGHT NOW

Everything runnable on a Linux runner is green. Two things are **not
verifiable here and are reported as skips, not passes**:

1. **The Swift/iOS build (1425 files).** Needs macOS + Xcode. This is the
   single biggest unverified surface in Nexus — run
   `xcodebuild -scheme FinalEvolutionLab build` on the Mac mini and expect
   real work: nothing has type-checked that code in this environment.
2. **The 182 integration tests.** They pass or fail against a live backend;
   they are skipped, not proven. Run them with a server + MongoDB up.

Claiming "100% green" while those are unrun would be the same mistake as the
smoke test reporting a login wall as six broken modes.

## FILES
| File | Goes where |
|---|---|
| `files/anim/SkinningGuard.ts` | **game source** `anim/` (Abacus) — REPLACES M51's |
| `files/tools/green_check.sh` | repo `tools/` |
| `files/tools/smoke.mjs` | repo `tools/` — REPLACES M66's |
| `files/backend/core.py`, `server.py` | repo `backend/` |
| `files/backend/routers/biofuel.py`, `games.py`, `system_scan.py` | repo `backend/routers/` |
| `files/backend/tests/conftest.py`, `test_iteration8_biofuel_pass.py` | repo `backend/tests/` |
| `files/workflows/fel-prebuild-ci.yml` | repo `.github/workflows/` |

## WIRING
1. Repo files to the paths above; `SkinningGuard.ts` into Abacus.
2. `chmod +x tools/green_check.sh`, then `bash tools/green_check.sh`.
3. FEL smoke needs a session once: `node tools/smoke.mjs --login`.
   **Do not commit `smoke-state.json`** — add it to `.gitignore`.
4. On the Mac mini, add the Swift job to the workflow.

## ACCEPTANCE
1. `bash tools/green_check.sh --nexus` → 5 passed, 0 failed, 2 skipped.
2. `cd backend && MOCK_DB=1 python3 -m pytest -q` → 44 passed, 0 failed.
3. `node tools/smoke.mjs` with a session → dunk/onevone/threevthree/carnival
   PASS; karate PASS once SkinningGuard v2 is live.
4. Without a session, gated routes report **AUTH**, never FAIL.
5. CI is green on push (the dead Unreal gate is gone).
