# AGENTS.md

## Cursor Cloud specific instructions

### Repository overview

This is a polyglot monorepo for **Final Evolution Lab**, a sports-tech / athletic-optimization product. The primary shipping client targets Unreal Engine 5.7 (C++ / Blueprint); the web + backend layers are the parts runnable in a Cloud Agent VM. Key runnable sub-projects:

| Sub-project | Path | Stack | Dev command |
|---|---|---|---|
| Main marketing/app site | `sites/final-evolution-main-site/` | React 18 + Vite 5 + TypeScript + Tailwind + Three.js + Supabase JS | `npm run dev` (port 5173) |
| Clinical Gate (medical disclaimer component) | `web/clinical-gate-react/` | React 18 + Vite 5 + TypeScript + Tailwind | `npm run dev` (port 5174) |
| Static PWA web shell (gateway, shop, wallet, play) | `web/` | Vanilla HTML/CSS/JS (Tailwind CDN) | `npx serve web -l 8080` from repo root |
| Supabase backend (DB + Edge Functions) | `supabase/` | PostgreSQL 17 + Deno Edge Functions | `supabase start` (requires Docker) |

### Running the web services

1. **Install dependencies** — run `npm install` in both `sites/final-evolution-main-site/` and `web/clinical-gate-react/`. The root `package.json` has no dependencies.
2. **Main site dev server**: `npm run dev` in `sites/final-evolution-main-site/` → http://localhost:5173
3. **Clinical gate dev server**: `npm run dev` in `web/clinical-gate-react/` → http://localhost:5174
4. **Static web shell**: `npx serve web -l 8080` from repo root → http://localhost:8080

### Lint / Typecheck / Build

- **Main site**: `npm run typecheck` (runs `tsc --noEmit`), `npm run build` (Vite production build)
- **Clinical gate**: `npx tsc --noEmit` (no lint script configured), `npm run build`
- No ESLint is configured for either React app.

### Environment variables

The main site reads Supabase and PayPal credentials from `.env` (Vite `VITE_` prefix). See `sites/final-evolution-main-site/.env.example`. The app runs without these env vars — features that depend on Supabase/PayPal gracefully degrade.

### Non-obvious notes

- The Unreal Engine project (`UnrealStarter/BasketballGame/`) and iOS app (`ios/FinalEvolutionLab/`) cannot be built in a Cloud Agent VM (requires UE 5.7 editor or Xcode on macOS).
- Supabase local dev (`supabase start`) requires Docker. If Docker is not available, the web apps still run — they just won't have a local backend.
- The root `package.json` is a shell with no `node_modules`; do not run `npm install` at root.
- Package manager is **npm** (lockfiles are `package-lock.json`).
