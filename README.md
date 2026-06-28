# Final Evolution Lab

Polyglot sports-tech monorepo for the Final Evolution Lab athlete operating system.

## Runnable surfaces in this checkout

| Surface | Path | Stack | Local command |
| --- | --- | --- | --- |
| Web app | `frontend/` | React 19, CRA/CRACO, Tailwind | `npm install && npm start` |
| API backend | `backend/` | FastAPI, MongoDB | `python3 -m pip install --user -r requirements.txt && uvicorn server:app --reload --host 0.0.0.0 --port 8000` |
| Game/native validation | `scripts/`, `UnrealStarter/`, `FinalEvolutionLab/` | Python smoke checks, UE/iOS source assets | `python3 scripts/smoke_test_modes.py` |

Unreal Engine and iOS packaging require UE/Xcode-capable machines; this Cloud VM can validate shared registries, backend wiring, and the web app.

## Environment

Copy the example env files when local overrides are needed:

```bash
cp frontend/.env.example frontend/.env
cp backend/.env.example backend/.env
```

Defaults are local-safe:

- Frontend API base: `http://localhost:8000` on localhost, current origin in production.
- Backend Mongo: `mongodb://localhost:27017`, database `final_evolution_lab`.
- PayPal and AI keys are optional; related features degrade gracefully when absent.

## Quality checks

```bash
cd frontend && npm run build
cd frontend && npm test -- --watchAll=false --passWithNoTests
python3 -m py_compile backend/core.py backend/server.py backend/routers/biofuel.py
python3 -c "import sys; sys.path.insert(0, 'backend'); import server; print('backend import ok')"
python3 scripts/smoke_test_modes.py
```
