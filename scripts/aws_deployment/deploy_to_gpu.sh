#!/usr/bin/env bash
###############################################################################
# deploy_to_gpu.sh — Transfer FEL project to AWS GPU instance
#
# Usage:
#   ./deploy_to_gpu.sh <GPU_IP> [SSH_KEY_PATH]
#
# Example:
#   ./deploy_to_gpu.sh 54.123.45.67 ~/.ssh/fel-gpu-key.pem
###############################################################################
set -euo pipefail

GPU_IP="${1:-}"
SSH_KEY="${2:-$HOME/.ssh/fel-gpu-key.pem}"
REMOTE_USER="ubuntu"
REMOTE_DIR="/home/ubuntu/fel-workspace/rork-final-evolution-lab"
PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

if [[ -z "$GPU_IP" ]]; then
    echo "Usage: $0 <GPU_IP> [SSH_KEY_PATH]"
    echo ""
    # Try to load from saved instance info
    if [[ -f "$HOME/.fel-gpu-instance.json" ]]; then
        IP=$(python3 -c "import json; print(json.load(open('$HOME/.fel-gpu-instance.json'))['public_ip'])" 2>/dev/null || true)
        if [[ -n "$IP" && "$IP" != "unknown" ]]; then
            echo "Found saved instance IP: $IP"
            echo "Run: $0 $IP"
        fi
    fi
    exit 1
fi

SSH_CMD="ssh -i $SSH_KEY -o StrictHostKeyChecking=no -o ConnectTimeout=10 $REMOTE_USER@$GPU_IP"
SCP_CMD="scp -i $SSH_KEY -o StrictHostKeyChecking=no"
RSYNC_CMD="rsync -avz --progress -e 'ssh -i $SSH_KEY -o StrictHostKeyChecking=no'"

echo "═══════════════════════════════════════════════════"
echo "  FEL → GPU Deployment"
echo "═══════════════════════════════════════════════════"
echo "  GPU IP:      $GPU_IP"
echo "  Project:     $PROJECT_ROOT"
echo "  Remote:      $REMOTE_DIR"
echo "  SSH Key:     $SSH_KEY"
echo "═══════════════════════════════════════════════════"

# Check connectivity
echo "\n[1/5] Testing SSH connection..."
if ! $SSH_CMD "echo 'SSH OK'; nvidia-smi --query-gpu=name,memory.total --format=csv,noheader 2>/dev/null || echo 'GPU: pending driver install'"; then
    echo "[ERROR] Cannot connect to $GPU_IP"
    exit 1
fi

# Check setup status
echo "\n[2/5] Checking GPU setup status..."
$SSH_CMD "cat /home/ubuntu/.fel-setup-complete 2>/dev/null || echo 'Setup still running... Check /var/log/fel-setup.log'"

# Create remote directory
echo "\n[3/5] Creating remote workspace..."
$SSH_CMD "mkdir -p $REMOTE_DIR"

# Transfer project files
echo "\n[4/5] Syncing project files..."
$RSYNC_CMD \
    --exclude '.git' \
    --exclude 'node_modules' \
    --exclude '__pycache__' \
    --exclude '.venv' \
    --exclude 'Builds' \
    --exclude 'GeneratedAssets/CVPreprocessed/*/segmentation/masks' \
    "$PROJECT_ROOT/" "$REMOTE_USER@$GPU_IP:$REMOTE_DIR/"

# Transfer .env if it exists
if [[ -f "$PROJECT_ROOT/.env" ]]; then
    echo "  Syncing .env..."
    $SCP_CMD "$PROJECT_ROOT/.env" "$REMOTE_USER@$GPU_IP:$REMOTE_DIR/.env"
fi

# Run setup on remote
echo "\n[5/5] Running remote setup..."
$SSH_CMD "cd $REMOTE_DIR && bash scripts/aws_deployment/setup_gpu_environment.sh" || {
    echo "[WARN] Remote setup had issues. SSH in to investigate."
}

echo ""
echo "═══════════════════════════════════════════════════"
echo "  Deployment Complete!"
echo "═══════════════════════════════════════════════════"
echo ""
echo "  SSH into GPU instance:"
echo "    ssh -i $SSH_KEY $REMOTE_USER@$GPU_IP"
echo ""
echo "  Run the complete pipeline:"
echo "    cd $REMOTE_DIR"
echo "    bash scripts/ue5_setup/fel_complete_pipeline.sh"
echo ""
echo "  Monitor progress:"
echo "    python3 scripts/aws_deployment/monitor_pipeline.py --remote $GPU_IP"
echo "═══════════════════════════════════════════════════"
