# AGENTS.md

## Repository overview

**Final Evolution Lab (FEL)** is a sports-tech / athletic-optimization super-app. The repo is a polyglot monorepo with three primary sub-projects:

| Sub-project | Path | Stack | Dev command |
|---|---|---|---|
| iOS Swift app | `FinalEvolutionLab/` | SwiftUI, HealthKit, Firebase, MultipeerConnectivity | Xcode (macOS only) |
| FastAPI backend | `backend/` | Python 3, FastAPI, Pydantic v2, Firebase/Firestore | `uvicorn backend.server:app --reload` (port 8000) |
| React web dashboard | `frontend/` | React 18, CRA + CRACO, Tailwind, shadcn/ui | `npm start` in `frontend/` (port 3000) |

---

## Sub-project details

### iOS Swift app (`FinalEvolutionLab/`)

- **Entry point:** `FinalEvolutionLabApp.swift`
- **Architecture:** MVVM — `LabViewModel` is the central state hub
- **Key directories:**
  - `Models/` — game engines, economy (`ShardEconomy`, `CoachEconomy`), scan, avatar, curriculum
  - `Views/` — all feature UIs. `GameModeRouter.swift` dispatches all 20 game modes to dedicated view files
  - `ViewModels/` — `LabViewModel.swift`, `TrainingViewModel.swift`
  - `Services/` — HealthKit, Firebase, WebSocket (`ArenaWebSocketService`), Realtime DB (`ArenaRealtimeService`), `EmergentRealtimeTrust` (anti-cheat gate)
  - `Generated/SocialDataConnect/` — Firebase Data Connect generated Swift client
- **Persistence:** `SaveSystem.swift` (UserDefaults). No remote profile sync yet.
- **Build:** Xcode 15+ on macOS. Cannot be built in a Cloud Agent VM.

### FastAPI backend (`backend/`)

- **Entry point:** `backend/server.py`
- **Run:** `pip install -r backend/requirements.txt && uvicorn backend.server:app --reload` → http://localhost:8000
- **Key routers:** `routers/games.py` (physics, arena, venue generation, dunk scoring), `routers/biofuel.py`, `routers/education_tracks.py`, `routers/system_scan.py`
- **Data:** Largely seeded/in-memory. MongoDB (`motor`) and Firestore are wired but most endpoints return fixtures.
- **Tests:** `python -m pytest backend/tests/` and `python scripts/smoke_test_modes.py`

### React web dashboard (`frontend/`)

- **Run:** `cd frontend && npm install --legacy-peer-deps && npm start` → http://localhost:3000
- **Purpose:** Ops/distribution/quality-gate dashboard — not the consumer game UI.
- **Key components:** `FELOSDashboard`, `SovereignDashboard`, `BioFuel`, `QualityGates`, `DistributionPage`

---

## Firebase / Data Connect

- **Project ID:** `final-evolution-lab`
- **Realtime DB:** `https://final-evolution-lab-default-rtdb.firebaseio.com`
- **Data Connect service:** `elijahbonds` (PostgreSQL in us-east4, instance `elijahbonds-fdc`, db `fdcdb`)
- **Schema:** `dataconnect/schema/schema.gql` — includes `UserProfile`, `CreatorCard`, `ShardLedger`, `ArenaSession`
- **Security rules:** `database.rules.json` (Realtime DB), `firestore.rules`
- **Firebase config:** `firebase.json`

---

## Game modes

20 modes defined in `backend/FEL_ModeManager.production.json` and `FinalEvolutionLab/Models/GameMode.swift`:

- **Production (12):** basketball_h2h, basketball_dunk, basketball_3v3, basketball_irl, karate_h2h, karate_endless, baseball, football, soccer, golf, tennis, volleyball, surfing
- **Staging (4):** skateboarding, snowboarding, gymnastics, brain_brawl
- **Preview (2):** who_scene_it, court_carnival
- **Non-game module:** market_browse (no PRQ delta, no shards per round)

Each mode has a dedicated SwiftUI view file in `FinalEvolutionLab/Views/` and is dispatched by `GameModeRouter.swift`.

---

## CI / CD

`.github/workflows/firebase-deploy.yml` — 4-job pipeline:
1. `validate-registries` — JSON lint + render mode assertions + smoke tests
2. `build-frontend` — React build with Firebase env vars from GitHub Secrets
3. `deploy-firebase` — Firebase Hosting + Firestore rules + Realtime DB rules (push only)
4. `deploy-dataconnect` — Data Connect schema + connectors (main branch only)

Required GitHub Secrets: see inline comments in the workflow file.

---

## Unreal Engine integration

- UE project (`UnrealStarter/BasketballGame/`) and C++ bridge (`UnrealIntegration/`) exist as **config + bridge stubs only** — no `.uproject`, maps, or assets are committed.
- The bridge handshake is `FEL-SOVEREIGN-BRIDGE-v2`. See `UnrealIntegration/Source/FinalEvolutionLab/`.
- Cannot be built in a Cloud Agent VM (requires UE 5.7 editor).

---

## Non-obvious notes

- `GameModeRules.swift` gates shard rewards via `rewardEligibleMinActions` — `market_browse` is 0 (no rewards).
- `EmergentRealtimeTrust` blocks WebSocket payloads from mutating PRQ/shards without a server-bound trusted session ID. Override in dev: `FEL_ALLOW_UNVERIFIED_EMERGENT=1`.
- Coach critique flow: athlete pays 500 shards, coach earns 400 (80%). `LabViewModel.critiqueCoachEarningShards = 400`. Stale escrow auto-releases after 7 days on next app launch.
- `ArenaPadOverlay` / `ArenaPadShellView` — the retro dual-analog gamepad overlay (formerly named PS2*).
- `SignatureComboEngine` — the signature dunk combo engine (formerly GoldenEraEngine).
- `FELScoreManager` / `FELNativeBridge` — score broadcast services (formerly Rork*).
