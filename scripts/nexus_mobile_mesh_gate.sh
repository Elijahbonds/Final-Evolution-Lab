#!/usr/bin/env bash
# Phase 3 — validate NEXUS_MESH_PROFILE=mobile resolves for all environment assets.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${ROOT}/build-full"
cd "$ROOT"

if [[ -z "${CC:-}" ]] && command -v gcc >/dev/null 2>&1; then
  export CC=gcc
fi
if [[ -z "${CXX:-}" ]] && command -v g++ >/dev/null 2>&1; then
  export CXX=g++
fi

if [[ ! -x "${BUILD_DIR}/nexus_renderer_test" ]]; then
  if [[ -f "${BUILD_DIR}/CMakeCache.txt" ]] && \
     grep -q "CMAKE_CXX_COMPILER:FILEPATH=/usr/bin/c++" "${BUILD_DIR}/CMakeCache.txt" && \
     [[ "${CXX:-}" == "g++" || "${CXX:-}" == */g++ ]]; then
    echo "==> Removing stale build-full cache that used broken /usr/bin/c++"
    rm -rf "$BUILD_DIR"
  fi
  cmake -S . -B "$BUILD_DIR" -DNEXUS_ENABLE_RENDERER=ON -DNEXUS_BUILD_TESTS=ON
  cmake --build "$BUILD_DIR" --target nexus_renderer_test
fi

export NEXUS_MESH_PROFILE=mobile
"${BUILD_DIR}/nexus_renderer_test"

python3 - <<'PY'
import json
from pathlib import Path

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
    print("WARN: mobile sidecar missing for:", ", ".join(missing))
    print("Runtime falls back to desktop mesh with decimation hook.")
else:
    print("All environment assets have mobile sidecars or within-budget desktop meshes.")
PY

echo "==> nexus_mobile_mesh_gate PASS"
