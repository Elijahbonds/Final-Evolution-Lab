#!/usr/bin/env bash
# Final Evolution — Unity iOS export (FELIOSBuilder) + optional xcodebuild + bundle id check.
#
#   export UNITY_EDITOR="/Applications/Unity/Hub/Editor/2022.3.XXf1/Unity.app/Contents/MacOS/Unity"
#   export FEL_UNITY_PROJECT="/path/to/UnityProject"
#   ./scripts/fel_pipeline_unity_ios.sh
#
# Optional: FEL_IOS_OUT (default: repo/UnityExport/iOS), FEL_BUILD_METHOD (default: FELIOSBuilder.BuildIOS),
#           FEL_EXPECTED_BUNDLE_ID (default: Config/FEL_IOS_BUNDLE_ID.txt in this repo).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

: "${UNITY_EDITOR:?Set UNITY_EDITOR to Unity.app/Contents/MacOS/Unity}"
: "${FEL_UNITY_PROJECT:?Set FEL_UNITY_PROJECT to Unity project root}"

OUT="${FEL_IOS_OUT:-$REPO_ROOT/UnityExport/iOS}"
export FEL_IOS_OUT="$OUT"

METHOD="${FEL_BUILD_METHOD:-FELIOSBuilder.BuildIOS}"

BUNDLE_FILE="$REPO_ROOT/Config/FEL_IOS_BUNDLE_ID.txt"
if [[ -z "${FEL_EXPECTED_BUNDLE_ID:-}" ]] && [[ -f "$BUNDLE_FILE" ]]; then
  FEL_EXPECTED_BUNDLE_ID="$(tr -d ' \t\n\r' < "$BUNDLE_FILE")"
fi
: "${FEL_EXPECTED_BUNDLE_ID:?Set FEL_EXPECTED_BUNDLE_ID or add Config/FEL_IOS_BUNDLE_ID.txt}"

echo "== Unity batch iOS export → $OUT (executeMethod $METHOD)"
mkdir -p "$OUT"

"${UNITY_EDITOR}" \
  -batchmode -nographics -quit \
  -projectPath "$FEL_UNITY_PROJECT" \
  -executeMethod "$METHOD"

echo "== Xcode build (optional, unsigned smoke)"
if [[ -d "$OUT" ]]; then
  PROJ=$(find "$OUT" -maxdepth 3 -name "*.xcodeproj" 2>/dev/null | head -1)
  if [[ -n "${PROJ:-}" ]]; then
    xcodebuild -project "$PROJ" -scheme Unity-iPhone -sdk iphoneos -configuration Release CODE_SIGNING_ALLOWED=NO -quiet || true
  fi
fi

echo "== Bundle id check"
if command -v plutil >/dev/null && [[ -f "$OUT/Info.plist" ]]; then
  BID=$(plutil -extract CFBundleIdentifier raw -o - "$OUT/Info.plist" 2>/dev/null || echo "")
  echo "Exported CFBundleIdentifier: $BID"
  if [[ "$BID" == "$FEL_EXPECTED_BUNDLE_ID" ]]; then
    echo "OK: matches FEL_EXPECTED_BUNDLE_ID / Config/FEL_IOS_BUNDLE_ID.txt"
  else
    echo "WARN: mismatch (expected $FEL_EXPECTED_BUNDLE_ID). Run FEL/Sync iOS Bundle Identifier in Unity Editor."
  fi
fi

echo "Done."
