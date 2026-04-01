#!/usr/bin/env bash
# Phase 3 — Smoke: venue path sanity + optional Unreal matrix + iOS SceneKit Release compile.
#
# Environment:
#   VERIFY_FEL_PHASE3_UE_MATRIX — set to 1 to run verify_fel_build_matrix.sh (adds time; uses VERIFY_FEL_SKIP_IOS=1 by default)
#   VERIFY_FEL_SKIP_IOS         — passed through when UE matrix runs (default 1)
#
# Usage:
#   bash UnrealStarter/scripts/verify_fel_phase3_smoke.sh
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
IOS_DIR="${REPO_ROOT}/ios"

echo "==> Phase 3 — venue paths (Phase 2 checks)"
bash "${SCRIPT_DIR}/verify_fel_phase2_venue_paths.sh"

if [[ "${VERIFY_FEL_PHASE3_UE_MATRIX:-0}" == "1" ]]; then
	if [[ "$(uname -s)" != "Darwin" ]]; then
		echo "verify_fel_phase3_smoke: VERIFY_FEL_PHASE3_UE_MATRIX=1 requires macOS" >&2
		exit 2
	fi
	echo "==> Phase 3 — Unreal compile matrix (VERIFY_FEL_SKIP_IOS=${VERIFY_FEL_SKIP_IOS:-1})"
	VERIFY_FEL_SKIP_IOS="${VERIFY_FEL_SKIP_IOS:-1}" bash "${SCRIPT_DIR}/verify_fel_build_matrix.sh"
else
	echo "==> Skipping Unreal matrix (set VERIFY_FEL_PHASE3_UE_MATRIX=1 to run)."
fi

if [[ ! -d "${IOS_DIR}" ]]; then
	echo "verify_fel_phase3_smoke: missing ${IOS_DIR}" >&2
	exit 1
fi

echo "==> Phase 3 — iOS SceneKit Release (CODE_SIGNING_ALLOWED=NO, generic device)"
(
	cd "${IOS_DIR}"
	xcodebuild -scheme FinalEvolutionLab -configuration Release \
		-destination 'generic/platform=iOS' build CODE_SIGNING_ALLOWED=NO
)

echo "==> Phase 3 smoke complete."
