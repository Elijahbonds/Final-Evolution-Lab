# AGENTS.md

## Cursor Cloud specific instructions

### Overview

Final Evolution Lab is a multi-platform athletic performance ecosystem. The runnable web services in this repo are:

| Service | Directory | Dev command | Port |
|---|---|---|---|
| Main Marketing Site (React + Vite + Three.js) | `sites/final-evolution-main-site/` | `npm run dev` | 5173 |
| Clinical Gate (React + Vite + Tailwind) | `web/clinical-gate-react/` | `npm run dev` | 5174 |
| Static PWA Web Shell | `web/` | `npx serve web` (from repo root) | 8080 |
| Supabase (Postgres, Auth, Realtime, Edge Functions) | `supabase/` | `supabase start` (from repo root) | 54321 (API), 54322 (DB), 54323 (Studio) |

iOS (Swift/SwiftUI), Unreal Engine 5.7 (C++), and Unity 6 (C#) targets are **not runnable** in this cloud VM — they require macOS/Xcode, UE5 editor, or Unity Hub respectively.

### Lint / Typecheck / Build

- **Main site typecheck:** `npm run typecheck` (or `npx tsc --noEmit`) in `sites/final-evolution-main-site/`
- **Main site build:** `npm run build` in `sites/final-evolution-main-site/`
- **Clinical gate build:** `npm run build` in `web/clinical-gate-react/`
- No ESLint configuration exists in either web project.

### Supabase local dev

- Requires Docker daemon running (`sudo dockerd` if not already up, then `sudo chmod 666 /var/run/docker.sock` for non-root access).
- `supabase start` from repo root pulls ~15 Docker images on first run (~60 s). Subsequent starts are much faster.
- `supabase status` shows all service URLs and API keys.
- Migrations in `supabase/migrations/` are applied automatically on `supabase start`.
- Edge functions (Stripe webhook, PayPal verify, Wix relay) live in `supabase/functions/` and are served via the local Supabase edge runtime.
- `imgproxy` and `pooler` services are expected to show as stopped — they are optional and not needed for local dev.

### Environment variables

The main site uses `VITE_` prefixed env vars (loaded by Vite from `.env` files):
- `VITE_PAYPAL_CLIENT_ID` — PayPal checkout (defaults to `sb` sandbox)
- `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY` — Supabase connection (can point to local `127.0.0.1:54321`)
- `VITE_ELEVENLABS_API_KEY` — optional TTS narration

The static web shell loads Supabase credentials from inline JS; no build step needed.

### Gotchas

- The root `package.json` is a minimal stub for the static web shell (no `dev` script, no dependencies). Web app dependencies live in their respective subdirectory `package.json` files.
- There is no root-level lockfile; each sub-project (`sites/final-evolution-main-site/`, `web/clinical-gate-react/`) has its own `package-lock.json`.
- Stripe/PayPal webhook edge functions require external API secrets that are not committed; they will return errors without those secrets configured, but local Supabase itself runs fine.
