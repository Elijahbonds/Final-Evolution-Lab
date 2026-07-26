# AGENTS.md

> **Working on the web app (Babylon/Next.js)? Start with
> [`docs/BLUEPRINT.md`](docs/BLUEPRINT.md) and
> [`docs/AGENT-ACCESS-AND-PROTOCOL.md`](docs/AGENT-ACCESS-AND-PROTOCOL.md),
> then run `node tools/agent_sync.mjs <your-agent-id>`.** Those supersede the
> NEXUS/iOS orchestration below for anything web-first. The rest of this file
> remains accurate for the C++/Swift retail ship.

## Cursor Cloud specific instructions

### Repository overview

This is the **canonical NEXUS monorepo** for **Final Evolution Lab** — a world-class athlete OS (engine + gameplay + economy + education + Studio IDE). **Production retail ship is NEXUS only:** custom C++20 engine (`engine/`, `app/gameplay/`, `runtime/`) + Swift iOS app (`FinalEvolutionLab/`). See **`NEXUS_ONLY_PIVOT.md`** and **`SHIPPING_ARCHITECTURE.md`**.

Unreal Engine 5.7 and Unity 6 remain **archived/legacy reference** in-repo — do not extend for retail ship.

Runnable sub-projects in Cloud Agent VM (web + backend):

| Sub-project | Path | Stack | Dev command |
|---|---|---|---|
| **New marketing site** (finalevolutiongroup.com) | `sites/finalevolutiongroup.com/` | React 18 + Vite 5 + TypeScript + Tailwind | `npm run dev` (port 5175) |
| Main marketing/app site (legacy) | `sites/final-evolution-main-site/` | React 18 + Vite 5 + TypeScript + Tailwind + Three.js + Supabase JS | `npm run dev` (port 5173) |
| Clinical Gate (medical disclaimer component) | `web/clinical-gate-react/` | React 18 + Vite 5 + TypeScript + Tailwind | `npm run dev` (port 5174) |
| Static PWA web shell (gateway, shop, wallet, play) | `web/` | Vanilla HTML/CSS/JS (Tailwind CDN) | `npx serve web -l 8080` from repo root |
| Supabase backend (DB + Edge Functions) | `supabase/` | PostgreSQL 17 + Deno Edge Functions | `supabase start` (requires Docker) |

### NEXUS build (requires macOS + Xcode for iOS)

```bash
cd ~/Final-Evolution-Lab
./scripts/nexus_build_gate.sh          # Engine CI gate
./scripts/build-nexus-ios.sh           # iOS static libs
./scripts/archive-ios-testflight.sh --dry-run
```

Full matrix: **`NEXUS_RESUME.md`**.

### iOS build floors (verified, not inferred)

**Xcode 16.3+ / Swift 6.1+ required.** Two hard floors:

- `project.pbxproj` is `objectVersion = 77` and uses
  `PBXFileSystemSynchronizedRootGroup` — **Xcode 15 cannot open this project
  at all.**
- **172 declarations apply `nonisolated` to a *type***, which is Swift 6.1
  (SE-0449). Swift 6.0 / Xcode 16.0–16.2 rejects every one. Verified against a
  real Swift 6.0.3 compiler, and re-counted against this branch.

**Cannot be BUILT in a Cloud Agent VM — but it can be partially CHECKED.**
74% of sources import SwiftUI/UIKit/Firebase, so no linkable build exists
off-Apple. `bash tools/swift_typecheck.sh` type-checks the Foundation-only
core (physics, rules, economy, matchmaking) with a real Swift compiler on
Linux.


### Running the web services

1. **Install dependencies** — run `npm install` in `sites/finalevolutiongroup.com/`, `sites/final-evolution-main-site/`, and `web/clinical-gate-react/`. The root `package.json` has no dependencies.
2. **New marketing site**: `npm run dev` in `sites/finalevolutiongroup.com/` → http://localhost:5175
3. **Legacy main site**: `npm run dev` in `sites/final-evolution-main-site/` → http://localhost:5173
4. **Clinical gate dev server**: `npm run dev` in `web/clinical-gate-react/` → http://localhost:5174
5. **Static web shell**: `npx serve web -l 8080` from repo root → http://localhost:8080

### Lint / Typecheck / Build

- **New marketing site**: `npm run typecheck` / `npm run build` in `sites/finalevolutiongroup.com/`
- **Legacy main site**: `npm run typecheck` / `npm run build` in `sites/final-evolution-main-site/`
- **Clinical gate**: `npx tsc --noEmit` / `npm run build` in `web/clinical-gate-react/`
- **CRA dashboard**: `npm run build` in `frontend/` (legacy-peer-deps on install)
- No ESLint is configured for any React app.

### Web deploy (Firebase Hosting — not Vercel)

Static web surfaces deploy to **Firebase Hosting (Classic)** on project `final-evolution-lab`. Full guide: **`docs/FIREBASE_HOSTING_DEPLOY.md`**.

```bash
./scripts/deploy-hosting.sh fel-dashboard   # CRA dashboard (frontend/build)
firebase deploy --only hosting:fel-dashboard
```

Custom domain **`finalevolutiongroup.com`**: Firebase Console → Hosting → Add custom domain. Handoff: **`artifacts/coord/vercel_migration_handoff.json`**.

### Unreal Engine / Unity (archived — not production)

- **Unreal:** `UnrealIntegration/`, `UnrealStarter/` — legacy UE 5.7 host; superseded by NEXUS.
- **Unity:** `Unity6-FinalEvolution-Lab/` — archived prototype.
- Not runnable in Cloud Agent VM (requires UE editor or Xcode on macOS for legacy paths).

### Environment variables

The main site reads Supabase and PayPal credentials from `.env` (Vite `VITE_` prefix). See `sites/final-evolution-main-site/.env.example`. The app runs without these env vars — features that depend on Supabase/PayPal gracefully degrade.

### Platform (Cursor control plane)

| Surface | Path | Role |
|---------|------|------|
| MCP server | `tools/nexus-cursor-mcp/` | Cursor Desktop tools: `playtest`, `list_artifacts`, `studio_open_file`, `studio_run_playtest`, `build_gate` |
| Tool registry | `Config/nexus_cursor_tool_registry.json` | Shared whitelist with iOS NEXUS Agent |
| Agent CLI | `build-headless/nexus_agent_cli` | `fel.studio.*` queries + generative commands (see `docs/NEXUS_AGENT_PROTOCOL.md`) |
| Artifacts | `artifacts/playtest/latest.json`, `artifacts/cursor-nexus/last-hud-snapshot.json` | Playtest + HUD observability for agents |

Setup: `docs/CURSOR_NEXUS_CONTROL.md`.

### Non-obvious notes

- **Production iOS ship:** NEXUS embed via `FinalEvolutionLab.xcodeproj` + `scripts/build-nexus-ios.sh` — not UnrealFramework.
- Label **preview/beta** where **`NEXUS_DELIVERY_MATRIX.md`** gaps remain (Metal stub, unsigned archive, live receipt POST).
- **NEXUS Studio IDE** (`docs/NEXUS_STUDIO_IDE.md`) — in-app code browser + Run panel; pairs with **Cursor MCP** control plane (`docs/CURSOR_NEXUS_CONTROL.md`, `tools/nexus-cursor-mcp/`).
- Supabase local dev (`supabase start`) requires Docker. If Docker is not available, the web apps still run — they just won't have a local backend.
- The root `package.json` is a shell with no `node_modules`; do not run `npm install` at root.
- Package manager is **npm** (lockfiles are `package-lock.json`).
- Vision alignment audits: **`docs/NEXUS_VISION_ALIGNMENT.md`**.
- **Agent orchestration:** **`docs/NEXUS_AGENT_ORCHESTRATION.md`** defines **Project Manager** and **Senior Advisor** coordinator roles (fleet status, P0–P3 queue, retask rules, subagent delegation). Machine-readable roles: **`Config/nexus_agent_roles.json`**. PM maintains **`docs/NEXUS_AGENT_FLEET_STATUS.md`** after each subagent completion. Cursor skill: **`~/.cursor/skills/nexus-pm-advisor/SKILL.md`**.
- **Support agents (parallel helpers):** **`support_build_verify`** (build gates, xcodebuild, bundle inspection → PASS/FAIL logs) and **`support_docs_drift`** (vision/delivery/fleet doc updates, honest drift labels, optional mirror sync). Assist primary specialties only — no vertical ownership. See **Support agents** in **`docs/NEXUS_AGENT_ORCHESTRATION.md`**. Cursor skill: **`~/.cursor/skills/nexus-support-agents/SKILL.md`**.
- **Idle brainstorm protocol:** When a specialty has no in-flight task (blocked, waiting, or support PASS complete), agents run a **15-min bounded brainstorm** → **`## Brainstorm handoff`** with gap, proposed assist, pair specialty, P0–P3, and Advisor check. PM ingests into **`docs/NEXUS_AGENT_FLEET_STATUS.md`** (**Idle / brainstorming**); **no auto-spawn** without Advisor **APPROVED**. See **Idle agent brainstorm** in **`docs/NEXUS_AGENT_ORCHESTRATION.md`**.
