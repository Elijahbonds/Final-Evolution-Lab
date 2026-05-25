# Backend and web surfaces

## Backend (`backend/`)

- **FastAPI** application (`server.py`, `core.py`, `routers/`).
- Provides REST endpoints for modes, fitness, vault/session style flows, analytics—**exact routes evolve**; agents should search `backend/routers/` for current paths.
- Used together with **configured hub URLs** in game/server deployment (not hardcoded in this reference).

## Frontend (`frontend/`)

- **React** SPA components (`frontend/src/`) — dashboards (e.g. vault/FEL OS–style UIs).
- Conceptually aligns with content shown in **WKWebView** inside the Unreal iOS host; URLs and bundling depend on your overlay loader configuration.

## Release and Distribution Metadata

From a web platform perspective, distribution metadata is tracked via a standard release payload detailing build versions and official Store/TestFlight links (see **`DISTRIBUTION_CANONICAL.md`**). AltStores, direct IPA installations, or proprietary release registries are not used.
