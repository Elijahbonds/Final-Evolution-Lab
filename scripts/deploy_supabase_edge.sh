#!/usr/bin/env bash
# Deploy Sovereign Edge Functions from repo root (M4 Pro / CI).
# Prerequisites: supabase CLI linked (`supabase link`), secrets set in Dashboard or `supabase secrets set`.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "==> Deploying stripe-webhook-handler"
supabase functions deploy stripe-webhook-handler --no-verify-jwt

echo "==> Deploying wix-order-completed"
supabase functions deploy wix-order-completed --no-verify-jwt

echo "==> Done. Stripe webhook URL: https://<project>.supabase.co/functions/v1/stripe-webhook-handler"
echo "    Configure endpoint + signing secret in Stripe Dashboard → Webhooks."
