#!/usr/bin/env bash
###############################################################################
# FEL Bootstrap — Runs on first launch of AWS G5.2xlarge instance
# Installs NVIDIA drivers, CUDA, Vulkan, UE5 deps, clones project, sets env
###############################################################################
set -euo pipefail

LOG="/home/ubuntu/.fel/bootstrap.log"
mkdir -p /home/ubuntu/.fel
exec > >(tee -a "$LOG") 2>&1

SECONDS=0
phase() { echo ""; echo "═══════════════════════════════════════════════════════════"; echo "  $*"; echo "═══════════════════════════════════════════════════════════"; }
step()  { echo "[$(date '+%H:%M:%S')] ▸ $*"; }
ok()    { echo "[$(date '+%H:%M:%S')] ✅ $*"; }
fail()  { echo "[$(date '+%H:%M:%S')] ❌ $*"; }

notify() {
  local msg="$1"
  # Load credentials
  if [ -f /home/ubuntu/.fel/credentials.env ]; then
    source /home/ubuntu/.fel/credentials.env 2>/dev/null || true
  fi
  # Slack
  if [ -n "${SLACK_WEBHOOK:-}" ]; then
    curl -s -X POST -H 'Content-type: application/json' \
      --data "{\"text\":\"🏗️ FEL Bootstrap: ${msg}\"}" \
      "$SLACK_WEBHOOK" >/dev/null 2>&1 || true
  fi
}

# Load credentials if available
if [ -f /home/ubuntu/.fel/credentials.env ]; then
  source /home/ubuntu/.fel/credentials.env 2>/dev/null || true
  ok "Loaded credentials"
fi

notify "Bootstrap starting on $(hostname)"

###############################################################################
# Phase 1: System Updates & Base Packages
###############################################################################
phase "Phase 1: System Updates & Base Packages"

step "Updating package lists..."
sudo apt-get update -y
sudo apt-get upgrade -y

step "Installing base packages..."
sudo apt-get install -y \
  build-essential git git-lfs curl wget unzip tar \
  software-properties-common apt-transport-https \
  ca-certificates gnupg lsb-release jq htop tmux \
  python3 python3-pip python3-venv python3-dev \
  nodejs npm \
  nginx certbot python3-certbot-nginx \
  docker.io docker-compose \
  cmake ninja-build clang libssl-dev \
  libx11-dev libxcursor-dev libxinerama-dev libxi-dev libxrandr-dev \
  libgl1-mesa-dev libglu1-mesa-dev \
  libasound2-dev libpulse-dev \
  libfreetype-dev libfontconfig1-dev \
  mono-complete \
  pciutils mesa-utils

# Enable Docker for ubuntu user
sudo usermod -aG docker ubuntu
sudo systemctl enable docker
sudo systemctl start docker

# Install Node.js 20 LTS
if ! node --version 2>/dev/null | grep -q "v20"; then
  step "Installing Node.js 20 LTS..."
  curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
  sudo apt-get install -y nodejs
fi

ok "Base packages installed"
notify "Phase 1 complete: Base packages installed"

###############################################################################
# Phase 2: NVIDIA Drivers (535+)
###############################################################################
phase "Phase 2: NVIDIA GPU Drivers"

if nvidia-smi &>/dev/null; then
  ok "NVIDIA drivers already installed"
  nvidia-smi
else
  step "Installing NVIDIA drivers 535..."
  sudo apt-get install -y linux-headers-$(uname -r)

  # Add NVIDIA repository
  distribution=$(. /etc/os-release; echo $ID$VERSION_ID)
  wget -qO - https://nvidia.github.io/libnvidia-container/gpgkey | \
    sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
  
  # Install driver
  sudo apt-get install -y nvidia-driver-535 nvidia-utils-535
  
  # If package install fails, try runfile
  if ! nvidia-smi &>/dev/null; then
    step "Trying runfile install..."
    wget -q https://us.download.nvidia.com/tesla/535.183.01/NVIDIA-Linux-x86_64-535.183.01.run \
      -O /tmp/nvidia-driver.run
    sudo sh /tmp/nvidia-driver.run --silent --no-questions || true
  fi

  # Verify
  if nvidia-smi &>/dev/null; then
    ok "NVIDIA drivers installed successfully"
    nvidia-smi
  else
    fail "NVIDIA driver installation may require reboot"
    echo "Run: sudo reboot && nvidia-smi"
  fi
fi

notify "Phase 2 complete: NVIDIA drivers"

###############################################################################
# Phase 3: CUDA 12.3
###############################################################################
phase "Phase 3: CUDA 12.3 Toolkit"

if nvcc --version 2>/dev/null | grep -q "12.3"; then
  ok "CUDA 12.3 already installed"
else
  step "Installing CUDA 12.3..."
  wget -q https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.1-1_all.deb \
    -O /tmp/cuda-keyring.deb
  sudo dpkg -i /tmp/cuda-keyring.deb
  sudo apt-get update -y
  sudo apt-get install -y cuda-toolkit-12-3

  # Set PATH
  echo 'export PATH=/usr/local/cuda-12.3/bin:$PATH' >> /home/ubuntu/.bashrc
  echo 'export LD_LIBRARY_PATH=/usr/local/cuda-12.3/lib64:${LD_LIBRARY_PATH:-}' >> /home/ubuntu/.bashrc
  export PATH=/usr/local/cuda-12.3/bin:$PATH
  export LD_LIBRARY_PATH=/usr/local/cuda-12.3/lib64:${LD_LIBRARY_PATH:-}

  ok "CUDA 12.3 installed"
fi

notify "Phase 3 complete: CUDA 12.3"

###############################################################################
# Phase 4: Vulkan SDK
###############################################################################
phase "Phase 4: Vulkan SDK"

if vulkaninfo --summary 2>/dev/null | grep -q "Vulkan"; then
  ok "Vulkan already available"
else
  step "Installing Vulkan SDK..."
  wget -qO - https://packages.lunarg.com/lunarg-signing-key-pub.asc | sudo apt-key add -
  sudo wget -qO /etc/apt/sources.list.d/lunarg-vulkan-1.3.275-jammy.list \
    https://packages.lunarg.com/vulkan/1.3.275/lunarg-vulkan-1.3.275-jammy.list || true
  sudo apt-get update -y
  sudo apt-get install -y vulkan-sdk libvulkan1 vulkan-tools || \
    sudo apt-get install -y libvulkan1 vulkan-tools mesa-vulkan-drivers

  ok "Vulkan SDK installed"
fi

notify "Phase 4 complete: Vulkan SDK"

###############################################################################
# Phase 5: NVIDIA Container Toolkit (for Docker GPU access)
###############################################################################
phase "Phase 5: NVIDIA Container Toolkit"

if dpkg -l | grep -q nvidia-container-toolkit; then
  ok "NVIDIA Container Toolkit already installed"
else
  step "Installing NVIDIA Container Toolkit..."
  distribution=$(. /etc/os-release; echo $ID$VERSION_ID)
  curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | \
    sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg 2>/dev/null || true
  curl -s -L https://nvidia.github.io/libnvidia-container/${distribution}/libnvidia-container.list | \
    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
    sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
  sudo apt-get update -y
  sudo apt-get install -y nvidia-container-toolkit
  sudo nvidia-ctk runtime configure --runtime=docker
  sudo systemctl restart docker

  ok "NVIDIA Container Toolkit installed"
fi

###############################################################################
# Phase 6: Project Setup
###############################################################################
phase "Phase 6: Project Setup"

PROJECT_DIR="/home/ubuntu/rork-final-evolution-lab"

if [ -d "$PROJECT_DIR" ]; then
  ok "Project already exists at $PROJECT_DIR"
  cd "$PROJECT_DIR"
  git pull origin main 2>/dev/null || true
else
  step "Project not found. Attempting clone..."
  cd /home/ubuntu
  GH_TOKEN="${GITHUB_TOKEN:-}"
  if [ -n "$GH_TOKEN" ]; then
    git clone "https://${GH_TOKEN}@github.com/finalevolutiongroup/final-evolution-lab.git" \
      rork-final-evolution-lab 2>/dev/null || \
    git clone "https://github.com/finalevolutiongroup/final-evolution-lab.git" \
      rork-final-evolution-lab 2>/dev/null || true
  fi
fi

if [ ! -d "$PROJECT_DIR" ]; then
  fail "Project directory not found. Please transfer manually:"
  echo "  scp -r -i key.pem /path/to/rork-final-evolution-lab ubuntu@<IP>:/home/ubuntu/"
  echo "  OR: rsync -avz -e 'ssh -i key.pem' /path/to/rork-final-evolution-lab ubuntu@<IP>:/home/ubuntu/"
fi

###############################################################################
# Phase 7: Environment Variables & .env
###############################################################################
phase "Phase 7: Environment Configuration"

if [ -d "$PROJECT_DIR" ]; then
  cd "$PROJECT_DIR"

  # Create .env from credentials
  step "Setting up .env file..."
  cat > "$PROJECT_DIR/.env" << ENV
# Final Evolution Lab — Environment Configuration
# Auto-generated by bootstrap.sh on $(date)
GITHUB_TOKEN=${GITHUB_TOKEN:-}
GAIA_API_KEY=${GAIA_API_KEY:-}
LUMA_API_KEY=${LUMA_API_KEY:-}
RUNWAY_API_KEY=${RUNWAY_API_KEY:-}
STABILITY_API_KEY=${STABILITY_API_KEY:-}
MESHY_API_KEY=${MESHY_API_KEY:-}
DEEPMOTION_CLIENT_ID=${DEEPMOTION_CLIENT_ID:-}
DEEPMOTION_CLIENT_SECRET=${DEEPMOTION_CLIENT_SECRET:-}
NOTIFICATION_EMAIL=${NOTIFICATION_EMAIL:-}
SLACK_WEBHOOK=${SLACK_WEBHOOK:-}
ENV
  chmod 600 "$PROJECT_DIR/.env"

  # Install Python deps
  step "Installing Python dependencies..."
  pip3 install --user -r scripts/ai_asset_pipeline/requirements.txt 2>/dev/null || true
  pip3 install --user -r scripts/cv_preprocessing/requirements.txt 2>/dev/null || true

  # Install Node deps
  step "Installing Node.js dependencies..."
  cd "$PROJECT_DIR/streaming/signalling" && npm install 2>/dev/null || true
  cd "$PROJECT_DIR/streaming/frontend" && npm install 2>/dev/null || true
  cd "$PROJECT_DIR"

  ok "Environment configured"
fi

###############################################################################
# Phase 8: Configure git for UE5 source access
###############################################################################
phase "Phase 8: Git Configuration for UE5 Source"

if [ -n "${GITHUB_TOKEN:-}" ]; then
  git config --global credential.helper store
  echo "https://${GITHUB_TOKEN}:x-oauth-basic@github.com" > /home/ubuntu/.git-credentials
  chmod 600 /home/ubuntu/.git-credentials
  git config --global user.email "fel-builder@finalevolutiongroup.com"
  git config --global user.name "FEL Builder"
  ok "Git credentials configured for UE5 source access"
else
  fail "No GITHUB_TOKEN set — UE5 source clone will require manual auth"
fi

###############################################################################
# Summary
###############################################################################
phase "Bootstrap Complete!"

ELAPSED=$SECONDS
MINUTES=$((ELAPSED / 60))

echo ""
echo "  Duration: ${MINUTES}m ${SECONDS}s"
echo "  Project:  $PROJECT_DIR"
echo ""
echo "  Next Steps:"
echo "    1. Verify GPU:  nvidia-smi"
echo "    2. Validate:    bash $PROJECT_DIR/deploy/aws/validate_environment.sh"
echo "    3. Run pipeline: bash $PROJECT_DIR/deploy/aws/run_pipeline.sh"
echo "    4. Or one-click: bash $PROJECT_DIR/deploy/aws/deploy_final_evolution_lab.sh --build --deploy"
echo ""

notify "Bootstrap complete! Duration: ${MINUTES}m. Ready for pipeline execution."

# Run validation automatically
if [ -f "$PROJECT_DIR/deploy/aws/validate_environment.sh" ]; then
  step "Running automatic validation..."
  bash "$PROJECT_DIR/deploy/aws/validate_environment.sh" || true
fi
