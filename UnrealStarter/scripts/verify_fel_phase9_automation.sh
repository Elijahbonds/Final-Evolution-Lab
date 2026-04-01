#!/usr/bin/env bash
# Phase 9 — Automation: static Unreal sign-off + optional compile matrix + iOS unit tests (SceneKit smoke).
#
# Environment:
#   VERIFY_FEL_PHASE9_UE_MATRIX — set to 1 to run verify_fel_build_matrix.sh (macOS only; honors VERIFY_FEL_SKIP_IOS, default 1)
#   VERIFY_FEL_SKIP_IOS_TESTS   — set to 1 to skip xcodebuild test (e.g. Linux CI without Xcode)
#   VERIFY_FEL_IOS_TEST_DEST    — override simulator destination (default: platform=iOS Simulator,name=iPhone 17)
#
# Usage (from repo root):
#   bash UnrealStarter/scripts/verify_fel_phase9_automation.sh
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
IOS_DIR="${REPO_ROOT}/ios"

echo "==> Phase 9 — static Unreal checks (verify_fel_phase10_signoff.sh, no compile)"
bash "${SCRIPT_DIR}/verify_fel_phase10_signoff.sh"

if [[ "${VERIFY_FEL_PHASE9_UE_MATRIX:-0}" == "1" ]]; then
	if [[ "$(uname -s)" != "Darwin" ]]; then
		echo "verify_fel_phase9_automation: VERIFY_FEL_PHASE9_UE_MATRIX=1 requires macOS" >&2
		exit 2
	fi
	echo "==> Phase 9 — Unreal compile matrix (VERIFY_FEL_SKIP_IOS=${VERIFY_FEL_SKIP_IOS:-1})"
	VERIFY_FEL_SKIP_IOS="${VERIFY_FEL_SKIP_IOS:-1}" bash "${SCRIPT_DIR}/verify_fel_build_matrix.sh"
else
	echo "==> Skipping Unreal compile matrix (set VERIFY_FEL_PHASE9_UE_MATRIX=1 to run)."
fi

if [[ "${VERIFY_FEL_SKIP_IOS_TESTS:-0}" == "1" ]]; then
	echo "==> Skipping iOS tests (VERIFY_FEL_SKIP_IOS_TESTS=1)."
elif [[ "$(uname -s)" != "Darwin" ]]; then
	echo "verify_fel_phase9_automation: skipping iOS tests (not macOS; set VERIFY_FEL_SKIP_IOS_TESTS=1 on Linux CI to silence)."
else
	if [[ ! -d "${IOS_DIR}" ]]; then
		echo "verify_fel_phase9_automation: missing ${IOS_DIR}" >&2
		exit 1
	fi
	DEST="${VERIFY_FEL_IOS_TEST_DEST:-platform=iOS Simulator,name=iPhone 17}"
	echo "==> Phase 9 — iOS unit tests (FinalEvolutionLabTests, ${DEST})"
	(
		cd "${IOS_DIR}"
		xcodebuild test \
			-scheme FinalEvolutionLab \
			-configuration Debug \
			-destination "${DEST}" \
			-only-testing:FinalEvolutionLabTests \
			CODE_SIGNING_ALLOWED=NO
	)
fi

echo "==> Phase 9 automation complete."
