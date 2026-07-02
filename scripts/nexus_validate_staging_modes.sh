#!/usr/bin/env bash
# Validate-only mesh gate for NEXUS staging simulators (mobile profile).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${ROOT}/build-full"
cd "$ROOT"

if [[ ! -x "${BUILD_DIR}/nexus_runtime" ]]; then
  cmake -S . -B "$BUILD_DIR" -DNEXUS_ENABLE_RENDERER=ON -DNEXUS_BUILD_RUNTIME=ON
  cmake --build "$BUILD_DIR" --target nexus_runtime
fi

export NEXUS_MESH_PROFILE=mobile

# All former staging simulators promoted to kProduction (2026-06-19 gameplay_tester).
STAGING_MODES=()

failed=()
for mode in "${STAGING_MODES[@]}"; do
  echo ">> validate-only --mode ${mode}"
  if ! "${BUILD_DIR}/nexus_runtime" --validate-only --mode "${mode}"; then
    failed+=("${mode}")
  fi
done

if ((${#failed[@]} > 0)); then
  echo "FAILED staging modes: ${failed[*]}"
  exit 1
fi

echo "==> nexus_validate_staging_modes PASS (${#STAGING_MODES[@]} modes — all promoted to production)"
