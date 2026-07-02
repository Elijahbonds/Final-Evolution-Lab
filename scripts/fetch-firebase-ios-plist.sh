#!/usr/bin/env bash
# Fetch GoogleService-Info.plist via Firebase CLI (requires firebase login + project access).
# Does NOT commit secrets — writes gitignored FinalEvolutionLab/GoogleService-Info.plist only.
#
# Usage:
#   ./scripts/fetch-firebase-ios-plist.sh              # list iOS apps; highlight com.finalevolutionlab.app
#   ./scripts/fetch-firebase-ios-plist.sh --download   # auto-download correct app plist
#   ./scripts/fetch-firebase-ios-plist.sh <IOS_APP_ID> # download plist for explicit app ID
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${ROOT}/FinalEvolutionLab/GoogleService-Info.plist"
PROJECT="${FIREBASE_PROJECT:-final-evolution-lab}"
BUNDLE_ID="com.finalevolutionlab.app"
LEGACY_BUNDLE_ID="FinalEvoLab"
DOWNLOAD=0
APP_ID=""

source "${ROOT}/scripts/use_firebase_cli.sh"

if ! command -v firebase >/dev/null; then
  echo "error: firebase CLI not found. Install: npm install -g firebase-tools" >&2
  exit 1
fi

if ! firebase apps:list IOS --project "$PROJECT" >/dev/null 2>&1; then
  echo "==> Authenticate (one-time): firebase login" >&2
  echo "    Then re-run this script." >&2
  exit 1
fi

for arg in "$@"; do
  case "$arg" in
    --download) DOWNLOAD=1 ;;
    -h|--help)
      echo "Usage: $0 [--download] [<IOS_APP_ID>]"
      echo ""
      echo "  --download   Auto-select iOS app with bundle ${BUNDLE_ID} and write GoogleService-Info.plist"
      echo "  <IOS_APP_ID> Download plist for explicit Firebase iOS app ID"
      exit 0
      ;;
    *)
      if [[ "$arg" != --* ]]; then
        APP_ID="$arg"
      fi
      ;;
  esac
done

fel_resolve_nexus_app_id() {
  local list_tmp resolved line
  list_tmp="$(mktemp)"
  firebase apps:list IOS --project "$PROJECT" >"$list_tmp" 2>/dev/null || firebase apps:list --project "$PROJECT" >"$list_tmp"
  while IFS= read -r line; do
    if [[ "$line" == *"Final Evolution Lab"* ]]; then
      resolved="$(grep -oE '1:[0-9]+:ios:[a-f0-9]+' <<<"$line" | head -1)"
      [[ -n "${resolved:-}" ]] && break
    fi
  done <"$list_tmp"
  if [[ -z "${resolved:-}" ]]; then
    local tmp_plist app_line candidate bundle
    while IFS= read -r app_line; do
      [[ "$app_line" =~ 1:[0-9]+:ios:[a-f0-9]+ ]] || continue
      candidate="$(grep -oE '1:[0-9]+:ios:[a-f0-9]+' <<<"$app_line" | head -1)"
      [[ -n "$candidate" ]] || continue
      tmp_plist="$(mktemp)"
      if firebase apps:sdkconfig IOS "$candidate" --project "$PROJECT" -o "$tmp_plist" 2>/dev/null; then
        bundle="$(/usr/libexec/PlistBuddy -c "Print :BUNDLE_ID" "$tmp_plist" 2>/dev/null || true)"
        rm -f "$tmp_plist"
        if [[ "$bundle" == "$BUNDLE_ID" ]]; then
          resolved="$candidate"
          break
        fi
      else
        rm -f "$tmp_plist"
      fi
    done <"$list_tmp"
  fi
  rm -f "$list_tmp"
  [[ -n "${resolved:-}" ]] || return 1
  echo "$resolved"
}

fel_download_plist() {
  local app_id="${1:?app id required}"
  local tmp
  tmp="$(mktemp)"
  trap 'rm -f "$tmp"' RETURN

  echo "==> firebase apps:sdkconfig IOS ${app_id} → ${OUT}"
  firebase apps:sdkconfig IOS "$app_id" --project "$PROJECT" -o "$tmp"

  if bash "${ROOT}/scripts/lib/firebase-plist-check.sh" is-placeholder "$tmp"; then
    echo "error: CLI returned placeholder-like config — check app ID and project access" >&2
    return 1
  fi

  local bundle
  bundle="$(/usr/libexec/PlistBuddy -c "Print :BUNDLE_ID" "$tmp")"
  if [[ "$bundle" != "$BUNDLE_ID" ]]; then
    echo "error: BUNDLE_ID is ${bundle}; expected ${BUNDLE_ID}" >&2
    if [[ "$bundle" == "$LEGACY_BUNDLE_ID" ]]; then
      echo "hint: app ID is legacy FinalEvoLab — use Final Evolution Lab app instead:" >&2
      echo "      https://console.firebase.google.com/project/${PROJECT}/settings/general" >&2
    fi
    return 1
  fi

  cp "$tmp" "$OUT"
  echo "==> Wrote ${OUT} (gitignored — verify with Config/FEL_FIREBASE_TESTFLIGHT_CHECKLIST.txt)"
  echo "    BUNDLE_ID: ${bundle}"
  echo "    GOOGLE_APP_ID: $(/usr/libexec/PlistBuddy -c 'Print :GOOGLE_APP_ID' "$OUT")"
  echo "    ! grep -q REPLACE_ME ${OUT} && echo OK"
}

if [[ $# -eq 0 || ( "$DOWNLOAD" -eq 1 && -z "$APP_ID" ) ]]; then
  echo "==> iOS apps in project ${PROJECT}:"
  firebase apps:list IOS --project "$PROJECT" 2>/dev/null || firebase apps:list --project "$PROJECT"
  echo ""
  echo "NEXUS ship target bundle: ${BUNDLE_ID}"
  echo "Legacy bundle (do NOT use for upload): ${LEGACY_BUNDLE_ID}"
  echo ""
  if resolved="$(fel_resolve_nexus_app_id)"; then
    echo "Correct Firebase iOS app ID: ${resolved}"
    echo "Download:"
    echo "  $0 ${resolved}"
    echo "  $0 --download"
  else
    echo "error: no Firebase iOS app registered for ${BUNDLE_ID}" >&2
    echo "       Register in Firebase Console → Project settings → Add app → iOS" >&2
    echo "       https://console.firebase.google.com/project/${PROJECT}/settings/general" >&2
    exit 1
  fi
  if [[ "$DOWNLOAD" -eq 1 ]]; then
    fel_download_plist "$resolved"
  fi
  exit 0
fi

if [[ -z "$APP_ID" ]]; then
  echo "error: missing IOS_APP_ID (or use --download)" >&2
  exit 1
fi

fel_download_plist "$APP_ID"
