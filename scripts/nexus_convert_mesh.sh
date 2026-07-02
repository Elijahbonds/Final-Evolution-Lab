#!/usr/bin/env bash
# Mesh conversion: FBX/glTF -> NEXUS .nexusmesh.json
# Usage:
#   ./scripts/nexus_convert_mesh.sh --convert [--asset ID]
#   ./scripts/nexus_convert_mesh.sh --from-gltf path/to/model.glb [--mobile]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
python3 "$ROOT/scripts/nexus_import_assets.py" "$@"
