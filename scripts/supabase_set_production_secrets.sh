#!/usr/bin/env bash
# Final Evolution — set Supabase Edge Function secrets for production (Stripe webhook + service role).
#
# Prerequisites: Supabase CLI logged in (`supabase login`) and project linked (`supabase link`).
#
# Usage (export vars then run):
#   export STRIPE_WEBHOOK_SIGNING_SECRET=whsec_...
#   export STRIPE_API_KEY=sk_live_...
#   export SUPABASE_SERVICE_ROLE_KEY=eyJ...
#   export SUPABASE_URL=https://xxxx.supabase.co   # optional if already in project
#   ./scripts/supabase_set_production_secrets.sh
#
# Legacy aliases (also accepted):
#   STRIPE_WEBHOOK_SECRET, STRIPE_SECRET_KEY
#
set -euo pipefail

WH="${STRIPE_WEBHOOK_SIGNING_SECRET:-${STRIPE_WEBHOOK_SECRET:-}}"
SK="${STRIPE_API_KEY:-${STRIPE_SECRET_KEY:-}}"
SRK="${SUPABASE_SERVICE_ROLE_KEY:-}"
URL="${SUPABASE_URL:-}"

if [[ -z "$WH" ]]; then
  echo "ERROR: Set STRIPE_WEBHOOK_SIGNING_SECRET (or STRIPE_WEBHOOK_SECRET)."
  exit 1
fi
if [[ -z "$SK" ]]; then
  echo "ERROR: Set STRIPE_API_KEY (or STRIPE_SECRET_KEY)."
  exit 1
fi
if [[ -z "$SRK" ]]; then
  echo "ERROR: Set SUPABASE_SERVICE_ROLE_KEY."
  exit 1
fi

ARGS=(
  "STRIPE_WEBHOOK_SIGNING_SECRET=$WH"
  "STRIPE_API_KEY=$SK"
  "SUPABASE_SERVICE_ROLE_KEY=$SRK"
)

# Also set aliases consumed by older deploy docs / local tooling
ARGS+=(
  "STRIPE_WEBHOOK_SECRET=$WH"
  "STRIPE_SECRET_KEY=$SK"
)

if [[ -n "$URL" ]]; then
  ARGS+=("SUPABASE_URL=$URL")
fi

echo "==> supabase secrets set (production Stripe + service role)"
supabase secrets set "${ARGS[@]}"

echo "==> Done. Deploy function: supabase functions deploy stripe-webhook-handler --no-verify-jwt"
echo "    Stripe Dashboard → Webhook → signing secret must match STRIPE_WEBHOOK_SIGNING_SECRET"
