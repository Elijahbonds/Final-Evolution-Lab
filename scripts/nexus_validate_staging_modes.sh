#!/usr/bin/env bash
# Validate-only mesh gate for NEXUS staging simulators (mobile profile).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${ROOT}/build-full"
cd "$ROOT"

# All former staging simulators promoted to kProduction (2026-06-19 gameplay_tester).
STAGING_MODES=()

mapfile -t REGISTRY_STAGING_MODES < <(python3 - <<'PY'
import json
from pathlib import Path

registry_path = Path("backend/FEL_ModeManager.production.json")
registry = json.loads(registry_path.read_text())["mode_manager"]["mode_registry"]
for mode_id, info in sorted(registry.items()):
    if info.get("status") == "staging":
        print(mode_id)
PY
)

if [[ "${STAGING_MODES[*]}" != "${REGISTRY_STAGING_MODES[*]}" ]]; then
  echo "FAILED staging registry drift:" >&2
  echo "  script STAGING_MODES=(${STAGING_MODES[*]})" >&2
  echo "  registry staging=(${REGISTRY_STAGING_MODES[*]})" >&2
  exit 1
fi

if ((${#STAGING_MODES[@]} == 0)); then
  echo "==> nexus_validate_staging_modes PASS (0 modes — registry has no staging entries)"
  exit 0
fi

if [[ ! -x "${BUILD_DIR}/nexus_runtime" ]]; then
  cmake -S . -B "$BUILD_DIR" -DNEXUS_ENABLE_RENDERER=ON -DNEXUS_BUILD_RUNTIME=ON
  cmake --build "$BUILD_DIR" --target nexus_runtime
fi

export NEXUS_MESH_PROFILE=mobile

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
