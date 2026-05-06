#!/usr/bin/env bash
# =============================================================================
# fix_ios_descriptor_path.sh
# Diagnose "Failed to open descriptor file ... FinalEvolutionLab.uproject" on iOS.
#
# Root cause is almost always an incomplete .app (missing cookeddata / .pak), not
# display name vs .uproject branding. This script checks your staged or Binaries
# .app and prints next steps.
#
# Usage (from repo root):
#   ./infra/fix_ios_descriptor_path.sh
#   APP="/path/to/FinalEvolutionLab-IOS-Shipping.app" ./infra/fix_ios_descriptor_path.sh
#
# =============================================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJ="${UE_PROJECT:-$HOME/Developer/FinalEvolutionLab57}"

pick_app() {
  if [[ -n "${APP:-}" && -d "$APP" ]]; then
    echo "$APP"
    return
  fi
  local c
  c="$(find "$PROJ/Binaries/IOS" -maxdepth 1 -name '*.app' -type d 2>/dev/null | head -1)"
  if [[ -n "$c" ]]; then
    echo "$c"
    return
  fi
  c="$(find "$REPO_ROOT/artifacts/IOS_Shipping_Archive" -maxdepth 2 -name '*.app' -type d 2>/dev/null | head -1)"
  if [[ -n "$c" ]]; then
    echo "$c"
    return
  fi
  echo ""
}

echo ">>> UE project (override with UE_PROJECT=): $PROJ"
[[ -f "$PROJ/FinalEvolutionLab.uproject" ]] || echo "WARN: .uproject not found — set UE_PROJECT to your game folder."

APP_PATH="$(pick_app)"
if [[ -z "$APP_PATH" ]]; then
  echo "No .app found under Binaries/IOS or artifacts/IOS_Shipping_Archive."
  echo "Build first: UPROJECT=\"$PROJ/FinalEvolutionLab.uproject\" $REPO_ROOT/fel_ue5_ios_shipping_package.sh --shipping"
  exit 1
fi

echo ">>> Inspecting: $APP_PATH"
du -sh "$APP_PATH" 2>/dev/null || true

has_cooked=0
find "$APP_PATH" -maxdepth 3 \( -type d -name 'cookeddata' -o -name '*.pak' \) -print -quit 2>/dev/null | grep -q . && has_cooked=1 || true

has_uproj=0
find "$APP_PATH" -name '*.uproject' -print -quit 2>/dev/null | grep -q . && has_uproj=1 || true

if [[ "$has_cooked" -eq 1 ]]; then
  echo ">>> OK: cookeddata and/or .pak present."
else
  echo ">>> PROBLEM: No cookeddata/ or .pak under this .app — device will fail to open descriptor / content."
  echo "    Fix: run a full iOS cook+stage (see fel_ue5_ios_shipping_package.sh) and install the .app produced"
  echo "    AFTER the Xcode 'Copy Executable and Staged Data' phase (or use the script's promote step)."
fi

if [[ "$has_uproj" -eq 1 ]]; then
  find "$APP_PATH" -name '*.uproject' -print 2>/dev/null
else
  echo ">>> Note: no .uproject inside bundle (UE may still run if staged layout is correct)."
fi

echo ""
echo "Branding: CFBundleDisplayName can be 'Final Evolution AI Coach'; keep FinalEvolutionLab.uproject + module name as-is."
