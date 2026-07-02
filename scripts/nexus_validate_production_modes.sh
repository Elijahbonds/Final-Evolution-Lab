#!/usr/bin/env bash
# Validate-only triangle budget for all FEL production modes (mobile profile).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${BUILD_DIR:-${ROOT}/build-full}"
cd "$ROOT"

if [[ ! -x "${BUILD_DIR}/nexus_runtime" ]]; then
  cmake -S . -B "$BUILD_DIR" -DNEXUS_ENABLE_RENDERER=ON -DNEXUS_BUILD_RUNTIME=ON
  cmake --build "$BUILD_DIR" --target nexus_runtime
fi

export NEXUS_MESH_PROFILE=mobile

mapfile -t PRODUCTION_MODES < <(python3 - <<'PY'
from pathlib import Path
import re
import sys

header = Path("app/gameplay/include/nexus/gameplay/arena_mode_registry.h")
source = header.read_text()
match = re.search(r"kProductionModeIds\[\]\s*=\s*\{(.*?)\};", source, flags=re.DOTALL)
if not match:
    print(f"Unable to parse kProductionModeIds from {header}", file=sys.stderr)
    raise SystemExit(1)

for mode_id in re.findall(r'"([^"]+)"', match.group(1)):
    print(mode_id)
PY
)

if ((${#PRODUCTION_MODES[@]} == 0)); then
  echo "No production modes parsed from arena_mode_registry.h"
  exit 1
fi

failed=()
for mode in "${PRODUCTION_MODES[@]}"; do
  echo ">> validate-only --mode ${mode}"
  if ! "${BUILD_DIR}/nexus_runtime" --validate-only --mode "${mode}"; then
    failed+=("${mode}")
  fi
done

if ((${#failed[@]} > 0)); then
  echo "FAILED modes: ${failed[*]}"
  exit 1
fi

echo "==> nexus_validate_production_modes PASS (${#PRODUCTION_MODES[@]} modes)"
