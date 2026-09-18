#!/usr/bin/env bash
# NEXUS Engine 10-Phase Pass — Phase 1 build gate (headless + GPU matrix)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# shellcheck source=scripts/nexus_build_lock.sh
source "${ROOT}/scripts/nexus_build_lock.sh"
nexus_acquire_build_lock "${ROOT}"

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

reset_build_dir() {
  local build_dir="$1"
  if [[ "${NEXUS_REUSE_BUILD:-0}" != "1" ]]; then
    cmake -E rm -rf "${build_dir}"
  fi
}

echo "==> Phase 1: headless build (NEXUS_ENABLE_RENDERER=OFF)"
reset_build_dir build-headless
cmake -S . -B build-headless --fresh \
  -DNEXUS_ENABLE_RENDERER=OFF \
  -DNEXUS_BUILD_RUNTIME=OFF \
  -DNEXUS_BUILD_TESTS=ON \
  "${CMAKE_COMPILER_ARGS[@]}"
cmake --build build-headless -j"$(sysctl -n hw.ncpu 2>/dev/null || echo 4)"
ctest --test-dir build-headless --output-on-failure

echo "==> Phase 1: full renderer build (NEXUS_ENABLE_RENDERER=ON)"
reset_build_dir build-full
cmake -S . -B build-full --fresh \
  -DNEXUS_ENABLE_RENDERER=ON \
  -DNEXUS_BUILD_RUNTIME=ON \
  -DNEXUS_BUILD_TESTS=ON \
  "${CMAKE_COMPILER_ARGS[@]}"
cmake --build build-full -j"$(sysctl -n hw.ncpu 2>/dev/null || nproc)"
ctest --test-dir build-full --output-on-failure

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
