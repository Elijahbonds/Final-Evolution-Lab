#!/usr/bin/env bash
# Phase 8 — Notarize and staple an existing .dmg (no Unreal rebuild).
#
#   export FEL_NOTARY_KEYCHAIN_PROFILE="YourNotaryProfile"
#   ./scripts/notarize_mac_dmg.sh path/to/SovereignLab_1.0_Gold.dmg
#
set -euo pipefail
DMG="${1:?Usage: $0 <path-to.dmg>}"
[[ -f "${DMG}" ]] || { echo "ERROR: not a file: ${DMG}" >&2; exit 1; }
: "${FEL_NOTARY_KEYCHAIN_PROFILE:?Set FEL_NOTARY_KEYCHAIN_PROFILE (notarytool keychain profile)}"

echo "==> notarytool submit --wait → ${DMG}"
xcrun notarytool submit "${DMG}" --keychain-profile "${FEL_NOTARY_KEYCHAIN_PROFILE}" --wait
echo "==> stapler staple"
xcrun stapler staple "${DMG}"
echo "OK — validate with: xcrun stapler validate \"${DMG}\""
