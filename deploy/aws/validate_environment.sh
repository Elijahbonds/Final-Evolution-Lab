#!/usr/bin/env bash
###############################################################################
# FEL Environment Validation — Verify GPU, drivers, dependencies
###############################################################################
set -uo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0; FAIL=0; WARN=0

check() {
  local desc="$1"; shift
  if "$@" &>/dev/null; then
    echo -e "  ${GREEN}✅ PASS${NC}  $desc"
    ((PASS++))
  else
    echo -e "  ${RED}❌ FAIL${NC}  $desc"
    ((FAIL++))
  fi
}

check_warn() {
  local desc="$1"; shift
  if "$@" &>/dev/null; then
    echo -e "  ${GREEN}✅ PASS${NC}  $desc"
    ((PASS++))
  else
    echo -e "  ${YELLOW}⚠️  WARN${NC}  $desc"
    ((WARN++))
  fi
}

echo "═══════════════════════════════════════════════════════════"
echo "  Final Evolution Lab — Environment Validation"
echo "  $(date)"
echo "═══════════════════════════════════════════════════════════"
echo ""

# ── GPU & Drivers ───────────────────────────────────────────────
echo "── GPU & Drivers ──────────────────────────────────────────"
check "NVIDIA GPU detected" bash -c "lspci | grep -i nvidia"
check "nvidia-smi available" which nvidia-smi
check "NVIDIA driver loaded" nvidia-smi
check_warn "CUDA nvcc available" which nvcc
check_warn "Vulkan available" bash -c "which vulkaninfo && vulkaninfo --summary 2>/dev/null | grep -q apiVersion"

if nvidia-smi &>/dev/null; then
  echo ""
  echo "  GPU Info:"
  nvidia-smi --query-gpu=name,driver_version,memory.total,temperature.gpu \
    --format=csv,noheader 2>/dev/null | sed 's/^/    /'
  DRIVER_VER=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -1)
  MAJOR_VER=$(echo "$DRIVER_VER" | cut -d. -f1)
  if [ "${MAJOR_VER:-0}" -ge 535 ]; then
    echo -e "  ${GREEN}✅ PASS${NC}  Driver version >= 535 ($DRIVER_VER)"
    ((PASS++))
  else
    echo -e "  ${RED}❌ FAIL${NC}  Driver version < 535 ($DRIVER_VER) — need 535+"
    ((FAIL++))
  fi
fi

echo ""

# ── System Resources ────────────────────────────────────────────
echo "── System Resources ───────────────────────────────────────"
TOTAL_RAM_MB=$(free -m | awk '/Mem:/ {print $2}')
check "RAM >= 24GB" bash -c "[ $TOTAL_RAM_MB -ge 24000 ]"
DISK_FREE_GB=$(df -BG /home | awk 'NR==2 {gsub(/G/,"",$4); print $4}')
check "Disk >= 200GB free" bash -c "[ ${DISK_FREE_GB:-0} -ge 200 ]"
CPU_CORES=$(nproc)
check "CPU >= 8 cores" bash -c "[ $CPU_CORES -ge 8 ]"

echo "  RAM: ${TOTAL_RAM_MB}MB | Disk Free: ${DISK_FREE_GB}GB | CPU Cores: ${CPU_CORES}"
echo ""

# ── Build Tools ─────────────────────────────────────────────────
echo "── Build Tools ──────────────────────────────────────────────"
check "git" which git
check "gcc/g++" which g++
check "cmake" which cmake
check "clang" which clang
check "python3" which python3
check "pip3" which pip3
check "node" which node
check "npm" which npm
check "docker" which docker
check_warn "docker-compose" bash -c "which docker-compose || docker compose version"

echo ""

# ── Project Files ───────────────────────────────────────────────
echo "── Project Files ────────────────────────────────────────────"
ROOT="/home/ubuntu/rork-final-evolution-lab"
check "Project directory exists" test -d "$ROOT"
check "Master pipeline script" test -f "$ROOT/scripts/ue5_setup/fel_complete_pipeline.sh"
check "UE5 install script" test -f "$ROOT/scripts/ue5_setup/install_ue5_linux.sh"
check "CV preprocessing pipeline" test -f "$ROOT/scripts/cv_preprocessing/preprocessing_pipeline.py"
check "AI asset pipeline" test -f "$ROOT/scripts/ai_asset_pipeline/local_first_pipeline.py"
check "Streaming docker-compose" test -f "$ROOT/streaming/docker-compose.yml"
check "Frontend source" test -d "$ROOT/streaming/frontend/src"
check "Signalling server" test -f "$ROOT/streaming/signalling/server.js"
check "Deploy scripts" test -d "$ROOT/deploy/aws"
check_warn ".env file" test -f "$ROOT/.env"
check_warn "Source videos" test -d "$ROOT/SourceVideos/Instagram"

echo ""

# ── Network Ports ───────────────────────────────────────────────
echo "── Network Ports ────────────────────────────────────────────"
for PORT in 3000 8888 8889 3478; do
  if ! ss -tlnp | grep -q ":${PORT} "; then
    echo -e "  ${GREEN}✅ PASS${NC}  Port $PORT is available"
    ((PASS++))
  else
    echo -e "  ${YELLOW}⚠️  WARN${NC}  Port $PORT is in use"
    ((WARN++))
  fi
done

echo ""

# ── Credentials ─────────────────────────────────────────────────
echo "── Credentials ──────────────────────────────────────────────"
if [ -f "$ROOT/.env" ]; then
  source "$ROOT/.env" 2>/dev/null || true
fi
if [ -f /home/ubuntu/.fel/credentials.env ]; then
  source /home/ubuntu/.fel/credentials.env 2>/dev/null || true
fi

check_warn "GITHUB_TOKEN set" bash -c "[ -n '${GITHUB_TOKEN:-}' ]"
check_warn "MESHY_API_KEY set" bash -c "[ -n '${MESHY_API_KEY:-}' ]"
check_warn "LUMA_API_KEY set" bash -c "[ -n '${LUMA_API_KEY:-}' ]"

echo ""

# ── Summary ─────────────────────────────────────────────────────
echo "═══════════════════════════════════════════════════════════"
echo -e "  Results: ${GREEN}${PASS} passed${NC}, ${RED}${FAIL} failed${NC}, ${YELLOW}${WARN} warnings${NC}"

if [ $FAIL -eq 0 ]; then
  echo -e "  ${GREEN}✅ Environment is ready for FEL pipeline!${NC}"
  echo ""
  echo "  Next: bash /home/ubuntu/rork-final-evolution-lab/deploy/aws/run_pipeline.sh"
else
  echo -e "  ${RED}❌ Environment has issues that need fixing.${NC}"
  echo ""
  echo "  Common fixes:"
  echo "    GPU driver: sudo apt install nvidia-driver-535 && sudo reboot"
  echo "    CUDA: sudo apt install cuda-toolkit-12-3"
  echo "    Project: scp -r local-project ubuntu@<IP>:/home/ubuntu/"
fi
echo "═══════════════════════════════════════════════════════════"

# Write validation result for pipeline consumption
RESULT_FILE="$ROOT/deploy/aws/validation_result.json"
cat > "$RESULT_FILE" << JSON
{
  "timestamp": "$(date -Iseconds)",
  "hostname": "$(hostname)",
  "passed": $PASS,
  "failed": $FAIL,
  "warnings": $WARN,
  "gpu_detected": $(nvidia-smi &>/dev/null && echo true || echo false),
  "ram_mb": $TOTAL_RAM_MB,
  "disk_free_gb": ${DISK_FREE_GB:-0},
  "cpu_cores": $CPU_CORES,
  "ready": $([ $FAIL -eq 0 ] && echo true || echo false)
}
JSON

exit $FAIL
