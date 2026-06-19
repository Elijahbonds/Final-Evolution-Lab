#!/usr/bin/env bash
# Stub mesh conversion: FBX/glTF -> NEXUS .nexusmesh.json
# Replace with Blender headless or assimp when production pipeline is ready.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
python3 "$ROOT/scripts/nexus_import_assets.py" --convert "$@"
