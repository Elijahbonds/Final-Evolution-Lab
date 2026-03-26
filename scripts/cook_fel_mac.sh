#!/usr/bin/env bash
# Cook Final Evolution Lab for Mac (Development). Requires UE 5.7 at default Epic path.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="${ROOT}/UnrealStarter/BasketballGame/FinalEvolutionLab.uproject"
UE_ROOT="${UE_ROOT:-/Users/Shared/Epic Games/UE_5.7}"
RUN_UAT="${UE_ROOT}/Engine/Build/BatchFiles/RunUAT.sh"
UNREAL_EDITOR="${UE_ROOT}/Engine/Binaries/Mac/UnrealEditor"
ARCHIVE="${ROOT}/UnrealStarter/BasketballGame/Saved/CookedBuild"

if [[ ! -f "${PROJECT}" ]]; then
  echo "Missing .uproject: ${PROJECT}" >&2
  exit 1
fi
if [[ ! -x "${RUN_UAT}" ]]; then
  echo "RunUAT not found: ${RUN_UAT} (set UE_ROOT)" >&2
  exit 1
fi

echo "==> Building + cooking (Mac Development, all maps)..."
"${RUN_UAT}" BuildCookRun \
  -project="${PROJECT}" \
  -noP4 \
  -platform=Mac \
  -clientconfig=Development \
  -cook \
  -allmaps \
  -build \
  -installed \
  -unrealexe="${UNREAL_EDITOR}" \
  -archive \
  -archivedirectory="${ARCHIVE}"

echo "==> Done. Staged build: ${ARCHIVE}"
