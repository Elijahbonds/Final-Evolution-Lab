# AGENTS.md

## Cursor Cloud specific instructions

### Repository overview

This branch of **Final Evolution Lab** is a polyglot athlete-OS repo. The
runnable Cloud VM surface is a React dashboard paired with a FastAPI/MongoDB
backend. Native iOS and Unreal Engine code is present for product integration
but cannot be fully built in this Linux environment.

| Sub-project | Path | Stack | Dev command |
| --- | --- | --- | --- |
| Web dashboard | `frontend/` | React 19 + CRA/CRACO + Tailwind | `npm start` (port 3000) |
| API backend | `backend/` | FastAPI + Motor/MongoDB | `uvicorn server:app --host 0.0.0.0 --port 8000` |
| iOS shell | `FinalEvolutionLab/` | SwiftUI + HealthKit/Firebase hooks | Requires macOS + Xcode |
| Unreal integration | `UnrealIntegration/`, `UnrealStarter/` | UE 5.7 C++/config snippets | Requires UE editor/project assets |

### Running the web services

1. Copy env templates if you need local overrides:
   - `cp frontend/.env.example frontend/.env`
   - `cp backend/.env.example backend/.env`
2. Install/start backend:
   - `cd backend && pip install -r requirements.txt`
   - `uvicorn server:app --host 0.0.0.0 --port 8000`
3. Install/start frontend:
   - `cd frontend && npm install`
   - `npm start`
4. Open `http://localhost:3000`.

The frontend defaults to `http://localhost:8000` for API calls during local
development. In production-like hosts it defaults to same-origin unless
`REACT_APP_BACKEND_URL` is set.

### Lint / build / smoke checks

- Frontend build: `cd frontend && npm run build`
- Frontend tests: `cd frontend && npm test -- --watchAll=false --passWithNoTests`
- Backend install: `cd backend && pip install -r requirements.txt`
- Backend import smoke:
  `python3 -c "import sys; sys.path.insert(0, 'backend'); import server; print('backend import ok')"`
- Backend syntax smoke:
  `python3 -m py_compile backend/core.py backend/server.py backend/routers/*.py`

### Environment variables

- Backend defaults:
  - `MONGO_URL=mongodb://localhost:27017`
  - `DB_NAME=final_evolution_lab`
- Optional integrations:
  - `EMERGENT_LLM_KEY` plus the private Emergent LLM SDK for live AI Coach and
    Bio-Fuel vision scans.
  - `PAYPAL_CLIENT_ID` and `PAYPAL_SECRET` for PayPal checkout.
  - `SOVEREIGN_*` settings for local Sovereign Hub behavior.

### Non-obvious notes

- Do not run `npm install` at the repo root; install inside `frontend/`.
- Package manager for the web app is npm and `frontend/package-lock.json` should
  be committed.
- Pixel Streaming is currently a local Sovereign Hub data-feed/deep-link flow;
  it is not an E3DS cloud iframe path.
- The iOS app cannot be built in the Cloud VM because it needs Xcode, signing,
  and local Firebase assets.
- The Unreal project cannot be compiled/cooked here because the complete
  `.uproject`, engine install, and game assets are not present in the checkout.
