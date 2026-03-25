#!/usr/bin/env bash
# "Phone ready": Unity batch export → Xcode workspace → build/install to a connected device.
# Prerequisites: Unity iOS module, Apple dev signing in Xcode, device trusted, FEL_APPLE_TEAM_ID for post-process.
#
#   export UNITY_EDITOR="/Applications/Unity/Hub/Editor/2022.3.XXf1/Unity.app/Contents/MacOS/Unity"
#   export FEL_UNITY_PROJECT="/path/to/UnityProject"
#   export FEL_APPLE_TEAM_ID="XXXXXXXXXX"
#   export IOS_DEVICE_NAME="Elijahs iPhone"   # optional; else first device
#   ./scripts/fel_claw_device_build.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

: "${UNITY_EDITOR:?UNITY_EDITOR}"
: "${FEL_UNITY_PROJECT:?FEL_UNITY_PROJECT}"

export FEL_IOS_OUT="${FEL_IOS_OUT:-$REPO_ROOT/UnityExport/iOS}"
export FEL_APPLE_TEAM_ID="${FEL_APPLE_TEAM_ID:-}"

echo "== 1) Unity ExportIOS (FELBuildScript.ExportIOS)"
"${UNITY_EDITOR}" -batchmode -nographics -quit \
  -projectPath "$FEL_UNITY_PROJECT" \
  -executeMethod FELBuildScript.ExportIOS

OUT="$FEL_IOS_OUT"
WS=$(find "$OUT" -maxdepth 3 -name "*.xcworkspace" 2>/dev/null | head -1)
PROJ=$(find "$OUT" -maxdepth 3 -name "*.xcodeproj" 2>/dev/null | head -1)

if [[ -n "${WS:-}" ]]; then
  echo "== 2) Opening workspace: $WS"
  open "$WS"
fi

if [[ -z "${PROJ:-}" ]]; then
  echo "No xcodeproj under $OUT — fix Unity export."
  exit 1
fi

echo "== 3) xcodebuild to physical device (requires signing)"
DEST=""
if command -v xcrun >/dev/null; then
  if [[ -n "${IOS_DEVICE_NAME:-}" ]]; then
    UDID=$(xcrun xctrace list devices 2>/dev/null | grep "$IOS_DEVICE_NAME" | head -1 | sed -n 's/.*(\([A-F0-9-]*\)).*/\1/p' || true)
    if [[ -n "${UDID:-}" ]]; then
      DEST="id=$UDID"
    fi
  fi
fi

if [[ -z "${DEST:-}" ]]; then
  echo "Set IOS_DEVICE_NAME to your device name, or build from Xcode (⌘R) after opening workspace."
  exit 0
fi

xcodebuild -project "$PROJ" -scheme Unity-iPhone \
  -destination "platform=iOS,$DEST" \
  build 2>&1 | tail -20

echo "Done. If signing failed, open the workspace in Xcode and select your Team."
