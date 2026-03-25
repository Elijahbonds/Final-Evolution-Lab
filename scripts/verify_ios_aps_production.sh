#!/usr/bin/env bash
# Bonds Standard — verify Release/TestFlight entitlements use production APNs (aps-environment).
#
# Usage (repo root):
#   ./scripts/verify_ios_aps_production.sh
#
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REL="$ROOT/Source/FinalEvolutionLabRelease.entitlements"
DBG="$ROOT/Source/FinalEvolutionLab.entitlements"

if [[ ! -f "$REL" ]]; then
  echo "ERROR: Missing $REL"
  exit 1
fi

echo "==> Release entitlements (Archive / TestFlight)"
if grep -q "<string>production</string>" "$REL" && grep -q "aps-environment" "$REL"; then
  echo "  [OK] $REL — aps-environment production"
else
  echo "  [FAIL] Expected aps-environment production in $REL"
  exit 1
fi

echo "==> Debug entitlements (should be development for local pushes)"
if [[ -f "$DBG" ]]; then
  if grep -q "aps-environment" "$DBG"; then
    echo "  [INFO] $DBG — verify development vs production for your workflow"
    grep -A1 "aps-environment" "$DBG" || true
  fi
fi

echo "==> Gold Master archive"
echo "  Run: FEL_CONFIGURATION=Release ./scripts/ios_clean_build.sh"
echo "  Then: ./scripts/publish_to_testflight.sh (xcrun altool validate-app / upload-app)"
