# Backend and web surfaces

## Backend (`backend/`)

- **FastAPI** application (`server.py`, `core.py`, `routers/`).
- Provides REST endpoints for modes, fitness, vault/session style flows, analytics—**exact routes evolve**; agents should search `backend/routers/` for current paths.
- Used together with **configured hub URLs** in game/server deployment (not hardcoded in this reference).

## Frontend (`frontend/`)

- **React** SPA components (`frontend/src/`) — dashboards (e.g. vault/FEL OS–style UIs).
- Conceptually aligns with content shown in **WKWebView** inside the Unreal iOS host; URLs and bundling depend on your overlay loader configuration.

## Superapp implication

“Superapp distribution” from a **web platform** perspective usually means: **publish a release record** pointing to **ASC / TestFlight** (public link or internal group), plus optional **deep links** (`finalevolution://…`) documented for QA. This repo does **not** define a proprietary Superapp API unless you add one—use **`DISTRIBUTION_SUPERAPP.md`** as the contract placeholder.
