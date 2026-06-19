# AGENTS.md

## Cursor Cloud specific instructions

### Repository overview

This branch of **Final Evolution Lab** is a sports-tech / athletic-optimization
superapp. The runnable Cloud VM surface is:

| Sub-project | Path | Stack | Dev command |
|---|---|---|---|
| Web superapp | `frontend/` | React 19 + CRACO + Tailwind | `npm start` (port 3000) |
| API | `backend/` | FastAPI + Motor/MongoDB | `uvicorn server:app --host 0.0.0.0 --port 8000` |

The primary native game target remains Unreal Engine 5.7 with an iOS wrapper,
but those builds require UE/Xcode tooling outside this Linux Cloud VM.

### Running the web services

1. Copy env examples:
   - `cp backend/.env.example backend/.env`
   - `cp frontend/.env.example frontend/.env`
2. Install frontend dependencies in `frontend/` with `npm install`.
3. Install backend dependencies in `backend/` with `pip install -r requirements.txt`.
4. Start the API from `backend/`: `uvicorn server:app --host 0.0.0.0 --port 8000`.
5. Start the web app from `frontend/`: `npm start`.

The backend defaults to `mongodb://localhost:27017` and
`DB_NAME=final_evolution_lab` when env vars are absent. Health checks are
available at `/health` and `/api/health` even before provider integrations are
configured.

### Lint / test / build

- Frontend build: `npm run build` in `frontend/`
- Backend focused mode smoke: `python -m pytest tests/test_iteration4_e3ds.py -q` in `backend/`
- Broader backend tests are live-API style and may require Mongo plus seeded
  sessions/tokens.

### Product-mode notes

- The product catalog exposes 19 modes.
- Sovereign/Pixel Streaming exposes 18 launchable UE modes; `market_browse` is
  a shop module and is intentionally non-launchable as gameplay.
- `backend/ue_mode_maps.json` is the canonical mode-id to Unreal map-token file
  used for launch and smoke-test alignment.

### Non-obvious notes

- Do not run `npm install` at the repo root.
- Package manager is npm; the frontend lockfile is `frontend/package-lock.json`.
- Provider-backed AI, PayPal, and E3DS flows need optional credentials; the app
  should still boot and show seeded core surfaces without them.
