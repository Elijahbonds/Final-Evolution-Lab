# AGENT_STATUS — Nexus AAA Sprint 1 (Agents 7–10)

Single writer: Sprint 1 coordinator. Updated: 2026-07-01.
Base branch: `integration/nexus-aaa` @ `faba51d` (post anti-gravity-fel → main merge).

| Agent | Workstream | Branch | Head SHA | PR | Status |
|---|---|---|---|---|---|
| 7 | CI, simulation, AAB/iOS artifact | `nexus/ci-aa` | `06105e6` | [#55](https://github.com/Elijahbonds/Final-Evolution-Lab/pull/55) (draft) | DONE, workflow activation blocked (see below) |
| 8 | Assets & render pipeline | `nexus/asset-pipeline` | `73c50d6` | [#56](https://github.com/Elijahbonds/Final-Evolution-Lab/pull/56) (draft) | DONE |
| 9 | Engine perf & GPU features | `nexus/engine-gfx` | `8b4caf6` | [#57](https://github.com/Elijahbonds/Final-Evolution-Lab/pull/57) (draft) | DONE, gate green |
| 10 | Audio, VFX, cinematics | `nexus/audio-vfx` | `edb631b` | [#58](https://github.com/Elijahbonds/Final-Evolution-Lab/pull/58) (draft) | DONE |

## Verification evidence

- **Agent 7**: `pytest tests/test_matches.py --noconftest` → **20 passed** (MOCK_DB=1);
  frontend `npm ci --legacy-peer-deps && npm run build` → OK (after ajv EOVERRIDE fix
  + committed lockfile); sim harness → **3/3 matches finished**, replay JSONs written.
  Both workflow YAMLs pass `yaml.safe_load`. **No Android project exists** → no AAB
  workflow invented; iOS archive dry-run workflow instead (`infra/ANDROID_AAB_STATUS.md`).
- **Agent 8**: full pipeline run → `[validate] tier=mobile-mid checked=16 errors=0`.
  ASTC outputs are honest `.todo.json` placeholders until `astcenc` is installed.
- **Agent 9**: `./scripts/nexus_build_gate.sh` → **PASS: headless 11/11, full 14/14**
  (13 existing + new `nexus_gfx_batch_test`), production + staging mode validation
  green. Decision doc: `docs/architecture/NEXUS_GPU_Feature_Decisions.md`.
- **Agent 10**: `swiftc -parse` clean on all 6 touched Swift files (iOS 17 sim SDK).
  All SFX synthesized procedurally (honest placeholder palette — the "announcer" is
  a synth sting, not VO; flagged for future recorded-audio drop).

## Blockers

1. **(Agent 7) `workflow` scope missing** on the git push credential
   (`gist, read:org, repo` only) — GitHub rejects pushes touching
   `.github/workflows/`. Workflows staged at `infra/ci/workflows/` with
   activation README. Fix: repo owner runs `gh auth refresh -h github.com -s workflow`,
   then `git mv` + push (est. 10 min).
2. **(pre-existing) `backend/tests/test_system_scan.py`**: 11/24 tests fail against
   the current system_scan router on this base (stale expectations — `metrics.*`
   now `None` vs expected `0.0`). Excluded from CI; needs triage (est. 0.5 d).
3. **(pre-existing) `backend/tests/conftest.py`** runs `seed_db` against live
   PostgreSQL at collection time, breaking offline runs — CI uses `--noconftest`.
   Consider gating the seed behind `MOCK_DB!=1` (est. 1 h).

## Next sprint queue (from decision doc)

- Backend instanced submission (Metal/Vulkan `instanceCount`) — 1.5 w
- Particle instanced-quad draw in `MetalRenderer` — 1 w (then compute promotion, 2 w)
- GPU skinning Option B phase 1 (pose palette upload) — 1 w

---

# AGENT_STATUS — Nexus AAA Sprint 0 (Agents 1–6)

Single writer: Sprint 0 coordinator. Updated: 2026-07-01.
Sequential branch chain (matches.py ownership 1 → 2 → 3 → 4 → 5 → 6), forked from
`integration/nexus-aaa` @ `427aee2` (pre main-merge; small conflict pass expected at merge —
merge PRs in stack order #95 → #96 → #97 → #98 → #99 → #101).

| Agent | Workstream | Branch | Head SHA | PR | Status |
|---|---|---|---|---|---|
| 1 | Judge/Seed Authority | `nexus/judge-offsets` | `92d627f` | [#95](https://github.com/Elijahbonds/Final-Evolution-Lab/pull/95) (draft) | DONE — 9/9 tests |
| 2 | Server Dunk Scoring (WDA port) | `nexus/dunk-server-scoring` | `d1ca595` | [#96](https://github.com/Elijahbonds/Final-Evolution-Lab/pull/96) (draft) | DONE — 30/30 tests, 4 pinned vectors |
| 3 | Match Events + Replay Export | `nexus/match-replay` | `c8ea469` | [#97](https://github.com/Elijahbonds/Final-Evolution-Lab/pull/97) (draft) | DONE — 13/13 tests |
| 4 | Sim Harness + Replay Validator | `nexus/sim-harness` | `18acf2e` | [#98](https://github.com/Elijahbonds/Final-Evolution-Lab/pull/98) (draft) | DONE — 3/3 replays validate, tamper → exit 1 |
| 5 | Snapshot Netcode Foundation | `nexus/netcode-snapshot` | `2321194` | [#99](https://github.com/Elijahbonds/Final-Evolution-Lab/pull/99) (draft) | DONE — 7/7 tests, live client demo 8/8 inputs |
| 6 | GameView QA & Replay UX | `nexus/gameview-debug` | `aaf81ee` | [#101](https://github.com/Elijahbonds/Final-Evolution-Lab/pull/101) (draft) | DONE — `npm run build` green |

## Verification evidence (all with MOCK_DB=1, no real DB)

- Full backend suite on chain head: `cd backend && MOCK_DB=1 python3 -m pytest
  tests/test_matches.py tests/test_dunk_scoring.py tests/test_match_seed_offsets.py
  tests/test_replay_export.py tests/test_netcode_snapshot.py` → **79 passed**.
- Determinism: fixed seed → `random.Random(seed).randint(-5,5)` offsets pinned in tests;
  WDA engine-3D scoring has 4 exact-value vectors; `replay_validator.py` re-computes all
  dunk_results + score accumulation from exported replays (exit 0 clean / exit 1 on tamper — both verified).
- End-to-end: `uvicorn sim_app:app` + `scripts/simulate_matches.py --base ... --count 3`
  → 3/3 replays exported and validated; `scripts/netcode_client_example.py` → 19 snapshots,
  8/8 inputs persisted, reconciliation loop demonstrated.
- Frontend: `npm install && npm run build` (npm; no yarn.lock) → build green after removing
  the broken global `ajv` override.

## Blockers / notes

1. `backend/server.py` on this lineage imports `emergentintegrations` (not installed
   locally) — harness uses `backend/sim_app.py` instead; full-server smoke deferred to CI.
2. Branch chain forked pre main-merge (`427aee2` vs integration `faba51d`): ~2 files
   overlap (`backend/routers/matches.py` lineage, frontend lockfile-adjacent). Resolve
   when promoting the stack.
3. WS `player_id` is client-asserted under MOCK_DB (guest auth) — per-connection auth
   binding is a pre-production TODO (documented in `infra/netcode_contract.md`).
4. No secrets touched; no task required one.
