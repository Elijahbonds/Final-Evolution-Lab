#!/usr/bin/env bash
# NEXUS playtest — venue visibility + agent loop for Cursor agents.
# Usage:
#   ./scripts/nexus_playtest.sh [--mode MODE] [--venue VENUE] [--duration SEC] [--skip-build]
# Writes: artifacts/playtest/latest.json (+ dev_stats_tick.json during runtime window)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${BUILD_DIR:-${ROOT}/build-full}"
HEADLESS_BUILD_DIR="${ROOT}/build-headless"
ARTIFACT_DIR="${ROOT}/artifacts/playtest"
LATEST_JSON="${ARTIFACT_DIR}/latest.json"
DEV_EXPORT="${ARTIFACT_DIR}/dev_stats_tick.json"
RUNTIME_LOG="${ARTIFACT_DIR}/runtime.log"

MODE="${NEXUS_PLAYTEST_MODE:-basketball_dunk}"
VENUE="${NEXUS_PLAYTEST_VENUE:-venice_beach}"
DURATION_SEC="${NEXUS_PLAYTEST_DURATION:-5}"
SKIP_BUILD=0

usage() {
  cat <<'EOF'
Usage: ./scripts/nexus_playtest.sh [options]

Options:
  --mode MODE         Arena mode id (default: basketball_dunk)
  --venue VENUE       Venue hint / token (default: venice_beach)
  --duration SEC      Runtime window seconds; 0 = validate + gameplay only (default: 5)
  --skip-build        Skip cmake build (expects build-full + build-headless binaries)

Artifacts:
  artifacts/playtest/latest.json        Aggregated playtest snapshot for agents
  artifacts/playtest/dev_stats_tick.json Last engine tick export (runtime window)
  artifacts/playtest/runtime.log          nexus_runtime stderr/stdout (runtime window)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode) MODE="$2"; shift 2 ;;
    --venue) VENUE="$2"; shift 2 ;;
    --duration) DURATION_SEC="$2"; shift 2 ;;
    --skip-build) SKIP_BUILD=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown arg: $1" >&2; usage >&2; exit 2 ;;
  esac
done

mkdir -p "${ARTIFACT_DIR}"
GENERATED_AT="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
RUNTIME="${BUILD_DIR}/nexus_runtime"
GAMEPLAY_TEST="${HEADLESS_BUILD_DIR}/nexus_gameplay_test"

export NEXUS_MESH_PROFILE="${NEXUS_MESH_PROFILE:-mobile}"
export NEXUS_DEV_STATS=0
export NEXUS_DEV_DRAW_STATS=0
export SDL_VIDEODRIVER="${SDL_VIDEODRIVER:-dummy}"

cd "${ROOT}"

if [[ "${SKIP_BUILD}" -eq 0 ]]; then
  echo "==> Configure + build (full renderer)"
  cmake -S . -B "${BUILD_DIR}" -DNEXUS_ENABLE_RENDERER=ON
  cmake --build "${BUILD_DIR}" -j"$(sysctl -n hw.ncpu 2>/dev/null || nproc)"
  echo "==> Configure + build (headless gameplay)"
  cmake -S . -B "${HEADLESS_BUILD_DIR}" -DNEXUS_ENABLE_RENDERER=OFF
  cmake --build "${HEADLESS_BUILD_DIR}" -j"$(sysctl -n hw.ncpu 2>/dev/null || nproc)" --target nexus_gameplay_test
fi

if [[ ! -x "${RUNTIME}" ]]; then
  echo "error: ${RUNTIME} missing — run without --skip-build" >&2
  exit 1
fi
if [[ ! -x "${GAMEPLAY_TEST}" ]]; then
  echo "error: ${GAMEPLAY_TEST} missing — run without --skip-build" >&2
  exit 1
fi

echo "==> Phase: validate-only (venue mesh + tris budget)"
VALIDATE_LOG="${ARTIFACT_DIR}/validate.log"
set +e
"${RUNTIME}" --validate-only --mode "${MODE}" --venue "${VENUE}" >"${VALIDATE_LOG}" 2>&1
VALIDATE_CODE=$?
set -e
VALIDATE_LINE="$(python3 - "${VALIDATE_LOG}" <<'PY'
import sys
from pathlib import Path

line = ""
for candidate in Path(sys.argv[1]).read_text(errors="replace").splitlines():
    if candidate.startswith("[NEXUS] validate-only OK"):
        line = candidate
print(line)
PY
)"
VALIDATE_STATUS="fail"
if [[ ${VALIDATE_CODE} -eq 0 && -n "${VALIDATE_LINE}" ]]; then
  VALIDATE_STATUS="pass"
fi

echo "==> Phase: headless gameplay smoke (dunk lifecycle)"
set +e
"${GAMEPLAY_TEST}" >"${ARTIFACT_DIR}/gameplay_test.log" 2>&1
GAMEPLAY_CODE=$?
set -e
GAMEPLAY_STATUS="fail"
if [[ ${GAMEPLAY_CODE} -eq 0 ]]; then
  GAMEPLAY_STATUS="pass"
fi

RUNTIME_STATUS="skipped"
rm -f "${DEV_EXPORT}" "${RUNTIME_LOG}"

if [[ "${DURATION_SEC}" -gt 0 ]]; then
  echo "==> Phase: runtime window (${DURATION_SEC}s, NEXUS_PLAYTEST_EXPORT=1)"
  export NEXUS_PLAYTEST_EXPORT=1
  export NEXUS_PLAYTEST_EXPORT_PATH="${DEV_EXPORT}"
  export NEXUS_PLAYTEST_MODE="${MODE}"
  export NEXUS_PLAYTEST_VENUE="${VENUE}"

  AGENT_FIFO="$(mktemp -u "${TMPDIR:-/tmp}/nexus-playtest-agent.XXXXXX")"
  mkfifo "${AGENT_FIFO}"
  (
    sleep 1
    python3 - "${MODE}" <<'PY'
import json
import sys

mode = sys.argv[1]
actions = {
    "basketball_h2h": ("fel.pickup.action", {"action": "shoot", "timing": 0.95, "success": True}),
    "basketball_dunk": ("fel.dunk.charge_begin", {}),
    "basketball_3v3": ("fel.sport.pulse", {"success": True, "timing": 0.95, "shot_type": "three_pointer"}),
    "court_carnival": ("fel.carnival.trigger_pad", {"pad": "trick_shot", "timing": 0.9}),
    "karate_h2h": ("fel.sport.pulse", {"success": True, "timing": 0.93, "action": "heavy_strike"}),
    "karate_endless": ("fel.karate.action", {"action": "heavy_strike"}),
    "baseball": ("fel.sport.pulse", {"success": True, "timing": 0.94, "sport_action": "home_run"}),
    "football": ("fel.sport.pulse", {"success": True, "timing": 0.88, "play_type": "touchdown"}),
    "soccer": ("fel.sport.pulse", {"success": True, "timing": 0.91, "sport_action": "penalty"}),
    "golf": ("fel.sport.pulse", {"success": True, "timing": 0.93, "club": "putt"}),
    "tennis": ("fel.sport.pulse", {"success": True, "timing": 0.94, "shot_type": "ace"}),
    "volleyball": ("fel.sport.pulse", {"success": True, "timing": 0.94, "rally_type": "ace_serve"}),
    "gymnastics": ("fel.gymnastics.tap", {"timing": 0.92, "difficulty": 0.75}),
    "surfing": ("fel.surf.carve", {"timing": 0.93, "wave_difficulty": 0.75}),
    "skateboarding": ("fel.skate.trick", {"difficulty": 0.85, "combo_multiplier": 2}),
    "snowboarding": ("fel.snow.carve", {"timing": 0.93, "line_difficulty": 0.75}),
    "brain_brawl": ("fel.brain.answer", {"correct": True, "response_time": 5.0, "category": "BodyIQ"}),
    "who_scene_it": ("fel.scene.buzz_in", {"timing": 0.91}),
}
command, params = actions.get(mode, ("fel.arena.mode_input", {"action": "browse"}))
messages = [
    {"type": "command", "id": "pt1", "payload": {"command": "fel.arena.start_session", "params": {"mode_id": mode, "user_id": "playtest"}}},
    {"type": "command", "id": "pt2", "payload": {"command": command, "params": params}},
    {"type": "query", "id": "pt3", "payload": {"query": "fel.query.get_mode_state"}},
    {"type": "query", "id": "pt4", "payload": {"query": "fel.query.get_session_state"}},
]
for message in messages:
    print(json.dumps(message, separators=(",", ":")), flush=True)
PY
    sleep "${DURATION_SEC}"
  ) >"${AGENT_FIFO}" &
  FEED_PID=$!

  set +e
  "${RUNTIME}" --mode "${MODE}" --venue "${VENUE}" <"${AGENT_FIFO}" >"${RUNTIME_LOG}" 2>&1 &
  RUNTIME_PID=$!

  ELAPSED=0
  while [[ ${ELAPSED} -lt ${DURATION_SEC} ]]; do
    if ! kill -0 "${RUNTIME_PID}" 2>/dev/null; then
      break
    fi
    sleep 1
    ELAPSED=$((ELAPSED + 1))
  done
  kill "${RUNTIME_PID}" 2>/dev/null || true
  wait "${RUNTIME_PID}" 2>/dev/null || true
  kill "${FEED_PID}" 2>/dev/null || true
  wait "${FEED_PID}" 2>/dev/null || true
  rm -f "${AGENT_FIFO}"
  set -e

  if [[ -f "${DEV_EXPORT}" ]]; then
    RUNTIME_STATUS="pass"
  else
    RUNTIME_STATUS="no_export"
  fi
fi

python3 - "${LATEST_JSON}" <<PY
import json
import re
from datetime import datetime, timezone
from pathlib import Path

latest = Path("${LATEST_JSON}")
validate_log = Path("${ARTIFACT_DIR}/validate.log")
dev_export = Path("${DEV_EXPORT}")

validate_line = ""
if validate_log.exists():
    for line in validate_log.read_text().splitlines():
        if line.startswith("[NEXUS] validate-only OK"):
            validate_line = line

def grab(pattern, text):
    m = re.search(pattern, text)
    return m.group(1) if m else None

env = {
    "validate_status": "${VALIDATE_STATUS}",
    "venue_key": grab(r" venue=([^ ]+)", validate_line),
    "mesh_path": grab(r" mesh=([^ ]+)", validate_line),
    "mesh_profile": grab(r" profile=([^ ]+)", validate_line),
    "vertex_count": int(v) if (v := grab(r" verts=([0-9]+)", validate_line)) else None,
    "triangle_count": int(t) if (t := grab(r" tris=([0-9]+)", validate_line)) else None,
}

runtime = {"status": "${RUNTIME_STATUS}"}
agent_responses = []
mode_state = None
agent_response_errors = []
if dev_export.exists():
    tick = json.loads(dev_export.read_text())
    stats = tick.get("dev_stats", {})
    runtime.update({
        "fps_last": stats.get("fps"),
        "frame_time_ms": stats.get("frame_time_ms"),
        "visible_draws": stats.get("visible_draws"),
        "culled_draws": stats.get("culled_draws"),
        "triangle_count": stats.get("triangle_count"),
        "within_draw_budget": stats.get("within_draw_budget"),
        "tick_frames": tick.get("frame"),
    })
    agent_responses = tick.get("agent_responses", [])
    agent_response_errors = [
        {
            "id": response.get("id"),
            "error": response.get("error"),
            "status": response.get("status"),
        }
        for response in agent_responses
        if response.get("status") != "ok"
    ]
    for response in agent_responses:
        if response.get("id") == "pt3" and response.get("status") == "ok":
            mode_state = response.get("payload")
            break

overall = "pass"
if env["validate_status"] != "pass" or "${GAMEPLAY_STATUS}" != "pass":
    overall = "fail"
if int("${DURATION_SEC}") > 0:
    if runtime["status"] != "pass" or mode_state is None:
        overall = "fail"
    elif mode_state.get("mode_id") != "${MODE}":
        overall = "fail"
    if agent_response_errors:
        overall = "fail"

doc = {
    "schema_version": "1",
    "generated_at": "${GENERATED_AT}",
    "overall_status": overall,
    "playtest": {
        "mode": "${MODE}",
        "venue": "${VENUE}",
        "duration_sec": int("${DURATION_SEC}"),
        "build_dir": "${BUILD_DIR}",
        "mesh_profile": "${NEXUS_MESH_PROFILE}",
    },
    "environment": env,
    "runtime": runtime,
    "gameplay_test": {"status": "${GAMEPLAY_STATUS}", "exit_code": int("${GAMEPLAY_CODE}")},
    "mode_state": mode_state,
    "agent_responses": agent_responses,
    "agent_response_errors": agent_response_errors,
    "artifacts": {
        "latest_json": "artifacts/playtest/latest.json",
        "dev_stats_tick": "artifacts/playtest/dev_stats_tick.json",
        "validate_log": "artifacts/playtest/validate.log",
        "runtime_log": "artifacts/playtest/runtime.log",
        "gameplay_test_log": "artifacts/playtest/gameplay_test.log",
    },
}

latest.write_text(json.dumps(doc, indent=2) + "\\n")
PY

echo "==> Wrote ${LATEST_JSON}"
"${ROOT}/scripts/nexus_playtest_report.sh" --input "${LATEST_JSON}"

OVERALL="$(python3 -c "import json; print(json.load(open('${LATEST_JSON}'))['overall_status'])")"
if [[ "${OVERALL}" != "pass" ]]; then
  exit 1
fi

echo "==> nexus_playtest PASS"
