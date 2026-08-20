#!/usr/bin/env bash
# Validate-only mesh gate for NEXUS staging simulators (mobile profile).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${ROOT}/build-validate"
VALIDATOR="${BUILD_DIR}/nexus_mode_validator"
cd "$ROOT"

export NEXUS_MESH_PROFILE=mobile

# All former staging simulators promoted to kProduction (2026-06-19 gameplay_tester).
STAGING_MODES=()

if ((${#STAGING_MODES[@]} > 0)); then
  if [[ -z "${CXX:-}" ]] && command -v g++ >/dev/null 2>&1; then
    export CC="${CC:-gcc}"
    export CXX="g++"
  fi

  if [[ ! -x "$VALIDATOR" ]]; then
    cmake -S . -B "$BUILD_DIR" \
      -DCMAKE_C_COMPILER="${CC:-cc}" \
      -DCMAKE_CXX_COMPILER="${CXX:-c++}" \
      -DNEXUS_ENABLE_RENDERER=OFF \
      -DNEXUS_ENABLE_METAL_RENDERER=ON \
      -DNEXUS_BUILD_RUNTIME=OFF \
      -DNEXUS_BUILD_TESTS=OFF
    cmake --build "$BUILD_DIR" --target nexus_mode_validator
  fi
fi

failed=()
for mode in "${STAGING_MODES[@]}"; do
  echo ">> validate-only --mode ${mode}"
  if ! "$VALIDATOR" --mode "${mode}"; then
    failed+=("${mode}")
  fi
done

if ((${#failed[@]} > 0)); then
  echo "FAILED staging modes: ${failed[*]}"
  exit 1
fi

echo "==> nexus_validate_staging_modes PASS (${#STAGING_MODES[@]} modes — all promoted to production)"
