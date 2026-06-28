# Final Evolution Lab

Final Evolution Lab is an athlete operating system that combines training, Bio-Fuel nutrition, education tracks, creator cards, game-mode progression, and sovereign telemetry surfaces.

This checkout's runnable Cloud surfaces are:

- `frontend/` — React + CRACO + Tailwind web app
- `backend/` — FastAPI API backed by MongoDB
- `FinalEvolutionLab/` and `Unreal*` — native/game integration code and configuration that require macOS/Xcode or Unreal Engine outside this Linux VM

## Prerequisites

- Node.js 22+ and npm 10+
- Python 3.11+
- MongoDB for authenticated/profile/game data

## Environment

Copy the examples before running locally:

```bash
cp backend/.env.example backend/.env
cp frontend/.env.example frontend/.env
```

Backend defaults allow import and health checks without a `.env`, but authenticated product flows require MongoDB.

## Backend

```bash
cd backend
python3 -m venv .venv
. .venv/bin/activate
pip install -r requirements.txt
uvicorn server:app --reload --host 0.0.0.0 --port 8000
```

Health checks:

- `GET http://localhost:8000/health`
- `GET http://localhost:8000/api/health`

Optional AI features (`/api/ai/*` and Bio-Fuel vision scanning) require `EMERGENT_LLM_KEY` and the private `emergentintegrations` SDK to be installed in the backend environment. Without them, the app still boots and non-AI flows continue to work.

## Frontend

```bash
cd frontend
npm install
npm start
```

The dev app runs on `http://localhost:3000` and defaults API calls to `http://localhost:8000/api` unless `REACT_APP_BACKEND_URL` is set.

Build check:

```bash
cd frontend
npm run build
```

## Tests and validation

Backend integration tests under `backend/tests/` expect a running API, MongoDB, and a valid `TEST_SESSION_TOKEN` for authenticated cases:

```bash
REACT_APP_BACKEND_URL=http://localhost:8000 TEST_SESSION_TOKEN=<token> pytest backend/tests -v
```

Useful repo-level validation scripts:

```bash
./scripts/verify_production_readiness.sh
./scripts/smoke_test_modes.py
```

The Unreal and iOS projects cannot be fully built in this Linux environment because they require external Unreal content/editor tooling or Xcode.
