#!/usr/bin/env bash
# NEXUS Engine 10-Phase Pass — Phase 1 build gate (headless + GPU matrix)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ -z "${CC:-}" ]] && command -v gcc >/dev/null 2>&1; then
  export CC="$(command -v gcc)"
fi
if [[ -z "${CXX:-}" ]] && command -v g++ >/dev/null 2>&1; then
  export CXX="$(command -v g++)"
fi

CMAKE_COMPILER_ARGS=()
if [[ -n "${CC:-}" ]]; then
  CMAKE_COMPILER_ARGS+=("-DCMAKE_C_COMPILER=${CC}")
fi
if [[ -n "${CXX:-}" ]]; then
  CMAKE_COMPILER_ARGS+=("-DCMAKE_CXX_COMPILER=${CXX}")
fi

canonical_compiler_path() {
  command -v "$1" 2>/dev/null || printf '%s' "$1"
}

cached_cxx_compiler() {
  local cache_file="$1/CMakeCache.txt"
  local line
  [[ -f "${cache_file}" ]] || return 0
  while IFS= read -r line; do
    case "${line}" in
      CMAKE_CXX_COMPILER:*=*)
        printf '%s' "${line#*=}"
        return 0
        ;;
    esac
  done <"${cache_file}"
}

reset_build_dir_if_compiler_changed() {
  local build_dir="$1"
  local expected_cxx="${CXX:-}"
  [[ -n "${expected_cxx}" ]] || return 0
  local cached_cxx
  cached_cxx="$(cached_cxx_compiler "${build_dir}")"
  [[ -n "${cached_cxx}" ]] || return 0

  if [[ "$(canonical_compiler_path "${cached_cxx}")" != "$(canonical_compiler_path "${expected_cxx}")" ]]; then
    echo "==> Resetting ${build_dir} (cached CXX=${cached_cxx}, requested CXX=${expected_cxx})"
    rm -rf "${build_dir}"
  fi
}

echo "==> Phase 1: headless build (NEXUS_ENABLE_RENDERER=OFF)"
reset_build_dir_if_compiler_changed build-headless
cmake -S . -B build-headless \
  "${CMAKE_COMPILER_ARGS[@]}" \
  -DNEXUS_ENABLE_RENDERER=OFF \
  -DNEXUS_BUILD_RUNTIME=OFF \
  -DNEXUS_BUILD_TESTS=ON
cmake --build build-headless -j"$(sysctl -n hw.ncpu 2>/dev/null || echo 4)"
ctest --test-dir build-headless --output-on-failure

echo "==> Phase 1: full renderer build (NEXUS_ENABLE_RENDERER=ON)"
reset_build_dir_if_compiler_changed build-full
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
