#!/usr/bin/env bash
# Phase 3 — validate NEXUS_MESH_PROFILE=mobile resolves for all environment assets.
# Usage: ./scripts/nexus_mobile_mesh_gate.sh [--warn-only]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${ROOT}/build-full"
WARN_ONLY=0

for arg in "$@"; do
  case "$arg" in
    --warn-only) WARN_ONLY=1 ;;
    -h|--help)
      echo "Usage: $0 [--warn-only]"
      exit 0
      ;;
    *)
      echo "error: unknown argument: $arg" >&2
      echo "Usage: $0 [--warn-only]" >&2
      exit 2
      ;;
  esac
done

cd "$ROOT"

if [[ -z "${CXX:-}" ]] && command -v g++ >/dev/null 2>&1; then
  export CXX=g++
fi

CMAKE_COMPILER_ARGS=()
if [[ -n "${CXX:-}" ]]; then
  CXX_PATH="$(command -v "${CXX}" || true)"
  CXX_PATH="${CXX_PATH:-${CXX}}"
  CMAKE_COMPILER_ARGS+=("-DCMAKE_CXX_COMPILER=${CXX_PATH}")

  if [[ -f "${BUILD_DIR}/CMakeCache.txt" ]]; then
    CACHED_CXX="$(python3 - "${BUILD_DIR}/CMakeCache.txt" <<'PY'
import sys
from pathlib import Path

for line in Path(sys.argv[1]).read_text(errors="replace").splitlines():
    if line.startswith("CMAKE_CXX_COMPILER:"):
        print(line.split("=", 1)[1])
        break
PY
)"
    if [[ -n "${CACHED_CXX}" && "${CACHED_CXX}" != "${CXX_PATH}" && "${CACHED_CXX}" != "${CXX}" ]]; then
      echo "==> Resetting stale full build cache (${CACHED_CXX} -> ${CXX_PATH})"
      rm -rf "${BUILD_DIR}"
    fi
  fi
fi

if [[ ! -x "${BUILD_DIR}/nexus_renderer_test" ]]; then
  cmake -S . -B "$BUILD_DIR" -DNEXUS_ENABLE_RENDERER=ON -DNEXUS_BUILD_TESTS=ON \
    "${CMAKE_COMPILER_ARGS[@]}"
  cmake --build "$BUILD_DIR" --target nexus_renderer_test
fi

export NEXUS_MESH_PROFILE=mobile
"${BUILD_DIR}/nexus_renderer_test"

python3 - "${WARN_ONLY}" <<'PY'
import json
import sys
from pathlib import Path

warn_only = sys.argv[1] == "1"
manifest = json.loads(Path("assets/nexus/manifests/nexus_asset_manifest.json").read_text())
import_root = Path(manifest.get("import_root", "assets/nexus/imported"))

def desktop_basename(asset: dict) -> str:
    desktop = asset.get("imported_mesh_desktop") or asset.get("imported_mesh") or ""
    if desktop.endswith("_mobile.nexusmesh.json"):
        return desktop.replace("_mobile.nexusmesh.json", ".nexusmesh.json")
    return desktop

def mobile_candidates(asset: dict) -> list[Path]:
    mobile = asset.get("imported_mesh_mobile") or ""
    desktop = desktop_basename(asset)
    candidates: list[Path] = []
    if mobile:
        candidates.append(import_root / mobile)
    if desktop.endswith(".nexusmesh.json"):
        inferred = desktop.replace(".nexusmesh.json", "_mobile.nexusmesh.json")
        inferred_path = import_root / inferred
        if inferred_path not in candidates:
            candidates.append(inferred_path)
    return candidates

missing = []
for asset in manifest.get("assets", []):
    if asset.get("kind") != "environment":
        continue
    if not any(p.exists() for p in mobile_candidates(asset)):
        missing.append(asset["id"])

if missing:
    level = "WARN" if warn_only else "ERROR"
    print(f"{level}: mobile sidecar missing for:", ", ".join(missing))
    print("Runtime would fall back to desktop mesh with decimation hook.")
    if not warn_only:
        sys.exit(1)
else:
    print("All environment assets have mobile sidecars or within-budget desktop meshes.")
PY

echo "==> nexus_mobile_mesh_gate PASS"
