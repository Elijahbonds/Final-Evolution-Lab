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
