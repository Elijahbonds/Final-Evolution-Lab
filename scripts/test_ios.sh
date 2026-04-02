#!/bin/bash
# ═══════════════════════════════════════════════════════════════════
# Final Evolution Lab — iOS Test Runner
# Runs unit tests and UI tests on the iOS Simulator
# ═══════════════════════════════════════════════════════════════════

set -e

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
XCODE_PROJ="$PROJECT_ROOT/ios/FinalEvolutionLab.xcodeproj"
SCHEME="FinalEvolutionLab"
SIMULATOR="${1:-iPhone 16 Pro}"

echo "╔═══════════════════════════════════════════════════╗"
echo "║   Final Evolution Lab — iOS Tests                ║"
echo "╚═══════════════════════════════════════════════════╝"
echo ""
echo "  Simulator: $SIMULATOR"
echo ""

# ── Unit Tests ───────────────────────────────────────────────────
echo "▸ Running unit tests..."
xcodebuild test \
  -project "$XCODE_PROJ" \
  -scheme "$SCHEME" \
  -destination "platform=iOS Simulator,name=$SIMULATOR" \
  -only-testing FinalEvolutionLabTests \
  2>&1 | grep -E '(Test Suite|Test Case|Executed|FAIL|PASS)' || true

echo ""

# ── UI Tests ─────────────────────────────────────────────────────
echo "▸ Running UI tests..."
xcodebuild test \
  -project "$XCODE_PROJ" \
  -scheme "$SCHEME" \
  -destination "platform=iOS Simulator,name=$SIMULATOR" \
  -only-testing FinalEvolutionLabUITests \
  2>&1 | grep -E '(Test Suite|Test Case|Executed|FAIL|PASS)' || true

echo ""
echo "✓ Test run complete."
