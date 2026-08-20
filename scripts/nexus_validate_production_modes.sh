#!/usr/bin/env bash
# Validate-only triangle budget for all FEL production modes (mobile profile).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${ROOT}/build-validate"
cd "$ROOT"

if [[ -z "${CXX:-}" ]] && command -v g++ >/dev/null 2>&1; then
  export CC="${CC:-gcc}"
  export CXX="g++"
fi

if [[ ! -x "${BUILD_DIR}/nexus_mode_validator" ]]; then
  cmake -S . -B "$BUILD_DIR" \
    -DNEXUS_ENABLE_RENDERER=OFF \
    -DNEXUS_BUILD_RUNTIME=OFF \
    -DNEXUS_BUILD_TESTS=OFF \
    -DNEXUS_BUILD_AGENT_CLI=OFF \
    -DNEXUS_BUILD_MODE_VALIDATOR=ON
  cmake --build "$BUILD_DIR" --target nexus_mode_validator -j"$(sysctl -n hw.ncpu 2>/dev/null || nproc)"
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
  if ! "${BUILD_DIR}/nexus_mode_validator" --mode "${mode}"; then
    failed+=("${mode}")
  fi
done

if ((${#failed[@]} > 0)); then
  echo "FAILED modes: ${failed[*]}"
  exit 1
fi

echo "==> nexus_validate_production_modes PASS (${#PRODUCTION_MODES[@]} modes)"
