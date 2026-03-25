#!/usr/bin/env bash
# Financial Ignition — apply Sovereign migrations, set secrets, deploy stripe-webhook-handler.
#
# Prerequisites:
#   - Node.js (npx) OR `brew install supabase/tap/supabase`
#   - Supabase: Dashboard → Account → Access Token, or `supabase login`
#
# Required env:
#   SUPABASE_ACCESS_TOKEN   — from https://supabase.com/dashboard/account/tokens
#   SUPABASE_PROJECT_REF    — Project Settings → General → Reference ID
#
# Optional:
#   SUPABASE_DB_PASSWORD      — Database password (Project Settings → Database). Use with `supabase link -p`
#                               when CLI needs direct Postgres access for `db push`.
#   STRIPE_WEBHOOK_SIGNING_SECRET, STRIPE_API_KEY, SUPABASE_SERVICE_ROLE_KEY
#   SUPABASE_URL — optional; defaults to https://${SUPABASE_PROJECT_REF}.supabase.co
#   (if Stripe + service role set, runs scripts/supabase_set_production_secrets.sh after link)
#
# Usage (repo root):
#   export SUPABASE_ACCESS_TOKEN=sbp_...
#   export SUPABASE_PROJECT_REF=xxxxxxxxxxxxxxxxxxxx
#   ./scripts/run_financial_ignition.sh
#
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SUPABASE_BIN=(npx --yes supabase)
if command -v supabase >/dev/null 2>&1; then
  SUPABASE_BIN=(supabase)
fi

echo "========================================================="
echo " Financial Ignition — Sovereign Bank"
echo "========================================================="

if [[ -z "${SUPABASE_ACCESS_TOKEN:-}" ]]; then
  echo ""
  echo "BLOCKED: SUPABASE_ACCESS_TOKEN is not set."
  echo "  1. Open https://supabase.com/dashboard/account/tokens"
  echo "  2. Create a token, then:"
  echo "     export SUPABASE_ACCESS_TOKEN='your_token_here'"
  echo "  3. export SUPABASE_PROJECT_REF='your_project_ref'"
  echo "  4. Re-run: ./scripts/run_financial_ignition.sh"
  echo ""
  echo "Alternative: run SQL manually — see DOCS/FINANCIAL_IGNITION.md"
  exit 2
fi

if [[ -z "${SUPABASE_PROJECT_REF:-}" ]]; then
  echo "ERROR: Set SUPABASE_PROJECT_REF (Project Settings → General → Reference ID)."
  exit 1
fi

export SUPABASE_ACCESS_TOKEN
export SUPABASE_URL="${SUPABASE_URL:-https://${SUPABASE_PROJECT_REF}.supabase.co}"

echo "==> Linking remote project ${SUPABASE_PROJECT_REF}..."
LINK_ARGS=(--project-ref "$SUPABASE_PROJECT_REF")
if [[ -n "${SUPABASE_DB_PASSWORD:-}" ]]; then
  LINK_ARGS+=(--password "$SUPABASE_DB_PASSWORD")
fi
"${SUPABASE_BIN[@]}" link "${LINK_ARGS[@]}" || {
  echo "NOTE: link failed — if already linked, continuing. For password prompts set SUPABASE_DB_PASSWORD."
}

echo "==> Pushing database migrations..."
"${SUPABASE_BIN[@]}" db push || {
  echo "ERROR: db push failed. Apply migrations via Dashboard SQL Editor:"
  echo "  supabase/migrations/20260324120000_sovereign_bank.sql"
  echo "  supabase/migrations/20260324140000_sovereign_realtime_athlete_map.sql"
  echo "  supabase/migrations/20260325120000_fel_upsert_athlete_link_rpc.sql"
  echo "  supabase/migrations/20260326120000_stripe_webhook_service_rpcs.sql"
  exit 1
}

if [[ -n "${STRIPE_WEBHOOK_SIGNING_SECRET:-}" && -n "${STRIPE_API_KEY:-}" && -n "${SUPABASE_SERVICE_ROLE_KEY:-}" ]]; then
  echo "==> Setting Edge Function secrets..."
  export SUPABASE_URL="${SUPABASE_URL:-https://${SUPABASE_PROJECT_REF}.supabase.co}"
  "$ROOT/scripts/supabase_set_production_secrets.sh"
else
  echo "==> Skipping secrets (set STRIPE_WEBHOOK_SIGNING_SECRET, STRIPE_API_KEY, SUPABASE_SERVICE_ROLE_KEY to auto-run)."
fi

echo "==> Deploying stripe-webhook-handler..."
"${SUPABASE_BIN[@]}" functions deploy stripe-webhook-handler --no-verify-jwt --project-ref "$SUPABASE_PROJECT_REF"

echo ""
echo "========================================================="
echo " Financial Ignition — steps completed."
echo " Next: Stripe Dashboard → Webhooks → endpoint:"
echo "   https://${SUPABASE_PROJECT_REF}.supabase.co/functions/v1/stripe-webhook-handler"
echo " Event: checkout.session.completed"
echo " See DOCS/FINANCIAL_IGNITION.md for Test Mode verification."
echo "========================================================="
