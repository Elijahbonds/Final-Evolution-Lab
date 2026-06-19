# Final Evolution Lab

Final Evolution Lab is an athlete operating system and sports-game platform. This
branch's runnable Cloud VM surface is a React superapp plus a FastAPI backend;
native Unreal Engine/iOS builds remain external to this Linux environment.

## Runnable projects

| Project | Path | Stack | Command |
|---|---|---|---|
| Web superapp | `frontend/` | React 19, CRACO, Tailwind | `npm install && npm start` |
| API | `backend/` | FastAPI, Motor/MongoDB | `pip install -r requirements.txt && uvicorn server:app --host 0.0.0.0 --port 8000` |

## Local configuration

Copy the example files before local development:

```bash
cp backend/.env.example backend/.env
cp frontend/.env.example frontend/.env
```

Defaults are suitable for local development:

- Frontend API: `REACT_APP_BACKEND_URL=http://localhost:8000`
- Backend DB: `MONGO_URL=mongodb://localhost:27017`
- Backend database: `DB_NAME=final_evolution_lab`

Provider-backed features such as AI, PayPal, and E3DS require their optional
environment variables. Without those credentials, the app still boots and core
seeded flows remain available.

## Product surface

- 19 product modes are registered in the backend mode catalog.
- 18 UE launchable modes are exposed to Sovereign/Pixel Streaming; the
  `market_browse` shop module is intentionally not launchable as gameplay.
- Backend health checks are available at `/health` and `/api/health`.

## Verification

```bash
cd frontend && npm run build
cd backend && python -m pytest tests/test_iteration4_e3ds.py -q
```

Unreal Engine 5.7 and iOS targets require UE/Xcode tooling and cannot be built
inside this Linux Cloud VM.
