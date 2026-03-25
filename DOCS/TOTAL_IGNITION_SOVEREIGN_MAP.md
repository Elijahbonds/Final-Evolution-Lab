# Total Ignition — Sovereign Lab map (repo truth)

This ties your **narrative** (PWA + Stripe → Supabase, 100% data ownership) to **files that already exist**.  
**Do not** apply ad-hoc migrations named `20260325_sovereign_economy.sql` if they duplicate tables — the **Sovereign Bank** is already defined.

---

## 1. Sovereign economy (SQL + RPC)

| Your concept | Implemented as |
|--------------|------------------|
| `user_balances` | `supabase/migrations/20260324120000_sovereign_bank.sql` — `user_id` **PK**, `shard_balance`, **`cortex_credits`**, `unlocked_gear_json`, RLS SELECT own |
| Audit trail | `sovereign_market_transactions` with `shard_delta`, `cortex_delta`, `product_sku`, `metadata` |
| Atomic credit | **`fel_apply_stripe_shard_credit`** (not `credit_shards`) — idempotent by `stripe_session_id`, **SECURITY DEFINER**, `service_role` only |

**Stripe → wallet:** Edge Function **`stripe-webhook-handler`** (`supabase/functions/stripe-webhook-handler/index.ts`) verifies **`Stripe-Signature`**, resolves user (`metadata`, `client_reference_id`, athlete link, email RPC), calls **`fel_apply_stripe_shard_credit`**.

There is **no** separate `supabase/functions/stripe-webhook/` — use **`stripe-webhook-handler`** only.

---

## 2. Wix → same ledger

**`wix-order-completed`** → same RPC `fel_apply_stripe_shard_credit` with synthetic session id `wix_<orderId>`.

---

## 3. `/play/` PWA (Dark Clinical + 16.6 ms story)

- **`web/play/index.html`** — gateway, COOP/COEP via **`netlify.toml`** + **`web/_headers`**
- **`web/play/manifest.webmanifest`** — installability
- Deploy: **`netlify.toml`** publish `web/` — see **`DOCS/FULL_DEPLOYMENT_REMAINING.md`**

---

## 4. Vertical Velocity Academy manifest

Canonical curriculum data: **`Config/ACADEMY_CURRICULUM_V1.json`**, Swift **`VerticalVelocityAcademy`**, web stub **`web/config/vva-game-modes.ts`**.  
Your “01–10 Total Ignition” table is a **product layer** — merge into ACADEMY JSON when copy locks; do not fork a second schema without updating the app.

---

## 5. Cloud Cortex (Gemini)

- Swift **`PRQManager.fetchAICoachInsight`**, **`GeminiService`**
- SFMA rotation fail → prescribed in **`buildCloudCortexPrompt`** — see **`Source/PRQManager.swift`**

---

## 6. Peak leaderboard (Supabase table)

Migration **`20260327120000_sovereign_peak_leaderboard.sql`** creates **`sovereign_peak_leaderboard`** (`athlete_id` text PK, `display_name`, `all_time_peak_z`, **`user_id`** for RLS).  
**Do not** recreate **`user_balances`** — it already exists in **`20260324120000_sovereign_bank.sql`**.

---

## 7. Deploy from M4 Pro (Edge Functions)

```bash
cd /path/to/rork-final-evolution-lab
./scripts/deploy_supabase_edge.sh
```

Or manually:

```bash
supabase functions deploy stripe-webhook-handler --no-verify-jwt
supabase functions deploy wix-order-completed --no-verify-jwt
```

Secrets: Supabase Dashboard → Edge Functions → **Stripe** keys, **`STRIPE_WEBHOOK_SIGNING_SECRET`**, **`SUPABASE_SERVICE_ROLE_KEY`**, **`SUPABASE_URL`**.

---

## 8. Example Cloud Cortex prescription (SFMA rotation screen fail)

One-line Neuro-Mechanic output (matches **`PRQManager.buildCloudCortexPrompt`** rules — under 200 characters):

> Neuro-Mechanic Prescription — Prescribe Vertical Velocity Academy Module 6 (NMS: Clearing the Path) with Isometric Split Stance Wall Push before plyometric volume; Spiral Line rotation roadblock flagged.

*(Generated at runtime by Gemini when `sfmaMultiSegmentalRotationPassed == false`.)*

---

*Revenue and athlete data stay in **your** Supabase project + Stripe account; the App Store is bypassed for the **web/PWA** path as described.*
