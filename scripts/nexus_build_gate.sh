#!/usr/bin/env bash
# NEXUS Engine 10-Phase Pass — Phase 1 build gate (headless + GPU matrix)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

detect_jobs() {
  if command -v sysctl >/dev/null 2>&1; then
    sysctl -n hw.ncpu 2>/dev/null && return
  fi
  if command -v nproc >/dev/null 2>&1; then
    nproc && return
  fi
  echo 4
}

if [[ -z "${CC:-}" ]] && [[ "$(uname -s)" == "Linux" ]] && command -v gcc >/dev/null 2>&1; then
  export CC=gcc
fi
if [[ -z "${CXX:-}" ]] && [[ "$(uname -s)" == "Linux" ]] && command -v g++ >/dev/null 2>&1; then
  export CXX=g++
fi

HEADLESS_DIR="${NEXUS_HEADLESS_DIR:-build-headless}"
FULL_DIR="${NEXUS_FULL_DIR:-build-full}"
BUILD_JOBS="${NEXUS_BUILD_JOBS:-$(detect_jobs)}"

echo "==> Phase 1: headless build (NEXUS_ENABLE_RENDERER=OFF)"
cmake -S . -B "${HEADLESS_DIR}" \
  -DNEXUS_ENABLE_RENDERER=OFF \
  -DNEXUS_BUILD_RUNTIME=OFF \
  -DNEXUS_BUILD_TESTS=ON
cmake --build "${HEADLESS_DIR}" -j"${BUILD_JOBS}"
ctest --test-dir "${HEADLESS_DIR}" --output-on-failure

echo "==> Phase 1: full renderer build (NEXUS_ENABLE_RENDERER=ON)"
cmake -S . -B "${FULL_DIR}" \
  -DNEXUS_ENABLE_RENDERER=ON \
  -DNEXUS_BUILD_RUNTIME=ON \
  -DNEXUS_BUILD_TESTS=ON
cmake --build "${FULL_DIR}" -j"${BUILD_JOBS}"
ctest --test-dir "${FULL_DIR}" --output-on-failure

# Production mode mesh budget (mobile profile). Skips when NEXUS_SKIP_PRODUCTION_MODE_VALIDATE=1.
if [[ "${NEXUS_SKIP_PRODUCTION_MODE_VALIDATE:-}" != "1" ]]; then
  echo "==> Phase 1b: production mode validate-only (mobile)"
  "${ROOT}/scripts/nexus_validate_production_modes.sh"
else
  echo "==> Phase 1b: skipped (NEXUS_SKIP_PRODUCTION_MODE_VALIDATE=1)"
fi

if [[ "${NEXUS_SKIP_STAGING_MODE_VALIDATE:-}" != "1" ]]; then
  echo "==> Phase 1c: staging mode validate-only (mobile)"
  "${ROOT}/scripts/nexus_validate_staging_modes.sh"
else
  echo "==> Phase 1c: skipped (NEXUS_SKIP_STAGING_MODE_VALIDATE=1)"
fi

echo "==> nexus_build_gate PASS"
