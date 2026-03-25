#!/usr/bin/env bash
# Final Evolution LLC — Gold Master (1.0.0 / 5) — TestFlight distribution
# - Preflight: MARKETING_VERSION 1.0.0 + CURRENT_PROJECT_VERSION 6 in project.pbxproj
# - Optional: export IPA from .xcarchive (xcodebuild -exportArchive)
# - Staging: ditto copy to build/distribution/ for audit trail
# - xcrun altool: validate-app then upload-app (App Store Connect API key or Apple ID)
#
# Required for upload (pick one):
#   A) ASC_API_KEY + ASC_ISSUER_ID  [+ optional ASC_P8_PATH]
#   B) APPLE_ID + APP_SPECIFIC_PASSWORD (or -p @keychain:ItemName)
#
# Prerequisite archive (Release):
#   FEL_CONFIGURATION=Release ./scripts/ios_clean_build.sh
#   ./scripts/verify_ios_aps_production.sh   # optional — confirms aps-environment production
#
# Usage (from repo root, after archive exists):
#   export ASC_API_KEY=XXXXXXXXXX ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
#   export ASC_P8_PATH="$HOME/AuthKey_XXXXXXXXXX.p8"   # optional if key is in ./private_keys or standard dirs
#   ./scripts/publish_to_testflight.sh
#
# Environment:
#   FEL_ARCHIVE_PATH   — path to .xcarchive (default: build/FinalEvolutionLabUnreal.xcarchive)
#   FEL_IPA_PATH       — explicit IPA (skips export when set and file exists)
#   FEL_VALIDATE_ONLY  — set to 1 to run validation only (no upload)
#
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PROJECT="FinalEvolutionLabUnreal.xcodeproj"
PBX="$ROOT/$PROJECT/project.pbxproj"
SCHEME="FinalEvolutionLabUnreal"
ARCHIVE_PATH="${FEL_ARCHIVE_PATH:-$ROOT/build/FinalEvolutionLabUnreal.xcarchive}"
EXPORT_DIR="${FEL_EXPORT_DIR:-$ROOT/build/export}"
DIST_DIR="${FEL_DIST_DIR:-$ROOT/build/distribution}"
EXPORT_PLIST="${FEL_EXPORT_OPTIONS_PLIST:-$ROOT/Config/ExportOptions-TestFlight.plist}"
VALIDATE_ONLY="${FEL_VALIDATE_ONLY:-0}"
IPA_PATH="${FEL_IPA_PATH:-}"

verify_gold_master_versions() {
  if [[ ! -f "$PBX" ]]; then
    echo "ERROR: Missing $PBX"
    exit 1
  fi
  if ! grep -q 'MARKETING_VERSION = 1.0.0' "$PBX"; then
    echo "ERROR: Preflight failed — expected MARKETING_VERSION = 1.0.0 in project.pbxproj"
    exit 1
  fi
  if ! grep -q 'CURRENT_PROJECT_VERSION = 6' "$PBX"; then
    echo "ERROR: Preflight failed — expected CURRENT_PROJECT_VERSION = 6 in project.pbxproj"
    exit 1
  fi
  echo "  [OK] Gold Master version gate: MARKETING_VERSION 1.0.0 / CURRENT_PROJECT_VERSION 6"
}

build_altool_auth() {
  ALTOOL_AUTH=()
  if [[ -n "${ASC_API_KEY:-}" && -n "${ASC_ISSUER_ID:-}" ]]; then
    ALTOOL_AUTH+=( --api-key "$ASC_API_KEY" --api-issuer "$ASC_ISSUER_ID" )
    if [[ -n "${ASC_P8_PATH:-}" ]]; then
      ALTOOL_AUTH+=( --p8-file-path "$ASC_P8_PATH" )
    fi
    return 0
  fi
  if [[ -n "${APPLE_ID:-}" ]]; then
    local pw="${ASC_PASSWORD:-${APP_SPECIFIC_PASSWORD:-}}"
    if [[ -z "$pw" ]]; then
      echo "ERROR: Set APP_SPECIFIC_PASSWORD or ASC_PASSWORD when using APPLE_ID."
      exit 1
    fi
    ALTOOL_AUTH+=( -u "$APPLE_ID" -p "$pw" )
    return 0
  fi
  echo "ERROR: No App Store Connect credentials."
  echo "  Set ASC_API_KEY + ASC_ISSUER_ID (and optionally ASC_P8_PATH), or APPLE_ID + APP_SPECIFIC_PASSWORD."
  exit 1
}

find_exported_ipa() {
  local f
  f="$(find "$EXPORT_DIR" -maxdepth 1 -name '*.ipa' -print -quit 2>/dev/null || true)"
  if [[ -n "$f" && -f "$f" ]]; then
    echo "$f"
    return 0
  fi
  return 1
}

echo "========================================================="
echo " Final Evolution Lab — TestFlight publish (1.0.0 build 6 / Alpha 1)"
echo "========================================================="
echo "==> Version gate (project.pbxproj)"
verify_gold_master_versions

if [[ -n "$IPA_PATH" && -f "$IPA_PATH" ]]; then
  echo "==> Using existing IPA: $IPA_PATH"
else
  if [[ ! -d "$ARCHIVE_PATH" ]]; then
    echo "ERROR: No archive at $ARCHIVE_PATH"
    echo "  Run: FEL_CONFIGURATION=Release ./scripts/ios_clean_build.sh"
    exit 1
  fi
  if [[ ! -f "$EXPORT_PLIST" ]]; then
    echo "ERROR: Missing export options plist: $EXPORT_PLIST"
    exit 1
  fi
  echo "==> Exporting IPA (app-store-connect) — $ARCHIVE_PATH"
  rm -rf "$EXPORT_DIR" 2>/dev/null || true
  mkdir -p "$EXPORT_DIR"
  xcodebuild \
    -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_DIR" \
    -exportOptionsPlist "$EXPORT_PLIST" \
    -allowProvisioningUpdates
  IPA_PATH="$(find_exported_ipa)" || true
  if [[ -z "${IPA_PATH:-}" || ! -f "$IPA_PATH" ]]; then
    echo "ERROR: Export did not produce an .ipa under $EXPORT_DIR"
    exit 1
  fi
  echo "  [OK] IPA: $IPA_PATH"
fi

mkdir -p "$DIST_DIR"
STAMPED="$DIST_DIR/FinalEvolutionLabUnreal-1.0.0-5.ipa"
echo "==> Staging artifact (ditto)"
ditto "$IPA_PATH" "$STAMPED"
echo "  [OK] $STAMPED"

echo "==> App Store Connect authentication"
build_altool_auth

echo "==> xcrun altool — validate-app"
xcrun altool --validate-app -f "$STAMPED" "${ALTOOL_AUTH[@]}" --show-progress --verbose

if [[ "$VALIDATE_ONLY" == "1" ]]; then
  echo "==> FEL_VALIDATE_ONLY=1 — skipping upload."
  exit 0
fi

echo "==> xcrun altool — upload-app (TestFlight / App Store Connect)"
xcrun altool --upload-app -f "$STAMPED" "${ALTOOL_AUTH[@]}" --show-progress --verbose

echo ""
echo "========================================================="
echo " Upload request finished. Confirm in App Store Connect → TestFlight"
echo " (Processing can take several minutes before the build appears.)"
echo "========================================================="
