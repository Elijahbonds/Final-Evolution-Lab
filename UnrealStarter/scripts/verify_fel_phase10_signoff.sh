#!/usr/bin/env bash
# Phase 10 — Engineering sign-off: static inventory for FEL Phases 1–9 + optional UBT matrix.
# Invoked by Phase 9: `verify_fel_phase9_automation.sh` (static checks without --compile by default).
#
# This is distinct from packaging “go live” Phase 10 in GOLD_MASTER_MAC_PACKAGING.txt
# (Netlify + verify_gold_master_distribution.sh).
#
# Usage (from repo root or anywhere):
#   bash UnrealStarter/scripts/verify_fel_phase10_signoff.sh
#   bash UnrealStarter/scripts/verify_fel_phase10_signoff.sh --compile
#
# --compile runs verify_fel_build_matrix.sh (macOS only; honors VERIFY_FEL_SKIP_IOS).
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
GAME="${REPO_ROOT}/UnrealStarter/BasketballGame"
SRC="${GAME}/Source/FinalEvolutionLab"

fail() {
	echo "verify_fel_phase10_signoff: $*" >&2
	exit 1
}

need_file() {
	[[ -f "$1" ]] || fail "missing file: $1"
}

fel_cpp_must_have() {
	local Pat="$1"
	local Hint="$2"
	if ! find "${SRC}" \( -name '*.cpp' -o -name '*.h' \) -exec grep -lF "${Pat}" {} + 2>/dev/null | grep -q .; then
		fail "expected C++ symbol/text not found (${Hint}): ${Pat}"
	fi
}

echo "==> Phase 10 static checks (project + configs + Phase 1–9 hooks)"

need_file "${GAME}/FinalEvolutionLab.uproject"
need_file "${GAME}/Content/FEL/Config/FEL_ClinicalUIPolicy.json"
need_file "${GAME}/Content/FEL/Config/BrainBrawlCurriculum.json"
need_file "${SRC}/FELClinicalUIPolicy.h"
need_file "${SRC}/FELArenaModeDefinitions.h"
need_file "${SRC}/UFELExerciseDemoPipelineSubsystem.h"
need_file "${SRC}/UFELCloudSyncSubsystem.cpp"
need_file "${SRC}/FELPlatformPaths.h"
need_file "${SRC}/FELNativeBridge.h"
need_file "${SCRIPT_DIR}/verify_fel_build_matrix.sh"

[[ -x "${SCRIPT_DIR}/verify_fel_build_matrix.sh" ]] || fail "chmod +x UnrealStarter/scripts/verify_fel_build_matrix.sh"

fel_cpp_must_have "namespace FELArenaModeIds" "canonical arena mode ids"
fel_cpp_must_have "ApplyArenaInputForMode" "arena input mapping contexts"
fel_cpp_must_have "ModeInputMappingContexts" "FFELArenaRules per-mode IMCs"
fel_cpp_must_have "GetClinicalUIPolicy" "clinical UI policy on game instance"
fel_cpp_must_have "TriggerExerciseDemoForMode" "exercise demo pipeline"
fel_cpp_must_have "TEXT(\"mod13\")" "board-sports demo module keys (surf)"
fel_cpp_must_have "bPendingCloudSync = false" "cloud sync stub must clear pending flag"

echo "==> Phase 10 static checks passed."

if [[ "${1:-}" == "--compile" ]]; then
	if [[ "$(uname -s)" != "Darwin" ]]; then
		fail "--compile requires macOS (same as verify_fel_build_matrix.sh)"
	fi
	echo "==> Running compile matrix (VERIFY_FEL_SKIP_IOS=${VERIFY_FEL_SKIP_IOS:-0})"
	bash "${SCRIPT_DIR}/verify_fel_build_matrix.sh"
fi

echo "==> Phase 10 sign-off complete."
