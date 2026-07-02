#!/usr/bin/env bash
# NEXUS gameplay regression — headless ctest + renderer-lite assets + gameplay artifact for agents.
# Usage: ./scripts/nexus_gameplay_regression.sh [--skip-build] [--skip-renderer-assets]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HEADLESS_DIR="${ROOT}/build-headless"
ARTIFACT_DIR="${ROOT}/artifacts/playtest"
REGRESSION_JSON="${ARTIFACT_DIR}/gameplay_regression.json"
REGRESSION_LOG="${ARTIFACT_DIR}/gameplay_regression_run.log"
RENDERER_ASSET_JSON="${ARTIFACT_DIR}/renderer_asset_regression.json"
SKIP_BUILD=0
RUN_RENDERER_ASSETS=1

for arg in "$@"; do
  case "$arg" in
    --skip-build) SKIP_BUILD=1 ;;
    --skip-renderer-assets) RUN_RENDERER_ASSETS=0 ;;
    -h|--help)
      echo "Usage: $0 [--skip-build] [--skip-renderer-assets]"
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

if [[ -z "${CXX:-}" ]] && command -v g++ >/dev/null 2>&1; then
  export CXX=g++
fi

if [[ "${SKIP_BUILD}" -eq 0 ]]; then
  echo "==> Configure + build full headless test matrix"
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

RENDERER_ASSET_CODE=0
if [[ "${RUN_RENDERER_ASSETS}" -eq 1 ]]; then
  echo "==> nexus_renderer_asset_regression (manifest/mobile mesh matrix)"
  RENDERER_ARGS=()
  if [[ "${SKIP_BUILD}" -eq 1 ]]; then
    RENDERER_ARGS+=(--skip-build)
  fi
  set +e
  "${ROOT}/scripts/nexus_renderer_asset_regression.sh" "${RENDERER_ARGS[@]}"
  RENDERER_ASSET_CODE=$?
  set -e
else
  echo "==> nexus_renderer_asset_regression skipped (--skip-renderer-assets)"
fi

GENERATED_AT="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
OVERALL="pass"
if [[ ${CTEST_CODE} -ne 0 || ${GAMEPLAY_CODE} -ne 0 || ${RENDERER_ASSET_CODE} -ne 0 ]]; then
  OVERALL="fail"
fi

python3 - "${REGRESSION_JSON}" "${GENERATED_AT}" "${OVERALL}" "${CTEST_CODE}" "${GAMEPLAY_CODE}" \
  "${RENDERER_ASSET_CODE}" "${RUN_RENDERER_ASSETS}" "${REGRESSION_LOG}" "${CTEST_LOG}" \
  "${RENDERER_ASSET_JSON}" \
  <<'PY'
import json
import re
import sys
from pathlib import Path

out_path = Path(sys.argv[1])
generated_at = sys.argv[2]
overall = sys.argv[3]
ctest_code = int(sys.argv[4])
gameplay_code = int(sys.argv[5])
renderer_asset_code = int(sys.argv[6])
run_renderer_assets = int(sys.argv[7])
gameplay_log = Path(sys.argv[8]).read_text(errors="replace")
ctest_log = Path(sys.argv[9]).read_text(errors="replace")
renderer_asset_json = Path(sys.argv[10])

production_modes = [
    "basketball_h2h", "basketball_dunk", "basketball_3v3", "court_carnival",
    "karate_h2h", "karate_endless", "baseball", "football", "soccer", "golf",
    "tennis", "volleyball", "gymnastics", "surfing", "skateboarding",
    "snowboarding", "brain_brawl", "who_scene_it",
]

probe_modes = re.findall(r"^PROBE: production_mode mode_id=([a-z0-9_]+)\b", gameplay_log, flags=re.MULTILINE)
modes_exercised = [m for m in production_modes if m in set(probe_modes)]
missing_modes = [m for m in production_modes if m not in set(probe_modes)]
fail_lines = [line.strip() for line in gameplay_log.splitlines() if line.startswith("FAIL:")]
pass_banner = "PASS: nexus_gameplay_test" in gameplay_log

if overall == "pass" and (missing_modes or not pass_banner):
    overall = "fail"

payload = {
    "schema_version": "1",
    "generated_at": generated_at,
    "overall_status": overall,
    "ctest_exit_code": ctest_code,
    "gameplay_test_exit_code": gameplay_code,
    "renderer_asset_regression_exit_code": renderer_asset_code,
    "production_modes_expected": len(production_modes),
    "production_modes_seen_in_log": len(modes_exercised),
    "production_modes": modes_exercised,
    "production_modes_missing": missing_modes,
    # Back-compat fields for older agent readers; prefer production_* above.
    "sprint_live_modes_expected": len(production_modes),
    "sprint_live_modes_seen_in_log": len(modes_exercised),
    "sprint_live_modes": modes_exercised,
    "failures": fail_lines,
    "pass_banner": pass_banner,
    "artifacts": {
        "gameplay_log": "artifacts/playtest/gameplay_regression_run.log",
        "ctest_log": "artifacts/playtest/gameplay_regression_ctest.log",
        "renderer_asset_json": "artifacts/playtest/renderer_asset_regression.json",
        "renderer_asset_ctest_log": "artifacts/playtest/renderer_asset_regression_ctest.log",
    },
}

if run_renderer_assets == 1 and renderer_asset_json.exists():
    renderer_payload = json.loads(renderer_asset_json.read_text())
    payload["renderer_asset_regression"] = {
        "overall_status": renderer_payload.get("overall_status"),
        "ctest_summary": renderer_payload.get("ctest_summary"),
        "tests_passed": renderer_payload.get("tests_passed", []),
        "coverage": renderer_payload.get("coverage", []),
    }
elif run_renderer_assets == 1:
    payload["renderer_asset_regression"] = {
        "overall_status": "fail",
        "error": "renderer asset regression did not write its JSON artifact",
    }
else:
    payload["renderer_asset_regression"] = {"overall_status": "skipped"}

ctest_summary = re.search(r"(\d+)% tests passed", ctest_log)
if ctest_summary:
    payload["ctest_summary"] = ctest_summary.group(0)

failed_tests = re.findall(r"^\s*\d+\s+-\s+([^\s]+)\s+\(([^)]+)\)", ctest_log, flags=re.MULTILINE)
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
  echo "==> nexus_gameplay_regression FAIL (ctest=${CTEST_CODE}, gameplay_test=${GAMEPLAY_CODE})" >&2
  exit 1
fi

echo "==> nexus_gameplay_regression PASS"
