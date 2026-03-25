#!/usr/bin/env bash
# Deploy `web/` to Netlify (install CLI: npm i -g netlify-cli) or print rsync instructions.
# Publish root: web/ — see web/DEPLOY.txt and repo root netlify.toml
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if command -v netlify >/dev/null 2>&1; then
  echo "==> Netlify deploy (production)"
  netlify deploy --prod --dir=web "$@"
else
  echo "Netlify CLI not found. Install: npm i -g netlify-cli"
  echo "Or sync manually, e.g.:"
  echo "  rsync -av --delete web/ user@host:/var/www/fel/"
  echo "See web/DEPLOY.txt for routes and fel-public-config.js."
  exit 1
fi
