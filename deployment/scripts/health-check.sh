#!/bin/bash
# =============================================================================
# Final Evolution Lab - Health Check Script
# =============================================================================
# Comprehensive health check for Pixel Streaming instances
#
# Usage:
#   ./health-check.sh [--url http://localhost:8888] [--verbose]
# =============================================================================
set -euo pipefail

BASE_URL="${1:-http://localhost:8888}"
VERBOSE=false
PASSED=0
FAILED=0

[[ "${2:-}" == "--verbose" ]] && VERBOSE=true

check() {
  local name="$1" result="$2" details="${3:-}"
  if [ "$result" = "pass" ]; then
    echo "  ✅ $name"
    [ "$VERBOSE" = true ] && [ -n "$details" ] && echo "     $details"
    ((PASSED++))
  else
    echo "  ❌ $name"
    [ -n "$details" ] && echo "     $details"
    ((FAILED++))
  fi
}

echo "================================================================"
echo "  FEL Health Check - $(date -u)"
echo "  Target: $BASE_URL"
echo "================================================================"

# 1. Signaling server health
HEALTH=$(curl -s -w "\n%{http_code}" "$BASE_URL/healthz" 2>/dev/null || echo "error\n000")
HTTP_CODE=$(echo "$HEALTH" | tail -1)
BODY=$(echo "$HEALTH" | head -1)

if [ "$HTTP_CODE" = "200" ]; then
  check "Signaling server" "pass" "$BODY"
else
  check "Signaling server" "fail" "HTTP $HTTP_CODE"
fi

# 2. Game modes API
MODES=$(curl -s "$BASE_URL/api/modes" 2>/dev/null || echo "")
MODE_COUNT=$(echo "$MODES" | python3 -c "import json,sys; print(len(json.load(sys.stdin).get('modes',[])))" 2>/dev/null || echo "0")
if [ "$MODE_COUNT" -ge 16 ]; then
  check "Game modes API" "pass" "$MODE_COUNT modes available"
else
  check "Game modes API" "fail" "Only $MODE_COUNT modes (expected 16+)"
fi

# 3. GPU availability
if nvidia-smi &>/dev/null; then
  GPU_INFO=$(nvidia-smi --query-gpu=name,utilization.gpu,memory.used,memory.total --format=csv,noheader 2>/dev/null)
  check "GPU available" "pass" "$GPU_INFO"
else
  check "GPU available" "fail" "nvidia-smi not found"
fi

# 4. UE5 server process
if pgrep -f "FinalEvolutionLab" &>/dev/null; then
  PID=$(pgrep -f "FinalEvolutionLab" | head -1)
  MEM=$(ps -p $PID -o rss= 2>/dev/null | awk '{printf "%.0f MB", $1/1024}')
  check "UE5 server process" "pass" "PID: $PID, Memory: $MEM"
else
  check "UE5 server process" "fail" "Process not running"
fi

# 5. Signaling service status
if systemctl is-active fel-signaling &>/dev/null; then
  check "Signaling systemd service" "pass"
else
  check "Signaling systemd service" "fail" "$(systemctl status fel-signaling 2>/dev/null | head -3)"
fi

# 6. Nginx
if systemctl is-active nginx &>/dev/null; then
  check "Nginx" "pass"
else
  check "Nginx" "fail"
fi

# 7. Disk space
FREE_GB=$(df -BG / | tail -1 | awk '{print $4}' | sed 's/G//')
if [ "$FREE_GB" -gt 10 ]; then
  check "Disk space" "pass" "${FREE_GB}GB free"
else
  check "Disk space" "fail" "Only ${FREE_GB}GB free (need 10GB+)"
fi

# 8. Memory
MEM_PCT=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100}')
if [ "$MEM_PCT" -lt 90 ]; then
  check "Memory" "pass" "${MEM_PCT}% used"
else
  check "Memory" "fail" "${MEM_PCT}% used (high)"
fi

# 9. TURN server (optional)
if systemctl is-active coturn &>/dev/null; then
  check "TURN server" "pass"
elif nc -z localhost 3478 2>/dev/null; then
  check "TURN server" "pass" "Port 3478 reachable"
else
  echo "  ⚠️  TURN server not running (optional)"
fi

# Summary
echo ""
echo "================================================================"
echo "  Results: $PASSED passed, $FAILED failed"
if [ $FAILED -eq 0 ]; then
  echo "  Status: ✅ HEALTHY"
  exit 0
else
  echo "  Status: ❌ UNHEALTHY"
  exit 1
fi
echo "================================================================"
