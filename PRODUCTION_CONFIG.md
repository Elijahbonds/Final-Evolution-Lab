# Production configuration — Gold Master Sovereign

Use with **Supabase Edge Functions**, **Netlify `web/`**, and **TestFlight**.

## Stripe

- **LIVE mode** for production revenue.
- **`sk_live_*`** and webhook signing **`whsec_*`** are stored in **Supabase Vault / Edge secrets** (`stripe-webhook-handler`, `wix-order-completed`). Do not commit or paste keys into AI Studio bundles.

## TestFlight

- Public invite placeholder: **https://testflight.apple.com/join/finalevolution**  
- Replace with the real App Store Connect link when available.

## Vertical Velocity Academy (VVA)

- **Data-driven Mode** in the **Unity/Unreal** runtime: load module JSON from **Supabase Storage** or REST.
- **Swift** mirrors: `Config/ACADEMY_CURRICULUM_V1.json`, `Source/Models/VerticalVelocityAcademy.swift`, `PRQManager` Cloud Cortex prompts.

## Hosting

| Asset | Location |
|-------|----------|
| **Mac `.dmg`** | **Supabase Storage** (bucket policy + public or signed URL) — see `DOCS/SOVEREIGN_DMG_STORAGE.md` |
| **Static web / PWA** | **Netlify** — `publish = web` in `netlify.toml`; COOP/COEP in `web/_headers` for `/play/*` |
| **Wix → wallet** | Velo `post_felRelayWixOrder` → Supabase **`wix-order-completed`** (not `stripe-webhook-handler`) |

## Medical disclaimer (first-run)

- **This repo** uses **SwiftUI** (`ContentView`, onboarding), not `App.tsx`. A mandatory disclaimer gate belongs in **`FinalEvolutionLabUnrealApp.swift` / onboarding flow** or your **Wix** shell if the web app is separate.
