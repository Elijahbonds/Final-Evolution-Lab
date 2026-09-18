#!/usr/bin/env bash
# Headless gameplay session smoke — Phase 3 bridge/receipt verification
# Usage: ./scripts/smoke_gameplay_session.sh [--skip-build]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${ROOT}/scripts/lib/nexus_build_lock.sh"
BUILD_DIR="${NEXUS_HEADLESS_BUILD_DIR:-${ROOT}/build-headless}"
SKIP_BUILD=0
RECEIPT_DIR="${HOME}/.fel/pending_receipts"

if [[ -z "${CXX:-}" ]] && command -v g++ >/dev/null 2>&1; then
  export CXX=g++
fi
if [[ -z "${CC:-}" ]] && command -v gcc >/dev/null 2>&1; then
  export CC=gcc
fi
CMAKE_COMPILER_ARGS=()
if [[ -n "${CXX:-}" ]]; then
  CMAKE_COMPILER_ARGS+=("-DCMAKE_CXX_COMPILER=${CXX}")
fi

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

nexus_acquire_build_lock
cd "$ROOT"

if [[ "$SKIP_BUILD" -eq 0 ]]; then
  echo "==> Configure headless build"
  if [[ "${NEXUS_REUSE_BUILD:-0}" != "1" ]]; then
    cmake -E rm -rf "$BUILD_DIR"
  fi
  cmake -S . -B "$BUILD_DIR" --fresh \
    -DNEXUS_ENABLE_RENDERER=OFF \
    "${CMAKE_COMPILER_ARGS[@]}"
  echo "==> Build"
  cmake --build "$BUILD_DIR" -j"$(sysctl -n hw.ncpu 2>/dev/null || nproc)"
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
