#!/usr/bin/env bash
# Package MyProjec (FEL basketball) for iOS — Unreal RunUAT.sh BuildCookRun, Development.
# -platform=IOS -clientconfig=Development -build -cook -stage -pak -archive
set -euo pipefail

UE_ROOT="${UE_ROOT:-/Users/Shared/Epic Games/UE_5.7}"
RUNUAT="${UE_ROOT}/Engine/Build/BatchFiles/RunUAT.sh"

PROJECT="${1:-${HOME}/Documents/Unreal Projects/MyProjec/MyProjec.uproject}"
ARCHIVE="${2:-${HOME}/Documents/Unreal Projects/MyProjec/Packaged/IOS}"

if [[ ! -x "${RUNUAT}" ]]; then
  echo "RunUAT not found at: ${RUNUAT}"
  exit 1
fi

if [[ ! -f "${PROJECT}" ]]; then
  echo "Project not found: ${PROJECT}"
  exit 1
fi

echo "Cooking & staging iOS Development build..."
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

echo "Done. iOS build exported to ${ARCHIVE}."
echo "Open the generated .xcworkspace in Xcode, select your iPhone, configure your Apple Developer Team signing, and hit Cmd+R!"
