# Financial Ignition — Go Live (Sovereign Bank)

Run these steps **on your machine** with production Supabase + Stripe access.

### One script (after `supabase init` in repo)

```bash
export SUPABASE_ACCESS_TOKEN='sbp_...'   # Dashboard → Account → Access Tokens
export SUPABASE_PROJECT_REF='xxxxxxxxxxxxxxxxxxxx'
```

**Project ref** is the segment in your DB host: `db.<PROJECT_REF>.supabase.co` (e.g. if the connection string is `postgresql://postgres:…@db.abc123xyz.supabase.co:5432/postgres`, then `SUPABASE_PROJECT_REF=abc123xyz`).

**Database password** (not the anon key): Dashboard → **Project Settings → Database** → reset or copy the Postgres password. If `supabase link` / `db push` asks for the DB password:

```bash
export SUPABASE_DB_PASSWORD='your-database-password'
```

Then Stripe + service role (optional but recommended):

```bash
export STRIPE_WEBHOOK_SIGNING_SECRET='whsec_...'
export STRIPE_API_KEY='sk_live_...'
export SUPABASE_SERVICE_ROLE_KEY='eyJ...'
# SUPABASE_URL defaults to https://${SUPABASE_PROJECT_REF}.supabase.co
```

```bash
./scripts/run_financial_ignition.sh
```

**Security:** never commit `postgresql://postgres:REAL_PASSWORD@...` or `.env` with secrets. Use Dashboard **SQL Editor** for migrations if you prefer not to put the DB password in a shell export.

---

## 1. Apply database migration

Ensure `20260326120000_stripe_webhook_service_rpcs.sql` (and prior Sovereign migrations) are on **production**:

```bash
cd /path/to/repo
supabase link --project-ref YOUR_PROJECT_REF   # once
supabase db push
```

Or paste the SQL into **Supabase Dashboard → SQL Editor** and execute (review first).

**Verify** in SQL:

```sql
SELECT proname FROM pg_proc WHERE proname IN (
  'fel_resolve_user_id_by_email',
  'fel_upsert_athlete_profile_link_for_service'
);
```

## 2. Set Edge Function secrets

```bash
export STRIPE_WEBHOOK_SIGNING_SECRET=whsec_...
export STRIPE_API_KEY=sk_live_...
export SUPABASE_SERVICE_ROLE_KEY=eyJ...
export SUPABASE_URL=https://YOUR_PROJECT.supabase.co

./scripts/supabase_set_production_secrets.sh
```

## 3. Deploy webhook

```bash
supabase functions deploy stripe-webhook-handler --no-verify-jwt
```

In **Stripe Dashboard → Developers → Webhooks**, add endpoint:

`https://YOUR_PROJECT.supabase.co/functions/v1/stripe-webhook-handler`  
Event: **`checkout.session.completed`**  
Copy the **signing secret** into `STRIPE_WEBHOOK_SIGNING_SECRET` (re-run secrets if it changed).

## 4. Test Mode dry run (VVA Blueprint $19.99)

1. Create a **test** Payment Link or Checkout Session with:
   - **Amount** $19.99 (or metadata `shard_delta` / `cortex_delta` / `product_sku`), and  
   - **Customer email** matching a **real Supabase Auth user** in your project, **or**  
   - `metadata.supabase_user_id` / linked `metadata.athlete_id`.

2. Forward webhooks locally (optional):

```bash
stripe listen --forward-to https://YOUR_PROJECT.supabase.co/functions/v1/stripe-webhook-handler
```

3. Complete test checkout. **Confirm** in Supabase:
   - **`user_balances`** — `shard_balance` / `cortex_credits` increased for that `user_id`.
   - **`sovereign_market_transactions`** — row with `stripe_session_id`.

4. **iOS app** (signed in): shard badge should update via Realtime without refresh.

---

*Final Evolution — Sovereign Bank go-live checklist*
