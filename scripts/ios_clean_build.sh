#!/usr/bin/env bash
# Gold Master (Build 6 / Alpha 1) — local Xcode + TestFlight prep
# - Preflight: MARKETING_VERSION 1.0.0 + CURRENT_PROJECT_VERSION 6
# - Purges DerivedData and optional local tooling clutter
# - xcodebuild clean + archive: generic iOS, Automatic signing, Release for Archive
#
# Usage (repo root):
#   ./scripts/ios_clean_build.sh
# With team (recommended for Distribution):
#   DEVELOPMENT_TEAM=XXXXXXXXXX ./scripts/ios_clean_build.sh
# Defaults to team in project.pbxproj when unset (Final Evolution LLC).
# Clean only (no archive):
#   FEL_ARCHIVE=0 ./scripts/ios_clean_build.sh
# Debug clean only:
#   FEL_CONFIGURATION=Debug FEL_ARCHIVE=0 ./scripts/ios_clean_build.sh
#
# Archive always uses Release unless FEL_ALLOW_NON_RELEASE_ARCHIVE=1 (not recommended for TestFlight).
#
# Entitlements: aps-environment production — Source/FinalEvolutionLab.entitlements (Debug) and
#               Source/FinalEvolutionLabRelease.entitlements (Release / Archive) for TestFlight signing parity.
# UIBackgroundModes: remote-notification via Config/FELBackgroundModesInfo.plist (merged Info.plist).
#
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PROJECT="FinalEvolutionLabUnreal.xcodeproj"
SCHEME="FinalEvolutionLabUnreal"
PBX="$ROOT/$PROJECT/project.pbxproj"
CONFIG="${FEL_CONFIGURATION:-Release}"
ARCHIVE_PATH="${FEL_ARCHIVE_PATH:-$ROOT/build/FinalEvolutionLabUnreal.xcarchive}"
DO_ARCHIVE="${FEL_ARCHIVE:-1}"
# Final Evolution LLC — match project.pbxproj DEVELOPMENT_TEAM for Release; override via env for CI.
DEFAULT_TEAM_ID="78L8GWA44F"
SIGNING_TEAM="${DEVELOPMENT_TEAM:-${FEL_DEVELOPMENT_TEAM:-$DEFAULT_TEAM_ID}}"

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
  echo "  [OK] Gold Master version preflight: 1.0.0 (6)"
}

echo "========================================================="
echo " Final Evolution Lab — iOS clean + archive (Build 6 / Alpha 1 / 1.0.0)"
echo "========================================================="

echo "==> Gold Master version check"
verify_gold_master_versions

if [[ "$DO_ARCHIVE" == "1" ]]; then
  if [[ "${FEL_ALLOW_NON_RELEASE_ARCHIVE:-0}" != "1" ]]; then
    CONFIG=Release
    echo "==> Archive: locked to -configuration Release (TestFlight / Gold Master Build 6)"
  elif [[ "$CONFIG" != "Release" ]]; then
    echo "==> WARNING: archiving with non-Release configuration ($CONFIG) — not recommended for TestFlight"
  fi
fi

echo "==> Removing optional local tooling clutter (if present)"
rm -rf "$ROOT/.fel-local-tooling" 2>/dev/null || true

echo "==> Purging DerivedData for FinalEvolutionLabUnreal"
purge_derived_data() {
  local d
  shopt -s nullglob
  for d in "${HOME}/Library/Developer/Xcode/DerivedData"/FinalEvolutionLabUnreal-*; do
    [[ -d "$d" ]] || continue
    chmod -R u+w "$d" 2>/dev/null || true
    if ! rm -rf "$d" 2>/dev/null; then
      sleep 1
      chmod -R u+w "$d" 2>/dev/null || true
      if ! rm -rf "$d" 2>/dev/null; then
        echo "  [WARN] Could not fully remove $d (close Xcode or Simulator and delete manually). Continuing."
      fi
    fi
  done
  shopt -u nullglob
}
purge_derived_data

echo "==> Removing previous local archive (optional fresh tree)"
rm -rf "$ROOT/build" 2>/dev/null || true
mkdir -p "$ROOT/build"

echo "==> xcodebuild clean — $CONFIG — generic iOS (CODE_SIGN_STYLE=Automatic, DEVELOPMENT_TEAM=$SIGNING_TEAM)"
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIG" \
  -destination 'generic/platform=iOS' \
  clean \
  CODE_SIGN_STYLE=Automatic \
  DEVELOPMENT_TEAM="$SIGNING_TEAM"

if [[ "$DO_ARCHIVE" != "1" ]]; then
  echo "==> FEL_ARCHIVE=0 — skipping archive. Next: open Xcode → Product → Archive (Release)."
  exit 0
fi

echo "==> xcodebuild archive — configuration Release / generic iOS / Automatic signing"
echo "    Archive output: $ARCHIVE_PATH"
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE_PATH" \
  archive \
  CODE_SIGN_STYLE=Automatic \
  DEVELOPMENT_TEAM="$SIGNING_TEAM"

echo ""
echo "==> OK — .xcarchive ready for Organizer:"
echo "    $ARCHIVE_PATH"
echo "    Open Xcode → Window → Organizer → Distribute App → TestFlight"
echo "    Release entitlements: aps-environment production (TestFlight / App Store)"
echo ""
echo "    If archive fails: enable Push Notifications for App ID com.finalevolution.FinalEvoAPP"
echo "    in developer.apple.com, then Xcode → Signing & Capabilities → refresh profiles."
echo "========================================================="
