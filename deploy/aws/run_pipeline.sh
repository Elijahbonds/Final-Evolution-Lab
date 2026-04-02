#!/usr/bin/env bash
###############################################################################
# FEL Master Pipeline Orchestrator
# Executes fel_complete_pipeline.sh with monitoring, retry, ETA, notifications
#
# Usage:
#   ./run_pipeline.sh [--skip-cv] [--skip-install] [--resume]
###############################################################################
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# ── Config ──────────────────────────────────────────────────────────────────
MAX_RETRIES=3
RETRY_DELAY=30
PIPELINE_SCRIPT="${ROOT}/scripts/ue5_setup/fel_complete_pipeline.sh"
LOG_DIR="${ROOT}/logs"
MONITOR_PID=""
PIPELINE_PID=""

mkdir -p "$LOG_DIR"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
MAIN_LOG="${LOG_DIR}/pipeline_${TIMESTAMP}.log"
MONITOR_LOG="${LOG_DIR}/monitor_${TIMESTAMP}.log"
PROGRESS_FILE="${LOG_DIR}/pipeline_progress.json"
RESUME_FILE="${LOG_DIR}/pipeline_resume.json"

# Forward args
PIPELINE_ARGS=()
RESUME=false
while [[ $# -gt 0 ]]; do
  case $1 in
    --resume) RESUME=true; shift;;
    *) PIPELINE_ARGS+=("$1"); shift;;
  esac
done

# ── Load credentials ────────────────────────────────────────────────────────
if [ -f "$ROOT/.env" ]; then
  set -a; source "$ROOT/.env" 2>/dev/null || true; set +a
fi
if [ -f /home/ubuntu/.fel/credentials.env ]; then
  set -a; source /home/ubuntu/.fel/credentials.env 2>/dev/null || true; set +a
fi

# ── Notification Functions ──────────────────────────────────────────────────
send_notification() {
  local level="$1"  # info, success, error
  local msg="$2"
  local emoji="ℹ️"
  case $level in
    success) emoji="✅";;
    error)   emoji="🚨";;
    warning) emoji="⚠️";;
  esac

  echo "[$(date '+%H:%M:%S')] NOTIFY [$level]: $msg" | tee -a "$MAIN_LOG"

  # Slack
  if [ -n "${SLACK_WEBHOOK:-}" ]; then
    curl -s -X POST -H 'Content-type: application/json' \
      --data "{\"text\":\"${emoji} FEL Pipeline: ${msg}\"}" \
      "$SLACK_WEBHOOK" >/dev/null 2>&1 || true
  fi

  # Email via AWS SES (if awscli available)
  if [ -n "${NOTIFICATION_EMAIL:-}" ] && command -v aws &>/dev/null; then
    aws ses send-email \
      --from "fel-pipeline@finalevolutiongroup.com" \
      --destination "ToAddresses=${NOTIFICATION_EMAIL}" \
      --message "Subject={Data='FEL Pipeline: ${level}'},Body={Text={Data='${msg}'}}" \
      2>/dev/null || true
  fi

  # SMS via AWS SNS (if configured)
  if [ -n "${SNS_TOPIC_ARN:-}" ] && [ "$level" = "error" ] && command -v aws &>/dev/null; then
    aws sns publish --topic-arn "$SNS_TOPIC_ARN" \
      --message "FEL CRITICAL: ${msg}" 2>/dev/null || true
  fi
}

# ── Progress Tracking ───────────────────────────────────────────────────────
PHASES=(
  "CV Preprocessing:10"
  "UE5 Engine Build:40"
  "Asset Import:15"
  "Environment Generation:10"
  "Linux Server Cook:15"
  "iOS Cook:5"
  "Deployment Package:5"
)
TOTAL_WEIGHT=100
CURRENT_PHASE_IDX=0
PHASE_START_TIME=$SECONDS

update_progress() {
  local phase_name="$1"
  local phase_status="$2"  # running, completed, failed
  local detail="${3:-}"

  # Calculate progress percentage
  local completed_weight=0
  for ((i=0; i<CURRENT_PHASE_IDX; i++)); do
    local w=$(echo "${PHASES[$i]}" | cut -d: -f2)
    completed_weight=$((completed_weight + w))
  done
  local pct=$((completed_weight * 100 / TOTAL_WEIGHT))

  # ETA calculation
  local elapsed=$((SECONDS - PHASE_START_TIME))
  local eta="calculating..."
  if [ $pct -gt 5 ]; then
    local total_est=$((elapsed * 100 / pct))
    local remaining=$((total_est - elapsed))
    local eta_min=$((remaining / 60))
    local eta_hr=$((eta_min / 60))
    eta_min=$((eta_min % 60))
    eta="${eta_hr}h ${eta_min}m"
  fi

  # GPU stats
  local gpu_util="N/A"
  local gpu_temp="N/A"
  local gpu_mem="N/A"
  if nvidia-smi &>/dev/null; then
    gpu_util=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null | head -1)
    gpu_temp=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader 2>/dev/null | head -1)
    gpu_mem=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader 2>/dev/null | head -1)
  fi

  local mem_used=$(free -m | awk '/Mem:/ {printf "%.1f%%", $3/$2*100}')
  local disk_used=$(df -h /home | awk 'NR==2 {print $5}')

  cat > "$PROGRESS_FILE" << JSON
{
  "timestamp": "$(date -Iseconds)",
  "phase": "$phase_name",
  "phase_index": $CURRENT_PHASE_IDX,
  "total_phases": ${#PHASES[@]},
  "status": "$phase_status",
  "progress_pct": $pct,
  "eta": "$eta",
  "elapsed_seconds": $elapsed,
  "detail": "$detail",
  "gpu": {
    "utilization": "${gpu_util}%",
    "temperature": "${gpu_temp}°C",
    "memory_used": "$gpu_mem"
  },
  "system": {
    "memory_used": "$mem_used",
    "disk_used": "$disk_used"
  }
}
JSON
}

# ── GPU/System Monitor (background) ────────────────────────────────────────
start_monitor() {
  (
    while true; do
      echo "--- $(date -Iseconds) ---" >> "$MONITOR_LOG"
      if nvidia-smi &>/dev/null; then
        nvidia-smi --query-gpu=timestamp,name,utilization.gpu,utilization.memory,memory.used,memory.total,temperature.gpu,power.draw \
          --format=csv,noheader >> "$MONITOR_LOG" 2>/dev/null
      fi
      echo "MEM: $(free -m | awk '/Mem:/ {printf "%dMB/%dMB (%.1f%%)", $3, $2, $3/$2*100}')" >> "$MONITOR_LOG"
      echo "DISK: $(df -h /home | awk 'NR==2 {print $3"/"$2" ("$5")"}')" >> "$MONITOR_LOG"
      echo "LOAD: $(uptime | awk -F'load average:' '{print $2}')" >> "$MONITOR_LOG"
      sleep 30
    done
  ) &
  MONITOR_PID=$!
  echo "Monitor started (PID: $MONITOR_PID)"
}

stop_monitor() {
  if [ -n "$MONITOR_PID" ]; then
    kill $MONITOR_PID 2>/dev/null || true
    wait $MONITOR_PID 2>/dev/null || true
  fi
}

# ── Cleanup ─────────────────────────────────────────────────────────────────
cleanup() {
  stop_monitor
  echo "Pipeline orchestrator exiting."
}
trap cleanup EXIT

# ── Phase Execution with Retry ──────────────────────────────────────────────
run_with_retry() {
  local cmd="$1"
  local phase_name="$2"
  local attempt=1

  while [ $attempt -le $MAX_RETRIES ]; do
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "  Phase: $phase_name (attempt $attempt/$MAX_RETRIES)"
    echo "═══════════════════════════════════════════════════════════"

    update_progress "$phase_name" "running" "attempt $attempt"
    send_notification "info" "Starting: $phase_name (attempt $attempt)"

    if eval "$cmd" 2>&1 | tee -a "$MAIN_LOG"; then
      update_progress "$phase_name" "completed"
      send_notification "success" "Completed: $phase_name"
      return 0
    fi

    local exit_code=$?
    echo "Phase '$phase_name' failed (exit: $exit_code, attempt: $attempt)"

    if [ $attempt -lt $MAX_RETRIES ]; then
      send_notification "warning" "Retrying: $phase_name (attempt $((attempt+1))/$MAX_RETRIES)"
      echo "Retrying in ${RETRY_DELAY}s..."
      sleep $RETRY_DELAY
    fi

    ((attempt++))
  done

  update_progress "$phase_name" "failed" "all retries exhausted"
  send_notification "error" "FAILED: $phase_name after $MAX_RETRIES attempts. Check logs: $MAIN_LOG"

  # Save resume point
  cat > "$RESUME_FILE" << JSON
{
  "failed_phase": "$phase_name",
  "phase_index": $CURRENT_PHASE_IDX,
  "timestamp": "$(date -Iseconds)",
  "log_file": "$MAIN_LOG",
  "command": "$cmd"
}
JSON

  return 1
}

###############################################################################
# MAIN EXECUTION
###############################################################################

echo "═══════════════════════════════════════════════════════════"
echo "  FINAL EVOLUTION LAB — Pipeline Orchestrator"
echo "  $(date)"
echo "  Log: $MAIN_LOG"
echo "  Monitor: $MONITOR_LOG"
echo "  Progress: $PROGRESS_FILE"
echo "═══════════════════════════════════════════════════════════"
echo ""

PHASE_START_TIME=$SECONDS
send_notification "info" "Pipeline starting on $(hostname)"

# Start background monitor
start_monitor

# ── Validate environment first ──────────────────────────────────────────────
echo "── Pre-flight validation ─────────────────────────────────"
if ! bash "${SCRIPT_DIR}/validate_environment.sh"; then
  send_notification "error" "Environment validation failed! Fix issues before running pipeline."
  echo ""
  echo "❌ Environment validation failed. Fix the issues above and retry."
  exit 1
fi

# ── Check for resume ────────────────────────────────────────────────────────
if [ "$RESUME" = true ] && [ -f "$RESUME_FILE" ]; then
  RESUME_PHASE=$(jq -r '.phase_index' "$RESUME_FILE" 2>/dev/null || echo "0")
  echo "Resuming from phase index: $RESUME_PHASE"
  CURRENT_PHASE_IDX=$RESUME_PHASE
fi

# ── Execute Master Pipeline ─────────────────────────────────────────────────
echo ""
echo "── Executing Master Pipeline ─────────────────────────────"
echo "  Script: $PIPELINE_SCRIPT"
echo "  Args: ${PIPELINE_ARGS[*]:-none}"
echo ""

if [ -f "$PIPELINE_SCRIPT" ]; then
  chmod +x "$PIPELINE_SCRIPT"
  run_with_retry "bash '$PIPELINE_SCRIPT' ${PIPELINE_ARGS[*]:-}" "FEL Complete Pipeline"
  PIPELINE_EXIT=$?
else
  echo "❌ Pipeline script not found: $PIPELINE_SCRIPT"
  send_notification "error" "Pipeline script not found!"
  PIPELINE_EXIT=1
fi

# ── Summary ─────────────────────────────────────────────────────────────────
TOTAL_ELAPSED=$SECONDS
TOTAL_MIN=$((TOTAL_ELAPSED / 60))
TOTAL_HR=$((TOTAL_MIN / 60))
TOTAL_MIN=$((TOTAL_MIN % 60))

echo ""
echo "═══════════════════════════════════════════════════════════"
if [ $PIPELINE_EXIT -eq 0 ]; then
  echo "  ✅ PIPELINE COMPLETED SUCCESSFULLY"
  send_notification "success" "Pipeline completed in ${TOTAL_HR}h ${TOTAL_MIN}m! Ready for deployment."
else
  echo "  ❌ PIPELINE FAILED"
  echo "  Check logs: $MAIN_LOG"
  echo "  Resume: bash $0 --resume"
  send_notification "error" "Pipeline failed after ${TOTAL_HR}h ${TOTAL_MIN}m. Check logs."
fi
echo "  Duration: ${TOTAL_HR}h ${TOTAL_MIN}m"
echo "  Logs: $MAIN_LOG"
echo "═══════════════════════════════════════════════════════════"

stop_monitor
exit $PIPELINE_EXIT
