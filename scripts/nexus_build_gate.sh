#!/usr/bin/env bash
# NEXUS Engine 10-Phase Pass — Phase 1 build gate (headless + GPU matrix)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ -z "${CXX:-}" ]] && command -v g++ >/dev/null 2>&1; then
  export CXX="$(command -v g++)"
fi

CMAKE_COMPILER_ARGS=()
if [[ -n "${CXX:-}" ]]; then
  CMAKE_COMPILER_ARGS+=("-DCMAKE_CXX_COMPILER=${CXX}")
fi

reset_stale_compiler_cache() {
  local build_dir="$1"
  local cache="${build_dir}/CMakeCache.txt"
  if [[ -z "${CXX:-}" || ! -f "${cache}" ]]; then
    return
  fi
  local cached_compiler
  cached_compiler="$(awk -F= '/^CMAKE_CXX_COMPILER:FILEPATH=/ {print $2}' "${cache}" || true)"
  if [[ -n "${cached_compiler}" && "${cached_compiler}" != "${CXX}" ]]; then
    echo "==> Resetting stale CMake compiler cache (${cached_compiler} -> ${CXX})"
    rm -f "${cache}"
    rm -rf "${build_dir}/CMakeFiles"
  fi
}

echo "==> Phase 1: headless build (NEXUS_ENABLE_RENDERER=OFF)"
reset_stale_compiler_cache build-headless
cmake -S . -B build-headless \
  "${CMAKE_COMPILER_ARGS[@]}" \
  -DNEXUS_ENABLE_RENDERER=OFF \
  -DNEXUS_BUILD_RUNTIME=OFF \
  -DNEXUS_BUILD_TESTS=ON
cmake --build build-headless -j"$(sysctl -n hw.ncpu 2>/dev/null || echo 4)"
ctest --test-dir build-headless --output-on-failure

echo "==> Phase 1: full renderer build (NEXUS_ENABLE_RENDERER=ON)"
reset_stale_compiler_cache build-full
cmake -S . -B build-full \
  "${CMAKE_COMPILER_ARGS[@]}" \
  -DNEXUS_ENABLE_RENDERER=ON \
  -DNEXUS_BUILD_RUNTIME=ON \
  -DNEXUS_BUILD_TESTS=ON
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
