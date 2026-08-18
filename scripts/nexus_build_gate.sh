#!/usr/bin/env bash
# NEXUS Engine 10-Phase Pass — Phase 1 build gate (headless + GPU matrix)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ "$(uname -s)" == "Linux" ]]; then
  export CC="${CC:-gcc}"
  export CXX="${CXX:-g++}"
fi
REQUESTED_CC="$(command -v "${CC}" 2>/dev/null || printf '%s' "${CC}")"
REQUESTED_CXX="$(command -v "${CXX}" 2>/dev/null || printf '%s' "${CXX}")"

clear_stale_cmake_compiler_cache() {
  local build_dir="$1"
  if [[ ! -f "${build_dir}/CMakeCache.txt" && -d "${build_dir}/CMakeFiles" ]]; then
    echo "==> Clearing incomplete CMake configure state in ${build_dir}"
    rm -rf "${build_dir}/CMakeFiles"
    return
  fi
  if [[ ! -f "${build_dir}/CMakeCache.txt" ]]; then
    return
  fi
  local cache_content
  cache_content="$(<"${build_dir}/CMakeCache.txt")"
  if [[ "${cache_content}" == *"CMAKE_CXX_COMPILER:FILEPATH="* &&
        "${cache_content}" != *"CMAKE_CXX_COMPILER:FILEPATH=${REQUESTED_CXX}"* ]]; then
    echo "==> Clearing stale CMake compiler cache in ${build_dir} (requested ${REQUESTED_CXX})"
    rm -f "${build_dir}/CMakeCache.txt"
    rm -rf "${build_dir}/CMakeFiles"
  fi
}

echo "==> Phase 1: headless build (NEXUS_ENABLE_RENDERER=OFF)"
clear_stale_cmake_compiler_cache "build-headless"
cmake -S . -B build-headless \
  -DCMAKE_C_COMPILER="${REQUESTED_CC}" \
  -DCMAKE_CXX_COMPILER="${REQUESTED_CXX}" \
  -DNEXUS_ENABLE_RENDERER=OFF \
  -DNEXUS_BUILD_RUNTIME=OFF \
  -DNEXUS_BUILD_TESTS=ON
cmake --build build-headless -j"$(sysctl -n hw.ncpu 2>/dev/null || echo 4)"
ctest --test-dir build-headless --output-on-failure

echo "==> Phase 1: full renderer build (NEXUS_ENABLE_RENDERER=ON)"
clear_stale_cmake_compiler_cache "build-full"
cmake -S . -B build-full \
  -DCMAKE_C_COMPILER="${REQUESTED_CC}" \
  -DCMAKE_CXX_COMPILER="${REQUESTED_CXX}" \
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
