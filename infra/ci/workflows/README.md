# Staged GitHub workflows (nexus/ci-aa)

**Why these live here instead of `.github/workflows/`:** the local git
credential is a GitHub OAuth token with scopes `gist, read:org, repo` — it
lacks the `workflow` scope, so GitHub **rejects any push that creates or
modifies files under `.github/workflows/`** ("refusing to allow an OAuth App
to create or update workflow ... without `workflow` scope").

## To activate (repo owner, one-time)

Either refresh the token with the workflow scope:

```bash
gh auth refresh -h github.com -s workflow
```

then move the files and push:

```bash
git mv infra/ci/workflows/ci.yml .github/workflows/ci.yml
git mv infra/ci/workflows/ios-archive-dry-run.yml .github/workflows/ios-archive-dry-run.yml
git commit -m "nexus/ci-aa: activate CI workflows"
git push
```

…or move them via the GitHub web UI (which always has workflow permission).

Both files are valid YAML (checked with `yaml.safe_load`) and every job was
executed locally before staging:

| Job | Local verification |
|---|---|
| `backend-tests` | `pytest tests/test_matches.py --noconftest` → 20 passed (MOCK_DB=1, Python venv from `backend/requirements-ci.txt`) |
| `frontend-build` | `npm ci --legacy-peer-deps && CI=false npm run build` → build OK (after ajv override fix + committed lockfile) |
| `sim` | `backend/tools/sim_server.py` + `scripts/simulate_matches.py --n 3` → 3/3 matches finished, replay JSONs written |
| `ios-archive-dry-run` | not run locally (manual `workflow_dispatch`; wraps existing `scripts/archive-ios-testflight.sh --dry-run`) |
