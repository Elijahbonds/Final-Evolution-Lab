# AGENTS.md

## Cursor Cloud specific instructions

### Repository overview

This branch of **Final Evolution Lab** contains a runnable web app plus API backend for an athlete-optimization product. The native Unreal/iOS shipping layers are represented by source/reference files, but the Cloud VM can only build and verify the web/backend surfaces.

| Sub-project | Path | Stack | Dev command |
|---|---|---|---|
| Main web app | `frontend/` | React 19 + Create React App/CRACO + Tailwind | `npm start` (port 3000) |
| API backend | `backend/` | FastAPI + Motor/MongoDB | `uvicorn server:app --reload --host 0.0.0.0 --port 8000` |

### Running the web app

1. Install frontend dependencies in `frontend/` with `npm install`.
2. Copy `frontend/.env.example` to `frontend/.env` if you need to override the API URL.
3. Start the app with `npm start` from `frontend/`.

The frontend defaults to `http://localhost:8000` for API calls during local development and to the current origin in production if `REACT_APP_BACKEND_URL` is not set.

### Running the backend

1. Create a Python virtual environment in `backend/`.
2. Install dependencies with `pip install -r requirements.txt`.
3. Copy `backend/.env.example` to `backend/.env` and set production secrets as needed.
4. Start the API with `uvicorn server:app --reload --host 0.0.0.0 --port 8000`.

`MONGO_URL` and `DB_NAME` have local defaults in `backend/core.py`, so the API can import and serve `/health` in a fresh Cloud VM. Features that require MongoDB collections, PayPal credentials, or the private AI provider key degrade at request time when those services are unavailable.

### Build / verification

- Frontend production build: `npm run build` in `frontend/`
- Backend import smoke test: `python3 -c "import server; print(server.app.title)"` in `backend/`
- Backend tests: `pytest tests/ -q` in `backend/` once a test API URL/session token is configured

### Native/game notes

- Unreal Engine and iOS/macOS native builds cannot be completed in this Linux Cloud VM because they require the external UE project/editor or Xcode.
- Game-mode launch and streaming surfaces are represented by backend routes and frontend dashboards; verify these through the React build and backend import/API smoke tests here.

### Package manager

The frontend uses **npm**. `frontend/package-lock.json` is expected to be committed for reproducible installs.
