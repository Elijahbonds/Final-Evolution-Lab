# Gold Master Sovereign Bundle — AI Studio context dump

## TASK: FIX ERRORS & FINALIZE DEPLOYMENT

**Instructions for AI Studio**

1. **a)** If a separate **React** app exists (e.g. Wix/React), fix **syntax/type errors** there — this repo may not contain those files. In **this** repo, the native shell is **Swift** + **Unreal** + static **`web/`**; do not invent `App.tsx` unless pasted below.
2. **b)** **Medical disclaimer:** implement as **mandatory first-run gate** in **SwiftUI** (`ContentView` / onboarding) or **Wix**; there is **no** `App.tsx` in `final-evolution-lab`.
3. **c)** **Wix → Supabase:** complete **`post_felRelayWixOrder`** → **`wix-order-completed`** Edge Function; header **`X-FEL-Wix-Secret`**; body includes **`wix_order_id`**, **`supabase_user_id`**, **`shard_delta`**, optional **`athlete_id`**.

---

## PRODUCTION_CONFIG.md

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


---

## Requested React paths — NOT IN THIS REPO

The following were requested for bundling but **do not exist** in `final-evolution-lab`:

- `App.tsx`
- `gameModes.ts`
- `GameModeRouter.tsx`

**Substitutes in-repo:** `web/config/vva-game-modes.ts` (VVA module registry), Swift `ContentView` + `AppTab` (`TabView`) for navigation.

---

## Web deployment + PWA + Wix relay

File: `netlify.toml`

```toml
# Publish the `web/` folder as the site root (FinalEvolutionGroup.com static shell).
# Routes: / → gateway, /play/ → PWA, /shop/ → Stripe links, /wallet/ → Supabase Realtime.
# COOP/COEP: mirrors `web/_headers` — cross-origin isolation for WebGPU / WASM under /play/.
# Large binaries (Mac DMG, Win zip): host on Supabase Storage `sovereign-assets` — see scripts/upload_to_supabase_storage.sh
# See web/DEPLOY.txt and scripts/deploy_web.sh
[build]
  publish = "web"
  command = "echo 'Static site: no build step'"

# Optional: pin Node if you add a build later
# [build.environment]
#   NODE_VERSION = "20"

# Trailing slash consistency (optional)
[[redirects]]
  from = "/play"
  to = "/play/"
  status = 301

[[redirects]]
  from = "/shop"
  to = "/shop/"
  status = 301

[[redirects]]
  from = "/wallet"
  to = "/wallet/"
  status = 301

# Cross-origin isolation for high-performance WebGPU / SharedArrayBuffer on /play/ (GBA-style PWA shell).
[[headers]]
  for = "/play/*"
  [headers.values]
    Cross-Origin-Opener-Policy = "same-origin"
    Cross-Origin-Embedder-Policy = "require-corp"
    X-Content-Type-Options = "nosniff"

[[headers]]
  for = "/play/index.html"
  [headers.values]
    Cross-Origin-Opener-Policy = "same-origin"
    Cross-Origin-Embedder-Policy = "require-corp"

[[headers]]
  for = "/play/sw.js"
  [headers.values]
    Cross-Origin-Opener-Policy = "same-origin"
    Cross-Origin-Embedder-Policy = "require-corp"
```

File: `web/_headers`

```http
# Netlify publish root is `web/` — this file applies site-wide.
# Cross-origin isolation for WebGPU / WASM under /play/ (see also web/play/_headers).
# Mobile Safari: COOP/COEP on /play/ only; /shop/ and /wallet/ stay unrestricted for Supabase + Stripe redirects.

/play/*
  Cross-Origin-Opener-Policy: same-origin
  Cross-Origin-Embedder-Policy: require-corp
  X-Content-Type-Options: nosniff

/play/index.html
  Cross-Origin-Opener-Policy: same-origin
  Cross-Origin-Embedder-Policy: require-corp

/play/sw.js
  Cross-Origin-Opener-Policy: same-origin
  Cross-Origin-Embedder-Policy: require-corp
```

File: `web/play/manifest.webmanifest`

```json
{
  "id": "/play/",
  "name": "Final Evolution Lab",
  "short_name": "FEL Lab",
  "description": "The Forensic Lab is Open — Neuro-Mechanic coaching, 16.6ms latency. Sovereign install to home screen.",
  "start_url": "/play/?source=pwa",
  "scope": "/play/",
  "prefer_related_applications": false,
  "display": "standalone",
  "display_override": ["standalone", "minimal-ui"],
  "orientation": "portrait-primary",
  "background_color": "#0a0c10",
  "theme_color": "#1e90ff",
  "categories": ["health", "fitness", "games"],
  "icons": [
    {
      "src": "./icons/icon-192.png",
      "sizes": "192x192",
      "type": "image/png",
      "purpose": "any"
    },
    {
      "src": "./icons/icon-192.png",
      "sizes": "192x192",
      "type": "image/png",
      "purpose": "maskable"
    },
    {
      "src": "./icons/icon-512.png",
      "sizes": "512x512",
      "type": "image/png",
      "purpose": "any"
    },
    {
      "src": "./icons/icon-512.png",
      "sizes": "512x512",
      "type": "image/png",
      "purpose": "maskable"
    }
  ]
}
```

File: `web/play/_headers`

```http
# When publishing the full site, Netlify reads `web/_headers` at the publish root.
# This file is kept in sync for partial /play-only deploys.
# Netlify / static host — cross-origin isolation for WebGPU / WASM workers.
# COEP `require-corp`: every embedded asset must be same-origin or send
# `Cross-Origin-Resource-Policy: cross-origin` (or credentialless fetch). Prevents cross-origin
# WebGPU buffer leaks / undefined behavior in Chromium. Tune per CDN if fonts/scripts break.

/play/*
  Cross-Origin-Opener-Policy: same-origin
  Cross-Origin-Embedder-Policy: require-corp
  X-Content-Type-Options: nosniff

/play/index.html
  Cross-Origin-Opener-Policy: same-origin
  Cross-Origin-Embedder-Policy: require-corp

/play/sw.js
  Cross-Origin-Opener-Policy: same-origin
  Cross-Origin-Embedder-Policy: require-corp
```

File: `web/config/vva-game-modes.ts`

```typescript
/**
 * Vertical Velocity Academy — module registry for web / Wix / future React shells.
 * Keep in sync with Swift `VerticalVelocityAcademyCurriculum` and `Config/ACADEMY_CURRICULUM_V1.json`.
 * Alpha 2: next five modules (13–17) are placeholders until curriculum copy is finalized.
 */

/** mod1 … mod17+ — extend as curriculum grows */
export type VVAModuleId = string;

export interface VVAModule {
  id: VVAModuleId;
  number: number;
  title: string;
  subtitle: string;
  phase: "Foundations" | "Load" | "Launch" | "Flight" | "Elite" | "TBD";
  cloudCortexTags: string[];
}

/** Shipped modules (1–12) — abbreviated for routing; full copy lives in app JSON. */
export const vvaShippedModules: VVAModule[] = [
  { id: "mod1", number: 1, title: "Bio-Electric Freeway", subtitle: "CNS freeway", phase: "Foundations", cloudCortexTags: ["freeway", "cns"] },
  { id: "mod2", number: 2, title: "Internal GPS", subtitle: "SFMA/FMS", phase: "Foundations", cloudCortexTags: ["screen", "gps", "ankle_piston_alias"] },
  { id: "mod3", number: 3, title: "The Piston", subtitle: "IAP", phase: "Foundations", cloudCortexTags: ["piston", "iap", "breathing"] },
  { id: "mod8", number: 8, title: "Rhythmic Penultimate", subtitle: "Push 1, 2", phase: "Launch", cloudCortexTags: ["penultimate", "rfd"] },
];

/** Next five modules (Alpha 2 expansion) — titles TBD; ingest into app when curriculum locks. */
export const vvaNextFiveModules: VVAModule[] = [
  { id: "mod13", number: 13, title: "TBD — Forensic Load Management", subtitle: "Placeholder", phase: "TBD", cloudCortexTags: ["alpha2"] },
  { id: "mod14", number: 14, title: "TBD — Elastic Energy Accounting", subtitle: "Placeholder", phase: "TBD", cloudCortexTags: ["alpha2"] },
  { id: "mod15", number: 15, title: "TBD — Competition taper", subtitle: "Placeholder", phase: "TBD", cloudCortexTags: ["alpha2"] },
  { id: "mod16", number: 16, title: "TBD — Crew / broadcast mirror", subtitle: "Placeholder", phase: "TBD", cloudCortexTags: ["alpha2"] },
  { id: "mod17", number: 17, title: "TBD — Sovereign economy + habits", subtitle: "Placeholder", phase: "TBD", cloudCortexTags: ["alpha2", "shards"] },
];

export function moduleById(id: string): VVAModule | undefined {
  const all = [...vvaShippedModules, ...vvaNextFiveModules];
  return all.find((m) => m.id === id);
}
```

File: `wix/velo/backend/http-functions.js`

```javascript
/**
 * Wix Velo — HTTP Functions (Dev Mode → HTTP Functions).
 * File name / export names follow Wix: https://dev.wix.com/docs/develop-websites/articles/coding-with-velo/code-http-functions
 *
 * Deploy: publish site with Dev Mode. URL shape:
 *   https://<your-site>/_functions/felRelayWixOrder
 *   https://<your-site>/_functions/felWixOrderPaidFromAutomation
 *
 * Order Paid / JOIN NOW flow:
 *   1) Wix Automations → "Order paid" → HTTP POST to felWixOrderPaidFromAutomation (or build JSON and POST to felRelayWixOrder).
 *   2) **JOIN NOW** (members area): store `supabase_user_id` + `athlete_id` in member custom fields or Automation payload —
 *      Velo forwards them so Edge `wix-order-completed` can call `fel_upsert_athlete_profile_link_for_service` + credit RPC.
 *   3) Body must resolve supabase_user_id + wix_order_id + shard_delta (see creditsForWixCents; mirror in felShardCatalog.js).
 *   4) Supabase Edge `wix-order-completed` — header **X-FEL-Wix-Secret** (must match Wix secret + Supabase `WIX_WEBHOOK_SHARED_SECRET`).
 *
 * Secrets (Wix Dashboard → Secrets):
 *   FEL_SUPABASE_ORDER_URL  — https://xxx.supabase.co/functions/v1/wix-order-completed
 *   FEL_WIX_WEBHOOK_SHARED_SECRET — same value as Supabase WIX_WEBHOOK_SHARED_SECRET
 */

import { ok, badRequest, serverError } from "wix-http-functions";
import { fetch } from "wix-fetch";
import { getSecret } from "wix-secrets-backend";

/** USD cents → shard/cortex (tune to Wix product prices). See also felShardCatalog.js copy. */
function creditsForWixCents(totalCents) {
  const map = {
    1999: { shard_delta: 500, cortex_delta: 120, product_sku: "wix_vva_blueprint" },
    4999: { shard_delta: 750, cortex_delta: 40, product_sku: "wix_cortex_shard_pack" },
    9999: { shard_delta: 2500, cortex_delta: 200, product_sku: "wix_sovereign_pro" },
  };
  const row = map[totalCents];
  if (!row) return { shard_delta: 0, cortex_delta: 0, product_sku: "wix_custom" };
  return { ...row };
}

async function relayToSupabase(body) {
  const url = await getSecret("FEL_SUPABASE_ORDER_URL");
  const secret = await getSecret("FEL_WIX_WEBHOOK_SHARED_SECRET");
  if (!url || !secret) {
    throw new Error("Missing Wix secrets: FEL_SUPABASE_ORDER_URL / FEL_WIX_WEBHOOK_SHARED_SECRET");
  }
  const res = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-FEL-Wix-Secret": secret,
    },
    body: JSON.stringify(body),
  });
  const text = await res.text();
  if (!res.ok) {
    throw new Error(text || `Upstream ${res.status}`);
  }
  return text;
}

/**
 * POST https://yoursite.com/_functions/felRelayWixOrder
 * Body example (from Automation or your mapper):
 * {
 *   "wix_order_id": "order-guid",
 *   "supabase_user_id": "uuid-from-member-field",
 *   "athlete_id": "optional-local-athlete-id",
 *   "shard_delta": 750,
 *   "cortex_delta": 40,
 *   "product_sku": "wix_sovereign_shard_pack"
 * }
 */
export async function post_felRelayWixOrder(request) {
  try {
    const body = await request.body.json();
    const text = await relayToSupabase(body);
    return ok({ body: text, headers: { "Content-Type": "application/json" } });
  } catch (e) {
    return badRequest({ body: String(e && e.message ? e.message : e) });
  }
}

/**
 * Wix Automation — Order paid (simplified payload). Map fields to match your Automation’s JSON.
 * Expected body (example — adjust keys to match Wix Automation “Send webhook” payload):
 * {
 *   "orderId": "wix-order-guid",
 *   "supabase_user_id": "uuid",
 *   "athlete_id": "optional-app-athlete-id",
 *   "totalAmountCents": 1999
 * }
 */
export async function post_felWixOrderPaidFromAutomation(request) {
  try {
    const raw = await request.body.json();
    const orderId = raw.orderId || raw.id || raw.order_id;
    const supabaseUserId =
      raw.supabase_user_id ||
      raw.userId ||
      (raw.metadata && raw.metadata.supabase_user_id) ||
      (raw.customFields && raw.customFields.supabase_user_id);
    const athleteId =
      raw.athlete_id ||
      raw.athleteId ||
      (raw.metadata && raw.metadata.athlete_id) ||
      (raw.customFields && raw.customFields.athlete_id) ||
      "";
    const cents = parseInt(String(raw.totalAmountCents ?? raw.total?.amount ?? 0), 10) || 0;
    const mapped = creditsForWixCents(cents);

    if (!orderId || !supabaseUserId) {
      return badRequest({ body: "Missing orderId or supabase_user_id" });
    }

    const payload = {
      wix_order_id: String(orderId),
      supabase_user_id: String(supabaseUserId).trim(),
      athlete_id: athleteId ? String(athleteId).trim() : "",
      shard_delta: mapped.shard_delta,
      cortex_delta: mapped.cortex_delta,
      product_sku: mapped.product_sku,
    };

    const text = await relayToSupabase(payload);
    return ok({ body: text, headers: { "Content-Type": "application/json" } });
  } catch (e) {
    return serverError({ body: String(e && e.message ? e.message : e) });
  }
}
```

File: `supabase/functions/wix-order-completed/index.ts`

```typescript
// Supabase Edge Function — Wix Store order → fel_apply_stripe_shard_credit (idempotent by synthetic session id).
//
// Wix does not send Stripe-signed webhooks. Use this endpoint from Wix Velo (or Automations) with a shared secret.
//
// Secrets:
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY
//   WIX_WEBHOOK_SHARED_SECRET — must match header X-FEL-Wix-Secret from your Velo relay
//
// Body (JSON):
//   wix_order_id (required), supabase_user_id (required UUID), athlete_id (optional),
//   shard_delta, cortex_delta (optional), product_sku (optional)

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";

function unauthorized(): Response {
  return new Response("Unauthorized", { status: 401 });
}

serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method Not Allowed", { status: 405 });
  }

  const shared = Deno.env.get("WIX_WEBHOOK_SHARED_SECRET") ?? "";
  const header = req.headers.get("x-fel-wix-secret") ?? "";
  if (!shared || header !== shared) {
    return unauthorized();
  }

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: "invalid_json" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  const orderId = String(body.wix_order_id ?? body.orderId ?? "").trim();
  const userId = String(body.supabase_user_id ?? body.user_id ?? "").trim();
  const athleteId = body.athlete_id ? String(body.athlete_id).trim() : "";
  const shardDelta = parseInt(String(body.shard_delta ?? "0"), 10) || 0;
  const cortexDelta = parseInt(String(body.cortex_delta ?? "0"), 10) || 0;
  const productSku = body.product_sku ? String(body.product_sku) : "wix_sovereign_shard";

  if (!orderId || !userId) {
    return new Response(
      JSON.stringify({ error: "missing wix_order_id or supabase_user_id" }),
      { status: 400, headers: { "Content-Type": "application/json" } },
    );
  }

  const uuidRe = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
  if (!uuidRe.test(userId)) {
    return new Response(JSON.stringify({ error: "invalid supabase_user_id" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  if (shardDelta === 0 && cortexDelta === 0) {
    return new Response(JSON.stringify({ error: "zero_credits" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const supabase = createClient(supabaseUrl, serviceKey);

  if (athleteId) {
    const { error: linkErr } = await supabase.rpc("fel_upsert_athlete_profile_link_for_service", {
      p_athlete_id: athleteId,
      p_user_id: userId,
      p_stripe_customer_id: null,
    });
    if (linkErr) console.error("fel_upsert_athlete_profile_link_for_service", linkErr);
  }

  const sessionId = `wix_${orderId}`;

  const { error } = await supabase.rpc("fel_apply_stripe_shard_credit", {
    p_user_id: userId,
    p_shard_delta: shardDelta,
    p_cortex_delta: cortexDelta,
    p_stripe_session_id: sessionId,
    p_product_sku: productSku,
    p_metadata: {
      source: "wix",
      wix_order_id: orderId,
      athlete_id: athleteId || null,
    },
  });

  if (error) {
    console.error("fel_apply_stripe_shard_credit", error);
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  return new Response(JSON.stringify({ ok: true, wix_order_id: orderId, userId, shardDelta, cortexDelta }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
```

---

# Final Evolution Lab — AI Studio architecture bundle

**Purpose:** Paste into [Google AI Studio](https://aistudio.google.com/) (or similar) for **forensic architecture review**.  
**Repo:** `final-evolution-lab` · **iOS:** `Source/` · **Unreal templates:** `UnrealStarter/BasketballGame/` · **UE target:** 5.7 / MyProjec.

---

---

## Claims vs code (read first)

- **Implemented (iOS):** SwiftUI Lab + Arena flows; **RealityKit** dunk court; `DunkContestState` phases and scoring; **PRQ** / `PerformanceMetrics` in app logic; **system scan** UI with **simulated** analysis → `SystemScanResult` (not a full on-device CV pipeline in this bundle).
- **Implemented (Unreal templates):** JSON **readiness snapshot** → `FFELReadinessSnapshot`; **`ApplyReadiness`** on character (**`JumpZVelocity`**, **`MaxWalkSpeed`**) and ball (**mass scale**); hoop **trigger scoring**; **session export** JSON; **Python** editor scripts for **floor / PlayerStart / hoop volumes** and optional **Luma/prop spawn** (paths in script).
- **Curriculum vs metrics:** **Bonds Bounce** in Swift is **`BlueprintLibrary`** (content + phases + URLs), **not** a second numeric schema; alignment with Unreal is **narrative / product**, not a shared “BondsBounce” calculation type with `FELReadinessTypes`.
- **Neuro-Mechanic (Swift + Unreal templates):** `PRQManager` exports **`readiness_snapshot.json`** with `verticalEstimateInches`, `hangTimeScale`, `kineticLeakageMultiplier` (joint PRIMED vs MODERATE/LEAKING from `BiomechanicsAudit`). Unreal **`FELReadinessIO`** parses those keys; **`FELKineticLeakage`** scales jump/sprint in **`AFELBasketballCharacter::ApplyReadiness`**; **`AFELBasketballGameMode`** mirrors neuro floats for Blueprint. See **`NEURO_MECHANIC_BRIDGE.md`**.
- **Roadmap / not demonstrated in pasted C++:** **Neural Drive fatigue** over time (no stamina decay, no load-based damping beyond leakage multipliers); **braking / deceleration** curves from PRQ; **shot variance** as gameplay; **live iOS → Editor** bridge (snapshot remains file-based for QA unless you add IPC).
- **Roadmap / not in Python scripts:** **Golden hour** lighting, **post-process** “juice,” or Niagara/VFX — scripts **spawn/layout** actors only unless you extend them.
- **Large Swift files** in this bundle are **excerpts**; do not infer missing UI or helpers as “implemented” without opening the repo.

---

## System instruction (paste into AI Studio “System instructions”)

You are the **Neuro-Mechanic Lead Architect** for **Final Evolution Lab**. You are reviewing a **split codebase**:

- **iOS (`Source/`):** SwiftUI for **Arena** (UI-only rounds) and **Lab**; **RealityKit** for the **dunk** scene. Performance narrative uses **PRQ**, **readiness / scan** flows, and optional **Gemini** services — not Unreal UMG.
- **Unreal 5.7 (`MyProjec` / templates under `UnrealStarter/BasketballGame/`):** C++ gameplay slice — movement, ball, hoop triggers, HUD, **readiness snapshot → tuning**, **session export JSON**. Editor automation via **Python** in `UnrealStarter/EditorPython/`.
- **Neural Drive fatigue** is **not** in the pasted C++: do not assume decay-under-load or stamina APIs. Recommend **concrete** extensions (e.g. **Stamina** component, **Curve** assets, or time-scaled multipliers applied **after** `ApplyReadiness`) only as **design proposals**, not as existing code.

**Product concepts**

- **Bonds Bounce Blueprint:** vertical-jump **training architecture** (phases, progression, copy in `BlueprintLibrary`); align any jump/dunk **phase naming** (e.g. load, launch, flight, landing) with this story when commenting on code. Note: audit doc flags a **naming mismatch** vs spec (Load/Launch vs Foundations/Flight/Elite).
- **Forensic goals:** trace how **scan / metrics** flow into **in-game feel** (Swift dunk engine + Unreal `ApplyReadiness`-style tuning), identify gaps between **docs and implementation**, and propose **UE 5.7**-realistic next steps (C++, Blueprint hooks, Python batch tools) **without inventing APIs** not shown below.

When unsure, **quote file paths** and state assumptions explicitly.

---

## Consolidated sources

The following sections use the format:

`File: path/to/file`

```{language}
…
```

### Architecture & flows (Markdown)

File: `PROJECT_FLOWS.md`

```markdown
# Final Evolution Lab – Key Flows

Short reference for **sequencing and where 3D vs UI** lives. See also `XCODE_CLEAN_AND_RUN.md` and `INSPIRATIONS_COMPARISON.md`.

---

## 1. Lab → Dunk (3D)

- **Entry:** Lab tab → scroll to court → tap **START APPROACH** (guard: `phase == .idle`).
- **Cover:** `fullScreenCover(isPresented: $showDunkFullScreen)` → **DunkFlowView**.
- **DunkFlowView:**  
  - First: **GetReadyScreen** (“Dunk Contest”, countdown 3–2–1–GO).  
  - `onComplete` → `showGetReady = false` (animated) → **DunkFullScreenView**.
- **DunkFullScreenView:**  
  - **RealityKitDunkView** (procedural 3D: court, backdrop, hoop, net, dunker, camera, lights).  
  - **PS2GamepadOverlay** for stick + face buttons (console/emulator style).  
  - Phases: idle → approach (hold left stick up = sprint) → launch (press ✕ = commit, no timing bar) → airborne (△□○✕ = finishers) → landing (press ✕ = commit) → scored.  
  - On scored: **ResultScreen** overlay (judge total, CONTINUE?) → `onClaimRewards` or dismiss.
- **On dismiss:** `onDismiss` cancels timer and calls `freestyleDunk.advanceRound()` so next run starts from idle.

**3D:** Only the dunk uses 3D; all assets are procedural in `RealityKitDunkView` (no external models).

---

## 2. Arena (UI only)

- **Entry:** Arena tab → tap a **mode row** → `selectedMode = mode` → `fullScreenCover(item: $selectedMode)` presents **ArenaGameFlowView**.
- **ArenaGameFlowView:**  
  - **Get Ready** → **Playing** (`GenericArenaPlayView`) → **Result** (`ResultScreen`).  
  - Phase transitions use `.animation(.easeInOut(duration: 0.32), value: phase)` and opacity/scale transitions.
- **GenericArenaPlayView:**  
  - No 3D; **mode-specific backdrop** (**Venice Beach** `VeniceBeachHoopsArenaBackground` + `VeniceCourtCanvasView` for H2H/3v3, **dojo** Karate, **stadium** baseball, **gridiron** football, **beach tennis** `BeachTennisCourtBackground`, **beach volleyball** `BeachVolleyballArenaBackground` + `BeachVolleyballRallyCanvasView`, **gymnastics** `AcademyArenaGymnasticsBackground` + `GymnasticsFloorRoutineCanvasView`, **soccer** `PenaltyStadiumArenaBackground` + solo `PenaltyKickView` or MP `PenaltySpotCanvasView`, **golf** `GolfLinksArenaBackground` + solo `GolfSwingView` or MP `ClosestToPinCanvasView`, **Brain Brawl** `BrainBrawlAcademyBackground` + `BrainBrawlDuelCanvasView` in solo `BrainBrawlPlayView` or local Versus `GenericArenaPlayView` (OPP label), **Dunk** `DunkContestVenueBackground` + `DunkRunwayCanvasView` in `ArenaDunkPlayView`, etc.) + round label, P1/P2 score, **PS2GamepadOverlay** (console/emulator style).  
  - **Controller-first:** Press ✕ (Cross) or tap action button to commit the round — no timing bar. Outcome from PRQ + commit (quality 0.62–0.90). Physical controller Cross (button A) also commits.  
  - Commit → PERFECT/GOOD/MISS feedback → round result alert → Next → next round or **finishGame()** → `onGameEnd` → phase = .result.
- **Result:** ResultScreen (P1/P2, shards, PRQ) → “BACK TO ARENA” → `onDismiss` → `selectedMode = nil` (cover dismisses).

**3D:** Arena play is UI-only (gradient + meter). Lab dunk is the only 3D gameplay scene.

---

## 3. Get Ready screen

- Used by **Arena** (per-mode title/subtitle) and **Dunk** (fixed “Dunk Contest”).
- Countdown: 3 → 2 → 1 → GO! (snappy timing), then `onComplete()` after ~380ms.
- Triggers phase change (Arena: .playing; Dunk: show game view) with animation.

---

## 4. File reference

| Flow / 3D          | Main files |
|--------------------|------------|
| Lab court + dunk   | `LabView.swift`, `DunkContestEngine.swift` |
| Dunk 3D scene      | `RealityKitDunkView.swift` (court, backdrop, hoop, dunker, camera, lights) |
| Arena list + game  | `ArenaView.swift` (ArenaGameFlowView, GenericArenaPlayView) |
| Get Ready / Result | `GameScreensView.swift` |
| Modes / venues     | `GameMode.swift` (GameModeRegistry, arenaVenues) |
```

File: `NEURO_MECHANIC_BRIDGE.md`

```markdown
# Neuro-Mechanic bridge — Swift ↔ Unreal

This repo implements **readiness-gated play** in two layers:

1. **Swift (ship today):** `PRQManager` derives `kineticLeakageMultiplier` and `hangTimeScale` from `SystemScanResult` + `BiomechanicsAudit` (ankle / knee / hip **PRIMED** vs **MODERATE** / **LEAKING**). Arena outcomes already use `effectiveMetrics.prqScore` via `GenericArenaPlayView` and related flows.
2. **Unreal (copy `UnrealStarter/` into your game module):** `FFELReadinessSnapshot` + `FELReadinessIO::TryLoadSnapshot` consume the **same JSON** keys. `UFELNeuroMechanicBridgeSubsystem::ReloadSnapshotFromDiskAndApply` is the **single load path** in `AFELBasketballGameMode::StartPlay`; `FELKineticLeakage` applies leakage + hang scale to jump and sprint caps in `AFELBasketballCharacter::ApplyReadiness`. The GameMode still exposes Blueprint-readonly **Neuro*** doubles after `StartPlay`, sourced from the subsystem cache.

## Neuro-Mechanic philosophy (abstract → concrete)

- **Efficiency = height:** `EfficiencyScore` scales realized vertical impulse after the scan-derived **potential** curve (`FELNeuroMechanicPhysics::EfficiencyHeightScale`).
- **Potential cap:** `verticalEstimateInches` maps to a **Bonds Bounce Blueprint** ceiling (`PotentialJumpZFromVerticalInches`); this is *not* a flat “tap to jump” scalar.
- **Neural drive realizes potential:** `NeuralDriveRealizationFactor` maps 0–100 drive into how much of that ceiling becomes **JumpZVelocity** on the ground.
- **Dynamic kinetic leakage:** Joint scan leakage (`KineticLeakageMultiplier` via `FELKineticLeakage`) stacks with **input-timing leakage** (`ComputeBondsBounceTimingLeakage`) — gather seconds vs an ideal ~280 ms window; **Early/Late** bands drive “Leaky” animation hooks (`LastJumpTimingBand`).
- **Elite apex control (Dunk Contest):** at `neuralDrive >= 90`, mid-air **planar nudges** (`ApplyMidAirNeuralCorrection`) simulate pro-grade body control (not a canned apex).
- **Neuro-Flow:** three **Perfect** timing jumps in a row (Dunk Contest) triggers short **Bloom + vignette + character time dilation** (`UpdateNeuroFlowVisuals`) so the arena reads the athlete’s streak.

## Sport-specific layer (12 Arena modes)

- **Registry:** `FFELArenaRules` embeds `FFELSportNeuroConstants` (kick power, swing window ms, slice multiplier, lateral strain thresholds, Karate/Baseball PRQ window expansion, etc.). Defaults are merged in `FELArenaRulesRegistry::ApplySportNeuroDefaults` per `EFELArenaMode`.
- **Lateral kinetic leakage:** `FELKineticLeakage::ApplyLateralCutWalkMultiplier` penalizes **Tennis / Soccer / Football** when lateral ground velocity exceeds the mode threshold while `neuralDrive` is below `LateralNeuralDriveRequired` (ankle/knee instability vs scan leakage).
- **Neuro-Skill buffer:** `FELNeuroSkill::PerfectHitWindowMsFromPRQ` widens the Baseball/Karate perfect-hit window as **PRQ** rises (`BaseballSwingWindowMs` + PRQ × `BaseballPerfectWindowPRQExpandMs`, same pattern for Karate).
- **Debug HUD metric 3:** `FELNeuroMechanicDisplay::GetSportHudMetric3` labels the third line (e.g. Kick Power, Perfect Window ms, Slice Control).
- **Session export:** `session_results.json` includes **`masteryScore`** and **`masteryMetric`** (Swift `GameSessionResult`) from `FELSportMastery::ComputeMasteryScoreAndMetric`.

## JSON contract (`readiness_snapshot.json`)

| Key | Source (Swift) |
|-----|----------------|
| `active_mode` | `GameModeId.rawValue` (Unreal: `EFELArenaMode` + `ArenaSettings.json` rules) |
| `prqScore`, `efficiencyScore`, `readinessScore`, `verticalPotential`, `neuralDrive`, `popForce`, `currentOutfit` | `PerformanceMetrics` |
| `verticalEstimateInches` | `SystemScanResult.verticalEstimateInches` |
| `hangTimeScale` | PRQ + flight time heuristic in `PRQManager` |
| `kineticLeakageMultiplier` | Joint statuses in `BiomechanicsAudit` |

Swift writes:

- **Documents:** `Documents/FEL/readiness_snapshot.json` (on device; use Files / iTunes File Sharing to copy into Unreal `Saved/FEL/` for desktop playtests).
- **UserDefaults** cache key: `fel_readiness_snapshot_json_cache`.

## PS5 / DualSense (Arena dunk)

When `ControllerDiscoveryService.hasPhysicalController` is true:

- **L2 (left trigger):** sprint hold / release mirrors Cross down/up during approach.
- **R2 (right trigger):** confirms **gather → jump** while phase is `.launch`.
- **Virtual overlay:** still gated off when a physical controller is present (`ArenaDunkPlayView` + `PS2GamepadOverlay`).

## Venue routing

`VenueManager` maps hub shortcuts (e.g. Games → **Venice** / **Dojo**) to `preselectedArenaModeId` and Arena tab selection, and calls `PRQManager.shared.sync` so export stays fresh before Unreal ingest.

## Exercise demonstration (ghost avatar)

Before the first Lab session, **`UFELOnboardingWidget`** can run **`AFELBasketballGameMode::TriggerExerciseDemo`** (“Watch Demo”): **`UFELDemoManager`** spawns a **`AFELExerciseDemonstrator`** ghost using **`FFELSportNeuroConstants::DemonstratorSkeletalMesh`** + **`DemonstratorAnimInstanceClass`** (author **`UFELArenaModeData`** per mode, with registry defaults → `/Game/Models/Avatar/`). **`ApplyDemonstrationPlayRateFromNeuro`** scales **`UAnimInstance::GlobalAnimRateScale`** from **`NeuroPRQScore`** and **`NeuroKineticLeakageMultiplier`**. Optional **Perfect Form** lines come from the Data Asset **`Hud`**. Dismiss blends the camera back to the pawn, then **`StartMatchCountdown`** runs.

**Data + async:** each Swift **`active_mode`** triggers **`FStreamableManager::RequestAsyncLoad`** on **`FELArenaModeCatalog`** soft paths so only that mode’s **`UFELArenaModeData`** and referenced meshes resolve for the session.
```

File: `app-synopsis.md`

```markdown
# Final Evolution Lab: Technical & Functional Synopsis

## 1. Abstract & Vision

Final Evolution Lab is a high-performance athletic optimization ecosystem that bridges elite biomechanical coaching with immersive digital simulation. It utilizes a **"Digital Twin"** architecture to translate forensic video data into a dynamic 3D avatar.

- **Core Metric:** PRQ (Performance Readiness Quotient).
- **Philosophy:** "Delete the Fear" — removing neural friction and biomechanical leaks.
- **Primary Stack:** Swift/SwiftUI (Social/UI Layer) + Unreal Engine (3D Simulation/Physics) + Firebase (Persistence/Cloud Sync).

---

## 2. The Digital Twin Pipeline (Data Flow)

The application follows a strict data-ingestion pipeline to maintain the "Digital Twin":

1. **Capture:** Raw video upload of athletic movements.
2. **Calibrate():** Computer vision extracts kinematics (Vertical Jump, Neural Drive, Pop Force, Efficiency).
3. **Audit():** Comparison against "Pro Signatures" to identify dysfunction.
4. **Sync():** Biomechanical data is injected into the Unreal Engine Character Blueprint to modify physics constraints (e.g., max impulse, jump height, recovery frames).

---

## 3. Core Functional Modules

### A. The Digital Vault (The Curriculum)

- **Bonds Bounce Blueprint:** Multi-phase training (Foundations → Load → Launch → Flight).
- **Forensic Insights:** Deep-dive technical breakdowns and "Mental Priming" scripts.
- **Academy Progression:** Mentor selection, node-based unlocks, and mastery interactions.

### B. The Gaming Labs (Unreal Engine 5)

- **Environments:** High-fidelity stylized recreations (e.g., Venice Beach Court).
- **Game Modes:** 1v1/2v2 Basketball, Dunk Contests, 3-Point Shootouts, and Sport-specific drills (QB/Soccer).
- **Readiness-Influenced Sim:** Avatar performance is dynamically gated by the user's real-world "Neural Readiness" scores.
- **Repo alignment:** **`UnrealStarter/VISION_ALIGNMENT.md`** ties Unreal work to the same **measure → train → play** story, **Arena** naming, and Swift schemas (`PerformanceMetrics`, `GameSessionResult`, `GameModeId`, `PRQScoring`) for the MyProjec / **`BasketballGame/`** lab slice — plus what is still to wire for full product parity.

### C. Recovery & Coaching Portal

- **Neural Decompression:** Guided 3D visualizations for posterior chain release.
- **Command Center:** Orchestrates critique request/review loops with "Verified Coaches."
- **Scout Bounties:** A marketplace where pro-team opportunities are unlocked via verified PRQ milestones.

---

## 4. Economic Architecture (Web3-Enabled)

A dual-currency system manages the "Play-to-Earn" loop:

- **Evolution Shards (ES):** Soft currency. Earned via training streaks. Used for gear, skins, and maintenance drains (inflation control).
- **Blueprint Credits (BC):** Hard currency. Purchased for elite coaching, "Forensic Feedback," and unlocking advanced curriculum phases.
- **Creator Cards:** Collectible assets that provide attribute boosts within the Labs.

---

## 5. Technical Specifications for Cursor

- **Frontend Architecture:** SwiftUI-heavy navigation with a persistent AppState coordinator.
- **3D Integration:** Unreal Engine integrated as a library or sub-view, communicating with the Swift layer via a bridge (data snapshots).
- **Physics Engine:** Unreal Engine Physics (high-fidelity collision and ball mechanics).
- **State Management:**
  - **Local:** Swift Persistence / UserDefaults for offline readiness.
  - **Cloud:** Firebase Firestore for global leaderboards (Venice Kings), matchmaking, and Digital Twin backups.
- **Async Patterns:** Stale-task protection for media observers, navigation-safe timers, and lifecycle-aware feedback banners.

---

## 6. Data Schema (Cursor-Ready Reference)

Key persisted types and their roles. All are Codable/Sendable where applicable.

| Type | Location | Purpose |
|------|----------|---------|
| **UserProfile** | `Models/UserProfile.swift` | Single source of truth: `metrics` (PRQ, verticalPotential, neuralDrive, popForce, etc.), `systemScan`, `evolutionShards`, `activeCreatorCard`, `sport`, `goal`, `critiqueRequests`. |
| **SystemScanResult** | `Models/UserProfile.swift` | Output of Calibrate pipeline: `prqScore`, `verticalEstimateInches`, `flightTimeSeconds`, `movementGrade`, `notes`, `recommendedTrack`, `avatarConfig` (AvatarSkinConfig). |
| **AvatarSkinConfig** | `Models/UserProfile.swift` | Injected into sim: `heightScale`, `weightScale`, `limbLength`, `skinTone`, `outfitStyle`, `auraColorR/G/B`, `trailIntensity`. |
| **PerformanceMetrics** | `Models/PerformanceMetrics.swift` | PRQ and related scores used for physics/readiness. |
| **BiomechanicsAudit** | `Models/BiomechanicsAudit.swift` | Output of Audit(): joint/zone status (e.g. ankleDorsiflexion, kneeTracking, hipExtension), leakage zones. Built from `SystemScanResult` via `BiomechanicsAudit.fromScanResult(_)`. |
| **GameSessionResult** | `Models/GameSession.swift` | Per-session record: `gameModeId`, `score`, `opponentScore`, `shardsEarned`, `prqBonus`, `roundsPlayed`, `duration`, `isMultiplayer`. Persisted via `SaveSystem.saveGameResult(_)`. |
| **GameMode / GameModeId** | `Models/GameMode.swift` | Registry of all modes (basketball H2H, dunk, 3v3, karate, baseball, football, soccer, golf, tennis, volleyball, gymnastics, brainBrawl). Used for scene selection, physics config, and PRQ weighting. |
| **TrainingProgram / TrainingDay / TrainingExercise** | `Models/TrainingProgram.swift`, `TrainingProgramData.swift` | Curriculum structure: tracks, days, warm-up/main work exercises, progression levels, equipment. |
| **Exercise** | `Models/Exercise.swift` | Lab exercise catalog: `id`, `category`, `difficulty`, `muscleGroups`, `sets`, `reps`, `restSeconds`, `demoDescription`. |
| **CreatorCard / CardPacksAndAuction** | `Models/CreatorCard.swift`, `CardPacksAndAuction.swift` | Collectibles and attribute boosts; economy hooks. |
| **SaveSystem** | (Services or Utilities) | Saves/loads `UserProfile`, `GameSessionResult`, and related state to local storage. |

**Firestore / Cloud:** Leaderboard entries, matchmaking state, and (when implemented) Digital Twin backups keyed by user ID; sync with local `UserProfile` and session results.

---

## 7. Unreal Engine Integration Points (Cursor-Ready Reference)

How the Swift/SwiftUI app hands off to (or receives data from) Unreal Engine.

| Concern | Swift Side | Unreal Side (Target) |
|---------|------------|----------------------|
| **Avatar calibration** | `SystemScanResult` + `AvatarSkinConfig`; `BiomechanicsAudit` (joint/zone status). | Character Blueprint: apply scale, limb ratios, and physics constraints (max impulse, jump height, recovery) from PRQ/audit. |
| **Readiness gating** | `PerformanceMetrics` (PRQ, neuralDrive, popForce, etc.); `ArcadePhysics.fromPRQ(_:neuralDrive:audit:)`; `GamePhysicsConfig.forMode(_:prq:audit:)`. | Sim reads a **data snapshot** (e.g. JSON or struct mirror) from the bridge; clamps or scales movement/ball physics by PRQ and audit flags. |
| **Session context** | `GameModeId`, `GameSessionResult`, optional `roundsPlayed`. | Level/mode selection; post-game stats and economy (shards, PRQ delta) can be reported back to Swift. |
| **Bridge contract** | Send: current `UserProfile` (or subset: metrics, avatarConfig, audit), selected `GameModeId`, session start. Receive: session end payload (score, opponentScore, duration). | Consume snapshot on level load; push session result back over the bridge for persistence and leaderboards. |
| **Scene / level mapping** | Lab court: `RealityKitDunkView` (RealityKit); migration path: replace or supplement with Unreal view per game mode. | One Unreal level (or sublevel) per game mode; Venice Beach, Dojo, Stadium, etc. |

**Note:** The current iOS app uses **RealityKit** for the Lab dunk court (`RealityKitDunkView`, `DunkFullScreenView`). The synopsis and this section describe the **target** architecture once Unreal Engine is integrated; the bridge and data snapshots should mirror the schema above so an LLM can map Swift types to Unreal parameters.

---

## 8. Key Logic Methods

| Method | Purpose |
|--------|---------|
| **Calibrate()** | Processes video into raw biomechanical metrics. (In-app: System Scan flow → `SystemScanResult`; full CV pipeline TBD.) |
| **Audit()** | Maps user metrics against elite benchmarks. (`BiomechanicsAudit.fromScanResult(_)`; leakage zones and joint status.) |
| **Simulate()** | Updates Unreal Avatar attributes based on latest PRQ. (Swift: `GamePhysicsConfig` / `ArcadePhysics`; Unreal: consume snapshot and drive Blueprint.) |
| **Program()** | Generates daily workout prescriptions based on PRQ gaps. (Training program/track selection, `TrainingDay`, recommended track from scan.) |
| **Verify()** | Signs off on metrics for pro-scouting eligibility. (Scout Bounties / critique flow; not yet fully implemented.) |

---

*Next step: Generate Swift boilerplate for the AppState coordinator or the PRQ data model from this synopsis, or extend the bridge contract for Unreal.*
```

File: `UnrealStarter/VISION_ALIGNMENT.md`

```markdown
# Unreal work ↔ Final Evolution Lab vision

Single source of truth for how **UnrealStarter** / **MyProjec** relate to the app: same north star as **`PITCH_DECK.md`**, same schema story as **`app-synopsis.md`** and Swift under **`FinalEvolutionLab/`** — not a standalone arcade product.

---

## North star (from `PITCH_DECK.md`)

- **Measure → train → play** in **one** ecosystem: scan drives **PRQ** and recommendations; curriculum and Academy **train**; **Arena / Lab** **plays** with outcomes tied to readiness.
- **Readiness-gated Arena / Lab** — better PRQ and mode-relevant attributes (**Court IQ**, **Hang Time**, **Shot Accuracy**, etc.) influence odds, feel, and rewards; fair but performance-driven.
- **One avatar / one data story** — scan → avatar → sim; **future Unreal or console** is expected to consume the **same** readiness snapshot and session shapes as iOS, not a forked economy.
- **Philosophy:** *Delete the fear* — coaching and clarity turn intent into output.

**Synopsis layer (`app-synopsis.md`):** **`Sync()`** injects biomechanical data into the sim (impulse, jump, recovery, etc.). Venice-style **Gaming Labs** belong to **FEL Arena**, not generic mini-games.

---

## Honest map of the current Unreal slice

**What this is today:** **Venice / Luma** environment path + **Elijah** stand-in mesh + **basketball modes** (street, shootout, timed blitz, practice, first-to-N) = an **Arena-style lab**: same verbs and naming as the pitch, built to accept real readiness data.

**What is wired in the Unreal lab (C++ under `BasketballGame/` / MyProjec):**

| Track | Status | Notes |
|--------|--------|--------|
| **Data contract** (readiness snapshot) | ✅ Lab | JSON → `FFELReadinessSnapshot` aligned with **`PerformanceMetrics.swift`** (`FELReadinessTypes.h`, `FELReadinessIO`). |
| **PRQ → sim** (character / ball) | ✅ Lab | Jump, move speed, ball mass scale from snapshot (`ApplyReadiness`). |
| **Court IQ / Hang Time** (attribute UX) | ✅ Lab | Labels + display values mirror **`PRQScoring.swift`** (`FELArenaBridge`). **Shot accuracy** as a *gameplay* axis (miss variance, contests) is **not** implemented here yet. |
| **Mode IDs** | ✅ Lab | `GetArenaGameModeId()` ↔ **`GameModeId`** raw strings in **`GameMode.swift`**. |
| **Shards / `GameSessionResult`** | 🟡 Lab file only | Match end writes **`Saved/FEL/last_session_result.json`** (`FELSessionExport`). **Still to wire:** iOS ingest, Firebase, profile **`evolutionShards`**, and production economy rules. |

**Still to wire (product / full vision):**

- **App ↔ Unreal bridge** — push `readiness_snapshot.json` from the device or CI; pull session JSON into **`GameSessionResult`** history.
- **Readiness-gated policy** — soft locks, matchmaking tiers, copy that matches Arena (lives in app first; Unreal can mirror).
- **Deeper attribute modulation** — shot error, fatigue, defender pressure, AI — beyond HUD + light physics tuning. **Neural Drive fatigue** (readiness decay under match load) is **not** implemented in the current C++ templates; add it explicitly (e.g. **Stamina** / **Curve** assets, or time-scaled multipliers on top of `ApplyReadiness`) rather than assuming it exists in repo code.
- **Production avatar** — scan → same rig / preset as hub (Meshy Elijah is a **stand-in**).

**Swift / schema pointers (repo):**

| Topic | File |
|--------|------|
| Snapshot fields | `FinalEvolutionLab/Models/PerformanceMetrics.swift` |
| Session export shape | `FinalEvolutionLab/Models/GameSession.swift` (`GameSessionResult`) |
| Mode ids | `FinalEvolutionLab/Models/GameMode.swift` (`GameModeId`) |
| PRQ weights / labels | `FinalEvolutionLab/Utilities/PRQScoring.swift` |
| Twin pipeline narrative | `app-synopsis.md` |

---

## Guardrails (stay on vision)

1. **Positioning** — Call this **Arena lab / export target**, not “shipped FEL.”
2. **Features** — Prefer work that can take a **readiness snapshot** later (`ApplyReadiness`-style hooks) over one-off rules with no data path.
3. **Naming** — Keep **Arena** language (Venice, beach court, shootout, dunk lineage) consistent with the app.
4. **Modes** — Every new mode gets a row in **`BasketballGame/GAME_MODES.md`** with **how PRQ could affect it** (even if only planned).

---

## Ordered next steps (vision sequence)

Same order as the integration plan; use it when prioritizing tickets.

| Step | Intent | Lab (Unreal) | Product (still to wire) |
|------|--------|----------------|-------------------------|
| 1 | **Data contract** | ✅ JSON snapshot load | Pipe from iOS profile / export |
| 2 | **Tune character / ball from metrics** | ✅ Baseline tuning | Richer **Sync()**-style curves |
| 3 | **Align mode IDs with Swift `GameModeId`** | ✅ | None if ids stable |
| 4 | **Session / economy hooks** | ✅ File export | Ingest shards, **`prqBonus`**, history, sync |

**Follow-ons:** multiplayer fields in export, shot variance, readiness gate UI, tvOS/console packaging.

---

## Repo doc index

| Doc | Role |
|-----|------|
| **`PITCH_DECK.md`** | North star, pillars |
| **`app-synopsis.md`** | Digital twin, **Sync()**, stack |
| **`UnrealStarter/README.md`** | Entry point + link here |
| **`BasketballGame/README.md`** | Arena / Gaming Labs — **not a separate product** |
| **`BasketballGame/GAME_MODES.md`** | Mode rules + PRQ notes + `gameModeId` |
| **`BasketballGame/GAME_FINISHED.md`** | Playable slice vs full PRQ-gated vision |
| **`BasketballGame/PACKAGE_AND_TEST.md`** | Preconditions, maps, input, readiness JSON, Mac **RunUAT** + Editor package, tester checklist, iOS + notarization pointers |
| **`BasketballGame/QA_GAMEPLAY_AUDIT.md`** | Mode matrix, scoring/export QA, Swift parity notes |
| **`IMPORT_CHECKLIST.md`** | Venice / Luma / Elijah asset paths |

---

*Final Evolution Lab — Your movement, audited. Your readiness, your edge.*
```

File: `AUDIT_BIOMECHANICAL_ECOSYSTEM.md (§3 Bonds Bounce + surrounding Digital Vault)`

```markdown
# Final Evolution Lab — Biomechanical Optimization Ecosystem Audit

This audit compares the **current codebase** to the product specification: *Final Evolution Lab: The Biomechanical Optimization Ecosystem* (Digital Twin, PRQ, Bonds Bounce Blueprint, Gaming Labs, Recovery Lab, Coaching Portal, Economy, Core Functions, Architecture).

---

## 1. Core Philosophy: "Delete the Fear"

| Spec | Status | Notes |
|------|--------|--------|
| Neural friction / biomechanical inefficiencies as focus | **Partial** | Copy and UX emphasize PRQ and movement; no explicit "Delete the Fear" or "neural friction" framing in code/strings. |
| Platform as "forensic auditor" for the body | **Partial** | `BiomechanicsAudit`, `SystemScanResult`, and leakage zones implement audit; "forensic" wording not used in-app. |
| Blueprints to "rewire" movement patterns | **Partial** | `BlueprintLibrary`, training tracks, and curricula exist; "rewire" narrative not surfaced. |

**Recommendation:** Add a short onboarding or Lab copy block that states the "Delete the Fear" premise and positions the app as a forensic movement auditor.

---

## 2. Digital Twin & Biomechanical Audit

### 2.1 Forensic Data Capture

| Spec | Status | Implementation |
|------|--------|----------------|
| Athletes upload video of movements (vertical jump, windmills, sprints) | **Implemented** | `SystemScanView`: PhotosPicker for video, phases (picking → analyzing → results), generates `SystemScanResult`. |
| Attribute mapping: four primary metrics | **Implemented** | **Vertical Jump** → `verticalEstimateInches` / `verticalPotential` ✓. **Neural Drive** → `neuralDrive` ✓. **Efficiency** → `efficiencyScore` ✓. **Pop Force** → `PerformanceMetrics.popForce`, derived in `LabViewModel.derivePopForceFromScan`, shown in System Scan results and Lab metrics grid. |
| PRQ as unified "flight readiness" score | **Implemented** | `PerformanceMetrics.prqScore`, `PRQ` (min/max/clamp, fromVerticalInches, modeReward, successChanceFromPRQ), `SystemScanResult.prqScore`. |

### 2.2 Audit Output

| Spec | Status | Implementation |
|------|--------|----------------|
| Compare movement to elite "Pro" signatures | **Partial** | Audit derives joint scores and leakage from scan; no explicit "Pro" comparison or pro signature library. |
| Kinetic chain leaks identified | **Implemented** | `BiomechanicsAudit`: `LeakageZone`, `JointScore` (ankle, knee, hip), `kineticLeakageZones`, `BiomechanicsGrade`. |
| Deep-dive technical breakdowns | **Partial** | Leakage descriptions and joint status; no structured "forensic insights" content model or narrative blocks. |

---

## 3. Digital Vault (Curriculum)

### 3.1 Bonds Bounce Blueprint

| Spec | Status | Implementation |
|------|--------|----------------|
| Multi-phase system: Foundations, **Load**, **Launch**, Flight | **Mismatch** | App uses **Foundations, Flight, Elite** (+ "Lifelong Mover" in `BlueprintLibrary.phases`). No **Load** or **Launch** as distinct phase names. |
| HD video guides, mental priming scripts, drill direction | **Partial** | `BlueprintLibrary` has blueprints with URLs (YouTube); `TrainingProgramData` has exercises with descriptions. No in-app "mental priming" or script content model. |
| Forensic insights ("why" behind adjustments) | **Partial** | Exercise `demoDescription` and leakage text; no dedicated forensic-insight content per phase/drill. |

**Recommendation:** Either (a) rename or add phases to align with spec (Foundations → Load → Launch → Flight) or (b) document that "Flight" = Launch and add a "Load" phase between Foundations and Flight. Add a content type for mental priming / forensic insight if desired.

### 3.2 Interactive Modules

| Spec | Status | Implementation |
|------|--------|----------------|
| Day/track structure | **Implemented** | `TrainingProgram` (days, weeks, track, equipment), `TrainingDay`, `CurriculumTrack`, `TrainingProgramData.program(for:equipment:)`. |
| Video guides per exercise | **Implemented** | `ExerciseDemoView`, `DemoEngine` (videoMap by exercise id), `VideoPlayerView`; fallback to `AvatarDemoView` when no video. |
| Clone-first demo playback (generated/local/reference hierarchy) | **Partial** | Demo flow is coach video vs avatar; no explicit "Digital Twin" or "reference clip → generated clone" hierarchy. Avatar is used when video unavailable (clone-first in behavior, not in naming or data model). |

---

## 4. Gaming Labs (3D Simulation)

| Spec | Status | Implementation |
|------|--------|----------------|
| High-fidelity 3D (React Three Fiber / Unreal) | **Different stack** | **RealityKit** for Lab court (`RealityKitDunkView`); native iOS, not web R3F or Unreal. |
| Basketball Lab (Venice Court) | **Implemented** | Lab court: `RealityKitDunkView` (court, hoop, dunker), `DunkFullScreenView` for full-screen play; freestyle dunk with finishers, scoring, shards. |
| Sport Lab (QB, soccer, tennis, volleyball, etc.) | **Scaffolded** | `GameMode` and physics configs exist; only freestyle dunk is active gameplay; other modes removed from UI. |
| Arena themes (colors, lighting, materials by mode) | **Implemented** | Mode-specific scenes and accents in `GameMode` (accentColor, environmentName). |
| Digital Twin competes in 3D | **Conceptual** | Avatar/scene represent the athlete; metrics (PRQ, audit) feed `ArcadePhysics` / `GamePhysicsConfig` and DDA. No literal "twin" entity in data model. |

**Note:** Spec’s "Rapier.js" and "React/Three" refer to a web stack; current app is native iOS + SceneKit. Document this as the chosen native architecture.

---

## 5. Recovery Lab

| Spec | Status | Implementation |
|------|--------|----------------|
| Neural Decompression (guided 3D visualizations, posterior chain release) | **Not implemented** | No dedicated "Recovery Lab" or "Neural Decompression" module. |
| Myofascial Reset (trigger-point guides from audit) | **Not implemented** | No myofascial or trigger-point content keyed off `BiomechanicsAudit`. |
| Readiness tracking (prevent overtraining) | **Partial** | `readinessScore` in metrics; HealthKit HRV and `NeuralReadinessScanView`; no dedicated Recovery Lab UI or "Neural Readiness" dashboard. |

**Recommendation:** Add a Recovery Lab surface (tab or section) with: (1) readiness summary, (2) audit-based suggestions (e.g. "Focus on posterior chain" from leakage), (3) placeholder or links for Neural Decompression and Myofascial Reset content.

---

## 6. Coaching Portal & Social Layer

| Spec | Status | Implementation |
|------|--------|----------------|
| Paid critiques (spend Evolution Shards for Verified Coach analysis) | **Implemented** | `LabViewModel.critiqueCostShards` (500), `CritiqueRequest` / `CritiqueResponse`, `CritiqueRequestView`, `CritiqueSubmitView`, escrow in `CoachEconomy`. |
| Venice Kings Leaderboard | **Partial** | Global leaderboard (`GlobalLeaderboardService`, `SocialView`, `LeaderboardEntry`); no "Venice Kings" branding in code. |
| Scout Bounties (pro-team opportunities, e.g. 40" vertical + 90 Neural Drive) | **Not implemented** | No bounty/milestone definitions, pro-scout eligibility, or reward flow. |
| Creator Cards (collectible, boost attributes in labs) | **Implemented** | `CreatorCard`, `CreatorCardState`, `CreatorCardBoostView`, apply/clear in `LabViewModel`; boosts feed `effectiveMetrics`. |

**Recommendation:** Add Scout Bounties: define milestones (e.g. vertical + neural drive thresholds), a small model (e.g. `ScoutBounty`), and a UI surface for "Pro Scout Eligibility" or "Bounties."

---

## 7. Economic System

| Spec | Status | Implementation |
|------|--------|----------------|
| Evolution Shards (ES): earned via training streaks, marketplace (Gear, Creator Cards, Coaching) | **Implemented** | `evolutionShards`, `ShardReward`, `ShardTransaction`, workout/game/critique flows; `ShardShopView`, `ShopCatalog`, Creator Cards, critiques. |
| Blueprint Credits (BC): unlock elite curriculum phases | **Partial** | `UserProfile.blueprintCredits` exists; no phase-gate or "unlock with BC" logic in curriculum. |
| Dual currency (Shards soft, Credits hard) | **Implemented** | `UserProfile.credits` (hard) added for Spatial Economy; `SpatialEconomy.swift` (CreditTransaction, CreditsBalance). BC and Credits can be unified or kept separate per product. |

**Recommendation:** If BC is distinct from Credits, document; otherwise consider using `credits` for both and renaming BC in UI. Add phase-unlock logic if elite phases are paywalled.

---

## 8. Core Functions (Spec Table)

| Function | Spec | Status | Implementation |
|----------|------|--------|----------------|
| **Calibrate()** | Process raw video into biomechanical data | **Implemented** | System scan flow: video → analysis → `SystemScanResult` (PRQ, vertical, flight, etc.); no function named "Calibrate". |
| **Audit()** | Compare current movement to elite Pro signatures | **Partial** | `BiomechanicsAudit.fromScanResult(_:)` produces audit; no explicit Pro comparison. |
| **Simulate()** | Run Digital Twin through 3D sport drills to test gains | **Conceptual** | Gameplay uses metrics and audit for physics/DDA; no dedicated "Simulate(drill)" API. |
| **Program()** | Daily training schedule from PRQ deficiencies | **Partial** | `TrainingProgramData.program(for:equipment:)`, track selection; no explicit "deficiency → program" prescription algorithm. |
| **Verify()** | Third-party validation for pro-scouting eligibility | **Not implemented** | No verification flow or third-party validation. |

… [truncated after §3.2 header — full file in repo] …
```

File: `UnrealStarter/BasketballGame/PACKAGE_AND_TEST.md (§1–6, §9–11)`

```markdown
# FEL basketball — package & test (publish-ready path)

Use this when you want a **Mac Development build for internal QA**, a **folder/zip for testers**, or to continue to **iOS** packaging from Unreal.

**Not the Swift app:** The iOS product in this repo is **`ios/FinalEvolutionLab.xcodeproj`** — see **`XCODE_CLEAN_AND_RUN.md`**. Unreal is a **separate** project (e.g. **FinalEvolutionLab** under *Documents*).

---

## Contents

| Section | What |
|---------|------|
| [1. Preconditions](#1-preconditions) | Blockers before cook |
| [2. Default map & game mode](#2-default-map--game-mode) | Maps & Modes + config snippets |
| [3. Input](#3-input-mac--gamepad) | Legacy PlayerInput + FEL bindings |
| [4. Readiness JSON](#4-readiness-json-optional-for-qa) | Snapshot + session export |
| [5. Mac Development packaging](#5-mac-development-packaging) | Editor UI + **RunUAT** CLI |
| [6. Tester checklist](#6-tester-checklist) | What QA should verify |
| [7. iOS (Unreal)](#7-ios-unreal--testflight-path) | Pointers to run/package on device |
| [8. Notarization (Mac)](#8-notarization-mac) | Short note for distribution |
| [9. Repo artifacts & FinalEvolutionLab defaults](#9-repo-artifacts--myprojec-defaults) | Files in this repo + what’s on disk |
| [10. Short path (TL;DR)](#10-short-path-tldr) | Ordered steps |
| [11. Cross-links](#11-cross-links) | Related docs |

---

## 1. Preconditions

| Check | Why |
|--------|-----|
| **FinalEvolutionLabEditor compiles** | C++ must build before cook. On this Mac use **UE 5.7** + current Xcode unless you match an older pair — see **`../MAC_PLATFORM_MAC_INVALID.md`**. |
| **A playable `.umap`** under **`/Game/FEL/Maps/`** | Blank template projects often have **no** shipped Content maps; **OpenWorld** is not a basketball court. |
| **PlayerStart** in that map | Pawn spawn location. |
| **At least one `FELHoopScoreVolume`** | Otherwise **Buckets** stay **0** — looks like a broken game. |
| **Meshes imported** (recommended) | Elijah / ball / optional Luma or Venice per **`../IMPORT_CHECKLIST.md`**. Missing assets → warnings or invisible mesh. |

**Fastest map:** Enable **Editor → Plugins → Python Editor Script Plugin**, restart Editor, run **`../EditorPython/fel_quick_playtest_level.py`**. It creates **`/Game/FEL/Maps/L_FEL_Playtest`**: scaled **Engine** cube floor, **PlayerStart**, two **`FELHoopScoreVolume`** actors. Requires **compiled FinalEvolutionLab C++** (`AFELHoopScoreVolume`).

---

## 2. Default map & game mode

**Project Settings → Maps & Modes**

- **Game Default Map** — e.g. **`/Game/FEL/Maps/L_FEL_Playtest`** (after the Python script), or **`L_VeniceLuma_Main`** when you build the full art map.
- **Editor Startup Map** — same as game default for day-to-day.
- **Default GameMode** — **`FELBasketballGameMode`**, or rely on **`GlobalDefaultGameMode`** in **`DefaultEngine.ini`**.

**Mergeable snippets (this folder)**

| File | Purpose |
|------|---------|
| **`CONFIG_DefaultEngine.ini.snippet`** | **OpenWorld** as default so the project **always opens** before `L_FEL_Playtest` exists; **commented** lines to switch to **`L_FEL_Playtest`** or **`L_VeniceLuma_Main`**; sets **`GlobalDefaultGameMode`**. |
| **`CONFIG_DefaultGame_FEL.ini`** | **`GeneralProjectSettings`** (name, company, version, description) + **`ProjectPackagingSettings`** for **Development** cook, **pak**, **IoStore**, **English** only. |

---

## 3. Input (Mac / gamepad)

In **`Config/DefaultInput.ini`** keep:

- `DefaultPlayerInputClass=/Script/Engine.PlayerInput`
- `DefaultInputComponentClass=/Script/Engine.InputComponent`
- The FEL axis/action block from **`CONFIG_DefaultInput_FEL.ini`**.

**Smoke test:** **WASD**, **mouse look**, **Space** jump, **gamepad** move / look / face-button jump.

---

## 4. Readiness JSON (optional for QA)

- Copy **`example_readiness_snapshot.json`** → **`Saved/FEL/readiness_snapshot.json`** next to the **`.uproject`**, or **`Content/FEL/Config/readiness_snapshot.json`**. If missing, defaults apply (PRQ **75**).
- After a match that **ends** with scoring on, check **`Saved/FEL/last_session_result.json`** (`GameSessionResult`-shaped). See **`QA_GAMEPLAY_AUDIT.md`** for modes that never end (no file).

---

## 5. Mac Development packaging

### Option A — Editor

1. **Platforms → Mac → Package Project** (or **File → Package Project → Mac**).
2. Choose output folder (e.g. Desktop).
3. Use **Development** for internal QA (console **`~`**, logs) unless you need **Shipping**.

### Option B — Command line (`RunUAT.sh` **BuildCookRun**)

Script: **`UnrealStarter/scripts/package_fel_mac.sh`** (executable). It invokes:

`Engine/Build/BatchFiles/RunUAT.sh BuildCookRun` — **Mac**, **Development**, **-build -cook -stage -pak -archive**.

```bash
chmod +x UnrealStarter/scripts/package_fel_mac.sh
UnrealStarter/scripts/package_fel_mac.sh "/path/to/FinalEvolutionLab.uproject" "/path/to/output-archive-dir"
```

**Defaults:** `UE_ROOT=/Users/Shared/Epic Games/UE_5.7`, project `~/Documents/Unreal Projects/FinalEvolutionLab/FinalEvolutionLab.uproject`, archive `./FEL-Mac-Development-Archive`. Override **`UE_ROOT`** if your engine lives elsewhere.

**Cook failures:** **Project Settings → Packaging → Maps to include** — add your FEL map, or ensure **Game Default Map** points at a cooked map under **`/Game`**.

---

## 6. Tester checklist

- [ ] App launches (no immediate crash).
- [ ] Move / look / jump; ball spawns with physics.
- [ ] Ball through **`FELHoopScoreVolume`** increases HUD score.
- [ ] **`FELBasketballGameMode` `PlayMode`** variants behave per **`GAME_MODES.md`** (timer, target, practice).
- [ ] After match end, move/look lock; if the mode ended with scoring on, **`last_session_result.json`** exists under **`Saved/FEL/`**.

---

## 7. iOS (Unreal / TestFlight path)

Unreal **does not** install through **`ios/FinalEvolutionLab.xcodeproj`**. You **package iOS** from the Unreal Editor (or automation), then open the **generated iOS `.xcworkspace`**, sign, run or archive.

Read in order:

1. **`../RUN_UNREAL_ON_IPHONE_XCODE.md`** — device run, workspace location, signing.
2. **`../../UNREAL_EXPORT_TO_XCODE.md`** — export / Xcode integration notes.
3. **`../../METAL_TOOLCHAIN_UNREAL.md`** — Metal / Xcode components if the build asks for them.

---

## 8. Notarization (Mac)

**Internal QA:** a **Development** packaged folder is usually enough; Gatekeeper may still prompt — testers can right-click → Open the first time.

**Wider Mac distribution** (DMG, zip outside TestFlight): Apple expects **notarization** for apps signed with Developer ID (Apple Developer Program). Use **Epic’s Mac packaging docs** + **Apple notarization** workflow when you move past the lab. **App Store** Mac has a separate pipeline.

---

## 9. Repo artifacts & FinalEvolutionLab defaults

**In this repo (`UnrealStarter/`):**

| Path | Role |
|------|------|
| **`BasketballGame/PACKAGE_AND_TEST.md`** | This document |
| **`EditorPython/fel_quick_playtest_level.py`** | Creates **`L_FEL_Playtest`** |
| **`scripts/package_fel_mac.sh`** | **RunUAT** Mac Development archive |
| **`BasketballGame/CONFIG_DefaultGame_FEL.ini`** | Merge into **`DefaultGame.ini`** |
| **`BasketballGame/CONFIG_DefaultEngine.ini.snippet`** | Merge into **`DefaultEngine.ini`** |
| **`BasketballGame/example_readiness_snapshot.json`** | Optional QA payload |

**Applied on a typical FinalEvolutionLab under *Documents* (mirror these if you clone fresh):**

- **`Config/DefaultGame.ini`** — project metadata + **Development** **`ProjectPackagingSettings`** (aligned with **`CONFIG_DefaultGame_FEL.ini`**).
- **`Config/DefaultEngine.ini`** — **`OpenWorld`** as **GameDefaultMap** / **EditorStartupMap** until **`L_FEL_Playtest`** exists; **commented** lines to switch to **`/Game/FEL/Maps/L_FEL_Playtest.L_FEL_Playtest`**; **`GlobalDefaultGameMode=FELBasketballGameMode`**.


… [§7–8 iOS/notarization omitted — see repo] …

---

## 10. Short path (TL;DR)

1. Open **FinalEvolutionLab** in **UE 5.7**.
2. Enable **Python Editor Script Plugin**, restart Editor.
3. Run **`UnrealStarter/EditorPython/fel_quick_playtest_level.py`** (Execute Python Script or Output Log `py "/full/path/to/fel_quick_playtest_level.py"`).
4. In **`Config/DefaultEngine.ini`**, set **`GameDefaultMap`** and **`EditorStartupMap`** to **`/Game/FEL/Maps/L_FEL_Playtest.L_FEL_Playtest`** (uncomment or paste).
5. **Platforms → Mac → Package Project** (**Development**) **or** run **`UnrealStarter/scripts/package_fel_mac.sh`**.
6. Hand testers this file + optional **`example_readiness_snapshot.json`**.

---

## 11. Cross-links

| Doc | Why |
|-----|-----|
| **`BasketballGame/README.md`** | Integrate C++, Json modules, links here |
| **`GAME_FINISHED.md`** | Playable slice + ship pointer |
| **`../README.md`** (UnrealStarter) | Entry + script paths |
| **`../VISION_ALIGNMENT.md`** | Product scope (Arena lab, not separate IP) |
| **`../../XCODE_CLEAN_AND_RUN.md` §4** | Unreal vs Swift Xcode |
| **`QA_GAMEPLAY_AUDIT.md`** | Mode/export QA matrix |
| **`GAME_MODES.md`** | `PlayMode` behavior |

---

*Arena lab — not a separate product.*
```

### Swift — full files (logic ≤ ~532 lines)

File: `Source/Models/DunkContestEngine.swift`

```swift
import Foundation
import QuartzCore

nonisolated enum DunkPhase: String, Sendable {
    case idle
    case approach
    case launch
    case airborne
    case landing
    case scored
}

nonisolated enum DunkTrickSlot: String, Sendable, CaseIterable {
    case windmill = "WINDMILL"
    case betweenLegs = "BETWEEN THE LEGS"
    case tomahawk = "TOMAHAWK"
    case threeSixty = "360"
    case reverseJam = "REVERSE JAM"
    case elbowHang = "ELBOW HANG"
    case freeThrowLine = "FREE THROW LINE"
    case doubleClutch = "DOUBLE CLUTCH"
    case eastbay360 = "360 EASTBAY"
    case kickUp = "KICK UP"
    case doubleEastbayOverCar = "DOUBLE UP EASTBAY OVER CAR"
    case honeyDip = "HONEY DIP"
    case superman = "SUPERMAN"
    case cradle = "ROCK THE CRADLE"
    case selfAlleyOop = "SELF ALLEY-OOP"
    case statueOfLiberty = "STATUE OF LIBERTY"
    case sevenTwenty = "720"

    var complexity: Double {
        switch self {
        case .tomahawk: return 0.6
        case .windmill: return 0.75
        case .betweenLegs: return 0.85
        case .threeSixty: return 0.8
        case .reverseJam: return 0.7
        case .elbowHang: return 0.9
        case .freeThrowLine: return 1.0
        case .doubleClutch: return 0.65
        case .eastbay360: return 0.92
        case .kickUp: return 0.88
        case .doubleEastbayOverCar: return 0.96
        case .honeyDip: return 0.93
        case .superman: return 0.91
        case .cradle: return 0.87
        case .selfAlleyOop: return 0.89
        case .statueOfLiberty: return 0.84
        case .sevenTwenty: return 0.94
        }
    }

    var icon: String {
        switch self {
        case .windmill: return "wind"
        case .betweenLegs: return "arrow.down.forward.and.arrow.up.backward"
        case .tomahawk: return "bolt.fill"
        case .threeSixty: return "arrow.trianglehead.2.clockwise.rotate.90"
        case .reverseJam: return "arrow.uturn.backward"
        case .elbowHang: return "hand.raised.fill"
        case .freeThrowLine: return "airplane"
        case .doubleClutch: return "hands.clap.fill"
        case .eastbay360: return "arrow.trianglehead.2.clockwise.rotate.90"
        case .kickUp: return "arrow.up.and.down"
        case .doubleEastbayOverCar: return "car.fill"
        case .honeyDip: return "hand.raised.fill"
        case .superman: return "figure.run"
        case .cradle: return "figure.stand"
        case .selfAlleyOop: return "square.and.arrow.down"
        case .statueOfLiberty: return "figure.arms.open"
        case .sevenTwenty: return "arrow.trianglehead.2.clockwise.rotate.90"
        }
    }

    var baseStylePoints: Int {
        Int(complexity * 20)
    }

    var faceButtonCategory: ArcadeFaceButton {
        switch self {
        case .windmill, .doubleClutch, .honeyDip, .superman: return .square
        case .betweenLegs, .threeSixty, .elbowHang, .eastbay360, .cradle, .sevenTwenty: return .triangle
        case .tomahawk, .reverseJam, .kickUp, .selfAlleyOop, .statueOfLiberty: return .circle
        case .freeThrowLine, .doubleEastbayOverCar: return .cross
        }
    }
}

struct DunkContestState {
    var phase: DunkPhase = .idle
    var round: Int = 1
    var totalRounds: Int = 3
    var totalScore: Int = 0
    var roundScores: [(round: Int, score: Int, message: String)] = []

    var sprintCharge: Double = 0
    /// Time to full charge ~0.6s at 60fps; feels intentional without dragging.
    var sprintChargeRate: Double = 1.65
    var isSprintHeld: Bool = false

    var launchTiming: Double = 0
    var launchTimingDirection: Double = 1
    var launchTimingSpeed: Double = 2.0
    var launchGreenZone: ClosedRange<Double> = 0.4...0.7

    var selectedTrick: DunkTrickSlot = .tomahawk
    var rotationAmount: Double = 0
    var isRotating: Bool = false
    var rotationTarget: Double = 1.0
    var airTime: Double = 0
    var maxAirTime: Double = 2.8
    var airPhaseStart: Double = 0

    var landingTiming: Double = 0
    var landingTimingDirection: Double = 1
    var landingTimingSpeed: Double = 2.2
    var landingGreenZone: ClosedRange<Double> = 0.35...0.65

    var trickHistory: [DunkTrickSlot] = []
    var showSlowMo: Bool = false
    var showApexFreeze: Bool = false
    var impactIntensity: Double = 0
    var crowdReaction: String = ""
    var judgeScores: (Int, Int, Int)?

    var activeModifier: DunkModifier = .standard
    var midAirState = MidAirTrickState()
    var inputBuffer = ArcadeInputBuffer()
    var freestyleComboMultiplier: Double = 1.0
    var styleLandingWindow: Bool = false
    var styleLandingSuccess: Bool = false
    var totalFreestylePoints: Int = 0
    var rimDistortionAmount: Double = 0

    /// When true, contest never ends (freestyle practice).
    var isFreestylePractice: Bool = false

    var isComplete: Bool {
        guard !isFreestylePractice, totalRounds > 0 else { return false }
        return round > totalRounds
    }

    var launchQuality: Double {
        let center = (launchGreenZone.lowerBound + launchGreenZone.upperBound) / 2
        let maxDist = (launchGreenZone.upperBound - launchGreenZone.lowerBound) / 2
        let dist = abs(launchTiming - center)
        if dist > maxDist * 2.5 { return 0 }
        return max(0, 1.0 - (dist / (maxDist * 2.0)))
    }

    var landingQuality: Double {
        let center = (landingGreenZone.lowerBound + landingGreenZone.upperBound) / 2
        let maxDist = (landingGreenZone.upperBound - landingGreenZone.lowerBound) / 2
        let dist = abs(landingTiming - center)
        if dist > maxDist * 2.5 { return 0 }
        return max(0, 1.0 - (dist / (maxDist * 2.0)))
    }

    var jumpHeight: Double {
        let sprintBonus = sprintCharge * 0.4
        let launchBonus = launchQuality * 0.6
        return min(1.0, sprintBonus + launchBonus)
    }

    var completedRotation: Double {
        min(1.0, rotationAmount / rotationTarget)
    }

    var dunkDifficulty: Double {
        let complexityScore = selectedTrick.complexity
        let heightScore = jumpHeight
        let contortionScore = Double(midAirState.branchCount) * 0.2
        return complexityScore * heightScore * (1.0 + contortionScore)
    }

    mutating func processArcadeInput(button: ArcadeFaceButton) {
        guard phase == .airborne else { return }
        let entry = InputBufferEntry(
            button: button,
            timestamp: CACurrentMediaTime(),
            modifier: activeModifier
        )
        inputBuffer = inputBuffer.adding(entry)
        let isDouble = inputBuffer.isDoubleTap(button)
        let trick = DunkTrickResolver.resolve(
            button: button,
            modifier: activeModifier,
            isDoubleTap: isDouble
        )
        selectedTrick = trick
        midAirState.addTrick(button)
        let points = DunkTrickResolver.freestylePoints(
            button: button,
            modifier: activeModifier,
            isDoubleTap: isDouble,
            chainLength: inputBuffer.chainLength
        )
        midAirState.addStylePoints(points)
        totalFreestylePoints += Int(Double(points) * midAirState.comboMultiplier)
        if !isRotating { isRotating = true }
    }

    mutating func setModifier(styleTrigger: Bool, powerTrigger: Bool) {
        if styleTrigger && powerTrigger {
            activeModifier = .signature
        } else if styleTrigger {
            activeModifier = .flashy
        } else if powerTrigger {
            activeModifier = .power
        } else {
            activeModifier = .standard
        }
    }

    /// `academyPlyosNeuroMultiplier`: Vertical Velocity Academy Plyos (`mod9`) mastery — permanent +2% neuro to contest scoring.
    mutating func calculateDunkScore(prq: Double, neuralBurst: Bool, academyPlyosNeuroMultiplier: Double = 1.0) -> (total: Int, j1: Int, j2: Int, j3: Int, message: String) {
        let normalized = min(max(prq / 100.0, 0), 1)

        let heightScore = jumpHeight * 20
        let trickScore = selectedTrick.complexity * 25
        let executionScore = ((launchQuality + landingQuality) / 2.0) * 20
        let rotationScore = completedRotation * 8

        var originalityBonus: Double = 0
        let previousCount = trickHistory.filter { $0 == selectedTrick }.count
        if previousCount == 0 { originalityBonus = 12 }
        else if previousCount == 1 { originalityBonus = 5 }

        let freestyleBonus = Double(min(totalFreestylePoints, 30))
        let chainBonus = Double(midAirState.branchCount) * 5
        let modifierBonus = (activeModifier.scoreMultiplier - 1.0) * 15

        let styleLandingBonus: Double = styleLandingSuccess ? 8 : 0

        var rawScore = heightScore + trickScore + executionScore + rotationScore +
                       originalityBonus + freestyleBonus + chainBonus + modifierBonus + styleLandingBonus
        rawScore *= (0.85 + normalized * 0.15)
        rawScore *= min(1.06, max(1.0, academyPlyosNeuroMultiplier))
        if neuralBurst { rawScore *= 1.12 }

        let base = min(50, Int(rawScore / 3.0) + 30)
        let spread = max(1, 5 - Int(executionScore / 8))
        let j1 = min(50, base + Int.random(in: 0..<spread))
        let j2 = min(50, base + Int.random(in: 0..<spread))
        let j3 = min(50, base + Int.random(in: 0..<spread))
        let total = j1 + j2 + j3

        let message: String
        if total >= 148 { message = "PERFECT 50!" }
        else if total >= 145 { message = "LEGENDARY!" }
        else if total >= 140 { message = "CROWD GOES WILD!" }
        else if total >= 135 { message = "ELECTRIFYING!" }
        else if total >= 130 { message = "VINCE CARTER STYLE!" }
        else if total >= 125 { message = "POWERFUL!" }
        else if total >= 118 { message = "SOLID DUNK" }
        else if total >= 108 { message = "NICE TRY" }
        else { message = "NEXT TIME" }

        impactIntensity = jumpHeight * landingQuality
        rimDistortionAmount = activeModifier == .power ? 0.15 : (activeModifier == .signature ? 0.2 : 0.08)
        trickHistory.append(selectedTrick)

        return (total, j1, j2, j3, message)
    }

    mutating func startApproach() {
        phase = .approach
        sprintCharge = 0
        isSprintHeld = true
        launchTiming = 0
        rotationAmount = 0
        isRotating = false
        airTime = 0
        landingTiming = 0
        showSlowMo = false
        showApexFreeze = false
        impactIntensity = 0
        crowdReaction = ""
        judgeScores = nil
        midAirState.reset()
        inputBuffer = ArcadeInputBuffer()
        freestyleComboMultiplier = 1.0
        styleLandingWindow = false
        styleLandingSuccess = false
        totalFreestylePoints = 0
        rimDistortionAmount = 0
        activeModifier = .standard
    }

    mutating func releaseSprint() {
        guard phase == .approach else { return }
        isSprintHeld = false
        phase = .launch
        launchTiming = 0
        launchTimingDirection = 1

        let difficulty = selectedTrick.complexity
        let greenWidth = max(0.24, 0.44 - difficulty * 0.1)
        let center = 0.5 + Double.random(in: -0.05...0.05)
        launchGreenZone = max(0, center - greenWidth / 2)...min(1, center + greenWidth / 2)
        launchTimingSpeed = 1.5 + difficulty * 0.5
    }

    mutating func confirmLaunch() {
        guard phase == .launch else { return }
        phase = .airborne
        airPhaseStart = CACurrentMediaTime()
        maxAirTime = 2.6 + jumpHeight * 0.9
        rotationTarget = 0.5 + selectedTrick.complexity * 0.5

        let difficulty = selectedTrick.complexity
        let dd = dunkDifficulty
        let landGreenWidth = max(0.18, 0.36 - dd * 0.06)
        let landCenter = 0.5 + Double.random(in: -0.04...0.04)
        landingGreenZone = max(0, landCenter - landGreenWidth / 2)...min(1, landCenter + landGreenWidth / 2)
        landingTimingSpeed = 2.0 + difficulty * 0.4
    }

    mutating func updateAirborne(delta: Double) {
        if phase == .landing {
            landingTiming += landingTimingDirection * landingTimingSpeed * delta
            if landingTiming >= 1.0 { landingTimingDirection = -1 }
            if landingTiming <= 0.0 { landingTimingDirection = 1 }
            landingTiming = max(0, min(1, landingTiming))
            return
        }
        guard phase == .airborne else { return }
        airTime += delta
        if isRotating {
            rotationAmount += delta * (1.4 + jumpHeight * 0.6)
        }
        landingTiming += landingTimingDirection * landingTimingSpeed * delta
        if landingTiming >= 1.0 { landingTimingDirection = -1 }
        if landingTiming <= 0.0 { landingTimingDirection = 1 }
        landingTiming = max(0, min(1, landingTiming))

        let apexThreshold = maxAirTime * 0.4
        showApexFreeze = airTime >= apexThreshold && airTime <= apexThreshold + 0.3
        showSlowMo = airTime >= maxAirTime * 0.3 && airTime <= maxAirTime * 0.7

        if airTime >= maxAirTime * 0.85 {
            styleLandingWindow = true
            midAirState.isStyleLandingAvailable = true
        }

        if airTime >= maxAirTime {
            phase = .landing
        }
    }

    mutating func attemptStyleLanding() -> Int {
        guard styleLandingWindow else { return 0 }
        styleLandingSuccess = true
        freestyleComboMultiplier += 0.5
        let bonus = midAirState.styleLandingRevert()
        return bonus
    }

    mutating func confirmLanding() {
        guard phase == .airborne || phase == .landing else { return }
        phase = .scored
    }

    mutating func advanceRound() {
        round += 1
        phase = .idle
        selectedTrick = .tomahawk
        midAirState.reset()
        inputBuffer = ArcadeInputBuffer()
        totalFreestylePoints = 0
    }

    /// Best single-dunk score this session (for practice display).
    var bestDunkScore: Int {
        roundScores.map(\.score).max() ?? 0
    }
}
```

File: `Source/Views/RealityKitDunkView.swift`

```swift
import SwiftUI
import RealityKit
import UIKit

/// RealityKit freestyle dunk court: procedural 3D only (no external assets). Court, hoop, net, dunker, backdrop, camera, lights built from MeshResource + SimpleMaterial.
struct RealityKitDunkView: View {
    var leftStickInput: CGPoint = .zero
    var isMidAir: Bool = false
    var dunkPhase: DunkPhase = .idle
    var jumpHeight: Float = 0
    var sprintCharge: Float = 0
    var avatarConfig: AvatarSkinConfig = .default
    @Binding var dunkImpactToTrigger: (modifier: DunkModifier, impactIntensity: Double)?

    private var dunkerTint: (r: Float, g: Float, b: Float) {
        (Float(avatarConfig.auraColorR), Float(avatarConfig.auraColorG), Float(avatarConfig.auraColorB))
    }

    var body: some View {
        RealityView { content in
            let root = Entity()
            root.name = "dunkRoot"

            let courtFloor = makeCourtFloor()
            root.addChild(courtFloor)

            let backdrop = makeBackdrop()
            root.addChild(backdrop)

            let hoop = makeHoop()
            root.addChild(hoop)

            let dunker = makeDunker(tint: dunkerTint, heightScale: Float(avatarConfig.heightScale))
            dunker.name = "dunker"
            root.addChild(dunker)

            let camera = makeCamera()
            root.addChild(camera)

            let light = makeLight()
            root.addChild(light)

            content.add(root)
        } update: { content in
            guard let root = content.entities.first(where: { $0.name == "dunkRoot" }),
                  let dunker = root.findEntity(named: "dunker") as? ModelEntity else { return }
            let forward = Float(leftStickInput.y)
            let baseZ: Float = 4
            let runZ = baseZ - forward * 8
            let jumpY: Float = isMidAir ? 1.2 + jumpHeight * 0.8 : 0
            let targetPosition = SIMD3<Float>(0, jumpY, runZ)
            dunker.position = targetPosition

            applyDunkerPose(to: dunker)
            updateCameraFollow(root: root, dunkerPosition: targetPosition)
            if dunkImpactToTrigger != nil {
                triggerRimEffect(root: root)
                DispatchQueue.main.async { dunkImpactToTrigger = nil }
            }
        }
        .ignoresSafeArea()
    }

    private func applyDunkerPose(to dunker: ModelEntity) {
        let (bodyPitch, bodyRoll, bodyScaleY, armLAngle, armRAngle): (Float, Float, Float, Float, Float)
        switch dunkPhase {
        case .idle:
            bodyPitch = 0
            bodyRoll = 0
            bodyScaleY = 1
            armLAngle = 0.15
            armRAngle = 0.15
        case .approach:
            let charge = min(1, sprintCharge)
            bodyPitch = -0.32 * charge
            bodyRoll = 0
            bodyScaleY = 1.0 - charge * 0.02
            armLAngle = -0.55 - charge * 0.35
            armRAngle = -0.55 - charge * 0.35
        case .launch:
            bodyPitch = -0.18
            bodyRoll = 0
            bodyScaleY = 0.97
            armLAngle = -0.7
            armRAngle = -0.7
        case .airborne:
            bodyPitch = 0.35 + jumpHeight * 0.25
            bodyRoll = jumpHeight * 0.18
            bodyScaleY = 1.04
            armLAngle = 1.0
            armRAngle = 1.0
        case .landing:
            bodyPitch = 0.08
            bodyRoll = 0
            bodyScaleY = 0.9
            armLAngle = 0.25
            armRAngle = 0.25
        case .scored:
            bodyPitch = 0
            bodyRoll = 0
            bodyScaleY = 1
            armLAngle = 0.15
            armRAngle = 0.15
        }
        dunker.orientation = simd_quatf(angle: bodyPitch, axis: [1, 0, 0]) * simd_quatf(angle: bodyRoll, axis: [0, 0, 1])
        dunker.transform.scale = SIMD3<Float>(1, bodyScaleY, 1)
        if let armL = dunker.findEntity(named: "armL") as? ModelEntity {
            armL.orientation = simd_quatf(angle: armLAngle, axis: [1, 0, 0])
        }
        if let armR = dunker.findEntity(named: "armR") as? ModelEntity {
            armR.orientation = simd_quatf(angle: armRAngle, axis: [1, 0, 0])
        }
    }

    private func makeCourtFloor() -> Entity {
        let courtMesh = MeshResource.generateBox(width: 12, height: 0.02, depth: 8)
        var courtMat = SimpleMaterial()
        courtMat.color = .init(tint: .init(red: 0.2, green: 0.13, blue: 0.06, alpha: 1))
        let court = ModelEntity(mesh: courtMesh, materials: [courtMat])
        court.position = SIMD3<Float>(0, 0.01, 0)
        court.name = "court"

        let centerLine = MeshResource.generateBox(width: 12, height: 0.02, depth: 0.14)
        var lineMat = SimpleMaterial()
        lineMat.color = .init(tint: .init(red: 0.45, green: 0.4, blue: 0.28, alpha: 1))
        let line = ModelEntity(mesh: centerLine, materials: [lineMat])
        line.position = SIMD3<Float>(0, 0.022, 0)
        court.addChild(line)

        let keyWidth: Float = 5.8
        let keyDepth: Float = 0.12
        let keyLine = MeshResource.generateBox(width: keyWidth, height: 0.02, depth: keyDepth)
        let key = ModelEntity(mesh: keyLine, materials: [lineMat])
        key.position = SIMD3<Float>(0, 0.022, -3.2)
        court.addChild(key)

        let arcSegments = 8
        let arcRadius: Float = 2.6
        for i in 0..<arcSegments {
            let t = Float(i) / Float(arcSegments)
            let angle = Float.pi * 0.5 + t * Float.pi * 0.55
            let x = cos(angle) * arcRadius
            let z = -3.0 + sin(angle) * arcRadius
            let seg = MeshResource.generateBox(width: 0.12, height: 0.02, depth: 0.5)
            let segEnt = ModelEntity(mesh: seg, materials: [lineMat])
            segEnt.position = SIMD3<Float>(x, 0.022, z)
            segEnt.orientation = simd_quatf(angle: -angle, axis: [0, 1, 0])
            court.addChild(segEnt)
        }

        return court
    }

    /// Distant floor and wall so the court isn’t floating in void (Venice Beach–style environment).
    private func makeBackdrop() -> Entity {
        let group = Entity()
        group.name = "backdrop"
        let floorExtend = MeshResource.generateBox(width: 24, height: 0.1, depth: 20)
        var floorMat = SimpleMaterial()
        floorMat.color = .init(tint: .init(red: 0.15, green: 0.12, blue: 0.1, alpha: 1))
        let floor = ModelEntity(mesh: floorExtend, materials: [floorMat])
        floor.position = SIMD3<Float>(0, -0.05, -6)
        floor.name = "backdropFloor"
        group.addChild(floor)
        let wall = MeshResource.generateBox(width: 28, height: 14, depth: 0.3)
        var wallMat = SimpleMaterial()
        wallMat.color = .init(tint: .init(red: 0.25, green: 0.32, blue: 0.4, alpha: 1))
        let wallEnt = ModelEntity(mesh: wall, materials: [wallMat])
        wallEnt.position = SIMD3<Float>(0, 6, -12)
        wallEnt.name = "backdropWall"
        group.addChild(wallEnt)
        return group
    }

    private func makeHoop() -> Entity {
        let backboard = MeshResource.generateBox(width: 1.2, height: 0.9, depth: 0.08)
        var backboardMat = SimpleMaterial()
        backboardMat.color = .init(tint: .init(red: 0.5, green: 0.52, blue: 0.55, alpha: 1))
        let backboardEntity = ModelEntity(mesh: backboard, materials: [backboardMat])
        backboardEntity.position = SIMD3<Float>(-4.5, 2.5, 0)
        backboardEntity.name = "backboard"

        let rectangle = MeshResource.generateBox(width: 0.7, height: 0.45, depth: 0.02)
        var rectMat = SimpleMaterial()
        rectMat.color = .init(tint: .init(white: 0.95, alpha: 1))
        let rect = ModelEntity(mesh: rectangle, materials: [rectMat])
        rect.position = SIMD3<Float>(0, -0.2, 0.05)
        backboardEntity.addChild(rect)

        let rim = MeshResource.generateCylinder(height: 0.08, radius: 0.45)
        var rimMat = SimpleMaterial()
        rimMat.color = .init(tint: .init(red: 0.85, green: 0.22, blue: 0.12, alpha: 1))
        let rimEntity = ModelEntity(mesh: rim, materials: [rimMat])
        rimEntity.position = SIMD3<Float>(0, -0.4, 0)
        rimEntity.orientation = simd_quatf(angle: .pi / 2, axis: [0, 0, 1])
        backboardEntity.addChild(rimEntity)

        makeNet(parent: backboardEntity)

        return backboardEntity
    }

    private func makeNet(parent: Entity) {
        let netSegment = MeshResource.generateBox(width: 0.08, height: 0.06, depth: 0.04)
        var netMat = SimpleMaterial()
        netMat.color = .init(tint: .init(white: 0.75, alpha: 1))
        let count = 12
        for i in 0..<count {
            let angle = Float(i) / Float(count) * 2 * .pi
            let x = cos(angle) * 0.42
            let z = sin(angle) * 0.42
            let seg = ModelEntity(mesh: netSegment, materials: [netMat])
            seg.position = SIMD3<Float>(x, -0.42, z)
            seg.orientation = simd_quatf(angle: -angle, axis: [0, 1, 0])
            parent.addChild(seg)
        }
    }

    private func makeDunker(tint: (r: Float, g: Float, b: Float), heightScale: Float = 1) -> Entity {
        let scale = heightScale
        let bodyMesh = MeshResource.generateBox(width: 0.38, height: 0.85 * scale, depth: 0.22)
        var bodyMat = SimpleMaterial()
        bodyMat.color = .init(tint: .init(red: CGFloat(tint.r), green: CGFloat(tint.g), blue: CGFloat(tint.b), alpha: 1))
        let body = ModelEntity(mesh: bodyMesh, materials: [bodyMat])
        body.position = SIMD3<Float>(0, 0.42 * scale, 0)

        let headMesh = MeshResource.generateSphere(radius: 0.14 * scale)
        var headMat = SimpleMaterial()
        headMat.color = .init(tint: .init(red: CGFloat(tint.r * 0.9), green: CGFloat(tint.g * 0.9), blue: CGFloat(tint.b * 0.9), alpha: 1))
        let head = ModelEntity(mesh: headMesh, materials: [headMat])
        head.name = "head"
        head.position = SIMD3<Float>(0, 0.58 * scale, 0)
        body.addChild(head)

        let armMesh = MeshResource.generateBox(width: 0.12, height: 0.35 * scale, depth: 0.1)
        var armMat = SimpleMaterial()
        armMat.color = .init(tint: .init(red: CGFloat(tint.r), green: CGFloat(tint.g), blue: CGFloat(tint.b), alpha: 1))
        let armL = ModelEntity(mesh: armMesh, materials: [armMat])
        armL.name = "armL"
        armL.position = SIMD3<Float>(-0.28, 0.35 * scale, 0)
        body.addChild(armL)
        let armR = ModelEntity(mesh: armMesh, materials: [armMat])
        armR.name = "armR"
        armR.position = SIMD3<Float>(0.28, 0.35 * scale, 0)
        body.addChild(armR)

        body.name = "dunker"
        body.position = SIMD3<Float>(0, 0, 4)
        return body
    }

    private func makeCamera() -> Entity {
        let camEntity = Entity()
        camEntity.name = "mainCamera"
        camEntity.position = SIMD3<Float>(2.2, 5.2, 9)
        camEntity.look(at: SIMD3<Float>(0, 2, -1), from: camEntity.position, relativeTo: nil)
        camEntity.components.set(PerspectiveCameraComponent())
        return camEntity
    }

    /// Camera follow: lerp position and look-at toward dunker so movement feels smooth and responsive.
    /// Uses DunkCameraConfig for tuning; lerp factor keeps motion smooth when state updates in quick succession.
    private func updateCameraFollow(root: Entity, dunkerPosition: SIMD3<Float>) {
        guard let camera = root.findEntity(named: "mainCamera") else { return }
        let baseZ: Float = 4
        let dz = dunkerPosition.z - baseZ
        let targetCamPos = SIMD3<Float>(
            2.2,
            5.2 + dunkerPosition.y * 0.45,
            9 + dz * 0.25
        )
        let lookAtTarget = SIMD3<Float>(
            0,
            2 + dunkerPosition.y * 0.35,
            -1 + dz * 0.15
        )
        let lerpFactor: Float = min(1, Float(PS2MovementConfig.dunkContest.cameraLerpFactor) / 22)
        let current = camera.position
        let newPos = current + (targetCamPos - current) * lerpFactor
        camera.position = newPos
        camera.look(at: lookAtTarget, from: newPos, relativeTo: nil)
    }

    private func makeLight() -> Entity {
        let group = Entity()
        group.name = "lights"

        let keyEntity = Entity()
        keyEntity.position = SIMD3<Float>(2.5, 10, 4)
        keyEntity.components.set(PointLightComponent(color: UIColor(red: 1, green: 0.95, blue: 0.88, alpha: 1), intensity: 3200, attenuationRadius: 15))
        group.addChild(keyEntity)

        let fillEntity = Entity()
        fillEntity.position = SIMD3<Float>(-3.5, 5, 5)
        fillEntity.components.set(PointLightComponent(color: UIColor(red: 0.75, green: 0.82, blue: 1.0, alpha: 1), intensity: 1000, attenuationRadius: 15))
        group.addChild(fillEntity)

        let rimEntity = Entity()
        rimEntity.position = SIMD3<Float>(-6, 3.5, 0)
        rimEntity.components.set(PointLightComponent(color: UIColor(red: 1, green: 0.85, blue: 0.6, alpha: 1), intensity: 600, attenuationRadius: 15))
        group.addChild(rimEntity)

        let ambientEntity = Entity()
        ambientEntity.position = SIMD3<Float>(0, 4, 2)
        ambientEntity.components.set(PointLightComponent(color: UIColor(red: 0.6, green: 0.65, blue: 0.75, alpha: 1), intensity: 400, attenuationRadius: 15))
        group.addChild(ambientEntity)

        return group
    }

    private func triggerRimEffect(root: Entity) {
        let ring = MeshResource.generateCylinder(height: 0.08, radius: 0.52)
        var flashMat = SimpleMaterial()
        flashMat.color = .init(tint: .init(red: 1, green: 0.8, blue: 0.35, alpha: 0.85))
        let flashEntity = ModelEntity(mesh: ring, materials: [flashMat])
        flashEntity.position = SIMD3<Float>(-4.5, 2.1, 0)
        flashEntity.orientation = simd_quatf(angle: .pi / 2, axis: [0, 0, 1])
        root.addChild(flashEntity)
        Task {
            try? await Task.sleep(for: .milliseconds(420))
            await MainActor.run {
                flashEntity.removeFromParent()
            }
        }
    }
}

extension Entity {
    func findEntity(named name: String) -> Entity? {
        if self.name == name { return self }
        for child in children {
            if let found = child.findEntity(named: name) { return found }
        }
        return nil
    }
}
```

File: `Source/ViewModels/LabViewModel.swift`

```swift
import SwiftUI

/// Holds `NotificationCenter` token so removal runs in `deinit` without touching `@MainActor` / `@Observable` stored state.
private final class PRQMetricsObserverBox {
    var token: NSObjectProtocol?
    deinit {
        if let token {
            NotificationCenter.default.removeObserver(token)
        }
    }
}

private final class WalletSyncObserverBox {
    var token: NSObjectProtocol?
    deinit {
        if let token {
            NotificationCenter.default.removeObserver(token)
        }
    }
}

@Observable
@MainActor
class LabViewModel {
    var profile: UserProfile
    var tracks: [CurriculumTrack] = SampleData.tracks
    var sessions: [WorkoutSession] = []
    var leaderboard: [LeaderboardEntry] = SampleData.leaderboard
    var selectedTrack: CurriculumTrack?
    /// When set, Training tab will switch to this track on next appear (used by Lab Quick Start).
    var preselectedTrack: TrainingTrack?
    /// When set, Arena tab will open this mode on next appear (e.g. Brain Brawl from Games dashboard).
    var preselectedArenaModeId: GameModeId?
    /// When set, Games → Vertical Velocity Academy opens this module (`mod1`…`mod12`) on next sheet presentation.
    var preselectedAcademyModuleId: String?
    /// When set, Lab will open the dunk full-screen flow on next appear (e.g. from Arena Dunk Contest).
    var openDunkOnNextLabAppearance: Bool = false
    var activeExercise: Exercise?
    var isWorkoutActive: Bool = false
    var workoutTimer: Int = 0
    var completedExerciseIds: Set<String> = []

    var neuralDrivePhase: Double = 0
    var healthKit = HealthKitService()
    var coachEconomy: CoachEconomy = SaveSystem.loadCoachEconomy()
    var gameResults: [GameSessionResult] = SaveSystem.loadGameResults()
    /// Unreal + future neuro session rows (Vault / Dashboard parity).
    var prqHistoryEntries: [PRQHistoryEntry] = SaveSystem.loadPRQHistory()
    var lastSessionReadiness: Double = 50

    var biomechanicsAudit: BiomechanicsAudit?
    var globalLeaderboard = GlobalLeaderboardService()
    var critiqueRequests: [CritiqueRequest] = SaveSystem.loadCritiqueRequests()
    var multipeerService = MultipeerService()

    /// Observes `PRQMetricsUpdated` (Unity → `PRQNativeBridge.postMetrics`) to persist XP / exercise rewards.
    private let prqMetricsObserverBox = PRQMetricsObserverBox()
    /// Supabase Realtime `user_balances` → `PRQManager.syncWallet` notification so shard / Cortex credits refresh in UI.
    /// Pipeline: `FELSupabaseWalletSync` + `FELAppConfig.felSupabaseURL` (production URL/keys for Alpha 1 — see `Config/FEL_ALPHA1_TESTFLIGHT_ENV.txt`).
    private let walletSyncObserverBox = WalletSyncObserverBox()

    init() {
        self.profile = SaveSystem.loadProfile()
        self.sessions = SaveSystem.loadSessions()

        if profile.systemScan == nil {
            applyScanResult(SystemScanResult.defaultForProfile(profile))
        }

        if let scan = profile.systemScan {
            self.biomechanicsAudit = BiomechanicsAudit.fromScanResult(scan)
        }

        PRQManager.shared.sync(from: self)
        PRQManager.shared.attachSessionBridge(self)

        globalLeaderboard.refreshRankings(userProfile: profile, sampleData: SampleData.leaderboard, effectivePrq: effectiveMetrics.prqScore)

        if healthKit.isAuthorized {
            Task {
                await healthKit.fetchLatestData()
                applyHealthKitData()
            }
        }

        prqMetricsObserverBox.token = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("PRQMetricsUpdated"),
            object: nil,
            queue: .main
        ) { [weak self] note in
            // `queue: .main` runs this block on the main queue; sync with MainActor-isolated `applyUnityHostMetrics`.
            MainActor.assumeIsolated {
                guard let self else { return }
                self.applyUnityHostMetrics(note.userInfo)
            }
        }

        Task { @MainActor in
            FELUnrealSessionImporter.shared.start(labViewModel: self)
        }

        Task { @MainActor in
            FELSupabaseWalletSync.shared.resumeSessionIfNeeded(labViewModel: self)
        }

        walletSyncObserverBox.token = NotificationCenter.default.addObserver(
            forName: .felWalletBalanceDidUpdate,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.profile = SaveSystem.loadProfile()
            }
        }
    }

    private func applyUnityHostMetrics(_ userInfo: [AnyHashable: Any]?) {
        guard let info = userInfo else { return }
        var changed = false
        if let xp = info["unityXP"] as? Int, xp > 0 {
            profile.evolutionShards += min(xp, 1_000)
            changed = true
        }
        if let rep = info["unityRepShards"] as? Int, rep > 0 {
            profile.evolutionShards += min(rep, 500)
            changed = true
        }
        if let payload = info["unityExerciseComplete"] as? String, !payload.isEmpty {
            profile.evolutionShards += 5
            changed = true
        }
        if changed {
            SaveSystem.saveProfile(profile)
            PRQManager.shared.sync(from: self)
            globalLeaderboard.refreshRankings(userProfile: profile, sampleData: SampleData.leaderboard, effectivePrq: effectiveMetrics.prqScore)
        }
    }

    var allExercises: [Exercise] {
        tracks.flatMap(\.exercises)
    }

    var todaysSessions: [WorkoutSession] {
        let calendar = Calendar.current
        return sessions.filter { calendar.isDateInToday($0.date) }
    }

    var weeklyShards: Int {
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return sessions.filter { $0.date >= weekAgo }.reduce(0) { $0 + $1.shardsEarned }
    }

    /// Program(): Recommends training track from PRQ, Pop Force, and biomechanics audit (deficiency-driven prescription).
    var recommendedTrackFromAudit: TrainingTrack? {
        let prq = profile.metrics.prqScore
        let popForce = profile.metrics.popForce
        let audit = biomechanicsAudit
        let leakage = audit?.leakagePercentage ?? 0
        if prq < 50 || leakage > 50 || popForce < 35 {
            return .foundations
        }
        if prq < 65 || audit?.overallGrade == .developing || popForce < 55 {
            return .flight
        }
        return .elite
    }

    func completeExercise(_ exercise: Exercise) {
        completedExerciseIds.insert(exercise.id)
        profile.metrics.neuralDrive = min(100, profile.metrics.neuralDrive + 2.5)
        profile.metrics.verticalPotential = min(100, profile.metrics.verticalPotential + 1.5)
        SaveSystem.saveProfile(profile)
    }

    func finishWorkout(for track: CurriculumTrack) {
        let completed = track.exercises.filter { completedExerciseIds.contains($0.id) }.count
        let rewards = ShardReward.forWorkout(exercisesCompleted: completed, trackDifficulty: track.difficulty)
        let totalShards = rewards.reduce(0) { $0 + $1.amount }
        let session = WorkoutSession(
            id: UUID().uuidString,
            trackId: track.id,
            date: Date(),
            exercisesCompleted: completed,
            totalExercises: track.totalExercises,
            durationSeconds: workoutTimer,
            shardsEarned: totalShards
        )
        sessions.append(session)
        profile.totalWorkouts += 1
        profile.evolutionShards += session.shardsEarned
        profile.metrics.prqScore = PRQ.clamp(profile.metrics.prqScore + Double(completed) * 0.5)
        profile.metrics.efficiencyScore = min(100, session.completionRate * 100)
        profile.metrics.verticalPotential = min(100, profile.metrics.verticalPotential + Double(completed) * 0.8)

        updateStreak()
        if profile.streakDays > 0 && profile.streakDays % 7 == 0 {
            profile.evolutionShards += 50
        }

        SaveSystem.saveProfile(profile)
        SaveSystem.saveSessions(sessions)

        isWorkoutActive = false
        workoutTimer = 0
        completedExerciseIds.removeAll()

        globalLeaderboard.refreshRankings(userProfile: profile, sampleData: SampleData.leaderboard, effectivePrq: effectiveMetrics.prqScore)
    }

    // MARK: - Fuel the Freeway (Photo-to-Shard nutrition)
    /// When true, Fuel UI shows "Congestion Alert" — roadblock on CNS Freeway; Movement Snack clears it.
    var hasCongestionAlert: Bool = false

    func applyMealLogRewards(structuralRepair: Bool, fascialElasticity: Bool, signalVelocity: Bool, congestionCleared: Bool) {
        let rewards = ShardReward.forMealLog(
            structuralRepair: structuralRepair,
            fascialElasticity: fascialElasticity,
            signalVelocity: signalVelocity,
            hadCongestionCleared: congestionCleared
        )
        let total = rewards.reduce(0) { $0 + $1.amount }
        profile.evolutionShards += total
        SaveSystem.saveProfile(profile)
    }

    func setCongestionAlert(_ value: Bool) {
        hasCongestionAlert = value
    }

    /// User completed a Movement Snack; clear congestion and award shards if applicable.
    func clearCongestion() {
        hasCongestionAlert = false
    }

    var effectiveMetrics: PerformanceMetrics {
        let gearPrq = FELGearBoostCalculator.gearPrqPoints(profile: profile)
        let basePrq = PRQ.clamp(profile.metrics.prqScore + gearPrq)
        guard let card = profile.activeCreatorCard,
              let catalogCard = CreatorCard.catalog.first(where: { $0.id == card.cardId }) else {
            return PerformanceMetrics(
                efficiencyScore: profile.metrics.efficiencyScore,
                prqScore: basePrq,
                readinessScore: profile.metrics.readinessScore,
                verticalPotential: profile.metrics.verticalPotential,
                neuralDrive: profile.metrics.neuralDrive,
                popForce: profile.metrics.popForce,
                currentOutfit: profile.metrics.currentOutfit
            )
        }
        let boost = catalogCard.metricsBoost
        return PerformanceMetrics(
            efficiencyScore: min(100, profile.metrics.efficiencyScore + boost.efficiencyScore),
            prqScore: PRQ.clamp(min(100, basePrq + boost.prqScore)),
            readinessScore: min(100, profile.metrics.readinessScore + boost.readinessScore),
            verticalPotential: min(100, profile.metrics.verticalPotential + boost.verticalPotential),
            neuralDrive: min(100, profile.metrics.neuralDrive + boost.neuralDrive),
            popForce: min(100, profile.metrics.popForce + boost.popForce),
            currentOutfit: boost.currentOutfit
        )
    }

    func applyScanResult(_ result: SystemScanResult) {
        profile.systemScan = result
        profile.metrics.prqScore = PRQ.clamp(result.prqScore)
        profile.metrics.verticalPotential = result.verticalEstimateInches
        profile.metrics.readinessScore = max(70, profile.metrics.readinessScore)
        let derivedPop = Self.derivePopForceFromScan(
            flightTimeSeconds: result.flightTimeSeconds,
            verticalInches: result.verticalEstimateInches,
            prq: result.prqScore
        )
        profile.metrics.popForce = derivedPop
        profile.metrics.efficiencyScore = max(70, min(100, profile.metrics.efficiencyScore * 0.6 + derivedPop * 0.4))

        biomechanicsAudit = BiomechanicsAudit.fromScanResult(result)

        SaveSystem.saveProfile(profile)
        PRQManager.shared.sync(from: self)
        // Readiness JSON (ankle/knee/hip kinetic heat) is written in `PRQManager.sync`; twin-birth + UI follow on the main actor.
        Task { @MainActor in
            FELBirthReadinessWriter.notifyTwinBirth()
            globalLeaderboard.refreshRankings(userProfile: profile, sampleData: SampleData.leaderboard, effectivePrq: effectiveMetrics.prqScore)
        }
    }

    /// Derives Pop Force (RFD/GRF proxy) from scan: flight time = reactivity, vertical = output.
    static func derivePopForceFromScan(flightTimeSeconds: Double, verticalInches: Double, prq: Double) -> Double {
        let flightComponent = min(50, flightTimeSeconds * 80)
        let verticalComponent = min(40, verticalInches * 1.25)
        let prqComponent = prq * 0.1
        return PRQ.clamp(flightComponent + verticalComponent + prqComponent)
    }

    var arcadePhysics: ArcadePhysics {
        ArcadePhysics.fromPRQ(effectiveMetrics.prqScore, neuralDrive: effectiveMetrics.neuralDrive, audit: biomechanicsAudit)
    }

    /// Academy Plyos (`mod9`) mastery: +2% to Dunk Contest judge math (exported to Unreal as `academyPlyosMasteryBonus`).
    var academyPlyosMasteryNeuroMultiplier: Double {
        profile.completedAcademyModuleIds.contains("mod9") ? 1.02 : 1.0
    }

    func markAcademyModuleComplete(_ moduleId: String) {
        guard VerticalVelocityAcademyCurriculum.module(id: moduleId) != nil else { return }
        if !profile.completedAcademyModuleIds.contains(moduleId) {
            profile.completedAcademyModuleIds.append(moduleId)
            SaveSystem.saveProfile(profile)
            PRQManager.shared.sync(from: self)
        }
    }

    var activeMovementSignature: MovementSignature {
        guard let card = profile.activeCreatorCard,
              let catalogCard = CreatorCard.catalog.first(where: { $0.id == card.cardId }) else {
            return MovementSignature(
                style: .standard,
                jumpApex: 1.0,
                hangTimeFactor: 1.0,
                firstStepBurst: 1.0,
                limbEmission: 0.3,
                trailColor: Theme.brandBlue
            )
        }
        return catalogCard.movementSignature
    }

    var userPRQTier: PRQTier {
        PRQTier.fromPRQ(effectiveMetrics.prqScore)
    }

    var totalGameWins: Int {
        gameResults.filter { $0.didWin }.count
    }

    var winRate: Double {
        guard !gameResults.isEmpty else { return 0 }
        return Double(totalGameWins) / Double(gameResults.count) * 100
    }

    func connectHealthKit() async {
        await healthKit.requestAuthorization()
        if healthKit.isAuthorized {
            await healthKit.fetchLatestData()
            applyHealthKitData()
        }
    }

    func refreshHealthData() async {
        guard healthKit.isAuthorized else { return }
        await healthKit.fetchLatestData()
        applyHealthKitData()
    }

    private func applyHealthKitData() {
        if healthKit.restingHeartRate > 0 {
            profile.metrics.readinessScore = calculateReadiness(rhr: healthKit.restingHeartRate)
        }

        let buff = healthKit.arcadePhysicsBuff
        if healthKit.hrvValue > 0 || healthKit.restingHeartRate > 0 {
            profile.metrics.neuralDrive = min(100, buff.neuralDriveOverride)
        }

        SaveSystem.saveProfile(profile)
    }

    private func calculateReadiness(rhr: Double) -> Double {
        let baseline: Double = 60
        let deviation = abs(rhr - baseline)
        return max(0, min(100, 100 - deviation * 2))
    }

    var healthKitBuff: ArcadePhysicsBuff {
        healthKit.arcadePhysicsBuff
    }

    private func updateStreak() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let lastSession = sessions.dropLast().last
        if let lastDate = lastSession?.date {
            let lastDay = calendar.startOfDay(for: lastDate)
            let daysBetween = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0
            if daysBetween <= 1 {
                profile.streakDays += 1
            } else {
                profile.streakDays = 1
            }
        } else {
            profile.streakDays = 1
        }
    }

    func completeOnboarding(sport: String, age: Int, goal: String) {
        profile.sport = sport
        profile.age = age
        profile.goal = goal
        profile.hasCompletedOnboarding = true
        SaveSystem.saveProfile(profile)
    }


    /// Academy Arena local trade (Multipeer): swap shards and/or Creator Cards in person.
    func applyAcademyTrade(giveShards: Int, receiveShards: Int, giveCardId: String?, receiveCardId: String?) -> Bool {
        guard giveShards >= 0, receiveShards >= 0 else { return false }
        guard profile.evolutionShards >= giveShards else { return false }
        if let g = giveCardId {
            guard profile.ownsCard(g) else { return false }
        }
        profile.evolutionShards -= giveShards
        profile.evolutionShards += receiveShards
        if let g = giveCardId, let idx = profile.ownedCardIds.firstIndex(of: g) {
            profile.ownedCardIds.remove(at: idx)
        }
        if let r = receiveCardId, !r.isEmpty, !profile.ownedCardIds.contains(r) {
            profile.ownedCardIds.append(r)
        }
        SaveSystem.saveProfile(profile)
        return true
    }

    func applyCreatorCard(_ card: CreatorCard) {
        Task { @MainActor in
            let alreadyOwned = profile.ownsCard(card.id)
            if !alreadyOwned {
                guard profile.evolutionShards >= card.costShards else { return }
                let ok = await FELSovereignShardEconomy.postCreatorCardUnlock(
                    card: card,
                    grossShards: card.costShards,
                    athleteId: profile.id,
                    displayName: profile.displayName
                )
                guard ok else { return }
                profile.evolutionShards -= card.costShards
                profile.ownedCardIds.append(card.id)
                UFELCreatorRevenueSubsystem.shared.recordCreatorCardUnlock(card: card, grossShards: card.costShards)
            }
            let oneWeekFromNow = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
            profile.activeCreatorCard = CreatorCardState(
                cardId: card.id,
                creatorName: card.creatorName,
                appliedAt: Date(),
                costShards: card.costShards,
                metricsBoost: card.metricsBoost,
                nextTaxDue: oneWeekFromNow,
                weeklyTaxShards: Self.weeklyCardTaxShards
            )
            SaveSystem.saveProfile(profile)
            UFELCreatorRevenueSubsystem.shared.recordCardStand(
                athleteAnonId: profile.id,
                cardId: card.id,
                coachMerchantID: card.felMerchantID
            )
        }
    }

    func clearCreatorCard() {
        profile.activeCreatorCard = nil
        SaveSystem.saveProfile(profile)
    }

    static let critiqueCostShards = 500
    /// Weekly Shard tax to keep equipped Creator Card buffs active (Spatial Sports Economy).
    static let weeklyCardTaxShards = 25

    func requestCritique(exerciseName: String, notes: String) -> Bool {
        let cost = Self.critiqueCostShards
        guard profile.evolutionShards >= cost else { return false }
        profile.evolutionShards -= cost

        let request = CritiqueRequest(
            id: UUID().uuidString,
            athleteId: profile.id,
            exerciseName: exerciseName,
            notes: notes,
            requestDate: Date(),
            shardsCost: cost,
            status: .pending,
            coachResponse: nil
        )
        critiqueRequests.append(request)

        coachEconomy.completeCritique(shards: cost, critiqueId: request.id)

        SaveSystem.saveProfile(profile)
        SaveSystem.saveCritiqueRequests(critiqueRequests)
        SaveSystem.saveCoachEconomy(coachEconomy)
        return true
    }

    func reviewCritique(requestId: String, rating: Double) {
        guard let index = critiqueRequests.firstIndex(where: { $0.id == requestId && $0.status == .completed }) else { return }
        critiqueRequests[index].status = .rated

        coachEconomy.releaseCritique(critiqueId: requestId, athleteRating: rating)

        SaveSystem.saveCritiqueRequests(critiqueRequests)
        SaveSystem.saveCoachEconomy(coachEconomy)
    }

    func simulateCoachResponse(requestId: String) {
        guard let index = critiqueRequests.firstIndex(where: { $0.id == requestId && $0.status == .pending }) else { return }
        critiqueRequests[index].status = .completed
        critiqueRequests[index].coachResponse = CritiqueResponse(
            coachName: "Coach V",
            responseDate: Date(),
            textFeedback: "Good intent on the load phase. Focus on maintaining ankle stiffness through ground contact. Your hip extension timing is slightly delayed — drill single-leg hip bridges before your next jump session.",
            overallGrade: "DEVELOPING",
            focusAreas: ["Ankle Stiffness", "Hip Extension", "Ground Contact"]
        )
        SaveSystem.saveCritiqueRequests(critiqueRequests)
    }
}
```

File: `Source/Services/PRQScoreManager.swift`

```swift
import Foundation
import Observation

// MARK: - Performance Readiness Quotient (PRQ) — Native Swift, no custom runtime
nonisolated let prqScoreUpdatedNotification = NSNotification.Name("PRQScoreUpdated")
nonisolated let prqScoreDidUpdateNotification = NSNotification.Name("PRQScoreDidUpdate")

@Observable
@MainActor
final class PRQScoreManager {
    static let shared = PRQScoreManager()

    static let userDefaultsKey = "app_prq_score"

    private(set) var currentPrqScore: Int

    /// One-time migration from pre–1.0 third-party tooling UserDefaults key (bytes spell legacy key; not stored as literal in source).
    private static let legacyPrqScoreKeyObsolete: String = String(
        decoding: [114, 111, 114, 107, 95, 112, 114, 113, 95, 115, 99, 111, 114, 101],
        as: UTF8.self
    )

    private init() {
        var value = UserDefaults.standard.integer(forKey: Self.userDefaultsKey)
        if value == 0, UserDefaults.standard.object(forKey: Self.legacyPrqScoreKeyObsolete) != nil {
            value = UserDefaults.standard.integer(forKey: Self.legacyPrqScoreKeyObsolete)
            UserDefaults.standard.set(value, forKey: Self.userDefaultsKey)
        }
        currentPrqScore = value
        if currentPrqScore == 0 {
            currentPrqScore = Int(PRQ.default)
        }

        NotificationCenter.default.addObserver(
            forName: prqScoreUpdatedNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let score = notification.userInfo?["score"] as? Int else { return }
            MainActor.assumeIsolated {
                self.currentPrqScore = score
                UserDefaults.standard.set(score, forKey: PRQScoreManager.userDefaultsKey)
                NotificationCenter.default.post(name: prqScoreDidUpdateNotification, object: nil, userInfo: ["score": score])
            }
        }
    }

    var prqTier: String {
        if currentPrqScore >= 95 { return "LEGENDARY" }
        if currentPrqScore >= 80 { return "ELITE" }
        if currentPrqScore >= 60 { return "ADVANCED" }
        if currentPrqScore >= 40 { return "DEVELOPING" }
        return "FOUNDATION"
    }

    var tierColor: String {
        if currentPrqScore >= 95 { return "gold" }
        if currentPrqScore >= 80 { return "purple" }
        if currentPrqScore >= 60 { return "blue" }
        if currentPrqScore >= 40 { return "green" }
        return "gray"
    }

    func simulateUnityScore(_ score: Int) {
        NotificationCenter.default.post(
            name: prqScoreUpdatedNotification,
            object: nil,
            userInfo: ["score": score]
        )
    }
}
```

File: `Source/Models/UserProfile.swift`

```swift
import Foundation

nonisolated struct UserProfile: Sendable, Identifiable {
    var id: String
    var displayName: String
    var athleteTag: String
    var metrics: PerformanceMetrics
    var evolutionShards: Int
    var credits: Int
    var totalWorkouts: Int
    var streakDays: Int
    var joinDate: Date
    var avatarSystemName: String
    var blueprintCredits: Int

    var sport: String?
    var age: Int?
    var goal: String?
    var hasCompletedOnboarding: Bool
    var systemScan: SystemScanResult?
    var activeCreatorCard: CreatorCardState?
    var ownedCardIds: [String]
    /// Vertical Velocity Academy — completed module keys (`mod1`…`mod12`). `mod9` = Plyos mastery (Dunk Contest neuro bonus).
    var completedAcademyModuleIds: [String]
    /// Shard marketplace exclusive gear — Unreal soft paths by slot (`jersey`, `shoes`) for `DigitalTwinSkeletalMesh` materials.
    var equippedGearTexturePaths: [String: String]
    /// Pro-Coach Sovereign Invite: coach `CreatorID` locked in on first System Scan when a valid pending code was registered.
    var linkedCoachCreatorId: String?
    /// When `linkedCoachCreatorId` was committed (first scan handoff).
    var coachInviteLinkedAt: Date?
    /// Supabase `auth.users.id` (UUID string) when signed in — used for wallet RLS + Stripe metadata.
    var supabaseUserId: String?

    func ownsCard(_ cardId: String) -> Bool {
        ownedCardIds.contains(cardId)
    }

    /// Avatar skin to use everywhere (from system scan or placeholder until scan data is in).
    /// Placeholder is a neutral model lookalike so the main user always has a visible avatar before calibration.
    var effectiveAvatarConfig: AvatarSkinConfig {
        systemScan?.avatarConfig ?? AvatarSkinConfig.placeholder
    }
}

extension UserProfile: Codable {
    enum CodingKeys: String, CodingKey {
        case id, displayName, athleteTag, metrics, evolutionShards, credits, totalWorkouts, streakDays, joinDate
        case avatarSystemName, blueprintCredits, sport, age, goal, hasCompletedOnboarding, systemScan
        case activeCreatorCard, ownedCardIds, completedAcademyModuleIds, equippedGearTexturePaths
        case linkedCoachCreatorId, coachInviteLinkedAt, supabaseUserId
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        displayName = try container.decode(String.self, forKey: .displayName)
        athleteTag = try container.decode(String.self, forKey: .athleteTag)
        metrics = try container.decode(PerformanceMetrics.self, forKey: .metrics)
        evolutionShards = try container.decode(Int.self, forKey: .evolutionShards)
        credits = (try? container.decode(Int.self, forKey: .credits)) ?? 0
        totalWorkouts = try container.decode(Int.self, forKey: .totalWorkouts)
        streakDays = try container.decode(Int.self, forKey: .streakDays)
        joinDate = try container.decode(Date.self, forKey: .joinDate)
        avatarSystemName = try container.decode(String.self, forKey: .avatarSystemName)
        blueprintCredits = try container.decode(Int.self, forKey: .blueprintCredits)
        sport = try container.decodeIfPresent(String.self, forKey: .sport)
        age = try container.decodeIfPresent(Int.self, forKey: .age)
        goal = try container.decodeIfPresent(String.self, forKey: .goal)
        hasCompletedOnboarding = (try? container.decode(Bool.self, forKey: .hasCompletedOnboarding)) ?? false
        systemScan = try container.decodeIfPresent(SystemScanResult.self, forKey: .systemScan)
        activeCreatorCard = try container.decodeIfPresent(CreatorCardState.self, forKey: .activeCreatorCard)
        ownedCardIds = (try? container.decode([String].self, forKey: .ownedCardIds)) ?? []
        completedAcademyModuleIds = (try? container.decode([String].self, forKey: .completedAcademyModuleIds)) ?? []
        equippedGearTexturePaths = (try? container.decode([String: String].self, forKey: .equippedGearTexturePaths)) ?? [:]
        linkedCoachCreatorId = try container.decodeIfPresent(String.self, forKey: .linkedCoachCreatorId)
        coachInviteLinkedAt = try container.decodeIfPresent(Date.self, forKey: .coachInviteLinkedAt)
        supabaseUserId = try container.decodeIfPresent(String.self, forKey: .supabaseUserId)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(athleteTag, forKey: .athleteTag)
        try container.encode(metrics, forKey: .metrics)
        try container.encode(evolutionShards, forKey: .evolutionShards)
        try container.encode(credits, forKey: .credits)
        try container.encode(totalWorkouts, forKey: .totalWorkouts)
        try container.encode(streakDays, forKey: .streakDays)
        try container.encode(joinDate, forKey: .joinDate)
        try container.encode(avatarSystemName, forKey: .avatarSystemName)
        try container.encode(blueprintCredits, forKey: .blueprintCredits)
        try container.encodeIfPresent(sport, forKey: .sport)
        try container.encodeIfPresent(age, forKey: .age)
        try container.encodeIfPresent(goal, forKey: .goal)
        try container.encode(hasCompletedOnboarding, forKey: .hasCompletedOnboarding)
        try container.encodeIfPresent(systemScan, forKey: .systemScan)
        try container.encodeIfPresent(activeCreatorCard, forKey: .activeCreatorCard)
        try container.encode(ownedCardIds, forKey: .ownedCardIds)
        try container.encode(completedAcademyModuleIds, forKey: .completedAcademyModuleIds)
        try container.encode(equippedGearTexturePaths, forKey: .equippedGearTexturePaths)
        try container.encodeIfPresent(linkedCoachCreatorId, forKey: .linkedCoachCreatorId)
        try container.encodeIfPresent(coachInviteLinkedAt, forKey: .coachInviteLinkedAt)
        try container.encodeIfPresent(supabaseUserId, forKey: .supabaseUserId)
    }

    static let guest = UserProfile(
        id: "guest_\(Int.random(in: 1000...9999))",
        displayName: "Guest Athlete",
        athleteTag: "0xGuest",
        metrics: .empty,
        evolutionShards: 0,
        credits: 0,
        totalWorkouts: 0,
        streakDays: 0,
        joinDate: Date(),
        avatarSystemName: "figure.run",
        blueprintCredits: 0,
        sport: nil,
        age: nil,
        goal: nil,
        hasCompletedOnboarding: false,
        systemScan: nil,
        activeCreatorCard: nil,
        ownedCardIds: [],
        completedAcademyModuleIds: [],
        equippedGearTexturePaths: [:],
        linkedCoachCreatorId: nil,
        coachInviteLinkedAt: nil,
        supabaseUserId: nil
    )

}

nonisolated struct SystemScanResult: Codable, Sendable {
    let id: String
    let date: Date
    let prqScore: Double
    let verticalEstimateInches: Double
    let flightTimeSeconds: Double
    let movementGrade: String
    let notes: [String]
    let recommendedTrack: String
    var avatarConfig: AvatarSkinConfig
    /// Capture metadata (120/240 fps) for frame-accurate flight when pose pipeline supplies indices.
    var videoNominalFrameRateHz: Double?
    var toeOffFrameIndex: Int?
    var heelStrikeFrameIndex: Int?
    /// SFMA multi-segmental rotation screen: `false` = fail → Cloud Cortex must prescribe Mod 4 + 90/90 rotation snack.
    var sfmaMultiSegmentalRotationPassed: Bool?

    enum CodingKeys: String, CodingKey {
        case id, date, prqScore, verticalEstimateInches, flightTimeSeconds, movementGrade, notes, recommendedTrack, avatarConfig
        case videoNominalFrameRateHz, toeOffFrameIndex, heelStrikeFrameIndex
        case sfmaMultiSegmentalRotationPassed
    }

    init(
        id: String,
        date: Date,
        prqScore: Double,
        verticalEstimateInches: Double,
        flightTimeSeconds: Double,
        movementGrade: String,
        notes: [String],
        recommendedTrack: String,
        avatarConfig: AvatarSkinConfig = .default,
        videoNominalFrameRateHz: Double? = nil,
        toeOffFrameIndex: Int? = nil,
        heelStrikeFrameIndex: Int? = nil,
        sfmaMultiSegmentalRotationPassed: Bool? = nil
    ) {
        self.id = id
        self.date = date
        self.prqScore = prqScore
        self.verticalEstimateInches = verticalEstimateInches
        self.flightTimeSeconds = flightTimeSeconds
        self.movementGrade = movementGrade
        self.notes = notes
        self.recommendedTrack = recommendedTrack
        self.avatarConfig = avatarConfig
        self.videoNominalFrameRateHz = videoNominalFrameRateHz
        self.toeOffFrameIndex = toeOffFrameIndex
        self.heelStrikeFrameIndex = heelStrikeFrameIndex
        self.sfmaMultiSegmentalRotationPassed = sfmaMultiSegmentalRotationPassed
    }

    /// Returns a copy of this result with a new avatar config (e.g. after user customization).
    nonisolated func withAvatarConfig(_ newConfig: AvatarSkinConfig) -> SystemScanResult {
        SystemScanResult(
            id: id,
            date: date,
            prqScore: prqScore,
            verticalEstimateInches: verticalEstimateInches,
            flightTimeSeconds: flightTimeSeconds,
            movementGrade: movementGrade,
            notes: notes,
            recommendedTrack: recommendedTrack,
            avatarConfig: newConfig,
            videoNominalFrameRateHz: videoNominalFrameRateHz,
            toeOffFrameIndex: toeOffFrameIndex,
            heelStrikeFrameIndex: heelStrikeFrameIndex,
            sfmaMultiSegmentalRotationPassed: sfmaMultiSegmentalRotationPassed
        )
    }

    /// Showcase Demo Mode: reuse cached rig/PRQ without re-running analysis (new id + timestamp).
    nonisolated func demoFastTrackClone() -> SystemScanResult {
        let tag = "Demo Fast-Track — cached AvatarRig (no re-scan)."
        var nextNotes = notes
        if !nextNotes.contains(where: { $0 == tag }) {
            nextNotes.append(tag)
        }
        return SystemScanResult(
            id: UUID().uuidString,
            date: Date(),
            prqScore: prqScore,
            verticalEstimateInches: verticalEstimateInches,
            flightTimeSeconds: flightTimeSeconds,
            movementGrade: movementGrade,
            notes: nextNotes,
            recommendedTrack: recommendedTrack,
            avatarConfig: avatarConfig,
            videoNominalFrameRateHz: videoNominalFrameRateHz,
            toeOffFrameIndex: toeOffFrameIndex,
            heelStrikeFrameIndex: heelStrikeFrameIndex,
            sfmaMultiSegmentalRotationPassed: sfmaMultiSegmentalRotationPassed
        )
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        date = try container.decode(Date.self, forKey: .date)
        prqScore = try container.decode(Double.self, forKey: .prqScore)
        verticalEstimateInches = try container.decode(Double.self, forKey: .verticalEstimateInches)
        flightTimeSeconds = try container.decode(Double.self, forKey: .flightTimeSeconds)
        movementGrade = try container.decode(String.self, forKey: .movementGrade)
        notes = try container.decode([String].self, forKey: .notes)
        recommendedTrack = try container.decode(String.self, forKey: .recommendedTrack)
        avatarConfig = (try? container.decode(AvatarSkinConfig.self, forKey: .avatarConfig)) ?? .default
        videoNominalFrameRateHz = try container.decodeIfPresent(Double.self, forKey: .videoNominalFrameRateHz)
        toeOffFrameIndex = try container.decodeIfPresent(Int.self, forKey: .toeOffFrameIndex)
        heelStrikeFrameIndex = try container.decodeIfPresent(Int.self, forKey: .heelStrikeFrameIndex)
        sfmaMultiSegmentalRotationPassed = try container.decodeIfPresent(Bool.self, forKey: .sfmaMultiSegmentalRotationPassed)
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(date, forKey: .date)
        try container.encode(prqScore, forKey: .prqScore)
        try container.encode(verticalEstimateInches, forKey: .verticalEstimateInches)
        try container.encode(flightTimeSeconds, forKey: .flightTimeSeconds)
        try container.encode(movementGrade, forKey: .movementGrade)
        try container.encode(notes, forKey: .notes)
        try container.encode(recommendedTrack, forKey: .recommendedTrack)
        try container.encode(avatarConfig, forKey: .avatarConfig)
        try container.encodeIfPresent(videoNominalFrameRateHz, forKey: .videoNominalFrameRateHz)
        try container.encodeIfPresent(toeOffFrameIndex, forKey: .toeOffFrameIndex)
        try container.encodeIfPresent(heelStrikeFrameIndex, forKey: .heelStrikeFrameIndex)
        try container.encodeIfPresent(sfmaMultiSegmentalRotationPassed, forKey: .sfmaMultiSegmentalRotationPassed)
    }

    /// Default scan for profiles that have not run a system scan yet. Auto-creates a character so the main user always loads with a skin.
    static func defaultForProfile(_ profile: UserProfile) -> SystemScanResult {
        let prq = PRQ.clamp(profile.metrics.prqScore)
        let vertical = min(40, max(18, profile.metrics.verticalPotential * 0.28))
        let flight = 0.48
        let track: String
        switch profile.goal ?? "" {
        case "Jump Higher": track = "Flight"
        case "Get Faster": track = "Foundations"
        case "Build Power": track = "Elite"
        default: track = "Foundations"
        }
        let grade: String
        switch prq {
        case 80...: grade = "ELITE POTENTIAL"
        case 65..<80: grade = "FLIGHT READY"
        case 50..<65: grade = "BUILDING BASE"
        default: grade = "FOUNDATION PHASE"
        }
        let avatarConfig = AvatarSkinConfig.fromScan(prq: prq, vertical: vertical, flight: flight, sport: profile.sport)
        return SystemScanResult(
            id: UUID().uuidString,
            date: Date(),
            prqScore: prq,
            verticalEstimateInches: vertical,
            flightTimeSeconds: flight,
            movementGrade: grade,
            notes: [],
            recommendedTrack: track,
            avatarConfig: avatarConfig
        )
    }
}

nonisolated struct AvatarSkinConfig: Codable, Sendable {
    var heightScale: Double
    var weightScale: Double
    var limbLength: Double
    var skinTone: AvatarSkinTone
    var outfitStyle: AvatarOutfitStyle
    var auraColorR: Double
    var auraColorG: Double
    var auraColorB: Double
    var trailIntensity: Double

    static let `default` = AvatarSkinConfig(
        heightScale: 1.0,
        weightScale: 1.0,
        limbLength: 1.0,
        skinTone: .cyan,
        outfitStyle: .standard,
        auraColorR: 0,
        auraColorG: 0.83,
        auraColorB: 1.0,
        trailIntensity: 0.3
    )

    /// Neutral model lookalike shown until system scan data is available. Same rig as post-scan avatar, distinct silver/grey aura.
    static let placeholder = AvatarSkinConfig(
        heightScale: 1.0,
        weightScale: 1.0,
        limbLength: 1.0,
        skinTone: .cyan,
        outfitStyle: .standard,
        auraColorR: 0.52,
        auraColorG: 0.54,
        auraColorB: 0.58,
        trailIntensity: 0.2
    )

    static func fromScan(prq: Double, vertical: Double, flight: Double, sport: String?) -> AvatarSkinConfig {
        let normalizedPRQ = min(max(prq / 100.0, 0), 1)
        let heightBonus = min(0.15, vertical / 200.0)
        let flightBonus = min(0.1, flight * 0.15)

        let tone: AvatarSkinTone
        let outfit: AvatarOutfitStyle
        let auraR: Double
        let auraG: Double
        let auraB: Double

        switch prq {
        case 80...:
            tone = .elitePurple
            outfit = .elite
            auraR = 0.6; auraG = 0.2; auraB = 1.0
        case 65..<80:
            tone = .cyan
            outfit = .flight
            auraR = 0; auraG = 0.95; auraB = 0.9
        case 50..<65:
            tone = .blue
            outfit = .developing
            auraR = 0; auraG = 0.83; auraB = 1.0
        default:
            tone = .green
            outfit = .standard
            auraR = 0.2; auraG = 1.0; auraB = 0.4
        }

        let sportWeightBias: Double
        switch sport ?? "" {
        case "Basketball", "Volleyball": sportWeightBias = 0.95
        case "Football": sportWeightBias = 1.1
        case "Gymnastics": sportWeightBias = 0.88
        default: sportWeightBias = 1.0
        }

        return AvatarSkinConfig(
            heightScale: 1.0 + heightBonus,
            weightScale: sportWeightBias,
            limbLength: 1.0 + flightBonus,
            skinTone: tone,
            outfitStyle: outfit,
            auraColorR: auraR,
            auraColorG: auraG,
            auraColorB: auraB,
            trailIntensity: 0.2 + normalizedPRQ * 0.6
        )
    }
}

nonisolated enum AvatarSkinTone: String, Codable, Sendable {
    case cyan
    case blue
    case green
    case elitePurple
    case orange
}

nonisolated enum AvatarOutfitStyle: String, Codable, Sendable {
    case standard
    case developing
    case flight
    case elite
}

nonisolated struct CreatorCardState: Codable, Sendable {
    let cardId: String
    let creatorName: String
    let appliedAt: Date
    let costShards: Int
    let metricsBoost: PerformanceMetrics
    /// When the next weekly Shard tax is due to keep buffs active (Spatial Sports Economy).
    var nextTaxDue: Date?
    /// Weekly tax in Shards; nil means use app default.
    var weeklyTaxShards: Int?
}
```

File: `Source/Services/GeminiService.swift`

```swift
import Foundation
import Observation

// MARK: - Gemini API (Google AI) — REST client for Xcode
// Use for Photo-to-Shard meal analysis, chat, or any generateContent. Get an API key: https://aistudio.google.com/apikey

/// Lightweight Gemini REST client. API key from Info.plist (GEMINI_API_KEY) or environment.
@Observable
@MainActor
final class GeminiService {
    static let shared = GeminiService()

    private let baseURL = "https://generativelanguage.googleapis.com/v1beta"
    private let model = "gemini-1.5-flash"

    /// Set via configure(apiKey:) or read from Bundle/ProcessInfo. Never commit real keys.
    private(set) var apiKey: String?

    var isConfigured: Bool { apiKey != nil && !(apiKey?.isEmpty ?? true) }

    private init() {
        apiKey = Self.readAPIKeyFromEnvironment()
    }

    /// Call once at app launch (e.g. from App delegate or first view). Prefer loading from a secure config.
    func configure(apiKey: String?) {
        self.apiKey = apiKey?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? apiKey : nil
    }

    /// Generate text from a prompt. Use for chat, analysis, or after parsing image + prompt for Photo-to-Shard.
    func generateContent(prompt: String) async throws -> String {
        guard let apiKey else {
            throw GeminiError.missingAPIKey
        }
        return try await Self.generateContentREST(prompt: prompt, apiKey: apiKey)
    }

    /// Stateless Gemini `generateContent` — safe from `Task.detached` so MainActor / SwiftUI never blocks on I/O (~16.7 ms frame budget).
    nonisolated static func generateContentREST(prompt: String, apiKey: String) async throws -> String {
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=\(apiKey)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "contents": [["role": "user", "parts": [["text": prompt]]]],
            "generationConfig": [
                "temperature": 0.4,
                "maxOutputTokens": 1024,
            ] as [String: Any],
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw GeminiError.invalidResponse
        }
        if http.statusCode != 200 {
            let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? [String: Any]
            let errMsg = (message?["message"] as? String) ?? "HTTP \(http.statusCode)"
            throw GeminiError.apiError(errMsg)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let candidates = json?["candidates"] as? [[String: Any]]
        let content = candidates?.first?["content"] as? [String: Any]
        let parts = content?["parts"] as? [[String: Any]]
        let text = parts?.first?["text"] as? String
        guard let text else {
            throw GeminiError.noContent
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Analyze an image (e.g. meal photo) with a prompt. Pass image as base64-encoded JPEG/PNG data.
    func generateContentWithImage(prompt: String, imageBase64: String, mimeType: String = "image/jpeg") async throws -> String {
        guard let apiKey else {
            throw GeminiError.missingAPIKey
        }
        let url = URL(string: "\(baseURL)/models/\(model):generateContent?key=\(apiKey)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "contents": [[
                "role": "user",
                "parts": [
                    ["text": prompt],
                    [
                        "inline_data": [
                            "mime_type": mimeType,
                            "data": imageBase64
                        ]
                    ]
                ]
            ]],
            "generationConfig": [
                "temperature": 0.3,
                "maxOutputTokens": 1024,
            ] as [String : Any]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw GeminiError.invalidResponse
        }
        if http.statusCode != 200 {
            let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? [String: Any]
            let errMsg = (message?["message"] as? String) ?? "HTTP \(http.statusCode)"
            throw GeminiError.apiError(errMsg)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let candidates = json?["candidates"] as? [[String: Any]]
        let content = candidates?.first?["content"] as? [String: Any]
        let parts = content?["parts"] as? [[String: Any]]
        let text = parts?.first?["text"] as? String
        guard let text else {
            throw GeminiError.noContent
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func readAPIKeyFromEnvironment() -> String? {
        FELAppConfig.geminiAPIKey
    }
}

enum GeminiError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case noContent
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Gemini API key not set. Add GEMINI_API_KEY to Info.plist or call GeminiService.shared.configure(apiKey:)."
        case .invalidResponse:
            return "Invalid response from Gemini API."
        case .noContent:
            return "No content in Gemini response."
        case .apiError(let msg):
            return "Gemini API error: \(msg)"
        }
    }
}
```

File: `Source/Services/ExerciseNarrationService.swift`

```swift
import Foundation
import AVFoundation
import Combine

/// Simple text-to-speech coaching for exercises. Reads demoDescription and cues when enabled.
@MainActor
final class ExerciseNarrationService: ObservableObject {
    static let shared = ExerciseNarrationService()

    @Published var isEnabled: Bool = false
    private let synthesizer = AVSpeechSynthesizer()

    func speakIntro(for exercise: TrainingExercise) {
        guard isEnabled, !synthesizer.isSpeaking else { return }
        let text = "\(exercise.name). \(exercise.cues)"
        speak(text)
    }

    func speakSetComplete(currentSet: Int, totalSets: Int) {
        guard isEnabled else { return }
        let remaining = totalSets - currentSet
        let text: String
        if remaining > 0 {
            text = "Set \(currentSet) complete. \(remaining) sets left."
        } else {
            text = "Exercise complete. Nice work."
        }
        speak(text)
    }

    private func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.47
        synthesizer.speak(utterance)
    }
}
```

File: `Source/Models/BlueprintLibrary.swift`

```swift
import SwiftUI

struct BlueprintLibrary {
    struct Blueprint: Identifiable {
        let id: String
        let title: String
        let subtitle: String
        let icon: String
        let category: String
        let url: URL
        let phases: [String]
    }

    struct Phase {
        let number: Int
        let name: String
        let description: String
        let color: Color
    }

    static let blueprints: [Blueprint] = [
        Blueprint(
            id: "bb_master",
            title: "Bonds Bounce Blueprint",
            subtitle: "The master overview of the vertical jump architecture.",
            icon: "play.rectangle.fill",
            category: "Master",
            url: SafeURL.make("https://youtu.be/hrlGbS0r-hM"),
            phases: ["Overview", "Architecture", "Progression"]
        ),
        Blueprint(
            id: "bb_overview",
            title: "Bonds Bounce Overview",
            subtitle: "The original vertical jump architecture breakdown.",
            icon: "play.circle.fill",
            category: "Overview",
            url: SafeURL.make("https://youtu.be/dAoLYThf1bc"),
            phases: ["Foundations", "Mechanics", "Application"]
        ),
        Blueprint(
            id: "bb_bodyweight",
            title: "Bodyweight & Mobility",
            subtitle: "Full exercise list with timestamps for structural integrity.",
            icon: "figure.flexibility",
            category: "Mobility",
            url: SafeURL.make("https://youtu.be/q1HLjLbhS2s"),
            phases: ["Ankle Mobility", "Hip Extension", "Structural Balance"]
        ),
        Blueprint(
            id: "bb_plyo",
            title: "Plyometric Exercises",
            subtitle: "Comprehensive reactive power drills with timestamps.",
            icon: "figure.jumprope",
            category: "Power",
            url: SafeURL.make("https://youtu.be/pqyxTY85x4U"),
            phases: ["Reactive Strength", "Depth Jumps", "Bounding"]
        ),
        Blueprint(
            id: "bb_fitness",
            title: "Final Evolution Fitness",
            subtitle: "Master exercise list for the complete training system.",
            icon: "flame.fill",
            category: "Complete",
            url: SafeURL.make("https://youtu.be/J037GG99GT0"),
            phases: ["Strength", "Power", "Speed", "Recovery"]
        ),
    ]

    static let phases: [Phase] = [
        Phase(number: 1, name: "Foundations", description: "Build structural integrity. Ankle stiffness, hip mobility, and ground contact mastery.", color: .green),
        Phase(number: 2, name: "Load", description: "Absorb and redirect force. Eccentric strength and stiffness under load for better RFD.", color: Color(red: 0.3, green: 0.7, blue: 0.4)),
        Phase(number: 3, name: "Launch", description: "Translate load into takeoff. Short ground-contact, high ground reaction force.", color: Color(red: 0.2, green: 0.5, blue: 1.0)),
        Phase(number: 4, name: "Flight", description: "Unlock explosive vertical power through plyometric progressions and neural drive.", color: Color(red: 0.4, green: 0.6, blue: 1.0)),
        Phase(number: 5, name: "Elite", description: "Peak performance. Max-intent jumping, resisted sprints, and pro-level dunk sessions.", color: Color(red: 0.6, green: 0.2, blue: 1.0)),
        Phase(number: 6, name: "Lifelong Mover", description: "Maintain Flight through sustainable movement systems like FRC and GOATA.", color: Color(red: 0.95, green: 0.49, blue: 0.15)),
    ]
}
```

File: `Source/Models/BiomechanicsEducation.swift`

```swift
// MARK: - Rate of Force Development (RFD) & Ground Reaction Force (GRF) — User Education
// Pop Force in the app is a composite index reflecting RFD and GRF efficiency.

import Foundation
import SwiftUI

/// User-facing education content for key biomechanical concepts.
enum BiomechanicsEducation {

    // MARK: - Rate of Force Development (RFD)

    static let rfdTitle = "Rate of Force Development (RFD)"
    static let rfdShortDefinition = "How quickly you can produce force from a standstill or after ground contact."
    static let rfdFullExplanation = """
        Rate of Force Development (RFD) is how fast your muscles and tendons build force from the moment you start pushing into the ground until peak force. In jumping and sprinting, a higher RFD means you reach peak force sooner, so you leave the ground faster and waste less time in contact.

        Why it matters:
        • Short ground-contact time (e.g. in pogos, bounds, sprints) demands high RFD.
        • Training with max-intent, low-rep efforts and reactive drills improves RFD.
        • Your Pop Force score in the Lab reflects how well your current movement uses RFD.
        """

    // MARK: - Ground Reaction Force (GRF)

    static let grfTitle = "Ground Reaction Force (GRF)"
    static let grfShortDefinition = "The force the ground exerts back on you when you push into it."
    static let grfFullExplanation = """
        Ground Reaction Force (GRF) is the force the ground pushes back on your body when you apply force into it. To jump higher or move faster, you want to maximize GRF in the right direction in a short time—so your body goes up (or forward) instead of wasting force sideways or into the floor.

        Why it matters:
        • Stiff ankles and a strong kinetic chain help you transfer force into the ground efficiently, increasing effective GRF.
        • Leaks in the chain (e.g. knee cave, soft ankles) reduce how much of your effort becomes useful GRF.
        • The Lab’s biomechanics audit and Pop Force score help you find and fix those leaks.
        """

    // MARK: - Pop Force (App Metric)

    static let popForceTitle = "Pop Force"
    static let popForceShortDefinition = "Your elastic reactivity and ground-contact efficiency—the combination of RFD and GRF in your jump."
    static let popForceFullExplanation = """
        Pop Force is Final Evolution Lab’s composite score for how well you use Rate of Force Development (RFD) and Ground Reaction Force (GRF) when you jump. It reflects:

        • How quickly you build force after touch-down (RFD).
        • How efficiently you direct that force into the ground (GRF) so you get maximum height or distance.

        Improving ankle stiffness, hip extension timing, and reactive strength (e.g. pogos, depth jumps) raises your Pop Force and your in-game performance in the Arena.
        """

    /// Single concept for list/grid display.
    struct Concept: Identifiable {
        let id: String
        let title: String
        let shortDefinition: String
        let fullExplanation: String
        let iconName: String
        let color: Color

        static let rfd = Concept(
            id: "rfd",
            title: rfdTitle,
            shortDefinition: rfdShortDefinition,
            fullExplanation: rfdFullExplanation,
            iconName: "bolt.fill",
            color: .orange
        )
        static let grf = Concept(
            id: "grf",
            title: grfTitle,
            shortDefinition: grfShortDefinition,
            fullExplanation: grfFullExplanation,
            iconName: "arrow.down.to.line",
            color: Theme.brandBlue
        )
        static let popForce = Concept(
            id: "pop_force",
            title: popForceTitle,
            shortDefinition: popForceShortDefinition,
            fullExplanation: popForceFullExplanation,
            iconName: "flame.fill",
            color: Theme.brandCyan
        )
        static let all: [Concept] = [.rfd, .grf, .popForce]
    }
}
```

File: `Source/Utilities/PRQScoring.swift`

```swift
import Foundation

nonisolated enum PRQ: Sendable {
    static let min: Double = 0
    static let max: Double = 100
    static let `default`: Double = 75
    static let legendaryThreshold: Double = 95

    static func clamp(_ value: Double) -> Double {
        guard value.isFinite else { return `default` }
        return Swift.min(`max`, Swift.max(`min`, value))
    }

    static func fromVerticalInches(_ verticalInches: Double) -> Int {
        Int(round(FELPRQScanFormula.scoreFromVerticalInches(verticalInches)))
    }

    static func matchReward(won: Bool, tied: Bool) -> Double {
        if won { return 2.0 }
        if tied { return 0.5 }
        return 0.2
    }

    static func modeReward(mode: GameModeId, won: Bool, tied: Bool, combo: Int, criticals: Int, scoreDifferential: Int) -> Double {
        let base = matchReward(won: won, tied: tied)
        let modeMultiplier = modeWeight(for: mode)
        let comboBonus = Swift.min(1.0, Double(combo) * 0.05)
        let criticalBonus = Swift.min(0.5, Double(criticals) * 0.1)
        let dominanceBonus = won ? Swift.min(0.5, Double(Swift.max(0, scoreDifferential)) * 0.05) : 0
        let raw = base * modeMultiplier + comboBonus + criticalBonus + dominanceBonus
        let minimumParticipation: Double = 0.1
        return clamp(Swift.max(minimumParticipation, raw))
    }

    static func modeWeight(for mode: GameModeId) -> Double {
        switch mode {
        case .basketballHeadToHead: 1.2
        case .basketballDunkContest: 1.0
        case .basketball3v3: 1.3
        case .karate: 1.4
        case .baseball: 1.0
        case .football: 1.5
        case .soccer: 1.1
        case .golf: 0.9
        case .tennis: 1.1
        case .volleyball: 1.2
        case .gymnastics: 1.0
        case .brainBrawl: 0.95
        }
    }

    /// Win chance per round: PRQ 50 ≈ 58–62%, 75 ≈ 72–76%, 90 ≈ 84–88% by mode. Floor and ceiling keep games fair.
    static func successChanceFromPRQ(_ prq: Double, for mode: GameModeId) -> Double {
        let safe = prq.isFinite ? prq : `default`
        let normalized = Swift.min(Swift.max(safe / 100.0, 0), 1)
        let (modeBase, ceiling): (Double, Double)
        switch mode {
        case .basketballHeadToHead, .basketball3v3: (modeBase, ceiling) = (0.34, 0.88)
        case .basketballDunkContest: (modeBase, ceiling) = (0.36, 0.90)
        case .karate: (modeBase, ceiling) = (0.30, 0.86)
        case .baseball: (modeBase, ceiling) = (0.28, 0.84)
        case .football: (modeBase, ceiling) = (0.32, 0.88)
        case .soccer: (modeBase, ceiling) = (0.32, 0.86)
        case .golf: (modeBase, ceiling) = (0.26, 0.82)
        case .tennis: (modeBase, ceiling) = (0.32, 0.86)
        case .volleyball: (modeBase, ceiling) = (0.34, 0.88)
        case .gymnastics: (modeBase, ceiling) = (0.28, 0.84)
        case .brainBrawl: (modeBase, ceiling) = (0.30, 0.86)
        }
        let raw = modeBase + normalized * (ceiling - modeBase)
        return Swift.min(Swift.max(raw, 0.18), 0.92)
    }

    static func attributeLabel(for mode: GameModeId) -> String {
        switch mode {
        case .basketballHeadToHead, .basketball3v3: "Court IQ"
        case .basketballDunkContest: "Hang Time"
        case .karate: "Fight IQ"
        case .baseball: "Bat Speed"
        case .football: "Burst Speed"
        case .soccer: "Shot Accuracy"
        case .golf: "Swing Precision"
        case .tennis: "Rally Control"
        case .volleyball: "Spike Power"
        case .gymnastics: "Form Score"
        case .brainBrawl: "Brain Speed"
        }
    }

    static func attributeValue(prq: Double, for mode: GameModeId) -> Double {
        let safe = prq.isFinite ? prq : `default`
        let normalized = Swift.min(Swift.max(safe / 100.0, 0), 1)
        let modeScale: Double
        switch mode {
        case .basketballHeadToHead, .basketball3v3: modeScale = 0.85
        case .basketballDunkContest: modeScale = 0.90
        case .karate: modeScale = 0.80
        case .baseball: modeScale = 0.75
        case .football: modeScale = 0.80
        case .soccer: modeScale = 0.78
        case .golf: modeScale = 0.70
        case .tennis: modeScale = 0.78
        case .volleyball: modeScale = 0.82
        case .gymnastics: modeScale = 0.75
        case .brainBrawl: modeScale = 0.78
        }
        return (modeScale * normalized * 100).rounded() / 100
    }
}
```

File: `Source/Models/GameMode.swift`

```swift
import SwiftUI

nonisolated enum GameModeId: String, Codable, Sendable, CaseIterable, Identifiable {
    case basketballHeadToHead = "basketball_h2h"
    case basketballDunkContest = "basketball_dunk"
    case basketball3v3 = "basketball_3v3"
    case karate = "karate"
    case baseball = "baseball"
    case football = "football"
    case soccer = "soccer"
    case golf = "golf"
    case tennis = "tennis"
    case volleyball = "volleyball"
    case gymnastics = "gymnastics"
    case brainBrawl = "brain_brawl"

    var id: String { rawValue }
}

nonisolated enum InputScheme: String, Sendable {
    case charge
    case swipe
    case swipeGolf
    case dragTap
    case kickReturn
    case rallyAce
    case penaltyKick
    case rhythmTap
}

extension GameModeId {
    var inputScheme: InputScheme {
        switch self {
        case .basketballHeadToHead, .basketballDunkContest, .basketball3v3, .karate:
            return .charge
        case .baseball:
            return .swipe
        case .golf:
            return .swipeGolf
        case .volleyball, .tennis:
            return .rallyAce
        case .football:
            return .kickReturn
        case .soccer:
            return .penaltyKick
        case .gymnastics:
            return .rhythmTap
        case .brainBrawl:
            return .rhythmTap
        }
    }

    /// Environment-specific copy and theming for Arena play (each mode built out in its venue).
    var environmentActionTitle: String {
        switch self {
        case .basketballHeadToHead, .basketball3v3: return "SHOOT!"
        case .basketballDunkContest: return "DUNK!"
        case .karate: return "STRIKE!"
        case .baseball: return "SWING!"
        case .football: return "RUN!"
        case .soccer: return "SHOOT!"
        case .golf: return "SWING!"
        case .tennis: return "RALLY!"
        case .volleyball: return "SPIKE!"
        case .gymnastics: return "STICK!"
        case .brainBrawl: return "ANSWER!"
        }
    }

    /// e.g. "Round", "Point", "Hole", "Question", "Bout", "At-bat", "Penalty"
    var environmentRoundLabel: String {
        switch self {
        case .basketballHeadToHead, .basketball3v3, .basketballDunkContest: return "Round"
        case .karate: return "Bout"
        case .baseball: return "At-bat"
        case .football: return "Drive"
        case .soccer: return "Penalty"
        case .golf: return "Hole"
        case .tennis, .volleyball: return "Point"
        case .gymnastics: return "Routine"
        case .brainBrawl: return "Question"
        }
    }

    /// Opponent label in play (e.g. "OPP", "CPU", "AI")
    var environmentOpponentLabel: String {
        switch self {
        case .karate: return "OPP"
        default: return "OPP"
        }
    }

    /// Number of rounds/points/holes etc. per match in Arena. Tuned per sport (e.g. first-to-3, best-of-5).
    var environmentRoundCount: Int {
        switch self {
        case .brainBrawl: return 5
        case .golf: return 3
        case .soccer: return 5
        case .tennis, .volleyball: return 5
        case .karate, .football: return 5
        default: return 3
        }
    }

    /// Secondary color for environment gradient (e.g. darker tint).
    var environmentSecondaryColor: Color {
        switch self {
        case .basketballHeadToHead, .basketballDunkContest, .basketball3v3: return Color(red: 0.1, green: 0.4, blue: 0.5)
        case .karate: return Color(red: 0.4, green: 0.05, blue: 0.05)
        case .baseball: return Color(red: 0.05, green: 0.25, blue: 0.45)
        case .football: return Color(red: 0.25, green: 0.15, blue: 0.05)
        case .soccer: return Color(red: 0.05, green: 0.4, blue: 0.15)
        case .golf: return Color(red: 0.1, green: 0.35, blue: 0.2)
        case .tennis: return Color(red: 0.4, green: 0.35, blue: 0.05)
        case .volleyball: return Color(red: 0.5, green: 0.35, blue: 0.05)
        case .gymnastics: return Color(red: 0.2, green: 0.15, blue: 0.5)
        case .brainBrawl: return Color(red: 0.3, green: 0.15, blue: 0.5)
        }
    }

    /// Short style tag for presentation (no third-party product names).
    var inspirationTag: String {
        switch self {
        case .basketballHeadToHead, .basketball3v3: return "Street hoops"
        case .basketballDunkContest: return "Dunk contest"
        case .karate: return "Point sparring"
        case .baseball, .golf: return "Arcade swing"
        case .football: return "Kick return"
        case .soccer: return "Penalty shootout"
        case .tennis, .volleyball: return "Beach rally"
        case .gymnastics: return "Routines & tumbling"
        case .brainBrawl: return "Curriculum quiz"
        }
    }

    /// One-line atmosphere for the play screen (e.g. "Sun, boards, and street rules.")
    var environmentAtmosphere: String {
        switch self {
        case .basketballHeadToHead: return "Sun, boards, and street rules."
        case .basketball3v3: return "Run the court. Three on three."
        case .basketballDunkContest: return "Sprint, gather, fly—face buttons for style."
        case .karate: return "Respect. Control. One clean point at a time."
        case .baseball: return "Clear the fences. Derby rules."
        case .football: return "One return. No second chances."
        case .soccer: return "You vs the keeper. Penalty pressure."
        case .golf: return "Closest to the pin. One swing per hole."
        case .tennis: return "Serve, rally, finish. Beach court intensity."
        case .volleyball: return "Sand, sun, and no mercy at the net."
        case .gymnastics: return "Stick the landing. Form is everything."
        case .brainBrawl: return "Your curriculum. AI opponent. First to answer wins."
        }
    }

    /// Short line for Get Ready screen (instructional). Arena = tap to commit, no timing bar; outcome from PRQ.
    var getReadySubtitle: String {
        switch self {
        case .basketballDunkContest: return "Sprint → Gather → Fly. Face buttons for finishers."
        case .basketballHeadToHead, .basketball3v3, .karate, .baseball, .football, .soccer, .golf, .tennis, .volleyball, .gymnastics:
            return "Press ✕ or tap to commit. Outcome from your PRQ."
        case .brainBrawl:
            return "Tap to lock your answer. First correct wins the question."
        }
    }

    /// Arena commit hint (no timing bar): one press = one commit.
    var arenaCommitHint: String {
        switch self {
        case .basketballDunkContest: return "Sprint → Gather → Fly. Face buttons for finishers."
        case .brainBrawl: return "Tap to lock answer. First correct wins."
        default: return "Press ✕ (Cross) or tap to commit. Outcome from PRQ (0.62–0.90)."
        }
    }

    /// Display name for the opponent in this environment (e.g. "Keeper", "Dojo Master").
    var opponentDisplayName: String {
        switch self {
        case .basketballHeadToHead, .basketball3v3: return "OPP"
        case .basketballDunkContest: return "JUDGES"
        case .karate: return "OPP"
        case .baseball: return "PITCHER"
        case .football: return "SPECIAL TEAMS"
        case .soccer: return "KEEPER"
        case .golf: return "FIELD"
        case .tennis: return "OPP"
        case .volleyball: return "NET"
        case .gymnastics: return "JUDGES"
        case .brainBrawl: return "OPP"
        }
    }

    /// Two- to three-sentence environment description for the play screen.
    var environmentDescription: String {
        switch self {
        case .basketballHeadToHead:
            return "Venice Beach half-court. One basket, one ball, first to score wins the round. Hand up to contest; your Court IQ drives the outcome."
        case .basketballDunkContest:
            return "The same iconic court, dunk contest rules. Sprint from the wing, hit the gather zone, then fly—face buttons pick your finisher. Hang Time is your edge."
        case .basketball3v3:
            return "Street rules, three on three. Every possession counts. Contest with hands up; Court IQ and timing decide who gets the bucket."
        case .karate:
            return "Point sparring in the dojo. One clean strike lands the bout. Control distance and timing; Fight IQ beats raw aggression."
        case .baseball:
            return "Home Run Derby at the stadium. You get one swing per at-bat. Clear the fence and you win the round; Bat Speed shapes your odds."
        case .football:
            return "Kick return, sudden death. One return—break it or get stopped. Burst Speed and vision; no second chances."
        case .soccer:
            return "Penalty shootout. You vs the keeper, one kick per round. Placement and composure; Shot Accuracy vs the save."
        case .golf:
            return "Closest to the pin. One swing per hole. Wind and lie are factored into your Swing Precision—get close to win the hole."
        case .tennis:
            return "Beach court rally. Serve, rally, put the point away. Rally Control and placement beat the opponent across the net."
        case .volleyball:
            return "Beach volleyball, rally scoring. Serve, receive, set, spike. Spike Power and timing through the block decide the point."
        case .gymnastics:
            return "Olympic-style routine. Execute, stick the landing. Form Score and consistency beat the judges."
        case .brainBrawl:
            return "Curriculum-based quiz vs AI. Same questions, first correct answer wins the question. Brain Speed and recall decide the round."
        }
    }

    /// In-round commit feedback (perfect / good / miss) — high-quality, sport-specific copy.
    var commitFeedbackPerfect: String {
        switch self {
        case .basketballHeadToHead, .basketball3v3: return "BUCKET!"
        case .basketballDunkContest: return "SLAM!"
        case .karate: return "STRIKE!"
        case .baseball: return "GONE!"
        case .football: return "HOUSE!"
        case .soccer: return "GOAL!"
        case .golf: return "TAP-IN!"
        case .tennis: return "ACE!"
        case .volleyball: return "KILL!"
        case .gymnastics: return "STUCK!"
        case .brainBrawl: return "CORRECT!"
        }
    }

    var commitFeedbackGood: String {
        switch self {
        case .basketballHeadToHead, .basketball3v3: return "GOOD"
        case .basketballDunkContest: return "NICE"
        case .karate: return "POINT"
        case .baseball: return "CONTACT"
        case .football: return "YARDS"
        case .soccer: return "ON TARGET"
        case .golf: return "GREEN"
        case .tennis: return "IN"
        case .volleyball: return "POINT"
        case .gymnastics: return "LANDED"
        case .brainBrawl: return "RIGHT"
        }
    }

    var commitFeedbackMiss: String {
        switch self {
        case .basketballHeadToHead, .basketball3v3: return "MISS"
        case .basketballDunkContest: return "OFF"
        case .karate: return "BLOCKED"
        case .baseball: return "OUT"
        case .football: return "STOPPED"
        case .soccer: return "SAVED"
        case .golf: return "WIDE"
        case .tennis: return "OUT"
        case .volleyball: return "BLOCKED"
        case .gymnastics: return "DEDUCT"
        case .brainBrawl: return "WRONG"
        }
    }

    /// Legacy: Arena uses no charge bar (tap to commit). Kept for any future mode that might use charge.
    var chargeBarTitle: String {
        switch self {
        case .basketballHeadToHead, .basketball3v3: return "PRESS ✕ TO SHOOT"
        case .basketballDunkContest: return "PRESS ✕ TO DUNK"
        case .karate: return "PRESS ✕ TO STRIKE"
        case .baseball: return "PRESS ✕ TO SWING"
        case .football: return "PRESS ✕ TO BREAK"
        case .soccer: return "PRESS ✕ TO SHOOT"
        case .golf: return "PRESS ✕ TO SWING"
        case .tennis: return "PRESS ✕ TO RALLY"
        case .volleyball: return "PRESS ✕ TO SPIKE"
        case .gymnastics: return "PRESS ✕ TO STICK"
        case .brainBrawl: return "TAP TO LOCK ANSWER"
        }
    }
}

nonisolated struct GameMode: Sendable, Identifiable, Hashable {
    let id: GameModeId
    let name: String
    let subtitle: String
    let sport: SportCategory
    let iconName: String
    let accentColor: Color
    let multiplayerType: MultiplayerType
    let environmentName: String
    let hint: String?

    nonisolated static func == (lhs: GameMode, rhs: GameMode) -> Bool { lhs.id == rhs.id }
    nonisolated func hash(into hasher: inout Hasher) { hasher.combine(id) }

    nonisolated enum SportCategory: String, Sendable {
        case basketball = "Basketball"
        case combat = "Combat Sports"
        case field = "Field Sports"
        case precision = "Precision"
    }

    nonisolated enum MultiplayerType: String, Sendable {
        case realtime
        case turnBased
        case solo
    }
}

struct GameModeRegistry {
    static let all: [GameMode] = [
        GameMode(
            id: .basketballHeadToHead,
            name: "Head to Head",
            subtitle: "1v1 Shootout",
            sport: .basketball,
            iconName: "figure.basketball",
            accentColor: Color(red: 1.0, green: 0.6, blue: 0.0),
            multiplayerType: .realtime,
            environmentName: "Venice Beach Court",
            hint: "Hands up = contest shot • Right stick = defender distance"
        ),
        GameMode(
            id: .basketballDunkContest,
            name: "Dunk Contest",
            subtitle: "Venice Beach Showdown",
            sport: .basketball,
            iconName: "figure.highintensity.intervaltraining",
            accentColor: Color(red: 0, green: 0.83, blue: 1.0),
            multiplayerType: .realtime,
            environmentName: "Venice Beach Court",
            hint: "Sprint → Gather → Fly → Face buttons for style"
        ),
        GameMode(
            id: .basketball3v3,
            name: "3v3 Streetball",
            subtitle: "Run the Court",
            sport: .basketball,
            iconName: "person.3.fill",
            accentColor: Color(red: 0.2, green: 0.8, blue: 0.4),
            multiplayerType: .realtime,
            environmentName: "Venice Beach Court",
            hint: "Hands up = contest • Right stick = defender distance"
        ),
        GameMode(
            id: .karate,
            name: "Karate",
            subtitle: "Point Sparring",
            sport: .combat,
            iconName: "figure.martial.arts",
            accentColor: Color(red: 1.0, green: 0.2, blue: 0.2),
            multiplayerType: .realtime,
            environmentName: "Dojo Arena",
            hint: "Stick combos for style • Block with right stick"
        ),
        GameMode(
            id: .baseball,
            name: "Home Run Derby",
            subtitle: "Wii-Style Swing",
            sport: .field,
            iconName: "figure.baseball",
            accentColor: Color(red: 0.1, green: 0.5, blue: 0.9),
            multiplayerType: .turnBased,
            environmentName: "Stadium Diamond",
            hint: "Home Run Derby • Swipe or tap"
        ),
        GameMode(
            id: .football,
            name: "Kick Return",
            subtitle: "Sudden Death Breakaway",
            sport: .field,
            iconName: "football.fill",
            accentColor: Color(red: 0.5, green: 0.3, blue: 0.1),
            multiplayerType: .turnBased,
            environmentName: "Stadium Field",
            hint: "Kick Return Sudden Death"
        ),
        GameMode(
            id: .soccer,
            name: "Penalty Shootout",
            subtitle: "Swipe to Score",
            sport: .field,
            iconName: "soccerball",
            accentColor: Color(red: 0.2, green: 0.7, blue: 0.3),
            multiplayerType: .realtime,
            environmentName: "Stadium Pitch",
            hint: "Penalty Shootout • Swipe to shoot"
        ),
        GameMode(
            id: .golf,
            name: "Closest to Pin",
            subtitle: "Wii-Style Swing",
            sport: .precision,
            iconName: "figure.golf",
            accentColor: Color(red: 0.3, green: 0.7, blue: 0.4),
            multiplayerType: .turnBased,
            environmentName: "Golf Green",
            hint: "Closest to the Pin • Wii-style swipe"
        ),
        GameMode(
            id: .tennis,
            name: "Rally Ace",
            subtitle: "Serve & Volley Showdown",
            sport: .precision,
            iconName: "tennis.racket",
            accentColor: Color(red: 0.85, green: 0.75, blue: 0.1),
            multiplayerType: .realtime,
            environmentName: "Venice Beach Court",
            hint: "Serve, Forehand, Backhand • Aim with drag"
        ),
        GameMode(
            id: .volleyball,
            name: "Rally Ace",
            subtitle: "Drag to Aim, Spike to Win",
            sport: .field,
            iconName: "volleyball.fill",
            accentColor: Color(red: 0.98, green: 0.75, blue: 0.14),
            multiplayerType: .realtime,
            environmentName: "Beach Court",
            hint: "Rally Ace • Drag to aim"
        ),
        GameMode(
            id: .gymnastics,
            name: "Gymnastics",
            subtitle: "Olympic Routines & Tumbling",
            sport: .precision,
            iconName: "figure.gymnastics",
            accentColor: Color(red: 0.39, green: 0.4, blue: 0.95),
            multiplayerType: .turnBased,
            environmentName: "Arena",
            hint: "Tumble, Vault, Dismount • Time for bonus"
        ),
        GameMode(
            id: .brainBrawl,
            name: "Brain Brawl",
            subtitle: "Curriculum Quiz vs AI",
            sport: .precision,
            iconName: "brain.head.profile",
            accentColor: Color(red: 0.6, green: 0.35, blue: 0.9),
            multiplayerType: .turnBased,
            environmentName: "Arena",
            hint: "Answer curriculum questions vs AI. Your path, your quiz."
        ),
    ]

    static func mode(for id: GameModeId) -> GameMode {
        all.first(where: { $0.id == id }) ?? all[0]
    }

    static var sportCategories: [GameMode.SportCategory] {
        [.basketball, .combat, .field, .precision]
    }

    static func modes(for sport: GameMode.SportCategory) -> [GameMode] {
        all.filter { $0.sport == sport }
    }

    // MARK: - Arena Venues (built-out arenas; modes grouped by environment)

    struct ArenaVenue: Sendable, Identifiable {
        let id: String
        let name: String
        let tagline: String
        let iconName: String
        let accentColor: Color
        /// Matches GameMode.environmentName for grouping
        let environmentName: String
        /// One-line atmosphere (e.g. "Sun and street rules.")
        var atmosphere: String { venueAtmosphere }
        /// Extended description for venue card or detail.
        var longDescription: String { venueLongDescription }

        private var venueAtmosphere: String {
            switch id {
            case "venice_beach": return "Sun, boards, and the Pacific breeze."
            case "dojo": return "Tatami, respect, one point at a time."
            case "stadium_diamond": return "Fences, crowd, and the long ball."
            case "stadium_field": return "Kick coverage and open grass."
            case "stadium_pitch": return "Twelve yards. You and the keeper."
            case "golf_green": return "Green, wind, and one clean swing."
            case "beach_court": return "Sand, sun, and no mercy at the net."
            case "arena": return "Routines, questions, and the podium."
            default: return "Compete. Adapt. Evolve."
            }
        }

        private var venueLongDescription: String {
            switch id {
            case "venice_beach":
                return "Outdoor courts by the Pacific. Half-court head-to-head, 3v3 runs, and the legendary dunk contest. Chain nets, concrete, and street rules. Your Court IQ and Hang Time drive every possession."
            case "dojo":
                return "Traditional dojo for point sparring. Controlled contact, clean strikes, and respect. Distance and timing beat raw power. Fight IQ decides each bout."
            case "stadium_diamond":
                return "Pro stadium diamond. Home Run Derby rules: one swing per at-bat. Clear the fence to win the round. Bat Speed and timing against the pitcher."
            case "stadium_field":
                return "Full stadium field for kick return. Sudden death—one return. Special teams vs your burst. Break it for the win; get stopped and it’s over. Burst Speed is everything."
            case "stadium_pitch":
                return "Penalty shootout at the pitch. You vs the keeper, one kick per round. Placement and composure under pressure. Shot Accuracy decides who blinks first."
            case "golf_green":
                return "Par-3 style closest-to-the-pin. One swing per hole. Wind and lie factor into your result. Swing Precision and calm win the hole."
            case "beach_court":
                return "Beach volleyball court. Rally scoring, sun, and sand. Serve, receive, set, spike. Spike Power and timing through the block decide every point."
            case "arena":
                return "Academy Arena hosts gymnastics routines and Brain Brawl. Stick the landing for Form Score; outthink the AI for Brain Speed. One routine or one question at a time."
            default:
                return "Compete in this arena. Your readiness and skill decide the outcome."
            }
        }
    }

    static let arenaVenues: [ArenaVenue] = [
        ArenaVenue(id: "venice_beach", name: "Venice Beach Court", tagline: "Outdoor hoops & beach tennis", iconName: "sportscourt.fill", accentColor: Color(red: 0, green: 0.83, blue: 1.0), environmentName: "Venice Beach Court"),
        ArenaVenue(id: "dojo", name: "Dojo Arena", tagline: "Point sparring & combat", iconName: "figure.martial.arts", accentColor: Color(red: 1.0, green: 0.2, blue: 0.2), environmentName: "Dojo Arena"),
        ArenaVenue(id: "stadium_diamond", name: "Stadium Diamond", tagline: "Home run derby", iconName: "figure.baseball", accentColor: Color(red: 0.1, green: 0.5, blue: 0.9), environmentName: "Stadium Diamond"),
        ArenaVenue(id: "stadium_field", name: "Stadium Field", tagline: "Kick return sudden death", iconName: "football.fill", accentColor: Color(red: 0.5, green: 0.3, blue: 0.1), environmentName: "Stadium Field"),
        ArenaVenue(id: "stadium_pitch", name: "Stadium Pitch", tagline: "Penalty shootout", iconName: "soccerball", accentColor: Color(red: 0.2, green: 0.7, blue: 0.3), environmentName: "Stadium Pitch"),
        ArenaVenue(id: "golf_green", name: "Golf Green", tagline: "Closest to the pin", iconName: "figure.golf", accentColor: Color(red: 0.3, green: 0.7, blue: 0.4), environmentName: "Golf Green"),
        ArenaVenue(id: "beach_court", name: "Beach Court", tagline: "Rally ace volleyball", iconName: "volleyball.fill", accentColor: Color(red: 0.98, green: 0.75, blue: 0.14), environmentName: "Beach Court"),
        ArenaVenue(id: "arena", name: "Academy Arena", tagline: "Gymnastics & Brain Brawl", iconName: "figure.gymnastics", accentColor: Color(red: 0.5, green: 0.4, blue: 0.95), environmentName: "Arena"),
    ]

    static func modes(for venue: ArenaVenue) -> [GameMode] {
        all.filter { $0.environmentName == venue.environmentName }
    }
}
```

File: `Source/PRQManager.swift`

```swift
import Foundation
import Observation

// MARK: - Neuro-Mechanic readiness export (Swift → Unreal `readiness_snapshot.json`)

nonisolated let felReadinessExportDidUpdateNotification = Notification.Name("FelReadinessExportDidUpdate")
/// FEL_NON_SHIPPING: posted after each `sync` when twin scales are recomputed (DA smoke overlay).
nonisolated let felReadinessTwinScalesUpdatedNotification = Notification.Name("FelReadinessTwinScalesUpdated")

// MARK: - Cloud Cortex (Google AI Studio / Gemini)

/// One row of PRQ history used for Bonds Apex / dunk-lane Cloud Cortex prompts.
nonisolated struct BondsApexJumpRow: Sendable {
    let dateISO8601: String
    let prqBonus: Double
    let neuroPerformance: Double?
    let gameModeId: String
}

/// Snapshot of athlete metrics + recent dunk-lane jumps for `fetchAICoachInsight`.
nonisolated struct PerformanceSnapshot: Sendable {
    let prqScore: Double
    let readinessScore: Double
    let efficiencyScore: Double
    let verticalPotential: Double
    let neuralDrive: Double
    let fatigueState: String
    let allTimePeakZCmS: Double?
    let bondsApexJumps: [BondsApexJumpRow]
    /// `false` = SFMA multi-segmental rotation screen fail — prescribe Mod 4 + 90/90 seated rotation.
    let sfmaMultiSegmentalRotationPassed: Bool?
}

extension PerformanceSnapshot {
    @MainActor
    static func make(from viewModel: LabViewModel) -> PerformanceSnapshot {
        let m = viewModel.effectiveMetrics
        let coach = FELCoachPerformanceSnapshot.decodedPayload()
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]

        let rows: [BondsApexJumpRow] = viewModel.prqHistoryEntries
            .filter { row in
                guard let gid = row.gameModeId?.lowercased() else { return false }
                return gid.contains("dunk") || gid.contains("basketball_dunk")
            }
            .sorted { $0.date > $1.date }
            .prefix(10)
            .map { row in
                BondsApexJumpRow(
                    dateISO8601: iso.string(from: row.date),
                    prqBonus: row.prqBonus,
                    neuroPerformance: row.neuroPerformance,
                    gameModeId: row.gameModeId ?? ""
                )
            }

        return PerformanceSnapshot(
            prqScore: m.prqScore,
            readinessScore: m.readinessScore,
            efficiencyScore: m.efficiencyScore,
            verticalPotential: m.verticalPotential,
            neuralDrive: m.neuralDrive,
            fatigueState: coach?.fatigueState ?? "Unknown",
            allTimePeakZCmS: coach?.allTimePeakZ,
            bondsApexJumps: Array(rows),
            sfmaMultiSegmentalRotationPassed: viewModel.profile.systemScan?.sfmaMultiSegmentalRotationPassed
        )
    }
}

/// Pulls PRQ, scan vertical estimate, and biomechanics audit into a single payload for Arena + Unreal `FELReadinessIO::TryLoadSnapshot`.
@Observable
@MainActor
final class PRQManager {
    static let shared = PRQManager()

    /// Persisted arena handoff for `readiness_snapshot.json` → Unreal `active_mode` (`FELReadinessIO.cpp`).
    static let lastExportedArenaModeKey = "felLastExportedArenaMode"

    /// Set in `ArenaView.performLuminanceCheck()` — when `false`, Unreal readiness JSON is not written (forensic scan needs adequate light).
    static let neuroMechanicLightingOptimalKey = "felNeuroMechanicLightingOptimal"

    /// First scan → Unreal twin-birth cinematic (`playTwinBirthCinematicOnce` in readiness JSON).
    static let pendingTwinBirthCinematicKey = "felPendingTwinBirthCinematic"
    /// First Lab tab visit → welcome toast on `AFELVaultHologramTerminalActor` + shard grant (consumed on export).
    static let pendingLabWelcomeToastKey = "felPendingLabWelcomeToast"

    private(set) var lastExport: FelReadinessSnapshotExport?
    private(set) var lastJSONString: String?
    private(set) var lastExportURL: URL?

    /// Google AI Studio (Gemini) — latest Neuro-Mechanic prescription line for Lab **Cloud Cortex** card.
    private(set) var cloudCortexPrescription: String?
    private(set) var cloudCortexLastUpdated: Date?
    private(set) var cloudCortexIsLoading: Bool = false
    private(set) var cloudCortexError: String?

#if FEL_NON_SHIPPING
    /// Last `avatarHeightScale` / `avatarWeightScale` from the readiness payload (computed every `sync`; matches JSON when write succeeds).
    private(set) var lastReadinessTwinScales: (height: Double, weight: Double)?
#endif

    private let userDefaultsKey = "fel_readiness_snapshot_json_cache"

    /// Weak link so `felUnrealSessionResultsReady` can call `sync(from:)` with full biomechanics audit after Vault merge.
    private weak var sessionBridgeLab: LabViewModel?
    private var felUnrealSessionResultsToken: NSObjectProtocol?

    private init() {
        registerFelUnrealSessionResultsObserver()
    }

    /// Call once from `LabViewModel` so session-result notifications refresh readiness + heat-map data with the live audit.
    func attachSessionBridge(_ vm: LabViewModel) {
        sessionBridgeLab = vm
    }

    private func registerFelUnrealSessionResultsObserver() {
        felUnrealSessionResultsToken = NotificationCenter.default.addObserver(
            forName: .felUnrealSessionResultsReady,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                // Defer so `FELUnrealSessionImporter` can merge `session_results.json` into the Vault first.
                try? await Task.sleep(nanoseconds: 250_000_000)
                guard let self else { return }
                self.refreshReadinessExportAfterUnrealSessionArtifact()
            }
        }
    }

    /// Re-writes `readiness_snapshot.json` from disk profile (no live `LabViewModel`) — cold-path fallback.
    func refreshReadinessFromSavedProfile() {
        let profile = SaveSystem.loadProfile()
        sync(profile: profile, audit: nil, metrics: profile.metrics)
    }

    private func refreshReadinessExportAfterUnrealSessionArtifact() {
        if let vm = sessionBridgeLab {
            sync(from: vm)
        } else {
            refreshReadinessFromSavedProfile()
        }
    }

    /// Sync from live profile + effective metrics (call after scan, profile load, or Arena appear).
    func sync(from viewModel: LabViewModel) {
        sync(
            profile: viewModel.profile,
            audit: viewModel.biomechanicsAudit,
            metrics: viewModel.effectiveMetrics
        )
    }

    /// Pushes `allTimePeakZ` + `displayName` to the Sovereign global leaderboard (Supabase or webhook when configured in Info.plist).
    func syncTopPerformance() async -> Int? {
        let profile = sessionBridgeLab?.profile ?? SaveSystem.loadProfile()
        let coach = FELCoachPerformanceSnapshot.decodedPayload()
        let peak = coach?.allTimePeakZ ?? 0
        return await FELSovereignLeaderboardSync.push(
            displayName: profile.displayName,
            allTimePeakZ: peak,
            athleteId: profile.id
        )
    }

    /// Sovereign Launch: pulls `user_balances` from Supabase and merges shard balance, Cloud Cortex credits, and optional gear paths into the active profile.
    func syncWallet() async {
        let profile = sessionBridgeLab?.profile ?? SaveSystem.loadProfile()
        guard let state = await FELSupabaseWalletSync.shared.authState() else { return }
        guard let snap = await FELSovereignShardEconomy.syncWallet(userId: state.userId, accessToken: state.accessToken) else { return }
        var merged = profile
        merged.supabaseUserId = state.userId.uuidString.lowercased()
        merged.evolutionShards = snap.shardBalance
        merged.credits = snap.cloudCortexCredits
        for (k, v) in snap.equippedGearTexturePaths where !v.isEmpty {
            merged.equippedGearTexturePaths[k] = v
        }
        SaveSystem.saveProfile(merged)
        sessionBridgeLab?.profile = merged
        NotificationCenter.default.post(name: .felWalletBalanceDidUpdate, object: nil)
    }

    /// Cloud Cortex: sends the last 10 Bonds Apex–lane jumps + `FatigueState` / Peak Z to Gemini; stores a one-line Neuro-Mechanic prescription.
    func fetchAICoachInsight(metrics: PerformanceSnapshot) async {
        cloudCortexIsLoading = true
        cloudCortexError = nil
        defer { cloudCortexIsLoading = false }

        guard GeminiService.shared.isConfigured else {
            cloudCortexError = GeminiError.missingAPIKey.localizedDescription
            return
        }
        guard let apiKey = GeminiService.shared.apiKey, !apiKey.isEmpty else {
            cloudCortexError = GeminiError.missingAPIKey.localizedDescription
            return
        }

        let snapshot = metrics
        do {
            // Prompt build + REST run entirely off MainActor — 3D HUD / Lab scroll never blocks on Gemini RTT.
            let raw = try await Task.detached(priority: .userInitiated) {
                let prompt = Self.buildCloudCortexPrompt(metrics: snapshot)
                return try await GeminiService.generateContentREST(prompt: prompt, apiKey: apiKey)
            }.value
            let line = Self.extractNeuroMechanicPrescription(from: raw)
            cloudCortexPrescription = line
            cloudCortexLastUpdated = Date()
        } catch {
            cloudCortexError = error.localizedDescription
        }
    }

    func sync(profile: UserProfile, audit: BiomechanicsAudit?, metrics: PerformanceMetrics) {
        let export = Self.buildExport(profile: profile, audit: audit, metrics: metrics)
#if FEL_NON_SHIPPING
        lastReadinessTwinScales = (export.avatarHeightScale, export.avatarWeightScale)
        NotificationCenter.default.post(name: felReadinessTwinScalesUpdatedNotification, object: nil)
#endif
        writeExport(export)
    }

    private static func buildExport(profile: UserProfile, audit: BiomechanicsAudit?, metrics: PerformanceMetrics) -> FelReadinessSnapshotExport {
        let scan = profile.systemScan
        let baseLeakage = Self.kineticLeakageMultiplier(audit: audit)
        let sovereignLeak = FELGearBoostCalculator.sovereignKineticLeakageScale(profile: profile)
        let leakage = max(0.45, min(1.0, baseLeakage * sovereignLeak))
        let hang = Self.hangTimeScale(scan: scan, prq: metrics.prqScore)
        let heats = Self.kineticJointHeats(audit: audit)
        let gear = FELGearBoostCalculator.aggregatedMultipliers(profile: profile)
        let neuroScale = FELGearBoostCalculator.neuroFlowIntensityScale(activeCard: profile.activeCreatorCard)
        let traitLine = FELGearBoostCalculator.stoodTraitLine(for: profile.activeCreatorCard)
        let stoodPhysics = FELGearBoostCalculator.stoodCardPhysics(from: profile.activeCreatorCard)
        let stoodTier = FELGearBoostCalculator.stoodCardTierString(for: profile.activeCreatorCard)
        let signatureTraitId = FELGearBoostCalculator.signatureTraitId(for: profile.activeCreatorCard)
        let rawMode = UserDefaults.standard.string(forKey: Self.lastExportedArenaModeKey)
            ?? GameModeId.basketballHeadToHead.rawValue
        let activeMode = Self.normalizeActiveModeForUnreal(rawMode)
        let avatar = profile.effectiveAvatarConfig

        return FelReadinessSnapshotExport(
            efficiencyScore: metrics.efficiencyScore,
            prqScore: metrics.prqScore,
            readinessScore: metrics.readinessScore,
            verticalPotential: metrics.verticalPotential,
            neuralDrive: metrics.neuralDrive,
            popForce: metrics.popForce,
            currentOutfit: metrics.currentOutfit,
            verticalEstimateInches: scan?.verticalEstimateInches ?? Double(metrics.verticalPotential) * 0.28,
            hangTimeScale: hang,
            kineticLeakageMultiplier: leakage,
            movementGrade: scan?.movementGrade,
            flightTimeSeconds: scan?.flightTimeSeconds,
            isPrimed: audit?.isPrimed,
            ankleKineticHeat: heats.ankle,
            kneeKineticHeat: heats.knee,
            hipKineticHeat: heats.hip,
            academyPlyosMasteryBonus: profile.completedAcademyModuleIds.contains("mod9") ? 0.02 : nil,
            videoNominalFrameRateHz: scan?.videoNominalFrameRateHz,
            jerseyTexturePath: profile.equippedGearTexturePaths["jersey"],
            shoeTexturePath: profile.equippedGearTexturePaths["shoes"],
            gearMotionWarpMultiplier: gear.motionWarp,
            gearJumpVelocityMultiplier: gear.jumpVelocity,
            stoodCreatorCardId: profile.activeCreatorCard?.cardId,
            neuroFlowIntensityScale: neuroScale,
            stoodCreatorCardTraitLine: traitLine.isEmpty ? nil : traitLine,
            stoodCardJumpScale: stoodPhysics.jump,
            stoodCardNeuralDriveAlpha: stoodPhysics.neuralAlpha,
            stoodCardTier: stoodTier,
            signatureTraitId: signatureTraitId,
            activeMode: activeMode,
            creatorCardTextures: nil,
            neuroMechanicLogoTexture: nil,
            bondsBounceLogoTexture: nil,
            avatarHeightScale: avatar.heightScale,
            avatarWeightScale: avatar.weightScale,
            sfmaMultiSegmentalRotationPassed: scan?.sfmaMultiSegmentalRotationPassed
        )
    }

    /// Multi-athlete / coach handoff: clears local `readiness_snapshot.json` cache, reapplies the profile, re-syncs twin scales (FEL_NON_SHIPPING HUD), and requests an Unreal `setUnrealReady` pulse via `felUnrealReadinessHandshakeRequested`.
    func switchAthleteProfile(newProfile: UserProfile) {
        clearLocalReadinessSnapshotArtifacts()
        if let vm = sessionBridgeLab {
            vm.profile = newProfile
            if let scan = newProfile.systemScan {
                vm.biomechanicsAudit = BiomechanicsAudit.fromScanResult(scan)
            } else {
                vm.biomechanicsAudit = nil
            }
            SaveSystem.saveProfile(newProfile)
            sync(from: vm)
        } else {
            SaveSystem.saveProfile(newProfile)
            let audit = newProfile.systemScan.map { BiomechanicsAudit.fromScanResult($0) }
            sync(profile: newProfile, audit: audit, metrics: newProfile.metrics)
        }
        NotificationCenter.default.post(
            name: .felUnrealReadinessHandshakeRequested,
            object: nil,
            userInfo: ["athleteId": newProfile.id, "athleteDisplayName": newProfile.displayName]
        )
    }

    /// Season / scout export: PRQ history rows + biometric scales from last readiness export + coach performance snapshot (Peak Z proxy, fatigue) — CSV for recruiters (`ScoutsPortalView`).
    func exportSeasonStatsCSV() -> String {
        let profile = sessionBridgeLab?.profile ?? SaveSystem.loadProfile()
        let history = sessionBridgeLab?.prqHistoryEntries ?? SaveSystem.loadPRQHistory()
        let coach = FELCoachPerformanceSnapshot.decodedPayload()
        let scales = lastExport
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]

        var lines: [String] = []
        lines.append("# Final Evolution — Performance Report (1.0.0)")
        lines.append("# Generated: \(iso.string(from: Date()))")
        lines.append("section,metric,value")
        lines.append("profile,id,\(Self.csvEscape(profile.id))")
        lines.append("profile,displayName,\(Self.csvEscape(profile.displayName))")
        lines.append("profile,athleteTag,\(Self.csvEscape(profile.athleteTag))")
        lines.append("profile,prqScore,\(String(format: "%.4f", profile.metrics.prqScore))")
        lines.append("profile,verticalPotential,\(String(format: "%.4f", profile.metrics.verticalPotential))")
        if let s = scales {
            lines.append("biometric,avatarHeightScale,\(String(format: "%.6f", s.avatarHeightScale))")
            lines.append("biometric,avatarWeightScale,\(String(format: "%.6f", s.avatarWeightScale))")
        } else {
            lines.append("biometric,avatarHeightScale,")
            lines.append("biometric,avatarWeightScale,")
        }
        lines.append("performanceHistory,peakZ_cm_s_max,\(coach?.allTimePeakZ.map { String(format: "%.4f", $0) } ?? "")")
        lines.append("performanceHistory,fatigueState,\(Self.csvEscape(coach?.fatigueState ?? "Unknown"))")
        lines.append("performanceHistory,jumpHeight_proxy_note,PeakZ_velocity_cm_s_from_Unreal_save_coach_JSON")
        lines.append("gear,gearId,\(Self.csvEscape(coach?.gearId ?? ""))")

        lines.append("prq_history_id,date_iso,source,prqBonus,mentalSharpness,neuroPerformance,gameModeId")
        for row in history.sorted(by: { $0.date < $1.date }) {
            let d = iso.string(from: row.date)
            lines.append([
                Self.csvEscape(row.id),
                Self.csvEscape(d),
                Self.csvEscape(row.source),
                String(format: "%.6f", row.prqBonus),
                row.mentalSharpness.map { String(format: "%.6f", $0) } ?? "",
                row.neuroPerformance.map { String(format: "%.6f", $0) } ?? "",
                Self.csvEscape(row.gameModeId ?? "")
            ].joined(separator: ","))
        }

        let bonuses = history.map(\.prqBonus)
        let avgBonus = bonuses.isEmpty ? 0.0 : bonuses.reduce(0, +) / Double(bonuses.count)
        lines.append("aggregate,prq_history_count,\(history.count)")
        lines.append("aggregate,avg_prqBonus,\(String(format: "%.6f", avgBonus))")
        return lines.joined(separator: "\n")
    }

    private static func csvEscape(_ s: String) -> String {
        if s.contains(",") || s.contains("\"") || s.contains("\n") {
            let doubled = s.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(doubled)\""
        }
        return s
    }

    private func clearLocalReadinessSnapshotArtifacts() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        lastExport = nil
        lastJSONString = nil
        lastExportURL = nil
#if FEL_NON_SHIPPING
        lastReadinessTwinScales = nil
        NotificationCenter.default.post(name: felReadinessTwinScalesUpdatedNotification, object: nil)
#endif
        if let url = try? Self.ensureFELDocumentsURL().appendingPathComponent("readiness_snapshot.json") {
            try? FileManager.default.removeItem(at: url)
        }
    }

    private func writeExport(_ export: FelReadinessSnapshotExport) {
        if let optimal = UserDefaults.standard.object(forKey: Self.neuroMechanicLightingOptimalKey) as? Bool, optimal == false {
            #if DEBUG
            print("[FEL] Skipping readiness_snapshot.json — lighting below forensic threshold (Arena System Scan needs brighter ambient light).")
            #endif
            return
        }

        var merged = export
        let d = UserDefaults.standard
        if d.bool(forKey: Self.pendingTwinBirthCinematicKey) {
            merged.playTwinBirthCinematicOnce = true
            d.set(false, forKey: Self.pendingTwinBirthCinematicKey)
        }
        if let toast = d.string(forKey: Self.pendingLabWelcomeToastKey), !toast.isEmpty {
            merged.labWelcomeToast = toast
            d.removeObject(forKey: Self.pendingLabWelcomeToastKey)
        }

        lastExport = merged
        guard let data = try? JSONEncoder.felPretty.encode(merged),
              let json = String(data: data, encoding: .utf8) else { return }

        lastJSONString = json
        UserDefaults.standard.set(json, forKey: userDefaultsKey)

        if let url = try? Self.ensureFELDocumentsURL().appendingPathComponent("readiness_snapshot.json") {
            try? json.write(to: url, atomically: true, encoding: .utf8)
            try? FELBiometricFileProtection.applyCompleteProtection(to: url)
            lastExportURL = url
        }

        NotificationCenter.default.post(name: felReadinessExportDidUpdateNotification, object: nil, userInfo: ["json": json])
    }

    /// Joint status from scan audit: MODERATE / LEAKING reduce effective verticality vs PRIMED (`optimal`).
    /// Collapses legacy / marketing labels to canonical `GameModeId.rawValue` for `FELArenaModeFromIdString` (Unreal).
    private static func normalizeActiveModeForUnreal(_ raw: String) -> String {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch s {
        case "dunk_contest", "dunkcontest", "hang_time", "hangtime":
            return GameModeId.basketballDunkContest.rawValue
        case "basketball-h2h", "h2h", "head_to_head", "headtohead":
            return GameModeId.basketballHeadToHead.rawValue
        case "market_browse", "sovereign_shop", "shop":
            return "market_browse"
        default:
            return raw.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private static func kineticLeakageMultiplier(audit: BiomechanicsAudit?) -> Double {
        guard let a = audit else { return 1.0 }
        var m = 1.0
        for joint in [a.ankleDorsiflexion, a.kneeTracking, a.hipExtension] {
            switch joint.status {
            case .optimal: break
            case .moderate: m *= 0.94
            case .deficit: m *= 0.88
            }
        }
        return max(0.55, min(1.0, m))
    }

    private static func hangTimeScale(scan: SystemScanResult?, prq: Double) -> Double {
        let flight = scan?.flightTimeSeconds ?? 0.48
        let base = 0.78 + prq / 400.0 + flight * 0.14
        return min(1.15, max(0.75, base))
    }

    /// 0 = PRIMED (cool), 1 = LEAKING (hot) — matches Athlete Hub heat bars.
    private static func kineticJointHeats(audit: BiomechanicsAudit?) -> (ankle: Double, knee: Double, hip: Double) {
        guard let a = audit else { return (0.2, 0.2, 0.2) }
        func heat(_ status: JointStatus) -> Double {
            switch status {
            case .optimal: return 0.12
            case .moderate: return 0.48
            case .deficit: return 0.88
            }
        }
        return (heat(a.ankleDorsiflexion.status), heat(a.kneeTracking.status), heat(a.hipExtension.status))
    }

    private static func ensureFELDocumentsURL() throws -> URL {
        try FELDocumentsFolder.urlCreatingIfNeeded()
    }

    private nonisolated static func loadGeminiSystemInstructions() -> String {
        if let url = Bundle.main.url(forResource: "GEMINI_SYSTEM_INSTRUCTIONS", withExtension: "txt", subdirectory: "Config") {
            return (try? String(contentsOf: url)) ?? ""
        }
        if let url = Bundle.main.url(forResource: "GEMINI_SYSTEM_INSTRUCTIONS", withExtension: "txt") {
            return (try? String(contentsOf: url)) ?? ""
        }
        return ""
    }

    private nonisolated static func buildCloudCortexPrompt(metrics: PerformanceSnapshot) -> String {
        let systemBlock = loadGeminiSystemInstructions()
        let peakZ = metrics.allTimePeakZCmS.map { String(format: "%.2f", $0) } ?? "n/a"
        let jumpLines: String
        if metrics.bondsApexJumps.isEmpty {
            jumpLines = "(No dunk-lane PRQ history rows yet — still prescribe from fatigue + Peak Z.)"
        } else {
            jumpLines = metrics.bondsApexJumps.enumerated().map { i, j in
                let n = j.neuroPerformance.map { String(format: "%.4f", $0) } ?? "—"
                return "\(i + 1). \(j.dateISO8601) | prqBonus=\(String(format: "%.4f", j.prqBonus)) neuro=\(n) mode=\(j.gameModeId)"
            }.joined(separator: "\n")
        }
        let academyModuleIndex = """
        Vertical Velocity Academy (10-module forensic curriculum): mod1 Bio-Electric Freeway; mod2 Internal GPS (SFMA/FMS); mod3 The Piston (IAP — diaphragm & pelvic floor); mod4 Movement Snacks; mod5 Anatomy of the Sling (Spiral Line overlay); mod6 Clearing the Path (NMS — Isometric Split Stance Wall Push); mod7 Loaded Spring; mod8 Rhythmic Penultimate (Push 1,2); mod9 Elastic Engine (progressed/regressed → deep-tier plyos); mod10 Flight Blueprint (Continuous Hops 45–60s = extensive/regressed elasticity depth).
        Forensic alias: "Module 2: The Ankle Piston" = ankle dorsiflexion + elastic recoil mechanics (ankle stiffness / Jump Code block) — prescribe alongside mod3 Piston (IAP) when bracing or Peak Z loss suggests ankle limitation; use mod8 Push 1,2 context for penultimate timing.
        """
        let rulesReminder = """
        \(academyModuleIndex)
        Hard rules: If Peak Z drops >5% over the last 3 dunk-lane sessions vs prior trend, prescribe 48h CNS recovery. If Peak Z is stable but PRQ is low, prescribe Neuro-Priming drills. Use FatigueState with Peak Z to infer CNS burnout risk.
        """
        let sfmaRotationBlock: String
        if metrics.sfmaMultiSegmentalRotationPassed == false {
            sfmaRotationBlock = """
        SFMA MULTI-SEGMENTAL ROTATION SCREEN: FAILED (forensic flag).
        Vertical Velocity Academy (10-module launch): you MUST explicitly prescribe Module 6 — NMS Correctives (Clearing the Path), and the Isometric Split Stance Wall Push as the primary neuromuscular corrective before high-intensity plyometrics or dunk-lane volume. Reference Spiral Line / rotation-chain context from Module 5 when explaining why.
        """
        } else {
            sfmaRotationBlock = """
        SFMA multi-segmental rotation: not flagged as failed (or not yet screened) — tie prescriptions to modules mod1–mod10 only when metrics support (Peak Z, PRQ, fatigue).
        """
        }
        return """
        === SYSTEM INSTRUCTIONS (Neuro-Mechanic / CONFIG) ===
        \(systemBlock.isEmpty ? "(Embedded CONFIG/GEMINI_SYSTEM_INSTRUCTIONS not bundled — follow rules below.)" : systemBlock)

        \(rulesReminder)

        \(sfmaRotationBlock)

        === CURRENT ATHLETE METRICS ===
        - PRQ: \(String(format: "%.2f", metrics.prqScore))
        - Readiness: \(String(format: "%.2f", metrics.readinessScore))
        - Efficiency: \(String(format: "%.2f", metrics.efficiencyScore))
        - Vertical potential: \(String(format: "%.2f", metrics.verticalPotential))
        - Neural drive: \(String(format: "%.2f", metrics.neuralDrive))
        - FatigueState (from Unreal coach JSON): \(metrics.fatigueState)
        - All-time Peak Z proxy (cm/s): \(peakZ)

        Last up to 10 Bonds Apex / dunk-lane jumps (PRQ history):
        \(jumpLines)

        Output exactly ONE line: Neuro-Mechanic Prescription — strictly fewer than 200 characters (UI cap). No markdown, no quotes, no bullets.
        """
    }

    private nonisolated static func extractNeuroMechanicPrescription(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let firstLine = trimmed.split(separator: "\n", omittingEmptySubsequences: false)
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .first(where: { !$0.isEmpty }) ?? trimmed
        let noBold = firstLine.replacingOccurrences(of: "**", with: "")
        return String(noBold.prefix(199))
    }
}

// MARK: - JSON shape (keys match `FELReadinessIO::ParseSnapshotJsonString` — `active_mode` is explicit).
// Security: metrics-only payload — no API keys, tokens, or DeepMotion credentials (those stay in process env / CI secrets).

nonisolated struct FelReadinessSnapshotExport: Codable, Sendable {
    var efficiencyScore: Double
    var prqScore: Double
    var readinessScore: Double
    var verticalPotential: Double
    var neuralDrive: Double
    var popForce: Double
    var currentOutfit: String
    var verticalEstimateInches: Double
    var hangTimeScale: Double
    var kineticLeakageMultiplier: Double
    /// System Scan — optional keys for backward-compatible decode; Unreal reads via `FELReadinessIO`.
    var movementGrade: String?
    var flightTimeSeconds: Double?
    var isPrimed: Bool?
    var ankleKineticHeat: Double?
    var kneeKineticHeat: Double?
    var hipKineticHeat: Double?
    /// Academy `mod9` (Plyos) complete — Unreal applies +2% jump neuro in Dunk Contest (`AcademyPlyosMasteryBonus`).
    var academyPlyosMasteryBonus: Double?
    /// System Scan video probe (async `loadTracks` / `nominalFrameRate`) — present when library clip was analyzed.
    var videoNominalFrameRateHz: Double?
    var playTwinBirthCinematicOnce: Bool?
    var labWelcomeToast: String?
    var jerseyTexturePath: String?
    var shoeTexturePath: String?
    /// MyTeam gear — matches `FELReadinessIO` (`gearMotionWarpMultiplier` / `gearJumpVelocityMultiplier`).
    var gearMotionWarpMultiplier: Double?
    var gearJumpVelocityMultiplier: Double?
    var stoodCreatorCardId: String?
    var neuroFlowIntensityScale: Double?
    var stoodCreatorCardTraitLine: String?
    var stoodCardJumpScale: Double?
    var stoodCardNeuralDriveAlpha: Double?
    var stoodCardTier: String?
    /// Creator Card signature — Unreal `EFELSignatureTrait` (`signature_trait_id`).
    var signatureTraitId: String?
    /// Unreal `ActiveArenaMode` — JSON key **`active_mode`** (not `activeArenaMode`).
    var activeMode: String
    /// Up to 3 card art paths for Vault hologram terminal (optional).
    var creatorCardTextures: [String]?
    var neuroMechanicLogoTexture: String?
    var bondsBounceLogoTexture: String?
    /// Swift `AvatarSkinConfig` — Unreal `AFELBasketballCharacter` mesh relative scale (digital twin rig).
    var avatarHeightScale: Double
    var avatarWeightScale: Double
    /// SFMA rotation screen — Unreal `UFELBiometricOverlays` congestion (optional for legacy JSON).
    var sfmaMultiSegmentalRotationPassed: Bool?

    enum CodingKeys: String, CodingKey {
        case efficiencyScore
        case prqScore
        case readinessScore
        case verticalPotential
        case neuralDrive
        case popForce
        case currentOutfit
        case verticalEstimateInches
        case hangTimeScale
        case kineticLeakageMultiplier
        case movementGrade
        case flightTimeSeconds
        case isPrimed
        case ankleKineticHeat
        case kneeKineticHeat
        case hipKineticHeat
        case academyPlyosMasteryBonus
        case videoNominalFrameRateHz
        case playTwinBirthCinematicOnce
        case labWelcomeToast
        case jerseyTexturePath
        case shoeTexturePath
        case gearMotionWarpMultiplier
        case gearJumpVelocityMultiplier
        case stoodCreatorCardId
        case neuroFlowIntensityScale
        case stoodCreatorCardTraitLine
        case stoodCardJumpScale
        case stoodCardNeuralDriveAlpha
        case stoodCardTier
        case signatureTraitId = "signature_trait_id"
        case activeMode = "active_mode"
        case creatorCardTextures
        case neuroMechanicLogoTexture
        case bondsBounceLogoTexture
        case avatarHeightScale
        case avatarWeightScale
        case sfmaMultiSegmentalRotationPassed
    }
}

private extension JSONEncoder {
    static var felPretty: JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys, .prettyPrinted]
        return e
    }
}
```

File: `Source/Services/FELSupabaseWalletSync.swift`

```swift
import Foundation
import Supabase

/// Supabase Auth session + Realtime `user_balances` so Stripe-credited shards appear instantly in the Lab shell.
/// Alpha 1: `subscribeWithError` on `public.user_balances` — ensure `FEL_SUPABASE_URL` points at production (same project as `stripe-webhook-handler`).
@MainActor
final class FELSupabaseWalletSync {
    static let shared = FELSupabaseWalletSync()

    private var client: SupabaseClient?
    private var realtimeChannel: RealtimeChannelV2?
    private var postgresChangeSubscription: RealtimeSubscription?
    private var listenTask: Task<Void, Never>?
    private var walletReconnectTask: Task<Void, Never>?
    private var walletReconnectAttempt: Int = 0

    private enum Key {
        static let email = "felSupabaseSignInEmail"
        /// Persisted local `athlete_id` for `athlete_profile_link` upserts after token refresh / foreground.
        static let linkedAthleteId = "felLinkedAthleteId"
    }

    var lastErrorMessage: String?

    private init() {}

    private func makeClient() -> SupabaseClient? {
        if let client {
            return client
        }
        guard let baseRaw = FELAppConfig.felSupabaseURL,
              let keyRaw = FELAppConfig.felSupabaseAnonKey,
              let url = URL(string: baseRaw.trimmingCharacters(in: .whitespacesAndNewlines)),
              !keyRaw.isEmpty else {
            return nil
        }
        let c = SupabaseClient(supabaseURL: url, supabaseKey: keyRaw)
        client = c
        return c
    }

    /// Signed-in JWT + user id for REST `user_balances` (RLS requires `auth.uid()`).
    func authState() async -> (userId: UUID, accessToken: String)? {
        guard let client = makeClient() else { return nil }
        do {
            let session = try await client.auth.session
            return (session.user.id, session.accessToken)
        } catch {
            return nil
        }
    }

    /// Restore session from Keychain (Supabase Auth), link athlete row, start Realtime.
    func resumeSessionIfNeeded(labViewModel: LabViewModel) {
        listenTask?.cancel()
        listenTask = Task {
            guard await authState() != nil else { return }
            UserDefaults.standard.set(labViewModel.profile.id, forKey: Key.linkedAthleteId)
            await upsertAthleteProfileLink(athleteId: labViewModel.profile.id)
            await syncProfileSupabaseId(labViewModel: labViewModel)
            await startWalletRealtime(labViewModel: labViewModel)
        }
    }

    func signIn(email: String, password: String, labViewModel: LabViewModel) async -> Bool {
        lastErrorMessage = nil
        guard let client = makeClient() else {
            lastErrorMessage = "Supabase not configured (FEL_SUPABASE_URL / FEL_SUPABASE_ANON_KEY)."
            return false
        }
        do {
            try await client.auth.signIn(email: email, password: password)
            UserDefaults.standard.set(email, forKey: Key.email)
            UserDefaults.standard.set(labViewModel.profile.id, forKey: Key.linkedAthleteId)
            await upsertAthleteProfileLink(athleteId: labViewModel.profile.id)
            await syncProfileSupabaseId(labViewModel: labViewModel)
            await PRQManager.shared.syncWallet()
            await startWalletRealtime(labViewModel: labViewModel)
            return true
        } catch {
            lastErrorMessage = error.localizedDescription
            return false
        }
    }

    func signOut() async {
        listenTask?.cancel()
        listenTask = nil
        postgresChangeSubscription = nil
        if let ch = realtimeChannel, let c = makeClient() {
            await c.realtimeV2.removeChannel(ch)
        }
        realtimeChannel = nil
        guard let client = makeClient() else { return }
        try? await client.auth.signOut()
        UserDefaults.standard.removeObject(forKey: Key.linkedAthleteId)
        lastErrorMessage = nil
    }

    /// Foreground / post-refresh: re-link `athlete_id` ↔ `user_id` so Stripe webhooks resolve after session rotation.
    func refreshAthleteProfileLink(athleteId: String) async {
        guard await authState() != nil else { return }
        await upsertAthleteProfileLink(athleteId: athleteId)
    }

    private func syncProfileSupabaseId(labViewModel: LabViewModel) async {
        guard let state = await authState() else { return }
        var p = labViewModel.profile
        let uuid = state.userId.uuidString.lowercased()
        guard p.supabaseUserId != uuid else { return }
        p.supabaseUserId = uuid
        labViewModel.profile = p
        SaveSystem.saveProfile(p)
    }

    private func upsertAthleteProfileLink(athleteId: String) async {
        guard let state = await authState() else { return }
        let ok = await FELSovereignShardEconomy.upsertAthleteProfileLinkRPC(athleteId: athleteId, accessToken: state.accessToken)
        if !ok {
            lastErrorMessage = "Could not upsert athlete_profile_link (check RPC migration and JWT)."
        }
    }

    private func startWalletRealtime(labViewModel: LabViewModel) async {
        guard let client = makeClient() else { return }
        guard let session = try? await client.auth.session else { return }

        // Do not cancel `listenTask` here — this function is often invoked from that task; self-cancel would drop the session chain.
        postgresChangeSubscription = nil
        if let ch = realtimeChannel {
            await client.realtimeV2.removeChannel(ch)
        }
        realtimeChannel = nil

        let uid = session.user.id
        let token = session.accessToken
        let realtime = client.realtimeV2
        await realtime.setAuth(token)
        await realtime.connect()

        let topic = "wallet-\(uid.uuidString.lowercased())"
        let channel = realtime.channel(topic)
        realtimeChannel = channel

        let filter = "user_id=eq.\(uid.uuidString.lowercased())"
        postgresChangeSubscription = channel.onPostgresChange(
            AnyAction.self,
            schema: "public",
            table: "user_balances",
            filter: filter
        ) { _ in
            Task { @MainActor in
                await PRQManager.shared.syncWallet()
            }
        }

        do {
            try await channel.subscribeWithError()
            walletReconnectAttempt = 0
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
            scheduleWalletRealtimeReconnect(labViewModel: labViewModel)
        }
    }

    /// Edge case: WebSocket / channel drops — bounded exponential backoff, then full re-subscribe (Stripe webhook still lands on next foreground sync).
    private func scheduleWalletRealtimeReconnect(labViewModel: LabViewModel) {
        walletReconnectTask?.cancel()
        let attempt = walletReconnectAttempt
        walletReconnectAttempt = min(attempt + 1, 12)
        let delaySec = min(60.0, pow(2.0, Double(attempt)))
        walletReconnectTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(delaySec * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await startWalletRealtime(labViewModel: labViewModel)
        }
    }
}
```

File: `Source/Services/VenueManager.swift`

```swift
import SwiftUI

// MARK: - Arena venue routing (ARENAS UI ↔ environments)

/// Maps high-level venues to `GameModeRegistry` / `GameModeId` for a single “dashboard → Arena” handoff.
enum VenueManager {
    enum Venue: String, CaseIterable, Sendable {
        case veniceBeach
        case dojo
        case stadiumDiamond
        case stadiumField
        case stadiumPitch
        case golfGreen
        case beachCourt
        case academyArena

        var environmentName: String {
            switch self {
            case .veniceBeach: return "Venice Beach Court"
            case .dojo: return "Dojo Arena"
            case .stadiumDiamond: return "Stadium Diamond"
            case .stadiumField: return "Stadium Field"
            case .stadiumPitch: return "Stadium Pitch"
            case .golfGreen: return "Golf Green"
            case .beachCourt: return "Beach Court"
            case .academyArena: return "Arena"
            }
        }

        /// Default mode to open when jumping in from a hub tile.
        var defaultModeId: GameModeId {
            switch self {
            case .veniceBeach: return .basketballHeadToHead
            case .dojo: return .karate
            case .stadiumDiamond: return .baseball
            case .stadiumField: return .football
            case .stadiumPitch: return .soccer
            case .golfGreen: return .golf
            case .beachCourt: return .volleyball
            case .academyArena: return .gymnastics
            }
        }
    }

    /// Switch to Arena tab and preselect a mode for the next `ArenaView` appear.
    @MainActor
    static func openVenue(_ venue: Venue, viewModel: LabViewModel, selectedTab: Binding<AppTab>) {
        viewModel.preselectedArenaModeId = venue.defaultModeId
        selectedTab.wrappedValue = .arena
        PRQManager.shared.sync(from: viewModel)
    }

    @MainActor
    static func openMode(_ modeId: GameModeId, viewModel: LabViewModel, selectedTab: Binding<AppTab>) {
        viewModel.preselectedArenaModeId = modeId
        selectedTab.wrappedValue = .arena
        PRQManager.shared.sync(from: viewModel)
    }

    /// Venice: hoops vs dunk lab redirect (dunk uses Lab full-screen flow).
    @MainActor
    static func openDunkContestLab(viewModel: LabViewModel, selectedTab: Binding<AppTab>) {
        viewModel.openDunkOnNextLabAppearance = true
        selectedTab.wrappedValue = .lab
        PRQManager.shared.sync(from: viewModel)
    }
}
```

### Swift — large views (excerpts per bundle spec)

File: `Source/LabView.swift (excerpt A: properties, dunk cover, scan sheet)`

```swift
// excerpt: Source/LabView.swift lines 1-163 (total 2243 lines)
import SwiftUI

struct LabView: View {
    let viewModel: LabViewModel
    @Binding var selectedTab: AppTab

    @Bindable private var prqManager = PRQManager.shared
    @State private var appeared = false
    @State private var pulsePhase: CGFloat = 0
    @State private var dunkFlash: Bool = false
    @State private var showCourtExpanded: Bool = false
    @State private var courtLoaded: Bool = false
    @State private var showSystemScan: Bool = false
    @State private var showBioSyncTransition: Bool = false
    @State private var showBiomechanicsDetail: Bool = false
    @State private var showCoach: Bool = false
    @State private var showBlueprints: Bool = false
    @State private var showBiomechanicsEducation: Bool = false
    @State private var showRecoveryLab: Bool = false
    @State private var showPressureManagement: Bool = false
    @State private var freestyleDunk = DunkContestState()
    @State private var freestyleDunkTimer: Task<Void, Never>?
    @State private var freestyleLastAction: String = ""
    @State private var freestyleJudgeScores: (Int, Int, Int)?
    @State private var freestyleCrowdMessage: String = ""
    @State private var freestyleScreenShake: CGFloat = 0
    @State private var freestyleDunkImpact: (modifier: DunkModifier, impactIntensity: Double)?
    @State private var showDunkFullScreen: Bool = false
    @State private var freestyleShardsEarned: Int?
    @Environment(\.simpleMode) private var simpleMode

    private var freestyleStickInput: CGPoint {
        switch freestyleDunk.phase {
        case .approach:
            return CGPoint(x: 0, y: CGFloat(freestyleDunk.sprintCharge))
        case .launch:
            return CGPoint(x: 0, y: 0.4)
        case .airborne, .landing:
            return .zero
        case .idle, .scored:
            return .zero
        }
    }

    private var freestyleIsMidAir: Bool {
        freestyleDunk.phase == .airborne || freestyleDunk.phase == .launch
    }

    private var effectiveMetrics: PerformanceMetrics {
        viewModel.effectiveMetrics
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    tierBanner
                    scanSection
                    pressureManagementSection
                    biomechanicsSection
                    movementScienceSection
                    athleteProfileBanner
                    courtSection
                        .id("labCourtSection")
                    neuralDriveCard
                    cloudCortexSection
                    hrvReadinessCard
                    metricsGrid
                    CreatorCardBoostView(viewModel: viewModel)
                    coachAndBlueprintsRow
                    parentalOverviewSection
                    quickStartSection
                    recentActivitySection
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .onChange(of: showDunkFullScreen) { _, isShowing in
                if !isShowing {
                    freestyleDunkTimer?.cancel()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        withAnimation(.easeOut(duration: 0.4)) {
                            proxy.scrollTo("labCourtSection", anchor: .center)
                        }
                    }
                }
            }
        }
        .background(Theme.deepBlack)
        .onChange(of: viewModel.openDunkOnNextLabAppearance) { _, open in
            if open {
                showDunkFullScreen = true
                viewModel.openDunkOnNextLabAppearance = false
            }
        }
        .onAppear {
            FELPrimedStreakNotificationScheduler.shared.recordSession(prq: Int(viewModel.effectiveMetrics.prqScore))
            grantWelcomeLabShardsIfNeeded()
            if viewModel.openDunkOnNextLabAppearance {
                showDunkFullScreen = true
                viewModel.openDunkOnNextLabAppearance = false
            }
            withAnimation(.spring(response: 0.6)) { appeared = true }
            Task {
                try? await Task.sleep(for: .milliseconds(600))
                withAnimation(.spring(response: 0.4)) { courtLoaded = true }
            }
        }
        .sheet(isPresented: $showSystemScan) {
            SystemScanView(
                sport: viewModel.profile.sport,
                goal: viewModel.profile.goal,
                profileForDemoFastTrack: viewModel.profile
            ) { result in
                viewModel.applyScanResult(result)
                showBioSyncTransition = true
            } onOpenAcademyModule: { moduleId in
                viewModel.preselectedAcademyModuleId = moduleId
                selectedTab = .games
                showSystemScan = false
            }
        }
        .fullScreenCover(isPresented: $showBioSyncTransition) {
            BioSyncLoadingView(viewModel: viewModel) {
                showBioSyncTransition = false
            }
        }
        .sheet(isPresented: $showBiomechanicsDetail) {
            biomechanicsDetailSheet
        }
        .navigationDestination(isPresented: $showCoach) {
            CoachView(viewModel: viewModel)
        }
        .navigationDestination(isPresented: $showBlueprints) {
            BlueprintsView(viewModel: viewModel)
        }
        .sheet(isPresented: $showBiomechanicsEducation) {
            BiomechanicsEducationView()
        }
        .sheet(isPresented: $showRecoveryLab) {
            RecoveryLabView(viewModel: viewModel)
        }
        .sheet(isPresented: $showPressureManagement) {
            NavigationStack {
                FELPressureManagementDashboardView()
                    .navigationTitle("Sensory Mapping")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { showPressureManagement = false }
                                .foregroundStyle(Theme.brandCyan)
                        }
                    }
                    .toolbarColorScheme(.dark, for: .navigationBar)
            }
            .presentationDetents([.large])
            .presentationBackground(Theme.deepBlack)
        }
        .fullScreenCover(isPresented: $showDunkFullScreen) {
            DunkFlowView(
                viewModel: viewModel,
```

File: `Source/LabView.swift (excerpt B: freestyle engine + handlers)`

```swift
// excerpt: Source/LabView.swift lines 856-1036 (total 2243 lines)
                    greenZone: freestyleDunk.landingGreenZone,
                    accentColor: .orange
                )

                Button {
                    confirmFreestyleLanding()
                } label: {
                    Text("LAND!")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            freestyleDunk.landingGreenZone.contains(freestyleDunk.landingTiming)
                                ? Color.orange
                                : Color.orange.opacity(0.4)
                        )
                        .clipShape(.rect(cornerRadius: 12))
                        .shadow(color: .orange.opacity(0.3), radius: 6)
                }
            }

        case .scored:
            EmptyView()
        }
    }

    private func freestyleTimingBar(value: Double, greenZone: ClosedRange<Double>, accentColor: Color) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.black.opacity(0.6))

                RoundedRectangle(cornerRadius: 4)
                    .fill(accentColor.opacity(0.25))
                    .frame(
                        width: geo.size.width * (greenZone.upperBound - greenZone.lowerBound)
                    )
                    .offset(x: geo.size.width * greenZone.lowerBound)

                RoundedRectangle(cornerRadius: 2)
                    .fill(greenZone.contains(value) ? accentColor : .red)
                    .frame(width: 4)
                    .offset(x: geo.size.width * value - 2)
                    .animation(.easeInOut(duration: 0.08), value: value)
            }
        }
        .frame(height: 16)
        .clipShape(.rect(cornerRadius: 5))
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(accentColor.opacity(0.3), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var freestyleDunkPhaseIndicator: some View {
        if freestyleDunk.phase != .idle && freestyleDunk.phase != .scored {
            VStack(spacing: 4) {
                Text(freestylePhaseLabel)
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(freestylePhaseColor)
                    .tracking(1)
                if freestyleDunk.phase == .airborne {
                    Text(String(format: "HEIGHT: %.0f%%", freestyleDunk.jumpHeight * 100))
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(.black.opacity(0.7))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(freestylePhaseColor.opacity(0.3), lineWidth: 1)
                    )
            )
            .padding(10)
            .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private var freestyleScoringOverlay: some View {
        if let scores = freestyleJudgeScores {
            VStack(spacing: 4) {
                if !freestyleCrowdMessage.isEmpty {
                    Text(freestyleCrowdMessage)
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(.orange)
                        .tracking(1)
                }
                HStack(spacing: 12) {
                    ForEach([scores.0, scores.1, scores.2], id: \.self) { s in
                        Text("\(s)")
                            .font(.system(size: 16, weight: .black, design: .monospaced))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(.orange.opacity(0.2))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(.orange.opacity(0.4), lineWidth: 1)
                                    )
                            )
                    }
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.black.opacity(0.75))
            )
            .padding(.bottom, 10)
            .allowsHitTesting(false)
            .transition(.scale.combined(with: .opacity))
        }
    }

    private var freestylePhaseLabel: String {
        switch freestyleDunk.phase {
        case .approach: return "SPRINTING"
        case .launch: return "GATHER"
        case .airborne: return "IN THE AIR"
        case .landing: return "LANDING"
        default: return ""
        }
    }

    private var freestylePhaseColor: Color {
        switch freestyleDunk.phase {
        case .approach: return .cyan
        case .launch: return .green
        case .airborne: return .purple
        case .landing: return .orange
        default: return .white
        }
    }

    // MARK: - Freestyle Dunk Engine Logic

    private func startFreestyleApproach() {
        guard freestyleDunk.phase == .idle else { return }
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            freestyleDunk.startApproach()
        }
        showDunkFullScreen = true
        freestyleDunkTimer?.cancel()
        freestyleDunkTimer = Task {
            while !Task.isCancelled && freestyleDunk.phase == .approach && freestyleDunk.isSprintHeld {
                try? await Task.sleep(for: .milliseconds(16))
                guard !Task.isCancelled else { return }
                freestyleDunk.sprintCharge = min(1.0, freestyleDunk.sprintCharge + 0.016 * freestyleDunk.sprintChargeRate)
                if freestyleDunk.sprintCharge >= 1.0 {
                    releaseFreestyleSprint()
                    return
                }
            }
        }
    }

    private func releaseFreestyleSprint() {
        guard freestyleDunk.phase == .approach else { return }
        freestyleDunkTimer?.cancel()
        withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
            freestyleDunk.releaseSprint()
        }
        freestyleDunkTimer = Task {
            while !Task.isCancelled && freestyleDunk.phase == .launch {
                try? await Task.sleep(for: .milliseconds(16))
                guard !Task.isCancelled else { return }
                freestyleDunk.launchTiming += freestyleDunk.launchTimingDirection * freestyleDunk.launchTimingSpeed * 0.016
                if freestyleDunk.launchTiming >= 1.0 { freestyleDunk.launchTimingDirection = -1 }
                if freestyleDunk.launchTiming <= 0.0 { freestyleDunk.launchTimingDirection = 1 }
                freestyleDunk.launchTiming = max(0, min(1, freestyleDunk.launchTiming))
            }
        }
    }
```

File: `Source/LabView.swift (excerpt C: DunkFlowView + DunkFullScreenView)`

```swift
// excerpt: Source/LabView.swift lines 1798-2067 (total 2243 lines)
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("RECENT ACTIVITY")
                .font(.system(.caption2, design: .monospaced, weight: .bold))
                .foregroundStyle(.secondary)
                .tracking(2)

            if viewModel.sessions.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "figure.run.circle")
                        .font(.system(size: 36))
                        .foregroundStyle(Theme.brandBlue.opacity(0.4))
                    Text("No workouts yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Start a track to begin your evolution")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                ForEach(viewModel.sessions.suffix(3).reversed()) { session in
                    SessionRow(session: session, tracks: viewModel.tracks)
                }
            }
        }
    }
}

struct AttributeImpactRow: View {
    let attribute: String
    let joint: String
    let status: JointStatus
    let modifier: String

    private var statusColor: Color {
        switch status {
        case .optimal: Theme.brandCyan
        case .moderate: .orange
        case .deficit: .red
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 1) {
                Text(attribute.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                Text("\(joint) → \(status.label)")
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(modifier)
                .font(.system(size: 13, weight: .black, design: .monospaced))
                .foregroundStyle(statusColor)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(statusColor.opacity(0.04))
        )
    }
}

struct TrackQuickStartRow: View {
    let track: CurriculumTrack

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Theme.difficultyColor(track.difficulty).opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: trackIcon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Theme.difficultyColor(track.difficulty))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(track.name.uppercased())
                    .font(.system(.subheadline, weight: .bold))
                    .foregroundStyle(.white)

                Text(track.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Theme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Theme.cardBorder, lineWidth: 0.5)
                )
        )
    }

    private var trackIcon: String {
        switch track.difficulty {
        case .foundation: "1.circle.fill"
        case .flight: "2.circle.fill"
        case .elite: "3.circle.fill"
        }
    }
}

struct SessionRow: View {
    let session: WorkoutSession
    let tracks: [CurriculumTrack]

    private var trackName: String {
        tracks.first(where: { $0.id == session.trackId })?.name ?? "Workout"
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(trackName.uppercased())
                    .font(.system(.caption, design: .monospaced, weight: .bold))
                    .foregroundStyle(.white)

                Text("\(session.exercisesCompleted)/\(session.totalExercises) exercises")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("+\(session.shardsEarned)")
                    .font(.system(.caption, design: .monospaced, weight: .bold))
                    .foregroundStyle(Theme.brandCyan)

                Text(session.date, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Theme.cardBackground)
        )
    }
}

// MARK: - Dunk flow: Get Ready (3-2-1-GO) then full-screen gameplay

private struct DunkFlowView: View {
    let viewModel: LabViewModel
    @Binding var freestyleDunk: DunkContestState
    @Binding var freestyleDunkImpact: (modifier: DunkModifier, impactIntensity: Double)?
    @Binding var freestyleJudgeScores: (Int, Int, Int)?
    @Binding var freestyleCrowdMessage: String
    @Binding var freestyleShardsEarned: Int?
    @Binding var freestyleScreenShake: CGFloat
    @Binding var dunkFlash: Bool
    let courtLoaded: Bool
    @Binding var showDunkFullScreen: Bool
    let onFaceButton: (PS2FaceButton) -> Void
    var onLeftStick: (CGPoint) -> Void = { _ in }
    let onDismiss: () -> Void
    let onClaimRewards: () -> Void

    @State private var showGetReady: Bool = true

    var body: some View {
        Group {
            if showGetReady {
                GetReadyScreen(
                    title: "Dunk Contest",
                    subtitle: "Hold left stick ↑ to sprint · Release to launch · Face buttons to finish",
                    inspirationTag: "Dunk contest",
                    accentColor: Theme.brandCyan,
                    onComplete: { withAnimation(.easeInOut(duration: 0.32)) { showGetReady = false } }
                )
                .statusBarHidden(true)
                .transition(.opacity.combined(with: .scale(scale: 0.97)))
            } else {
                DunkFullScreenView(
                    viewModel: viewModel,
                    freestyleDunk: $freestyleDunk,
                    freestyleDunkImpact: $freestyleDunkImpact,
                    freestyleJudgeScores: $freestyleJudgeScores,
                    freestyleCrowdMessage: $freestyleCrowdMessage,
                    freestyleShardsEarned: $freestyleShardsEarned,
                    freestyleScreenShake: $freestyleScreenShake,
                    dunkFlash: $dunkFlash,
                    courtLoaded: courtLoaded,
                    onFaceButton: onFaceButton,
                    onLeftStick: onLeftStick,
                    onDismiss: onDismiss,
                    onClaimRewards: onClaimRewards
                )
                .transition(.opacity.combined(with: .scale(scale: 0.99)))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showGetReady)
        .onDisappear { showGetReady = true }
    }
}

// MARK: - Full-Screen Dunk Gameplay (hides tab bar and nav; game-only UI)

private struct DunkFullScreenView: View {
    let viewModel: LabViewModel
    @Binding var freestyleDunk: DunkContestState
    @Binding var freestyleDunkImpact: (modifier: DunkModifier, impactIntensity: Double)?
    @Binding var freestyleJudgeScores: (Int, Int, Int)?
    @Binding var freestyleCrowdMessage: String
    @Binding var freestyleShardsEarned: Int?
    @Binding var freestyleScreenShake: CGFloat
    @Binding var dunkFlash: Bool
    let courtLoaded: Bool
    let onFaceButton: (PS2FaceButton) -> Void
    var onLeftStick: (CGPoint) -> Void = { _ in }
    let onDismiss: () -> Void
    let onClaimRewards: () -> Void

    private var stickInput: CGPoint {
        switch freestyleDunk.phase {
        case .approach: return CGPoint(x: 0, y: CGFloat(freestyleDunk.sprintCharge))
        case .launch: return CGPoint(x: 0, y: 0.4)
        default: return .zero
        }
    }

    private var isMidAir: Bool {
        freestyleDunk.phase == .airborne || freestyleDunk.phase == .launch
    }

    private var phaseLabel: String {
        switch freestyleDunk.phase {
        case .approach: return "SPRINTING"
        case .launch: return "GATHER"
        case .airborne: return "IN THE AIR"
        case .landing: return "LANDING"
        default: return ""
        }
    }

    private var phaseColor: Color {
        switch freestyleDunk.phase {
        case .approach: return .cyan
        case .launch: return .green
        case .airborne: return .purple
        case .landing: return .orange
        default: return .white
        }
    }
```

_Omitted from `LabView.swift`: header/metrics/court UI sections (~lines 164–855, 1037–1797, 2068–end) — layout and non-dunk Lab chrome._

File: `Source/Views/SystemScanView.swift (excerpt part 1)`

```swift
import SwiftUI
import PhotosUI
import AVFoundation
import UniformTypeIdentifiers

/// Animated “ghost” guide: phone angle + standing zone for the first biomechanics capture.
private struct FirstScanGhostGuideOverlay: View {
    var phase: CGFloat

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                RoundedRectangle(cornerRadius: 36, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Theme.brandCyan.opacity(0.35 + 0.25 * phase), Theme.brandBlue.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .frame(width: w * 0.42, height: w * 0.88)
                    .rotationEffect(.degrees(-8))
                    .position(x: w * 0.72, y: h * 0.42)
                    .shadow(color: Theme.brandCyan.opacity(0.15 + 0.1 * phase), radius: 18)

                Image(systemName: "iphone.gen2")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(.white.opacity(0.14 + 0.08 * phase))
                    .rotationEffect(.degrees(-8))
                    .position(x: w * 0.72, y: h * 0.42)

                Image(systemName: "figure.stand")
                    .font(.system(size: 120, weight: .ultraLight))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Theme.brandBlue.opacity(0.12), Theme.brandCyan.opacity(0.18)],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .position(x: w * 0.38, y: h * 0.48)
                    .scaleEffect(0.96 + 0.04 * phase)

                VStack(alignment: .leading, spacing: 6) {
                    Text("FIRST SCAN")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(Theme.brandCyan)
                        .tracking(3)
                    Text("Stand 6–8 ft back • full body in frame")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                    Text("Film landscape — phone at hip height, slight upward tilt toward takeoff.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
                .frame(maxWidth: w * 0.52, alignment: .leading)
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .position(x: w * 0.34, y: h * 0.2)
            }
        }
        .ignoresSafeArea()
    }
}

private struct VideoFile: Transferable {
    let url: URL
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .movie) { video in
            SentTransferredFile(video.url)
        }

        FileRepresentation(importedContentType: .movie) { received in
            let name = received.file.lastPathComponent
            let temp = FileManager.default.temporaryDirectory.appending(path: name.isEmpty ? "scan_video.mov" : name)
            try? FileManager.default.removeItem(at: temp)
            try FileManager.default.copyItem(at: received.file, to: temp)
            return Self(url: temp)
        }
    }
}

struct SystemScanView: View {
    let sport: String?
    let goal: String?
    /// When set with Demo Mode on, Fast-Track can reuse `systemScan` or `defaultForProfile` without video analysis.
    var profileForDemoFastTrack: UserProfile? = nil
    let onComplete: (SystemScanResult) -> Void
    /// Deep-link to Vertical Velocity Academy module (`mod1`…`mod12`).
    var onOpenAcademyModule: ((String) -> Void)? = nil

    @AppStorage("felDemoModeShowcase") private var felDemoModeShowcase = false
    @EnvironmentObject private var unrealRuntime: UFELUnrealOverlayRuntime
    @Environment(\.dismiss) private var dismiss
    @State private var phase: ScanPhase = .picking
    @State private var selectedItem: PhotosPickerItem?
    @State private var videoURL: URL?
    @State private var isLoadingVideo: Bool = false
    @State private var analysisProgress: Double = 0
    @State private var scanLines: CGFloat = 0
    @State private var gridPulse: Bool = false
    @State private var ghostGuidePhase: CGFloat = 0

    private enum ScanPhase {
        case picking
        case analyzing
        case results
    }

    @State private var generatedResult: SystemScanResult?
    @State private var showAvatarCustomize = false
    @State private var editableAvatarConfig: AvatarSkinConfig?
    @State private var compareJoint: JointType?
    @State private var compareFlip: Bool = false
    @State private var compareTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            if !unrealRuntime.bIsUnrealReady {
                NavigationStack {
                    ZStack {
                        Theme.deepBlack.ignoresSafeArea()
                        Theme.meshGradient.opacity(0.3).ignoresSafeArea()
                        scanGrid

                        if phase == .picking {
                            FirstScanGhostGuideOverlay(phase: ghostGuidePhase)
                                .allowsHitTesting(false)
                        }

                        VStack(spacing: 0) {
                            switch phase {
                            case .picking:
                                pickingPhase
                            case .analyzing:
                                analyzingPhase
                            case .results:
                                if let result = generatedResult {
                                    resultsPhase(result)
                                }
                            }
                        }
                    }
                    .navigationTitle("")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { dismiss() }
                                .foregroundStyle(Theme.brandBlue)
                        }
                    }
                    .toolbarColorScheme(.dark, for: .navigationBar)
                }
            }
            if unrealRuntime.bIsUnrealReady {
                UFELUnrealViewportContainer()
            }
        }
        .onAppear {
            unrealRuntime.setUnrealReady(true)
        }
        .onDisappear {
            unrealRuntime.setUnrealReady(false)
        }
        .sheet(isPresented: $showAvatarCustomize) {
            if let result = generatedResult {
                AvatarCustomizeView(
                    initialConfig: editableAvatarConfig ?? result.avatarConfig,
                    onSave: { editableAvatarConfig = $0 }
                )
            }
        }
        .presentationDetents([.large])
        .presentationBackground(Theme.deepBlack)
        .onDisappear {

// … pickingPhase / analyzingPhase / resultsPhase UI omitted …
```

File: `Source/Views/SystemScanView.swift (excerpt part 2: startAnalysis + generateScanResult)`

```swift
                    HStack(spacing: 8) {
                        Image(systemName: "bolt.fill")
                        Text("ENTER THE LAB")
                    }
                    .font(.system(.subheadline, design: .monospaced, weight: .black))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(gradeColor(result.prqScore))
                    .clipShape(.rect(cornerRadius: 14))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .padding(.top, 16)
        }
        .scrollIndicators(.hidden)
    }

    private func prqBreakdownSection(_ result: SystemScanResult) -> some View {
        let b = SystemScanMovementDecoder.prqBreakdown(scan: result, goal: goal)
        return VStack(alignment: .leading, spacing: 12) {
            Text("PRQ BREAKDOWN")
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(Theme.brandCyan)
                .tracking(2)

            Text("PRQ blends Neural Drive (reactive flight) with Biomechanical Integrity (vertical stiffness and joint chain quality). Tier bias nudges the score toward your stated goal.")
                .font(.caption)
                .foregroundStyle(.secondary)

            GeometryReader { geo in
                let w = geo.size.width
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.06))
                    HStack(spacing: 0) {
                        Capsule()
                            .fill(Theme.brandCyan.opacity(0.85))
                            .frame(width: max(8, w * b.neuralShare))
                        Capsule()
                            .fill(Theme.brandBlue.opacity(0.85))
                            .frame(width: max(8, w * b.structuralShare))
                    }
                }
            }
            .frame(height: 14)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Neural drive \(Int(b.neuralShare * 100)) percent, biomechanical integrity \(Int(b.structuralShare * 100)) percent")

            HStack {
                Label {
                    Text("Neural Drive (reactive)")
                        .font(.caption2)
                } icon: {
                    Circle().fill(Theme.brandCyan.opacity(0.85)).frame(width: 8, height: 8)
                }
                Spacer()
                Text(String(format: "%.0f pts contrib.", b.neuralComponent))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
            HStack {
                Label {
                    Text("Biomechanical integrity")
                        .font(.caption2)
                } icon: {
                    Circle().fill(Theme.brandBlue.opacity(0.85)).frame(width: 8, height: 8)
                }
                Spacer()
                Text(String(format: "%.0f pts contrib.", b.structuralComponent))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
            Text(String(format: "Goal tier contribution: %.1f pts", b.tierComponent))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Theme.cardBackground)
        )
        .padding(.horizontal)
    }

    private func movementAuditSection(audit: BiomechanicsAudit, scanResult: SystemScanResult) -> some View {
        let cards = SystemScanMovementDecoder.jointInsights(from: audit)
        return VStack(alignment: .leading, spacing: 14) {
            Text("MOVEMENT AUDIT")
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(Theme.foundationGreen)
                .tracking(2)
            Text("Education first — we name the leak, then route you to the exact Academy module. No fear; just the next rep.")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(cards) { card in
                jointInsightCard(card, scanResult: scanResult)
            }
```

_Omitted from `SystemScanView.swift`: `pickingPhase`, `analyzingPhase`, `resultsPhase` view builders (large SwiftUI layout)._

File: `Source/Views/ArenaView.swift (excerpt: ArenaView shell + ArenaGameFlowView + GenericArenaPlayView header + PRQ commit)`

```swift
// excerpt: Source/Views/ArenaView.swift lines 1-70 (total 2619 lines)
import Combine
import SwiftUI

/// Arena: built-out venues; each venue groups game modes. Tap a mode → Get Ready → Play → Result.
struct ArenaView: View {
    let viewModel: LabViewModel
    @Binding var selectedTab: AppTab

    @EnvironmentObject private var unrealRuntime: UFELUnrealOverlayRuntime

    @State private var selectedMode: GameMode?
    @State private var showLocalPlayLobby = false
    @State private var localPlayMode: GameMode?
    @State private var localPlayIsHost = false
    @State private var showReloadAlert = false
    @State private var arenaLevelLoadWatchdog: Task<Void, Never>?
    @State private var viewportSceneHandshakeTask: Task<Void, Never>?
    /// Gold Master: one-time cinematic welcome + handshake progress (ties to `setUnrealReady`).
    @AppStorage("felArenaWelcomeElijahComplete") private var welcomeElijahComplete = false
    /// First launch: Luma Venice Shop / System Initializing guidance (`GAMEPLAY_STATUS.md` onboarding).
    @AppStorage("felUniversalShipFirstLaunchOnboardingComplete") private var shipFirstLaunchOnboardingComplete = false
    @State private var welcomeHandshakeProgress: Double = 0
    @State private var showFatigueSystemScanBanner = false
    @State private var arenaSyncSettingsExpanded = false
    @AppStorage("felPixelStreamingFallbackURL") private var pixelStreamingFallbackURL = ""
    @State private var showPixelStreamingWebFallback = false
    @StateObject private var arenaLuminanceMonitor = FELArenaAmbientLuminanceMonitor()
    @State private var lastBridgedAmbientLuma: Float?
    /// Fills only while `felNeuroMechanicLightingOptimal` is true (~3.5s steady optimal light for AvatarRigBuilder capture).
    @State private var lightingCalibrationProgress01: Double = 0
    @AppStorage("felAvatarRigLightingCalibrationComplete") private var avatarRigLightingCalibrationComplete = false
    @AppStorage("felDemoModeShowcase") private var felDemoModeShowcase = false
    @State private var heroClipOffered = false
    @State private var heroClipRecording = false
    @State private var lastHeroClipApexInches: Double?
    @State private var heroClipStatusMessage: String?

#if FEL_NON_SHIPPING
    /// DA COMPOUND: live twin scales from last readiness `sync` (matches `readiness_snapshot.json` when export runs).
    @State private var twinScaleDebugLine: String = "avatarHeightScale — · avatarWeightScale —"
    /// InputLatencyMonitor parity (Unreal) — `UserDefaults` + `felInputLatencyJumpMsSample` from native bridge.
    @State private var inputLatencyWarningActive = false
    @State private var inputLatencyFlashPhase = false
    @State private var lastInputLatencyMsDisplay: String = "—"
#endif

    private var shouldShowForensicLightPauseOverlay: Bool {
        guard let lum = arenaLuminanceMonitor.lastNormalizedBrightness else { return false }
        return lum < 0.3
    }

    var body: some View {
        ZStack {
            if !unrealRuntime.bIsUnrealReady {
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        header
                        localPlaySection
                        ForEach(GameModeRegistry.arenaVenues) { venue in
                            venueSection(venue)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 32)
                }
                .background(Theme.deepBlack)
            }
            if unrealRuntime.bIsUnrealReady {
                UFELUnrealViewportContainer()
                arenaInputSchemeOverlay

// … venueSection / modeRow / ArenaDunkInterstitialView …
// excerpt: Source/Views/ArenaView.swift lines 295-560 (total 2619 lines)
            }
        }
#if FEL_NON_SHIPPING
        .onReceive(NotificationCenter.default.publisher(for: felReadinessTwinScalesUpdatedNotification)) { _ in
            refreshTwinScaleDebugLine()
        }
        .onReceive(NotificationCenter.default.publisher(for: felReadinessExportDidUpdateNotification)) { _ in
            refreshTwinScaleDebugLine()
        }
        .onReceive(NotificationCenter.default.publisher(for: .felInputLatencyJumpMsSample)) { note in
            if let ms = note.userInfo?["latencyMs"] as? Double {
                UserDefaults.standard.set(ms, forKey: FELInputLatencyCalibration.userDefaultsKey)
                refreshInputLatencyHudState()
            }
        }
        .onReceive(Timer.publish(every: 0.3, on: .main, in: .common).autoconnect()) { _ in
            refreshInputLatencyHudState()
            if inputLatencyWarningActive {
                inputLatencyFlashPhase.toggle()
            }
        }
#endif
    }

    private func downloadHeroClipTapped() {
        guard !heroClipRecording else { return }
        heroClipRecording = true
        heroClipStatusMessage = nil
        FELHeroClipRecorder.recordAndSaveToPhotos { result in
            heroClipRecording = false
            switch result {
            case .success:
                heroClipStatusMessage = "Saved to Photos"
                heroClipOffered = false
            case .failure(let error):
                heroClipStatusMessage = error.localizedDescription
            }
        }
    }

    private func refreshCoachFatigueBanner() {
        showFatigueSystemScanBanner = FELCoachPerformanceSnapshot.isFatigueDetected
    }

    /// Neuro-Mechanic: average luma from live `sampleBuffer` — gates `readiness_snapshot.json` when too dark for forensic scan.
    private func performLuminanceCheck() {
        let threshold: Float = 0.3
        guard let lum = arenaLuminanceMonitor.lastNormalizedBrightness else {
            return
        }
        let wasSuboptimal = UserDefaults.standard.object(forKey: PRQManager.neuroMechanicLightingOptimalKey) as? Bool == false
        if lum < threshold {
            UserDefaults.standard.set(false, forKey: PRQManager.neuroMechanicLightingOptimalKey)
        } else {
            UserDefaults.standard.set(true, forKey: PRQManager.neuroMechanicLightingOptimalKey)
            if wasSuboptimal {
                PRQManager.shared.sync(from: viewModel)
            }
        }
        let prevBridged = lastBridgedAmbientLuma
        lastBridgedAmbientLuma = lum
        if unrealRuntime.bIsUnrealReady {
            FELUnrealLuminanceBridge.notifyEmbeddedUnrealAmbientChanged(luma: lum, previous: prevBridged)
        }
    }

    private func beginArenaUnrealHandshake() {
        viewportSceneHandshakeTask?.cancel()
        unrealRuntime.setUnrealReady(false)
        startArenaLevelLoadWatchdog()
    }

    private func startArenaLevelLoadWatchdog() {
        arenaLevelLoadWatchdog?.cancel()
        arenaLevelLoadWatchdog = Task { @MainActor in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            showReloadAlert = true
        }
    }

    private func cancelArenaLevelLoadWatchdog() {
        arenaLevelLoadWatchdog?.cancel()
        arenaLevelLoadWatchdog = nil
    }

    private var forensicLightingPauseOverlay: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(
                        LinearGradient(colors: [.yellow, .orange.opacity(0.95)], startPoint: .top, endPoint: .bottom)
                    )
                    .symbolRenderingMode(.hierarchical)
                    .shadow(color: .orange.opacity(0.45), radius: 14)
                Text("Forensic Scan Paused: Increase Ambient Light for 1.0.0 Accuracy.")
                    .font(.system(size: 17, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 28)
            }
            .padding(36)
        }
    }

#if FEL_NON_SHIPPING
    private var readinessTwinScaleDebugOverlay: some View {
        VStack {
            Spacer()
            HStack(alignment: .bottom, spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("NEURO-MECHANIC · CALIBRATION (non-shipping)")
                        .font(.system(size: 10, weight: .bold, design: .default))
                        .foregroundStyle(Color.white)
                        .tracking(0.6)
                    Text(twinScaleDebugLine)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color(red: 0.35, green: 1.0, blue: 0.55))
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                    HStack(spacing: 8) {
                        Text("Input→launch")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.85))
                        Text(lastInputLatencyMsDisplay)
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(inputLatencyWarningActive ? Color.red : Color.white)
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.black.opacity(0.92))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.white.opacity(0.22), lineWidth: 1)
                        )
                )
                if inputLatencyWarningActive {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(.red)
                        .shadow(color: .red.opacity(inputLatencyFlashPhase ? 0.95 : 0.25), radius: inputLatencyFlashPhase ? 12 : 4)
                        .opacity(inputLatencyFlashPhase ? 1 : 0.45)
                        .animation(.easeInOut(duration: 0.28), value: inputLatencyFlashPhase)
                        .accessibilityLabel("Input latency exceeds one frame at 60 hertz")
                }
                Spacer(minLength: 0)
            }
            .padding(.leading, 12)
            .padding(.trailing, 8)
            .padding(.bottom, 28)
        }
        .allowsHitTesting(false)
    }

    private func refreshTwinScaleDebugLine() {
        if let s = PRQManager.shared.lastReadinessTwinScales {
            twinScaleDebugLine = String(format: "avatarHeightScale %.4f · avatarWeightScale %.4f", s.height, s.weight)
        } else {
            twinScaleDebugLine = "avatarHeightScale — · avatarWeightScale — (sync pending)"
        }
    }

    private func refreshInputLatencyHudState() {
        let key = FELInputLatencyCalibration.userDefaultsKey
        guard UserDefaults.standard.object(forKey: key) != nil else {
            inputLatencyWarningActive = false
            lastInputLatencyMsDisplay = "— (no sample)"
            return
        }
        let ms = UserDefaults.standard.double(forKey: key)
        lastInputLatencyMsDisplay = String(format: "%.2f ms (≤%.2f target)", ms, FELInputLatencyCalibration.oneFrame60HzMs)
        inputLatencyWarningActive = ms > FELInputLatencyCalibration.oneFrame60HzMs
    }
#endif

    /// Progress advances only while `felNeuroMechanicLightingOptimal` is true (FELLuminanceAnalyzer ≥ 0.3).
    @ViewBuilder
    private var lightingCalibrationStrip: some View {
        if avatarRigLightingCalibrationComplete {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.brandCyan)
                Text("Lighting calibration complete — AvatarRigBuilder / readiness capture ready.")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.07))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Theme.brandCyan.opacity(0.35), lineWidth: 1)
                    )
            )
            .accessibilityElement(children: .combine)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Calibration Progress")
                        .font(.system(size: 11, weight: .heavy, design: .monospaced))
                        .foregroundStyle(Theme.brandCyan)
                        .tracking(1.5)
                    Spacer(minLength: 8)
                    Text("\(Int(min(100, lightingCalibrationProgress01 * 100)))%")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                ProgressView(value: lightingCalibrationProgress01, total: 1.0)
                    .tint(Theme.brandCyan)
                Text("Stay still in optimal light until complete — required for 1.0.0 AvatarRigBuilder alignment.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.06))
            )
            .accessibilityElement(children: .combine)
        }
    }

    private var welcomeElijahHandshakeOverlay: some View {
        VStack(spacing: 14) {
            Text("Welcome Elijah")
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            Text("SYSTEM INITIALIZING")
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .foregroundStyle(Theme.brandCyan)
                .tracking(3)
            ProgressView(value: welcomeHandshakeProgress, total: 1.0)
                .tint(Theme.brandCyan)
                .padding(.horizontal, 28)
            Text("Handshake tracks Unreal `setUnrealReady` — pick a mode below to load the arena.")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
            Button("Skip intro") {
                welcomeElijahComplete = true
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Theme.brandCyan.opacity(0.9))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .padding(.horizontal, 14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Theme.brandCyan.opacity(0.35), lineWidth: 1)
        )
        .padding(.horizontal, 12)

// … GenericArenaPlayView body (canvas, multipeer, sport branches) …
// excerpt: Source/Views/ArenaView.swift lines 1125-1168 (total 2619 lines)
        let diff = playerScore - opponentScore
        let gain = PRQ.modeReward(mode: mode.id, won: won, tied: tied, combo: 0, criticals: 0, scoreDifferential: diff)
        let baseShards = 6 + totalRounds * 2
        let shards = max(8, min(40, baseShards + (playerScore * 3) + (won ? 12 : 0) + (diff > 0 ? diff * 2 : 0)))
        onMatchEnd(playerScore, opponentScore, shards, gain, roundScores)
    }
}

private struct SoloGolfArenaRoundsView: View {
    let mode: GameMode
    let viewModel: LabViewModel
    let onExit: () -> Void
    let onMatchEnd: (Int, Int, Int, Double, [(Int, Int)]) -> Void

    @State private var round: Int = 1
    @State private var playerScore: Int = 0
    @State private var opponentScore: Int = 0
    @State private var roundScores: [(Int, Int)] = []

    private var totalRounds: Int { mode.id.environmentRoundCount }

    var body: some View {
        ZStack {
            GolfLinksArenaBackground(accentColor: mode.accentColor)
            VStack(spacing: 12) {
                Text("HOLE \(round) OF \(totalRounds)")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundStyle(mode.accentColor)
                GolfSwingView(
                    mode: mode,
                    onExit: onExit,
                    onSwingResolved: { quality in
                        resolveRound(shotQuality: quality)
                    }
                )
                .id(round)
            }
        }
    }

    private func resolveRound(shotQuality: Double) {
        let adjusted = max(0.62, min(0.9, shotQuality))
        let prq = viewModel.effectiveMetrics.prqScore
        let baseChance = PRQ.successChanceFromPRQ(prq, for: mode.id)
```

_Omitted from `ArenaView.swift`: remainder of `GenericArenaPlayView` (scoreRound, finishGame, sport-specific branches), environment copy extensions._

File: `Source/Views/GameScreensView.swift (excerpt: GetReadyScreen + ResultScreen core)`

```swift
// excerpt: Source/Views/GameScreensView.swift lines 1-180 (total 720 lines)
import SwiftUI

struct GetReadyScreen: View {
    let title: String
    var subtitle: String? = nil
    /// Optional style tag for Get Ready screen (no third-party product names).
    var inspirationTag: String? = nil
    var countdown: Int = 3
    var accentColor: Color = Theme.brandBlue
    var onComplete: () -> Void

    @State private var count: Int = 3
    @State private var timer: Task<Void, Never>?
    @State private var pulse: Bool = false
    @State private var ringScale: CGFloat = 0.5
    @State private var showGo: Bool = false
    @State private var outerRingRotation: Double = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
                .background(.ultraThinMaterial.opacity(0.5))

            RadialGradient(
                colors: [accentColor.opacity(0.08), .clear],
                center: .center,
                startRadius: 20,
                endRadius: 300
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(spacing: 24) {
                Text("GET READY")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .tracking(6)
                    .foregroundStyle(accentColor.opacity(0.9))
                Text(title)
                    .font(.system(size: 28, weight: .black))
                    .italic()
                    .tracking(3)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .white.opacity(0.75)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: accentColor.opacity(0.4), radius: 12)
                    .animation(.easeOut(duration: 0.3), value: title)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.85))
                        .tracking(1)
                        .multilineTextAlignment(.center)
                }
                if let tag = inspirationTag, !tag.isEmpty {
                    Text(tag)
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .tracking(2)
                        .foregroundStyle(accentColor.opacity(0.85))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(accentColor.opacity(0.15)))
                }

                ZStack {
                    Circle()
                        .stroke(
                            AngularGradient(
                                colors: [accentColor.opacity(0.3), accentColor.opacity(0.05), accentColor.opacity(0.3)],
                                center: .center
                            ),
                            lineWidth: 3
                        )
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(outerRingRotation))

                    Circle()
                        .stroke(accentColor.opacity(0.12), lineWidth: 6)
                        .frame(width: 100, height: 100)

                    Circle()
                        .stroke(accentColor.opacity(0.4), lineWidth: 3)
                        .frame(width: 100, height: 100)
                        .scaleEffect(ringScale)
                        .opacity(pulse ? 0.0 : 0.6)

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [accentColor.opacity(0.1), accentColor.opacity(0.02)],
                                center: .center,
                                startRadius: 5,
                                endRadius: 50
                            )
                        )
                        .frame(width: 100, height: 100)

                    if showGo {
                        Text("GO!")
                            .font(.system(size: 40, weight: .black, design: .monospaced))
                            .foregroundStyle(accentColor)
                            .shadow(color: accentColor.opacity(0.6), radius: 20)
                            .transition(.scale(scale: 0.3).combined(with: .opacity))
                    } else if count > 0 {
                        Text("\(count)")
                            .font(.system(size: 52, weight: .black, design: .monospaced))
                            .foregroundStyle(.white)
                            .shadow(color: .white.opacity(0.3), radius: 8)
                            .contentTransition(.numericText())
                    }
                }
                .animation(.spring(response: 0.22, dampingFraction: 0.7), value: showGo ? 1 : count)
                .padding(.top, 8)

                HStack(spacing: 6) {
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 10))
                    Text("READY?")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .tracking(5)
                }
                .foregroundStyle(.white.opacity(0.35))
                .padding(.top, 8)

                Text("Tap or controller • both work in game")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.25))
                    .tracking(1)
                    .padding(.top, 6)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(showGo ? "Go" : "Get ready, \(count) seconds. Tap or controller both work in game.")
        .onAppear {
            count = countdown
            pulse = false
            showGo = false
            ringScale = 0.5
            startCountdown()
        }
        .onDisappear {
            timer?.cancel()
        }
    }

    private func startCountdown() {
        withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
            outerRingRotation = 360
        }
        timer?.cancel()
        timer = Task {
            for i in stride(from: countdown, through: 1, by: -1) {
                guard !Task.isCancelled else { return }
                withAnimation(.spring(response: 0.2, dampingFraction: 0.65)) {
                    count = i
                    ringScale = 0.5
                }
                withAnimation(.easeOut(duration: 0.5)) {
                    pulse = true
                    ringScale = 1.4
                }
                try? await Task.sleep(for: .milliseconds(120))
                withAnimation { pulse = false }
                try? await Task.sleep(for: .milliseconds(480))
            }
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.15, dampingFraction: 0.5)) {
                count = 0
                showGo = true
            }
            try? await Task.sleep(for: .milliseconds(380))
            onComplete()
        }
    }
}

// … PreGameMovementSnackView, RoundTransitionScreen omitted …
// excerpt: Source/Views/GameScreensView.swift lines 297-523 (total 720 lines)
struct ResultScreen: View {
    let winner: ResultWinner
    let p1Score: Int
    let p2Score: Int
    var title: String? = nil
    var accentColor: Color = Theme.brandBlue
    var shardsEarned: Int = 0
    var prqGain: Double = 0
    var prqCurrent: Double = PRQ.default
    var modeAttributeLabel: String? = nil
    var modeAttributeValue: Double? = nil
    /// When provided (e.g. from Arena generic play), shows "Round 1: P1 1 – P2 0" style breakdown.
    var roundBreakdown: [(Int, Int)]? = nil
    /// Total Evolution Shards in vault after this match (persistent economy HUD).
    var vaultShardTotal: Int? = nil
    var returnButtonTitle: String = "CLAIM REWARDS & EXIT"
    var onReturn: () -> Void

    enum ResultWinner {
        case p1, p2, draw
    }

    @State private var appeared = false
    @State private var trophyBounce = false
    @State private var glowPulse = false

    private var isP1Win: Bool { winner == .p1 }

    var body: some View {
        ZStack {
            Color.black.opacity(0.88)
                .ignoresSafeArea()
                .background(.ultraThinMaterial.opacity(0.5))

            if isP1Win {
                ZStack {
                    RadialGradient(
                        colors: [accentColor.opacity(glowPulse ? 0.16 : 0.08), .clear],
                        center: .center,
                        startRadius: 10,
                        endRadius: 350
                    )
                    .ignoresSafeArea()

                    RadialGradient(
                        colors: [.yellow.opacity(glowPulse ? 0.06 : 0.02), .clear],
                        center: .top,
                        startRadius: 20,
                        endRadius: 300
                    )
                    .ignoresSafeArea()
                }
                .allowsHitTesting(false)
            }

            VStack(spacing: 24) {
                Spacer()

                if let title {
                    Text(title.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                        .tracking(4)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 10)
                }

                ZStack {
                    if isP1Win {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [.yellow.opacity(0.15), .clear],
                                    center: .center,
                                    startRadius: 10,
                                    endRadius: 60
                                )
                            )
                            .frame(width: 120, height: 120)
                            .scaleEffect(glowPulse ? 1.2 : 1.0)
                    }

                    Image(systemName: isP1Win ? "trophy.fill" : (winner == .draw ? "equal.circle.fill" : "flag.checkered"))
                        .font(.system(size: 60))
                        .foregroundStyle(
                            isP1Win
                                ? AnyShapeStyle(LinearGradient(colors: [.yellow, .orange, .yellow], startPoint: .top, endPoint: .bottom))
                                : AnyShapeStyle(.secondary)
                        )
                        .shadow(color: isP1Win ? .yellow.opacity(0.5) : .clear, radius: 24)
                        .scaleEffect(trophyBounce ? 1.15 : 1.0)
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)

                Text(isP1Win ? "VICTORY" : (winner == .draw ? "DRAW" : "DEFEAT"))
                    .font(.system(size: 40, weight: .black))
                    .italic()
                    .tracking(3)
                    .foregroundStyle(
                        isP1Win
                            ? AnyShapeStyle(LinearGradient(colors: [accentColor, .white, accentColor], startPoint: .leading, endPoint: .trailing))
                            : AnyShapeStyle(.white.opacity(0.9))
                    )
                    .shadow(color: isP1Win ? accentColor.opacity(0.4) : .clear, radius: 20)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 15)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityLabel(isP1Win ? "Victory" : (winner == .draw ? "Draw" : "Defeat"))
                if isP1Win {
                    Text("PLAYER 1 WINS")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .tracking(4)
                        .foregroundStyle(accentColor.opacity(0.8))
                        .opacity(appeared ? 1 : 0)
                }

                HStack(spacing: 20) {
                    VStack(spacing: 6) {
                        Text("\(p1Score)")
                            .font(.system(size: 40, weight: .black, design: .monospaced))
                            .foregroundStyle(.white)
                            .shadow(color: accentColor.opacity(0.3), radius: 8)
                            .contentTransition(.numericText())
                            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: p1Score)
                        Text("P1")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .tracking(2)
                            .foregroundStyle(accentColor.opacity(0.8))
                    }

                    Text("\u{2014}")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.tertiary)

                    VStack(spacing: 6) {
                        Text("\(p2Score)")
                            .font(.system(size: 40, weight: .black, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.4))
                            .contentTransition(.numericText())
                            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: p2Score)
                        Text("P2")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .tracking(2)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Score: Player 1 \(p1Score), Player 2 \(p2Score)")
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial.opacity(0.3))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(accentColor.opacity(0.15), lineWidth: 1)
                        )
                )
                .opacity(appeared ? 1 : 0)

                rewardsEarnedSection
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 12)
                    .animation(.spring(response: 0.5, dampingFraction: 0.78).delay(0.15), value: appeared)

                if let vault = vaultShardTotal {
                    HStack(spacing: 8) {
                        Image(systemName: "vault.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.brandCyan.opacity(0.9))
                        Text("Vault")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Text("\(vault)")
                            .font(.system(size: 16, weight: .black, design: .monospaced))
                            .foregroundStyle(.white)
                        Text("shards")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(Theme.brandCyan.opacity(0.85))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.06))
                            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.brandCyan.opacity(0.2), lineWidth: 1))
                    )
                    .opacity(appeared ? 1 : 0)
                }

                if let rounds = roundBreakdown, !rounds.isEmpty {
                    roundBreakdownSection(rounds)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 12)
                        .animation(.spring(response: 0.5, dampingFraction: 0.78).delay(0.2), value: appeared)
                }

                prqBreakdownSection
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 12)
                    .animation(.spring(response: 0.5, dampingFraction: 0.78).delay(0.25), value: appeared)

                Button {
                    onReturn()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 12, weight: .bold))
                        Text(returnButtonTitle)
                            .font(.system(.subheadline, design: .monospaced, weight: .black))
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [accentColor, accentColor.opacity(0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .clipShape(.rect(cornerRadius: 14))
                    .shadow(color: accentColor.opacity(0.3), radius: 12)
                }
                .accessibilityLabel(returnButtonTitle)
                .accessibilityHint("Returns to previous screen and claims rewards")
```

_Omitted from `GameScreensView.swift`: `ResultScreen` private sections (`rewardsEarnedSection`, `prqBreakdownSection`), other views._

### Unreal C++ / JSON (MyProjec templates)

File: `UnrealStarter/BasketballGame/FELReadinessTypes.h`

```cpp
// Copyright (c) Final Evolution Lab.
// Mirrors FinalEvolutionLab/Models/PerformanceMetrics.swift (Codable keys).

#pragma once

#include "CoreMinimal.h"
#include "FELReadinessTypes.generated.h"

/** Creator Card → Arena signature move (Economy pillar; parsed from `signature_trait_id` in readiness JSON). */
UENUM(BlueprintType)
enum class EFELSignatureTrait : uint8
{
	None UMETA(DisplayName = "None"),
	Bonds_Apex_Ignition UMETA(DisplayName = "Bonds Apex Ignition"),
	Dojo_Ghost_Strike UMETA(DisplayName = "Dojo Ghost Strike"),
	Neuro_Flow_Teleport UMETA(DisplayName = "Neuro Flow Teleport"),
};

FORCEINLINE EFELSignatureTrait FEL_ParseSignatureTraitId(const FString& Id)
{
	FString L = Id;
	L.ToLowerInline();
	if (L == TEXT("bonds_apex_ignition"))
	{
		return EFELSignatureTrait::Bonds_Apex_Ignition;
	}
	if (L == TEXT("dojo_ghost_strike"))
	{
		return EFELSignatureTrait::Dojo_Ghost_Strike;
	}
	if (L == TEXT("neuro_flow_teleport"))
	{
		return EFELSignatureTrait::Neuro_Flow_Teleport;
	}
	return EFELSignatureTrait::None;
}

USTRUCT(BlueprintType)
struct FFELReadinessSnapshot
{
	GENERATED_BODY()

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL")
	double EfficiencyScore = 0.0;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL")
	double PRQScore = 75.0;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL")
	double ReadinessScore = 0.0;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL")
	double VerticalPotential = 0.0;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL")
	double NeuralDrive = 0.0;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL")
	double PopForce = 0.0;

	/** Scan-derived vertical estimate (inches). Swift `SystemScanResult.verticalEstimateInches`. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|NeuroMechanic")
	double VerticalEstimateInches = 0.0;

	/** 0.75–1.15 typical; scales hang-time / jump apex feel from PRQ + flight time. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|NeuroMechanic")
	double HangTimeScale = 1.0;

	/** 0.55–1.0; reduces effective verticality when ankle/knee/hip scan status is not PRIMED. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|NeuroMechanic")
	double KineticLeakageMultiplier = 1.0;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL")
	FString CurrentOutfit = TEXT("standard");

	/** Swift `GameModeId.rawValue` — drives ArenaSettings + Unreal rules (e.g. `basketball_dunk`, `brain_brawl`). */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Arena")
	FString ActiveArenaMode = TEXT("basketball_h2h");

	// --- System Scan / Athlete Hub (optional keys; Swift `FELBirthReadinessWriter` / extended PRQ export) ---

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Scan")
	FString MovementGrade;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Scan")
	double FlightTimeSeconds = 0.0;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Scan")
	bool bAthletePrimed = false;

	/** 0 = cool (primed joint), 1 = hot (leakage) — Ankle / Knee / Hip kinetic map. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Scan")
	double KineticHeatAnkle = 0.0;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Scan")
	double KineticHeatKnee = 0.0;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Scan")
	double KineticHeatHip = 0.0;

	/** Vertical Velocity Academy — Plyos (`mod9`) mastery: +2% neuro potential in Dunk Contest. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Academy")
	double AcademyPlyosMasteryBonus = 0.0;

	// --- Lab aesthetic / Vault (Swift profile → soft content paths; optional in readiness_snapshot.json) ---

	/** Content path to UTexture2D for Neuro-Mechanic banner/floor (e.g. `/Game/FEL/UI/Brand/T_NeuroMechanic_Logo.T_NeuroMechanic_Logo`). */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Lab|Brand")
	FString NeuroMechanicLogoTexturePath;

	/** Bonds Bounce Blueprint logo for Lab court / decals. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Lab|Brand")
	FString BondsBounceLogoTexturePath;

	/** Up to 3 Creator Card textures for Vault hologram terminal (highest vertical, etc.). */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Lab|Vault")
	TArray<FString> CreatorCardTexturePaths;

	/** Swift one-shot: first Bio-Sync / twin reveal — `UFELCinematicCameraComponent` orbit + Neuro-Flow ignition. Consumed by bridge after play. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Lab|Onboarding")
	bool bPlayTwinBirthCinematicOnce = false;

	/** Holographic welcome line on `AFELVaultHologramTerminalActor` (e.g. shard grant). */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Lab|Onboarding")
	FString LabWelcomeToast;

	/** Shard marketplace exclusive gear — material texture paths for digital twin (Swift `equippedGearTexturePaths`). */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Lab|Economy")
	FString JerseyTexturePath;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Lab|Economy")
	FString ShoeTexturePath;

	/** Aggregated gear buffs from Swift MyTeam economy (1.0–1.05). */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Lab|Economy")
	double GearMotionWarpMultiplier = 1.0;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Lab|Economy")
	double GearJumpVelocityMultiplier = 1.0;

	/** Creator Card "stand" in Lab — drives Neuro-Flow presentation scale. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Lab|MyTeam")
	FString StoodCreatorCardId;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Lab|MyTeam")
	double NeuroFlowIntensityScale = 1.0;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Lab|MyTeam")
	FString StoodCreatorCardTraitLine;

	/** Stood Creator Card — extra jump scale (1.0–1.12) layered after gear jump mult. Swift `stoodCardJumpScale`. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Lab|MyTeam")
	double StoodCardJumpScale = 1.0;

	/** Stood Creator Card — scales primed / neural anim layer alpha (1.0–1.15). Swift `stoodCardNeuralDriveAlpha`. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Lab|MyTeam")
	double StoodCardNeuralDriveAlpha = 1.0;

	/** `standard` | `gold` | `diamond` — Neuro-Flow aura + Vault terminal tint. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Lab|MyTeam")
	FString StoodCardTier = TEXT("standard");

	/** Swift `signature_trait_id` — unlocks `AFELBasketballCharacter::ExecuteSignatureMove` for equipped Creator Card. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Lab|MyTeam|Signature")
	EFELSignatureTrait SignatureTrait = EFELSignatureTrait::None;

	/** Swift `AvatarSkinConfig.heightScale` — vertical scale on skeletal mesh (Z) vs `readiness_snapshot.json` digital twin. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Lab|Avatar")
	double AvatarHeightScale = 1.0;

	/** Swift `AvatarSkinConfig.weightScale` — horizontal blend (X/Y) on mesh for rig parity. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Lab|Avatar")
	double AvatarWeightScale = 1.0;

	/** Swift `sfmaMultiSegmentalRotationPassed` in readiness JSON — drives UFELBiometricOverlays congestion. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|SFMA")
	bool bSFMASpiralRotationScreenPass = true;
};
```

File: `UnrealStarter/BasketballGame/FELArenaDifficultyScaling.h`

```cpp
// Copyright (c) Final Evolution Lab.
// PRQ-driven difficulty: weaker motion-warp pull + heavier "leaky" animation when readiness is low.

#pragma once

#include "CoreMinimal.h"

namespace FELArenaDifficultyScaling
{
	/**
	 * Sovereign Skins / shard gear — 1.0–1.05 multiplier on motion-warp pull and jump velocity (MyTeam economy).
	 * Swift `FELGearBoostCalculator` / `gearJumpVelocityMultiplier` in `readiness_snapshot.json` should mirror these ids
	 * when exporting; `AFELBasketballCharacter::ApplyReadiness` applies C++ `CalculateGearBoost` from jersey/shoe paths
	 * so JumpZ uses the same physical scale in the 3D arena.
	 */
	struct FGearBoostMultipliers
	{
		float MotionWarpMagnetismMult = 1.f;
		float JumpVelocityScaleMult = 1.f;
	};

	/** Maps marketplace gear id (e.g. `gear_jersey_cyan_pulse`) to small buffs; unknown → identity. */
	inline FGearBoostMultipliers CalculateGearBoost(const FString& GearId)
	{
		FGearBoostMultipliers Out;
		// Texture paths from Swift marketplace often include "Sovereign" / folder segments — apply jump scale for equipped jersey/shoes.
		if (GearId.Contains(TEXT("sovereign")) || GearId.Contains(TEXT("Sovereign")))
		{
			Out.MotionWarpMagnetismMult = 1.04f;
			Out.JumpVelocityScaleMult = 1.04f;
		}
		else if (GearId.Contains(TEXT("jersey_cyan")) || GearId.Contains(TEXT("gear_jersey_cyan")))
		{
			Out.MotionWarpMagnetismMult = 1.03f;
			Out.JumpVelocityScaleMult = 1.02f;
		}
		else if (GearId.Contains(TEXT("shoes_signal")) || GearId.Contains(TEXT("gear_shoes_signal")))
		{
			Out.MotionWarpMagnetismMult = 1.02f;
			Out.JumpVelocityScaleMult = 1.04f;
		}
		else if (GearId.Contains(TEXT("outfit_neon")) || GearId.Contains(TEXT("neon")))
		{
			Out.MotionWarpMagnetismMult = 1.02f;
			Out.JumpVelocityScaleMult = 1.02f;
		}
		else if (GearId.Contains(TEXT("outfit_gold")) || GearId.Contains(TEXT("gold")))
		{
			Out.MotionWarpMagnetismMult = 1.05f;
			Out.JumpVelocityScaleMult = 1.05f;
		}
		return Out;
	}

	/**
	 * Sovereign Skins: each equipped jersey/shoe/outfit reduces kinetic leakage by ~1–5% (multiplier toward 1.0 from scan baseline).
	 * Values are per-gear factors in (0.95, 1.0] — multiply together, then clamp to [0.95, 1.0].
	 */
	inline float SkinKineticLeakageScaleFromGearId(const FString& GearId)
	{
		if (GearId.Contains(TEXT("sovereign")) || GearId.Contains(TEXT("Sovereign")))
		{
			return 0.97f;
		}
		if (GearId.Contains(TEXT("jersey_cyan")) || GearId.Contains(TEXT("gear_jersey_cyan")))
		{
			return 0.98f;
		}
		if (GearId.Contains(TEXT("shoes_signal")) || GearId.Contains(TEXT("gear_shoes_signal")))
		{
			return 0.99f;
		}
		if (GearId.Contains(TEXT("outfit_neon")) || GearId.Contains(TEXT("neon")))
		{
			return 0.99f;
		}
		if (GearId.Contains(TEXT("outfit_gold")) || GearId.Contains(TEXT("gold")))
		{
			return 0.95f;
		}
		if (GearId.Contains(TEXT("outfit_shadow")))
		{
			return 0.995f;
		}
		if (GearId.Contains(TEXT("outfit_chrome")))
		{
			return 0.992f;
		}
		return 1.f;
	}

	/** Creator Card “Stand” — extra jump / neural presentation (matches Swift `stoodCard*` export). */
	inline void StoodCardPhysicsFromId(const FString& CardId, float& OutJumpScale, float& OutNeuralAlpha)
	{
		OutJumpScale = 1.f;
		OutNeuralAlpha = 1.f;
		if (CardId.Contains(TEXT("coach_v")))
		{
			OutJumpScale = 1.045f;
			OutNeuralAlpha = 1.08f;
		}
		else if (CardId.Contains(TEXT("bonds_bounce")))
		{
			OutJumpScale = 1.055f;
			OutNeuralAlpha = 1.06f;
		}
		else if (CardId.Contains(TEXT("flight_lab")))
		{
			OutJumpScale = 1.04f;
			OutNeuralAlpha = 1.07f;
		}
		else if (CardId.Contains(TEXT("neural_max")))
		{
			OutJumpScale = 1.03f;
			OutNeuralAlpha = 1.12f;
		}
		OutJumpScale = FMath::Clamp(OutJumpScale, 1.f, 1.08f);
		OutNeuralAlpha = FMath::Clamp(OutNeuralAlpha, 1.f, 1.15f);
	}

	/** Aggregated MyTeam asset boosts — Sovereign Gear leakage reduction + Stood Card jump / neural alpha. */
	struct FAssetBoostResult
	{
		float KineticLeakageScale = 1.f;
		float JumpVelocityScale = 1.f;
		float NeuralDriveAlpha = 1.f;
	};

	inline FAssetBoostResult CalculateAssetBoosts(const TArray<FString>& SovereignSkinGearIds, const FString& StoodCreatorCardId)
	{
		FAssetBoostResult R;
		for (const FString& Id : SovereignSkinGearIds)
		{
			if (Id.IsEmpty())
			{
				continue;
			}
			R.KineticLeakageScale *= SkinKineticLeakageScaleFromGearId(Id);
			const FGearBoostMultipliers G = CalculateGearBoost(Id);
			R.JumpVelocityScale *= G.JumpVelocityScaleMult;
		}
		R.KineticLeakageScale = FMath::Clamp(R.KineticLeakageScale, 0.95f, 1.f);
		R.JumpVelocityScale = FMath::Clamp(R.JumpVelocityScale, 1.f, 1.08f);

		float JS = 1.f;
		float NA = 1.f;
		StoodCardPhysicsFromId(StoodCreatorCardId, JS, NA);
		R.JumpVelocityScale *= JS;
		R.NeuralDriveAlpha = NA;
		R.JumpVelocityScale = FMath::Clamp(R.JumpVelocityScale, 1.f, 1.12f);
		return R;
	}

	/** 0–100 PRQ → 0.35–1.0 magnetism toward full warp targets (rim/goal). Below 60, pull is softened. */
	inline float MotionWarpMagnetismFromPRQ(float PRQ0to100)
	{
		const float P = FMath::Clamp(PRQ0to100, 0.f, 100.f);
		if (P >= 60.f)
		{
			return 1.f;
		}
		return FMath::Lerp(0.35f, 1.f, P / 60.f);
	}

	/** When PRQ < 60, extra reduction of "primed" layer alpha (more fatigued / leaky blend). 0 at PRQ ≥ 60. */
	inline float LeakyAnimLayerExtraFromPRQ(float PRQ0to100)
	{
		const float P = FMath::Clamp(PRQ0to100, 0.f, 100.f);
		if (P >= 60.f)
		{
			return 0.f;
		}
		return FMath::Clamp((60.f - P) / 60.f, 0.f, 1.f) * 0.5f;
	}
}
```

File: `UnrealStarter/BasketballGame/FELReadinessIO.h`

```cpp
// Copyright (c) Final Evolution Lab.

#pragma once

#include "CoreMinimal.h"
#include "FELReadinessTypes.h"

class UWorld;

/** Load JSON snapshot aligned with Swift PerformanceMetrics (camelCase keys). See NEURO_MECHANIC_BRIDGE.md. */
struct FELReadinessIO
{
	/**
	 * Parse JSON string (Swift export / file contents). Keys: efficiencyScore, prqScore, signature_trait_id, readinessScore, verticalPotential, neuralDrive, popForce, verticalEstimateInches, hangTimeScale, kineticLeakageMultiplier, currentOutfit, active_mode.
	 * When `WorldForTravel` is non-null, triggers mandatory `OpenLevel` for the venue matching `active_mode` (MapTravel handshake) after the snapshot is fully parsed.
	 * If `OutIssuedVenueTravel` is set, it receives whether `OpenLevel` was issued (callers should defer `ApplyReadinessToActors` until the new map loads).
	 */
	static bool ParseSnapshotJsonString(const FString& JsonStr, FFELReadinessSnapshot& Out, FString* OutError = nullptr, UWorld* WorldForTravel = nullptr, bool* OutIssuedVenueTravel = nullptr);

	/**
	 * When `active_mode` requests a basketball venue, travel to the canonical Venice Beach 3D shell (Signal Velocity).
	 * Returns true if `OpenLevel` was issued (caller must not touch actors in this frame — world will reload).
	 */
	static bool TryMandatoryVenueTravelForActiveMode(UWorld* World, const FFELReadinessSnapshot& Snap);

	/** Drive level `APostProcessVolume` tagged `FEL_NeuroFlow` from `Snap.PRQScore` (Measure You pillar). */
	static void ApplySystemScanOptics(class APlayerCameraManager* PCM);
	static void ApplyNeuroFlowPostProcessFromSnapshot(UWorld* World, const FFELReadinessSnapshot& Snap);

	/**
	 * Tries, in order: Documents/FEL (iOS, Swift PRQManager), Saved/FEL, Content/FEL/Config.
	 * See FELPlatformPaths::GetReadinessSnapshotCandidatePaths.
	 */
	static bool TryLoadSnapshot(FFELReadinessSnapshot& Out, FString* OutError = nullptr);
};
```

File: `UnrealStarter/BasketballGame/FELReadinessIO.cpp`

```cpp
// Copyright (c) Final Evolution Lab.

#include "FELReadinessIO.h"
#include "FELArenaModeDefinitions.h"
#include "FELDigitalTwinVenuePaths.h"
#include "FELPlatformPaths.h"
#include "Misc/FileHelper.h"
#include "Misc/Paths.h"
#include "Dom/JsonObject.h"
#include "Serialization/JsonReader.h"
#include "Serialization/JsonSerializer.h"
#include "Engine/World.h"
#include "Engine/PostProcessVolume.h"
#include "Kismet/GameplayStatics.h"
#include "FELCameraCompatibility.h"

// UE 5.7: If you branched code that used `FMinimalViewInfo::POV`, replace with flattened fields from
// `PlayerCameraManager->GetCameraCacheView()` — use `.Location`, `.Rotation`, `.FOV` (see FELCameraCompatibility.h).
// Example: `const FVector Loc = FELCameraCompatUE57::GetCameraCacheLocation(PCM);`

bool FELReadinessIO::ParseSnapshotJsonString(const FString& JsonStr, FFELReadinessSnapshot& Out, FString* OutError, UWorld* WorldForTravel, bool* OutIssuedVenueTravel)
{
	TSharedPtr<FJsonObject> Root;
	const TSharedRef<TJsonReader<>> Reader = TJsonReaderFactory<>::Create(JsonStr);
	if (!FJsonSerializer::Deserialize(Reader, Root) || !Root.IsValid())
	{
		if (OutError)
		{
			*OutError = TEXT("Invalid JSON");
		}
		return false;
	}

	auto GetD = [&](const TCHAR* Key, double Default) -> double
	{
		double V = Default;
		if (Root->TryGetNumberField(Key, V) && FMath::IsFinite(V))
		{
			return V;
		}
		return Default;
	};

	Out.EfficiencyScore = GetD(TEXT("efficiencyScore"), 0.0);
	Out.PRQScore = GetD(TEXT("prqScore"), 75.0);
	Out.ReadinessScore = GetD(TEXT("readinessScore"), 0.0);
	Out.VerticalPotential = GetD(TEXT("verticalPotential"), 0.0);
	Out.NeuralDrive = GetD(TEXT("neuralDrive"), 0.0);
	Out.PopForce = GetD(TEXT("popForce"), 0.0);
	Out.VerticalEstimateInches = GetD(TEXT("verticalEstimateInches"), 0.0);
	Out.HangTimeScale = GetD(TEXT("hangTimeScale"), 1.0);
	Out.KineticLeakageMultiplier = GetD(TEXT("kineticLeakageMultiplier"), 1.0);
	FString Outfit = TEXT("standard");
	(void)Root->TryGetStringField(TEXT("currentOutfit"), Outfit);
	Out.CurrentOutfit = Outfit.IsEmpty() ? TEXT("standard") : Outfit;

	// Canonical mode ids: `basketball_h2h`, `basketball_dunk` (aliases `dunk_contest` normalized in `FELArenaModeFromIdString`).
	FString ActiveMode = TEXT("basketball_h2h");
	(void)Root->TryGetStringField(TEXT("active_mode"), ActiveMode);
	Out.ActiveArenaMode = ActiveMode.IsEmpty() ? TEXT("basketball_h2h") : ActiveMode;

	FString MoveGrade;
	if (Root->TryGetStringField(TEXT("movementGrade"), MoveGrade))
	{
		Out.MovementGrade = MoveGrade;
	}
	(void)Root->TryGetNumberField(TEXT("flightTimeSeconds"), Out.FlightTimeSeconds);
	(void)Root->TryGetBoolField(TEXT("isPrimed"), Out.bAthletePrimed);
	(void)Root->TryGetNumberField(TEXT("ankleKineticHeat"), Out.KineticHeatAnkle);
	(void)Root->TryGetNumberField(TEXT("kneeKineticHeat"), Out.KineticHeatKnee);
	(void)Root->TryGetNumberField(TEXT("hipKineticHeat"), Out.KineticHeatHip);
	Out.KineticHeatAnkle = FMath::Clamp(Out.KineticHeatAnkle, 0.0, 1.0);
	Out.KineticHeatKnee = FMath::Clamp(Out.KineticHeatKnee, 0.0, 1.0);
	Out.KineticHeatHip = FMath::Clamp(Out.KineticHeatHip, 0.0, 1.0);

	double PlyosBonus = 0.0;
	(void)Root->TryGetNumberField(TEXT("academyPlyosMasteryBonus"), PlyosBonus);
	Out.AcademyPlyosMasteryBonus = FMath::Clamp(PlyosBonus, 0.0, 0.25);

	FString NMLogo;
	if (Root->TryGetStringField(TEXT("neuroMechanicLogoTexture"), NMLogo))
	{
		Out.NeuroMechanicLogoTexturePath = NMLogo;
	}
	FString BBLogo;
	if (Root->TryGetStringField(TEXT("bondsBounceLogoTexture"), BBLogo))
	{
		Out.BondsBounceLogoTexturePath = BBLogo;
	}
	const TArray<TSharedPtr<FJsonValue>>* CardArr = nullptr;
	if (Root->TryGetArrayField(TEXT("creatorCardTextures"), CardArr) && CardArr)
	{
		Out.CreatorCardTexturePaths.Reset();
		for (const TSharedPtr<FJsonValue>& V : *CardArr)
		{
			if (!V.IsValid())
			{
				continue;
			}
			const FString S = V->AsString();
			if (!S.IsEmpty())
			{
				Out.CreatorCardTexturePaths.Add(S);
				if (Out.CreatorCardTexturePaths.Num() >= 3)
				{
					break;
				}
			}
		}
	}

	bool TwinBirth = false;
	if (Root->TryGetBoolField(TEXT("playTwinBirthCinematicOnce"), TwinBirth))
	{
		Out.bPlayTwinBirthCinematicOnce = TwinBirth;
	}
	bool SfmaPass = true;
	if (Root->TryGetBoolField(TEXT("sfmaMultiSegmentalRotationPassed"), SfmaPass))
	{
		Out.bSFMASpiralRotationScreenPass = SfmaPass;
	}
	FString WelcomeToast;
	if (Root->TryGetStringField(TEXT("labWelcomeToast"), WelcomeToast) && !WelcomeToast.IsEmpty())
	{
		Out.LabWelcomeToast = WelcomeToast;
	}

	FString JerseyTex;
	if (Root->TryGetStringField(TEXT("jerseyTexturePath"), JerseyTex) && !JerseyTex.IsEmpty())
	{
		Out.JerseyTexturePath = JerseyTex;
	}
	FString ShoeTex;
	if (Root->TryGetStringField(TEXT("shoeTexturePath"), ShoeTex) && !ShoeTex.IsEmpty())
	{
		Out.ShoeTexturePath = ShoeTex;
	}

	(void)Root->TryGetNumberField(TEXT("gearMotionWarpMultiplier"), Out.GearMotionWarpMultiplier);
	(void)Root->TryGetNumberField(TEXT("gearJumpVelocityMultiplier"), Out.GearJumpVelocityMultiplier);
	Out.GearMotionWarpMultiplier = FMath::Clamp(Out.GearMotionWarpMultiplier, 1.0, 1.06);
	Out.GearJumpVelocityMultiplier = FMath::Clamp(Out.GearJumpVelocityMultiplier, 1.0, 1.06);

	FString StoodCard;
	if (Root->TryGetStringField(TEXT("stoodCreatorCardId"), StoodCard))
	{
		Out.StoodCreatorCardId = StoodCard;
	}
	(void)Root->TryGetNumberField(TEXT("neuroFlowIntensityScale"), Out.NeuroFlowIntensityScale);
	Out.NeuroFlowIntensityScale = FMath::Clamp(Out.NeuroFlowIntensityScale, 1.0, 1.2);

	FString TraitLine;
	if (Root->TryGetStringField(TEXT("stoodCreatorCardTraitLine"), TraitLine))
	{
		Out.StoodCreatorCardTraitLine = TraitLine;
	}

	(void)Root->TryGetNumberField(TEXT("stoodCardJumpScale"), Out.StoodCardJumpScale);
	(void)Root->TryGetNumberField(TEXT("stoodCardNeuralDriveAlpha"), Out.StoodCardNeuralDriveAlpha);
	Out.StoodCardJumpScale = FMath::Clamp(Out.StoodCardJumpScale, 1.0, 1.12);
	Out.StoodCardNeuralDriveAlpha = FMath::Clamp(Out.StoodCardNeuralDriveAlpha, 1.0, 1.15);

	FString Tier;
	if (Root->TryGetStringField(TEXT("stoodCardTier"), Tier) && !Tier.IsEmpty())
	{
		Out.StoodCardTier = Tier;
	}

	FString SigTraitId;
	if (Root->TryGetStringField(TEXT("signature_trait_id"), SigTraitId) && !SigTraitId.IsEmpty())
	{
		Out.SignatureTrait = FEL_ParseSignatureTraitId(SigTraitId);
	}

	Out.AvatarHeightScale = GetD(TEXT("avatarHeightScale"), 1.0);
	Out.AvatarWeightScale = GetD(TEXT("avatarWeightScale"), 1.0);
	Out.AvatarHeightScale = FMath::Clamp(Out.AvatarHeightScale, 0.65, 1.35);
	Out.AvatarWeightScale = FMath::Clamp(Out.AvatarWeightScale, 0.65, 1.35);

	Out.PRQScore = FMath::Clamp(Out.PRQScore, 0.0, 100.0);
	Out.HangTimeScale = FMath::Clamp(Out.HangTimeScale, 0.5, 1.25);
	Out.KineticLeakageMultiplier = FMath::Clamp(Out.KineticLeakageMultiplier, 0.45, 1.0);

	if (OutIssuedVenueTravel)
	{
		*OutIssuedVenueTravel = false;
	}
	if (WorldForTravel)
	{
		const bool bTraveled = TryMandatoryVenueTravelForActiveMode(WorldForTravel, Out);
		if (OutIssuedVenueTravel)
		{
			*OutIssuedVenueTravel = bTraveled;
		}
	}
	return true;
}

bool FELReadinessIO::TryMandatoryVenueTravelForActiveMode(UWorld* World, const FFELReadinessSnapshot& Snap)
{
	if (!World || !World->IsGameWorld())
	{
		UE_LOG(LogTemp, Warning, TEXT("FELReadiness: TryMandatoryVenueTravel — no game world (viewport may stay uninitialized)."));
		return false;
	}
	if (Snap.ActiveArenaMode.IsEmpty())
	{
		return false;
	}
	const EFELArenaMode Mode = FELArenaModeFromIdString(Snap.ActiveArenaMode);
	FName TargetLevel;
	const FString Current = UGameplayStatics::GetCurrentLevelName(World, true);

	switch (Mode)
	{
	case EFELArenaMode::BasketballHeadToHead:
	case EFELArenaMode::BasketballDunkContest:
	case EFELArenaMode::Basketball3v3:
		if (Current.Contains(TEXT("VeniceBeach")) || Current.Contains(TEXT("VeniceBeach_Arena")))
		{
			UE_LOG(LogTemp, Log, TEXT("FELReadiness: already on Venice (current='%s'); skip OpenLevel."), *Current);
			return false;
		}
		// Cooked .umap must exist at this soft path (see CONFIG_DefaultGame_FEL.ini MapsToCook + FELDigitalTwinVenuePaths).
		TargetLevel = FName(FELDigitalTwinVenuePaths::VeniceBeachArena);
		break;
	case EFELArenaMode::Karate:
		if (Current.Contains(TEXT("Dojo_Stadium")) || Current.Contains(TEXT("Dojo")))
		{
			UE_LOG(LogTemp, Log, TEXT("FELReadiness: already on Dojo (current='%s'); skip OpenLevel."), *Current);
			return false;
		}
		TargetLevel = FName(FELDigitalTwinVenuePaths::DojoStadium);
		break;
	case EFELArenaMode::MarketBrowse:
		// Gold Master: `active_mode` market_browse → `/Game/FEL/Venues/Luma_Venice_Shop` (Luma Venice Shop; see CONFIG_DefaultGame_FEL.ini MapsToCook).
		if (Current.Contains(TEXT("SovereignShop")) || Current.Contains(TEXT("L_SovereignShop_Luma"))
			|| Current.Contains(TEXT("Luma_Venice_Shop")))
		{
			return false;
		}
		TargetLevel = FName(FELDigitalTwinVenuePaths::LumaVeniceShop);
		UE_LOG(LogTemp, Display, TEXT("FELReadiness: market_browse → OpenLevel %s"), FELDigitalTwinVenuePaths::LumaVeniceShop);
		break;
	default:
		UE_LOG(LogTemp, Verbose, TEXT("FELReadiness: mode not mapped to venue travel (active_mode='%s')."), *Snap.ActiveArenaMode);
		return false;
	}

	UE_LOG(LogTemp, Warning, TEXT("FELReadiness: OpenLevel — active_mode='%s' current='%s' target=%s (if load fails, confirm .umap is cooked under this path)."),
		*Snap.ActiveArenaMode,
		*Current,
		*TargetLevel.ToString());
	UGameplayStatics::OpenLevel(World, TargetLevel);
	return true;
}

void FELReadinessIO::ApplyNeuroFlowPostProcessFromSnapshot(UWorld* World, const FFELReadinessSnapshot& Snap)
{
	if (!World || !World->IsGameWorld())
	{
		return;
	}
	const float Prq01 = FMath::Clamp(static_cast<float>(Snap.PRQScore) / 100.f, 0.f, 1.f);
	TArray<AActor*> Found;
	UGameplayStatics::GetAllActorsOfClass(World, APostProcessVolume::StaticClass(), Found);
	for (AActor* A : Found)
	{
		if (!A || !A->ActorHasTag(FName(TEXT("FEL_NeuroFlow"))))
		{
			continue;
		}
		APostProcessVolume* PP = Cast<APostProcessVolume>(A);
		if (!PP)
		{
			continue;
		}
		FPostProcessSettings& S = PP->Settings;
		S.bOverride_BloomIntensity = true;
		S.BloomIntensity = FMath::Lerp(0.65f, 2.2f, Prq01);
		S.bOverride_VignetteIntensity = true;
		S.VignetteIntensity = FMath::Lerp(0.12f, 0.52f, Prq01);
		PP->BlendWeight = FMath::Lerp(0.35f, 1.f, Prq01);
		break;
	}
}

bool FELReadinessIO::TryLoadSnapshot(FFELReadinessSnapshot& Out, FString* OutError)
{
	TArray<FString> Paths;
	FELPlatformPaths::GetReadinessSnapshotCandidatePaths(Paths);

	for (const FString& Path : Paths)
	{
		if (!FPaths::FileExists(Path))
		{
			continue;
		}
		FString Json;
		if (!FFileHelper::LoadFileToString(Json, *Path))
		{
			if (OutError)
			{
				*OutError = FString::Printf(TEXT("Could not read %s"), *Path);
			}
			return false;
		}
		return ParseSnapshotJsonString(Json, Out, OutError);
	}

	if (OutError)
	{
		*OutError = TEXT("No readiness_snapshot.json (checked Documents/FEL, Saved/FEL, Content/FEL/Config)");
	}
	return false;
}

void FELReadinessIO::ApplySystemScanOptics(APlayerCameraManager* PCM)
{
	if (!PCM) return;
	// Use FELCameraCompatibility.h globally in FELReadinessIO.cpp to ensure System Scan optics are identical.
	const FVector Loc = FELCameraCompatUE57::GetCameraCacheLocation(PCM);
	const FRotator Rot = FELCameraCompatUE57::GetCameraCacheRotation(PCM);
	const float CurrentFOV = FELCameraCompatUE57::GetCameraCacheFOV(PCM);
	
	// Enforce default 90 FOV for System Scan parity across iOS, Mac, Switch, PS5
	PCM->SetFOV(90.f);
}
```

File: `UnrealStarter/BasketballGame/FELKineticLeakage.h`

```cpp
// Copyright (c) Final Evolution Lab.
// Neuro-Mechanic: scan-driven reduction of explosive vertical when joints are MODERATE/LEAKING vs PRIMED.

#pragma once

#include "CoreMinimal.h"
#include "FELArenaModeDefinitions.h"
#include "FELArenaRulesTypes.h"
#include "FELJumpTimingTypes.h"
#include "FELReadinessTypes.h"

namespace FELKineticLeakage
{
	/** Applies joint-scan KineticLeakageMultiplier and HangTimeScale to a base jump velocity (cm/s). */
	float ApplyNeuroMechanicJump(float BaseJumpZ, const FFELReadinessSnapshot& Snap);

	/** Optional sprint cap modifier (same leakage curve). */
	float ApplyNeuroMechanicWalkSpeed(float BaseSpeed, const FFELReadinessSnapshot& Snap);

	/**
	 * Dynamic Bonds Bounce timing: maps seconds spent in a fast approach (gather) into [~0.5, 1.0] realized impulse.
	 * Gaussian ideal ~0.28s; early/late tails are "Leaky" bands for animation / feel (not a flat multiplier).
	 */
	float ComputeBondsBounceTimingLeakage(float SecondsInApproachRun, EFELJumpTimingBand& OutBand);

	/**
	 * Lateral kinetic leakage (Tennis / Soccer / Football): hard cuts with low neural drive → speed penalty.
	 * Returns a multiplier in ~[0.5, 1] applied to MaxWalkSpeed on top of scan leakage.
	 */
	float ApplyLateralCutWalkMultiplier(
		float NeuralDrive0to100,
		float KineticLeakageMultiplier,
		float LateralStrain01,
		EFELArenaMode Mode,
		const FFELSportNeuroConstants& Sport);
}
```

File: `UnrealStarter/BasketballGame/FELKineticLeakage.cpp`

```cpp
// Copyright (c) Final Evolution Lab.

#include "FELKineticLeakage.h"
#include "FELArenaModeDefinitions.h"

namespace
{
	float GetLateralStrainThresholdForMode(const EFELArenaMode Mode, const FFELSportNeuroConstants& C)
	{
		switch (Mode)
		{
		case EFELArenaMode::Tennis:
			return C.TennisLateralStrainThreshold;
		case EFELArenaMode::Soccer:
			return C.SoccerLateralStrainThreshold;
		case EFELArenaMode::Football:
			return C.FootballLateralStrainThreshold;
		default:
			return 1.f;
		}
	}
}

float FELKineticLeakage::ApplyLateralCutWalkMultiplier(
	const float NeuralDrive0to100,
	const float KineticLeakageMultiplier,
	const float LateralStrain01,
	const EFELArenaMode Mode,
	const FFELSportNeuroConstants& Sport)
{
	if (Mode != EFELArenaMode::Tennis && Mode != EFELArenaMode::Soccer && Mode != EFELArenaMode::Football)
	{
		return 1.f;
	}
	const float Thresh = GetLateralStrainThresholdForMode(Mode, Sport);
	if (LateralStrain01 < Thresh)
	{
		return 1.f;
	}
	if (NeuralDrive0to100 >= Sport.LateralNeuralDriveRequired)
	{
		return 1.f;
	}
	const float Leak = FMath::Clamp(KineticLeakageMultiplier, 0.45f, 1.f);
	const float Penalty = FMath::Lerp(Sport.LateralWalkPenaltyMin, 1.f, NeuralDrive0to100 / 100.f);
	return FMath::Clamp(Penalty * Leak, 0.45f, 1.f);
}

float FELKineticLeakage::ComputeBondsBounceTimingLeakage(float SecondsInApproachRun, EFELJumpTimingBand& OutBand)
{
	OutBand = EFELJumpTimingBand::None;
	const float T = FMath::Max(0.f, SecondsInApproachRun);
	// Ideal gather commit (~180–320 ms sprint into jump); sigma defines tolerance.
	static constexpr float IdealSec = 0.28f;
	static constexpr float SigmaSec = 0.15f;
	const float X = (T - IdealSec) / FMath::Max(1e-3f, SigmaSec);
	const float G = FMath::Exp(-0.5f * X * X);
	// Realized fraction: floor 0.48 at worst timing, 1.0 at ideal.
	const float Leak = FMath::Lerp(0.48f, 1.f, G);

	if (G >= 0.88f)
	{
		OutBand = EFELJumpTimingBand::Perfect;
	}
	else if (G >= 0.48f)
	{
		OutBand = EFELJumpTimingBand::Good;
	}
	else
	{
		OutBand = (T < IdealSec) ? EFELJumpTimingBand::Early : EFELJumpTimingBand::Late;
	}
	return FMath::Clamp(Leak, 0.45f, 1.f);
}

float FELKineticLeakage::ApplyNeuroMechanicJump(float BaseJumpZ, const FFELReadinessSnapshot& Snap)
{
	const float Leak = FMath::Clamp(static_cast<float>(Snap.KineticLeakageMultiplier), 0.55f, 1.f);
	const float Hang = FMath::Clamp(static_cast<float>(Snap.HangTimeScale), 0.75f, 1.15f);
	return BaseJumpZ * Leak * Hang;
}

float FELKineticLeakage::ApplyNeuroMechanicWalkSpeed(float BaseSpeed, const FFELReadinessSnapshot& Snap)
{
	const float Leak = FMath::Clamp(static_cast<float>(Snap.KineticLeakageMultiplier), 0.55f, 1.f);
	return BaseSpeed * FMath::Lerp(0.92f, 1.f, Leak);
}
```

File: `UnrealStarter/BasketballGame/FELSessionExport.h`

```cpp
// Copyright (c) Final Evolution Lab.
// Writes JSON shaped for Swift GameSessionResult (camelCase).

#pragma once

#include "CoreMinimal.h"
#include "FELMatchTypes.h"

class AFELBasketballGameState;
class UWorld;

struct FELSessionExport
{
	/** Legacy filename under FEL data dir. */
	static bool WriteLastSession(const AFELBasketballGameState* GS, UWorld* World, FString* OutError = nullptr);

	/**
	 * Production session_results.json (Swift GameSessionResult keys + neuro fields + masteryScore/masteryMetric).
	 * Includes nested `arena_result` (`FFELArenaResult`) for Vault / economy handshake.
	 * Writes to Documents/FEL on iOS (see FELPlatformPaths).
	 */
	static bool WriteSessionResults(const FFELMatchResultSummary& Summary, const FString& ArenaGameModeId, FString* OutError = nullptr);
};
```

File: `UnrealStarter/BasketballGame/FELSessionExport.cpp`

```cpp
// Copyright (c) Final Evolution Lab.

#include "FELSessionExport.h"
#include "FELArenaBridge.h"
#include "FELBasketballGameState.h"
#include "FELPlatformPaths.h"
#include "HAL/PlatformFilemanager.h"
#include "Misc/FileHelper.h"
#include "Misc/Guid.h"
#include "Misc/Paths.h"
#include "Serialization/JsonSerializer.h"
#include "Serialization/JsonWriter.h"

static double SwiftReferenceDateSeconds()
{
	static const FDateTime kRef(2001, 1, 1);
	return (FDateTime::UtcNow() - kRef).GetTotalSeconds();
}

bool FELSessionExport::WriteLastSession(const AFELBasketballGameState* GS, UWorld* World, FString* OutError)
{
	if (!GS || !World)
	{
		return false;
	}

	const bool bEconomy = GS->IsScoringEnabled();
	const int32 Score = GS->GetScore();
	const double PRQ = GS->GetReadinessSnapshot().PRQScore;
	const FString& ModeId = GS->GetArenaGameModeId();

	const int32 Shards = FELArenaBridge::ComputeShardsEarned(Score, PRQ, ModeId, bEconomy);
	const double Bonus = FELArenaBridge::ComputePRQBonus(Score, PRQ, bEconomy);

	const double StartT = GS->GetMatchStartWorldTimeSeconds();
	const float Now = World->GetTimeSeconds();
	const int32 DurationSecs = FMath::Max(0, FMath::RoundToInt(static_cast<double>(Now) - StartT));

	TSharedPtr<FJsonObject> O = MakeShared<FJsonObject>();
	O->SetStringField(TEXT("id"), FGuid::NewGuid().ToString(EGuidFormats::DigitsWithHyphens));
	O->SetStringField(TEXT("gameModeId"), ModeId);
	O->SetNumberField(TEXT("date"), SwiftReferenceDateSeconds());
	O->SetNumberField(TEXT("score"), static_cast<double>(Score));
	O->SetNumberField(TEXT("opponentScore"), 0.0);
	O->SetNumberField(TEXT("shardsEarned"), static_cast<double>(Shards));
	O->SetNumberField(TEXT("prqBonus"), Bonus);
	O->SetBoolField(TEXT("isMultiplayer"), false);
	O->SetNumberField(TEXT("duration"), static_cast<double>(DurationSecs));
	if (bEconomy)
	{
		O->SetNumberField(TEXT("roundsPlayed"), static_cast<double>(Score));
	}

	FString OutStr;
	const TSharedRef<TJsonWriter<TCHAR, TCondensedJsonPrintPolicy<TCHAR>>> Writer =
		TJsonWriterFactory<TCHAR, TCondensedJsonPrintPolicy<TCHAR>>::Create(&OutStr);
	if (!FJsonSerializer::Serialize(O.ToSharedRef(), Writer))
	{
		if (OutError)
		{
			*OutError = TEXT("JSON serialize failed");
		}
		return false;
	}

	const FString Dir = FELPlatformPaths::GetFELDataDirectory();
	IPlatformFile& PF = FPlatformFileManager::Get().GetPlatformFile();
	if (!PF.DirectoryExists(*Dir))
	{
		PF.CreateDirectoryTree(*Dir);
	}

	const FString Path = Dir / TEXT("last_session_result.json");
	if (!FFileHelper::SaveStringToFile(OutStr, *Path))
	{
		if (OutError)
		{
			*OutError = FString::Printf(TEXT("Could not write %s"), *Path);
		}
		return false;
	}
	return true;
}

bool FELSessionExport::WriteSessionResults(const FFELMatchResultSummary& Summary, const FString& ArenaGameModeId, FString* OutError)
{
	TSharedPtr<FJsonObject> O = MakeShared<FJsonObject>();
	O->SetStringField(TEXT("id"), FGuid::NewGuid().ToString(EGuidFormats::DigitsWithHyphens));
	O->SetStringField(TEXT("gameModeId"), ArenaGameModeId.IsEmpty() ? Summary.GameModeId : ArenaGameModeId);
	O->SetNumberField(TEXT("date"), SwiftReferenceDateSeconds());
	O->SetNumberField(TEXT("score"), static_cast<double>(Summary.Score));
	O->SetNumberField(TEXT("opponentScore"), static_cast<double>(Summary.OpponentScore));
	O->SetNumberField(TEXT("shardsEarned"), static_cast<double>(Summary.ShardsEarned));
	O->SetNumberField(TEXT("prqBonus"), Summary.PRQBonus);
	O->SetBoolField(TEXT("isMultiplayer"), false);
	O->SetNumberField(TEXT("duration"), static_cast<double>(Summary.DurationSeconds));
	if (Summary.bEconomy && Summary.Score > 0)
	{
		O->SetNumberField(TEXT("roundsPlayed"), static_cast<double>(Summary.Score));
	}
	// Optional for Swift; ignored by Codable if model not extended.
	O->SetNumberField(TEXT("neuroPerformance"), Summary.NeuroPerformanceScore);
	O->SetNumberField(TEXT("mentalSharpness"), Summary.MentalSharpnessScore);
	O->SetNumberField(TEXT("brainBrawlBoostCount"), static_cast<double>(Summary.BrainBrawlBoostCount));
	O->SetNumberField(TEXT("xpEarned"), static_cast<double>(Summary.XPEarned));
	O->SetNumberField(TEXT("masteryScore"), Summary.MasteryScore);
	O->SetStringField(TEXT("masteryMetric"), Summary.MasteryMetricId);

	if (Summary.AcademyCompletedModuleKeys.Num() > 0 || Summary.AcademyEvolutionShardsEarned > 0)
	{
		TSharedPtr<FJsonObject> AP = MakeShared<FJsonObject>();
		TArray<TSharedPtr<FJsonValue>> ModArr;
		ModArr.Reserve(Summary.AcademyCompletedModuleKeys.Num());
		for (const FString& K : Summary.AcademyCompletedModuleKeys)
		{
			ModArr.Add(MakeShared<FJsonValueString>(K));
		}
		AP->SetArrayField(TEXT("completed_module_ids"), ModArr);
		AP->SetNumberField(TEXT("evolution_shards_earned"), static_cast<double>(Summary.AcademyEvolutionShardsEarned));
		O->SetObjectField(TEXT("academy_progress"), AP);
	}

	{
		const FFELArenaResult& A = Summary.ArenaResult;
		TSharedPtr<FJsonObject> AR = MakeShared<FJsonObject>();
		AR->SetNumberField(TEXT("final_score"), static_cast<double>(A.FinalScore));
		AR->SetNumberField(TEXT("new_prq_estimate"), A.NewPRQEstimate);
		AR->SetNumberField(TEXT("evolution_shards_earned"), static_cast<double>(A.EvolutionShardsEarned));
		AR->SetNumberField(TEXT("perfect_timing_count"), static_cast<double>(A.PerfectTimingCount));
		AR->SetBoolField(TEXT("best_moment_replay_available"), A.bBestMomentReplayAvailable);
		O->SetObjectField(TEXT("arena_result"), AR);
	}

	FString OutStr;
	const TSharedRef<TJsonWriter<TCHAR, TCondensedJsonPrintPolicy<TCHAR>>> Writer =
		TJsonWriterFactory<TCHAR, TCondensedJsonPrintPolicy<TCHAR>>::Create(&OutStr);
	if (!FJsonSerializer::Serialize(O.ToSharedRef(), Writer))
	{
		if (OutError)
		{
			*OutError = TEXT("JSON serialize failed");
		}
		return false;
	}

	const FString Dir = FELPlatformPaths::GetFELDataDirectory();
	IPlatformFile& PF = FPlatformFileManager::Get().GetPlatformFile();
	if (!PF.DirectoryExists(*Dir))
	{
		PF.CreateDirectoryTree(*Dir);
	}

	const FString Path = FELPlatformPaths::GetSessionResultsJsonPath();
	if (!FFileHelper::SaveStringToFile(OutStr, *Path))
	{
		if (OutError)
		{
			*OutError = FString::Printf(TEXT("Could not write %s"), *Path);
		}
		return false;
	}
	return true;
}
```

File: `UnrealStarter/BasketballGame/UFELAssetRegistrySubsystem.h`

```cpp
// Copyright (c) Final Evolution Lab.
// Global 3D registry: venue levels, Academy mocap montages, Digital Twin mesh — async warm-up + purge for Gold Master memory budget.

#pragma once

#include "CoreMinimal.h"
#include "FELArenaModeDefinitions.h"
#include "Subsystems/GameInstanceSubsystem.h"
#include "Engine/PrimaryAssetId.h"
#include "Engine/SkeletalMesh.h"
#include "Engine/StreamableManager.h"
#include "Templates/SharedPointer.h"
#include "UObject/SoftObjectPtr.h"
#include "UFELAssetRegistrySubsystem.generated.h"

class UWorld;
class UAnimMontage;
class USkeletalMesh;

/**
 * Central registry for soft paths + async warm-up handles.
 * Venues: one UWorld per EFELArenaMode (assign real maps in editor via subsystem defaults or project config).
 * Academy: mod1…mod12 → DeepMotion-exported montages.
 */
UCLASS()
class FINALEVOLUTIONLAB_API UFELAssetRegistrySubsystem : public UGameInstanceSubsystem
{
	GENERATED_BODY()

public:
	virtual void Initialize(FSubsystemCollectionBase& Collection) override;
	virtual void Deinitialize() override;

	/** 12 sport venues — Venice Beach, Dojo, etc. (content paths). */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "FEL|Registry|Venues")
	TMap<EFELArenaMode, TSoftObjectPtr<UWorld>> VenueWorldByArenaMode;

	/** Vertical Velocity Academy module keys (mod1…mod12) → demonstration montages under /Game/FEL/DeepMotion/… */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "FEL|Registry|Academy")
	TMap<FString, TSoftObjectPtr<UAnimMontage>> AcademyModuleDemonstrationMontage;

	/** Scan-calibrated Digital Twin (same family as AFELBasketballCharacter mesh). */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "FEL|Registry|Avatar")
	TSoftObjectPtr<USkeletalMesh> DigitalTwinSkeletalMesh;

	/**
	 * Optional per-mode PrimaryAssetLabel bundles (FELVenue — see CONFIG_DefaultGame_FEL.ini AssetManagerSettings).
	 * When set, Bio-Sync warm-up loads this bundle atomically (twin mesh + Niagara + Luma textures) instead of separate soft paths.
	 */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "FEL|Registry|Bundles")
	TMap<EFELArenaMode, FPrimaryAssetId> VenuePrimaryAssetBundles;

	/** When Swift Bio-Sync / readiness snapshot arrives: preload twin mesh + active venue in background (signal velocity). */
	UFUNCTION(BlueprintCallable, Category = "FEL|Registry|WarmUp")
	void WarmUpForBioSync(EFELArenaMode ActiveMode);

	/** Release streamable handles for a venue slice (call when leaving a mode). */
	UFUNCTION(BlueprintCallable, Category = "FEL|Registry|Memory")
	void PurgeVenueForMode(EFELArenaMode Mode);

	/** Optional: clear all warm-up handles (e.g. Lab shell exit). */
	UFUNCTION(BlueprintCallable, Category = "FEL|Registry|Memory")
	void PurgeAllVenueWarmHandles();

	UFUNCTION(BlueprintPure, Category = "FEL|Registry|Academy")
	bool HasModuleDemonstrationMontage(const FString& ModuleKey) const;

	UFUNCTION(BlueprintCallable, Category = "FEL|Registry|Academy")
	UAnimMontage* ResolveModuleDemonstrationMontage(const FString& ModuleKey, bool bLoadSynchronously);

	UFUNCTION(BlueprintPure, Category = "FEL|Registry|Academy")
	TSoftObjectPtr<UAnimMontage> GetModuleDemonstrationMontageSoft(const FString& ModuleKey) const;

	/** Async montage resolve — OnComplete fires when load finishes (or immediately if already resident). */
	TSharedPtr<FStreamableHandle> RequestAsyncDemonstrationMontage(
		const FString& ModuleKey,
		FStreamableDelegate OnComplete);

	UFUNCTION(BlueprintPure, Category = "FEL|Registry")
	bool HasCompletedBioSyncWarmUp() const { return bBioSyncWarmUpFinished; }

private:
	void SeedDefaultMapsIfEmpty();
	void OnBioSyncWarmUpFinished();

	FStreamableManager StreamableManager;
	TSharedPtr<FStreamableHandle> BioSyncWarmHandle;
	TMap<EFELArenaMode, TSharedPtr<FStreamableHandle>> VenueWarmHandlesByMode;
	bool bBioSyncWarmUpFinished = false;
};
```

File: `UnrealStarter/BasketballGame/UFELAssetRegistrySubsystem.cpp`

```cpp
// Copyright (c) Final Evolution Lab.

#include "UFELAssetRegistrySubsystem.h"
#include "FELDigitalTwinVenuePaths.h"
#include "Animation/AnimMontage.h"
#include "Engine/AssetManager.h"
#include "Engine/World.h"
#include "Serialization/AsyncLoading.h"

namespace
{
	static FSoftObjectPath DefaultVenuePathForMode(const EFELArenaMode Mode)
	{
		switch (Mode)
		{
		case EFELArenaMode::BasketballHeadToHead:
			return FSoftObjectPath(FELDigitalTwinVenuePaths::VeniceBeachArena);
		case EFELArenaMode::BasketballDunkContest:
			return FSoftObjectPath(TEXT("/Game/FEL/Venues/DunkArena/DunkArena.DunkArena"));
		case EFELArenaMode::Basketball3v3:
			return FSoftObjectPath(TEXT("/Game/FEL/Venues/StreetCourt3v3/StreetCourt3v3.StreetCourt3v3"));
		case EFELArenaMode::Karate:
			return FSoftObjectPath(FELDigitalTwinVenuePaths::DojoStadium);
		case EFELArenaMode::Baseball:
			return FSoftObjectPath(TEXT("/Game/FEL/Venues/BaseballPark/BaseballPark.BaseballPark"));
		case EFELArenaMode::Football:
			return FSoftObjectPath(TEXT("/Game/FEL/Venues/Gridiron/Gridiron.Gridiron"));
		case EFELArenaMode::Soccer:
			return FSoftObjectPath(TEXT("/Game/FEL/Venues/Pitch/Pitch.Pitch"));
		case EFELArenaMode::Golf:
			return FSoftObjectPath(TEXT("/Game/FEL/Venues/Links/Links.Links"));
		case EFELArenaMode::Tennis:
			return FSoftObjectPath(TEXT("/Game/FEL/Venues/TennisCourt/TennisCourt.TennisCourt"));
		case EFELArenaMode::Volleyball:
			return FSoftObjectPath(TEXT("/Game/FEL/Venues/SandCourt/SandCourt.SandCourt"));
		case EFELArenaMode::Gymnastics:
			return FSoftObjectPath(TEXT("/Game/FEL/Venues/TrainingFloor/TrainingFloor.TrainingFloor"));
		case EFELArenaMode::BrainBrawl:
			return FSoftObjectPath(TEXT("/Game/FEL/Venues/NeuroArena/NeuroArena.NeuroArena"));
		case EFELArenaMode::MarketBrowse:
			return FSoftObjectPath(FELDigitalTwinVenuePaths::LumaVeniceShop);
		default:
			return FSoftObjectPath(FELDigitalTwinVenuePaths::VeniceBeachArena);
		}
	}

	static FSoftObjectPath DefaultDeepMotionMontagePath(const int32 ModuleIndex1Based)
	{
		return FSoftObjectPath(*FString::Printf(
			TEXT("/Game/FEL/DeepMotion/Demo_mod%d/Demo_mod%d.Demo_mod%d"),
			ModuleIndex1Based,
			ModuleIndex1Based,
			ModuleIndex1Based));
	}
}

void UFELAssetRegistrySubsystem::Initialize(FSubsystemCollectionBase& Collection)
{
	Super::Initialize(Collection);
	SeedDefaultMapsIfEmpty();
}

void UFELAssetRegistrySubsystem::Deinitialize()
{
	PurgeAllVenueWarmHandles();
	if (BioSyncWarmHandle.IsValid())
	{
		BioSyncWarmHandle->CancelHandle();
		BioSyncWarmHandle.Reset();
	}
	Super::Deinitialize();
}

void UFELAssetRegistrySubsystem::SeedDefaultMapsIfEmpty()
{
	if (VenueWorldByArenaMode.Num() == 0)
	{
		static const EFELArenaMode kModes[] = {
			EFELArenaMode::BasketballHeadToHead,
			EFELArenaMode::BasketballDunkContest,
			EFELArenaMode::Basketball3v3,
			EFELArenaMode::Karate,
			EFELArenaMode::Baseball,
			EFELArenaMode::Football,
			EFELArenaMode::Soccer,
			EFELArenaMode::Golf,
			EFELArenaMode::Tennis,
			EFELArenaMode::Volleyball,
			EFELArenaMode::Gymnastics,
			EFELArenaMode::BrainBrawl,
			EFELArenaMode::MarketBrowse,
		};
		for (EFELArenaMode M : kModes)
		{
			TSoftObjectPtr<UWorld> W;
			W = TSoftObjectPtr<UWorld>(DefaultVenuePathForMode(M));
			VenueWorldByArenaMode.Add(M, W);
		}
	}

	if (AcademyModuleDemonstrationMontage.Num() == 0)
	{
		for (int32 i = 1; i <= 12; ++i)
		{
			const FString Key = FString::Printf(TEXT("mod%d"), i);
			TSoftObjectPtr<UAnimMontage> Montage;
			Montage = TSoftObjectPtr<UAnimMontage>(DefaultDeepMotionMontagePath(i));
			AcademyModuleDemonstrationMontage.Add(Key, Montage);
		}
	}

	if (DigitalTwinSkeletalMesh.IsNull())
	{
		DigitalTwinSkeletalMesh = TSoftObjectPtr<USkeletalMesh>(
			FSoftObjectPath(TEXT("/Game/FEL/Characters/ElijahBonds/SKM_ElijahBonds_Walking.SKM_ElijahBonds_Walking")));
	}
}

void UFELAssetRegistrySubsystem::WarmUpForBioSync(const EFELArenaMode ActiveMode)
{
	bBioSyncWarmUpFinished = false;
	if (BioSyncWarmHandle.IsValid())
	{
		BioSyncWarmHandle->CancelHandle();
		BioSyncWarmHandle.Reset();
	}

	if (UAssetManager::IsInitialized())
	{
		if (const FPrimaryAssetId* BundleId = VenuePrimaryAssetBundles.Find(ActiveMode))
		{
			if (BundleId->IsValid())
			{
				UAssetManager::Get().LoadPrimaryAsset(
					*BundleId,
					TArray<FName>(),
					FStreamableDelegate::CreateUObject(this, &UFELAssetRegistrySubsystem::OnBioSyncWarmUpFinished));
				return;
			}
		}
	}

	TArray<FSoftObjectPath> Paths;
	if (!DigitalTwinSkeletalMesh.IsNull())
	{
		Paths.Add(DigitalTwinSkeletalMesh.ToSoftObjectPath());
	}
	if (const TSoftObjectPtr<UWorld>* Venue = VenueWorldByArenaMode.Find(ActiveMode))
	{
		if (!Venue->IsNull())
		{
			Paths.Add(Venue->ToSoftObjectPath());
		}
	}

	if (Paths.Num() == 0)
	{
		OnBioSyncWarmUpFinished();
		return;
	}

	BioSyncWarmHandle = StreamableManager.RequestAsyncLoad(
		Paths,
		FStreamableDelegate::CreateUObject(this, &UFELAssetRegistrySubsystem::OnBioSyncWarmUpFinished));

	if (const TSoftObjectPtr<UWorld>* Venue = VenueWorldByArenaMode.Find(ActiveMode))
	{
		if (!Venue->IsNull())
		{
			if (TSharedPtr<FStreamableHandle>* Existing = VenueWarmHandlesByMode.Find(ActiveMode))
			{
				if (Existing->IsValid())
				{
					(*Existing)->ReleaseHandle();
				}
			}
			VenueWarmHandlesByMode.Remove(ActiveMode);
			VenueWarmHandlesByMode.Add(ActiveMode, BioSyncWarmHandle);
		}
	}
}

void UFELAssetRegistrySubsystem::OnBioSyncWarmUpFinished()
{
	bBioSyncWarmUpFinished = true;
}

void UFELAssetRegistrySubsystem::PurgeVenueForMode(const EFELArenaMode Mode)
{
	if (TSharedPtr<FStreamableHandle>* H = VenueWarmHandlesByMode.Find(Mode))
	{
		if (H->IsValid())
		{
			(*H)->ReleaseHandle();
		}
		VenueWarmHandlesByMode.Remove(Mode);
	}
	if (UAssetManager* AM = UAssetManager::GetIfValid())
	{
		if (const FPrimaryAssetId* BundleId = VenuePrimaryAssetBundles.Find(Mode))
		{
			if (BundleId->IsValid())
			{
				AM->UnloadPrimaryAsset(*BundleId, true);
			}
		}
	}
	FlushAsyncLoading();
}

void UFELAssetRegistrySubsystem::PurgeAllVenueWarmHandles()
{
	for (auto& Pair : VenueWarmHandlesByMode)
	{
		if (Pair.Value.IsValid())
		{
			Pair.Value->ReleaseHandle();
		}
	}
	VenueWarmHandlesByMode.Empty();
	if (UAssetManager::IsInitialized())
	{
		for (const TPair<EFELArenaMode, FPrimaryAssetId>& P : VenuePrimaryAssetBundles)
		{
			if (P.Value.IsValid())
			{
				UAssetManager::Get().UnloadPrimaryAsset(P.Value, true);
			}
		}
	}
	FlushAsyncLoading();
}

bool UFELAssetRegistrySubsystem::HasModuleDemonstrationMontage(const FString& ModuleKey) const
{
	const TSoftObjectPtr<UAnimMontage>* Found = AcademyModuleDemonstrationMontage.Find(ModuleKey);
	return Found && !Found->IsNull();
}

UAnimMontage* UFELAssetRegistrySubsystem::ResolveModuleDemonstrationMontage(const FString& ModuleKey, const bool bLoadSynchronously)
{
	const TSoftObjectPtr<UAnimMontage>* Found = AcademyModuleDemonstrationMontage.Find(ModuleKey);
	if (!Found || Found->IsNull())
	{
		return nullptr;
	}
	if (bLoadSynchronously)
	{
		return Found->LoadSynchronous();
	}
	return Found->Get();
}

TSoftObjectPtr<UAnimMontage> UFELAssetRegistrySubsystem::GetModuleDemonstrationMontageSoft(const FString& ModuleKey) const
{
	if (const TSoftObjectPtr<UAnimMontage>* Found = AcademyModuleDemonstrationMontage.Find(ModuleKey))
	{
		return *Found;
	}
	return TSoftObjectPtr<UAnimMontage>();
}

TSharedPtr<FStreamableHandle> UFELAssetRegistrySubsystem::RequestAsyncDemonstrationMontage(
	const FString& ModuleKey,
	FStreamableDelegate OnComplete)
{
	const TSoftObjectPtr<UAnimMontage>* Found = AcademyModuleDemonstrationMontage.Find(ModuleKey);
	if (!Found || Found->IsNull())
	{
		if (OnComplete.IsBound())
		{
			OnComplete.Execute();
		}
		return nullptr;
	}
	if (Found->Get())
	{
		if (OnComplete.IsBound())
		{
			OnComplete.Execute();
		}
		return nullptr;
	}
	// StreamableManager invokes OnComplete on the game thread when the asset finishes loading.
	return StreamableManager.RequestAsyncLoad(Found->ToSoftObjectPath(), OnComplete);
}
```

File: `UnrealStarter/BasketballGame/example_readiness_snapshot.json`

```json
{
  "academyPlyosMasteryBonus": 0.02,
  "active_mode": "basketball_h2h",
  "ankleKineticHeat": 0.48,
  "currentOutfit": "standard",
  "efficiencyScore": 62.5,
  "flightTimeSeconds": 0.52,
  "hangTimeScale": 0.98,
  "hipKineticHeat": 0.12,
  "isPrimed": true,
  "kineticLeakageMultiplier": 0.91,
  "kneeKineticHeat": 0.12,
  "movementGrade": "FLIGHT READY",
  "neuralDrive": 55,
  "popForce": 48,
  "prqScore": 88,
  "neuroMechanicLogoTexture": "/Game/FEL/UI/Brand/T_NeuroMechanic_Logo.T_NeuroMechanic_Logo",
  "bondsBounceLogoTexture": "/Game/FEL/UI/Brand/T_BondsBounce_Logo.T_BondsBounce_Logo",
  "creatorCardTextures": [
    "/Game/FEL/UI/Cards/T_Creator_Vertical.T_Creator_Vertical",
    "/Game/FEL/UI/Cards/T_Creator_Speed.T_Creator_Speed",
    "/Game/FEL/UI/Cards/T_Creator_Recovery.T_Creator_Recovery"
  ],
  "readinessScore": 71,
  "signature_trait_id": "bonds_apex_ignition",
  "verticalEstimateInches": 32,
  "verticalPotential": 64
}
```

File: `UnrealStarter/BasketballGame/FELBasketballCharacter.h`

```cpp
// Copyright (c) Final Evolution Lab. Copy into your game module (e.g. Source/FinalEvolutionLab/).

#pragma once

#include "CoreMinimal.h"
#include "UObject/PropertyChangedEvent.h"
#include "FELArenaRulesTypes.h"
#include "FELJumpTimingTypes.h"
#include "FELReadinessTypes.h"
#include "IFELBiometricReceiver.h"
#include "Camera/CameraShakeBase.h"
#include "GameFramework/Character.h"
#include "Materials/MaterialInstanceDynamic.h"
#include "FELBasketballCharacter.generated.h"

DECLARE_DYNAMIC_MULTICAST_DELEGATE(FFELOnPerfectDunk);
DECLARE_DYNAMIC_MULTICAST_DELEGATE(FFELOnPerfectStrike);

class USpringArmComponent;
class UCameraComponent;
class UPointLightComponent;
class UNiagaraSystem;
class USoundBase;
class USoundAttenuation;
class USoundMix;
class UMaterialInterface;
class UTexture2D;
class UMotionWarpingComponent;
class UFELLandingIKComponent;
class UFELCinematicCameraComponent;

struct FFELArenaRules;

/**
 * Third-person character using the Elijah Bonds skeletal mesh (default path in .cpp).
 */
UCLASS()
class FINALEVOLUTIONLAB_API AFELBasketballCharacter : public ACharacter, public IFELBiometricReceiver
{
	GENERATED_BODY()

public:
	AFELBasketballCharacter(const FObjectInitializer& ObjectInitializer);

	virtual void ApplyBiometricContext_Implementation(const FFELBiometricContext& Context) override;

	/** Jump / sprint tuning from scan metrics (see VISION_ALIGNMENT.md). */
	void ApplyReadiness(const FFELReadinessSnapshot& Snap);

	/** After ApplyReadiness: optional scales from ArenaSettings.json. Arena Dunk vs Lab Dunk: leakage is always applied inside ApplyReadiness (GAMEPLAY_STATUS parity). */
	void ApplyArenaPhysicsLayer(const FFELArenaRules& Rules);

	/**
	 * Dunk contest hang-time + neuro-drive VFX: call after ApplyReadiness + ApplyArenaPhysicsLayer from the neuro bridge.
	 * Uses Rules.bIsDunkContest + snapshot HangTimeScale / NeuralDrive.
	 */
	void ApplyNeuroArenaGameplay(const FFELReadinessSnapshot& Snap, const FFELArenaRules& Rules);

	/** First Bio-Sync: twin reveal orbit + Neuro-Flow ignition (driven by readiness `bPlayTwinBirthCinematicOnce`). */
	UFUNCTION(BlueprintCallable, Category = "FEL|Onboarding")
	void PlayTwinBirthIntro(float DurationSeconds = 3.f);

	/** Last Bonds Bounce timing evaluation (Blueprint → "Leaky" anim layer when Early/Late). */
	UPROPERTY(BlueprintReadOnly, Category = "FEL|Neuro")
	EFELJumpTimingBand LastJumpTimingBand = EFELJumpTimingBand::None;

	/** 0.45–1.0 realized fraction from input timing alone (after snapshot pipeline). */
	UPROPERTY(BlueprintReadOnly, Category = "FEL|Neuro")
	float LastJumpTimingLeakFactor = 1.f;

	UPROPERTY(BlueprintReadOnly, Category = "FEL|Neuro")
	bool bNeuroFlowActive = false;

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "FEL")
	USpringArmComponent* CameraBoom;

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "FEL")
	UCameraComponent* FollowCamera;

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "FEL|Neuro")
	UPointLightComponent* NeuroDriveFootGlow;

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "FEL|Neuro")
	UPointLightComponent* NeuroDriveHandGlow;

	/** Steam / energy leak at feet when TimingLeak < 0.7 (assign Niagara system in editor). */
	UPROPERTY(EditDefaultsOnly, Category = "FEL|Feedback")
	TObjectPtr<UNiagaraSystem> BondsBounceLeakVFX;

	/** "Sonic boom" at contact / hands when Neuro-Flow triggers (optional; assign in editor). */
	UPROPERTY(EditDefaultsOnly, Category = "FEL|Feedback")
	TObjectPtr<UNiagaraSystem> NeuroFlowSonicBoomVFX;

	/** Optional: apex "Sonic Flare" for `Bonds_Apex_Ignition`; falls back to `NeuroFlowSonicBoomVFX` if unset. */
	UPROPERTY(EditDefaultsOnly, Category = "FEL|Feedback|Signature")
	TObjectPtr<UNiagaraSystem> SignatureSonicFlareVFX;

	/** Heavy landing: scaled by `CachedAnkleHeat01` + impact speed (optional shake class). */
	UPROPERTY(EditDefaultsOnly, Category = "FEL|Feedback")
	TSubclassOf<UCameraShakeBase> HeavyLandingCameraShake;

	/** Luma Venice 0.5x global dilation: broadcast camera punch (optional; FOV still kicks if unset). */
	UPROPERTY(EditDefaultsOnly, Category = "FEL|Feedback|Signature")
	TSubclassOf<UCameraShakeBase> SignatureHeroBroadcastCameraShake;

	/** Apex / Perfect-band cinematic framing (spring arm + FOV; driven from Tick). */
	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "FEL|Neuro")
	TObjectPtr<UFELCinematicCameraComponent> CinematicCamera;

	/** Sonic / ring sting when entering Neuro-Flow (optional). */
	UPROPERTY(EditDefaultsOnly, Category = "FEL|Audio")
	TObjectPtr<USoundBase> NeuroFlowSonicCue;

	/** Stadium "boom" when Bonds Bounce timing is Perfect (3D spatial; assign attenuation for arena falloff). */
	UPROPERTY(EditDefaultsOnly, Category = "FEL|Audio")
	TObjectPtr<USoundBase> PerfectDunkStadiumBoomCue;

	UPROPERTY(EditDefaultsOnly, Category = "FEL|Audio")
	TObjectPtr<USoundAttenuation> PerfectDunkSpatialAttenuation;

	/** Sound mix that ducks other classes while Neuro-Flow sting plays (optional). */
	UPROPERTY(EditDefaultsOnly, Category = "FEL|Audio")
	TObjectPtr<USoundMix> NeuroFlowDuckMix;

	/**
	 * Sovereign / MyTeam gear albedo — editor hook applies ASTC + 1024 cap for iOS/Android packaging (Fortnite-style tiering).
	 * Assign shop jersey/shoe source textures here so PostEditChangeProperty can stamp mobile-friendly settings.
	 */
	UPROPERTY(EditAnywhere, Category = "FEL|Gear|Sovereign")
	TArray<TObjectPtr<UTexture2D>> SovereignGearTextures;

	/** Post-process blendable: edge / electric aura when PRQ is Primed (>85). Use stencil against CustomDepth on mesh. */
	UPROPERTY(EditDefaultsOnly, Category = "FEL|Neuro|Primed")
	TObjectPtr<UMaterialInterface> PrimedNeuroPostProcessMaterial;

	/** Skeletal mesh material slot index for jersey MID — drives `FEL_JerseyNeuroPulse` / `FEL_JerseyEmissiveCyan` (match MI parameters). */
	UPROPERTY(EditDefaultsOnly, Category = "FEL|Neuro|Jersey", meta = (ClampMin = "0"))
	int32 NeuroFlowJerseyMaterialIndex = 0;

	UPROPERTY(BlueprintAssignable, Category = "FEL|Neuro")
	FFELOnPerfectDunk OnPerfectDunk;

	UPROPERTY(BlueprintAssignable, Category = "FEL|Neuro")
	FFELOnPerfectStrike OnPerfectStrike;

	/** Karate / strike modes: call from Blueprint when timing is Perfect — iOS haptics + Niagara at contact. */
	UFUNCTION(BlueprintCallable, Category = "FEL|Feedback")
	void BroadcastPerfectStrikeImpact();

	/**
	 * Creator Card signature move (`CachedSignatureTrait` from `signature_trait_id`).
	 * Mobile: `AFELBasketballPlayerController` maps tap/hold/double-tap (Enhanced Input parity) to this.
	 */
	UFUNCTION(BlueprintCallable, Category = "FEL|Signature")
	void ExecuteSignatureMove();

	/** Blueprint / legacy — forwards to `ExecuteSignatureMove`. */
	UFUNCTION(BlueprintCallable, Category = "FEL|Signature")
	void TriggerSignatureMove();

	/** Gold Master: `AFELBasketballPlayerController::InputModeHandshake` (Mac Space) — same as default `Jump` action → `FEL_OnJumpPressed`. */
	UFUNCTION(BlueprintCallable, Category = "FEL|Input")
	void FELHandshakeJump();

	/** IA_ShootTap during ascent: snap motion-warp toward rim using save-game peak Z as reference (Neuro-Mechanic integrity). */
	UFUNCTION(BlueprintCallable, Category = "FEL|Input")
	void TryShootTapAscentRimSnap();

	UFUNCTION(BlueprintPure, Category = "FEL|Signature")
	EFELSignatureTrait GetEquippedSignatureTrait() const { return CachedSignatureTrait; }

	UFUNCTION(BlueprintPure, Category = "FEL|Gear")
	float GetCachedGearJumpMult() const { return CachedGearJumpMult; }

	/** Peak upward Z velocity (uu/s) sampled during the last jump — AI Coach / System Scan (stored in `FFELAthleteStats::JumpHeight` field at save time). */
	UFUNCTION(BlueprintPure, Category = "FEL|Coach")
	float GetLastJumpPeakZVelocityForStats() const { return LastJumpPeakZVelocityForStats; }

	/** Apply `UFELSaveGame` after `LoadGameFromSlot` (Bonds_Apex_Ignition unlock + cached gear mult). */
	void ApplyPersistedGearState(class UFELSaveGame* Save);

	/** True while signature execution should block buffered shoot (IMC tap / deferred 0.16s shoot). */
	UFUNCTION(BlueprintCallable, Category = "FEL|Signature")
	bool IsSignatureMoveWindowActive() const;

	virtual bool CanJump() const override;

	virtual void BeginPlay() override;

	/**
	 * Mobile: virtual stick + optional sprint/gather from `AFELBasketballPlayerController` touch bridge.
	 * MoveForward/MoveRight are -1..1; TurnDelta is additive yaw; Sprint01/Gather01 are smoothed internally.
	 */
	UFUNCTION(BlueprintCallable, Category = "FEL|Touch")
	void ApplyTouchDriveInput(float MoveForward, float MoveRight, float TurnDelta, float Sprint01, float Gather01, float DeltaSeconds);

	/** Motion Warping — align mocap jumps to rim / goal targets (see `FELMotionWarpingLibrary`). */
	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "FEL|Animation")
	TObjectPtr<UMotionWarpingComponent> MotionWarping;

	/** Landing wobble from ankle/knee kinetic heat (Lab Dunk + Gymnastics). */
	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "FEL|Animation")
	TObjectPtr<UFELLandingIKComponent> LandingIK;

	/** Data-driven mocap + jump clips (mirrors ArenaSettings / `FFELSportNeuroConstants`). */
	UPROPERTY(BlueprintReadOnly, Category = "FEL|Animation")
	FFELSportNeuroConstants CachedSportNeuro;

	UPROPERTY(BlueprintReadOnly, Category = "FEL|Neuro")
	float CachedPRQScore = 75.f;

	/** 0..1 horizontal speed vs neuro max walk (Athlete Hub — engine truth, not Swift). */
	UFUNCTION(BlueprintPure, Category = "FEL|AthleteHub")
	float GetSprintGauge01() const;

	/** 0..1 neural drive from readiness pipeline (Gather analog). */
	UFUNCTION(BlueprintPure, Category = "FEL|AthleteHub")
	float GetGatherNeuralDrive01() const;

	/** 0..1 active Neuro-Flow camera post blend. */
	UFUNCTION(BlueprintPure, Category = "FEL|AthleteHub")
	float GetNeuroFlowVisualBlend01() const;

	UPROPERTY(BlueprintReadOnly, Category = "FEL|Scan")
	float CachedAnkleHeat01 = 0.2f;

	UPROPERTY(BlueprintReadOnly, Category = "FEL|Scan")
	float CachedKneeHeat01 = 0.2f;

protected:
#if WITH_EDITOR
	virtual void PostEditChangeProperty(FPropertyChangedEvent& PropertyChangedEvent) override;
	void ApplySovereignTexturePlatformDefaults();
#endif

	virtual void Tick(float DeltaSeconds) override;
	virtual void Jump() override;
	virtual void Landed(const FHitResult& Hit) override;
	virtual void EndPlay(const EEndPlayReason::Type EndPlayReason) override;
	virtual void OnMovementModeChanged(EMovementMode PrevMovementMode, uint8 PreviousCustomMode) override;
	virtual void SetupPlayerInputComponent(class UInputComponent* PlayerInputComponent) override;

	void MoveForward(float Value);
	void MoveRight(float Value);
	void Turn(float Value);
	void LookUp(float Value);

	void FEL_OnJumpPressed();
	void FEL_OnJumpReleased();

	void ApplyBondsBounceHitStop();
	void ClearBondsBounceHitStop();

	void UpdateNeuroDriveVisuals(float NeuralDrivePercent);
	void TickApproachRun(float DeltaSeconds);
	void ApplyLateralWalkFromNeuro();
	float ComputeLateralStrain01() const;
	void ApplyMidAirNeuralCorrection(float DeltaSeconds);
	void UpdateNeuroFlowVisuals(float DeltaSeconds);
	void UpdateHeroBroadcastCameraFeedback();
	void TriggerNeuroFlow();
	void ApplyJumpTakeoffAnimWarp(EFELJumpTimingBand Band);
	void ApplyNeuroLayerBlendToAnimInstance();
	void SpawnBondsBounceLeakVFX(float TimingLeak);
	void PlayNeuroFlowAudioCue();
	void PopNeuroFlowDuckMix();
	void UpdatePrimedPostProcess(float DeltaSeconds);
	void UpdateNeuroFlowCharacterMaterials(float DeltaSeconds);
	void EnsureNeuroFlowMaterialDynamics();
	void SpawnPerfectDunkRimNiagara();
	void TickSignatureTrait(float DeltaSeconds);
	void SpawnSignatureSonicFlareAtApex();
	/** Nintendo Switch: Joy-Con HD Rumble — Bonds Apex (≥40") primary snap + Sonic Flare bloom-matched secondary pulse. */
	void TriggerSwitchHaptics(float BloomIntensity01, bool bBondsApexHighJump);
	void TryNeuroFlowTeleportTowardRim();

	/** RC 1.0 Luma Venice: restore global dilation + broadcast bloom after short hang window. */
	void OnSonicFlareBroadcastWindowEnd();

	UFUNCTION()
	void OnPerfectDunkWarpHapticTimerFired();
	void PlayPerfectDunkSpatialBoom();
	FVector GetNearestHoopLocationForVFX() const;

	FTimerHandle JumpWarpResetTimerHandle;
	FTimerHandle MotionWarpClearTimerHandle;
	FTimerHandle NeuroFlowAudioMixTimerHandle;
	FTimerHandle HitStopResetTimerHandle;
	FTimerHandle PerfectDunkWarpHapticTimerHandle;
	FTimerHandle SonicFlareBroadcastTimerHandle;

	/** Luma_Venice_Shop: Bonds Apex TV moment — global slow-mo + bloom (see package_gold_master RC constants). */
	bool bSonicFlareBroadcastHangActive = false;
	bool bSonicFlareBroadcastBloomActive = false;
	bool bWasSonicFlareBroadcastHangActive = false;

#if PLATFORM_PS5
	/** PS5 Pro: mirror-finish RT cvars during Sonic Flare window (Venice shop floor); restored when the 0.2s hang ends. */
	void PushVeniceMirrorFinishRtIfPS5Pro();
	void PopVeniceMirrorFinishRt();
	bool bVeniceMirrorFinishRtPushed = false;
	bool bHasVeniceMirrorSavedMaxRoughness = false;
	bool bHasVeniceMirrorSavedRTGI = false;
	float VeniceMirrorSavedMaxRoughness = 0.f;
	int32 VeniceMirrorSavedRTGI = 0;
#endif

	/** Kinetic chain: Sprint→Gather (ExecuteSignatureMove) transfers horizontal speed into next jump (see AUDIT_BIOMECHANICAL_ECOSYSTEM). */
	float PendingKineticGatherJumpBoost = 0.f;
	/** Snapshot before Bonds Apex jump for +25% AirControl (Fortnite-style mid-air strafe parity). */
	float CachedAirControlBeforeBondsApexJump = 0.35f;
	float DefaultFollowCameraFOV = 90.f;
	float AscentRimSnapCooldownRemaining = 0.f;
	bool bBondsApexSeekingApexPrevFrame = false;

	/** Grace period after leaving ground without a jump (ledge walk-off). */
	float CoyoteTimeRemaining = 0.f;
	static constexpr float CoyoteTimeSeconds = 0.1f;
	/** Set true at jump start so Walking→Falling from takeoff does not grant coyote. */
	bool bLeftGroundByJump = false;

	/** Snapshot + arena pipeline jump Z before per-jump timing multiplier (cm/s). */
	float CachedJumpZAfterNeuroPipeline = 420.f;
	/** Max walk speed after neuro + arena physics, before lateral-cut leakage (uu/s). */
	float CachedNeuroMaxWalkSpeed = 600.f;
	/** Seconds spent above approach speed while grounded (gather clock for Bonds Bounce). */
	float ApproachRunSeconds = 0.f;
	float CachedNeuralDrive = 0.f;
	int32 ConsecutivePerfectJumps = 0;
	float NeuroFlowRemainSec = 0.f;
	float NeuroFlowVisualBlend = 0.f;
	bool bNeuroFlowDuckMixPushed = false;
	float PrimedPostProcessBlend = 0.f;

	static constexpr float ApproachSpeedThresholdUU = 280.f;

	bool bIsDunkContestContext = false;
	float NeuroHangTimeScaleCached = 1.f;
	float DefaultMovementGravityScale = 1.f;
	/** Vertical velocity band (uu/s) for apex hang-time gravity easing. */
	float DunkApexVelocityBand = 220.f;
	bool bNeuroDriveGlowActive = false;

	float CachedKineticLeakageMult = 1.f;
	FString CachedActiveArenaMode;

	/** From `readiness_snapshot.json` MyTeam gear (1.0–1.06). */
	float CachedGearMotionWarpMult = 1.f;
	float CachedGearJumpMult = 1.f;
	float CachedNeuroFlowIntensityScale = 1.f;

	/** Stood Creator Card — layered after gear jump mult. */
	float CachedStoodCardJumpScale = 1.f;
	float CachedStoodCardNeuralAlpha = 1.f;
	FString CachedStoodCardTier;
	FLinearColor CachedNeuroFlowAuraColor = FLinearColor(0.15f, 1.f, 0.95f);

	EFELSignatureTrait CachedSignatureTrait = EFELSignatureTrait::None;
	float SignatureMoveCooldownRemaining = 0.f;
	float SignatureAuraBlend01 = 0.f;
	bool bPendingSignatureApexIgnition = false;
	bool bBondsApexIgnitionSeekApex = false;
	bool bBondsApexWasRising = false;
	double SignatureGhostStrikeUntilTime = 0.0;

	/** True from jump takeoff until landing — tracks max upward Z velocity for PerformanceHistory. */
	bool bTrackJumpPeakForStats = false;
	float LastJumpPeakZVelocityForStats = 0.f;

	/** iOS touch: sprint / gather modifiers (0..1), smoothed in ApplyTouchDriveInput. */
	float TouchSprintBlend01 = 0.f;
	float TouchGatherBlend01 = 0.f;

	UPROPERTY(Transient)
	TArray<TObjectPtr<UMaterialInstanceDynamic>> NeuroFlowMaterialDynamics;

	bool bNeuroFlowMIDsEnsured = false;
};
```

File: `UnrealStarter/BasketballGame/FELBasketballCharacter.cpp`

```cpp
// Copyright (c) Final Evolution Lab.

#include "FELBasketballCharacter.h"
#include "UFELSaveGame.h"

DEFINE_LOG_CATEGORY_STATIC(LogFEL, Log, All);
#include "FELNativeBridge.h"
#include "FELHoopTargetActor.h"
#include "UFELInputComponent.h"
#include "FELBiometricTypes.h"
#include "FELArenaDifficultyScaling.h"
#include "FELArenaModeDefinitions.h"
#include "FELArenaRulesTypes.h"
#include "FELBasketballGameState.h"
#include "UFELNeuroFlowShareCaptureSubsystem.h"
#include "FELBasketballPlayerController.h"
#include "FELKineticLeakage.h"
#include "FELMotionWarpingLibrary.h"
#include "FELNeuroAnimLayerBlend.h"
#include "FELNeuroAnimLayerInterface.h"
#include "FELNeuroMechanicBridgeSubsystem.h"
#include "FELNeuroMechanicPhysics.h"
#include "FinalEvolutionLab.h"
#include "UFELLandingIKComponent.h"
#include "FELCinematicCameraComponent.h"
#include "FELConsoleHapticBridge.h"
#if PLATFORM_SWITCH
#include "GameFramework/ForceFeedbackParameters.h"
#endif
#include "Animation/AnimInstance.h"
#include "Animation/AnimMontage.h"
#include "Components/MotionWarpingComponent.h"
#include "Camera/CameraComponent.h"
#include "GameFramework/PlayerController.h"
#include "Components/CapsuleComponent.h"
#include "Components/PointLightComponent.h"
#include "Engine/Engine.h"
#include "Engine/GameInstance.h"
#include "GameFramework/CharacterMovementComponent.h"
#include "GameFramework/Controller.h"
#include "GameFramework/SpringArmComponent.h"
#include "Kismet/GameplayStatics.h"
#include "Math/RotationMatrix.h"
#include "Math/UnrealMathUtility.h"
#include "NiagaraFunctionLibrary.h"
#include "NiagaraSystem.h"
#include "Materials/MaterialInterface.h"
#include "Materials/MaterialInstanceDynamic.h"
#include "Engine/Texture2D.h"
#include "HAL/IConsoleManager.h"
#include "HAL/PlatformMisc.h"
#include "Sound/SoundAttenuation.h"
#include "Sound/SoundBase.h"
#include "Sound/SoundMix.h"

namespace
{
FLinearColor FEL_NeuroFlowAuraColorForTier(const FString& Tier)
{
	if (Tier.Contains(TEXT("diamond"), ESearchCase::IgnoreCase))
	{
		return FLinearColor(0.88f, 0.95f, 1.f);
	}
	if (Tier.Contains(TEXT("gold"), ESearchCase::IgnoreCase))
	{
		return FLinearColor(1.f, 0.82f, 0.28f);
	}
	return FLinearColor(0.12f, 0.96f, 1.f);
}

FLinearColor FEL_SignatureAuraColorForTrait(const EFELSignatureTrait T)
{
	switch (T)
	{
	case EFELSignatureTrait::Bonds_Apex_Ignition:
		return FLinearColor(1.f, 0.85f, 0.12f, 1.f);
	case EFELSignatureTrait::Dojo_Ghost_Strike:
		return FLinearColor(0.72f, 0.22f, 1.f, 1.f);
	case EFELSignatureTrait::Neuro_Flow_Teleport:
		return FLinearColor(0.12f, 0.96f, 1.f, 1.f);
	default:
		return FLinearColor(0.15f, 1.f, 0.95f, 1.f);
	}
}

#if PLATFORM_PS5
static bool FEL_IsPS5ProHardware_ForVenice()
{
	if (FPlatformMisc::GetEnvironmentVariable(TEXT("FEL_FORCE_PS5_PRO")) == TEXT("1"))
	{
		return true;
	}
	const FString Brand = FPlatformMisc::GetCPUBrand();
	return Brand.Contains(TEXT("Pro"), ESearchCase::IgnoreCase);
}
#endif
}

AFELBasketballCharacter::AFELBasketballCharacter(const FObjectInitializer& ObjectInitializer)
	: Super(ObjectInitializer.SetDefaultSubobjectClass<UFELInputComponent>(TEXT("InputComponent0")))
{
	PrimaryActorTick.bCanEverTick = true;

	bUseControllerRotationPitch = false;
	bUseControllerRotationYaw = false;
	bUseControllerRotationRoll = false;

	if (UCharacterMovementComponent* Move = GetCharacterMovement())
	{
		Move->bOrientRotationToMovement = true;
		CachedAirControlBeforeBondsApexJump = Move->AirControl;
	}

	GetMesh()->SetupAttachment(GetCapsuleComponent());
	GetMesh()->SetRelativeLocation(FVector(0.f, 0.f, -96.f));
	GetMesh()->SetRelativeRotation(FRotator(0.f, -90.f, 0.f));

	static ConstructorHelpers::FObjectFinder<USkeletalMesh> MeshAsset(
		TEXT("/Game/FEL/Characters/ElijahBonds/SKM_ElijahBonds_Walking.SKM_ElijahBonds_Walking"));
	if (MeshAsset.Succeeded())
	{
		GetMesh()->SetSkeletalMesh(MeshAsset.Object);
	}

	CameraBoom = CreateDefaultSubobject<USpringArmComponent>(TEXT("CameraBoom"));
	CameraBoom->SetupAttachment(RootComponent);
	CameraBoom->TargetArmLength = 400.f;
	CameraBoom->bUsePawnControlRotation = true;

	FollowCamera = CreateDefaultSubobject<UCameraComponent>(TEXT("FollowCamera"));
	FollowCamera->SetupAttachment(CameraBoom, USpringArmComponent::SocketName);
	FollowCamera->bUsePawnControlRotation = false;

	NeuroDriveFootGlow = CreateDefaultSubobject<UPointLightComponent>(TEXT("NeuroDriveFootGlow"));
	NeuroDriveFootGlow->SetupAttachment(GetCapsuleComponent());
	NeuroDriveFootGlow->SetRelativeLocation(FVector(0.f, -28.f, -92.f));
	NeuroDriveFootGlow->SetIntensity(0.f);
	NeuroDriveFootGlow->SetLightColor(FLinearColor(0.15f, 1.f, 0.25f));
	NeuroDriveFootGlow->SetAttenuationRadius(180.f);
	NeuroDriveFootGlow->SetVisibility(false);

	NeuroDriveHandGlow = CreateDefaultSubobject<UPointLightComponent>(TEXT("NeuroDriveHandGlow"));
	NeuroDriveHandGlow->SetupAttachment(GetCapsuleComponent());
	NeuroDriveHandGlow->SetRelativeLocation(FVector(48.f, 0.f, 96.f));
	NeuroDriveHandGlow->SetIntensity(0.f);
	NeuroDriveHandGlow->SetLightColor(FLinearColor(0.15f, 1.f, 0.25f));
	NeuroDriveHandGlow->SetAttenuationRadius(160.f);
	NeuroDriveHandGlow->SetVisibility(false);

	MotionWarping = CreateDefaultSubobject<UMotionWarpingComponent>(TEXT("MotionWarping"));
	MotionWarping->SetupAttachment(GetMesh());

	LandingIK = CreateDefaultSubobject<UFELLandingIKComponent>(TEXT("LandingIK"));

	CinematicCamera = CreateDefaultSubobject<UFELCinematicCameraComponent>(TEXT("CinematicCamera"));
}

bool AFELBasketballCharacter::CanJump() const
{
	if (CoyoteTimeRemaining > 0.f)
	{
		const UCharacterMovementComponent* M = GetCharacterMovement();
		if (M && !M->IsMovingOnGround())
		{
			return true;
		}
	}
	return Super::CanJump();
}

float AFELBasketballCharacter::GetSprintGauge01() const
{
	const UCharacterMovementComponent* M = GetCharacterMovement();
	if (!M)
	{
		return 0.f;
	}
	const float Denom = FMath::Max(1.f, CachedNeuroMaxWalkSpeed);
	return FMath::Clamp(M->Velocity.Size2D() / Denom, 0.f, 1.f);
}

float AFELBasketballCharacter::GetGatherNeuralDrive01() const
{
	return FMath::Clamp(CachedNeuralDrive / 100.f, 0.f, 1.f);
}

float AFELBasketballCharacter::GetNeuroFlowVisualBlend01() const
{
	return FMath::Clamp(NeuroFlowVisualBlend, 0.f, 1.f);
}

void AFELBasketballCharacter::BeginPlay()
{
	Super::BeginPlay();
	if (FollowCamera)
	{
		DefaultFollowCameraFOV = FollowCamera->FieldOfView;
		const FVector CamLoc = FollowCamera->GetComponentLocation();
		UE_LOG(LogTemp, Warning, TEXT("GOLD MASTER: Camera Active at Loc: %s"), *CamLoc.ToString());
		if (CamLoc.IsNearlyZero())
		{
			UE_LOG(LogTemp, Error, TEXT("GOLD MASTER: CRITICAL - Camera stuck at Origin (0,0,0). Possession failed?"));
		}
	}
	else
	{
		UE_LOG(LogTemp, Error, TEXT("GOLD MASTER: FollowCamera Component is NULL."));
	}
	if (USkeletalMeshComponent* Sk = GetMesh())
	{
		Sk->SetHiddenInGame(false);
		Sk->SetVisibility(true, true);
	}
	EnsureNeuroFlowMaterialDynamics();
}

#if WITH_EDITOR
void AFELBasketballCharacter::PostEditChangeProperty(FPropertyChangedEvent& PropertyChangedEvent)
{
	Super::PostEditChangeProperty(PropertyChangedEvent);
	if (PropertyChangedEvent.Property
		&& PropertyChangedEvent.Property->GetFName() == GET_MEMBER_NAME_CHECKED(AFELBasketballCharacter, SovereignGearTextures))
	{
		ApplySovereignTexturePlatformDefaults();
	}
}

void AFELBasketballCharacter::ApplySovereignTexturePlatformDefaults()
{
	for (UTexture2D* Tex : SovereignGearTextures)
	{
		if (!Tex)
		{
			continue;
		}
		Tex->CompressionSettings = TC_ASTC;
		Tex->MaxTextureSize = 1024;
		Tex->Modify();
		Tex->PostEditChange();
		Tex->MarkPackageDirty();
	}
}
#endif

void AFELBasketballCharacter::ApplyTouchDriveInput(
	const float MoveForward,
	const float MoveRight,
	const float TurnDelta,
	const float Sprint01,
	const float Gather01,
	const float DeltaSeconds)
{
	TouchSprintBlend01 = FMath::FInterpTo(TouchSprintBlend01, FMath::Clamp(Sprint01, 0.f, 1.f), DeltaSeconds, 22.f);
	TouchGatherBlend01 = FMath::FInterpTo(TouchGatherBlend01, FMath::Clamp(Gather01, 0.f, 1.f), DeltaSeconds, 18.f);
	if (Controller && !FMath::IsNearlyZero(TurnDelta))
	{
		AddControllerYawInput(TurnDelta);
	}
	const float Yaw = Controller ? Controller->GetControlRotation().Yaw : GetActorRotation().Yaw;
	const FRotator YawRot(0.f, Yaw, 0.f);
	if (!FMath::IsNearlyZero(MoveForward) || !FMath::IsNearlyZero(MoveRight))
	{
		AddMovementInput(FRotationMatrix(YawRot).GetUnitAxis(EAxis::X), MoveForward);
		AddMovementInput(FRotationMatrix(YawRot).GetUnitAxis(EAxis::Y), MoveRight);
	}
}

void AFELBasketballCharacter::TriggerSignatureMove()
{
	ExecuteSignatureMove();
}

void AFELBasketballCharacter::ApplyPersistedGearState(UFELSaveGame* Save)
{
	if (!Save)
	{
		return;
	}
	if (Save->CachedGearJumpMult > 0.f)
	{
		CachedGearJumpMult = FMath::Clamp(Save->CachedGearJumpMult, 1.f, 1.06f);
	}
	for (const FString& Id : Save->UnlockedSovereignSkins)
	{
		if (Id.Equals(TEXT("Bonds_Apex_Ignition"), ESearchCase::IgnoreCase))
		{
			CachedSignatureTrait = EFELSignatureTrait::Bonds_Apex_Ignition;
			break;
		}
	}
}

void AFELBasketballCharacter::FELHandshakeJump()
{
	FEL_OnJumpPressed();
}

bool AFELBasketballCharacter::IsSignatureMoveWindowActive() const
{
	if (SignatureAuraBlend01 > 0.08f)
	{
		return true;
	}
	if (bPendingSignatureApexIgnition || bBondsApexIgnitionSeekApex)
	{
		return true;
	}
	if (const UWorld* W = GetWorld())
	{
		if (W->GetTimeSeconds() < SignatureGhostStrikeUntilTime)
		{
			return true;
		}
	}
	return false;
}

void AFELBasketballCharacter::ExecuteSignatureMove()
{
	if (CachedSignatureTrait == EFELSignatureTrait::None || SignatureMoveCooldownRemaining > 0.f)
	{
		return;
	}
	UWorld* const W = GetWorld();
	if (!W)
	{
		return;
	}
	const float Now = W->GetTimeSeconds();
	SignatureMoveCooldownRemaining = 3.5f;
	SignatureAuraBlend01 = 1.f;

	switch (CachedSignatureTrait)
	{
	case EFELSignatureTrait::Bonds_Apex_Ignition:
		bPendingSignatureApexIgnition = true;
		// Kinetic energy transfer (gather pole-vault): 15% of forward horizontal speed → next jump Z boost.
		PendingKineticGatherJumpBoost = 0.f;
		if (UCharacterMovementComponent* Move = GetCharacterMovement())
		{
			FVector Vel = Move->Velocity;
			Vel.Z = 0.f;
			FVector Fwd(GetActorForwardVector().X, GetActorForwardVector().Y, 0.f);
			if (Fwd.Normalize())
			{
				const float ForwardSpeed = FVector::DotProduct(Vel, Fwd);
				PendingKineticGatherJumpBoost = 0.15f * FMath::Max(0.f, ForwardSpeed);
			}
		}
		break;
	case EFELSignatureTrait::Dojo_Ghost_Strike:
		SignatureGhostStrikeUntilTime = static_cast<double>(Now) + 0.55;
		break;
	case EFELSignatureTrait::Neuro_Flow_Teleport:
		TryNeuroFlowTeleportTowardRim();
		break;
	default:
		break;
	}
}

void AFELBasketballCharacter::TryNeuroFlowTeleportTowardRim()
{
	if (TouchGatherBlend01 < 0.25f && ApproachRunSeconds < 0.06f)
	{
		return;
	}
	FVector ToHoop = GetNearestHoopLocationForVFX() - GetActorLocation();
	ToHoop.Z = 0.f;
	const float Len = ToHoop.Size();
	if (Len < 50.f)
	{
		return;
	}
	ToHoop /= Len;
	const FVector Delta = ToHoop * 200.f;
	FHitResult Hit;
	AddActorWorldOffset(Delta, true, &Hit);
}

void AFELBasketballCharacter::SpawnSignatureSonicFlareAtApex()
{
	UWorld* const W = GetWorld();
	if (!W)
	{
		return;
	}
	UNiagaraSystem* const Flare = SignatureSonicFlareVFX ? SignatureSonicFlareVFX : NeuroFlowSonicBoomVFX;
	if (!Flare)
	{
		return;
	}
	USkeletalMeshComponent* const Sk = GetMesh();
	const FVector Loc = Sk ? Sk->GetComponentLocation() + FVector(0.f, 0.f, 140.f) : GetActorLocation() + FVector(0.f, 0.f, 140.f);
	const FRotator Rot = GetActorRotation();
	const float Scale = FMath::Lerp(1.f, 1.55f, FMath::Clamp(CachedPRQScore / 100.f, 0.f, 1.f));
	UNiagaraFunctionLibrary::SpawnSystemAtLocation(W, Flare, Loc, Rot, FVector(Scale), true, true);

	static constexpr float GravityCmPerSecSqForApexIn = 980.f;
	const float PeakVzForApex = FMath::Max(LastJumpPeakZVelocityForStats, 0.f);
	const float ApexHeightCmForApex = (PeakVzForApex * PeakVzForApex) / (2.f * GravityCmPerSecSqForApexIn);
	const float ApexHeightInForApex = ApexHeightCmForApex / 2.54f;
#if PLATFORM_SWITCH
	{
		const float Bloom01 = FMath::Clamp(CachedPRQScore / 100.f, 0.f, 1.f);
		TriggerSwitchHaptics(Bloom01, ApexHeightInForApex >= 40.f);
	}
#endif

#if PLATFORM_IOS
	FELNativeBridge::NotifySonicFlareApexHaptics();
#elif PLATFORM_PS5
	if (APlayerController* PC = Cast<APlayerController>(GetController()))
	{
		FELConsoleHapticBridge::ApplySonicFlareApexImpulse(PC);
	}
#endif

	const FString ShortMap = UGameplayStatics::GetCurrentLevelName(W, true);
	if (ShortMap.Contains(TEXT("Luma_Venice")))
	{
#if PLATFORM_PS5
		PopVeniceMirrorFinishRt();
		PushVeniceMirrorFinishRtIfPS5Pro();
#endif
		bSonicFlareBroadcastHangActive = true;
		bSonicFlareBroadcastBloomActive = true;
		// Bonds Apex auto-replay: estimated apex height from peak upward Z velocity (cm/s) vs gravity (cm/s²).
		// ≥40" (~101.6 cm) → 3s slo-mo broadcast (Sonic Flare + mirror floor); else short TV moment.
		static constexpr float GravityCmPerSecSq = 980.f;
		static constexpr float DemoReplayHeightInches = 40.f;
		static constexpr float ShortBroadcastSec = 0.2f;
		static constexpr float DemoReplayBroadcastSec = 3.f;
		const float PeakVz = FMath::Max(LastJumpPeakZVelocityForStats, 0.f);
		const float ApexHeightCm = (PeakVz * PeakVz) / (2.f * GravityCmPerSecSq);
		const float ApexHeightIn = ApexHeightCm / 2.54f;
		const float BroadcastWindowSec =
			(ApexHeightIn >= DemoReplayHeightInches) ? DemoReplayBroadcastSec : ShortBroadcastSec;
#if PLATFORM_IOS
		if (BroadcastWindowSec >= DemoReplayBroadcastSec - KINDA_SMALL_NUMBER)
		{
			FELNativeBridge::NotifyHeroMomentExportReady(ApexHeightIn);
		}
#endif
		W->GetTimerManager().ClearTimer(SonicFlareBroadcastTimerHandle);
		W->GetTimerManager().SetTimer(
			SonicFlareBroadcastTimerHandle,
			this,
			&AFELBasketballCharacter::OnSonicFlareBroadcastWindowEnd,
			BroadcastWindowSec,
			false);
	}
}

void AFELBasketballCharacter::TriggerSwitchHaptics(const float BloomIntensity01, const bool bBondsApexHighJump)
{
#if PLATFORM_SWITCH
	if (APlayerController* PC = Cast<APlayerController>(GetController()))
	{
		FForceFeedbackParameters FFP;
		FFP.bLooping = false;
		FFP.Tag = NAME_None;
		if (bBondsApexHighJump)
		{
			// Bonds Apex ≥ ~40" — high-frequency snap; both Joy-Cons (large + small motors on each side).
			PC->PlayDynamicForceFeedback(1.f, 0.085f, true, true, true, true, FFP);
		}
		// Secondary pulse: Niagara Sonic Flare bloom intensity (PRQ / visual scale proxy).
		const float B = FMath::Clamp(BloomIntensity01, 0.2f, 1.f);
		PC->PlayDynamicForceFeedback(B, 0.14f + B * 0.12f, true, true, true, true, FFP);
	}
#else
	(void)BloomIntensity01;
	(void)bBondsApexHighJump;
#endif
}

void AFELBasketballCharacter::OnSonicFlareBroadcastWindowEnd()
{
	bSonicFlareBroadcastHangActive = false;
	bSonicFlareBroadcastBloomActive = false;
#if PLATFORM_PS5
	PopVeniceMirrorFinishRt();
#endif
	if (UWorld* W = GetWorld())
	{
		UGameplayStatics::SetGlobalTimeDilation(W, 1.f);
	}
}

#if PLATFORM_PS5
void AFELBasketballCharacter::PushVeniceMirrorFinishRtIfPS5Pro()
{
	if (!FEL_IsPS5ProHardware_ForVenice() || bVeniceMirrorFinishRtPushed)
	{
		return;
	}
	if (IConsoleVariable* CV = IConsoleManager::Get().FindConsoleVariable(TEXT("r.RayTracing.Reflections.MaxRoughness")))
	{
		VeniceMirrorSavedMaxRoughness = CV->GetFloat();
		bHasVeniceMirrorSavedMaxRoughness = true;
		CV->Set(0.8f, ECVF_SetByCode);
	}
	if (IConsoleVariable* CV = IConsoleManager::Get().FindConsoleVariable(TEXT("r.RayTracing.GlobalIllumination")))
	{
		VeniceMirrorSavedRTGI = CV->GetInt();
		bHasVeniceMirrorSavedRTGI = true;
		CV->Set(1, ECVF_SetByCode);
	}
	bVeniceMirrorFinishRtPushed = true;
}

void AFELBasketballCharacter::PopVeniceMirrorFinishRt()
{
	if (!bVeniceMirrorFinishRtPushed)
	{
		return;
	}
	if (bHasVeniceMirrorSavedMaxRoughness)
	{
		if (IConsoleVariable* CV = IConsoleManager::Get().FindConsoleVariable(TEXT("r.RayTracing.Reflections.MaxRoughness")))
		{
			CV->Set(VeniceMirrorSavedMaxRoughness, ECVF_SetByCode);
		}
		bHasVeniceMirrorSavedMaxRoughness = false;
	}
	if (bHasVeniceMirrorSavedRTGI)
	{
		if (IConsoleVariable* CV = IConsoleManager::Get().FindConsoleVariable(TEXT("r.RayTracing.GlobalIllumination")))
		{
			CV->Set(VeniceMirrorSavedRTGI, ECVF_SetByCode);
		}
		bHasVeniceMirrorSavedRTGI = false;
	}
	bVeniceMirrorFinishRtPushed = false;
}
#endif

void AFELBasketballCharacter::TryShootTapAscentRimSnap()
{
	if (AscentRimSnapCooldownRemaining > 0.f)
	{
		return;
	}
	UCharacterMovementComponent* M = GetCharacterMovement();
	if (!M || M->IsMovingOnGround() || M->Velocity.Z <= 80.f)
	{
		return;
	}
	if (!MotionWarping)
	{
		return;
	}
	UFELSaveGame* Save = nullptr;
	if (UGameplayStatics::DoesSaveGameExist(UFELSaveGame::GetSlotName(), UFELSaveGame::UserSlotIndex))
	{
		Save = Cast<UFELSaveGame>(UGameplayStatics::LoadGameFromSlot(UFELSaveGame::GetSlotName(), UFELSaveGame::UserSlotIndex));
	}
	if (!Save)
	{
		return;
	}
	const float SavePeak = UFELSaveGame::GetAllTimePeakJumpZVelocity(Save);
	if (SavePeak < 40.f)
	{
		return;
	}
	const float CurVz = FMath::Max(LastJumpPeakZVelocityForStats, M->Velocity.Z);
	const float T = FMath::GetMappedRangeValueClamped(
		FVector2D(SavePeak * 0.35f, SavePeak),
		FVector2D(0.f, 1.f),
		CurVz);
	const float ZScale = FMath::Lerp(0.82f, 1.f, T);
	UWorld* const W = GetWorld();
	if (!W)
	{
		return;
	}
	TArray<AActor*> Hoops;
	UGameplayStatics::GetAllActorsOfClass(W, AFELHoopTargetActor::StaticClass(), Hoops);
	AActor* Best = nullptr;
	float BestD = 1e30f;
	for (AActor* A : Hoops)
	{
		if (!A)
		{
			continue;
		}
		const float D = FVector::DistSquared(GetActorLocation(), A->GetActorLocation());
		if (D < BestD)
		{
			BestD = D;
			Best = A;
		}
	}
	if (!Best || BestD > FMath::Square(4500.f))
	{
		return;
	}
	const float ZOff = CachedSportNeuro.DunkJumpWarpZOffsetCM * ZScale;
	const FVector WarpLoc = FELMotionWarping::ComputeDunkWarpLocationWithPRQ(
		Best->GetActorLocation(),
		GetActorLocation(),
		ZOff,
		CachedPRQScore,
		CachedGearMotionWarpMult);
	FELMotionWarping::SetJumpWarpToTarget(MotionWarping, WarpLoc, FELMotionWarping::JumpAlignTargetName);
	W->GetTimerManager().ClearTimer(MotionWarpClearTimerHandle);
	TWeakObjectPtr<UMotionWarpingComponent> WeakMW(MotionWarping);
	W->GetTimerManager().SetTimer(
		MotionWarpClearTimerHandle,
		[WeakMW]()
		{
			if (WeakMW.IsValid())
			{
				FELMotionWarping::ClearWarpTarget(WeakMW.Get(), FELMotionWarping::JumpAlignTargetName);
			}
		},
		0.85f,
		false);
	AscentRimSnapCooldownRemaining = 0.35f;
}

void AFELBasketballCharacter::TickSignatureTrait(float DeltaSeconds)
{
	SignatureMoveCooldownRemaining = FMath::Max(0.f, SignatureMoveCooldownRemaining - DeltaSeconds);
	SignatureAuraBlend01 = FMath::Max(0.f, SignatureAuraBlend01 - DeltaSeconds * 0.55f);

	if (!bBondsApexIgnitionSeekApex)
	{
		return;
	}
	UCharacterMovementComponent* M = GetCharacterMovement();
	if (!M || M->IsMovingOnGround())
	{
		bBondsApexIgnitionSeekApex = false;
		bBondsApexWasRising = false;
		return;
	}
	const float Vz = M->Velocity.Z;
	if (bBondsApexWasRising && Vz <= 40.f)
	{
		SpawnSignatureSonicFlareAtApex();
		bBondsApexIgnitionSeekApex = false;
		bBondsApexWasRising = false;
		return;
	}
	if (Vz > 180.f)
	{
		bBondsApexWasRising = true;
	}
}

void AFELBasketballCharacter::BroadcastPerfectStrikeImpact()
{
	OnPerfectStrike.Broadcast();
	FELNativeBridge::NotifyPerfectImpactHaptics(true);
	UWorld* const W = GetWorld();
	if (!W || !NeuroFlowSonicBoomVFX)
	{
		return;
	}
	const FVector Loc =
		GetMesh() ? GetMesh()->GetComponentLocation() + GetActorForwardVector() * 95.f : GetActorLocation() + FVector(0.f, 0.f, 96.f);
	UNiagaraFunctionLibrary::SpawnSystemAtLocation(W, NeuroFlowSonicBoomVFX, Loc, GetActorRotation(), FVector(1.05f), true, true);
}

FVector AFELBasketballCharacter::GetNearestHoopLocationForVFX() const
{
	UWorld* const W = GetWorld();
	if (!W)
	{
		return GetActorLocation();
	}
	TArray<AActor*> Hoops;
	UGameplayStatics::GetAllActorsOfClass(W, AFELHoopTargetActor::StaticClass(), Hoops);
	AActor* Best = nullptr;
	float BestD = 1e30f;
	for (AActor* A : Hoops)
	{
		if (!A)
		{
			continue;
		}
		const float D = FVector::DistSquared(GetActorLocation(), A->GetActorLocation());
		if (D < BestD)
		{
			BestD = D;
			Best = A;
		}
	}
	if (Best && BestD < FMath::Square(6500.f))
	{
		return Best->GetActorLocation();
	}
	return GetMesh() ? GetMesh()->GetComponentLocation() + FVector(0.f, 0.f, 140.f) : GetActorLocation();
}

void AFELBasketballCharacter::EnsureNeuroFlowMaterialDynamics()
{
	if (bNeuroFlowMIDsEnsured)
	{
		return;
	}
	USkeletalMeshComponent* const Sk = GetMesh();
	if (!Sk)
	{
		return;
	}
	bNeuroFlowMIDsEnsured = true;
	NeuroFlowMaterialDynamics.Empty();
	const int32 Num = Sk->GetNumMaterials();
	for (int32 i = 0; i < Num; ++i)
	{
		if (UMaterialInterface* Base = Sk->GetMaterial(i))
		{
			UMaterialInstanceDynamic* Mid = UMaterialInstanceDynamic::Create(Base, this);
			Sk->SetMaterial(i, Mid);
			NeuroFlowMaterialDynamics.Add(Mid);
		}
	}
}

void AFELBasketballCharacter::UpdateNeuroFlowCharacterMaterials(float DeltaSeconds)
{
	(void)DeltaSeconds;
	if (NeuroFlowMaterialDynamics.Num() == 0 || !GetWorld())
	{
		return;
	}
	const float Prq01 = FMath::Clamp(CachedPRQScore / 100.f, 0.f, 1.f);
	const bool bPrimed = CachedPRQScore > 85.f;
	const float Pulse = bPrimed ? FMath::Sin(GetWorld()->GetTimeSeconds() * 5.75f) * 0.5f + 0.5f : 0.f;
	const float Sync = PrimedPostProcessBlend;
	const FLinearColor CyanSignal(0.12f, 0.96f, 1.f, 1.f);
	const int32 JerseyIdx = NeuroFlowJerseyMaterialIndex;
	for (int32 i = 0; i < NeuroFlowMaterialDynamics.Num(); ++i)
	{
		UMaterialInstanceDynamic* Mid = NeuroFlowMaterialDynamics[i];
		if (!Mid)
		{
			continue;
		}
		const bool bJersey = (i == JerseyIdx);
		const float PulseScale = bJersey && bPrimed ? 1.38f : 1.f;
		Mid->SetScalarParameterValue(TEXT("FEL_NeuroFlowPulse"), Sync * Pulse * PulseScale);
		const float VelScalar = FMath::Max(Prq01 * 0.22f, Sync * Prq01);
		const float NeuroFlowIntensity =
			bPrimed ? FMath::Lerp(0.55f, 1.f, Prq01) * (0.65f + 0.35f * Pulse) * Sync : FMath::Lerp(0.08f, 0.42f, Prq01);
		Mid->SetScalarParameterValue(TEXT("FEL_NeuroFlowIntensity"), NeuroFlowIntensity);
		Mid->SetScalarParameterValue(TEXT("FEL_SignalVelocity"), VelScalar * (bJersey ? 1.12f : 1.f));
		Mid->SetVectorParameterValue(TEXT("FEL_NeuroFlowAccent"), CyanSignal * VelScalar);
		Mid->SetScalarParameterValue(TEXT("FEL_PostProcessNeuroSync"), Sync);
		if (bJersey)
		{
			const float JerseyBreath = bPrimed ? Pulse : 0.f;
			Mid->SetScalarParameterValue(TEXT("FEL_JerseyNeuroPulse"), JerseyBreath);
			const float EmissiveScale = FMath::Lerp(0.12f, 0.95f, JerseyBreath) * (0.35f + 0.65f * Sync);
			Mid->SetVectorParameterValue(TEXT("FEL_JerseyEmissiveCyan"), CyanSignal * EmissiveScale);
		}
		const float SigBlend = SignatureAuraBlend01;
		if (SigBlend > 0.002f && CachedSignatureTrait != EFELSignatureTrait::None)
		{
			const FLinearColor SigCol = FEL_SignatureAuraColorForTrait(CachedSignatureTrait);
			Mid->SetVectorParameterValue(TEXT("FEL_SignatureAuraColor"), SigCol * SigBlend);
			Mid->SetScalarParameterValue(TEXT("FEL_SignatureAuraIntensity"), SigBlend);
		}
	}
}

void AFELBasketballCharacter::SpawnPerfectDunkRimNiagara()
{
	UWorld* const W = GetWorld();
	if (!W || !NeuroFlowSonicBoomVFX)
	{
		return;
	}
	const FVector Loc = GetNearestHoopLocationForVFX();
	const float Scale = FMath::Lerp(0.95f, 1.45f, FMath::Clamp(CachedPRQScore / 100.f, 0.f, 1.f));
	UNiagaraFunctionLibrary::SpawnSystemAtLocation(W, NeuroFlowSonicBoomVFX, Loc, FRotator::ZeroRotator, FVector(Scale), true, true);
}

void AFELBasketballCharacter::ApplyBiometricContext_Implementation(const FFELBiometricContext& Context)
{
	FFELReadinessSnapshot Snap;
	Snap.EfficiencyScore = Context.EfficiencyScore;
	Snap.PRQScore = Context.PRQScore;
	Snap.NeuralDrive = Context.NeuralDrive;
	Snap.PopForce = Context.PopForce;
	Snap.VerticalEstimateInches = Context.VerticalEstimateInches;
	Snap.HangTimeScale = Context.HangTimeScale;
	Snap.KineticLeakageMultiplier = Context.KineticLeakageMultiplier;
	ApplyReadiness(Snap);
}

void AFELBasketballCharacter::ApplyReadiness(const FFELReadinessSnapshot& Snap)
{
	CachedNeuralDrive = FMath::Clamp(static_cast<float>(Snap.NeuralDrive), 0.f, 100.f);
	CachedPRQScore = FMath::Clamp(static_cast<float>(Snap.PRQScore), 0.f, 100.f);
	CachedAnkleHeat01 = FMath::Clamp(static_cast<float>(Snap.KineticHeatAnkle), 0.f, 1.f);
	CachedKneeHeat01 = FMath::Clamp(static_cast<float>(Snap.KineticHeatKnee), 0.f, 1.f);
	CachedKineticLeakageMult = FMath::Clamp(static_cast<float>(Snap.KineticLeakageMultiplier), 0.35f, 1.f);
	CachedActiveArenaMode = Snap.ActiveArenaMode;
	CachedGearMotionWarpMult = FMath::Clamp(static_cast<float>(Snap.GearMotionWarpMultiplier), 1.f, 1.06f);
	CachedGearJumpMult = FMath::Clamp(static_cast<float>(Snap.GearJumpVelocityMultiplier), 1.f, 1.06f);
	CachedNeuroFlowIntensityScale = FMath::Clamp(static_cast<float>(Snap.NeuroFlowIntensityScale), 1.f, 1.2f);
	CachedStoodCardJumpScale = FMath::Clamp(static_cast<float>(Snap.StoodCardJumpScale), 1.f, 1.12f);
	CachedStoodCardNeuralAlpha = FMath::Clamp(static_cast<float>(Snap.StoodCardNeuralDriveAlpha), 1.f, 1.15f);
	CachedStoodCardTier = Snap.StoodCardTier.IsEmpty() ? TEXT("standard") : Snap.StoodCardTier;
	CachedSignatureTrait = Snap.SignatureTrait;
	CachedNeuroFlowAuraColor = FEL_NeuroFlowAuraColorForTier(CachedStoodCardTier);
	if (NeuroDriveFootGlow)
	{
		NeuroDriveFootGlow->SetLightColor(CachedNeuroFlowAuraColor);
	}
	if (NeuroDriveHandGlow)
	{
		NeuroDriveHandGlow->SetLightColor(CachedNeuroFlowAuraColor);
	}
	if (LandingIK)
	{
		LandingIK->SetKineticHeats(CachedAnkleHeat01, CachedKneeHeat01);
	}

	if (USkeletalMeshComponent* Sk = GetMesh())
	{
		const float HS = FMath::Clamp(static_cast<float>(Snap.AvatarHeightScale), 0.65f, 1.35f);
		const float WS = FMath::Clamp(static_cast<float>(Snap.AvatarWeightScale), 0.65f, 1.35f);
		Sk->SetRelativeScale3D(FVector(WS, WS, HS));
	}

	if (UCharacterMovementComponent* M = GetCharacterMovement())
	{
		const float V = FMath::Clamp(static_cast<float>(Snap.VerticalPotential), 0.f, 100.f);
		const float VIn = FMath::Clamp(static_cast<float>(Snap.VerticalEstimateInches), 0.f, 72.f);
		const float N = CachedNeuralDrive;
		const float P = FMath::Clamp(static_cast<float>(Snap.PRQScore), 0.f, 100.f);
		const float Eff = FMath::Clamp(static_cast<float>(Snap.EfficiencyScore), 0.f, 100.f);

		const float Potential = FELNeuroMechanicPhysics::PotentialJumpZFromVerticalInches(VIn);
		const float Drive = FELNeuroMechanicPhysics::NeuralDriveRealizationFactor(N);
		const float EffScale = FELNeuroMechanicPhysics::EfficiencyHeightScale(Eff);
		const float Train = FELNeuroMechanicPhysics::VerticalTrainingBonus(V);
		const float BaseJump = Potential * Drive * EffScale + P * 0.14f + Train;

		M->JumpZVelocity = FELKineticLeakage::ApplyNeuroMechanicJump(BaseJump, Snap) * CachedGearJumpMult * CachedStoodCardJumpScale;
		// Sovereign / MyTeam gear: FELArenaDifficultyScaling::CalculateGearBoost (jersey/shoe paths including "Sovereign") replaces the
		// Swift GearJumpVelocityMultiplier for physics via multiply-then-divide — no double-stack with PRQ export aggregates.
		float CppGearJump = 1.f;
		const bool bHasGearPaths = !Snap.JerseyTexturePath.IsEmpty() || !Snap.ShoeTexturePath.IsEmpty();
		if (bHasGearPaths)
		{
			if (!Snap.JerseyTexturePath.IsEmpty())
			{
				CppGearJump *= FELArenaDifficultyScaling::CalculateGearBoost(Snap.JerseyTexturePath).JumpVelocityScaleMult;
			}
			if (!Snap.ShoeTexturePath.IsEmpty())
			{
				CppGearJump *= FELArenaDifficultyScaling::CalculateGearBoost(Snap.ShoeTexturePath).JumpVelocityScaleMult;
			}
			CppGearJump = FMath::Clamp(CppGearJump, 1.f, 1.08f);
			M->JumpZVelocity *= CppGearJump / FMath::Max(1.f, CachedGearJumpMult);
		}
		const float NetGearScaleApplied =
			bHasGearPaths ? (CppGearJump / FMath::Max(1.f, CachedGearJumpMult)) : CachedGearJumpMult;
		if (bHasGearPaths)
		{
			UE_LOG(LogFEL, Display,
				TEXT("Gold Master: Jump Scale Applied: %f | JumpZ=%.1f SwiftGearMult=%.4f CppPathMult=%.4f"),
				NetGearScaleApplied,
				M->JumpZVelocity,
				CachedGearJumpMult,
				CppGearJump);
		}
		const float BaseSpeed = 380.f + N * 1.8f + P * 0.25f;
		M->MaxWalkSpeed = FELKineticLeakage::ApplyNeuroMechanicWalkSpeed(BaseSpeed, Snap);
		CachedJumpZAfterNeuroPipeline = M->JumpZVelocity;
		CachedNeuroMaxWalkSpeed = M->MaxWalkSpeed;
	}
}

void AFELBasketballCharacter::ApplyArenaPhysicsLayer(const FFELArenaRules& Rules)
{
	CachedSportNeuro = Rules.SportNeuro;
	if (UCharacterMovementComponent* M = GetCharacterMovement())
	{
		M->JumpZVelocity *= Rules.PhysicsJumpScale;
		M->MaxWalkSpeed *= Rules.PhysicsWalkScale;
		CachedJumpZAfterNeuroPipeline = M->JumpZVelocity;
		CachedNeuroMaxWalkSpeed = M->MaxWalkSpeed;
	}
}

void AFELBasketballCharacter::PlayTwinBirthIntro(const float DurationSeconds)
{
	if (CinematicCamera)
	{
		CinematicCamera->BeginTwinBirthCinematic(DurationSeconds);
	}
	TriggerNeuroFlow();
}

void AFELBasketballCharacter::ApplyNeuroArenaGameplay(const FFELReadinessSnapshot& Snap, const FFELArenaRules& Rules)
{
	bIsDunkContestContext = Rules.bIsDunkContest;
	NeuroHangTimeScaleCached = static_cast<float>(FMath::Clamp(Snap.HangTimeScale, 0.65, 1.35));
	CachedNeuralDrive = FMath::Clamp(static_cast<float>(Snap.NeuralDrive), 0.f, 100.f);

	if (UCharacterMovementComponent* M = GetCharacterMovement())
	{
		DefaultMovementGravityScale = M->GravityScale;
		if (!bIsDunkContestContext)
		{
			M->GravityScale = DefaultMovementGravityScale;
		}
		// Academy → Arena: Plyos mastery (+2% default) scales realized jump neuro in Dunk Contest only.
		if (bIsDunkContestContext && Snap.AcademyPlyosMasteryBonus > 0.0)
		{
			const float Mult = 1.f + static_cast<float>(FMath::Clamp(Snap.AcademyPlyosMasteryBonus, 0.0, 0.25));
			M->JumpZVelocity *= Mult;
			CachedJumpZAfterNeuroPipeline = M->JumpZVelocity;
		}
	}

	UpdateNeuroDriveVisuals(CachedNeuralDrive);
}

void AFELBasketballCharacter::UpdateNeuroDriveVisuals(const float NeuralDrivePercent)
{
	const bool bHigh = NeuralDrivePercent >= 85.f;
	bNeuroDriveGlowActive = bHigh;
	const float Intensity = bHigh ? 320.f : 0.f;
	if (NeuroDriveFootGlow)
	{
		NeuroDriveFootGlow->SetIntensity(Intensity);
		NeuroDriveFootGlow->SetVisibility(bHigh);
	}
	if (NeuroDriveHandGlow)
	{
		NeuroDriveHandGlow->SetIntensity(Intensity * 0.85f);
		NeuroDriveHandGlow->SetVisibility(bHigh);
	}
}

float AFELBasketballCharacter::ComputeLateralStrain01() const
{
	const UCharacterMovementComponent* M = GetCharacterMovement();
	if (!M)
	{
		return 0.f;
	}
	const FVector Vel(M->Velocity.X, M->Velocity.Y, 0.f);
	if (Vel.IsNearlyZero())
	{
		return 0.f;
	}
	const FVector Right(GetActorRightVector().X, GetActorRightVector().Y, 0.f);
	const float Lateral = FMath::Abs(FVector::DotProduct(Vel, Right.GetSafeNormal()));
	const float MaxS = FMath::Max(CachedNeuroMaxWalkSpeed, 120.f);
	return FMath::Clamp(Lateral / MaxS, 0.f, 1.f);
}

void AFELBasketballCharacter::ApplyLateralWalkFromNeuro()
{
	UCharacterMovementComponent* M = GetCharacterMovement();
	if (!M)
	{
		return;
	}
	UGameInstance* const GI = GetGameInstance();
	if (!GI)
	{
		return;
	}
	UFELNeuroMechanicBridgeSubsystem* const Br = GI->GetSubsystem<UFELNeuroMechanicBridgeSubsystem>();
	float GhostMult = 1.f;
	if (UWorld* W = GetWorld())
	{
		if (W->GetTimeSeconds() < static_cast<float>(SignatureGhostStrikeUntilTime))
		{
			GhostMult = 1.28f;
		}
	}
	if (!Br || !Br->HasCachedSnapshot())
	{
		M->MaxWalkSpeed = CachedNeuroMaxWalkSpeed * FMath::Lerp(1.f, 1.14f, TouchSprintBlend01) * GhostMult;
		return;
	}
	FFELReadinessSnapshot Snap;
	Br->GetCachedSnapshot(Snap);
	FFELArenaRules Rules;
	Br->GetCurrentArenaSettings(Rules);
	const EFELArenaMode Mode = FELArenaModeFromIdString(Snap.ActiveArenaMode);
	const float Mult = FELKineticLeakage::ApplyLateralCutWalkMultiplier(
		static_cast<float>(Snap.NeuralDrive),
		static_cast<float>(Snap.KineticLeakageMultiplier),
		ComputeLateralStrain01(),
		Mode,
		Rules.SportNeuro);
	M->MaxWalkSpeed = CachedNeuroMaxWalkSpeed * Mult * FMath::Lerp(1.f, 1.14f, TouchSprintBlend01) * GhostMult;
}

void AFELBasketballCharacter::TickApproachRun(float DeltaSeconds)
{
	UCharacterMovementComponent* M = GetCharacterMovement();
	if (!M || !M->IsMovingOnGround())
	{
		return;
	}
	const float Speed2D = M->Velocity.Size2D();
	if (Speed2D >= ApproachSpeedThresholdUU)
	{
		const float GatherBoost = 1.f + 0.95f * TouchGatherBlend01;
		ApproachRunSeconds += DeltaSeconds * GatherBoost;
		ApproachRunSeconds = FMath::Min(ApproachRunSeconds, 2.5f);
	}
}

void AFELBasketballCharacter::ApplyMidAirNeuralCorrection(float DeltaSeconds)
{
	if (!bIsDunkContestContext || CachedNeuralDrive < 90.f)
	{
		return;
	}
	UCharacterMovementComponent* M = GetCharacterMovement();
	if (!M || M->IsMovingOnGround())
	{
		return;
	}
	const float Elite = FMath::Clamp((CachedNeuralDrive - 90.f) / 10.f, 0.f, 1.f);
	const FVector Wish = M->GetLastInputVector();
	if (Wish.IsNearlyZero())
	{
		return;
	}
	FVector Planar(Wish.X, Wish.Y, 0.f);
	if (Planar.IsNearlyZero())
	{
		return;
	}
	Planar.Normalize();
	const float NudgeUU = 620.f * Elite * DeltaSeconds;
	M->Velocity += Planar * NudgeUU;
}

void AFELBasketballCharacter::TriggerNeuroFlow()
{
	NeuroFlowRemainSec = 4.5f;
	bNeuroFlowActive = true;
	PlayNeuroFlowAudioCue();

	if (NeuroFlowSonicBoomVFX)
	{
		UWorld* const W = GetWorld();
		USkeletalMeshComponent* const Sk = GetMesh();
		if (W && Sk)
		{
			static const FName HandR(TEXT("hand_r"));
			FVector Loc = Sk->DoesSocketExist(HandR) ? Sk->GetSocketLocation(HandR)
			                                        : GetActorLocation() + FVector(0.f, 0.f, 110.f);
			const float Scale = FMath::Lerp(0.75f, 1.35f, FMath::Clamp(CachedPRQScore / 100.f, 0.f, 1.f));
			const FRotator Rot = GetActorRotation();
			UNiagaraFunctionLibrary::SpawnSystemAtLocation(W, NeuroFlowSonicBoomVFX, Loc, Rot, FVector(Scale), true, true);
		}
	}
}

void AFELBasketballCharacter::PlayNeuroFlowAudioCue()
{
	UWorld* const W = GetWorld();
	if (!W)
	{
		return;
	}
	if (NeuroFlowSonicCue)
	{
		UGameplayStatics::PlaySound2D(W, NeuroFlowSonicCue);
	}
	if (NeuroFlowDuckMix)
	{
		UGameplayStatics::PushSoundMixModifier(W, NeuroFlowDuckMix);
		bNeuroFlowDuckMixPushed = true;
		GetWorldTimerManager().ClearTimer(NeuroFlowAudioMixTimerHandle);
		GetWorldTimerManager().SetTimer(NeuroFlowAudioMixTimerHandle, this, &AFELBasketballCharacter::PopNeuroFlowDuckMix, 2.5f, false);
	}
}

void AFELBasketballCharacter::PopNeuroFlowDuckMix()
{
	if (!bNeuroFlowDuckMixPushed)
	{
		return;
	}
	UWorld* const W = GetWorld();
	if (W && NeuroFlowDuckMix)
	{
		UGameplayStatics::PopSoundMixModifier(W, NeuroFlowDuckMix);
	}
	bNeuroFlowDuckMixPushed = false;
}

void AFELBasketballCharacter::ApplyNeuroLayerBlendToAnimInstance()
{
	USkeletalMeshComponent* const Sk = GetMesh();
	if (!Sk)
	{
		return;
	}
	UAnimInstance* const AI = Sk->GetAnimInstance();
	if (!AI || !AI->GetClass()->ImplementsInterface(UFELNeuroAnimLayerInterface::StaticClass()))
	{
		return;
	}
	const float BasePrim = FELNeuroAnimLayerBlend::CombinedPrimedAlpha(CachedPRQScore, CachedKineticLeakageMult);
	const float ExtraLeaky = FELArenaDifficultyScaling::LeakyAnimLayerExtraFromPRQ(CachedPRQScore);
	const float Prim = FMath::Clamp(FMath::Max(0.f, BasePrim * (1.f - ExtraLeaky)) * CachedStoodCardNeuralAlpha, 0.f, 1.f);
	const float Hip = FELNeuroAnimLayerBlend::HipExtensionScaleFromLeakage(CachedKineticLeakageMult);
	IFELNeuroAnimLayerInterface::Execute_FEL_ApplyNeuroLayerBlend(AI, CachedPRQScore, Prim, Hip);
}

void AFELBasketballCharacter::ApplyJumpTakeoffAnimWarp(const EFELJumpTimingBand Band)
{
	USkeletalMeshComponent* const Sk = GetMesh();
	if (!Sk)
	{
		return;
	}
	UAnimInstance* const AI = Sk->GetAnimInstance();
	if (!AI)
	{
		return;
	}

	const TSoftObjectPtr<UAnimSequence>* SeqPtr = CachedSportNeuro.JumpTimingTakeoffSequences.Find(Band);
	if (!SeqPtr || SeqPtr->IsNull())
	{
		SeqPtr = CachedSportNeuro.JumpTimingTakeoffSequences.Find(EFELJumpTimingBand::Good);
	}
	UAnimSequence* Seq = nullptr;
	if (SeqPtr && !SeqPtr->IsNull())
	{
		Seq = SeqPtr->Get();
		if (!Seq)
		{
			Seq = SeqPtr->LoadSynchronous();
		}
	}

	UAnimMontage* MontageToPlay = nullptr;
	if (Seq)
	{
		MontageToPlay = UAnimMontage::CreateSlotAnimationAsDynamicMontage(
			Seq,
			FName(TEXT("DefaultSlot")),
			0.25f,
			0.25f,
			1.f,
			1);
	}

	if (MontageToPlay)
	{
		AI->Montage_Play(MontageToPlay);
	}

	UWorld* const W = GetWorld();
	if (W && MotionWarping)
	{
		TArray<AActor*> Hoops;
		UGameplayStatics::GetAllActorsOfClass(W, AFELHoopTargetActor::StaticClass(), Hoops);
		AActor* Best = nullptr;
		float BestD = 1e30f;
		for (AActor* A : Hoops)
		{
			if (!A)
			{
				continue;
			}
			const float D = FVector::DistSquared(GetActorLocation(), A->GetActorLocation());
			if (D < BestD)
			{
				BestD = D;
				Best = A;
			}
		}
		if (Best && BestD < FMath::Square(4500.f))
		{
			const FVector WarpLoc = FELMotionWarping::ComputeDunkWarpLocationWithPRQ(
				Best->GetActorLocation(),
				GetActorLocation(),
				CachedSportNeuro.DunkJumpWarpZOffsetCM,
				CachedPRQScore,
				CachedGearMotionWarpMult);
			FELMotionWarping::SetJumpWarpToTarget(MotionWarping, WarpLoc, FELMotionWarping::JumpAlignTargetName);
			W->GetTimerManager().ClearTimer(MotionWarpClearTimerHandle);
			TWeakObjectPtr<UMotionWarpingComponent> WeakMW(MotionWarping);
			W->GetTimerManager().SetTimer(
				MotionWarpClearTimerHandle,
				[WeakMW]()
				{
					if (WeakMW.IsValid())
					{
						FELMotionWarping::ClearWarpTarget(WeakMW.Get(), FELMotionWarping::JumpAlignTargetName);
					}
				},
				0.85f,
				false);
		}
	}

	if (!MontageToPlay)
	{
		float Rate = 1.f;
		if (Band == EFELJumpTimingBand::Perfect)
		{
			Rate = 1.1f;
		}
		else if (Band == EFELJumpTimingBand::Early || Band == EFELJumpTimingBand::Late)
		{
			Rate = 0.85f;
		}

		AI->GlobalAnimRateScale = Rate;
		TWeakObjectPtr<UAnimInstance> WeakAI(AI);
		GetWorldTimerManager().ClearTimer(JumpWarpResetTimerHandle);
		GetWorldTimerManager().SetTimer(
			JumpWarpResetTimerHandle,
			[WeakAI]()
			{
				if (UAnimInstance* Ptr = WeakAI.Get())
				{
					Ptr->GlobalAnimRateScale = 1.f;
				}
			},
			0.35f,
			false);
	}
}

void AFELBasketballCharacter::SpawnBondsBounceLeakVFX(const float TimingLeak)
{
	if (TimingLeak >= 0.7f || !BondsBounceLeakVFX)
	{
		return;
	}
	UWorld* const W = GetWorld();
	if (!W)
	{
		return;
	}
	const float HalfZ = GetCapsuleComponent() ? GetCapsuleComponent()->GetScaledCapsuleHalfHeight() : 88.f;
	const FVector SpawnLoc = GetActorLocation() - FVector(0.f, 0.f, HalfZ - 4.f);
	const FRotator SpawnRot(0.f, GetActorRotation().Yaw, 0.f);
	UNiagaraFunctionLibrary::SpawnSystemAtLocation(W, BondsBounceLeakVFX, SpawnLoc, SpawnRot, FVector(1.f), true, true);
}

void AFELBasketballCharacter::UpdatePrimedPostProcess(float DeltaSeconds)
{
	if (USkeletalMeshComponent* Sk = GetMesh())
	{
		const bool bPrimed = CachedPRQScore > 85.f;
		Sk->SetRenderCustomDepth(bPrimed);
		if (bPrimed)
		{
			Sk->SetCustomDepthStencilValue(1);
		}
	}

	if (!FollowCamera || !PrimedNeuroPostProcessMaterial)
	{
		PrimedPostProcessBlend = 0.f;
		return;
	}

	const float TargetW = (CachedPRQScore > 85.f) ? FMath::Clamp((CachedPRQScore - 85.f) / 15.f, 0.f, 1.f) : 0.f;
	PrimedPostProcessBlend = FMath::FInterpTo(PrimedPostProcessBlend, TargetW, DeltaSeconds, 3.5f);

	FPostProcessSettings& PP = FollowCamera->PostProcessSettings;
	if (PrimedPostProcessBlend < 0.002f)
	{
		PP.RemoveBlendable(PrimedNeuroPostProcessMaterial);
	}
	else
	{
		PP.AddBlendable(PrimedNeuroPostProcessMaterial, PrimedPostProcessBlend);
	}
}

void AFELBasketballCharacter::PlayPerfectDunkSpatialBoom()
{
	UWorld* const W = GetWorld();
	if (!W || !PerfectDunkStadiumBoomCue)
	{
		return;
	}
	const FVector Loc = GetNearestHoopLocationForVFX();
	const FRotator Rot = GetActorRotation();
	UGameplayStatics::SpawnSoundAtLocation(
		W,
		PerfectDunkStadiumBoomCue,
		Loc,
		Rot,
		1.f,
		1.f,
		0.f,
		PerfectDunkSpatialAttenuation);
}

void AFELBasketballCharacter::UpdateNeuroFlowVisuals(float DeltaSeconds)
{
	if (NeuroFlowRemainSec > 0.f)
	{
		NeuroFlowRemainSec -= DeltaSeconds;
		if (NeuroFlowRemainSec <= 0.f)
		{
			NeuroFlowRemainSec = 0.f;
			bNeuroFlowActive = false;
		}
	}

	const float TargetBlend = (NeuroFlowRemainSec > 0.f) ? FMath::Clamp(NeuroFlowRemainSec / 4.5f, 0.f, 1.f) : 0.f;
	NeuroFlowVisualBlend = FMath::FInterpTo(NeuroFlowVisualBlend, TargetBlend, DeltaSeconds, 2.8f);

	if (UWorld* W = GetWorld())
	{
		// Bonds Apex broadcast (Luma Venice): fixed 0.5 global dilation — overrides Neuro-Flow for ~0.2s game-time window.
		if (bSonicFlareBroadcastHangActive)
		{
			UGameplayStatics::SetGlobalTimeDilation(W, 0.5f);
		}
		// Cinematic replay highlight overrides Neuro-Flow dilation for a few seconds.
		else if (CinematicCamera && CinematicCamera->IsReplayHighlightActive())
		{
			UGameplayStatics::SetGlobalTimeDilation(W, 0.48f);
		}
		else
		{
			// Cinematic apex: global dilation (character CustomTimeDilation stays 1 so we don’t double-stack with world).
			UGameplayStatics::SetGlobalTimeDilation(W, FMath::Lerp(1.f, 0.93f, NeuroFlowVisualBlend));
		}
	}

	if (FollowCamera)
	{
		FPostProcessSettings& PP = FollowCamera->PostProcessSettings;
		if (NeuroFlowVisualBlend > 0.02f)
		{
			// Bloom + vignette + subtle time dilation = "Neuro-Flow"; add Scene Color Fringe / CA material on camera in BP for extra edge separation.
			PP.bOverride_BloomIntensity = true;
			PP.BloomIntensity = FMath::Lerp(1.f, 1.85f, NeuroFlowVisualBlend);
			PP.bOverride_BloomThreshold = true;
			PP.BloomThreshold = FMath::Lerp(-1.f, 0.85f, NeuroFlowVisualBlend);
			PP.bOverride_VignetteIntensity = true;
			PP.VignetteIntensity = FMath::Lerp(0.f, 0.48f, NeuroFlowVisualBlend);
			PP.bOverride_BloomTint = true;
			PP.BloomTint = CachedNeuroFlowAuraColor;
		}
		else
		{
			PP.bOverride_BloomIntensity = false;
			PP.bOverride_BloomThreshold = false;
			PP.bOverride_VignetteIntensity = false;
			PP.bOverride_BloomTint = false;
		}

		if (bSonicFlareBroadcastBloomActive)
		{
			const float BaseBloom = (NeuroFlowVisualBlend > 0.02f)
				? FMath::Lerp(1.f, 1.85f, NeuroFlowVisualBlend)
				: 1.f;
			PP.bOverride_BloomIntensity = true;
			PP.BloomIntensity = BaseBloom * 2.0f;
		}
	}

	UpdateHeroBroadcastCameraFeedback();
}

void AFELBasketballCharacter::UpdateHeroBroadcastCameraFeedback()
{
	if (!FollowCamera)
	{
		return;
	}
	const bool bHang = bSonicFlareBroadcastHangActive;
	if (bHang && !bWasSonicFlareBroadcastHangActive)
	{
		FollowCamera->SetFieldOfView(105.f);
		if (APlayerController* PC = Cast<APlayerController>(GetController()))
		{
			if (SignatureHeroBroadcastCameraShake)
			{
				PC->ClientStartCameraShake(
					SignatureHeroBroadcastCameraShake,
					1.f,
					ECameraShakePlaySpace::CameraLocal,
					FRotator::ZeroRotator);
			}
		}
	}
	else if (!bHang && bWasSonicFlareBroadcastHangActive)
	{
		FollowCamera->SetFieldOfView(DefaultFollowCameraFOV);
	}
	bWasSonicFlareBroadcastHangActive = bHang;
}

void AFELBasketballCharacter::Tick(float DeltaSeconds)
{
	if (UCharacterMovementComponent* MoveCoyote = GetCharacterMovement())
	{
		if (MoveCoyote->IsFalling() && CoyoteTimeRemaining > 0.f)
		{
			CoyoteTimeRemaining = FMath::Max(0.f, CoyoteTimeRemaining - DeltaSeconds);
		}
	}

	Super::Tick(DeltaSeconds);

	TickApproachRun(DeltaSeconds);
	ApplyLateralWalkFromNeuro();
	ApplyMidAirNeuralCorrection(DeltaSeconds);

	AscentRimSnapCooldownRemaining = FMath::Max(0.f, AscentRimSnapCooldownRemaining - DeltaSeconds);

	// Bonds Apex Sonic Flare / broadcast flags before Neuro-Flow post so same-frame global dilation + bloom apply.
	TickSignatureTrait(DeltaSeconds);

	{
		UCharacterMovementComponent* MoveAir = GetCharacterMovement();
		if (MoveAir)
		{
			if (bBondsApexIgnitionSeekApex && MoveAir->IsFalling())
			{
				MoveAir->AirControl = FMath::Min(1.f, CachedAirControlBeforeBondsApexJump * 1.25f);
			}
			else if (bBondsApexSeekingApexPrevFrame && !bBondsApexIgnitionSeekApex)
			{
				MoveAir->AirControl = CachedAirControlBeforeBondsApexJump;
			}
		}
		bBondsApexSeekingApexPrevFrame = bBondsApexIgnitionSeekApex;
	}
	UpdateNeuroFlowVisuals(DeltaSeconds);
	UpdatePrimedPostProcess(DeltaSeconds);
	UpdateNeuroFlowCharacterMaterials(DeltaSeconds);
	if (CinematicCamera)
	{
		CinematicCamera->UpdateApexCamera(DeltaSeconds, NeuroFlowVisualBlend * CachedNeuroFlowIntensityScale, ApproachRunSeconds);
	}
	ApplyNeuroLayerBlendToAnimInstance();

	if (UFELInputComponent* FEL = Cast<UFELInputComponent>(InputComponent))
	{
		FEL->TickInputBuffers(this);
	}

	UCharacterMovementComponent* M = GetCharacterMovement();
	if (!M)
	{
		return;
	}

	if (bTrackJumpPeakForStats)
	{
		LastJumpPeakZVelocityForStats = FMath::Max(LastJumpPeakZVelocityForStats, M->Velocity.Z);
	}

	if (!bIsDunkContestContext)
	{
		M->GravityScale = DefaultMovementGravityScale;
		return;
	}

	if (M->IsMovingOnGround())
	{
		M->GravityScale = DefaultMovementGravityScale;
		return;
	}

	const float Vz = M->Velocity.Z;
	const float HT = NeuroHangTimeScaleCached;
	const float Band = FMath::Max(80.f, DunkApexVelocityBand);
	const float ApexT = FMath::Clamp(1.f - FMath::Abs(Vz) / Band, 0.f, 1.f);
	const float Smooth = ApexT * ApexT * (3.f - 2.f * ApexT);
	const float TargetScale = DefaultMovementGravityScale * FMath::Lerp(1.f, 1.f / FMath::Max(0.5f, HT), Smooth);
	M->GravityScale = TargetScale;
}

void AFELBasketballCharacter::Jump()
{
	UCharacterMovementComponent* M = GetCharacterMovement();
	if (!M || !CanJump())
	{
		return;
	}
#if PLATFORM_PS5
	const bool bBondsApexCommitSnap = bPendingSignatureApexIgnition && CachedSignatureTrait == EFELSignatureTrait::Bonds_Apex_Ignition;
#endif
	if (AFELBasketballPlayerController* PC = Cast<AFELBasketballPlayerController>(GetController()))
	{
		PC->InputLatencyMonitor_OnCharacterLaunch();
	}
#if PLATFORM_PS5
	if (bBondsApexCommitSnap)
	{
		if (APlayerController* HapPC = Cast<APlayerController>(GetController()))
		{
			FELConsoleHapticBridge::ApplyBondsApexTriggerSnap(HapPC);
		}
	}
#endif

	CachedAirControlBeforeBondsApexJump = M->AirControl;

	bLeftGroundByJump = true;
	bTrackJumpPeakForStats = true;
	LastJumpPeakZVelocityForStats = 0.f;

	const bool bGrounded = M->IsMovingOnGround();
	if (!bGrounded)
	{
		CoyoteTimeRemaining = 0.f;
	}

	// Gear + neuro pipeline (ApplyReadiness); Bonds Apex +20% applies here — before timing leakage — so signature scales the full stack.
	float PostGearJumpZ = CachedJumpZAfterNeuroPipeline;
	if (bPendingSignatureApexIgnition && CachedSignatureTrait == EFELSignatureTrait::Bonds_Apex_Ignition)
	{
		PostGearJumpZ += PendingKineticGatherJumpBoost;
		PendingKineticGatherJumpBoost = 0.f;
		// SM6 vs ES3.1 parity: signature tier maps to fixed multiplier (not frame dt — identical apex height across render feature levels).
		constexpr float SignatureChargeT = 1.f;
		const float BondsApexMult = FMath::GetMappedRangeValueClamped(
			FVector2D(0.f, 1.f),
			FVector2D(1.f, 1.2f),
			SignatureChargeT);
		PostGearJumpZ *= BondsApexMult;
		bBondsApexIgnitionSeekApex = true;
		bBondsApexWasRising = false;
		bPendingSignatureApexIgnition = false;
	}

	EFELJumpTimingBand Band = EFELJumpTimingBand::Good;
	const float TimingLeak = FELKineticLeakage::ComputeBondsBounceTimingLeakage(ApproachRunSeconds, Band);
	LastJumpTimingBand = Band;

	float EffectiveLeak = TimingLeak;
	if (bIsDunkContestContext)
	{
		LastJumpTimingLeakFactor = TimingLeak;
		EffectiveLeak = TimingLeak;
		if (Band == EFELJumpTimingBand::Perfect)
		{
			ConsecutivePerfectJumps++;
			if (ConsecutivePerfectJumps >= 3)
			{
				TriggerNeuroFlow();
				ConsecutivePerfectJumps = 0;
			}
		}
		else
		{
			ConsecutivePerfectJumps = 0;
		}
		M->JumpZVelocity = PostGearJumpZ * TimingLeak;
	}
	else
	{
		const float Soft = FMath::Lerp(0.90f, 1.f, FMath::InverseLerp(0.48f, 1.f, TimingLeak));
		LastJumpTimingLeakFactor = Soft;
		EffectiveLeak = Soft;
		M->JumpZVelocity = PostGearJumpZ * Soft;
	}

	if (Band == EFELJumpTimingBand::Perfect)
	{
		ApplyBondsBounceHitStop();
		OnPerfectDunk.Broadcast();
		if (bIsDunkContestContext)
		{
			FELNativeBridge::NotifyPerfectImpactHaptics(false);
		}
		if (UWorld* W = GetWorld())
		{
			W->GetTimerManager().SetTimer(
				PerfectDunkWarpHapticTimerHandle,
				this,
				&AFELBasketballCharacter::OnPerfectDunkWarpHapticTimerFired,
				0.11f,
				false);
		}
		SpawnPerfectDunkRimNiagara();
		PlayPerfectDunkSpatialBoom();
		if (UGameInstance* GI = GetGameInstance())
		{
			if (UFELNeuroFlowShareCaptureSubsystem* Share = GI->GetSubsystem<UFELNeuroFlowShareCaptureSubsystem>())
			{
				Share->RequestNeuroFlowMomentCapture(5.f);
			}
		}
		if (CinematicCamera)
		{
			CinematicCamera->NotifyPerfectTimingBand();
		}
		if (UWorld* W = GetWorld())
		{
			if (AFELBasketballGameState* GS = W->GetGameState<AFELBasketballGameState>())
			{
				GS->AddPerfectTimingHit();
			}
		}
	}

	ApplyJumpTakeoffAnimWarp(Band);
	if (AFELBasketballPlayerController* PC = Cast<AFELBasketballPlayerController>(GetController()))
	{
		PC->PlayBondsBounceHaptics(Band, EffectiveLeak);
	}
	SpawnBondsBounceLeakVFX(EffectiveLeak);

	if (bGrounded)
	{
		Super::Jump();
	}
	else
	{
		M->Velocity.Z = FMath::Max(M->Velocity.Z, M->JumpZVelocity);
	}
	ApproachRunSeconds = 0.f;
}

void AFELBasketballCharacter::Landed(const FHitResult& Hit)
{
	float ImpactZ = 0.f;
	if (UCharacterMovementComponent* MovePre = GetCharacterMovement())
	{
		ImpactZ = FMath::Abs(MovePre->Velocity.Z);
	}

	Super::Landed(Hit);
	CoyoteTimeRemaining = 0.f;
	bLeftGroundByJump = false;
	bTrackJumpPeakForStats = false;
	bBondsApexIgnitionSeekApex = false;
	bBondsApexWasRising = false;
	if (UCharacterMovementComponent* Move = GetCharacterMovement())
	{
		Move->JumpZVelocity = CachedJumpZAfterNeuroPipeline;
	}
	if (LandingIK)
	{
		const bool bStickLanding = bIsDunkContestContext || CachedActiveArenaMode.Contains(TEXT("gymnastics"));
		LandingIK->ApplyLandingFromScan(bStickLanding, CachedAnkleHeat01, CachedKneeHeat01);
	}

	if (HeavyLandingCameraShake)
	{
		if (APlayerController* PC = Cast<APlayerController>(GetController()))
		{
			const float Heat = CachedAnkleHeat01;
			const float Impact01 = FMath::Clamp(ImpactZ / 1100.f, 0.f, 1.f);
			const float Mag = FMath::Clamp(
				FMath::Lerp(0.12f, 1.05f, Heat) * FMath::Lerp(0.25f, 1.f, Impact01),
				0.f,
				1.85f);
			if (Mag > 0.08f && (ImpactZ > 220.f || Heat > 0.35f))
			{
				PC->ClientStartCameraShake(HeavyLandingCameraShake, Mag, ECameraShakePlaySpace::CameraLocal);
			}
		}
	}
}

void AFELBasketballCharacter::OnMovementModeChanged(EMovementMode PrevMovementMode, uint8 PreviousCustomMode)
{
	Super::OnMovementModeChanged(PrevMovementMode, PreviousCustomMode);
	if (UCharacterMovementComponent* M = GetCharacterMovement())
	{
		if (PrevMovementMode == MOVE_Walking && M->IsFalling())
		{
			if (!bLeftGroundByJump)
			{
				CoyoteTimeRemaining = CoyoteTimeSeconds;
			}
			bLeftGroundByJump = false;
		}
		if (M->IsMovingOnGround())
		{
			ApproachRunSeconds = 0.f;
			CoyoteTimeRemaining = 0.f;
		}
	}
}

void AFELBasketballCharacter::OnPerfectDunkWarpHapticTimerFired()
{
	FELNativeBridge::NotifyPerfectDunkWarpThud();
}

void AFELBasketballCharacter::EndPlay(const EEndPlayReason::Type EndPlayReason)
{
	GetWorldTimerManager().ClearTimer(JumpWarpResetTimerHandle);
	GetWorldTimerManager().ClearTimer(NeuroFlowAudioMixTimerHandle);
	GetWorldTimerManager().ClearTimer(HitStopResetTimerHandle);
	GetWorldTimerManager().ClearTimer(PerfectDunkWarpHapticTimerHandle);
	GetWorldTimerManager().ClearTimer(SonicFlareBroadcastTimerHandle);
	bSonicFlareBroadcastHangActive = false;
	bSonicFlareBroadcastBloomActive = false;
#if PLATFORM_PS5
	PopVeniceMirrorFinishRt();
#endif
	if (UWorld* W = GetWorld())
	{
		UGameplayStatics::SetGlobalTimeDilation(W, 1.f);
	}
	PopNeuroFlowDuckMix();
	Super::EndPlay(EndPlayReason);
}

void AFELBasketballCharacter::SetupPlayerInputComponent(UInputComponent* PlayerInputComponent)
{
	Super::SetupPlayerInputComponent(PlayerInputComponent);

	PlayerInputComponent->BindAxis("MoveForward", this, &AFELBasketballCharacter::MoveForward);
	PlayerInputComponent->BindAxis("MoveRight", this, &AFELBasketballCharacter::MoveRight);
	PlayerInputComponent->BindAxis("Turn", this, &AFELBasketballCharacter::Turn);
	PlayerInputComponent->BindAxis("LookUp", this, &AFELBasketballCharacter::LookUp);
	PlayerInputComponent->BindAction("Jump", IE_Pressed, this, &AFELBasketballCharacter::FEL_OnJumpPressed);
	PlayerInputComponent->BindAction("Jump", IE_Released, this, &AFELBasketballCharacter::FEL_OnJumpReleased);
}

void AFELBasketballCharacter::FEL_OnJumpPressed()
{
	if (AFELBasketballPlayerController* PC = Cast<AFELBasketballPlayerController>(GetController()))
	{
		PC->InputLatencyMonitor_MarkPress();
	}
	if (CanJump())
	{
		Jump();
	}
	else if (UFELInputComponent* FEL = Cast<UFELInputComponent>(InputComponent))
	{
		FEL->BufferJump();
	}
}

void AFELBasketballCharacter::FEL_OnJumpReleased()
{
	StopJumping();
}

void AFELBasketballCharacter::ApplyBondsBounceHitStop()
{
	CustomTimeDilation = 0.05f;
	if (GetWorld())
	{
		GetWorldTimerManager().SetTimer(
			HitStopResetTimerHandle,
			this,
			&AFELBasketballCharacter::ClearBondsBounceHitStop,
			2.f / 60.f,
			false);
	}
}

void AFELBasketballCharacter::ClearBondsBounceHitStop()
{
	CustomTimeDilation = 1.f;
}

void AFELBasketballCharacter::MoveForward(float Value)
{
	if (Controller && !FMath::IsNearlyZero(Value))
	{
		const FRotator YawRot(0.f, Controller->GetControlRotation().Yaw, 0.f);
		AddMovementInput(FRotationMatrix(YawRot).GetUnitAxis(EAxis::X), Value);
	}
}

void AFELBasketballCharacter::MoveRight(float Value)
{
	if (Controller && !FMath::IsNearlyZero(Value))
	{
		const FRotator YawRot(0.f, Controller->GetControlRotation().Yaw, 0.f);
		AddMovementInput(FRotationMatrix(YawRot).GetUnitAxis(EAxis::Y), Value);
	}
}

void AFELBasketballCharacter::Turn(float Value)
{
	AddControllerYawInput(Value);
}

void AFELBasketballCharacter::LookUp(float Value)
{
	AddControllerPitchInput(Value);
}
```

File: `UnrealStarter/BasketballGame/FELBasketballGameMode.h`

```cpp
// Copyright (c) Final Evolution Lab.

#pragma once

#include "CoreMinimal.h"
#include "FELArenaRulesTypes.h"
#include "FELArenaModeDefinitions.h"
#include "FELBasketballModes.h"
#include "FELGameModeDefinitions.h"
#include "FELReadinessTypes.h"
#include "FELMatchTypes.h"
#include "FELQuizWidget.h"
#include "FELOnboardingWidget.h"
#include "FELMatchResultsWidget.h"
#include "FELBiometricTypes.h"
#include "UFELArenaModeData.h"
#include "UFELDemoManager.h"
#include "Engine/StreamableManager.h"
#include "Templates/SharedPointer.h"
#include "GameFramework/GameModeBase.h"
#include "FELBasketballGameMode.generated.h"

class AFELBasketballActor;

DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FOnFELMatchComplete, FFELMatchResultSummary, Result);

/**
 * All modes share the same pawn, ball, HUD, and hoop volumes; rules differ via GameState.
 */
UCLASS()
class FINALEVOLUTIONLAB_API AFELBasketballGameMode : public AGameModeBase
{
	GENERATED_BODY()

public:
	AFELBasketballGameMode();

	/** 12-mode manager: from `readiness_snapshot.json` → `active_mode` + `ArenaSettings.json`. */
	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "FEL|Arena")
	EFELArenaMode CurrentMode = EFELArenaMode::BasketballHeadToHead;

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "FEL|Arena")
	FFELArenaRules CurrentArenaRules;

	/** Async-loaded Primary Data Asset for CurrentMode (null until load or if asset missing). */
	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "FEL|Arena")
	TObjectPtr<UFELArenaModeData> LoadedArenaModeData = nullptr;

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "FEL|Demonstration")
	TObjectPtr<UFELDemoManager> DemoManager = nullptr;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "FEL|Mode")
	EFELBasketballPlayMode PlayMode = EFELBasketballPlayMode::StreetBall;

	/** Used when PlayMode == TimedBlitz. */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "FEL|Mode", meta = (ClampMin = "5", UIMin = "5"))
	float TimedBlitzSeconds = 120.f;

	/** Used when PlayMode == HalfCourtShootout. */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "FEL|Mode", meta = (ClampMin = "1", UIMin = "1"))
	int32 ShootoutTargetBuckets = 11;

	/** Used when PlayMode == FirstToTwentyOne (override if you duplicate mode in Blueprint). */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "FEL|Mode", meta = (ClampMin = "1", UIMin = "1"))
	int32 FirstToNTargetBuckets = 21;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "FEL")
	TSubclassOf<AFELBasketballActor> BallClass;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "FEL")
	FVector BallSpawnOffset = FVector(120.f, 0.f, 40.f);

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "FEL")
	FVector SecondBallSpawnOffset = FVector(120.f, 140.f, 40.f);

	/** Optional WBP subclass of UFELQuizWidget; defaults to native C++ layout. */
	UPROPERTY(EditDefaultsOnly, Category = "FEL|BrainBrawl")
	TSubclassOf<UFELQuizWidget> BrainBrawlQuizWidgetClass;

	/** First Lab visit: dismiss writes lab_onboarding_completed.flag (PROJECT_FLOWS). */
	UPROPERTY(EditDefaultsOnly, Category = "FEL|Onboarding")
	TSubclassOf<UFELOnboardingWidget> LabOnboardingWidgetClass;

	/** Victory / Bonds Bounce screen; optional WBP subclass of UFELMatchResultsWidget. */
	UPROPERTY(EditDefaultsOnly, Category = "FEL|Match")
	TSubclassOf<UFELMatchResultsWidget> MatchResultsWidgetClass;

	/** Get Ready countdown before InProgress (seconds). */
	UPROPERTY(EditDefaultsOnly, Category = "FEL|Match", meta = (ClampMin = "0", UIMin = "0"))
	float CountdownToStartSeconds = 3.f;

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "FEL|Match")
	EFELMatchPhase MatchPhase = EFELMatchPhase::WaitingToStart;

	/** Fired when GameState reports match end; includes Shards/XP/neuro summary. */
	UPROPERTY(BlueprintAssignable, Category = "FEL|Match")
	FOnFELMatchComplete OnMatchComplete;

	/** Swift `GameModeId.rawValue` for session export / HUD parity. */
	UFUNCTION(BlueprintCallable, Category = "FEL")
	FString GetArenaGameModeId() const;

	/** Mirror subsystem cache into Blueprint-readable Neuro* (call after hot-reload or external ApplyReadiness). */
	UFUNCTION(BlueprintCallable, Category = "FEL|NeuroMechanic")
	void SyncNeuroFieldsFromSnapshot(const FFELReadinessSnapshot& Snap);

	/** Re-run after hot-reload or shell push (PIE): re-apply GameState rules from snapshot + registry. */
	UFUNCTION(BlueprintCallable, Category = "FEL|Arena")
	void RefreshArenaConfigurationFromSnapshot(const FFELReadinessSnapshot& Snap);

	/** Bio-Sync / readiness handoff: async warm-up Digital Twin mesh + active venue (`UFELAssetRegistrySubsystem`). */
	UFUNCTION(BlueprintCallable, Category = "FEL|Arena|Assets")
	void WarmUp3DAssets();

	/** Ghost "Perfect Form" demonstrator while WaitingToStart (onboarding Watch Demo). */
	UFUNCTION(BlueprintCallable, Category = "FEL|Demonstration")
	void TriggerExerciseDemo();

	/** Blend camera back to pawn and destroy demonstrator (call from onboarding dismiss). */
	UFUNCTION(BlueprintCallable, Category = "FEL|Demonstration")
	void EndExerciseDemoIfActive();

	virtual void Tick(float DeltaSeconds) override;

	virtual void PostInitializeComponents() override;

	virtual void EndPlay(const EEndPlayReason::Type EndPlayReason) override;

	virtual void RestartPlayer(AController* NewPlayer) override;

protected:
	virtual void BeginPlay() override;

	virtual void StartPlay() override;

	/** Load readiness (cache only), parse `active_mode`, merge factory + ArenaSettings.json + async UFELArenaModeData. */
	void ConfigureArenaFromReadinessSnapshot(const FFELReadinessSnapshot& Snap);

	/** Data-driven hooks — override in Blueprint GameMode or C++ subclass. */
	UFUNCTION(BlueprintNativeEvent, Category = "FEL|Arena")
	void OnBrainBrawlModeActivated();

	UFUNCTION(BlueprintNativeEvent, Category = "FEL|Arena")
	void OnDunkContestModeActivated();

	void SpawnMatchBallAtOffset(const FVector& OffsetFromPlayerStart);
	void ApplyModeToGameState();
	/** Presentation hooks (quiz / dunk announce): only when PreviousMode != CurrentMode (avoids duplicate quiz on R reload). StartPlay passes Unknown so first activation still fires. */
	void ApplyModeSpecificBehaviors(EFELArenaMode PreviousMode);
	void LockPlayerInputIfMatchEnded();

	void MaybeStartMatchFlow();
	void StartMatchCountdown();
	void EnterMatchInProgressPhase();
	void BindGameStateMatchDelegate();

	UFUNCTION()
	void HandleGameStateMatchEnded();

	UFUNCTION()
	void OnLabOnboardingDismissed();

	FFELMatchResultSummary BuildMatchResultSummary() const;

	void ShowMatchResultsWidget(const FFELMatchResultSummary& Summary);

	/** Last snapshot from UFELNeuroMechanicBridgeSubsystem after StartPlay (single source of truth). */
	FFELReadinessSnapshot LoadedReadiness;

	bool bLockedInputOnMatchEnd = false;

	bool bMatchCompletionHandled = false;

	FTimerHandle MatchStartCountdownTimer;

	/** Loads only the active mode Data Asset + dependencies (M4-friendly). */
	FStreamableManager ArenaModeStreamableManager;
	TSharedPtr<FStreamableHandle> ArenaModeLoadHandle;

	void ApplyArenaRulesFromFactorySync();
	void RequestArenaModeDataAsync();
	void OnArenaModeDataLoaded();
	void BroadcastBiometricToWorld();
	FFELBiometricContext BuildBiometricContext() const;

	/** Neuro-Mechanic globals for Blueprint/HUD (mirrors last loaded snapshot). */
	UPROPERTY(BlueprintReadOnly, Category = "FEL|NeuroMechanic")
	double NeuroVerticalEstimateInches = 0.0;

	UPROPERTY(BlueprintReadOnly, Category = "FEL|NeuroMechanic")
	double NeuroHangTimeScale = 1.0;

	UPROPERTY(BlueprintReadOnly, Category = "FEL|NeuroMechanic")
	double NeuroKineticLeakageMultiplier = 1.0;

	UPROPERTY(BlueprintReadOnly, Category = "FEL|NeuroMechanic")
	double NeuroPRQScore = 75.0;

	/** SFMA rotation screen — mirrored from `readiness_snapshot.json` → fascial congestion in Lab. */
	UPROPERTY(BlueprintReadOnly, Category = "FEL|NeuroMechanic|SFMA")
	bool NeuroSFMA_SpiralRotationPass = true;
};
```

File: `UnrealStarter/BasketballGame/FELBasketballGameMode.cpp`

```cpp
// Copyright (c) Final Evolution Lab.

#include "FELBasketballGameMode.h"
#include "FELArenaBridge.h"
#include "FELArenaModeCatalog.h"
#include "FELArenaRulesRegistry.h"
#include "IFELBiometricReceiver.h"
#include "FELBasketballActor.h"
#include "FELBasketballCharacter.h"
#include "FELBasketballGameState.h"
#include "FELBasketballHUD.h"
#include "FELBasketballPlayerController.h"
#include "FELArenaModeDefinitions.h"
#include "FELNeuroMechanicBridgeSubsystem.h"
#include "FELPlatformPaths.h"
#include "FELProgressionSubsystem.h"
#include "FELQuizWidget.h"
#include "FELSessionExport.h"
#include "UFELAcademySubsystem.h"
#include "FELSportMastery.h"
#include "FELOnboardingWidget.h"
#include "FELNativeBridge.h"
#include "FELMatchResultsWidget.h"
#include "UFELArenaModeData.h"
#include "UFELAssetRegistrySubsystem.h"
#include "FinalEvolutionLab.h"
#include "Blueprint/UserWidget.h"
#include "Engine/World.h"
#include "FELVenueShopFlyByDirector.h"
#include "GameFramework/Actor.h"
#include "GameFramework/PlayerController.h"
#include "GameFramework/PlayerStart.h"
#include "GameFramework/SpectatorPawn.h"
#include "Kismet/GameplayStatics.h"
#include "TimerManager.h"

namespace
{
	static double ComputeNeuroPerformanceScore(const double PRQ, const int32 ScoreBuckets, const int32 BrainBoosts)
	{
		const double P = FMath::Clamp(PRQ, 0.0, 100.0);
		const double S = FMath::Clamp(static_cast<double>(ScoreBuckets) * 4.0, 0.0, 40.0);
		const double B = FMath::Clamp(static_cast<double>(BrainBoosts) * 7.0, 0.0, 35.0);
		return FMath::Clamp(0.55 * P + 0.35 * S + B, 0.0, 100.0);
	}

	static double ComputeMentalSharpnessScore(const double PRQ, const int32 BrainBoosts)
	{
		const double P = FMath::Clamp(PRQ, 0.0, 100.0);
		const double B = FMath::Clamp(static_cast<double>(BrainBoosts) * 12.0, 0.0, 48.0);
		return FMath::Clamp(0.45 * P + B, 0.0, 100.0);
	}
}

AFELBasketballGameMode::AFELBasketballGameMode()
{
	PrimaryActorTick.bCanEverTick = true;

	// 3D Digital Twin: skeletal mesh pawn (`AFELBasketballCharacter`), not a 2D spectator sprite.
	DefaultPawnClass = AFELBasketballCharacter::StaticClass();
	PlayerControllerClass = AFELBasketballPlayerController::StaticClass();
	BallClass = AFELBasketballActor::StaticClass();
	GameStateClass = AFELBasketballGameState::StaticClass();
	HUDClass = AFELBasketballHUD::StaticClass();
	DemoManager = CreateDefaultSubobject<UFELDemoManager>(TEXT("FELDemoManager"));
}

void AFELBasketballGameMode::PostInitializeComponents()
{
	Super::PostInitializeComponents();

	if (UGameInstance* GI = GetGameInstance())
	{
		if (UFELNeuroMechanicBridgeSubsystem* Bridge = GI->GetSubsystem<UFELNeuroMechanicBridgeSubsystem>())
		{
			FString Err;
			if (Bridge->TryLoadSnapshotIntoCacheOnly(Err))
			{
				FFELReadinessSnapshot Snap;
				Bridge->GetCachedSnapshot(Snap);
				ConfigureArenaFromReadinessSnapshot(Snap);
			}
			else
			{
				ConfigureArenaFromReadinessSnapshot(FFELReadinessSnapshot());
			}
		}
	}
}

void AFELBasketballGameMode::RestartPlayer(AController* NewPlayer)
{
	Super::RestartPlayer(NewPlayer);
	if (!NewPlayer || NewPlayer->GetPawn() != nullptr)
	{
		return;
	}
	UWorld* const W = GetWorld();
	if (!W)
	{
		return;
	}
	AActor* Start = FindPlayerStart(NewPlayer);
	if (!Start)
	{
		return;
	}
	UClass* SpecClass = SpectatorClass ? *SpectatorClass : ASpectatorPawn::StaticClass();
	if (!SpecClass)
	{
		return;
	}
	FActorSpawnParameters Params;
	Params.SpawnCollisionHandlingOverride = ESpawnActorCollisionHandlingMethod::AdjustIfPossibleButAlwaysSpawn;
	if (APawn* Sp = W->SpawnActor<APawn>(SpecClass, Start->GetActorLocation(), Start->GetActorRotation(), Params))
	{
		NewPlayer->Possess(Sp);
		UE_LOG(LogTemp, Warning, TEXT("FELGameMode: Default pawn missing after RestartPlayer — spectator fallback at %s"), *Start->GetActorLocation().ToString());
	}
}

void AFELBasketballGameMode::ConfigureArenaFromReadinessSnapshot(const FFELReadinessSnapshot& Snap)
{
	CurrentMode = FELArenaModeFromIdString(Snap.ActiveArenaMode);
	if (CurrentMode == EFELArenaMode::Unknown)
	{
		CurrentMode = EFELArenaMode::BasketballHeadToHead;
	}

	ApplyArenaRulesFromFactorySync();
	RequestArenaModeDataAsync();
}

void AFELBasketballGameMode::ApplyArenaRulesFromFactorySync()
{
	CurrentArenaRules = FELArenaRulesRegistry::GetMergedRules(CurrentMode);
	PlayMode = CurrentArenaRules.UnrealBasketballSlice;
	TimedBlitzSeconds = FMath::Max(5.f, CurrentArenaRules.TimeLimitSeconds);

	if (PlayMode == EFELBasketballPlayMode::HalfCourtShootout)
	{
		ShootoutTargetBuckets = FMath::Max(1, CurrentArenaRules.TargetScore);
	}
	else if (PlayMode == EFELBasketballPlayMode::FirstToTwentyOne)
	{
		FirstToNTargetBuckets = FMath::Max(1, CurrentArenaRules.TargetScore);
	}
}

void AFELBasketballGameMode::RequestArenaModeDataAsync()
{
	if (ArenaModeLoadHandle.IsValid())
	{
		ArenaModeLoadHandle->CancelHandle();
		ArenaModeLoadHandle.Reset();
	}

	const FSoftObjectPath Path = FELArenaModeCatalog::GetDefaultSoftPathForMode(CurrentMode);
	TArray<FSoftObjectPath> Paths;
	Paths.Add(Path);

	ArenaModeLoadHandle = ArenaModeStreamableManager.RequestAsyncLoad(
		Paths,
		FStreamableDelegate::CreateUObject(this, &AFELBasketballGameMode::OnArenaModeDataLoaded));
}

void AFELBasketballGameMode::OnArenaModeDataLoaded()
{
	UFELArenaModeData* DA = nullptr;
	if (ArenaModeLoadHandle.IsValid())
	{
		DA = Cast<UFELArenaModeData>(ArenaModeLoadHandle->GetLoadedAsset());
	}

	if (DA && DA->GetArenaMode() == CurrentMode)
	{
		LoadedArenaModeData = DA;
		CurrentArenaRules = DA->ArenaRules;
		FELArenaRulesRegistry::ApplyJsonOverridesToRules(CurrentMode, CurrentArenaRules);
		FELArenaRulesRegistry::SanitizeRulesInPlace(CurrentArenaRules, CurrentMode);
	}
	else
	{
		if (DA && DA->GetArenaMode() != CurrentMode)
		{
#if !UE_BUILD_SHIPPING
			UE_LOG(LogTemp, Warning,
				TEXT("FEL: UFELArenaModeData ArenaMode mismatch (expected %d, asset %d). Using factory merge."),
				static_cast<int32>(CurrentMode),
				static_cast<int32>(DA->GetArenaMode()));
#endif
		}
		LoadedArenaModeData = nullptr;
		ApplyArenaRulesFromFactorySync();
	}

	PlayMode = CurrentArenaRules.UnrealBasketballSlice;
	TimedBlitzSeconds = FMath::Max(5.f, CurrentArenaRules.TimeLimitSeconds);
	if (PlayMode == EFELBasketballPlayMode::HalfCourtShootout)
	{
		ShootoutTargetBuckets = FMath::Max(1, CurrentArenaRules.TargetScore);
	}
	else if (PlayMode == EFELBasketballPlayMode::FirstToTwentyOne)
	{
		FirstToNTargetBuckets = FMath::Max(1, CurrentArenaRules.TargetScore);
	}

	if (GetWorld() && GetWorld()->HasBegunPlay())
	{
		ApplyModeToGameState();
		BroadcastBiometricToWorld();
		if (APlayerController* PC = GetWorld()->GetFirstPlayerController())
		{
			if (AFELBasketballPlayerController* BPC = Cast<AFELBasketballPlayerController>(PC))
			{
				BPC->ApplyArenaInputForMode(CurrentMode);
			}
		}
	}
}

FFELBiometricContext AFELBasketballGameMode::BuildBiometricContext() const
{
	FFELBiometricContext C;
	C.PRQScore = NeuroPRQScore;
	C.NeuralDrive = LoadedReadiness.NeuralDrive;
	C.PopForce = LoadedReadiness.PopForce;
	C.VerticalEstimateInches = NeuroVerticalEstimateInches;
	C.HangTimeScale = NeuroHangTimeScale;
	C.KineticLeakageMultiplier = NeuroKineticLeakageMultiplier;
	C.EfficiencyScore = LoadedReadiness.EfficiencyScore;
	C.bSFMASpiralRotationScreenPass = NeuroSFMA_SpiralRotationPass;
	return C;
}

void AFELBasketballGameMode::BroadcastBiometricToWorld()
{
	if (!GetWorld())
	{
		return;
	}
	const FFELBiometricContext Ctx = BuildBiometricContext();
	TArray<AActor*> Actors;
	UGameplayStatics::GetAllActorsWithInterface(GetWorld(), UFELBiometricReceiver::StaticClass(), Actors);
	for (AActor* A : Actors)
	{
		IFELBiometricReceiver::Execute_ApplyBiometricContext(A, Ctx);
	}
}

void AFELBasketballGameMode::ApplyModeSpecificBehaviors(const EFELArenaMode PreviousMode)
{
	if (PreviousMode == CurrentMode)
	{
		return;
	}
	switch (CurrentMode)
	{
	case EFELArenaMode::BrainBrawl:
		OnBrainBrawlModeActivated();
		break;
	case EFELArenaMode::BasketballDunkContest:
		OnDunkContestModeActivated();
		break;
	default:
		break;
	}
}

void AFELBasketballGameMode::OnBrainBrawlModeActivated_Implementation()
{
	if (!GetWorld())
	{
		return;
	}
	APlayerController* PC = GetWorld()->GetFirstPlayerController();
	if (!PC)
	{
		return;
	}
	const TSubclassOf<UFELQuizWidget> Cls = BrainBrawlQuizWidgetClass ? BrainBrawlQuizWidgetClass : UFELQuizWidget::StaticClass();
	UFELQuizWidget* Quiz = CreateWidget<UFELQuizWidget>(PC, Cls);
	if (!Quiz)
	{
		return;
	}
	Quiz->InitializeQuiz(GetGameInstance());
	Quiz->AddToViewport(120);
	PC->SetShowMouseCursor(true);
	FInputModeGameAndUI Mode;
	Mode.SetWidgetToFocus(Quiz->TakeWidget());
	Mode.SetLockMouseToViewportBehavior(EMouseLockMode::DoNotLock);
	PC->SetInputMode(Mode);
}

void AFELBasketballGameMode::OnDunkContestModeActivated_Implementation()
{
	// Dunk contest physics + rules come from snapshot + FFELArenaRules::bIsDunkContest (ApplyNeuroArenaGameplay on the pawn).
}

void AFELBasketballGameMode::RefreshArenaConfigurationFromSnapshot(const FFELReadinessSnapshot& Snap)
{
	const EFELArenaMode PreviousMode = CurrentMode;
	EFELArenaMode NewMode = FELArenaModeFromIdString(Snap.ActiveArenaMode);
	if (NewMode == EFELArenaMode::Unknown)
	{
		NewMode = EFELArenaMode::BasketballHeadToHead;
	}
	if (UGameInstance* GI = GetGameInstance())
	{
		if (UFELAssetRegistrySubsystem* R = GI->GetSubsystem<UFELAssetRegistrySubsystem>())
		{
			if (PreviousMode != NewMode && PreviousMode != EFELArenaMode::Unknown)
			{
				R->PurgeVenueForMode(PreviousMode);
			}
		}
	}
	ConfigureArenaFromReadinessSnapshot(Snap);
	ApplyModeToGameState();
	ApplyModeSpecificBehaviors(PreviousMode);
}

void AFELBasketballGameMode::BeginPlay()
{
	Super::BeginPlay();
	UE_LOG(LogTemp, Warning, TEXT("GOLD MASTER: Level Tick Started"));
	if (UWorld* const W = GetWorld())
	{
		FELNativeBridge::NotifyLevelLoaded(W->GetMapName());

		const FString ShortMap = UGameplayStatics::GetCurrentLevelName(W, true);
		if (ShortMap.Contains(TEXT("Luma_Venice_Shop")) || ShortMap.Contains(TEXT("Luma_Venice")))
		{
			FActorSpawnParameters FlyParams;
			FlyParams.SpawnCollisionHandlingOverride = ESpawnActorCollisionHandlingMethod::AlwaysSpawn;
			W->SpawnActor<AFELVenueShopFlyByDirector>(AFELVenueShopFlyByDirector::StaticClass(), FVector::ZeroVector, FRotator::ZeroRotator, FlyParams);
		}
	}
}

void AFELBasketballGameMode::StartPlay()
{
	bLockedInputOnMatchEnd = false;
	bMatchCompletionHandled = false;
	MatchPhase = EFELMatchPhase::WaitingToStart;

	Super::StartPlay();

	if (UGameInstance* GI = GetGameInstance())
	{
		if (UFELProgressionSubsystem* Prog = GI->GetSubsystem<UFELProgressionSubsystem>())
		{
			Prog->ResetSessionCounters();
		}
	}

	LoadedReadiness = FFELReadinessSnapshot();
	if (UGameInstance* GI = GetGameInstance())
	{
		if (UFELNeuroMechanicBridgeSubsystem* Bridge = GI->GetSubsystem<UFELNeuroMechanicBridgeSubsystem>())
		{
			FString Err;
			if (!Bridge->HasCachedSnapshot())
			{
				Bridge->TryLoadSnapshotIntoCacheOnly(Err);
			}
			if (Bridge->HasCachedSnapshot())
			{
				Bridge->GetCachedSnapshot(LoadedReadiness);
			}
		}
	}

	ConfigureArenaFromReadinessSnapshot(LoadedReadiness);

	ApplyModeToGameState();

	switch (CurrentArenaRules.BallSpawnType)
	{
	case EFELArenaBallSpawnType::None:
		break;
	case EFELArenaBallSpawnType::SingleAtPrimary:
		if (CurrentArenaRules.BallCount > 0)
		{
			SpawnMatchBallAtOffset(BallSpawnOffset);
		}
		break;
	case EFELArenaBallSpawnType::DualHalfCourt:
		SpawnMatchBallAtOffset(BallSpawnOffset);
		SpawnMatchBallAtOffset(SecondBallSpawnOffset);
		break;
	}

	if (UGameInstance* GI = GetGameInstance())
	{
		if (UFELNeuroMechanicBridgeSubsystem* Bridge = GI->GetSubsystem<UFELNeuroMechanicBridgeSubsystem>())
		{
			Bridge->ApplyReadiness(LoadedReadiness);
		}
	}

	SyncNeuroFieldsFromSnapshot(LoadedReadiness);

	if (AFELBasketballGameState* GS = GetGameState<AFELBasketballGameState>())
	{
		GS->SetReadinessContext(LoadedReadiness, GetArenaGameModeId());
	}

	BindGameStateMatchDelegate();
	if (APlayerController* PC = GetWorld()->GetFirstPlayerController())
	{
		if (AFELBasketballPlayerController* BPC = Cast<AFELBasketballPlayerController>(PC))
		{
			BPC->ApplyArenaInputForMode(CurrentMode);
		}
	}
	MaybeStartMatchFlow();
}

void AFELBasketballGameMode::EndPlay(const EEndPlayReason::Type EndPlayReason)
{
	if (ArenaModeLoadHandle.IsValid())
	{
		ArenaModeLoadHandle->CancelHandle();
		ArenaModeLoadHandle.Reset();
	}
	EndExerciseDemoIfActive();
	if (UWorld* W = GetWorld())
	{
		W->GetTimerManager().ClearTimer(MatchStartCountdownTimer);
	}
	if (AFELBasketballGameState* GS = GetGameState<AFELBasketballGameState>())
	{
		GS->OnMatchEnded.RemoveDynamic(this, &AFELBasketballGameMode::HandleGameStateMatchEnded);
	}
	Super::EndPlay(EndPlayReason);
}

void AFELBasketballGameMode::Tick(float DeltaSeconds)
{
	Super::Tick(DeltaSeconds);

	if (MatchPhase == EFELMatchPhase::InProgress)
	{
		if (AFELBasketballGameState* GS = GetGameState<AFELBasketballGameState>())
		{
			GS->TickMatchTime(DeltaSeconds);
		}
	}

	if (AFELBasketballGameState* GS = GetGameState<AFELBasketballGameState>())
	{
		LockPlayerInputIfMatchEnded();
	}
}

void AFELBasketballGameMode::BindGameStateMatchDelegate()
{
	if (AFELBasketballGameState* GS = GetGameState<AFELBasketballGameState>())
	{
		GS->OnMatchEnded.AddDynamic(this, &AFELBasketballGameMode::HandleGameStateMatchEnded);
	}
}

void AFELBasketballGameMode::MaybeStartMatchFlow()
{
	if (!GetWorld())
	{
		return;
	}
	if (!FELPlatformPaths::HasCompletedLabOnboarding())
	{
		const TSubclassOf<UFELOnboardingWidget> Cls = LabOnboardingWidgetClass ? LabOnboardingWidgetClass : UFELOnboardingWidget::StaticClass();
		if (APlayerController* PC = GetWorld()->GetFirstPlayerController())
		{
			UFELOnboardingWidget* W = CreateWidget<UFELOnboardingWidget>(PC, Cls);
			if (W)
			{
				W->InitializeLabOnboarding();
				W->OnDismissed.AddDynamic(this, &AFELBasketballGameMode::OnLabOnboardingDismissed);
				W->AddToViewport(200);
				PC->SetShowMouseCursor(true);
				FInputModeGameAndUI Mode;
				Mode.SetWidgetToFocus(W->TakeWidget());
				Mode.SetLockMouseToViewportBehavior(EMouseLockMode::DoNotLock);
				PC->SetInputMode(Mode);
				return;
			}
		}
	}
	StartMatchCountdown();
}

void AFELBasketballGameMode::OnLabOnboardingDismissed()
{
	EndExerciseDemoIfActive();
	StartMatchCountdown();
}

void AFELBasketballGameMode::StartMatchCountdown()
{
	MatchPhase = EFELMatchPhase::WaitingToStart;
	if (UGameInstance* GI = GetGameInstance())
	{
		if (UFELNeuroMechanicBridgeSubsystem* B = GI->GetSubsystem<UFELNeuroMechanicBridgeSubsystem>())
		{
			B->SetBrainBrawlBoostCountingEnabled(false);
		}
	}
	if (APlayerController* PC = GetWorld()->GetFirstPlayerController())
	{
		PC->SetIgnoreMoveInput(true);
	}
	if (UWorld* W = GetWorld())
	{
		W->GetTimerManager().SetTimer(
			MatchStartCountdownTimer,
			this,
			&AFELBasketballGameMode::EnterMatchInProgressPhase,
			FMath::Max(0.1f, CountdownToStartSeconds),
			false);
	}
}

void AFELBasketballGameMode::EnterMatchInProgressPhase()
{
	MatchPhase = EFELMatchPhase::InProgress;
	ApplyModeSpecificBehaviors(EFELArenaMode::Unknown);
	if (UGameInstance* GI = GetGameInstance())
	{
		if (UFELNeuroMechanicBridgeSubsystem* B = GI->GetSubsystem<UFELNeuroMechanicBridgeSubsystem>())
		{
			B->ResetBrainBrawlBoostCountForActivePhase();
			B->SetBrainBrawlBoostCountingEnabled(true);
		}
	}
	if (APlayerController* PC = GetWorld()->GetFirstPlayerController())
	{
		PC->SetIgnoreMoveInput(false);
	}
}

void AFELBasketballGameMode::HandleGameStateMatchEnded()
{
	if (bMatchCompletionHandled || !GetWorld())
	{
		return;
	}
	bMatchCompletionHandled = true;
	MatchPhase = EFELMatchPhase::MatchComplete;

	if (UGameInstance* GI = GetGameInstance())
	{
		if (UFELNeuroMechanicBridgeSubsystem* B = GI->GetSubsystem<UFELNeuroMechanicBridgeSubsystem>())
		{
			B->SetBrainBrawlBoostCountingEnabled(false);
		}
	}

	const FFELMatchResultSummary Summary = BuildMatchResultSummary();
	OnMatchComplete.Broadcast(Summary);
	FELNativeBridge::NotifyMatchCompleteIOSFeedback(Summary);

	if (UGameInstance* GI = GetGameInstance())
	{
		if (UFELProgressionSubsystem* P = GI->GetSubsystem<UFELProgressionSubsystem>())
		{
			P->ApplyMatchRewards(Summary);
		}
	}

	FString Err;
	const bool bWroteSession = FELSessionExport::WriteSessionResults(Summary, GetArenaGameModeId(), &Err);
	if (AFELBasketballGameState* GS = GetGameState<AFELBasketballGameState>())
	{
		FELSessionExport::WriteLastSession(GS, GetWorld(), nullptr);
	}
	if (bWroteSession)
	{
		FELNativeBridge::NotifySessionResultsReady(FELPlatformPaths::GetSessionResultsJsonPath());
		if (UGameInstance* GIA = GetGameInstance())
		{
			if (UFELAcademySubsystem* Aca = GIA->GetSubsystem<UFELAcademySubsystem>())
			{
				Aca->ClearSessionAcademyProgressAfterExport();
			}
		}
	}
	ShowMatchResultsWidget(Summary);
}

FFELMatchResultSummary AFELBasketballGameMode::BuildMatchResultSummary() const
{
	FFELMatchResultSummary R;
	const AFELBasketballGameState* GS = GetGameState<AFELBasketballGameState>();
	const FString ModeId = GetArenaGameModeId();
	if (!GS)
	{
		R.GameModeId = ModeId;
		return R;
	}

	const int32 Score = GS->GetScore();
	const bool bEconomy = GS->IsScoringEnabled();
	double PRQ = LoadedReadiness.PRQScore;
	if (UGameInstance* GI = GetGameInstance())
	{
		if (UFELNeuroMechanicBridgeSubsystem* Br = GI->GetSubsystem<UFELNeuroMechanicBridgeSubsystem>())
		{
			FFELReadinessSnapshot S;
			Br->GetCachedSnapshot(S);
			PRQ = S.PRQScore;
		}
	}

	int32 BrainBoosts = 0;
	if (UGameInstance* GI = GetGameInstance())
	{
		if (UFELNeuroMechanicBridgeSubsystem* Br = GI->GetSubsystem<UFELNeuroMechanicBridgeSubsystem>())
		{
			BrainBoosts = Br->GetBrainBrawlBoostCountThisSession();
		}
	}

	const int32 BaseShards = FELArenaBridge::ComputeShardsEarned(Score, PRQ, ModeId, bEconomy);
	const int32 ShardBonus = BrainBoosts * 8;
	R.ShardsEarned = FMath::Clamp(BaseShards + ShardBonus, 8, 80);
	R.XPEarned = 30 + Score * 6 + BrainBoosts * 15;
	R.PRQBonus = FELArenaBridge::ComputePRQBonus(Score, PRQ, bEconomy);
	R.FinalPRQ = PRQ;
	R.Score = Score;
	R.OpponentScore = 0;
	R.BrainBrawlBoostCount = BrainBoosts;
	R.NeuroPerformanceScore = ComputeNeuroPerformanceScore(PRQ, Score, BrainBoosts);
	R.MentalSharpnessScore = ComputeMentalSharpnessScore(PRQ, BrainBoosts);
	R.GameModeId = ModeId;
	R.bEconomyEnabled = bEconomy;
	R.MatchEndBanner = GS->GetMatchEndBanner();
	R.MatchEndDetail = GS->GetMatchEndDetail();

	if (UWorld* W = GetWorld())
	{
		const double Now = static_cast<double>(W->GetTimeSeconds());
		R.DurationSeconds = FMath::Max(0, FMath::RoundToInt(Now - GS->GetMatchStartWorldTimeSeconds()));
	}

	FFELReadinessSnapshot SnapForMastery = LoadedReadiness;
	if (UGameInstance* GI = GetGameInstance())
	{
		if (UFELNeuroMechanicBridgeSubsystem* Br = GI->GetSubsystem<UFELNeuroMechanicBridgeSubsystem>())
		{
			if (Br->HasCachedSnapshot())
			{
				Br->GetCachedSnapshot(SnapForMastery);
			}
		}
	}
	FELSportMastery::ComputeMasteryScoreAndMetric(ModeId, SnapForMastery, Score, R.MasteryScore, R.MasteryMetricId);

	if (UGameInstance* GIA = GetGameInstance())
	{
		if (UFELAcademySubsystem* Aca = GIA->GetSubsystem<UFELAcademySubsystem>())
		{
			Aca->GetSessionAcademyProgress(R.AcademyCompletedModuleKeys, R.AcademyEvolutionShardsEarned);
		}
	}

	R.ArenaResult.FinalScore = Score;
	R.ArenaResult.NewPRQEstimate = PRQ;
	R.ArenaResult.EvolutionShardsEarned = R.ShardsEarned;
	R.ArenaResult.PerfectTimingCount = GS->GetPerfectTimingHits();
	R.ArenaResult.bBestMomentReplayAvailable = R.ArenaResult.PerfectTimingCount > 0;

	return R;
}

void AFELBasketballGameMode::ShowMatchResultsWidget(const FFELMatchResultSummary& Summary)
{
	if (!GetWorld())
	{
		return;
	}
	APlayerController* PC = GetWorld()->GetFirstPlayerController();
	if (!PC)
	{
		return;
	}
	const TSubclassOf<UFELMatchResultsWidget> Cls = MatchResultsWidgetClass ? MatchResultsWidgetClass : UFELMatchResultsWidget::StaticClass();
	UFELMatchResultsWidget* W = CreateWidget<UFELMatchResultsWidget>(PC, Cls);
	if (!W)
	{
		return;
	}
	W->InitializeWithSummary(Summary);
	W->AddToViewport(250);
	PC->SetShowMouseCursor(true);
	FInputModeGameAndUI Mode;
	Mode.SetWidgetToFocus(W->TakeWidget());
	Mode.SetLockMouseToViewportBehavior(EMouseLockMode::DoNotLock);
	PC->SetInputMode(Mode);
}

void AFELBasketballGameMode::ApplyModeToGameState()
{
	AFELBasketballGameState* GS = GetGameState<AFELBasketballGameState>();
	if (!GS)
	{
		return;
	}

	const FFELArenaRules& R = CurrentArenaRules;
	switch (PlayMode)
	{
	case EFELBasketballPlayMode::StreetBall:
		GS->ApplyRules(R.ModeDisplayName, R.bScoringEnabled, R.TargetScore, 0.f);
		break;
	case EFELBasketballPlayMode::HalfCourtShootout:
		GS->ApplyRules(R.ModeDisplayName, R.bScoringEnabled, ShootoutTargetBuckets, 0.f);
		break;
	case EFELBasketballPlayMode::TimedBlitz:
		GS->ApplyRules(R.ModeDisplayName, R.bScoringEnabled, R.TargetScore, TimedBlitzSeconds);
		break;
	case EFELBasketballPlayMode::Practice:
		GS->ApplyRules(R.ModeDisplayName, R.bScoringEnabled, 0, 0.f);
		break;
	case EFELBasketballPlayMode::FirstToTwentyOne:
		GS->ApplyRules(R.ModeDisplayName, R.bScoringEnabled, FirstToNTargetBuckets, 0.f);
		break;
	default:
		GS->ApplyRules(R.ModeDisplayName, R.bScoringEnabled, R.TargetScore, 0.f);
		break;
	}
}

void AFELBasketballGameMode::LockPlayerInputIfMatchEnded()
{
	if (bLockedInputOnMatchEnd || !GetWorld())
	{
		return;
	}

	const AFELBasketballGameState* GS = GetGameState<AFELBasketballGameState>();
	if (!GS || !GS->HasMatchEnded())
	{
		return;
	}

	bLockedInputOnMatchEnd = true;
	if (APlayerController* PC = GetWorld()->GetFirstPlayerController())
	{
		PC->SetIgnoreMoveInput(true);
		PC->SetIgnoreLookInput(true);
	}
}

void AFELBasketballGameMode::SyncNeuroFieldsFromSnapshot(const FFELReadinessSnapshot& Snap)
{
	NeuroVerticalEstimateInches = Snap.VerticalEstimateInches;
	NeuroHangTimeScale = Snap.HangTimeScale;
	NeuroKineticLeakageMultiplier = Snap.KineticLeakageMultiplier;
	NeuroPRQScore = Snap.PRQScore;
	NeuroSFMA_SpiralRotationPass = Snap.bSFMASpiralRotationScreenPass;
	if (GetWorld() && GetWorld()->HasBegunPlay())
	{
		BroadcastBiometricToWorld();
	}
}

FString AFELBasketballGameMode::GetArenaGameModeId() const
{
	return FELArenaModeToIdString(CurrentMode);
}

void AFELBasketballGameMode::TriggerExerciseDemo()
{
	if (DemoManager)
	{
		DemoManager->TriggerExerciseDemo();
	}
}

void AFELBasketballGameMode::EndExerciseDemoIfActive()
{
	if (DemoManager)
	{
		DemoManager->EndExerciseDemoIfActive();
	}
}

void AFELBasketballGameMode::SpawnMatchBallAtOffset(const FVector& OffsetFromPlayerStart)
{
	if (!BallClass || !GetWorld())
	{
		return;
	}

	AActor* ChosenStart = nullptr;
	TArray<AActor*> Starts;
	UGameplayStatics::GetAllActorsOfClass(GetWorld(), APlayerStart::StaticClass(), Starts);
	if (Starts.Num() > 0)
	{
		ChosenStart = Starts[0];
	}

	FVector Loc = ChosenStart ? ChosenStart->GetActorLocation() : FVector::ZeroVector;
	Loc += OffsetFromPlayerStart;
	const FRotator Rot = ChosenStart ? ChosenStart->GetActorRotation() : FRotator::ZeroRotator;

	FActorSpawnParameters Params;
	Params.SpawnCollisionHandlingOverride = ESpawnActorCollisionHandlingMethod::AdjustIfPossibleButAlwaysSpawn;
	GetWorld()->SpawnActor<AFELBasketballActor>(BallClass, Loc, Rot, Params);
}
```

File: `UnrealStarter/BasketballGame/FELHoopScoreVolume.h`

```cpp
// Copyright (c) Final Evolution Lab.

#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "FELHoopScoreVolume.generated.h"

class UBoxComponent;

/**
 * Place under/near a hoop; when the FEL basketball overlaps, adds score (with cooldown).
 */
UCLASS()
class FINALEVOLUTIONLAB_API AFELHoopScoreVolume : public AActor
{
	GENERATED_BODY()

public:
	AFELHoopScoreVolume();

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "FEL")
	UBoxComponent* TriggerBox;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "FEL")
	int32 PointsPerBucket = 1;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "FEL")
	float ScoreCooldownSeconds = 1.5f;

protected:
	virtual void BeginPlay() override;

	UFUNCTION()
	void OnTriggerOverlap(UPrimitiveComponent* OverlappedComponent, AActor* OtherActor, UPrimitiveComponent* OtherComp,
		int32 OtherBodyIndex, bool bFromSweep, const FHitResult& SweepResult);

	float LastScoreWorldTime = -1000.f;
};
```

File: `UnrealStarter/BasketballGame/FELHoopScoreVolume.cpp`

```cpp
// Copyright (c) Final Evolution Lab.

#include "FELHoopScoreVolume.h"
#include "FELBasketballActor.h"
#include "FELBasketballGameState.h"
#include "FinalEvolutionLab.h"
#include "Components/BoxComponent.h"
#include "Engine/World.h"
#include "GameFramework/GameStateBase.h"

AFELHoopScoreVolume::AFELHoopScoreVolume()
{
	PrimaryActorTick.bCanEverTick = false;

	TriggerBox = CreateDefaultSubobject<UBoxComponent>(TEXT("TriggerBox"));
	SetRootComponent(TriggerBox);
	TriggerBox->InitBoxExtent(FVector(100.f, 100.f, 140.f));
	TriggerBox->SetCollisionProfileName(TEXT("OverlapAllDynamic"));
	TriggerBox->SetGenerateOverlapEvents(true);
}

void AFELHoopScoreVolume::BeginPlay()
{
	Super::BeginPlay();
	TriggerBox->OnComponentBeginOverlap.AddDynamic(this, &AFELHoopScoreVolume::OnTriggerOverlap);
}

void AFELHoopScoreVolume::OnTriggerOverlap(UPrimitiveComponent* OverlappedComponent, AActor* OtherActor,
	UPrimitiveComponent* OtherComp, int32 OtherBodyIndex, bool bFromSweep, const FHitResult& SweepResult)
{
	if (!OtherActor || !GetWorld())
	{
		return;
	}

	if (!Cast<AFELBasketballActor>(OtherActor))
	{
		return;
	}

	const float Now = GetWorld()->GetTimeSeconds();
	if (Now - LastScoreWorldTime < ScoreCooldownSeconds)
	{
		return;
	}
	LastScoreWorldTime = Now;

	if (AFELBasketballGameState* GS = GetWorld()->GetGameState<AFELBasketballGameState>())
	{
		if (GS->IsScoringEnabled() && !GS->HasMatchEnded())
		{
			GS->AddScore(PointsPerBucket);
		}
	}
}
```

File: `UnrealStarter/BasketballGame/FELArenaBridge.h`

```cpp
// Copyright (c) Final Evolution Lab.
// Parity with FinalEvolutionLab/Utilities/PRQScoring.swift (modeWeight, attributeLabel, attributeValue).

#pragma once

#include "CoreMinimal.h"

struct FELArenaBridge
{
	/** Shards curve for Unreal Arena lab (tunable); scales with PRQ and Swift modeWeight. */
	static int32 ComputeShardsEarned(int32 ScoreBuckets, double PRQ, const FString& GameModeId, bool bEconomyEnabled);

	/** Small PRQ-linked bonus double for GameSessionResult. */
	static double ComputePRQBonus(int32 ScoreBuckets, double PRQ, bool bEconomyEnabled);

	static FString AttributeLabelForGameModeId(const FString& Id);
	static double AttributeDisplay01To100(double PRQ, const FString& GameModeId);
	static double ModeWeightForGameModeId(const FString& Id);
};
```

File: `UnrealStarter/BasketballGame/FELArenaBridge.cpp`

```cpp
// Copyright (c) Final Evolution Lab.

#include "FELArenaBridge.h"

static double ModeScaleForBasketball(const FString& Id)
{
	if (Id == TEXT("basketball_h2h") || Id == TEXT("basketball_3v3"))
	{
		return 0.85;
	}
	if (Id == TEXT("basketball_dunk"))
	{
		return 0.90;
	}
	return 0.85;
}

FString FELArenaBridge::AttributeLabelForGameModeId(const FString& Id)
{
	if (Id == TEXT("basketball_h2h") || Id == TEXT("basketball_3v3"))
	{
		return TEXT("Court IQ");
	}
	if (Id == TEXT("basketball_dunk"))
	{
		return TEXT("Hang Time");
	}
	return TEXT("Arena");
}

double FELArenaBridge::AttributeDisplay01To100(double PRQ, const FString& GameModeId)
{
	const double Safe = FMath::IsFinite(PRQ) ? PRQ : 75.0;
	const double N = FMath::Clamp(Safe / 100.0, 0.0, 1.0);
	const double ModeScale = ModeScaleForBasketball(GameModeId);
	return FMath::RoundToDouble(ModeScale * N * 100.0) / 100.0;
}

double FELArenaBridge::ModeWeightForGameModeId(const FString& Id)
{
	if (Id == TEXT("basketball_h2h"))
	{
		return 1.2;
	}
	if (Id == TEXT("basketball_dunk"))
	{
		return 1.0;
	}
	if (Id == TEXT("basketball_3v3"))
	{
		return 1.3;
	}
	return 1.0;
}

int32 FELArenaBridge::ComputeShardsEarned(int32 ScoreBuckets, double PRQ, const FString& GameModeId, bool bEconomyEnabled)
{
	if (!bEconomyEnabled)
	{
		return 0;
	}
	const double SafePRQ = FMath::IsFinite(PRQ) ? FMath::Clamp(PRQ, 0.0, 100.0) : 75.0;
	const double W = ModeWeightForGameModeId(GameModeId);
	const double Raw = 5.0 + static_cast<double>(FMath::Max(0, ScoreBuckets)) * 3.0 * W * (SafePRQ / 100.0);
	return FMath::Max(1, FMath::RoundToInt(Raw));
}

double FELArenaBridge::ComputePRQBonus(int32 ScoreBuckets, double PRQ, bool bEconomyEnabled)
{
	if (!bEconomyEnabled)
	{
		return 0.0;
	}
	if (ScoreBuckets <= 0)
	{
		return 0.0;
	}
	const double SafePRQ = FMath::IsFinite(PRQ) ? FMath::Clamp(PRQ, 0.0, 100.0) : 75.0;
	const double Raw = 0.05 * static_cast<double>(ScoreBuckets) * (SafePRQ / 100.0);
	return FMath::Clamp(Raw, 0.1, 5.0);
}
```

### Unreal — UFELInputManager (Push 1,2 haptics) + Biometric overlays header

File: `UnrealStarter/BasketballGame/UFELInputManager.h`

```cpp
// Copyright (c) Final Evolution Lab.
// Cross-platform gamepad bridge: desktop uses `UPlayerInput` joystick count; browser / Pixel Streaming uses
// W3C Gamepad API (Chromium maps DualSense via standard layout) and optional WebHID for vendor-specific bands.
// Inject path: call `InjectBrowserGamepadSample` from a JS→C++ bridge when running WASM or Pixel Streaming mirrors.

#pragma once

#include "CoreMinimal.h"
#include "Kismet/BlueprintFunctionLibrary.h"
#include "UFELInputManager.generated.h"

/**
 * Sovereign Launch input facade — Gamepad API parity across PC, Mac, and web-hosted mirrors.
 * WebHID (DualSense / custom PJF-Band firmware) is surfaced in-browser; forward HID reports through your
 * Pixel Streaming or WASM JavaScript layer into `InjectBrowserGamepadSample`.
 */
UCLASS()
class FINALEVOLUTIONLAB_API UFELInputManager : public UBlueprintFunctionLibrary
{
	GENERATED_BODY()

public:
	/**
	 * Vertical Velocity Academy — Push 1,2 haptics: Phase 0 = penultimate "Push" (grounded, both large motors);
	 * phases 1–2 = takeoff "1, 2" snaps (small motors). PS5: stacked FFP pulses + L2/R2 lanes (see UFELInputManager.cpp).
	 */
	UFUNCTION(BlueprintCallable, Category = "FEL|Input|Haptics", meta = (WorldContext = "WorldContextObject"))
	static void PlayPushTwelveClinicalHaptic(const UObject* WorldContextObject, int32 BeatPhaseMod3);

public:
	/** True when at least one physical gamepad is connected (desktop / console targets). */
	UFUNCTION(BlueprintCallable, Category = "FEL|Input", meta = (WorldContext = "WorldContextObject"))
	static bool IsAnyGamepadConnected(const UObject* WorldContextObject);

	/**
	 * Browser mirror path: maps W3C Gamepad axes/buttons (or WebHID-decoded DualSense) into FEL handshake buffers.
	 * Thresholds match `AFELBasketballPlayerController` stick gates for signature gestures.
	 */
	UFUNCTION(BlueprintCallable, Category = "FEL|Input")
	static void InjectBrowserGamepadSample(
		float LeftStickX,
		float LeftStickY,
		float RightStickX,
		float RightStickY,
		bool FaceBottom,
		bool FaceRight,
		bool LeftShoulder,
		bool RightShoulder);
};
```

File: `UnrealStarter/BasketballGame/UFELInputManager.cpp`

```cpp
// Copyright (c) Final Evolution Lab.

#include "UFELInputManager.h"
#include "Engine/Engine.h"
#include "Engine/EngineTypes.h"
#include "Engine/World.h"
#include "GameFramework/PlayerController.h"
#include "GameFramework/PlayerInput.h"
#include "HAL/Platform.h"
#include "Math/UnrealMathUtility.h"
#if PLATFORM_PS5
#include "GameFramework/ForceFeedbackParameters.h"
#endif

void UFELInputManager::PlayPushTwelveClinicalHaptic(const UObject* WorldContextObject, int32 BeatPhaseMod3)
{
	UWorld* World = GEngine ? GEngine->GetWorldFromContextObject(WorldContextObject, EGetWorldErrorMode::ReturnNull) : nullptr;
	if (!World)
	{
		return;
	}
	APlayerController* PC = World->GetFirstPlayerController();
	if (!PC)
	{
		return;
	}
	const int32 Phase = ((BeatPhaseMod3 % 3) + 3) % 3;
	// Bonds Standard calibration: Phase 0 = penultimate "Push" — heavy / grounded (both large motors, longer duration).
	// Phases 1–2 = takeoff "1, 2" — short, sharp small-motor snaps (explosive cue).
#if PLATFORM_PS5
	// DualSense: use FForceFeedbackParameters + stacked pulses — L2/R2 lanes match `FELConsoleHapticBridge` (adaptive trigger feel).
	FForceFeedbackParameters FFP;
	FFP.bLooping = false;
	FFP.Tag = NAME_None;
	if (Phase == 0)
	{
		// Grounded push: symmetric large-motor rumble, then brief L2 resistance lane (same bool pattern as Gather tension).
		PC->PlayDynamicForceFeedback(1.0f, 0.19f, true, false, true, false, FFP);
		PC->PlayDynamicForceFeedback(0.45f, 0.11f, false, false, true, false, FFP);
	}
	else
	{
		const float SnapIntensity = (Phase == 1) ? 0.88f : 0.95f;
		PC->PlayDynamicForceFeedback(SnapIntensity, 0.028f, false, true, false, true, FFP);
		PC->PlayDynamicForceFeedback(1.f, 0.05f, false, false, false, true, FFP);
	}
#else
	// Desktop / Mac / Xbox / mobile: standard rumble routing via gameplay channel tag (matches `AFELBasketballPlayerController::PlayBondsBounceHaptics`).
#if PLATFORM_IOS || PLATFORM_ANDROID
	// Alpha 1: small-motor snaps read subtle on phone speakers / Taptic-adjacent rumble — boost takeoff phases slightly.
	static constexpr float MobileSnapBoost = 1.14f;
#else
	static constexpr float MobileSnapBoost = 1.f;
#endif
	if (Phase == 0)
	{
		PC->PlayDynamicForceFeedback(1.0f, 0.19f, true, false, true, false, ECollisionChannel::ECC_GameTraceChannel1, false);
	}
	else
	{
		const float BaseSnap = (Phase == 1) ? 0.88f : 0.95f;
		const float SnapIntensity = FMath::Clamp(BaseSnap * MobileSnapBoost, 0.f, 1.f);
		const float SnapDur = (MobileSnapBoost > 1.f) ? 0.034f : 0.028f;
		PC->PlayDynamicForceFeedback(SnapIntensity, SnapDur, false, true, false, true, ECollisionChannel::ECC_GameTraceChannel1, false);
	}
#endif
}

namespace
{
struct FFELBrowserPadState
{
	float LeftX = 0.f;
	float LeftY = 0.f;
	float RightX = 0.f;
	float RightY = 0.f;
	bool FaceBottom = false;
	bool FaceRight = false;
	bool LeftShoulder = false;
	bool RightShoulder = false;
};

FFELBrowserPadState GBrowserPadState;
}

bool UFELInputManager::IsAnyGamepadConnected(const UObject* WorldContextObject)
{
	UWorld* World = GEngine ? GEngine->GetWorldFromContextObject(WorldContextObject, EGetWorldErrorMode::ReturnNull) : nullptr;
	if (!World)
	{
		return false;
	}
	for (FConstPlayerControllerIterator It = World->GetPlayerControllerIterator(); It; ++It)
	{
		APlayerController* PC = It->Get();
		if (PC && PC->PlayerInput && PC->PlayerInput->GetJoystickCount() > 0)
		{
			return true;
		}
	}
	return false;
}

void UFELInputManager::InjectBrowserGamepadSample(
	float LeftStickX,
	float LeftStickY,
	float RightStickX,
	float RightStickY,
	bool FaceBottom,
	bool FaceRight,
	bool LeftShoulder,
	bool RightShoulder)
{
	// Consumed by Pixel Streaming / WASM UI layers that bridge navigator.getGamepads() or navigator.hid (WebHID).
	GBrowserPadState.LeftX = FMath::Clamp(LeftStickX, -1.f, 1.f);
	GBrowserPadState.LeftY = FMath::Clamp(LeftStickY, -1.f, 1.f);
	GBrowserPadState.RightX = FMath::Clamp(RightStickX, -1.f, 1.f);
	GBrowserPadState.RightY = FMath::Clamp(RightStickY, -1.f, 1.f);
	GBrowserPadState.FaceBottom = FaceBottom;
	GBrowserPadState.FaceRight = FaceRight;
	GBrowserPadState.LeftShoulder = LeftShoulder;
	GBrowserPadState.RightShoulder = RightShoulder;
}
```

File: `UnrealStarter/BasketballGame/UFELBiometricOverlays.h`

```cpp
// Copyright (c) Final Evolution Lab.
// Clinical Mirror — Spiral Line + Front Functional Line translucent HUD; Push 1,2 pulse; SFMA rotation FAIL → red congestion.

#pragma once

#include "CoreMinimal.h"
#include "Components/ActorComponent.h"
#include "FELBiometricTypes.h"
#include "UFELBiometricOverlays.generated.h"

class UStaticMeshComponent;
class UMaterialInstanceDynamic;

/**
 * High-fidelity fascial plane overlays for the Unreal Lab: assign two translucent meshes (Spiral Line, Front Functional Line)
 * in-editor and drive M_Clinical_Transparency / CONFIG_Clinical scalars. Pair with UFELRhythmicCueingWidget beats.
 */
UCLASS(ClassGroup = (FEL), meta = (BlueprintSpawnableComponent))
class FINALEVOLUTIONLAB_API UFELBiometricOverlays : public UActorComponent
{
	GENERATED_BODY()

public:
	UFELBiometricOverlays();

	/** Finds all UFELBiometricOverlays in the world and applies Push 1,2 rhythm pulse (clinical HUD sync). */
	UFUNCTION(BlueprintCallable, Category = "FEL|Clinical", meta = (WorldContext = "WorldContextObject"))
	static void ApplyGlobalRhythmPulse(UObject* WorldContextObject, int32 BeatPhaseMod3);

	/** Wire Spiral / Front meshes from the owning actor (or leave null for material-only / Blueprint mesh spawn). */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Clinical|Meshes")
	TObjectPtr<UStaticMeshComponent> SpiralLineMesh;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Clinical|Meshes")
	TObjectPtr<UStaticMeshComponent> FrontFunctionalLineMesh;

	/** Optional MID slots — created from mesh materials in BeginPlay when meshes are set. */
	UPROPERTY(Transient, BlueprintReadOnly, Category = "FEL|Clinical")
	TObjectPtr<UMaterialInstanceDynamic> SpiralMID;

	UPROPERTY(Transient, BlueprintReadOnly, Category = "FEL|Clinical")
	TObjectPtr<UMaterialInstanceDynamic> FrontMID;

	/** Master toggle for spiral + front line visibility and ticking. */
	UFUNCTION(BlueprintCallable, Category = "FEL|Clinical")
	void SetClinicalOverlaysActive(bool bActive);

	/** Called from GameMode biometric broadcast — SFMA rotation FAIL drives red congestion on fascial planes. */
	UFUNCTION(BlueprintCallable, Category = "FEL|Clinical")
	void ApplyBiometricContext(const FFELBiometricContext& Context);

	/** Beat phase 0 = penultimate Push, 1 = "1", 2 = "2" — ties to UFELRhythmicCueingWidget / Push 1,2 cadence. */
	UFUNCTION(BlueprintCallable, Category = "FEL|Clinical")
	void OnPushRhythmBeat(int32 BeatPhaseMod3);

protected:
	virtual void BeginPlay() override;
	virtual void TickComponent(float DeltaTime, ELevelTick TickType, FActorComponentTickFunction* ThisTickFunction) override;

private:
	void EnsureMIDs();
	void PushPulseForPhase(int32 Phase);
	void ApplyCongestionVisual(bool bRedRoadblock);

	UPROPERTY(EditAnywhere, Category = "FEL|Clinical")
	bool bOverlaysActive = true;

	UPROPERTY(EditAnywhere, Category = "FEL|Clinical")
	bool bSFMA_RotationRoadblock = false;

	UPROPERTY(EditAnywhere, Category = "FEL|Clinical")
	float BasePulseSpeed = 1.15f;

	/** Scales spiral emissive pulse so the overlay stays readable under the rim at high approach speed (Alpha 1 polish). 0.75–0.9 typical. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Clinical", meta = (ClampMin = "0.35", ClampMax = "1.0"))
	float SpiralVisualIntensityScale = 0.82f;

	float PulseAccum = 0.f;
	float FrontFunctionalTension = 0.f;
	float SpiralPulseBoost = 0.f;
	/** Last values pushed to MIDs — skip redundant scalar sets during System Scan / recording to reduce render-thread work. */
	float LastWrittenSpiralPulse = -1000.f;
	float LastWrittenFrontTension = -1000.f;
	float LastWrittenFrontPulsePhase = -1000.f;
};
```

File: `UnrealStarter/BasketballGame/FELBasketballActor.cpp (excerpt: ApplyReadiness only)`

```cpp
void AFELBasketballActor::ApplyReadiness(const FFELReadinessSnapshot& Snap)
{
	if (!CollisionSphere)
	{
		return;
	}
```

### Unreal Editor Python

File: `UnrealStarter/EditorPython/README.md`

```markdown
# Unreal Editor Python — FEL level setup (UE 5.7 / MyProjec)

These scripts work with **Unreal Engine 5.7** and the **MyProjec** game module (same layout as **`../BasketballGame/`** templates). Older **5.2+** builds are generally compatible; enable the plugin the same way.

## Enable Python

1. **Edit → Plugins** → enable **Python Editor Script Plugin** → restart the editor.
2. **Edit → Project Settings → Plugins → Python** → enable **Developer Mode** if you want the console.

## Project layout

Typical paths on disk:

- **`.uproject`:** `~/Documents/Unreal Projects/MyProjec/MyProjec.uproject`
- **Python folder:** `MyProjec/Content/Python/` (create if missing)

`fel_quick_playtest_level.py` expects **compiled MyProjec C++** (e.g. `/Script/MyProjec.FELHoopScoreVolume`). See **`../BasketballGame/PACKAGE_AND_TEST.md`** § fast playtest map.

## One-time: copy assets into the project

Follow **`../FEL_UE52_LevelSetup.md`**: copy `LumaScan/` and `MeshyAssets/` into your project (or import directly from this repo path), then import so asset names match the constants in `fel_setup_level.py` (or edit the constants).

## Run the setup script

1. Copy `fel_setup_level.py` into your UE project, e.g. **`Content/Python/fel_setup_level.py`** (create the folder).
2. In Unreal: **Window → Developer Tools → Output Log** → dropdown **Python** (or use the Python console if exposed).
3. Execute:

```python
import sys
sys.path.append("/Users/YOU/Documents/Unreal Projects/MyProjec/Content/Python")
import fel_setup_level
fel_setup_level.run()
```

Or from **Tools → Execute Python Script** (if your build exposes it), pick `fel_setup_level.py`.

4. Save the level (**File → Save Current**).

The script spawns actors; it does not import FBX/OBJ/GLB (use Content Browser import first).
```

File: `UnrealStarter/EditorPython/fel_setup_level.py`

```python
import unreal

# Modified to match the default names Unreal generates when you drag and drop the files!
ASSET_PATHS = {
    "luma_environment": "/Game/FEL/Environment/Luma/mesh.mesh",
    "basketball_prop": "/Game/FEL/Props/Meshy_AI_HoopBus_Basketball_0319064117_texture.Meshy_AI_HoopBus_Basketball_0319064117_texture",
    "elijah_mesh": "/Game/FEL/Characters/ElijahBonds/Meshy_AI_Elijah_Bonds_biped_Animation_Running_withSkin.Meshy_AI_Elijah_Bonds_biped_Animation_Running_withSkin",
}

HOOP_OFFSET_CM = 165.0
BALL_Z_ABOVE_FLOOR_CM = 50.0
CHARACTER_Z_ABOVE_FLOOR_CM = 92.0

def _load_static(path: str):
    obj = unreal.load_asset(path)
    if obj is None:
        unreal.log_warning("FEL: Missing asset (did you drag and drop it?): " + path)
    return obj

def _load_skeletal(path: str):
    obj = unreal.load_asset(path)
    if obj is None:
        unreal.log_warning("FEL: Missing asset (did you drag and drop it?): " + path)
    return obj

def _spawn_static_mesh(name: str, mesh, location: unreal.Vector, rotation: unreal.Rotator):
    if mesh is None:
        return None
    actor = unreal.EditorLevelLibrary.spawn_actor_from_class(unreal.StaticMeshActor, location, rotation)
    if actor:
        actor.set_actor_label(name)
        comp = actor.static_mesh_component
        comp.set_static_mesh(mesh)
        comp.set_collision_enabled(unreal.CollisionEnabledType.QUERY_AND_PHYSICS)
    return actor

def _spawn_skeletal(name: str, sk_mesh, location: unreal.Vector, rotation: unreal.Rotator):
    if sk_mesh is None:
        return None
    actor = unreal.EditorLevelLibrary.spawn_actor_from_class(unreal.SkeletalMeshActor, location, rotation)
    if actor:
        actor.set_actor_label(name)
        actor.skeletal_mesh_component.set_skeletal_mesh(sk_mesh)
    return actor

def run():
    unreal.log("FEL: Setting up Luma environment + hoop props + Elijah Bonds test character...")

    sm_luma = _load_static(ASSET_PATHS["luma_environment"])
    sm_ball = _load_static(ASSET_PATHS["basketball_prop"])
    sk_elijah = _load_skeletal(ASSET_PATHS["elijah_mesh"])

    origin = unreal.Vector(0.0, 0.0, 0.0)
    rot_identity = unreal.Rotator(0.0, 0.0, 0.0)

    env = _spawn_static_mesh("ENV_LumaCourt", sm_luma, origin, rot_identity)
    loc_a = unreal.Vector(-HOOP_OFFSET_CM, 0.0, BALL_Z_ABOVE_FLOOR_CM)
    loc_b = unreal.Vector(HOOP_OFFSET_CM, 0.0, BALL_Z_ABOVE_FLOOR_CM)
    _spawn_static_mesh("PROP_Basketball_HoopEnd_A", sm_ball, loc_a, rot_identity)
    _spawn_static_mesh("PROP_Basketball_HoopEnd_B", sm_ball, loc_b, rot_identity)

    char_loc = unreal.Vector(0.0, 0.0, CHARACTER_Z_ABOVE_FLOOR_CM)
    _spawn_skeletal("CHAR_ElijahBonds_Test", sk_elijah, char_loc, rot_identity)

    unreal.log("FEL: Done! Assets placed.")

if __name__ == "__main__":
    run()
```

File: `UnrealStarter/EditorPython/fel_quick_playtest_level.py`

```python
# Copyright (c) Final Evolution Lab.
#
# Creates asset + level: /Game/FEL/Maps/L_FEL_Playtest
#   - Floor: scaled /Engine/BasicShapes/Cube
#   - PlayerStart
#   - Two AFELHoopScoreVolume actors (scoring works out of the box)
#
# Prerequisites:
#   - Python Editor Script Plugin (Edit → Plugins → Scripting), Editor restart.
#   - MyProjec C++ compiled so /Script/MyProjec.FELHoopScoreVolume exists.
#
# Run (macOS example):
#   py "/Users/you/.../final-evolution-lab/UnrealStarter/EditorPython/fel_quick_playtest_level.py"
# Or: Tools → Execute Python Script → this file.
#
# Next: DefaultEngine.ini → GameDefaultMap + EditorStartupMap =
#   /Game/FEL/Maps/L_FEL_Playtest.L_FEL_Playtest
#   See UnrealStarter/BasketballGame/PACKAGE_AND_TEST.md §10.

import unreal

MAP_PACKAGE = "/Game/FEL/Maps"
MAP_NAME = "L_FEL_Playtest"
MAP_PATH = f"{MAP_PACKAGE}/{MAP_NAME}"


def _ensure_dir(path: str) -> None:
    if not unreal.EditorAssetLibrary.does_directory_exist(path):
        unreal.EditorAssetLibrary.make_directory(path)


def _ensure_world_asset() -> str:
    asset_full = f"{MAP_PATH}.{MAP_NAME}"
    if unreal.EditorAssetLibrary.does_asset_exist(asset_full):
        unreal.log(f"FEL: Map asset already exists: {asset_full}")
        return asset_full

    _ensure_dir(MAP_PACKAGE)
    factory = unreal.WorldFactory()
    asset_tools = unreal.AssetToolsHelpers.get_asset_tools()
    asset_tools.create_asset(MAP_NAME, MAP_PACKAGE, unreal.World, factory)
    unreal.log(f"FEL: Created world asset {asset_full}")
    return asset_full


def _load_map(asset_full: str) -> bool:
    # asset_full like /Game/FEL/Maps/L_FEL_Playtest.L_FEL_Playtest
    pkg = asset_full.rsplit(".", 1)[0]
    ok = unreal.EditorLoadingAndSavingUtils.load_map(pkg)
    if not ok:
        unreal.log_error(f"FEL: load_map failed for {pkg}")
    return ok


def _spawn_floor():
    mesh = unreal.EditorAssetLibrary.load_asset("/Engine/BasicShapes/Cube.Cube")
    if not mesh:
        unreal.log_error("FEL: Could not load /Engine/BasicShapes/Cube.Cube")
        return
    loc = unreal.Vector(0.0, 0.0, 0.0)
    rot = unreal.Rotator(0.0, 0.0, 0.0)
    actor = unreal.EditorLevelLibrary.spawn_actor_from_class(unreal.StaticMeshActor, loc, rot)
    if actor:
        actor.set_actor_label("FEL_PlaytestFloor")
        actor.static_mesh_component.set_static_mesh(mesh)
        actor.set_actor_scale3d(unreal.Vector(40.0, 40.0, 0.15))
        actor.set_actor_location(unreal.Vector(0.0, 0.0, -15.0), False, False)
        unreal.log("FEL: Spawned scaled cube as floor.")


def _spawn_player_start():
    loc = unreal.Vector(0.0, 0.0, 120.0)
    rot = unreal.Rotator(0.0, 0.0, 0.0)
    actor = unreal.EditorLevelLibrary.spawn_actor_from_class(unreal.PlayerStart, loc, rot)
    if actor:
        actor.set_actor_label("PlayerStart")
        unreal.log("FEL: Spawned PlayerStart.")


def _spawn_hoop_volumes():
    hoop_cls = unreal.load_class(None, "/Script/MyProjec.FELHoopScoreVolume")
    if not hoop_cls:
        unreal.log_error("FEL: Could not load class /Script/MyProjec.FELHoopScoreVolume — is C++ compiled?")
        return

    # Box volumes ~2.5 m above floor, spaced along X (adjust to your court later).
    placements = [
        ("FEL_HoopVolume_A", unreal.Vector(-350.0, 0.0, 250.0)),
        ("FEL_HoopVolume_B", unreal.Vector(350.0, 0.0, 250.0)),
    ]
    for label, loc in placements:
        actor = unreal.EditorLevelLibrary.spawn_actor_from_class(hoop_cls, loc, unreal.Rotator(0.0, 0.0, 0.0))
        if actor:
            actor.set_actor_label(label)
            unreal.log(f"FEL: Spawned {label} at {loc.x},{loc.y},{loc.z}")


def run():
    unreal.log("FEL: Building quick playtest level (floor + PlayerStart + hoop volumes)…")
    asset_full = _ensure_world_asset()
    if not _load_map(asset_full):
        return

    _spawn_floor()
    _spawn_player_start()
    _spawn_hoop_volumes()

    asset_long = f"{MAP_PATH}.{MAP_NAME}"
    unreal.EditorAssetLibrary.save_asset(asset_long)
    unreal.log(
        "FEL: Saved. In DefaultEngine.ini set GameDefaultMap + EditorStartupMap to "
        f"{asset_long} then package per UnrealStarter/BasketballGame/PACKAGE_AND_TEST.md"
    )


if __name__ == "__main__":
    run()
```


---

*End of **Gold Master Sovereign Bundle**. Regenerate with:* `python3 scripts/generate_ai_studio_bundle.py`
