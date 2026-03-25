# Final Handover — Wix, AI Studio, Sovereign Web

Use this file as the **single source** for copy-paste prompts. Names matter:

| Name | What it is |
|------|------------|
| **`post_felRelayWixOrder`** | Wix Velo **HTTP function** (your site `/_functions/felRelayWixOrder`). |
| **`wix-order-completed`** | Supabase **Edge Function** URL: `…/functions/v1/wix-order-completed` (shared secret `X-FEL-Wix-Secret`). |
| **`stripe-webhook-handler`** | Stripe-only; **not** for raw Wix payloads. |

There is **no `App.tsx`** in this repository — the shipped app shell is **Swift** (`Source/`, `FinalEvolutionLabUnrealApp.swift`). Any **React** “Medical Gate” lives in **Wix** or a separate web repo; align AI Studio output with **this** repo where noted below.

---

## 1. Response to Wix / AI Coach (Velo + checkout metadata)

Copy everything inside the block into your Wix / Gemini chat.

```
Authorization & Dev Mode

• I authorize enabling Wix Dev Mode and Velo for this site.
• Goal: bridge Wix Store paid orders to our Supabase Edge Function that credits Evolution Shards.

Technical contract (do not rename on Supabase):
  – Supabase endpoint: POST https://<PROJECT>.supabase.co/functions/v1/wix-order-completed
  – Header: X-FEL-Wix-Secret: <same value as Supabase secret WIX_WEBHOOK_SHARED_SECRET>
  – JSON body must include: wix_order_id, supabase_user_id (UUID), shard_delta (and cortex_delta if applicable), optional athlete_id, optional product_sku.

Velo:
  – Implement or finish the HTTP function post_felRelayWixOrder that forwards JSON to the URL above.
  – Reference file pattern: repo path wix/velo/backend/http-functions.js (copy logic into your site’s Velo backend).

Checkout / JOIN NOW:
  – Ensure logged-in members pass supabase_user_id (from our auth or a custom profile field) and athlete_id into the order payload or Automation step that calls the relay.
  – Dark Clinical aesthetic: keep existing dark background, cyan accents, high-contrast type for any new React/Velo UI.

Do not send Wix traffic to stripe-webhook-handler — that endpoint expects Stripe signatures only.
```

---

## 2. Master prompt for AI Studio (Gold Master + repo truth)

Copy everything inside the block into **Google AI Studio** (system + user task). It is written so **Gemini can complete** without assuming files that don’t exist in `final-evolution-lab`.

```
You are the Lead Systems Architect for Final Evolution (final-evolution-lab).

PRODUCTION PARAMETERS (treat as fixed unless the user says otherwise):
1) Financial: Stripe live keys are stored as Supabase Edge secrets — use live-mode checkout and webhook logic only. Do not print or echo secrets.
2) TestFlight: Use placeholder public link https://testflight.apple.com/join/finalevolution for any /join / “Get the app” CTA until the real App Store Connect link is provided.
3) VVA: Vertical Velocity Academy modules are data-driven in Swift (`Source/Models/VerticalVelocityAcademy.swift`, `Config/ACADEMY_CURRICULUM_V1.json`) and Unreal overlays; Unity/Unreal JSON can be extended to fetch from Supabase Storage — propose schema, don’t invent bucket names without a placeholder.
4) DMG: Prefer hosting the Mac `.dmg` on Supabase Storage (public bucket + signed URL or public object URL) for Sovereign control; keep Netlify `web/` for static PWA only. Document bucket policy and CORS in a short markdown section.

REPO CONSTRAINTS (critical):
• This repo does NOT contain App.tsx. The iOS app entry is Swift (`FinalEvolutionLabUnrealApp.swift`, `ContentView.swift`). If a “Medical Disclaimer first-run gate” is required, implement it in SwiftUI (e.g. @AppStorage gate before main tabs) OR state explicitly that the change belongs to a separate Wix/React repo.
• PWA gateway `/play/` is static HTML (`web/play/index.html`) with `web/_headers` (COOP/COEP on /play/*) and `netlify.toml` publish = web. Do not remove COOP/COEP for WebGPU/WASM.

TASK:
1) List any “open questions” from prior reviews and resolve them in one pass.
2) If “6 code errors” were reported, locate them by file path — if paths don’t exist in this repo, say so and give the equivalent fix in Swift or web/play.
3) Finalize `/play/` PWA: manifest `start_url` /play/?source=pwa, service worker, headers.
4) Output: (A) bullet changelog, (B) exact file edits as diffs or full file bodies, (C) verification checklist for testers.

Do not fabricate API keys or Supabase project refs.
```

---

## 3. Supabase Storage for DMG (Sovereign link)

1. Create bucket `fel-distribution` (or similar) — **public read** for the `.dmg` object only, or **signed URLs** with long TTL.
2. Upload `FinalEvolutionLabUnreal-Sovereign.dmg` from `scripts/package_sovereign_desktop.sh` output.
3. Set `web/play/index.html` Mac button `href` to the **public URL** (or a short redirect on your domain).
4. Keep **anon** key out of DMG URLs; public bucket URLs are fine for read-only binaries.

---

## 4. “What’s next?” (pick one)

| Option | Action |
|--------|--------|
| **Alpha 1 Welcome Email** | Draft tester email: install PWA → sign Sovereign Wallet → pair DualSense → confirm Spiral/Push 1,2. |
| **Audit Wix → Supabase** | After Velo is live, compare `sovereign_market_transactions.metadata->source = 'wix'` to Wix order IDs. |
| **Sovereign Pro dashboard** | Extend `web/wallet/` + in-app PRQ for Cortex + Bio-Electric stats. |

---

## 5. Making sure Gemini “can complete” this task

- **Give AI Studio access** to this repo or paste **`HANDOVER_FINAL_EVOLUTION.md`** + **`web/DEPLOY.txt`** + **`DOCS/SOVEREIGN_STRIPE_PRODUCTION.md`** (excerpts).
- **Do not** ask it to fix **`App.tsx`** unless you attach that file from another project.
- **Run** `python3 scripts/generate_ai_studio_bundle.py` for full architecture context if needed.
