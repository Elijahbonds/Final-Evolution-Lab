#!/usr/bin/env bash
# Phase 9 — Automation: compile-check FinalEvolutionLab (Editor + Mac game + optional iOS UBT).
#
# Prerequisites: macOS, UE 5.7 at UE_ROOT, Xcode toolchain for Mac/iOS targets.
#
# Environment:
#   UE_ROOT              — default: /Users/Shared/Epic Games/UE_5.7
#   VERIFY_FEL_SKIP_IOS  — set to 1 to skip iOS UBT (faster; use on machines without iOS platform installed)
#
# Usage (repo root or anywhere):
#   bash UnrealStarter/scripts/verify_fel_build_matrix.sh
#
# Exit codes: 0 success, non-zero first failing UBT/check exit code.
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
	echo "verify_fel_build_matrix.sh: requires macOS (Darwin) for Mac/iOS Unreal targets." >&2
	exit 2
fi

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

run_ubt() {
	local Label="$1"
	local TargetArg="$2"
	echo ""
	echo "==> ${Label}"
	"${DOTNET}" "${UBT}" -Target="${TargetArg}"
}

run_ubt "FinalEvolutionLabEditor (Mac Development)" "FinalEvolutionLabEditor Mac Development -Project=${PROJECT}"
run_ubt "FinalEvolutionLab game (Mac Development)" "FinalEvolutionLab Mac Development -Project=${PROJECT}"

if [[ "${VERIFY_FEL_SKIP_IOS:-0}" == "1" ]]; then
	echo ""
	echo "==> Skipping iOS probe (VERIFY_FEL_SKIP_IOS=1)."
else
	bash "${SCRIPT_DIR}/check_fel_ios_engine.sh"
fi

echo ""
echo "==> FEL build matrix verification succeeded."
