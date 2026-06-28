# AGENTS.md

## Cursor Cloud specific instructions

### Repository overview

This is a polyglot monorepo for **Final Evolution Lab**, a sports-tech / athletic-optimization product. The runnable Cloud surfaces in this branch are the React web app and FastAPI backend, plus Python smoke checks that validate shared game/native registries.

| Sub-project | Path | Stack | Dev command |
|---|---|---|---|
| Web app | `frontend/` | React 19 + CRA/CRACO + Tailwind | `npm start` (port 3000) |
| API backend | `backend/` | FastAPI + MongoDB | `uvicorn server:app --reload --host 0.0.0.0 --port 8000` |
| Game/native registry checks | `scripts/`, `UnrealStarter/`, `FinalEvolutionLab/` | Python + UE/iOS source/config | `python3 scripts/smoke_test_modes.py` |

### Running the web services

1. Install frontend dependencies with `npm install` in `frontend/`.
2. Install backend dependencies with `python3 -m pip install --user -r requirements.txt` in `backend/`.
3. Optional local env overrides:
   - `cp frontend/.env.example frontend/.env`
   - `cp backend/.env.example backend/.env`
4. Start the backend from `backend/`: `uvicorn server:app --reload --host 0.0.0.0 --port 8000`.
5. Start the frontend from `frontend/`: `npm start`.

The frontend defaults to `http://localhost:8000` on localhost and to the current origin in production when `REACT_APP_BACKEND_URL` is not set.

### Lint / test / build

- Frontend build: `npm run build` in `frontend/`.
- Frontend test command: `npm test -- --watchAll=false --passWithNoTests` in `frontend/`.
- Backend import check: `python3 -c "import sys; sys.path.insert(0, 'backend'); import server; print('backend import ok')"` from repo root.
- Backend compile check: `python3 -m py_compile backend/core.py backend/server.py backend/routers/biofuel.py` from repo root.
- Game/native registry smoke suite: `python3 scripts/smoke_test_modes.py` from repo root.

### Unreal Engine / iOS notes

- UE and iOS source/config live under `UnrealStarter/`, `UnrealIntegration/`, and `FinalEvolutionLab/`.
- Full UE compile/cook/package and iOS builds are not runnable in this Linux Cloud VM because they require UE/Xcode-capable machines.
- Use the Python smoke suite to validate mode registry, UE map routing, Swift enum coverage, and economy integration in this environment.

### Environment variables

- Backend local defaults: `MONGO_URL=mongodb://localhost:27017`, `DB_NAME=final_evolution_lab`.
- Optional backend keys: `PAYPAL_CLIENT_ID`, `PAYPAL_SECRET`, `EMERGENT_LLM_KEY`.
- Optional frontend keys: `REACT_APP_BACKEND_URL`, `REACT_APP_PAYPAL_CLIENT_ID`.
- PayPal and AI-backed features should degrade gracefully when optional keys are absent.

### Non-obvious notes

- Package manager for the web app is **npm**; commit `frontend/package-lock.json` for deterministic installs.
- The repository root intentionally does not have a runnable Node app; do not run `npm install` at root.
