#!/usr/bin/env bash
# NEXUS renderer asset regression — manifest, mobile mesh, and console-tier checks
# without requiring SDL3/Vulkan. Uses the non-Apple Metal stub build to compile the
# renderer asset stack in Linux CI.
# Usage: ./scripts/nexus_renderer_asset_regression.sh [--skip-build]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${NEXUS_RENDERER_LITE_BUILD_DIR:-${ROOT}/build-renderer-lite}"
ARTIFACT_DIR="${ROOT}/artifacts/playtest"
REGRESSION_JSON="${ARTIFACT_DIR}/renderer_asset_regression.json"
REGRESSION_LOG="${ARTIFACT_DIR}/renderer_asset_regression_ctest.log"
SKIP_BUILD=0

for arg in "$@"; do
  case "$arg" in
    --skip-build) SKIP_BUILD=1 ;;
    -h|--help)
      echo "Usage: $0 [--skip-build]"
      exit 0
      ;;
    *)
      echo "error: unknown argument: ${arg}" >&2
      exit 2
      ;;
  esac
done

mkdir -p "${ARTIFACT_DIR}"
cd "${ROOT}"

if [[ -z "${CC:-}" ]] && command -v gcc >/dev/null 2>&1; then
  export CC=gcc
fi
if [[ -z "${CXX:-}" ]] && command -v g++ >/dev/null 2>&1; then
  export CXX=g++
fi

if [[ "${SKIP_BUILD}" -eq 0 ]]; then
  echo "==> Configure + build renderer asset test matrix (SDL/Vulkan-free)"
  cmake -S . -B "${BUILD_DIR}" \
    -DNEXUS_ENABLE_RENDERER=OFF \
    -DNEXUS_ENABLE_METAL_RENDERER=ON \
    -DNEXUS_BUILD_RUNTIME=OFF \
    -DNEXUS_BUILD_TESTS=ON
  cmake --build "${BUILD_DIR}" --target nexus_renderer_test nexus_console_tier_test \
    -j"$(sysctl -n hw.ncpu 2>/dev/null || nproc)"
fi

for test_binary in nexus_renderer_test nexus_console_tier_test; do
  if [[ ! -x "${BUILD_DIR}/${test_binary}" ]]; then
    echo "error: ${BUILD_DIR}/${test_binary} missing — run without --skip-build" >&2
    exit 1
  fi
done

echo "==> ctest (renderer asset matrix)"
set +e
ctest --test-dir "${BUILD_DIR}" -R 'nexus_renderer_test|nexus_console_tier_test' \
  --output-on-failure >"${REGRESSION_LOG}" 2>&1
CTEST_CODE=$?
set -e

GENERATED_AT="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
OVERALL="pass"
if [[ ${CTEST_CODE} -ne 0 ]]; then
  OVERALL="fail"
fi

python3 - "${REGRESSION_JSON}" "${GENERATED_AT}" "${OVERALL}" "${CTEST_CODE}" \
  "${REGRESSION_LOG}" <<'PY'
import json
import re
import sys
from pathlib import Path

out_path = Path(sys.argv[1])
generated_at = sys.argv[2]
overall = sys.argv[3]
ctest_code = int(sys.argv[4])
ctest_log_path = Path(sys.argv[5])
ctest_log = ctest_log_path.read_text(errors="replace")

passed_tests = re.findall(r"Test #\d+: ([^\s]+) \.+\s+Passed", ctest_log)
failed_tests = re.findall(r"^\s*\d+\s+-\s+([^\s]+)\s+\(([^)]+)\)", ctest_log, flags=re.MULTILINE)
fail_lines = [line.strip() for line in ctest_log.splitlines() if line.startswith("FAIL:")]

payload = {
    "schema_version": "1",
    "generated_at": generated_at,
    "overall_status": overall,
    "ctest_exit_code": ctest_code,
    "tests_expected": ["nexus_renderer_test", "nexus_console_tier_test"],
    "tests_passed": passed_tests,
    "failures": fail_lines,
    "artifacts": {
        "ctest_log": "artifacts/playtest/renderer_asset_regression_ctest.log",
    },
    "coverage": [
        "NEXUS asset manifest venue loading",
        "mobile mesh profile budget checks",
        "Metal embed config defaults through non-Apple stub",
        "console-tier draw batching and degradation policy",
    ],
}

ctest_summary = re.search(r"(\d+)% tests passed", ctest_log)
if ctest_summary:
    payload["ctest_summary"] = ctest_summary.group(0)

if failed_tests:
    payload["ctest_failures"] = [
        {"name": name, "status": status}
        for name, status in failed_tests
    ]

out_path.write_text(json.dumps(payload, indent=2) + "\n")
print(json.dumps(payload, indent=2))
PY

echo "==> Wrote ${REGRESSION_JSON}"

OVERALL="$(python3 -c "import json; print(json.load(open('${REGRESSION_JSON}'))['overall_status'])")"
if [[ "${OVERALL}" != "pass" ]]; then
  echo "==> nexus_renderer_asset_regression FAIL (ctest=${CTEST_CODE})" >&2
  exit 1
fi

echo "==> nexus_renderer_asset_regression PASS"
