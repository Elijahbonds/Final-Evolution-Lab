#!/usr/bin/env bash
# Final Evolution LLC — Sovereign desktop bundles (Mac .dmg + Windows .zip).
# - Mac: wrap cooked .app in a DMG, optionally notarize with notarytool + staple.
# - Windows: zip the shipping folder (exe + dependencies).
# - Gemini / Cloud Cortex: never embed plaintext keys — encrypt at rest and load via launchd / env at runtime.
#
# Required (Mac DMG):
#   FEL_MAC_APP       — path to FinalEvolutionLabUnreal.app (or your cooked Unreal app)
# Optional (notarization):
#   FEL_NOTARIZE      — set to 1 to run xcrun notarytool + stapler
#   FEL_APPLE_ID      — Apple ID for notarytool
#   FEL_TEAM_ID       — Developer team ID
#   FEL_NOTARY_KEYCHAIN_PROFILE — app-specific password keychain profile name for notarytool --keychain-profile
#
# Required (Windows zip):
#   FEL_WIN_FOLDER    — directory containing the .exe + DLLs
#
# Encrypted env bundle (both platforms):
#   FEL_GEMINI_KEY_PLAINTEXT — optional; if set with FEL_ENV_PASSPHRASE, writes encrypted blob only.
#   FEL_ENV_PASSPHRASE       — passphrase for openssl enc -aes-256-cbc
#
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${FEL_OUT_DIR:-$ROOT/build/sovereign-desktop}"
mkdir -p "$OUT"

encrypt_gemini_env() {
  local blob="$OUT/GEMINI_ENV.enc"
  if [[ -z "${FEL_GEMINI_KEY_PLAINTEXT:-}" || -z "${FEL_ENV_PASSPHRASE:-}" ]]; then
    echo "==> Skipping GEMINI_ENV.enc (set FEL_GEMINI_KEY_PLAINTEXT + FEL_ENV_PASSPHRASE to generate)"
    return 0
  fi
  echo "==> Writing encrypted Cloud Cortex env blob (openssl aes-256-cbc)"
  printf '%s' "GEMINI_API_KEY=${FEL_GEMINI_KEY_PLAINTEXT}" | openssl enc -aes-256-cbc -salt -pbkdf2 -out "$blob" -pass "pass:${FEL_ENV_PASSPHRASE}"
  echo "    $blob (load at runtime with matching passphrase — do not commit passphrase)"
}

package_mac() {
  local app="${FEL_MAC_APP:-}"
  if [[ -z "$app" || ! -d "$app" ]]; then
    echo "==> Mac: FEL_MAC_APP not set or missing — skip DMG"
    return 0
  fi
  local name
  name="$(basename "$app" .app)"
  local dmg="$OUT/${name}-Sovereign.dmg"
  echo "==> Mac: creating DMG → $dmg"
  hdiutil create -volname "$name" -srcfolder "$app" -ov -format UDZO "$dmg"
  if [[ "${FEL_NOTARIZE:-0}" == "1" ]]; then
    if [[ -z "${FEL_APPLE_ID:-}" || -z "${FEL_TEAM_ID:-}" ]]; then
      echo "ERROR: FEL_NOTARIZE=1 requires FEL_APPLE_ID and FEL_TEAM_ID"
      exit 1
    fi
    echo "==> notarytool submit + staple (requires ASC API key or keychain profile)"
    if [[ -n "${FEL_NOTARY_KEYCHAIN_PROFILE:-}" ]]; then
      xcrun notarytool submit "$dmg" --keychain-profile "$FEL_NOTARY_KEYCHAIN_PROFILE" --wait
    else
      echo "Set FEL_NOTARY_KEYCHAIN_PROFILE or use API key method per Apple TN3147."
    fi
    xcrun stapler staple "$dmg" || true
  fi
}

package_win() {
  local folder="${FEL_WIN_FOLDER:-}"
  if [[ -z "$folder" || ! -d "$folder" ]]; then
    echo "==> Windows: FEL_WIN_FOLDER not set — skip zip"
    return 0
  fi
  local zip="$OUT/FEL-Sovereign-Win-x64.zip"
  echo "==> Windows: zipping → $zip"
  rm -f "$zip"
  ditto -c -k --sequesterRsrc --keepParent "$folder" "$zip"
}

encrypt_gemini_env
package_mac
package_win

echo "========================================================="
echo " Sovereign desktop artifacts under: $OUT"
echo " Next: upload DMG/zip to Supabase Storage (bypasses Netlify size limits):"
echo "   ./scripts/upload_to_supabase_storage.sh <path-to-dmg-or-zip>"
echo " Then set window.FEL_PUBLIC_DMG_URL in web/fel-public-config.js (public object URL)."
echo "========================================================="
