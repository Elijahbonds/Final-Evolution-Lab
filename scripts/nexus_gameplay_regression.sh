#!/usr/bin/env bash
# NEXUS gameplay regression — headless ctest + nexus_gameplay_test artifact for agents.
# Usage: ./scripts/nexus_gameplay_regression.sh [--skip-build]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HEADLESS_DIR="${ROOT}/build-headless"
ARTIFACT_DIR="${ROOT}/artifacts/playtest"
REGRESSION_JSON="${ARTIFACT_DIR}/gameplay_regression.json"
REGRESSION_LOG="${ARTIFACT_DIR}/gameplay_regression_run.log"
SKIP_BUILD=0

for arg in "$@"; do
  case "$arg" in
    --skip-build) SKIP_BUILD=1 ;;
    -h|--help)
      echo "Usage: $0 [--skip-build]"
      exit 0
      ;;
  esac
done

mkdir -p "${ARTIFACT_DIR}"
cd "${ROOT}"

if [[ "${SKIP_BUILD}" -eq 0 ]]; then
  echo "==> Configure + build headless gameplay tests"
  cmake -S . -B "${HEADLESS_DIR}" \
    -DNEXUS_ENABLE_RENDERER=OFF \
    -DNEXUS_BUILD_RUNTIME=OFF \
    -DNEXUS_BUILD_TESTS=ON
  cmake --build "${HEADLESS_DIR}" -j"$(sysctl -n hw.ncpu 2>/dev/null || nproc)"
fi

GAMEPLAY_TEST="${HEADLESS_DIR}/nexus_gameplay_test"
if [[ ! -x "${GAMEPLAY_TEST}" ]]; then
  echo "error: ${GAMEPLAY_TEST} missing — run without --skip-build" >&2
  exit 1
fi

echo "==> ctest (headless matrix)"
CTEST_LOG="${ARTIFACT_DIR}/gameplay_regression_ctest.log"
set +e
ctest --test-dir "${HEADLESS_DIR}" --output-on-failure >"${CTEST_LOG}" 2>&1
CTEST_CODE=$?
set -e

echo "==> nexus_gameplay_test (integration suite)"
set +e
"${GAMEPLAY_TEST}" >"${REGRESSION_LOG}" 2>&1
GAMEPLAY_CODE=$?
set -e

GENERATED_AT="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
OVERALL="pass"
if [[ ${CTEST_CODE} -ne 0 || ${GAMEPLAY_CODE} -ne 0 ]]; then
  OVERALL="fail"
fi

python3 - "${REGRESSION_JSON}" "${GENERATED_AT}" "${OVERALL}" "${CTEST_CODE}" "${GAMEPLAY_CODE}" \
  "${REGRESSION_LOG}" "${CTEST_LOG}" <<'PY'
import json
import re
import sys
from pathlib import Path

out_path = Path(sys.argv[1])
generated_at = sys.argv[2]
overall = sys.argv[3]
ctest_code = int(sys.argv[4])
gameplay_code = int(sys.argv[5])
gameplay_log = Path(sys.argv[6]).read_text(errors="replace")
ctest_log = Path(sys.argv[7]).read_text(errors="replace")

sprint_modes = [
    "basketball_dunk", "karate_endless", "basketball_h2h", "court_carnival",
    "gymnastics", "brain_brawl", "skateboarding", "snowboarding", "surfing",
    "who_scene_it",
]

modes_exercised = [m for m in sprint_modes if f"mode={m}" in gameplay_log or f"mode_id={m}" in gameplay_log]
fail_lines = [line.strip() for line in gameplay_log.splitlines() if line.startswith("FAIL:")]

payload = {
    "schema_version": "1",
    "generated_at": generated_at,
    "overall_status": overall,
    "ctest_exit_code": ctest_code,
    "gameplay_test_exit_code": gameplay_code,
    "sprint_live_modes_expected": len(sprint_modes),
    "sprint_live_modes_seen_in_log": len(modes_exercised),
    "sprint_live_modes": modes_exercised,
    "failures": fail_lines,
    "pass_banner": "PASS: nexus_gameplay_test" in gameplay_log,
    "artifacts": {
        "gameplay_log": "artifacts/playtest/gameplay_regression_run.log",
        "ctest_log": "artifacts/playtest/gameplay_regression_ctest.log",
    },
}

ctest_summary = re.search(r"(\d+)% tests passed", ctest_log)
if ctest_summary:
    payload["ctest_summary"] = ctest_summary.group(0)

out_path.write_text(json.dumps(payload, indent=2) + "\n")
print(json.dumps(payload, indent=2))
PY

echo "==> Wrote ${REGRESSION_JSON}"

if [[ "${OVERALL}" != "pass" ]]; then
  echo "==> nexus_gameplay_regression FAIL (ctest=${CTEST_CODE}, gameplay_test=${GAMEPLAY_CODE})" >&2
  exit 1
fi

echo "==> nexus_gameplay_regression PASS"
