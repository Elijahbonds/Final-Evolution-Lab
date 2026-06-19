# AGENTS.md

## Repository overview

This branch of **Final Evolution Lab** is a React/FastAPI product repo with native and Unreal Engine integration artifacts.

| Area | Path | Stack | Dev command |
| --- | --- | --- | --- |
| Web dashboard | `frontend/` | React + CRACO + Tailwind | `yarn start` |
| API backend | `backend/` | FastAPI + MongoDB | `uvicorn server:app --host 0.0.0.0 --port 8000` |
| Mode registry smoke tests | `scripts/smoke_test_modes.py` | Python | `python3 scripts/smoke_test_modes.py` |
| iOS shell | `FinalEvolutionLab/` | SwiftUI/WKWebView/UE framework host | Requires macOS + Xcode |
| Unreal integration | `UnrealIntegration/`, `UnrealStarter/BasketballGame/` | UE 5.7 snippets/config | Requires full external UE project |

## Running locally

1. Copy env templates:
   - `cp backend/.env.example backend/.env`
   - `cp frontend/.env.example frontend/.env`
2. Backend:
   - `cd backend`
   - `pip install -r requirements.txt`
   - `uvicorn server:app --host 0.0.0.0 --port 8000`
3. Frontend:
   - `cd frontend`
   - `yarn install`
   - `yarn start`

The frontend defaults to `http://localhost:8000` when `REACT_APP_BACKEND_URL` is unset.

## Verification

- Frontend build: `cd frontend && yarn build`
- Backend compile/import smoke: `cd backend && python -m compileall .`
- Static mode alignment: `python3 scripts/smoke_test_modes.py`

## Important notes

- Do not run package-manager commands at the repository root; the runnable web package is `frontend/`.
- `frontend/package.json` pins Yarn classic. Prefer `yarn install` and commit a `yarn.lock` when dependency resolution changes.
- The backend can import with local Mongo defaults, but most authenticated routes require a running MongoDB and a valid session.
- AI, Bio-Fuel vision, and PayPal routes intentionally degrade when provider keys/packages are not configured.
- UE/iOS builds are not runnable in this Linux Cloud VM; inspect and update integration/config files only unless a macOS/UE environment is provided.
