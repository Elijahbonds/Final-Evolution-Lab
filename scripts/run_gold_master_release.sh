#!/usr/bin/env bash
# Run Gold Master phases in order: package (7) + optional notarize in package script (8),
# upload (9) if Supabase env is set, verify (10) if FEL_VERIFY_AFTER_RELEASE=1.
#
# Sovereign Gold Pipeline (full: Unreal → DMG → notarize → Supabase → verify):
#   # 1. Identity & cloud handshake (never commit secrets)
#   export SUPABASE_URL="https://rlqkschgvlrva-wsdzjxq.supabase.co"
#   export SUPABASE_SERVICE_ROLE_KEY="<Paste_Service_Role_Key_Here>"
#   export FEL_NOTARY_KEYCHAIN_PROFILE="<Paste_Notary_Profile_Name_Here>"
#   # 2. From repo root — FEL_MAC_UNIVERSAL + FEL_REQUIRE_UNIVERSAL: request fat binary, fail lipo if single-arch
#   cd /Users/elijahbonds/Documents/rork-final-evolution-lab
#   FEL_NOTARIZE=1 FEL_VERIFY_AFTER_RELEASE=1 FEL_REQUIRE_UNIVERSAL=1 FEL_MAC_UNIVERSAL=1 \
#     FEL_NETLIFY_DOWNLOAD_URL="https://finalevolutiongroup.com/download/final-evolution" \
#     ./scripts/run_gold_master_release.sh
#   # Alternate short URL (pre-custom-domain): FEL_NETLIFY_DOWNLOAD_URL="https://YOUR_SITE.netlify.app/download/final-evolution"
#
# Examples:
#   # Build DMG only (same as package script alone)
#   ./scripts/run_gold_master_release.sh
#
#   # Build + notarize + upload + verify
#   export SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=...
#   export FEL_NOTARIZE=1 FEL_NOTARY_KEYCHAIN_PROFILE=...
#   FEL_VERIFY_AFTER_RELEASE=1 FEL_NETLIFY_DOWNLOAD_URL="https://yoursite.netlify.app/download/final-evolution" \
#     ./scripts/run_gold_master_release.sh
#
#   # Upload existing DMG (skip Unreal)
#   FEL_SKIP_PACKAGE=1 ./scripts/run_gold_master_release.sh
#
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PKG="${ROOT}/UnrealStarter/BasketballGame/Scripts/package_gold_master_mac_shipping.sh"
DEFAULT_DMG="${ROOT}/UnrealStarter/BasketballGame/Saved/Archive/GoldMaster_Mac_Shipping/SovereignLab_1.0_Gold.dmg"
# If you override DMG_NAME in the package script, set FEL_DMG_PATH here for upload.
DMG="${FEL_DMG_PATH:-$DEFAULT_DMG}"

# Fail fast before RunUAT (can take 30–60+ min) if notarization was requested without credentials.
if [[ "${FEL_NOTARIZE:-0}" == "1" ]]; then
  : "${FEL_NOTARY_KEYCHAIN_PROFILE:?FEL_NOTARIZE=1 requires FEL_NOTARY_KEYCHAIN_PROFILE (create with: xcrun notarytool store-credentials)}"
fi

if [[ "${FEL_SKIP_PACKAGE:-0}" != "1" ]]; then
  echo "=== Phases 7–8: package (+ notarize if FEL_NOTARIZE=1)"
  bash "${PKG}"
else
  echo "=== Skip package (FEL_SKIP_PACKAGE=1)"
fi

if [[ -n "${SUPABASE_URL:-}" && -n "${SUPABASE_SERVICE_ROLE_KEY:-}" ]]; then
  echo "=== Phase 9: Supabase upload"
  if [[ -f "${DMG}" ]]; then
    "${ROOT}/scripts/upload_gold_master_mac_dmg.sh" "${DMG}"
  else
    echo "ERROR: DMG not found at ${DMG} — cannot upload (set FEL_DMG_PATH or run package first)" >&2
    exit 1
  fi
else
  echo "=== Skip Phase 9 (set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY)"
fi

if [[ "${FEL_VERIFY_AFTER_RELEASE:-0}" == "1" ]]; then
  echo "=== Phase 10: verify distribution URLs"
  "${ROOT}/scripts/verify_gold_master_distribution.sh"
fi

echo "=== Gold Master release runner finished"
