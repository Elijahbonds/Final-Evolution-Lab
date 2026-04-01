#!/usr/bin/env bash
# Opens the Unreal-generated iOS .xcworkspace for FinalEvolutionLab.
# UE keeps the iOS .xcworkspace under Intermediate/ProjectFiles; cooked content is under Saved/StagedBuilds/IOS.
# Usage: open_fel_ios_xcode.sh [search_root]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GAME_DIR="$(cd "${SCRIPT_DIR}/../BasketballGame" && pwd)"
ROOT="${1:-${GAME_DIR}}"

if ! command -v open >/dev/null 2>&1; then
  echo "macOS 'open' not found" >&2
  exit 1
fi

# Collect in priority order: staged/cooked builds first (required for physical device).
WS=()
while IFS= read -r line; do
  [[ -n "${line}" ]] && WS+=("${line}")
done < <(find "${ROOT}" -path "*/Saved/StagedBuilds/*" -name "*.xcworkspace" 2>/dev/null)

while IFS= read -r line; do
  [[ -n "${line}" ]] && WS+=("${line}")
done < <(find "${ROOT}" -path "*/Saved/Archive/*" -name "*.xcworkspace" 2>/dev/null)

while IFS= read -r line; do
  [[ -n "${line}" ]] && WS+=("${line}")
done < <(find "${ROOT}" -path "*/Binaries/IOS/*" -name "*.xcworkspace" 2>/dev/null)

while IFS= read -r line; do
  [[ -n "${line}" ]] && WS+=("${line}")
done < <(find "${ROOT}" -path "*/Intermediate/*" -name "*.xcworkspace" 2>/dev/null)

if [[ ${#WS[@]} -eq 0 ]]; then
  echo "No .xcworkspace found under ${ROOT}" >&2
  echo "Run a full iOS cook first, e.g.:" >&2
  echo "  bash \"${SCRIPT_DIR}/package_fel_ios.sh\"" >&2
  exit 1
fi

# Prefer iOS game workspace over Mac editor when multiple match.
PICK=""
for w in "${WS[@]}"; do
  if [[ "${w}" == *"_IOS_"* ]] || [[ "${w}" == *"/IOS/"* ]]; then
    PICK="${w}"
    break
  fi
done
if [[ -z "${PICK}" ]]; then
  for w in "${WS[@]}"; do
    if [[ "${w}" == *"FinalEvolutionLab"* ]] || [[ "${w}" == *"IOS"* ]]; then
      PICK="${w}"
      break
    fi
  done
fi
if [[ -z "${PICK}" ]]; then
  PICK="${WS[0]}"
fi

# Warn only if there is no cooked iOS app yet (Xcode from Intermediate before first package will fail on device).
STAGED_IOS_APP=""
while IFS= read -r line; do
  [[ -n "${line}" ]] && STAGED_IOS_APP="${line}" && break
done < <(find "${ROOT}/Saved/StagedBuilds/IOS" -maxdepth 1 -name "*.app" 2>/dev/null)

if [[ -z "${STAGED_IOS_APP}" ]] && [[ "${PICK}" == *"/Intermediate/"* ]] && [[ "${PICK}" == *"_IOS_"* ]]; then
  echo "" >&2
  echo "WARNING: No cooked iOS app under Saved/StagedBuilds/IOS yet." >&2
  echo "  Building to a phone without running package first often shows:" >&2
  echo "  \"Failed to open descriptor file ... FinalEvolutionLab.uproject\"" >&2
  echo "Run:" >&2
  echo "  bash \"${SCRIPT_DIR}/package_fel_ios.sh\"" >&2
  echo "" >&2
fi

echo "Opening: ${PICK}"
open -a Xcode "${PICK}"
