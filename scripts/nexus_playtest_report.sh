#!/usr/bin/env bash
# Human + machine-readable playtest summary for Cursor agents.
# Usage:
#   ./scripts/nexus_playtest_report.sh [--input PATH] [--json]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INPUT="${ROOT}/artifacts/playtest/latest.json"
EMIT_JSON=0

for arg in "$@"; do
  case "$arg" in
    --input=*) INPUT="${arg#*=}" ;;
    --input) shift; INPUT="${1:?--input requires path}" ;;
    --json) EMIT_JSON=1 ;;
    -h|--help)
      echo "Usage: $0 [--input artifacts/playtest/latest.json] [--json]"
      exit 0
      ;;
  esac
done

while [[ $# -gt 0 ]]; do
  case "$1" in
    --input) INPUT="$2"; shift 2 ;;
    --json) EMIT_JSON=1; shift ;;
    *) shift ;;
  esac
done

if [[ ! -f "${INPUT}" ]]; then
  echo "error: playtest artifact not found: ${INPUT}" >&2
  echo "Run: ./scripts/nexus_playtest.sh" >&2
  exit 1
fi

REPORT_JSON="${ROOT}/artifacts/playtest/report.json"
mkdir -p "$(dirname "${REPORT_JSON}")"

if ! command -v python3 >/dev/null 2>&1; then
  echo "error: python3 required for playtest report" >&2
  exit 1
fi

python3 - "${INPUT}" "${REPORT_JSON}" "${EMIT_JSON}" <<'PY'
import json
import sys
from pathlib import Path

input_path = Path(sys.argv[1])
report_path = Path(sys.argv[2])
emit_json = sys.argv[3] == "1"

data = json.loads(input_path.read_text())
playtest = data.get("playtest", {})
env = data.get("environment", {})
runtime = data.get("runtime", {})
gameplay = data.get("gameplay_test", {})

summary = {
    "schema_version": "1",
    "source": str(input_path.relative_to(input_path.parents[2]) if len(input_path.parents) > 2 else input_path),
    "generated_at": data.get("generated_at"),
    "overall_status": data.get("overall_status"),
    "mode": playtest.get("mode"),
    "venue": playtest.get("venue"),
    "duration_sec": playtest.get("duration_sec"),
    "triangle_count_validate": env.get("triangle_count"),
    "triangle_count_runtime": runtime.get("triangle_count"),
    "fps_last": runtime.get("fps_last"),
    "visible_draws": runtime.get("visible_draws"),
    "validate_status": env.get("validate_status"),
    "runtime_status": runtime.get("status"),
    "gameplay_test_status": gameplay.get("status"),
    "mode_state_present": data.get("mode_state") is not None and data.get("mode_state") != "null",
    "agent_response_count": len(data.get("agent_responses") or []),
    "cursor_read_path": "artifacts/playtest/latest.json",
}

report_path.write_text(json.dumps(summary, indent=2) + "\n")

lines = [
    "NEXUS Playtest Report",
    f"  status:        {summary['overall_status']}",
    f"  mode/venue:    {summary['mode']} @ {summary['venue']}",
    f"  validate:      {summary['validate_status']} (tris={summary['triangle_count_validate']})",
    f"  gameplay_test: {summary['gameplay_test_status']}",
    f"  runtime:       {summary['runtime_status']} (fps={summary['fps_last']}, draws={summary['visible_draws']})",
    f"  mode_state:    {'yes' if summary['mode_state_present'] else 'no'}",
    f"  agent_msgs:    {summary['agent_response_count']}",
    f"  artifact:      {summary['cursor_read_path']}",
    f"  machine:       {report_path}",
]

if emit_json:
    print(json.dumps(summary, indent=2))
else:
    print("\n".join(lines))
PY
