#!/usr/bin/env bash
###############################################################################
# install_ue5_linux.sh — Download and build Unreal Engine 5.4 from source
# for Final Evolution Lab on Linux (GPU-enabled machine required for rendering)
#
# Prerequisites:
#   - GitHub account linked to Epic Games (https://www.unrealengine.com/ue-on-github)
#   - Git with GitHub authentication configured
#   - ~200GB free disk space
#   - Ubuntu 22.04+ or similar
#
# Usage:
#   export GITHUB_TOKEN="ghp_your_token_here"  # or use SSH keys
#   ./install_ue5_linux.sh [--branch 5.4] [--install-dir /opt/UnrealEngine]
###############################################################################
set -euo pipefail

# ── Configuration ────────────────────────────────────────────────────────────
UE_BRANCH="${UE_BRANCH:-5.4}"
INSTALL_DIR="${INSTALL_DIR:-/opt/UnrealEngine}"
REPO_URL="https://github.com/EpicGames/UnrealEngine.git"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
LOG_FILE="${ROOT}/logs/ue5_install_$(date +%Y%m%d_%H%M%S).log"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --branch) UE_BRANCH="$2"; shift 2;;
    --install-dir) INSTALL_DIR="$2"; shift 2;;
    --help) echo "Usage: $0 [--branch 5.4] [--install-dir /opt/UnrealEngine]"; exit 0;;
    *) echo "Unknown option: $1"; exit 1;;
  esac
done

mkdir -p "$(dirname "$LOG_FILE")"

log() { echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG_FILE"; }
err() { log "ERROR: $*"; exit 1; }

log "═══════════════════════════════════════════════════════════════"
log " UE5 Linux Installation — Branch: ${UE_BRANCH}"
log " Install Directory: ${INSTALL_DIR}"
log "═══════════════════════════════════════════════════════════════"

# ── Phase 0: System Requirements Check ───────────────────────────────────────
log "Phase 0: Checking system requirements..."

# Disk space (need ~200GB)
AVAIL_GB=$(df -BG "${INSTALL_DIR%/*}" 2>/dev/null | tail -1 | awk '{print $4}' | tr -d 'G')
if [[ ${AVAIL_GB:-0} -lt 150 ]]; then
  err "Insufficient disk space: ${AVAIL_GB}GB available, need 150GB+"
fi
log "  Disk: ${AVAIL_GB}GB available ✓"

# RAM (need 32GB+)
TOTAL_RAM_GB=$(free -g | awk '/Mem:/{print $2}')
if [[ ${TOTAL_RAM_GB} -lt 16 ]]; then
  err "Insufficient RAM: ${TOTAL_RAM_GB}GB, need 16GB+ (32GB recommended)"
fi
log "  RAM: ${TOTAL_RAM_GB}GB ✓"

# CPU cores
NUM_CORES=$(nproc)
log "  CPU: ${NUM_CORES} cores ✓"

# GPU check
GPU_INFO=$(lspci 2>/dev/null | grep -i 'vga\|3d\|display' || echo "none")
if echo "$GPU_INFO" | grep -qi "nvidia"; then
  log "  GPU: NVIDIA detected ✓"
  nvidia-smi --query-gpu=name,memory.total --format=csv,noheader 2>/dev/null | while read line; do
    log "    → $line"
  done
elif echo "$GPU_INFO" | grep -qi "amd\|radeon"; then
  log "  GPU: AMD detected ✓ (Vulkan required)"
else
  log "  ⚠ WARNING: No GPU detected. UE5 Editor requires a GPU for rendering."
  log "    Server cooking (headless) may still work for dedicated server builds."
  log "    Pixel Streaming requires GPU at runtime."
  read -p "  Continue anyway? [y/N] " -n 1 -r
  echo
  [[ $REPLY =~ ^[Yy]$ ]] || exit 0
fi

# ── Phase 1: Install Dependencies ───────────────────────────────────────────
log "Phase 1: Installing build dependencies..."

if command -v apt-get &>/dev/null; then
  sudo apt-get update -qq
  sudo apt-get install -y -qq \
    build-essential git git-lfs cmake \
    clang libclang-dev \
    mono-devel mono-xbuild \
    libx11-dev libxcursor-dev libxrandr-dev libxi-dev \
    libgl1-mesa-dev libglu1-mesa-dev \
    libpulse-dev libasound2-dev \
    libsdl2-dev libfreetype6-dev \
    python3 python3-pip \
    zip unzip curl wget \
    dotnet-sdk-6.0 2>/dev/null || true
  log "  APT dependencies installed ✓"
elif command -v dnf &>/dev/null; then
  sudo dnf install -y \
    gcc gcc-c++ git git-lfs cmake clang \
    mono-devel mesa-libGL-devel SDL2-devel freetype-devel \
    pulseaudio-libs-devel python3 zip unzip curl wget
  log "  DNF dependencies installed ✓"
fi

# ── Phase 2: Clone UE5 Source ────────────────────────────────────────────────
log "Phase 2: Cloning Unreal Engine source (branch: ${UE_BRANCH})..."

if [[ -d "${INSTALL_DIR}/.git" ]]; then
  log "  Existing clone found, pulling updates..."
  cd "${INSTALL_DIR}"
  git fetch origin
  git checkout "${UE_BRANCH}" || git checkout "release" || git checkout "ue5-main"
  git pull
else
  sudo mkdir -p "${INSTALL_DIR}"
  sudo chown "$(whoami):$(whoami)" "${INSTALL_DIR}"
  
  # Try HTTPS first, fall back to SSH
  if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    CLONE_URL="https://${GITHUB_TOKEN}@github.com/EpicGames/UnrealEngine.git"
  else
    CLONE_URL="${REPO_URL}"
  fi
  
  log "  Cloning (this will take 30-60 minutes)..."
  git clone --branch "${UE_BRANCH}" --single-branch --depth 1 "${CLONE_URL}" "${INSTALL_DIR}" 2>&1 | tee -a "$LOG_FILE" || {
    log "  HTTPS clone failed, trying SSH..."
    git clone --branch "${UE_BRANCH}" --single-branch --depth 1 \
      "git@github.com:EpicGames/UnrealEngine.git" "${INSTALL_DIR}" 2>&1 | tee -a "$LOG_FILE" || {
      err "Failed to clone UE5. Ensure your GitHub account is linked to Epic Games."
      log "  Visit: https://www.unrealengine.com/ue-on-github"
    }
  }
fi

cd "${INSTALL_DIR}"

# ── Phase 3: Setup & Build ──────────────────────────────────────────────────
log "Phase 3: Running Setup scripts..."

if [[ -f "Setup.sh" ]]; then
  ./Setup.sh 2>&1 | tee -a "$LOG_FILE"
  log "  Setup.sh completed ✓"
fi

if [[ -f "GenerateProjectFiles.sh" ]]; then
  ./GenerateProjectFiles.sh 2>&1 | tee -a "$LOG_FILE"
  log "  GenerateProjectFiles.sh completed ✓"
fi

log "Phase 3b: Building Unreal Engine (this will take 2-6 hours)..."
PARALLEL_JOBS=$((NUM_CORES > 8 ? NUM_CORES - 2 : NUM_CORES))

make -j${PARALLEL_JOBS} 2>&1 | tee -a "$LOG_FILE" || {
  log "  make failed, trying with reduced parallelism..."
  make -j4 2>&1 | tee -a "$LOG_FILE" || err "Build failed. Check ${LOG_FILE} for details."
}

log "  Build completed ✓"

# ── Phase 4: Verify Installation ─────────────────────────────────────────────
log "Phase 4: Verifying installation..."

UE_EDITOR="${INSTALL_DIR}/Engine/Binaries/Linux/UnrealEditor"
UE_CMD="${INSTALL_DIR}/Engine/Binaries/Linux/UnrealEditor-Cmd"
RUN_UAT="${INSTALL_DIR}/Engine/Build/BatchFiles/RunUAT.sh"

for bin in "$UE_EDITOR" "$UE_CMD" "$RUN_UAT"; do
  if [[ -f "$bin" ]]; then
    log "  Found: $(basename $bin) ✓"
  else
    log "  ⚠ Missing: $bin"
  fi
done

# ── Phase 5: Create Environment File ─────────────────────────────────────────
log "Phase 5: Creating environment configuration..."

UE_ENV_FILE="${ROOT}/.ue5_env"
cat > "$UE_ENV_FILE" <<EOF
# UE5 Environment Configuration for Final Evolution Lab
# Source this file: source .ue5_env

export UE_ROOT="${INSTALL_DIR}"
export UE_EDITOR="${INSTALL_DIR}/Engine/Binaries/Linux/UnrealEditor"
export UE_CMD="${INSTALL_DIR}/Engine/Binaries/Linux/UnrealEditor-Cmd"
export RUN_UAT="${INSTALL_DIR}/Engine/Build/BatchFiles/RunUAT.sh"
export FEL_PROJECT="${ROOT}/UnrealStarter/BasketballGame/FinalEvolutionLab.uproject"

# Add UE5 to PATH
export PATH="${INSTALL_DIR}/Engine/Binaries/Linux:\${PATH}"
EOF

log "  Environment file: ${UE_ENV_FILE} ✓"
log ""
log "═══════════════════════════════════════════════════════════════"
log " UE5 Installation Complete!"
log " "
log " To use: source ${UE_ENV_FILE}"
log " To open project: \$UE_EDITOR \$FEL_PROJECT"
log " Log file: ${LOG_FILE}"
log "═══════════════════════════════════════════════════════════════"
