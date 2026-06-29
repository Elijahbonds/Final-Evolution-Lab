# AGENTS.md

## Cursor Cloud specific instructions

### Repository overview

This checkout is the **Final Evolution Lab** app/game integration repo. The Cloud VM runnable surface is a React web app backed by FastAPI and MongoDB. Native iOS and Unreal Engine integration files are present for product alignment, but full native/game builds require macOS/Xcode, Unreal Engine 5.7, signing assets, and cooked game content that are not available in this Linux VM.

| Sub-project | Path | Stack | Dev command |
|---|---|---|---|
| Web app | `frontend/` | React 19 + CRA/CRACO + Tailwind | `npm start` (port 3000) |
| Backend API | `backend/` | FastAPI + Motor/MongoDB | `uvicorn server:app --host 0.0.0.0 --port 8000` |
| Backend tests | `backend/tests/` | pytest + requests | Run against a live API with `REACT_APP_BACKEND_URL=http://localhost:8000` |
| Native iOS shell | `FinalEvolutionLab/` | Swift/Xcode + UE host stubs | Not runnable in Cloud VM |
| Unreal integration | `UnrealIntegration/`, `UnrealStarter/` | UE 5.7 bridge/config artifacts | Not runnable in Cloud VM |

### Running the web services

1. Install frontend dependencies with `npm install` in `frontend/`.
2. Install backend dependencies with `python3 -m pip install --user -r backend/requirements.txt`.
3. Copy env templates if you need local overrides:
   - `cp backend/.env.example backend/.env`
   - `cp frontend/.env.example frontend/.env`
4. Start MongoDB locally or point `MONGO_URL` at an accessible instance. Backend imports default to `mongodb://localhost:27017` and `final_evolution_lab` for local development.
5. Start the backend from `backend/`: `uvicorn server:app --host 0.0.0.0 --port 8000`.
6. Start the frontend from `frontend/`: `npm start` and open http://localhost:3000.

### Lint / test / build

- Frontend build: `npm run build` in `frontend/`.
- Frontend tests: `npm test -- --watchAll=false --passWithNoTests` in `frontend/`.
- Backend import smoke: `python3 -c "import sys; sys.path.insert(0, 'backend'); import server; print('backend import ok')"` from repo root.
- Backend compile smoke: `python3 -m py_compile backend/core.py backend/server.py backend/routers/*.py`.
- Mode registry smoke: `python3 scripts/smoke_test_modes.py`.
- Targeted backend pytest requires a running backend and MongoDB, for example: `REACT_APP_BACKEND_URL=http://localhost:8000 python3 -m pytest backend/tests/test_iteration8_biofuel_pass.py -q`.

### Environment variables

- Backend: see `backend/.env.example`. `MONGO_URL` and `DB_NAME` have local defaults; AI, PayPal, and E3DS keys are optional and degrade gracefully when absent.
- Frontend: see `frontend/.env.example`. `REACT_APP_BACKEND_URL` defaults to `http://localhost:8000` in development and `window.location.origin` in production builds.

### Non-obvious notes

- Package manager is **npm** for the frontend; commit `frontend/package-lock.json`.
- Do not run `npm install` at repo root; the root has no Node app.
- The app uses `backend/FEL_ModeManager.production.json` as the source of truth for game-mode launchability. Preview and non-game module modes should remain visible but not launchable.
- iOS/UE verification in this VM is limited to static checks and scripts. Full validation needs UE 5.7 editor/cooker, Xcode on macOS, signing credentials, Firebase plist, and the embedded `UnrealFramework.framework`.
