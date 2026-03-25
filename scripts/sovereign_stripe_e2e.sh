#!/usr/bin/env bash
# Test-mode Stripe → Supabase wallet E2E (manual + optional REST verify).
# Prerequisites: Stripe test Payment Links in web/fel-public-config.js, webhook deployed,
# Edge Function secrets set, user exists in Supabase Auth.
set -euo pipefail

echo "=== Sovereign Stripe E2E (test mode) ==="
echo ""
echo "1) Config"
echo "   Copy web/fel-public-config.example.js → web/fel-public-config.js"
echo "   Set FEL_STRIPE_PAYMENT_LINK_* to Stripe Dashboard Payment Links (test mode)."
echo ""
echo "2) Deploy web/ (or run: npx serve web -p 3000) and open /wallet/"
echo "   Sign in with the same Supabase user you will use at checkout."
echo ""
echo "3) Open /shop/ while signed in — checkout appends client_reference_id=<your auth uuid>."
echo "   Pay with card 4242 4242 4242 4242 (any future expiry, any CVC)."
echo ""
echo "4) Webhook"
echo "   Stripe Dashboard → Developers → Webhooks → your endpoint"
echo "   URL: \${SUPABASE_URL}/functions/v1/stripe-webhook-handler"
echo "   Event: checkout.session.completed"
echo ""
echo "   Local forward (optional):"
echo "   stripe listen --forward-to \"\${SUPABASE_URL}/functions/v1/stripe-webhook-handler\""
echo ""
echo "5) Verify"
echo "   Supabase → Table Editor → user_balances / sovereign_market_transactions"
echo "   /wallet/ should show updated shards (Realtime) within seconds."
echo ""

if [[ -n "${SUPABASE_URL:-}" && -n "${SUPABASE_ANON_KEY:-}" && -n "${TEST_USER_JWT:-}" ]]; then
  echo "==> REST snapshot (TEST_USER_JWT must be the wallet user)"
  curl -sS "${SUPABASE_URL}/rest/v1/user_balances?select=shard_balance,cortex_credits,updated_at" \
    -H "apikey: ${SUPABASE_ANON_KEY}" \
    -H "Authorization: Bearer ${TEST_USER_JWT}" | head -c 800
  echo ""
else
  echo "(Optional) Export SUPABASE_URL, SUPABASE_ANON_KEY, TEST_USER_JWT to print wallet row here."
fi

echo "Done."
