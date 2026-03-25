#!/usr/bin/env bash
# Gold Master — Sovereign economy smoke checks (run with real secrets in env; do not commit tokens).
# Prerequisites: Supabase CLI logged in, migrations applied, Edge Function deployed, Stripe CLI for signing.
set -euo pipefail

: "${SUPABASE_URL:?Set SUPABASE_URL (https://xxx.supabase.co)}"
: "${SUPABASE_ANON_KEY:?Set anon key (PostgREST apikey header)}"
: "${TEST_USER_JWT:?JWT for user A (authenticated) }"
: "${OTHER_USER_JWT:?JWT for user B — must not see A's wallet}"

echo "==> 1) RLS: user A can read own user_balances"
curl -sS "${SUPABASE_URL}/rest/v1/user_balances?select=shard_balance,cortex_credits&limit=1" \
  -H "apikey: ${SUPABASE_ANON_KEY:-}" \
  -H "Authorization: Bearer ${TEST_USER_JWT}" | head -c 400
echo ""

echo "==> 2) RLS: user B must not get user A rows (expect empty or 403 depending on PostgREST config)"
curl -sS "${SUPABASE_URL}/rest/v1/user_balances?select=*" \
  -H "apikey: ${SUPABASE_ANON_KEY:-}" \
  -H "Authorization: Bearer ${OTHER_USER_JWT}" | head -c 400
echo ""

echo "==> 3) Stripe webhook (local): stripe listen --forward-to \"\${SUPABASE_URL}/functions/v1/stripe-webhook-handler\""
echo "    Then: stripe trigger checkout.session.completed (with metadata.supabase_user_id + shard_delta)"
echo "    Verify rows in user_balances and sovereign_market_transactions in Supabase Table Editor."

echo "==> 4) Supabase CLI alternative: supabase functions serve stripe-webhook-handler --env-file ./supabase/.env.local"
echo "Done."
