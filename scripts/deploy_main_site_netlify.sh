#!/usr/bin/env bash
# Phase 10 — Build and deploy sites/final-evolution-main-site (Vite) to Netlify production.
# This site owns /download/final-evolution → Supabase DMG (see netlify.toml in that folder).
#
# Prereqs: Node 18+, npm i -g netlify-cli, netlify login (once), site linked in that directory.
#
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SITE="${ROOT}/sites/final-evolution-main-site"
cd "${SITE}"

if ! command -v npm >/dev/null 2>&1; then
  echo "ERROR: npm not found" >&2
  exit 1
fi

echo "==> npm ci + build"
npm ci
npm run build

if command -v netlify >/dev/null 2>&1; then
  echo "==> netlify deploy --prod --dir=dist"
  netlify deploy --prod --dir=dist "$@"
else
  echo "Netlify CLI not found. Install: npm i -g netlify-cli" >&2
  echo "Build output is ready at: ${SITE}/dist — upload manually or link CI." >&2
  exit 1
fi

echo "Next: ./scripts/verify_gold_master_distribution.sh with FEL_NETLIFY_DOWNLOAD_URL=<your-prod>/download/final-evolution"
