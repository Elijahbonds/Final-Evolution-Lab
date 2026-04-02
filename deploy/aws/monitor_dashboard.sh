#!/usr/bin/env bash
###############################################################################
# FEL Real-Time Monitoring Dashboard
# Shows pipeline progress, GPU stats, system metrics in a live terminal view
#
# Usage: ./monitor_dashboard.sh [--watch]
###############################################################################

ROOT="/home/ubuntu/rork-final-evolution-lab"
PROGRESS_FILE="${ROOT}/logs/pipeline_progress.json"
MONITOR_LOG="${ROOT}/logs/monitor_*.log"
WATCH_MODE=false

[ "${1:-}" = "--watch" ] && WATCH_MODE=true

render_dashboard() {
  clear
  local COLS=$(tput cols 2>/dev/null || echo 80)
  local LINE=$(printf '%*s' "$COLS" '' | tr ' ' '═')

  echo "$LINE"
  echo "  🎮 FINAL EVOLUTION LAB — Pipeline Monitor"
  echo "  $(date '+%Y-%m-%d %H:%M:%S')"
  echo "$LINE"
  echo ""

  # ── Pipeline Progress ───
  if [ -f "$PROGRESS_FILE" ]; then
    local phase=$(jq -r '.phase // "Unknown"' "$PROGRESS_FILE" 2>/dev/null)
    local status=$(jq -r '.status // "unknown"' "$PROGRESS_FILE" 2>/dev/null)
    local pct=$(jq -r '.progress_pct // 0' "$PROGRESS_FILE" 2>/dev/null)
    local eta=$(jq -r '.eta // "N/A"' "$PROGRESS_FILE" 2>/dev/null)
    local elapsed=$(jq -r '.elapsed_seconds // 0' "$PROGRESS_FILE" 2>/dev/null)
    local detail=$(jq -r '.detail // ""' "$PROGRESS_FILE" 2>/dev/null)
    local phase_idx=$(jq -r '.phase_index // 0' "$PROGRESS_FILE" 2>/dev/null)
    local total_phases=$(jq -r '.total_phases // 7' "$PROGRESS_FILE" 2>/dev/null)

    echo "  ── Pipeline Status ──"
    echo ""

    # Status icon
    local status_icon="🔄"
    case $status in
      completed) status_icon="✅";;
      failed)    status_icon="❌";;
      running)   status_icon="🔄";;
    esac

    echo "    Phase:    $status_icon $phase ($((phase_idx+1))/$total_phases)"
    echo "    Status:   $status"
    echo "    Detail:   $detail"
    echo ""

    # Progress bar
    local bar_width=40
    local filled=$((pct * bar_width / 100))
    local empty=$((bar_width - filled))
    local bar=""
    for ((i=0; i<filled; i++)); do bar="${bar}█"; done
    for ((i=0; i<empty; i++)); do bar="${bar}░"; done
    echo "    Progress: [${bar}] ${pct}%"
    echo ""

    local e_hr=$((elapsed / 3600))
    local e_min=$(( (elapsed % 3600) / 60))
    echo "    Elapsed:  ${e_hr}h ${e_min}m"
    echo "    ETA:      $eta"
  else
    echo "  ⏳ No pipeline data yet (waiting for pipeline to start)"
  fi

  echo ""

  # ── GPU Stats ──────────
  echo "  ── GPU Stats ──"
  echo ""
  if nvidia-smi &>/dev/null; then
    nvidia-smi --query-gpu=name,utilization.gpu,memory.used,memory.total,temperature.gpu,power.draw \
      --format=csv,noheader 2>/dev/null | while IFS=, read -r name util mem_used mem_total temp power; do
      echo "    GPU:      $name"
      echo "    Util:     $util"
      echo "    Memory:   $mem_used / $mem_total"
      echo "    Temp:     $temp"
      echo "    Power:    $power"
    done
  else
    echo "    GPU: Not available"
  fi

  echo ""

  # ── System Resources ───
  echo "  ── System Resources ──"
  echo ""
  echo "    CPU Load: $(uptime | awk -F'load average:' '{print $2}')"
  echo "    Memory:   $(free -m | awk '/Mem:/ {printf "%dMB / %dMB (%.1f%%)", $3, $2, $3/$2*100}')"
  echo "    Disk:     $(df -h /home | awk 'NR==2 {print $3 " / " $2 " (" $5 ")"}')"
  echo ""

  # ── Recent Log Lines ───
  echo "  ── Recent Log ──"
  echo ""
  local latest_log=$(ls -t ${ROOT}/logs/pipeline_*.log 2>/dev/null | head -1)
  if [ -n "$latest_log" ]; then
    tail -5 "$latest_log" 2>/dev/null | sed 's/^/    /'
  else
    echo "    No pipeline log yet"
  fi

  echo ""

  # ── Active Processes ───
  echo "  ── FEL Processes ──"
  echo ""
  ps aux | grep -E "(fel_complete|cook_fel|install_ue5|import_all|node|nginx)" | grep -v grep | \
    awk '{printf "    %-8s %-6s %s %s\n", $1, $2, $3"%", $11}' | head -10

  echo ""
  echo "$LINE"

  if [ "$WATCH_MODE" = true ]; then
    echo "  Refreshing every 5 seconds. Press Ctrl+C to exit."
  fi
}

if [ "$WATCH_MODE" = true ]; then
  while true; do
    render_dashboard
    sleep 5
  done
else
  render_dashboard
fi
