# AGENTS.md

## Cursor Cloud specific instructions

### Repository overview

This is a polyglot monorepo for **Final Evolution Lab**, a sports-tech / athletic-optimization product. It contains an Unreal Engine 5.7 client and a native iOS shell (neither buildable in a Cloud Agent VM), plus a runnable web stack. The parts that run in a Cloud Agent VM are the **FastAPI + MongoDB backend** and the **Create React App frontend** (generated from the emergent.sh `fastapi_react_mongo_shadcn` base; see `.emergent/emergent.yml`).

| Service | Path | Stack | Dev command | Port |
|---|---|---|---|---|
| **Backend API** | `backend/` | FastAPI + Uvicorn + MongoDB (motor) | `python3 -m uvicorn server:app --host 0.0.0.0 --port 8001` | 8001 |
| **Frontend** | `frontend/` | React 19 + CRA + CRACO + Tailwind + shadcn | `yarn start` | 3000 |
| **MongoDB** | (system service) | MongoDB 8.0 | `mongod --dbpath /data/db --bind_ip 127.0.0.1 --logpath /var/log/mongodb/mongod.log --fork` | 27017 |

All backend routes are mounted under the `/api` prefix (e.g. `GET /api/`, `GET /api/auth/me`). There is also an unprefixed `GET /health` k8s probe.

### Running the stack

1. **Start MongoDB first** (the backend calls `os.environ['MONGO_URL']` at import time and will crash if Mongo env vars are missing). Start with the `mongod` command above.
2. **Start the backend**: from `backend/`, run `python3 -m uvicorn server:app --host 0.0.0.0 --port 8001`. Verify with `curl localhost:8001/api/` → `{"message":"Final Evolution Lab API",...}`.
3. **Start the frontend**: from `frontend/`, run `yarn start` (CRACO dev server on port 3000). It proxies to the backend via `REACT_APP_BACKEND_URL`.

### Environment files (required, git-ignored)

These `.env` files are git-ignored and not committed, so they must exist locally for the stack to run. The update script recreates them if missing:

- `backend/.env`: `MONGO_URL=mongodb://localhost:27017`, `DB_NAME=test_database`. Optional: `EMERGENT_LLM_KEY`, `PAYPAL_CLIENT_ID`, `PAYPAL_SECRET`, `OPENAI_API_KEY`.
- `frontend/.env`: `REACT_APP_BACKEND_URL=http://localhost:8001`.

### Lint / Test / Build

- **Frontend lint**: ESLint is wired into the CRACO build (`react-hooks` rules in `craco.config.js`), so lint runs automatically during `yarn start` / `yarn build`. There is no standalone lint script, and standalone `npx eslint` fails because the project has no ESLint v9 flat config.
- **Frontend build**: `yarn build` in `frontend/`.
- **Backend tests**: `cd backend && REACT_APP_BACKEND_URL=http://localhost:8001 TEST_SESSION_TOKEN=<token> python3 -m pytest tests/` — the suite hits the **running** server over HTTP, so the backend (and Mongo) must be up first. Provide a session token (see Auth testing).
- **Backend lint/format tools** available: `flake8`, `black`, `mypy`, `isort`.
- The root `backend_test.py` targets a remote preview URL by default; override `self.base_url` or point at localhost to run it locally.

### Auth testing (no real OAuth needed)

Login normally uses emergent.sh Google OAuth, which can't complete in the VM. To test authenticated flows, seed a user + session directly in Mongo and use the token:

```
mongosh --quiet --eval "db=db.getSiblingDB('test_database');
db.users.insertOne({user_id:'helloworld-user',email:'hello@example.com',name:'Hello World',role:'athlete',sport:'basketball',prq_score:75,level:1,xp:0,streak_days:0,total_workouts:0,coins:100,followers:[],following:[],created_at:new Date().toISOString()});
db.user_sessions.insertOne({user_id:'helloworld-user',session_token:'helloworld-session-token',expires_at:new Date(Date.now()+7*864e5).toISOString(),created_at:new Date().toISOString()});"
```

- API: send `Authorization: Bearer <token>` (cookie `session_token=<token>` also works).
- Browser UI: in DevTools console run `localStorage.setItem('fel_session_token','<token>')`, then navigate to `/dashboard` (the axios interceptor in `App.js` attaches the Bearer token). Routes: `/` landing, `/login`, `/dashboard` (protected).

### Non-obvious notes

- `server.py` imports `paypalrestsdk` and `aiofiles`, which were missing from `backend/requirements.txt`; they have been added. Always install backend deps with the emergent extra index: `pip install -r requirements.txt --extra-index-url https://d33sy5i8bnduwe.cloudfront.net/simple/` (the `emergentintegrations` package is only on that index, not PyPI).
- AI/coach endpoints need `EMERGENT_LLM_KEY` or `OPENAI_API_KEY`; without them those specific endpoints return 500 but the rest of the app works. A few backend tests also fail without seeded production data / AI keys — these are app-level, not environment, issues.
- Frontend package manager is **yarn** (`packageManager: yarn@1.22.22` in `package.json`); a `yarn.lock` is generated on first install. Do not run `npm install` at the repo root.
- The Unreal Engine project (`UnrealStarter/`) and iOS app (`FinalEvolutionLab.xcodeproj`, `fastlane/`) cannot be built in a Cloud Agent VM (require UE 5.7 editor or Xcode on macOS).
