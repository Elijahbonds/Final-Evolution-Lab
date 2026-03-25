#!/usr/bin/env bash
# Upload Gold Master binaries to Supabase Storage — bucket: sovereign-assets
#
# Prerequisites:
#   1) Create bucket `sovereign-assets` in Supabase Dashboard → Storage (public read for /builds/* if you want direct links).
#   2) Export:
#        export SUPABASE_URL="https://YOUR_PROJECT.supabase.co"
#        export SUPABASE_SERVICE_ROLE_KEY="eyJ..."   # service_role — never commit
#
# Usage (repo root):
#   ./scripts/upload_to_supabase_storage.sh path/to/FinalEvolutionLabUnreal-Sovereign.dmg
#   ./scripts/upload_to_supabase_storage.sh path/to/FEL-Sovereign-Win-x64.zip
#
# Optional:
#   FEL_STORAGE_PREFIX=builds/v1   — object key prefix (default: builds)
#
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
: "${SUPABASE_URL:?Set SUPABASE_URL}"
: "${SUPABASE_SERVICE_ROLE_KEY:?Set SUPABASE_SERVICE_ROLE_KEY}"

FILE="${1:?Usage: $0 <path-to-dmg-or-zip>}"
[[ -f "$FILE" ]] || { echo "ERROR: not a file: $FILE"; exit 1; }

PREFIX="${FEL_STORAGE_PREFIX:-builds}"
BASENAME="$(basename "$FILE")"
OBJECT_KEY="${PREFIX}/${BASENAME}"

# Storage REST: upload with upsert
URL="${SUPABASE_URL%/}/storage/v1/object/sovereign-assets/${OBJECT_KEY}"

echo "==> Uploading to ${URL}"
curl -sS -X POST "$URL" \
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
