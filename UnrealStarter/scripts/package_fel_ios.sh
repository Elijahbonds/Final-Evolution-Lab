#!/usr/bin/env bash
# FinalEvolutionLab — iOS RunUAT BuildCookRun (Development): build, cook, stage, pak, archive.
# Default paths point at this repo: UnrealStarter/BasketballGame/FinalEvolutionLab.uproject
#
# Prerequisite: Epic Games Launcher → UE 5.7 → Options → install iOS target platform.
#   If you see "Missing files required to build IOS targets", iOS support is not installed.
#
# Usage:
#   bash UnrealStarter/scripts/package_fel_ios.sh [path/to/FinalEvolutionLab.uproject] [archive_dir]
#
# After success: open the .xcworkspace (or run open_fel_ios_xcode.sh), pick your iPhone, set Team, ⌘R.
set -euo pipefail

UE_ROOT="${UE_ROOT:-/Users/Shared/Epic Games/UE_5.7}"
RUNUAT="${UE_ROOT}/Engine/Build/BatchFiles/RunUAT.sh"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GAME_DIR="$(cd "${SCRIPT_DIR}/../BasketballGame" && pwd)"

PROJECT="${1:-${GAME_DIR}/FinalEvolutionLab.uproject}"
ARCHIVE="${2:-${GAME_DIR}/Saved/Archive/IOS_Development}"

if [[ ! -x "${RUNUAT}" ]]; then
  echo "RunUAT not found at: ${RUNUAT} — set UE_ROOT" >&2
  exit 1
fi

if [[ ! -f "${PROJECT}" ]]; then
  echo "Project not found: ${PROJECT}" >&2
  exit 1
fi

mkdir -p "${ARCHIVE}"

echo "Cooking & staging iOS Development build..."
echo "  UE_ROOT:  ${UE_ROOT}"
echo "  Project:  ${PROJECT}"
echo "  Archive:  ${ARCHIVE}"

"${RUNUAT}" BuildCookRun \
  -project="${PROJECT}" \
  -nop4 \
  -platform=IOS \
  -clientconfig=Development \
  -serverconfig=Development \
  -build \
  -cook \
  -stage \
  -pak \
  -archive \
  -archivedirectory="${ARCHIVE}"

echo ""
echo "Done. iOS output: ${ARCHIVE}"
echo "Open workspace: bash \"${SCRIPT_DIR}/open_fel_ios_xcode.sh\" \"${GAME_DIR}\""
echo "Or: open the .xcworkspace under the archive or Saved/StagedBuilds — then select iPhone, Signing Team, ⌘R."
