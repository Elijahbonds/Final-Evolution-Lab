# Sovereign Economy — Production Deployment (Stripe ↔ Supabase)

This document wires **FinalEvolutionGroup.com** checkout to **`user_balances`** via the existing Edge Function `supabase/functions/stripe-webhook-handler/index.ts` and RPC `fel_apply_stripe_shard_credit`.

**Prerequisites:** Stripe account (live mode for production), Supabase project with migrations applied, [Stripe CLI](https://stripe.com/docs/stripe-cli) installed and logged in (`stripe login`).

---

## 1. Create Stripe Products & Prices (CLI)

Run in **test mode** first (`stripe login` defaults); switch to **live** with `stripe config --set live_mode true` or use Dashboard live keys only on a secure machine.

Replace placeholder IDs in later steps with the IDs Stripe prints.

```bash
# VVA Blueprint — $19.99 USD
stripe products create \
  --name "VVA Blueprint" \
  --description "Vertical Velocity Academy blueprint access + Cortex alignment" \
  --metadata product_sku=vva_blueprint

# Save prod_xxx from output, then:
stripe prices create \
  --product prod_REPLACE \
  --unit-amount 1999 \
  --currency usd \
  --metadata product_sku=vva_blueprint

# Cortex Shard Pack — $49.99 USD
stripe products create \
  --name "Cortex Shard Pack" \
  --description "Evolution Shards + Cloud Cortex credits bundle" \
  --metadata product_sku=cortex_shard_pack

stripe prices create \
  --product prod_REPLACE \
  --unit-amount 4999 \
  --currency usd \
  --metadata product_sku=cortex_shard_pack

# Sovereign Pro — $99.99 USD
stripe products create \
  --name "Sovereign Pro" \
  --description "Sovereign Pro tier — premium Sovereign economy" \
  --metadata product_sku=sovereign_pro

stripe prices create \
  --product prod_REPLACE \
  --unit-amount 9999 \
  --currency usd \
  --metadata product_sku=sovereign_pro
```

**Export JSON (optional, for your shop repo):**

```bash
stripe products list --limit 20 -e json > stripe_products_snapshot.json
```

---

## 2. Checkout Metadata — How Credits Reach `user_balances`

The webhook resolves the Supabase user in this order:

1. **`metadata.supabase_user_id`** or **`metadata.user_id`** on the Checkout Session (preferred).
2. Else **`metadata.athlete_id`**, looked up in **`athlete_profile_link`** (must exist — app calls `fel_upsert_athlete_profile_link` on sign-in).

Then it reads deltas:

| Metadata key | Purpose |
|--------------|---------|
| `shard_delta` | Integer shards to add (also accepts `shards`) |
| `cortex_delta` | Integer Cloud Cortex credits (also accepts `cortex_credits`) |
| `product_sku` | Stored on `sovereign_market_transactions` |

If **both** `shard_delta` and `cortex_delta` resolve to **0**, the RPC returns without updating (idempotent no-op for empty metadata).

### Recommended metadata per SKU (examples — tune for your economics)

Configure **Payment Links** or **Checkout Session creation** (server-side) so each purchase sends something like:

| Product | `product_sku` | Example `shard_delta` | Example `cortex_delta` |
|---------|----------------|------------------------|-------------------------|
| VVA Blueprint | `vva_blueprint` | `0` | `50` (or your blueprint unlock policy) |
| Cortex Shard Pack | `cortex_shard_pack` | `500` | `25` |
| Sovereign Pro | `sovereign_pro` | `1200` | `100` |

**Always** pass **`supabase_user_id`** (UUID string) when your web backend knows it after login; otherwise ensure the athlete has opened the app and linked **`athlete_id`** so the webhook can resolve the row.

### Payment Links + `client_reference_id` (static web shop)

The repo ships **`web/shop/`** and **`web/wallet/`**. After the user signs in with Supabase Auth on the Wallet page, the Shop page opens Stripe Payment Links with:

- **`client_reference_id=<supabase auth user uuid>`** — the Edge Function `stripe-webhook-handler` treats a UUID-shaped `session.client_reference_id` like `metadata.supabase_user_id` and credits **`user_balances`**.
- **`prefilled_email`** when the session includes an email (optional UX).

Copy **`web/fel-public-config.example.js`** to **`web/fel-public-config.js`** (gitignored) and set `FEL_STRIPE_PAYMENT_LINK_*` to your Dashboard Payment Link URLs. Deploy **`web/`** as the site root (see **`netlify.toml`** and **`scripts/deploy_web.sh`**).

---

## 3. Supabase Secrets (Production)

Set secrets for the **Edge Function** runtime (not in client apps). Use the [Supabase CLI](https://supabase.com/docs/guides/cli) linked to your project.

**Preferred names (production):**

| Secret | Purpose |
|--------|---------|
| `STRIPE_WEBHOOK_SIGNING_SECRET` | Stripe webhook signing (`whsec_...`) |
| `STRIPE_API_KEY` | Stripe API (`sk_live_...`) |
| `SUPABASE_SERVICE_ROLE_KEY` | Service role JWT |
| `SUPABASE_URL` | `https://YOUR_PROJECT.supabase.co` |

The Edge Function also accepts legacy names: `STRIPE_WEBHOOK_SECRET`, `STRIPE_SECRET_KEY`.

**One-shot script (from repo root, after exporting env vars):**

```bash
./scripts/supabase_set_production_secrets.sh
```

Or manual:

```bash
supabase secrets set \
  STRIPE_WEBHOOK_SIGNING_SECRET=whsec_... \
  STRIPE_API_KEY=sk_live_... \
  SUPABASE_SERVICE_ROLE_KEY=eyJ... \
  SUPABASE_URL=https://YOUR_PROJECT.supabase.co
```

- **Signing secret:** Stripe Dashboard → Developers → Webhooks → your endpoint.
- **`SUPABASE_SERVICE_ROLE_KEY`:** Project Settings → API → **service_role** (never ship in the iOS app).

Apply migration **`20260326120000_stripe_webhook_service_rpcs.sql`** (email resolution + service-role athlete link + optional `stripe_customer_id` on `athlete_profile_link`) before relying on email-based checkout resolution.

```bash
supabase secrets list
```

---

## 4. Deploy the Webhook Handler

From the repo root:

```bash
supabase functions deploy stripe-webhook-handler --no-verify-jwt
```

Register the function URL in Stripe:

- **URL:** `https://YOUR_PROJECT.supabase.co/functions/v1/stripe-webhook-handler`
- **Events:** `checkout.session.completed`

Test locally:

```bash
stripe listen --forward-to localhost:54321/functions/v1/stripe-webhook-handler
# or forward to deployed URL in Dashboard “Send test webhook”
```

**Web shop E2E (test card + `client_reference_id`):** run `./scripts/sovereign_stripe_e2e.sh` — it prints the full checklist and, if `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `TEST_USER_JWT` are set, dumps the current `user_balances` row for that user.

---

## 5. `athlete_id` ↔ `user_id` Verification Checklist

1. User signs in via **FELSupabaseWalletSync** → **`fel_upsert_athlete_profile_link`** runs → row in **`athlete_profile_link`**.
2. Stripe Checkout includes **`metadata.athlete_id`** equal to the app’s **`UserProfile.id`**, **or** **`metadata.supabase_user_id`** equal to **`auth.users.id`**.
3. Webhook logs: no `missing_user_resolution`; RPC runs; **`user_balances`** increases; **`sovereign_market_transactions`** has a row with **`stripe_session_id`**.
4. iOS app: **Realtime** on **`user_balances`** triggers **`PRQManager.syncWallet()`** → shard badge updates without manual refresh.

---

## 6. Operational Notes

- **Idempotency:** Duplicate `checkout.session.completed` for the same `stripe_session_id` does not double-credit (see migration guard on `sovereign_market_transactions`).
- **RLS:** Athletes only **SELECT** their own wallet row; credits happen only via **service_role** RPC from Edge.
- **Live vs test:** Use separate Stripe products/webhooks/secrets for test mode until you flip live keys and redeploy secrets.

---

**Production go-live (live Stripe keys):** run `./scripts/sovereign_bank_production_launch.sh` for the ordered checklist (migration → secrets → `stripe-webhook-handler` deploy → webhook URL → live smoke test).

---

*Sovereign Bank deployment — Final Evolution 1.0.0*
