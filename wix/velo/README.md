# Wix Velo — Sovereign Shard store → Supabase wallet

**GitHub-first bridge (recommended):** use the packaged site backend in **`final-evolution-wix-bridge/`** (README there: connect Wix ↔ GitHub, clone on Mac, `velo-relay.jsw` + `http-functions.js`). This folder (`wix/velo/`) stays the in-repo copy of **`http-functions.js`** aligned with that package.

The Stripe Edge Function `stripe-webhook-handler` only accepts **Stripe-signed** events. For **Wix Stores** orders, deploy **`wix-order-completed`** and call it from Velo with a shared secret.

## 1. Supabase

```bash
supabase secrets set WIX_WEBHOOK_SHARED_SECRET="your-long-random-string"
supabase functions deploy wix-order-completed --no-verify-jwt
```

URL: `https://YOUR_PROJECT.supabase.co/functions/v1/wix-order-completed`

## 2. Wix Secrets (Editor → Dev Mode → Secrets)

| Name | Value |
|------|--------|
| `FEL_SUPABASE_ORDER_URL` | `https://YOUR_PROJECT.supabase.co/functions/v1/wix-order-completed` |
| `FEL_WIX_WEBHOOK_SHARED_SECRET` | Same as `WIX_WEBHOOK_SHARED_SECRET` |

## 3. Product setup

1. **Stores → Products** — create **Sovereign Shard Pack** (price as you like).
2. **Members** — add profile fields or use **Checkout custom fields** (Wix plan permitting) for:
   - `supabase_user_id` (UUID from your app / wallet)
   - `athlete_id` (optional, matches in-app `UserProfile.id`)

3. **Automations** (recommended): **Order paid** → **Trigger Webhook** → your Velo HTTP function URL, **or** use the Velo `post_felRelayWixOrder` example in `http-functions.js` and call it from automation with JSON body.

### Velo: map order → Supabase user (metadata)

Your Automation or Velo job must send JSON that includes:

```json
{
  "wix_order_id": "<from order>",
  "supabase_user_id": "<member custom field OR collected at checkout>",
  "athlete_id": "<optional in-app id>",
  "shard_delta": 750,
  "cortex_delta": 40,
  "product_sku": "wix_sovereign_shard_pack"
}
```

`athlete_id` is optional but recommended so `fel_upsert_athlete_profile_link_for_service` can link forensic app identity to the same Supabase user as Stripe checkout.

## 4. Metadata contract

Relay JSON must include:

- `wix_order_id` — unique order id from Wix
- `supabase_user_id` — `auth.users.id` UUID (same as Wallet / Stripe flow)
- `athlete_id` — optional string for `athlete_profile_link`
- `shard_delta` / `cortex_delta` — integers (same RPC as Stripe)

Header on the Edge Function request:

- `X-FEL-Wix-Secret: <FEL_WIX_WEBHOOK_SHARED_SECRET>`
- `Content-Type: application/json`

## 5. Why not call `stripe-webhook-handler`?

That handler verifies `Stripe-Signature`. Wix orders are not Stripe Checkout sessions unless you route payments through Stripe Checkout externally.
