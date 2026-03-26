#!/usr/bin/env bash
# Phase 10 — Smoke-check Gold Master DMG is reachable (Supabase public object + optional Netlify short URL).
#
# Default DMG URL matches sites/final-evolution-main-site/src/constants/downloads.ts — override if your project differs:
#   FEL_DMG_PUBLIC_URL="https://<project>.supabase.co/storage/v1/object/public/sovereign-assets/mac/SovereignLab_1.0_Gold.dmg"
#
# Optional: also verify on-domain redirect (302 → Supabase):
#   FEL_NETLIFY_DOWNLOAD_URL="https://<your-site>.netlify.app/download/final-evolution"
#
set -euo pipefail

# Keep in sync with GOLD_MASTER_DMG_PRODUCTION_URL in sites/final-evolution-main-site/src/constants/downloads.ts
DEFAULT_DMG_URL="https://rlqkschgvlrva-wsdzjxq.supabase.co/storage/v1/object/public/sovereign-assets/mac/SovereignLab_1.0_Gold.dmg"
DMG_URL="${FEL_DMG_PUBLIC_URL:-$DEFAULT_DMG_URL}"
SHORT_URL="${FEL_NETLIFY_DOWNLOAD_URL:-}"

echo "==> Range GET (first byte) ${DMG_URL}"
if ! curl -sS -f -r 0-0 "${DMG_URL}" -o /dev/null; then
  echo "ERROR: DMG URL not readable (expect 206/200). Run Phase 9 upload or fix public bucket ACL." >&2
  exit 1
fi

CL="$(curl -sSI "${DMG_URL}" | grep -i '^content-length:' | awk '{print $2}' | tr -d '\r' | head -1 || true)"
if [[ -n "${CL}" ]] && [[ "${CL}" =~ ^[0-9]+$ ]] && [[ "${CL}" -lt 1048576 ]]; then
  echo "WARNING: Content-Length ${CL} bytes — expected a multi-MB .dmg; wrong object or empty upload?" >&2
fi

if [[ -n "${SHORT_URL}" ]]; then
  echo "==> GET ${SHORT_URL} (expect redirect to Supabase .dmg)"
  CODE="$(curl -sS -o /dev/null -w '%{http_code}' -I "${SHORT_URL}")"
  if [[ "${CODE}" != "302" && "${CODE}" != "301" && "${CODE}" != "307" && "${CODE}" != "308" ]]; then
    echo "ERROR: short URL HTTP ${CODE} — expected 30x redirect (check sites/.../netlify.toml)." >&2
    exit 1
  fi
  LOC="$(curl -sSI "${SHORT_URL}" | grep -i '^location:' | head -1 | sed 's/^[Ll]ocation:[[:space:]]*//' | tr -d '\r')"
  if [[ "${LOC}" != *".dmg"* ]]; then
    echo "ERROR: Location does not look like a .dmg: ${LOC}" >&2
    exit 1
  fi
  echo "    Location: ${LOC}"
fi

echo "OK — Gold Master distribution checks passed."
