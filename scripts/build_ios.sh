#!/bin/bash
# ═══════════════════════════════════════════════════════════════════
# Final Evolution Lab — iOS Build Script
# Builds the app from command line (useful for CI/CD or automation)
# ═══════════════════════════════════════════════════════════════════

set -e

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
XCODE_PROJ="$PROJECT_ROOT/ios/FinalEvolutionLab.xcodeproj"
SCHEME="FinalEvolutionLab"
CONFIG="${1:-Debug}"  # Debug or Release
DESTINATION="${2:-generic/platform=iOS}"
BUILD_DIR="$PROJECT_ROOT/Builds/iOS"

echo "╔═══════════════════════════════════════════════════╗"
echo "║   Final Evolution Lab — iOS Build                ║"
echo "╚═══════════════════════════════════════════════════╝"
echo ""
echo "  Configuration: $CONFIG"
echo "  Destination:   $DESTINATION"
echo "  Output:        $BUILD_DIR"
echo ""

mkdir -p "$BUILD_DIR"

# ── Build ────────────────────────────────────────────────────────
echo "▸ Building $SCHEME ($CONFIG)..."

xcodebuild \
  -project "$XCODE_PROJ" \
  -scheme "$SCHEME" \
  -destination "$DESTINATION" \
  -configuration "$CONFIG" \
  -derivedDataPath "$BUILD_DIR/DerivedData" \
  build 2>&1 | tail -20

BUILD_EXIT=$?

if [ $BUILD_EXIT -eq 0 ]; then
    echo ""
    echo "✓ Build succeeded!"
    echo ""
    echo "  Build artifacts: $BUILD_DIR/DerivedData/"
else
    echo ""
    echo "✗ Build failed (exit code: $BUILD_EXIT)"
    echo "  Run 'xcodebuild ... | xcpretty' for better output"
    exit $BUILD_EXIT
fi

# ── Optional: Archive ────────────────────────────────────────────
if [ "$CONFIG" = "Release" ] && [ "$3" = "--archive" ]; then
    echo ""
    echo "▸ Archiving for distribution..."
    
    ARCHIVE_PATH="$BUILD_DIR/$SCHEME.xcarchive"
    
    xcodebuild archive \
      -project "$XCODE_PROJ" \
      -scheme "$SCHEME" \
      -destination 'generic/platform=iOS' \
      -configuration Release \
      -archivePath "$ARCHIVE_PATH" 2>&1 | tail -10
    
    if [ $? -eq 0 ]; then
        echo "✓ Archive created: $ARCHIVE_PATH"
        echo ""
        echo "  To export IPA:"
        echo "  xcodebuild -exportArchive \\"
        echo "    -archivePath $ARCHIVE_PATH \\"
        echo "    -exportOptionsPlist ios/ExportOptions.plist \\"
        echo "    -exportPath $BUILD_DIR/IPA/"
    fi
fi
