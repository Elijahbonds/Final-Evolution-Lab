# Final Evolution Lab

Final Evolution Lab is an athlete operating system with a React web app, FastAPI/MongoDB backend, and native iOS/Unreal integration artifacts.

## Runnable in this environment

- `frontend/` — React 19 + CRA/CRACO dashboard and game/app UI.
- `backend/` — FastAPI API for auth, games, FEL OS, Bio-Fuel, education, sovereign bridge, and mode registry endpoints.

Native iOS and Unreal Engine assets are included for integration work but are not buildable in this Linux Cloud VM.

## Local setup

```bash
cd backend
cp .env.example .env
python3 -m pip install --user -r requirements.txt
uvicorn server:app --host 0.0.0.0 --port 8000
```

```bash
cd frontend
cp .env.example .env
npm install
npm start
```

Open http://localhost:3000. The frontend defaults to `http://localhost:8000/api` in development when `REACT_APP_BACKEND_URL` is not set.

## Verification

```bash
cd frontend && npm run build
python3 -c "import sys; sys.path.insert(0, 'backend'); import server; print('backend import ok')"
python3 -m py_compile backend/core.py backend/server.py backend/routers/*.py
python3 scripts/smoke_test_modes.py
```

Backend pytest files in `backend/tests/` expect a running API and MongoDB. Set `REACT_APP_BACKEND_URL=http://localhost:8000` before running them locally.
