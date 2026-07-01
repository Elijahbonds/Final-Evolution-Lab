#!/usr/bin/env bash
# NEXUS runtime benchmark stub — mobile AAA ship gate (see NEXUS_Performance_Targets.md).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${BUILD_DIR:-${ROOT}/build-full}"
RUNTIME="${BUILD_DIR}/nexus_runtime"
DURATION_SEC="${NEXUS_BENCH_SECONDS:-10}"
MODE="${NEXUS_BENCH_MODE:-basketball_dunk}"

if [[ ! -x "${RUNTIME}" ]]; then
  echo "nexus_runtime not found — build first:" >&2
  echo "  cmake -S . -B ${BUILD_DIR} -DNEXUS_ENABLE_RENDERER=ON && cmake --build ${BUILD_DIR}" >&2
  exit 1
fi

echo "== NEXUS bench stub =="
echo "  runtime:  ${RUNTIME}"
echo "  mode:     ${MODE}"
echo "  duration: ${DURATION_SEC}s (manual window run — headless GPU TBD)"
echo ""
echo "Targets (mobile @ 1080p):"
echo "  FPS:        >= 60  (PerfMonitor smoothed)"
echo "  RAM:        < 400 MB"
echo "  Draw calls: < 750 visible"
echo "  Triangles:  <= 130k scene budget"
echo ""

export NEXUS_MESH_PROFILE="${NEXUS_MESH_PROFILE:-mobile}"
export NEXUS_DEV_STATS=0
export NEXUS_DEV_DRAW_STATS=0

echo ">> validate-only gate"
"${RUNTIME}" --validate-only --mode "${MODE}"

echo ""
echo ">> interactive bench (${DURATION_SEC}s) — close window or wait"
echo "   Tip: NEXUS_DEV_HUD=1 for fps/draws/tris overlay logs"

run_timed_bench() {
  if command -v timeout >/dev/null 2>&1; then
    timeout "${DURATION_SEC}" "${RUNTIME}" --mode "${MODE}" 2>&1
    return $?
  fi
  if command -v gtimeout >/dev/null 2>&1; then
    gtimeout "${DURATION_SEC}" "${RUNTIME}" --mode "${MODE}" 2>&1
    return $?
  fi
  # macOS ships without coreutils timeout — bounded run via background + sleep.
  "${RUNTIME}" --mode "${MODE}" 2>&1 &
  local pid=$!
  local elapsed=0
  while [[ ${elapsed} -lt ${DURATION_SEC} ]]; do
    if ! kill -0 "${pid}" 2>/dev/null; then
      wait "${pid}"
      return $?
    fi
    sleep 1
    elapsed=$((elapsed + 1))
  done
  kill "${pid}" 2>/dev/null || true
  wait "${pid}" 2>/dev/null || true
  return 124
}

run_timed_bench || {
  code=$?
  if [[ ${code} -eq 124 ]]; then
    echo "bench: completed ${DURATION_SEC}s run (timeout expected)"
    exit 0
  fi
  exit "${code}"
}

echo "bench: completed"
