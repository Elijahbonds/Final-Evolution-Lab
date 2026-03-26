#!/usr/bin/env bash
# Upload Gold Master binaries to Supabase Storage — bucket: sovereign-assets
#
# Prerequisites:
#   1) Create bucket `sovereign-assets` in Supabase Dashboard → Storage (public read for objects you link from the site).
#   2) Export:
#        export SUPABASE_URL="https://YOUR_PROJECT.supabase.co"
#        export SUPABASE_SERVICE_ROLE_KEY="eyJ..."   # service_role — never commit
#
# Usage (repo root):
#   ./scripts/upload_to_supabase_storage.sh path/to/FinalEvolutionLabUnreal-Sovereign.dmg
#   ./scripts/upload_to_supabase_storage.sh path/to/FEL-Sovereign-Win-x64.zip
#
# Phase 9 (Mac Gold DMG — matches Netlify + sites/.../downloads.ts):
#   ./scripts/upload_gold_master_mac_dmg.sh
#   or: FEL_STORAGE_PREFIX=mac ./scripts/upload_to_supabase_storage.sh path/to/SovereignLab_1.0_Gold.dmg
#
# Optional:
#   FEL_STORAGE_PREFIX=builds/v1   — object key prefix (default: builds, or mac/ for SovereignLab_1.0_Gold.dmg)
#
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
: "${SUPABASE_URL:?Set SUPABASE_URL}"
: "${SUPABASE_SERVICE_ROLE_KEY:?Set SUPABASE_SERVICE_ROLE_KEY}"

FILE="${1:?Usage: $0 <path-to-dmg-or-zip>}"
[[ -f "$FILE" ]] || { echo "ERROR: not a file: $FILE"; exit 1; }

BASENAME="$(basename "$FILE")"
# Gold Mac DMG (Phase 9) lives under mac/ per sites/.../downloads.ts — avoid wrong default prefix.
if [[ -n "${FEL_STORAGE_PREFIX:-}" ]]; then
  PREFIX="${FEL_STORAGE_PREFIX}"
elif [[ "${BASENAME}" == "SovereignLab_1.0_Gold.dmg" ]]; then
  PREFIX="mac"
else
  PREFIX="builds"
fi
OBJECT_KEY="${PREFIX}/${BASENAME}"

# Storage REST: upload with upsert
URL="${SUPABASE_URL%/}/storage/v1/object/sovereign-assets/${OBJECT_KEY}"

echo "==> Uploading to ${URL}"
curl -sS -f -X POST "$URL" \
  -H "Authorization: Bearer ${SUPABASE_SERVICE_ROLE_KEY}" \
  -H "apikey: ${SUPABASE_SERVICE_ROLE_KEY}" \
  -H "Content-Type: application/octet-stream" \
  -H "x-upsert: true" \
  --data-binary "@${FILE}"

echo ""
echo "==> Public URL (if bucket/object is public):"
echo "    ${SUPABASE_URL%/}/storage/v1/object/public/sovereign-assets/${OBJECT_KEY}"
echo ""
echo "==> Signed URL: use Dashboard → Storage → object → Create signed URL, or Supabase client in app."
echo "    Set Mac button href + Wix Thank You page to this URL (or your custom domain redirect)."
