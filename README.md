# Final Evolution Lab

Final Evolution Lab is a sports-tech superapp that pairs a FastAPI backend,
a React web dashboard, an iOS SwiftUI shell, and Unreal Engine integration
artifacts for game-mode launch and streaming workflows.

## Runnable surfaces in this checkout

| Surface | Path | Stack | Local command |
|---|---|---|---|
| Web dashboard | `frontend/` | React 19, CRA/CRACO, Tailwind | `npm install && npm start` |
| API backend | `backend/` | FastAPI, Motor/MongoDB | `pip install -r requirements.txt && uvicorn server:app --host 0.0.0.0 --port 8000` |
| Backend regression tests | `backend/tests/` | pytest + requests | `pytest backend/tests` after the API and MongoDB are running |

The iOS app under `FinalEvolutionLab/` requires macOS/Xcode. The Unreal
directories contain integration/config assets and shipping scripts, not a full
cookable UE project in this Linux checkout.

## Local setup

1. Copy environment examples if you need local overrides:
   - `cp backend/.env.example backend/.env`
   - `cp frontend/.env.example frontend/.env`
2. Start MongoDB locally on `mongodb://localhost:27017`.
3. Start the backend from `backend/`:
   - `pip install -r requirements.txt`
   - `uvicorn server:app --host 0.0.0.0 --port 8000`
4. Start the web app from `frontend/`:
   - `npm install`
   - `npm start`

If no env files are present, the backend defaults to
`mongodb://localhost:27017/final_evolution_lab` and the frontend defaults to
`http://localhost:8000`.

## Quality gates

- Frontend production build: `cd frontend && npm run build`
- Backend import/bootstrap check: `cd backend && python3 -c "import server; print(server.app.title)"`
- Backend API tests: `pytest backend/tests` with MongoDB and the API running.

## Product surface notes

- The backend currently registers 19 app/game modes. Sixteen are Unreal/E3DS
  launchable game modes; `market_browse` is web-only shop navigation, and the
  newer `who_scene_it` and `court_carnival` modes are app/game experiences.
- PayPal and AI integrations are optional for local development. Leave their
  env vars blank unless exercising those flows.
