#!/usr/bin/env bash
###############################################################################
# setup_gpu_environment.sh — Configure GPU environment for FEL pipeline
#
# Run on the GPU instance after project transfer.
# Installs NVIDIA drivers, CUDA, Vulkan, Python deps, and verifies GPU.
#
# Usage:
#   bash setup_gpu_environment.sh
###############################################################################
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

log() { echo "[$(date '+%H:%M:%S')] $*"; }

log "═══ FEL GPU Environment Setup ═══"
echo "  Host: $(hostname)"
echo "  OS: $(lsb_release -ds 2>/dev/null || cat /etc/os-release | head -1)"
echo "  Kernel: $(uname -r)"
echo ""

# ── Check if running as root or with sudo ─────────────────────────────────
SUDO=""
if [[ $EUID -ne 0 ]]; then
    SUDO="sudo"
fi

# ── Phase 1: NVIDIA Driver ────────────────────────────────────────────────
log "Phase 1: NVIDIA Driver Check"
if command -v nvidia-smi &>/dev/null; then
    GPU_INFO=$(nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader 2>/dev/null || echo "unknown")
    log "  GPU detected: $GPU_INFO"
else
    log "  NVIDIA driver not found. Installing..."
    $SUDO apt-get update -y
    $SUDO apt-get install -y linux-headers-$(uname -r)
    $SUDO apt-get install -y nvidia-driver-535 nvidia-utils-535 2>/dev/null || {
        log "  Trying alternative driver package..."
        $SUDO ubuntu-drivers install 2>/dev/null || log "  [WARN] Driver install may need reboot"
    }
    log "  [NOTE] Reboot may be required for driver activation"
fi

# ── Phase 2: CUDA Toolkit ─────────────────────────────────────────────────
log "Phase 2: CUDA Toolkit"
if command -v nvcc &>/dev/null; then
    CUDA_VER=$(nvcc --version | grep release | awk '{print $5}' | tr -d ',')
    log "  CUDA version: $CUDA_VER"
else
    log "  Installing CUDA toolkit..."
    if [[ ! -f /usr/share/keyrings/cuda-archive-keyring.gpg ]]; then
        wget -q https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.1-1_all.deb -O /tmp/cuda-keyring.deb
        $SUDO dpkg -i /tmp/cuda-keyring.deb
    fi
    $SUDO apt-get update -y
    $SUDO apt-get install -y cuda-toolkit-12-3 2>/dev/null || log "  [WARN] CUDA install needs driver first"
    echo 'export PATH=/usr/local/cuda/bin:$PATH' >> ~/.bashrc
    echo 'export LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH' >> ~/.bashrc
fi

# ── Phase 3: Vulkan ───────────────────────────────────────────────────────
log "Phase 3: Vulkan Runtime"
$SUDO apt-get install -y vulkan-tools libvulkan1 mesa-vulkan-drivers 2>/dev/null || true
if command -v vulkaninfo &>/dev/null; then
    VK_DRIVER=$(vulkaninfo --summary 2>/dev/null | grep driverName | head -1 || echo "unknown")
    log "  Vulkan: $VK_DRIVER"
else
    log "  [WARN] Vulkan info not available"
fi

# ── Phase 4: Build Tools ──────────────────────────────────────────────────
log "Phase 4: Build Tools"
$SUDO apt-get install -y build-essential git git-lfs clang mono-complete \
    python3-pip python3-venv nodejs npm 2>/dev/null || true

# ── Phase 5: Python Dependencies ──────────────────────────────────────────
log "Phase 5: Python Dependencies"
cd "$ROOT"

# Create virtual environment
if [[ ! -d ".venv" ]]; then
    python3 -m venv .venv
fi
source .venv/bin/activate

# Install CV preprocessing deps
pip install --upgrade pip
pip install -r scripts/cv_preprocessing/requirements.txt 2>/dev/null || {
    pip install ultralytics opencv-python-headless scipy numpy
}

# Install AI pipeline deps
pip install -r scripts/ai_asset_pipeline/requirements.txt 2>/dev/null || true
pip install python-dotenv

log "  Python packages installed"

# ── Phase 6: Docker (optional) ────────────────────────────────────────────
log "Phase 6: Docker"
if command -v docker &>/dev/null; then
    log "  Docker: $(docker --version)"
else
    log "  Installing Docker..."
    $SUDO apt-get install -y docker.io docker-compose 2>/dev/null || true
    $SUDO usermod -aG docker ubuntu 2>/dev/null || true
fi

# ── Phase 7: GitHub Authentication ────────────────────────────────────────
log "Phase 7: GitHub Configuration"
if [[ -n "${GITHUB_PAT:-}" ]]; then
    git config --global credential.helper store
    echo "https://oauth2:${GITHUB_PAT}@github.com" > ~/.git-credentials
    chmod 600 ~/.git-credentials
    log "  GitHub PAT configured"
else
    log "  [NOTE] Set GITHUB_PAT env var for automated GitHub access"
fi

# ── Phase 8: Verify ───────────────────────────────────────────────────────
log "Phase 8: Environment Verification"
echo ""
echo "  GPU:     $(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null || echo 'Not available')"
echo "  CUDA:    $(nvcc --version 2>/dev/null | grep release | awk '{print $5}' | tr -d ',' || echo 'Not installed')"
echo "  Python:  $(python3 --version)"
echo "  Node:    $(node --version 2>/dev/null || echo 'Not installed')"
echo "  Docker:  $(docker --version 2>/dev/null || echo 'Not installed')"
echo "  Git:     $(git --version)"
echo "  Disk:    $(df -h / | tail -1 | awk '{print $4}') free"
echo "  RAM:     $(free -h | awk '/Mem/{print $2}') total"
echo ""

# Check source videos
if [[ -d "$ROOT/SourceVideos/Instagram/basketball" ]]; then
    VIDEO_COUNT=$(ls -1 "$ROOT/SourceVideos/Instagram/basketball/"*.mp4 2>/dev/null | wc -l)
    log "  Source videos: $VIDEO_COUNT found"
else
    log "  [WARN] Source videos not found"
fi

log "═══ GPU Environment Setup Complete ═══"
echo ""
echo "Next steps:"
echo "  1. Run CV preprocessing:  python3 scripts/cv_preprocessing/preprocessing_pipeline.py --all"
echo "  2. Run full pipeline:     bash scripts/ue5_setup/fel_complete_pipeline.sh"
echo "  3. Monitor:               python3 scripts/aws_deployment/monitor_pipeline.py"
