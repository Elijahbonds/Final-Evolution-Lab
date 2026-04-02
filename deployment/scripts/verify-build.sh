#!/bin/bash
# =============================================================================
# Final Evolution Lab - Build Verification Script
# =============================================================================
# Verifies that a UE5 build is ready for Pixel Streaming deployment
#
# Usage:
#   ./verify-build.sh /path/to/build
#   ./verify-build.sh /opt/fel/current
# =============================================================================
set -euo pipefail

BUILD_DIR="${1:-/opt/fel/current}"
PASSED=0
FAILED=0
WARNED=0

check() {
  local desc="$1"
  local result="$2"
  if [ "$result" = "0" ]; then
    echo "  ✅ $desc"
    ((PASSED++))
  else
    echo "  ❌ $desc"
    ((FAILED++))
  fi
}

warn() {
  local desc="$1"
  echo "  ⚠️  $desc"
  ((WARNED++))
}

echo "================================================================"
echo "  FEL Build Verification"
echo "  Build directory: $BUILD_DIR"
echo "================================================================"

# Check build directory exists
check "Build directory exists" $(test -d "$BUILD_DIR" && echo 0 || echo 1)

# Check main executable
check "Main executable exists" $(test -f "$BUILD_DIR/FinalEvolutionLab.sh" && echo 0 || echo 1)

if [ -f "$BUILD_DIR/FinalEvolutionLab.sh" ]; then
  check "Main executable is executable" $(test -x "$BUILD_DIR/FinalEvolutionLab.sh" && echo 0 || echo 1)
fi

# Check launch script
check "Launch script exists" $(test -f "$BUILD_DIR/launch_pixel_streaming.sh" && echo 0 || echo 1)

# Check Engine directory
check "Engine directory exists" $(test -d "$BUILD_DIR/Engine" && echo 0 || echo 1)

# Check Pixel Streaming plugin
PS_PLUGIN=$(find "$BUILD_DIR" -name "PixelStreaming" -type d 2>/dev/null | head -1)
check "Pixel Streaming plugin present" $(test -n "$PS_PLUGIN" && echo 0 || echo 1)

# Check game content
CONTENT_DIR=$(find "$BUILD_DIR" -name "Content" -type d 2>/dev/null | head -1)
check "Game content directory exists" $(test -n "$CONTENT_DIR" && echo 0 || echo 1)

# Check for required config files
check "Engine config exists" $(find "$BUILD_DIR" -name "Engine.ini" 2>/dev/null | head -1 | xargs test -f 2>/dev/null && echo 0 || echo 1)

# Check binary
BINARY=$(find "$BUILD_DIR" -name "FinalEvolutionLab" -type f ! -name "*.sh" 2>/dev/null | head -1)
check "Game binary exists" $(test -n "$BINARY" && echo 0 || echo 1)

if [ -n "$BINARY" ]; then
  # Check if binary is the right architecture
  FILE_INFO=$(file "$BINARY" 2>/dev/null || echo "")
  check "Binary is x86_64" $(echo "$FILE_INFO" | grep -q 'x86-64' && echo 0 || echo 1)
  check "Binary is Linux ELF" $(echo "$FILE_INFO" | grep -q 'ELF' && echo 0 || echo 1)
fi

# Check disk space
BUILD_SIZE=$(du -sh "$BUILD_DIR" 2>/dev/null | awk '{print $1}')
FREE_SPACE=$(df -h "$BUILD_DIR" 2>/dev/null | tail -1 | awk '{print $4}')
echo ""
echo "  Build size:   $BUILD_SIZE"
echo "  Free space:   $FREE_SPACE"

# Warnings
if ! nvidia-smi &>/dev/null; then
  warn "NVIDIA GPU not detected - Pixel Streaming requires a GPU"
fi

if ! systemctl is-active nginx &>/dev/null; then
  warn "Nginx is not running"
fi

# Summary
echo ""
echo "================================================================"
echo "  Results: $PASSED passed, $FAILED failed, $WARNED warnings"
if [ $FAILED -eq 0 ]; then
  echo "  Status: ✅ BUILD VERIFIED"
else
  echo "  Status: ❌ BUILD VERIFICATION FAILED"
  exit 1
fi
echo "================================================================"
