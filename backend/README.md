# Phase 1 guide-aligned FastAPI backend (`app/`)

This tree is the Postgres-backed replacement for the legacy dual-stack in
`server.py` (Mongo + monolith routes). The legacy `server.py` remains the
Docker default until production cutover is complete.

## Local development

### Option A — Docker Postgres (recommended)

```bash
# From repo root
docker compose up -d postgres redis

cd backend
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt

# Migrate schema (Postgres must be reachable)
alembic upgrade head

# Run the new app (not server.py)
uvicorn app.main:app --reload --port 8000
```

Environment (`.env` in `backend/`):

```env
DATABASE_URL=postgresql+asyncpg://fel_user:fel_password@localhost:5432/fel_db
USE_SQLITE_DEV=false
JWT_SECRET_KEY=dev-only-change-me
```

### Option B — SQLite dev fallback (no Docker)

Only for local shell work when Postgres is unavailable. **Do not enable in
staging/production.**

```env
USE_SQLITE_DEV=true
SQLITE_DEV_PATH=fel_dev.sqlite3
```

Tables are created on first session write via SQLAlchemy metadata (Alembic
migrations are Postgres-oriented). Install the async SQLite driver:

```bash
pip install aiosqlite
```

## Docker migration (dual-stack → `app.main`)

The root `docker-compose.yml` still runs `uvicorn server:app` on port 8888.
Switch only after Phase 1 tests pass and Postgres migrations are applied.

Safe cutover steps:

1. `docker compose up -d postgres redis`
2. `docker compose exec api alembic upgrade head` (once the API image includes `app/` and Alembic)
3. Set feature flags on the API service:
   - `USE_SQLITE_DEV=false` (required in prod-like environments)
   - `DATABASE_URL=postgresql+asyncpg://fel_user:fel_password@postgres:5432/fel_db`
4. Change the API `command` to `uvicorn app.main:app --host 0.0.0.0 --port 8888`
5. Smoke-test: `GET /healthz`, `POST /api/games/session`, Vault `session_end` WS
6. Keep `server.py` reachable behind a feature flag or separate service until
   Mongo-dependent routes are ported or retired

Rollback: revert the Docker `command` to `server:app` and restart the API container.

## Tests

```bash
cd backend
source .venv/bin/activate
pytest tests_phase1 -q
```

Phase 1 tests bootstrap an in-memory SQLite database automatically via
`tests_phase1/conftest.py`.

## Economy parity

Session economy (XP, shards, PRQ Δ) is computed in `app/utils/formulas.py` and
matches `server.py` v2.0 outcome-based logic (Architecture §6.1–6.2). Vault
`session_end` and `POST /api/games/session` both flow through
`session_processor`, which fails closed if persistence errors occur.
