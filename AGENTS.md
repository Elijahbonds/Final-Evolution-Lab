# AGENTS.md

## Cursor Cloud specific instructions

### Repository overview

This is a polyglot monorepo for **Final Evolution Lab**, a sports-tech / athletic-optimization product. The runnable Cloud surfaces on this branch are the React web app, FastAPI backend, Firebase emulator/data-connect assets, and static validation scripts. Native iOS and Unreal Engine artifacts are present as source/config/integration packages but require macOS/Xcode or a full UE 5.7 project outside this VM.

| Sub-project | Path | Stack | Local command |
|---|---|---|---|
| Web athlete OS | `frontend/` | Create React App + CRACO + React + Tailwind | `npm start` (port 3000) |
| Backend API | `backend/` | FastAPI + MongoDB | `uvicorn server:app --host 0.0.0.0 --port 8000` |
| Firebase Data Connect | `dataconnect/` | Firebase Data Connect / GraphQL | `firebase emulators:start` |
| iOS native shell | `FinalEvolutionLab/` | SwiftUI + HealthKit + Firebase | Requires Xcode on macOS |
| Unreal integration package | `UnrealIntegration/` | UE 5.7 C++ drop-in snippets | Copy into full UE project before compiling |
| Unreal config mirror | `UnrealStarter/BasketballGame/` | JSON/INI shipping config | Static validation only in Cloud |

### Running the web app

1. Copy `frontend/.env.example` to `frontend/.env` and adjust values if needed.
2. Install dependencies in `frontend/`.
3. Run `npm start` in `frontend/` -> http://localhost:3000.
4. The app defaults API calls to the same origin when `REACT_APP_BACKEND_URL` is unset; set it to `http://localhost:8000` when running the backend separately.

### Running the backend

1. Copy `backend/.env.example` to `backend/.env`.
2. Ensure MongoDB is reachable at `MONGO_URL`.
3. Install Python requirements from `backend/requirements.txt`.
4. Run `uvicorn server:app --host 0.0.0.0 --port 8000` from `backend/`.

Optional provider keys:
- `EMERGENT_LLM_KEY` enables Bio-Fuel AI vision scan.
- `PAYPAL_CLIENT_ID` / `PAYPAL_CLIENT_SECRET` enable checkout flows.
- `E3DS_API_KEY` enables production Eagle 3D streaming integration.

### Verification

- Frontend build: `npm run build` in `frontend/`.
- Backend import/smoke: `python -m py_compile backend/server.py backend/core.py backend/routers/biofuel.py`.
- Mode registry smoke test: `python3 scripts/smoke_test_modes.py` from repo root.
- Backend integration tests live in `backend/tests/` and expect a running backend plus MongoDB/test session seed.

### Unreal Engine and iOS constraints

- `UnrealIntegration/` is not a standalone UE project. It includes drop-in C++ files that reference classes from the full Final Evolution Lab UE 5.7 project.
- `UnrealStarter/BasketballGame/` contains config and registry mirrors only; no `.uproject` is committed on this branch.
- `FinalEvolutionLab/` requires Xcode/macOS and local Firebase/iOS credentials; it cannot be built inside the Linux Cloud VM.

### Data-layer notes

- Runtime backend persistence uses MongoDB via `backend/core.py`.
- Social/community iOS paths use Firebase Data Connect assets in `dataconnect/`.
- Health/readiness bridge rules live in `firestore.rules` and `infra/SYSTEM_SCAN_FIRESTORE_SCHEMA.md`.
- Supabase is not present on this branch.

### Non-obvious notes

- The root `package.json` is intentionally ignored for React Native/Expo artifacts; use `frontend/package.json` for the web app.
- The production web shell is in `frontend/public/` and should stay product-owned; do not reintroduce scaffold badges or analytics snippets without an explicit product decision.
- Keep game mode IDs aligned across `backend/ue_mode_maps.json`, `infra/ue5_config/DefaultGame.ini`, `UnrealIntegration/Source/FinalEvolutionLab/FELEmergentDeepLinkSubsystem.cpp`, Swift `GameMode`, and `scripts/smoke_test_modes.py`.
