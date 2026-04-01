#!/usr/bin/env bash
# Opens the Unreal-generated iOS .xcworkspace for FinalEvolutionLab (after BuildCookRun archive).
# Usage: open_fel_ios_xcode.sh [search_root]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GAME_DIR="$(cd "${SCRIPT_DIR}/../BasketballGame" && pwd)"
ROOT="${1:-${GAME_DIR}}"

if ! command -v open >/dev/null 2>&1; then
  echo "macOS 'open' not found" >&2
  exit 1
fi

WS=()
while IFS= read -r line; do
  WS+=("${line}")
done < <(find "${ROOT}" \( -path "*/Binaries/*" -o -path "*/Intermediate/*" -o -path "*/Saved/*" \) -name "*.xcworkspace" 2>/dev/null | head -20)

if [[ ${#WS[@]} -eq 0 ]]; then
  echo "No .xcworkspace found under ${ROOT}" >&2
  echo "Run BuildCookRun for iOS first, e.g.:" >&2
  echo "  bash \"${SCRIPT_DIR}/package_fel_ios.sh\"" >&2
  exit 1
fi

# Prefer workspace whose name contains the project or IOS
PICK=""
for w in "${WS[@]}"; do
  if [[ "${w}" == *"FinalEvolutionLab"* ]] || [[ "${w}" == *"IOS"* ]]; then
    PICK="${w}"
    break
  fi
done
if [[ -z "${PICK}" ]]; then
  PICK="${WS[0]}"
fi

echo "Opening: ${PICK}"
open -a Xcode "${PICK}"
