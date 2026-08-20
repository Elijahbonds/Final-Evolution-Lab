#!/usr/bin/env bash
# Validate-only triangle budget for all FEL production modes (mobile profile).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${ROOT}/build-validate"
VALIDATOR="${BUILD_DIR}/nexus_mode_validator"
cd "$ROOT"

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

export NEXUS_MESH_PROFILE=mobile

PRODUCTION_MODES=(
  basketball_h2h basketball_dunk basketball_3v3 court_carnival
  karate_h2h karate_endless
  baseball football soccer golf tennis volleyball
  gymnastics surfing skateboarding snowboarding brain_brawl
  who_scene_it
)

failed=()
for mode in "${PRODUCTION_MODES[@]}"; do
  echo ">> validate-only --mode ${mode}"
  if ! "$VALIDATOR" --mode "${mode}"; then
    failed+=("${mode}")
  fi
done

if ((${#failed[@]} > 0)); then
  echo "FAILED modes: ${failed[*]}"
  exit 1
fi

echo "==> nexus_validate_production_modes PASS (${#PRODUCTION_MODES[@]} modes)"
