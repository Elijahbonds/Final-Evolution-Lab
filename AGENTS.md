# AGENTS.md

## Cursor Cloud specific instructions

### Repository overview

This is a polyglot monorepo for **Final Evolution Lab**, a sports-tech / athletic-optimization product. The primary shipping client targets Unreal Engine 5.7 (C++ / Swift host shell); the Linux-runnable surfaces in this branch are the CRA frontend and FastAPI/MongoDB backend.

| Sub-project | Path | Stack | Dev command |
|---|---|---|---|
| Web app / athlete OS | `frontend/` | React 19 + CRA/CRACO + Tailwind | `npm start` (port 3000) |
| API backend | `backend/` | FastAPI + MongoDB | `uvicorn server:app --reload --port 8000` |
| Firebase Data Connect schema | `dataconnect/` | GraphQL schema/connectors for social surfaces | `firebase dataconnect:sdk:generate` |
| iOS shell | `FinalEvolutionLab/` | Swift / SwiftUI host for web + Unreal surfaces | Requires Xcode on macOS |
| Unreal integration snippets | `UnrealIntegration/`, `UnrealStarter/` | UE 5.7 C++/config snippets | Inspect-only in Linux |

### Running the web services

1. **Frontend** — run `npm install` in `frontend/`, then `npm start` → http://localhost:3000.
2. **Backend** — install Python deps with `python3 -m pip install --user -r backend/requirements.txt`, copy `backend/.env.example` to `backend/.env` if you need non-default values, then run `uvicorn server:app --reload --port 8000` from `backend/`.
3. **MongoDB** — defaults are `MONGO_URL=mongodb://localhost:27017` and `DB_NAME=final_evolution_lab`. Start a local MongoDB instance for authenticated API workflows.
4. **Frontend env** — copy `frontend/.env.example` to `frontend/.env` when pointing at a non-default API or real PayPal/store URLs.

### Lint / Typecheck / Build

- **Frontend build**: `npm run build` in `frontend/`.
- **Frontend smoke tests**: `npm test -- --watchAll=false --passWithNoTests` in `frontend/`.
- **Backend import/compile**: `python3 -m py_compile backend/core.py backend/server.py backend/routers/*.py` from repo root.
- **Backend tests**: `python3 -m pytest backend/tests -q` when MongoDB/test services are available.
- **Mode smoke test**: `python3 scripts/smoke_test_modes.py`.

### Unreal Engine (not runnable in Cloud Agent VM)

- Native UE compile/cook/package requires UE 5.7 outside this Linux VM.
- Backend/native launch map tokens are coordinated through `backend/ue_mode_maps.json`, `backend/FEL_ModeManager.production.json`, and `UnrealStarter/BasketballGame/Config/FEL_VenueRegistry.production.json`.
- Pixel Streaming/Eagle 3D integration is exposed through the frontend Pixel Stream tab and backend `/api/streaming/*` routes; real provider keys are optional env vars.

### Environment variables

The frontend reads `REACT_APP_*` variables from `frontend/.env`. The backend reads `backend/.env` via `python-dotenv`. See `frontend/.env.example` and `backend/.env.example`.

### Non-obvious notes

- The Unreal Engine and iOS app cannot be built in a Linux Cloud Agent VM; use inspection and validation scripts only.
- Supabase is not present in this branch. Backend persistence is MongoDB, with Firebase Data Connect schema files for social surfaces.
- The root has no frontend dependencies; do not run `npm install` at root.
- Package manager is **npm** for `frontend/` and the committed lockfile is `frontend/package-lock.json`.
