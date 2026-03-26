#!/usr/bin/env bash
# Gold Master: build every clinical placeholder .umap in a fresh Unreal Editor process (avoids world-leak fatal on Mac unattended).
# Usage:
#   export UE_ROOT="/Users/Shared/Epic Games/UE_5.7"
#   bash UnrealStarter/BasketballGame/EditorPython/fel_clinical_placeholder_venues_batch.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GAME_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
PROJ="${GAME_DIR}/FinalEvolutionLab.uproject"
PY="${SCRIPT_DIR}/fel_clinical_placeholder_venues.py"
UE_ROOT="${UE_ROOT:-/Users/Shared/Epic Games/UE_5.7}"
UE="${UE_ROOT}/Engine/Binaries/Mac/UnrealEditor.app/Contents/MacOS/UnrealEditor"

if [[ ! -x "$UE" ]]; then
  echo "FEL Titan: UnrealEditor not found at: $UE (set UE_ROOT)" >&2
  exit 1
fi
if [[ ! -f "$PROJ" ]]; then
  echo "FEL Titan: .uproject not found: $PROJ" >&2
  exit 1
fi

LAST=$((10))
for i in $(seq 0 "${LAST}"); do
  echo "FEL Titan batch: FEL_VENUE_INDEX=${i}"
  # UE 5.7 Mac unattended + -Quit may exit non-zero after save; .umap is still written — do not abort the loop.
  FEL_VENUE_INDEX="${i}" \
    "${UE}" "${PROJ}" \
    -ExecutePythonScript="${PY}" \
    -stdout -unattended -nosplash -nullrhi -Quit || true
done

echo "FEL Titan: batch complete (indices 0..${LAST}, $((LAST + 1)) maps). Verify Content/FEL/Venues/*/*.umap"
