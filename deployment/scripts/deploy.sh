#!/bin/bash
# =============================================================================
# Final Evolution Lab - Deployment Script
# =============================================================================
# Deploys a new UE5 build to running Pixel Streaming instances.
# Supports blue-green deployment with automatic rollback.
#
# Usage:
#   ./deploy.sh [--version <build-version>] [--rollback] [--force]
#   ./deploy.sh --version 20260402-120000-abc1234
#   ./deploy.sh --rollback
# =============================================================================
set -euo pipefail

# --- Configuration ---
S3_BUCKET="${FEL_S3_BUCKET:-fel-ue5-builds}"
AWS_REGION="${AWS_REGION:-us-west-2}"
ASG_NAME="${FEL_ASG_NAME:-final-evolution-lab-production-gpu-asg}"
DEPLOY_DIR="/opt/fel"
HEALTH_CHECK_URL="http://localhost:8888/healthz"
HEALTH_CHECK_TIMEOUT=120
HEALTH_CHECK_INTERVAL=10

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info()  { echo -e "[$(date -u +%H:%M:%S)] ${GREEN}[DEPLOY]${NC} $1"; }
log_warn()  { echo -e "[$(date -u +%H:%M:%S)] ${YELLOW}[WARN]${NC}   $1"; }
log_error() { echo -e "[$(date -u +%H:%M:%S)] ${RED}[ERROR]${NC}  $1"; }

# Parse args
VERSION=""
ROLLBACK=false
FORCE=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --version) VERSION="$2"; shift 2 ;;
    --rollback) ROLLBACK=true; shift ;;
    --force) FORCE=true; shift ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# --- Rollback ---
if [ "$ROLLBACK" = true ]; then
  log_info "Initiating rollback..."
  
  if [ -d "$DEPLOY_DIR/previous" ]; then
    # Stop current
    sudo systemctl stop fel-ue5-server 2>/dev/null || true
    
    # Swap current <-> previous
    mv "$DEPLOY_DIR/current" "$DEPLOY_DIR/failed"
    mv "$DEPLOY_DIR/previous" "$DEPLOY_DIR/current"
    
    # Start rolled-back version
    sudo systemctl start fel-ue5-server
    
    log_info "Rolled back successfully. Failed build moved to $DEPLOY_DIR/failed/"
    exit 0
  else
    log_error "No previous deployment found for rollback"
    exit 1
  fi
fi

# --- Determine version ---
if [ -z "$VERSION" ]; then
  log_info "Fetching latest build version from S3..."
  VERSION=$(aws s3 cp "s3://$S3_BUCKET/builds/LATEST" - --region "$AWS_REGION" 2>/dev/null || true)
  
  if [ -z "$VERSION" ]; then
    log_error "No builds found in S3 bucket: $S3_BUCKET"
    exit 1
  fi
fi

log_info "Deploying version: $VERSION"

# --- Pre-deployment checks ---
log_info "Running pre-deployment checks..."

# Check S3 artifact exists
ARTIFACT="builds/fel-build-$VERSION.tar.gz"
if ! aws s3 ls "s3://$S3_BUCKET/$ARTIFACT" --region "$AWS_REGION" &>/dev/null; then
  log_error "Build artifact not found: s3://$S3_BUCKET/$ARTIFACT"
  exit 1
fi
log_info "  Artifact verified in S3"

# Check disk space (need at least 20GB free)
FREE_GB=$(df -BG "$DEPLOY_DIR" | tail -1 | awk '{print $4}' | sed 's/G//')
if [ "$FREE_GB" -lt 20 ]; then
  log_error "Insufficient disk space: ${FREE_GB}GB free (need 20GB+)"
  exit 1
fi
log_info "  Disk space OK (${FREE_GB}GB free)"

# --- Download ---
log_info "Downloading build from S3..."
mkdir -p "$DEPLOY_DIR/builds"
aws s3 cp "s3://$S3_BUCKET/$ARTIFACT" "$DEPLOY_DIR/builds/" --region "$AWS_REGION"
log_info "  Download complete"

# --- Blue-Green Deployment ---
log_info "Starting blue-green deployment..."

# Preserve previous deployment for rollback
if [ -d "$DEPLOY_DIR/current" ] && [ "$(ls -A $DEPLOY_DIR/current 2>/dev/null)" ]; then
  log_info "  Backing up current deployment..."
  rm -rf "$DEPLOY_DIR/previous"
  mv "$DEPLOY_DIR/current" "$DEPLOY_DIR/previous"
fi

# Extract new build
mkdir -p "$DEPLOY_DIR/current"
tar -xzf "$DEPLOY_DIR/builds/fel-build-$VERSION.tar.gz" -C "$DEPLOY_DIR/current/" --strip-components=1
chmod +x "$DEPLOY_DIR/current/FinalEvolutionLab.sh" 2>/dev/null || true
chmod +x "$DEPLOY_DIR/current/launch_pixel_streaming.sh" 2>/dev/null || true

log_info "  Build extracted to $DEPLOY_DIR/current/"

# --- Restart Services ---
log_info "Restarting services..."
sudo systemctl restart fel-signaling
sleep 2
sudo systemctl restart fel-ue5-server

# --- Health Check ---
log_info "Running health checks (timeout: ${HEALTH_CHECK_TIMEOUT}s)..."
ELAPSED=0
HEALTHY=false

while [ $ELAPSED -lt $HEALTH_CHECK_TIMEOUT ]; do
  RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "$HEALTH_CHECK_URL" 2>/dev/null || echo "000")
  
  if [ "$RESPONSE" = "200" ]; then
    HEALTHY=true
    break
  fi
  
  log_info "  Waiting for health check... ($ELAPSED/${HEALTH_CHECK_TIMEOUT}s, HTTP $RESPONSE)"
  sleep $HEALTH_CHECK_INTERVAL
  ELAPSED=$((ELAPSED + HEALTH_CHECK_INTERVAL))
done

if [ "$HEALTHY" = true ]; then
  log_info "Health check passed! ✅"
  
  # Save deployment info
  cat > "$DEPLOY_DIR/config/current-deployment.json" << EOF
{
  "version": "$VERSION",
  "deployed_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "deployed_by": "$(whoami)@$(hostname)",
  "health_check": "passed"
}
EOF
  
  # Clean up old build artifacts (keep last 3)
  ls -t "$DEPLOY_DIR/builds/"*.tar.gz 2>/dev/null | tail -n +4 | xargs rm -f 2>/dev/null || true
  
  log_info "Deployment complete! Version $VERSION is live."
else
  log_error "Health check failed after ${HEALTH_CHECK_TIMEOUT}s"
  
  if [ -d "$DEPLOY_DIR/previous" ]; then
    log_warn "Initiating automatic rollback..."
    sudo systemctl stop fel-ue5-server 2>/dev/null || true
    rm -rf "$DEPLOY_DIR/current"
    mv "$DEPLOY_DIR/previous" "$DEPLOY_DIR/current"
    sudo systemctl start fel-ue5-server
    log_warn "Rolled back to previous version"
  fi
  
  exit 1
fi
