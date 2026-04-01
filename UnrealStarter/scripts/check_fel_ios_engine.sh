#!/usr/bin/env bash
# Verifies UE 5.7 can build iOS targets (Epic Launcher → Engine → Options → iOS platform must be installed).
# Exit 0 = UBT accepts IOS; exit 1 = install iOS support or fix UE_ROOT.
set -euo pipefail

UE_ROOT="${UE_ROOT:-/Users/Shared/Epic Games/UE_5.7}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GAME_DIR="$(cd "${SCRIPT_DIR}/../BasketballGame" && pwd)"
PROJECT="${PROJECT:-${GAME_DIR}/FinalEvolutionLab.uproject}"
DOTNET="${UE_ROOT}/Engine/Binaries/ThirdParty/DotNet/8.0.412/mac-arm64/dotnet"
UBT="${UE_ROOT}/Engine/Binaries/DotNET/UnrealBuildTool/UnrealBuildTool.dll"

if [[ ! -f "${PROJECT}" ]]; then
  echo "Project not found: ${PROJECT}" >&2
  exit 1
fi
if [[ ! -x "${DOTNET}" ]] || [[ ! -f "${UBT}" ]]; then
  echo "UnrealBuildTool not found. Set UE_ROOT (current: ${UE_ROOT})" >&2
  exit 1
fi

echo "==> Probing IOS target (UnrealBuildTool)..."
TMP_LOG="$(mktemp -t fel_ubt_ios.XXXXXX.log)"
set +e
OUT="$("${DOTNET}" "${UBT}" -Target="FinalEvolutionLab IOS Development -Project=${PROJECT}" -log="${TMP_LOG}" 2>&1)"
RC=$?
set -e
rm -f "${TMP_LOG}"

if echo "${OUT}" | grep -q "Missing files required to build IOS targets"; then
  echo "" >&2
  echo "FAILED: iOS platform files are not installed for this engine." >&2
  echo "  Epic Games Launcher → Library → UE 5.7 → ⋯ → Options → install \"iOS\"" >&2
  echo "  (or equivalent \"Target Platforms\" / iOS checkbox for your engine build)." >&2
  echo "" >&2
  exit 1
fi

if [[ "${RC}" -ne 0 ]]; then
  echo "UnrealBuildTool exit code: ${RC}" >&2
  echo "See log output above or ~/Library/Logs/Unreal Engine/LocalBuildLogs/" >&2
  exit "${RC}"
fi

echo "==> iOS engine support OK — UnrealBuildTool accepted FinalEvolutionLab IOS Development."
exit 0
