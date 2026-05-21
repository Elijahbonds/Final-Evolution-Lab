# AGENTS.md

## Shipping target (anti-drift)

**Unreal Engine 5.7** is the canonical production shipping target per leadership decision. See `SHIPPING_ARCHITECTURE.md`.

- Do not implement new production gameplay in Unity.
- Do not revive SwiftUI-first hosting or Unreal-as-a-Library / XCFramework embedding.
- One retail iOS app: Unreal host + native WKWebView dashboard overlay.
- Distribution: App Store Connect / TestFlight only. No sideload/AltStore/Sovereign Store.
- Unity and Swift remain reference/prototype. Production fixes land in Unreal.

## Cursor Cloud specific instructions

### Repository overview

This is a polyglot monorepo for **Final Evolution Lab**, a sports-tech / athletic-optimization product. The primary shipping client targets Unreal Engine 5.7 (C++ / Blueprint); the web + backend layers are the parts runnable in a Cloud Agent VM. Key runnable sub-projects:

| Sub-project | Path | Stack | Dev command |
|---|---|---|---|
| **New marketing site** (finalevolutiongroup.com) | `sites/finalevolutiongroup.com/` | React 18 + Vite 5 + TypeScript + Tailwind | `npm run dev` (port 5175) |
| Main marketing/app site (legacy) | `sites/final-evolution-main-site/` | React 18 + Vite 5 + TypeScript + Tailwind + Three.js + Supabase JS | `npm run dev` (port 5173) |
| Clinical Gate (medical disclaimer component) | `web/clinical-gate-react/` | React 18 + Vite 5 + TypeScript + Tailwind | `npm run dev` (port 5174) |
| Static PWA web shell (gateway, shop, wallet, play) | `web/` | Vanilla HTML/CSS/JS (Tailwind CDN) | `npx serve web -l 8080` from repo root |
| Supabase backend (DB + Edge Functions) | `supabase/` | PostgreSQL 17 + Deno Edge Functions | `supabase start` (requires Docker) |

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
- No ESLint is configured for any React app.

### Unreal Engine (not runnable in Cloud Agent VM)

- 12 fully wired game modes via `EFELArenaMode` enum + per-mode session subsystems
- Pixel Streaming enabled (`PIXEL_STREAMING_ENABLED=1`), WebServers infra under `Samples/PixelStreaming/WebServers/`
- Exercise demo pipeline: `UFELExerciseDemoPipelineSubsystem` maps each mode to Academy module montages (mod1-mod12)

### Environment variables

The main site reads Supabase and PayPal credentials from `.env` (Vite `VITE_` prefix). See `sites/final-evolution-main-site/.env.example`. The app runs without these env vars — features that depend on Supabase/PayPal gracefully degrade.

### Non-obvious notes

- The Unreal Engine project (`UnrealStarter/BasketballGame/`) and iOS app (`ios/FinalEvolutionLab/`) cannot be built in a Cloud Agent VM (requires UE 5.7 editor or Xcode on macOS).
- Supabase local dev (`supabase start`) requires Docker. If Docker is not available, the web apps still run — they just won't have a local backend.
- The root `package.json` is a shell with no `node_modules`; do not run `npm install` at root.
- Package manager is **npm** (lockfiles are `package-lock.json`).
