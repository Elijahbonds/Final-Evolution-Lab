#!/usr/bin/env bash
# Headless gameplay session smoke — Phase 3 bridge/receipt verification
# Usage: ./scripts/smoke_gameplay_session.sh [--skip-build]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${ROOT}/build-headless"
SKIP_BUILD=0
RECEIPT_DIR="${HOME}/.fel/pending_receipts"

for arg in "$@"; do
  case "$arg" in
    --skip-build) SKIP_BUILD=1 ;;
    -h|--help)
      echo "Usage: $0 [--skip-build]"
      echo "  Runs nexus_gameplay_test and prints a sample receipt path under ~/.fel/pending_receipts/"
      exit 0
      ;;
  esac
done

cd "$ROOT"

if [[ "$SKIP_BUILD" -eq 0 ]]; then
  echo "==> Configure headless build"
  cmake -S . -B "$BUILD_DIR" -DNEXUS_ENABLE_RENDERER=OFF -DNEXUS_BUILD_RUNTIME=OFF -DNEXUS_BUILD_TESTS=ON
  echo "==> Build"
  cmake --build "$BUILD_DIR" -j"$(sysctl -n hw.ncpu 2>/dev/null || nproc)"
elif [[ ! -x "${BUILD_DIR}/nexus_gameplay_test" ]]; then
  echo "==> Headless build missing; building C++ gameplay smoke target"
  cmake -S . -B "$BUILD_DIR" -DNEXUS_ENABLE_RENDERER=OFF -DNEXUS_BUILD_RUNTIME=OFF -DNEXUS_BUILD_TESTS=ON
  cmake --build "$BUILD_DIR" --target nexus_gameplay_test -j"$(sysctl -n hw.ncpu 2>/dev/null || nproc)"
fi

echo "==> ctest (nexus_gameplay_test)"
ctest --test-dir "$BUILD_DIR" -R nexus_gameplay_test --output-on-failure

echo "==> Receipt queue directory: ${RECEIPT_DIR}"
mkdir -p "$RECEIPT_DIR"
SAMPLE="$(find "$RECEIPT_DIR" -maxdepth 1 -name '*.json' -type f 2>/dev/null | head -n 1 || true)"
if [[ -n "$SAMPLE" ]]; then
  echo "    sample receipt: ${SAMPLE}"
else
  echo "    (no receipt files yet — run a session end + flush from iOS or runtime to populate)"
fi

echo "==> smoke_gameplay_session PASS"
