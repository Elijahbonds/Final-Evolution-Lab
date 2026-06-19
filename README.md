# Final Evolution Lab

Final Evolution Lab is an athlete operating system that combines a web dashboard, FastAPI backend, native iOS shell, and Unreal Engine integration snippets for game-mode launch and Sovereign Hub telemetry.

## What runs in this repository

| Area | Path | Stack | Local command |
| --- | --- | --- | --- |
| Web dashboard | `frontend/` | React + CRACO + Tailwind | `yarn start` |
| API backend | `backend/` | FastAPI + MongoDB | `uvicorn server:app --host 0.0.0.0 --port 8000` |
| Static mode audit | `scripts/smoke_test_modes.py` | Python JSON/INI checks | `python3 scripts/smoke_test_modes.py` |

Native iOS and Unreal Engine shipping assets are present as integration/configuration material, but the full UE project, packaged framework, and Xcode build environment are not available in this Linux workspace.

## Quick start

1. Start MongoDB locally or point the backend at a reachable MongoDB instance.
2. Copy env templates:
   - `cp backend/.env.example backend/.env`
   - `cp frontend/.env.example frontend/.env`
3. Install and run the backend:
   - `cd backend`
   - `pip install -r requirements.txt`
   - `uvicorn server:app --host 0.0.0.0 --port 8000`
4. Install and run the frontend:
   - `cd frontend`
   - `yarn install`
   - `yarn start`

The frontend defaults to `http://localhost:8000` if `REACT_APP_BACKEND_URL` is not set.

## Verification

- Frontend production build: `cd frontend && yarn build`
- Backend import/health smoke: `cd backend && python -m compileall .`
- Mode registry alignment: `python3 scripts/smoke_test_modes.py`

## Runtime notes

- Google auth depends on the Emergent auth service.
- AI/Bio-Fuel features require `EMERGENT_LLM_KEY` and the provider package.
- PayPal checkout degrades with a 503 response unless PayPal credentials are configured.
- Pixel Streaming can work with a pasted Eagle 3D iframe URL, while native launch deep links use `backend/ue_mode_maps.json` as the canonical mode-to-Unreal-token map.
