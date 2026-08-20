#!/usr/bin/env bash
# NEXUS Engine 10-Phase Pass — Phase 1 build gate (headless + GPU matrix)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ -z "${CXX:-}" ]] && command -v g++ >/dev/null 2>&1; then
  export CC="${CC:-gcc}"
  export CXX="g++"
fi

REQUESTED_CXX="$(command -v "${CXX:-c++}" 2>/dev/null || true)"
if [[ -z "${REQUESTED_CXX}" ]]; then
  echo "error: requested C++ compiler '${CXX:-c++}' was not found" >&2
  exit 1
fi

configure_build_dir() {
  local build_dir="$1"
  shift
  local cache_file="${build_dir}/CMakeCache.txt"
  if [[ -f "${cache_file}" ]]; then
    local cached_cxx=""
    local cache_key
    local cache_value
    while IFS='=' read -r cache_key cache_value; do
      if [[ "${cache_key}" == CMAKE_CXX_COMPILER:* ]]; then
        cached_cxx="${cache_value}"
        break
      fi
    done <"${cache_file}"
    if [[ -n "${cached_cxx}" && "${cached_cxx}" != "${REQUESTED_CXX}" ]]; then
      echo "==> Recreating ${build_dir}; cached compiler ${cached_cxx} differs from ${REQUESTED_CXX}"
      rm -rf "${build_dir}"
    fi
  fi
  cmake -S . -B "${build_dir}" -DCMAKE_CXX_COMPILER="${REQUESTED_CXX}" "$@"
}

echo "==> Phase 1: headless build (NEXUS_ENABLE_RENDERER=OFF)"
configure_build_dir build-headless \
  -DNEXUS_ENABLE_RENDERER=OFF \
  -DNEXUS_BUILD_RUNTIME=OFF \
  -DNEXUS_BUILD_TESTS=ON
cmake --build build-headless -j"$(sysctl -n hw.ncpu 2>/dev/null || echo 4)"
ctest --test-dir build-headless --output-on-failure

echo "==> Phase 1: full renderer build (NEXUS_ENABLE_RENDERER=ON)"
configure_build_dir build-full \
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
