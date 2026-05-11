#!/usr/bin/env bash
# Run UI tests that attach full-window screenshots for Arena grid + every gameplay mode.
# Requires Xcode + iOS Simulator (or device). Outputs appear in Xcode test results / CI artifacts.
#
# Usage:
#   ./scripts/capture_game_mode_screenshots.sh
#   DESTINATION='platform=iOS Simulator,name=iPhone 16 Pro' ./scripts/capture_game_mode_screenshots.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

SCHEME="${SCHEME:-FinalEvolutionLab}"
DESTINATION="${DESTINATION:-platform=iOS Simulator,name=iPhone 16,OS=latest}"

echo "== Game mode screenshots (UITest attachments) =="
echo "   Scheme:       $SCHEME"
echo "   Destination:  $DESTINATION"
echo "   Tests:        FinalEvolutionLabUITests/GameModeScreenshotUITests"
echo

cd "$ROOT"

xcodebuild \
  -scheme "$SCHEME" \
  -destination "$DESTINATION" \
  -only-testing:FinalEvolutionLabUITests/GameModeScreenshotUITests \
  test

echo
echo "Done. In Xcode: Report navigator → Tests → open attachments for PNGs."
echo "Or extract from xcresult: xcrun xcresulttool get --path <path>.xcresult ..."
