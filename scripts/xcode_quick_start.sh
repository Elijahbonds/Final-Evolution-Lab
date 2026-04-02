#!/bin/bash
# ═══════════════════════════════════════════════════════════════════
# Final Evolution Lab — Xcode Quick Start
# Run this on your Mac Mini M4 Pro to open and prepare the project
# ═══════════════════════════════════════════════════════════════════

set -e

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
XCODE_PROJ="$PROJECT_ROOT/ios/FinalEvolutionLab.xcodeproj"

echo "╔═══════════════════════════════════════════════════╗"
echo "║   Final Evolution Lab — Xcode Quick Start        ║"
echo "╚═══════════════════════════════════════════════════╝"
echo ""

# ── Check prerequisites ──────────────────────────────────────────
echo "▸ Checking prerequisites..."

if ! command -v xcodebuild &>/dev/null; then
    echo "✗ Xcode not found. Install from Mac App Store."
    echo "  Then run: xcode-select --install"
    exit 1
fi

XCODE_VERSION=$(xcodebuild -version | head -1)
echo "  ✓ $XCODE_VERSION"

if ! xcode-select -p &>/dev/null; then
    echo "  ▸ Installing Xcode Command Line Tools..."
    xcode-select --install
    echo "  ✓ CLT installation started (follow the GUI prompt)"
fi

# ── Check iOS SDK ────────────────────────────────────────────────
SDK_COUNT=$(xcodebuild -showsdks 2>/dev/null | grep -c iphoneos || true)
if [ "$SDK_COUNT" -gt 0 ]; then
    echo "  ✓ iOS SDK available"
else
    echo "  ✗ No iOS SDK found. Open Xcode and install iOS platform."
fi

# ── Check Apple Silicon ──────────────────────────────────────────
ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
    echo "  ✓ Apple Silicon ($ARCH) — native builds enabled"
else
    echo "  ⚠ Running on $ARCH — some features may differ"
fi

# ── Check certificates ───────────────────────────────────────────
if [ -f "$PROJECT_ROOT/certs/FinalEvolutionLab.pem" ]; then
    echo "  ✓ Certificate PEM files found in certs/"
else
    echo "  ⚠ No certificate files in certs/ — use Xcode auto-signing"
fi

# ── Accept Xcode license if needed ───────────────────────────────
if ! xcodebuild -checkFirstLaunchStatus 2>/dev/null; then
    echo "  ▸ Accepting Xcode license..."
    sudo xcodebuild -license accept 2>/dev/null || true
fi

echo ""
echo "▸ Project structure:"
echo "  Swift App:  ios/FinalEvolutionLab/  (50+ views, 40+ models)"
echo "  UE5 Game:   ios/FinalEvolutionLab_Unreal/"
echo "  Tests:      ios/FinalEvolutionLabTests/"
echo "  Certs:      certs/"
echo "  Videos:     ios/magic_reveal_videos/ (7 venue reveals)"
echo ""

# ── Open in Xcode ────────────────────────────────────────────────
if [ -d "$XCODE_PROJ" ]; then
    echo "▸ Opening FinalEvolutionLab.xcodeproj in Xcode..."
    open "$XCODE_PROJ"
    echo ""
    echo "═══════════════════════════════════════════════════"
    echo "  Next steps in Xcode:"
    echo "  1. Select your Team (Signing & Capabilities)"
    echo "  2. Select destination (iPhone or My Mac)"
    echo "  3. Press ⌘R to build and run"
    echo "═══════════════════════════════════════════════════"
else
    echo "✗ Xcode project not found at: $XCODE_PROJ"
    exit 1
fi
