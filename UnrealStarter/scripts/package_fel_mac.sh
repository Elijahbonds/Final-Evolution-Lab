#!/usr/bin/env bash
# Package MyProjec (FEL basketball) for Mac — Unreal RunUAT.sh BuildCookRun, Development.
# -platform=Mac -clientconfig=Development -build -cook -stage -pak -archive
# Override: UE_ROOT (engine root), or pass .uproject path + archive directory as args.
# Usage: package_fel_mac.sh [MyProjec.uproject] [archive_directory]
set -euo pipefail

UE_ROOT="${UE_ROOT:-/Users/Shared/Epic Games/UE_5.7}"
RUNUAT="${UE_ROOT}/Engine/Build/BatchFiles/RunUAT.sh"

# Default: in-repo canonical UE project (see UNREAL_ONLY.md)
REPO_UE_DEFAULT="$(cd "$(dirname "$0")/../BasketballGame" && pwd)/FinalEvolutionLab.uproject"
PROJECT="${1:-$REPO_UE_DEFAULT}"
ARCHIVE="${2:-${PWD}/FEL-Mac-Development-Archive}"

if [[ ! -x "${RUNUAT}" ]]; then
  echo "RunUAT not found at: ${RUNUAT}"
  echo "Set UE_ROOT to your engine install (e.g. export UE_ROOT=\"/Users/Shared/Epic Games/UE_5.7\")"
  exit 1
fi

if [[ ! -f "${PROJECT}" ]]; then
  echo "Project not found: ${PROJECT}"
  exit 1
fi

echo "Cooking & staging Mac Development build..."
echo "  Project:  ${PROJECT}"
echo "  Archive:  ${ARCHIVE}"

"${RUNUAT}" BuildCookRun \
  -project="${PROJECT}" \
  -nop4 \
  -platform=Mac \
  -clientconfig=Development \
  -serverconfig=Development \
  -build \
  -cook \
  -stage \
  -pak \
  -archive \
  -archivedirectory="${ARCHIVE}"

echo "Done. Run the packaged app from the archive folder (MacNoEditor or similar)."
