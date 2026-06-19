# AGENTS.md

## Cursor Cloud specific instructions

### Repository overview

This checkout is the **Final Evolution Lab** superapp branch: a FastAPI
backend, a React web dashboard, a SwiftUI iOS shell, and Unreal Engine
integration/config artifacts for streaming and game-mode launch.

| Sub-project | Path | Stack | Dev / verify command |
|---|---|---|---|
| Web dashboard | `frontend/` | React 19 + CRA/CRACO + Tailwind | `npm install && npm start` (port 3000) |
| API backend | `backend/` | FastAPI + Motor/MongoDB | `pip install -r requirements.txt && uvicorn server:app --host 0.0.0.0 --port 8000` |
| Backend tests | `backend/tests/` | pytest + requests | `pytest backend/tests` after MongoDB and the API are running |
| iOS shell | `FinalEvolutionLab/` | SwiftUI + Firebase descriptors | Requires Xcode/macOS |
| Unreal integration | `UnrealIntegration/`, `UnrealStarter/` | UE 5.7 config/C++ snippets | Requires an external UE project/toolchain |

### Running the web services

1. Copy examples when local overrides are needed:
   - `cp backend/.env.example backend/.env`
   - `cp frontend/.env.example frontend/.env`
2. Start MongoDB locally on `mongodb://localhost:27017`.
3. Backend: run `uvicorn server:app --host 0.0.0.0 --port 8000` from `backend/`.
4. Frontend: run `npm install`, then `npm start` from `frontend/`.

If env files are absent, the backend defaults to
`mongodb://localhost:27017/final_evolution_lab` with a short server-selection
timeout, and the frontend defaults to `http://localhost:8000`.

### Lint / build / smoke checks

- Frontend production build: `cd frontend && npm run build`
- Backend import/bootstrap smoke: `cd backend && python3 -c "import server; print(server.app.title)"`
- Backend API tests: `pytest backend/tests` with MongoDB and API running.

### Game / native notes

- The backend exposes 19 app/game modes. Sixteen are Unreal/E3DS-launchable;
  `market_browse` is a web-only shop module, while `who_scene_it` and
  `court_carnival` are app/game experiences.
- The Unreal tree in this repo is not a complete cookable project; it contains
  mode maps, venue registry data, shipping scripts, and C++ integration
  artifacts for a UE 5.7 project maintained outside this Linux checkout.
- The iOS app cannot be built in Cursor Cloud because it needs Xcode/macOS and
  production Firebase/Apple assets that are intentionally not committed.

### Environment variables

- Backend: see `backend/.env.example` for `MONGO_URL`, `DB_NAME`,
  `MONGO_SERVER_SELECTION_TIMEOUT_MS`, optional AI, and optional PayPal vars.
- Frontend: see `frontend/.env.example` for `REACT_APP_BACKEND_URL` and the
  optional PayPal client ID.
- AI coach/chat routes are designed to degrade gracefully when the optional
  private AI SDK or `EMERGENT_LLM_KEY` is unavailable.
- Do not run `npm install` at repo root; the web package lives in `frontend/`.
  Package manager is **npm** and `frontend/package-lock.json` is committed.
