#!/usr/bin/env bash
# Create a Release .xcarchive for device / App Store Connect export.
#
# Prerequisites:
# - Xcode logged in: Xcode → Settings → Accounts (Apple ID + team access).
# - Apple Developer: App ID matching PRODUCT_BUNDLE_IDENTIFIER (currently
#   com.finalevolutionlab.app) under team 78L8GWA44F — create if missing.
# - FinalEvolutionLab/GoogleService-Info.plist present (copy from Firebase Console).
# - Enough disk space (DerivedData + SPM checkouts are large).
#
# Usage (from repo root):
#   chmod +x scripts/ios_archive.sh
#   ./scripts/ios_archive.sh
#
# Do NOT run plain `xcodebuild archive` from ~ — either cd to this repo first or pass
# -project "$PWD/FinalEvolutionLab.xcodeproj". You must pass -allowProvisioningUpdates
# unless profiles for com.finalevolutionlab.app already exist on this Mac.
#
# Optional overrides:
#   DEVELOPMENT_TEAM=XXXXXXXXXX ./scripts/ios_archive.sh
#   DERIVED_DATA="$PWD/build/DerivedData" ./scripts/ios_archive.sh

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

ARCHIVE_PATH="${ARCHIVE_PATH:-$ROOT/build/FinalEvolutionLab.xcarchive}"
DERIVED_DATA="${DERIVED_DATA:-$ROOT/build/DerivedData}"
SRC_PACKAGES="${SRC_PACKAGES:-$ROOT/build/SourcePackages}"
DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM:-78L8GWA44F}"

mkdir -p "$(dirname "$ARCHIVE_PATH")" "$DERIVED_DATA" "$SRC_PACKAGES"

echo "Archiving → $ARCHIVE_PATH"
echo "Team: $DEVELOPMENT_TEAM (override with DEVELOPMENT_TEAM=...)"

exec xcodebuild archive \
  -project "$ROOT/FinalEvolutionLab.xcodeproj" \
  -scheme FinalEvolutionLab \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE_PATH" \
  -derivedDataPath "$DERIVED_DATA" \
  -clonedSourcePackagesDirPath "$SRC_PACKAGES" \
  -allowProvisioningUpdates \
  DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM"
