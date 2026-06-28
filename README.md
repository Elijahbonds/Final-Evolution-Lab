# Final Evolution Lab

Final Evolution Lab is an athlete operating system with a React web dashboard,
FastAPI backend, SwiftUI native shell, and Unreal Engine integration snippets.
The Cloud-runnable product surface is the web app plus API.

## Runnable services

| Service | Path | Stack | Command |
| --- | --- | --- | --- |
| Web dashboard | `frontend/` | React 19, CRA/CRACO, Tailwind | `npm install && npm start` |
| API backend | `backend/` | FastAPI, Motor/MongoDB | `pip install -r requirements.txt && uvicorn server:app --host 0.0.0.0 --port 8000` |

The SwiftUI app and Unreal Engine project assets require macOS/Xcode or Unreal
Engine and are not buildable in this Linux Cloud VM.

## Local setup

1. Copy env templates:

   ```bash
   cp frontend/.env.example frontend/.env
   cp backend/.env.example backend/.env
   ```

2. Start MongoDB locally or update `backend/.env` with a reachable
   `MONGO_URL`. If no env file is present, the backend defaults to
   `mongodb://localhost:27017` and database `final_evolution_lab`.

3. Start the API:

   ```bash
   cd backend
   pip install -r requirements.txt
   uvicorn server:app --host 0.0.0.0 --port 8000
   ```

4. Start the web dashboard:

   ```bash
   cd frontend
   npm install
   npm start
   ```

5. Open `http://localhost:3000`.

## Verification

Useful checks from a fresh checkout:

```bash
cd frontend && npm install && npm run build
cd backend && pip install -r requirements.txt
python3 -c "import sys; sys.path.insert(0, 'backend'); import server; print('backend import ok')"
python3 -m py_compile backend/core.py backend/server.py backend/routers/*.py
```

## Feature availability

- Authentication uses the Emergent Google OAuth handshake in production.
- AI Coach and Bio-Fuel vision scanning require `EMERGENT_LLM_KEY` and the
  optional private Emergent LLM SDK. Without them, non-AI endpoints still run
  and AI surfaces return clear fallback/unavailable responses.
- PayPal checkout requires sandbox or production `PAYPAL_CLIENT_ID` and
  `PAYPAL_SECRET`.
- Pixel Streaming is currently wired to the local Sovereign Hub data-feed flow,
  not an E3DS cloud iframe. Native clients receive launch commands through the
  Sovereign bridge/deep-link path.

## Native and Unreal notes

- SwiftUI sources live under `FinalEvolutionLab/`; building requires Xcode on
  macOS and local signing/Firebase assets.
- Unreal integration snippets live under `UnrealIntegration/` and
  `UnrealStarter/`. Full UE compile/cook/package is not possible from this
  checkout because engine/editor assets and the complete `.uproject` are not
  present in the Cloud VM.
