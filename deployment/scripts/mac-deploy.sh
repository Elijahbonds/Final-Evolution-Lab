#!/bin/bash
###############################################################################
# mac-deploy.sh — One-command deployment from Mac Mini M4 Pro to AWS
#
# Usage:
#   bash deployment/scripts/mac-deploy.sh [--skip-upload] [--skip-terraform] [--teardown]
#
# Prerequisites:
#   - AWS CLI configured (aws configure)
#   - Terraform installed (brew install hashicorp/tap/terraform)
#   - UE5 Linux build completed in Builds/Linux/
#
# Budget: Optimized for $400/month
###############################################################################

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Config
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
AWS_REGION="${AWS_REGION:-us-west-2}"
TERRAFORM_DIR="$PROJECT_ROOT/deployment/aws"
BUILD_DIR="$PROJECT_ROOT/Builds/Linux"
BUILD_ARCHIVE="$PROJECT_ROOT/Builds/fel-linux-build.tar.gz"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/fel-mac-mini}"

# Flags
SKIP_UPLOAD=false
SKIP_TERRAFORM=false
TEARDOWN=false

for arg in "$@"; do
  case $arg in
    --skip-upload) SKIP_UPLOAD=true ;;
    --skip-terraform) SKIP_TERRAFORM=true ;;
    --teardown) TEARDOWN=true ;;
    --help|-h)
      echo "Usage: $0 [--skip-upload] [--skip-terraform] [--teardown]"
      echo ""
      echo "  --skip-upload     Skip S3 upload (use existing build)"
      echo "  --skip-terraform  Skip Terraform apply (infrastructure already exists)"
      echo "  --teardown        Destroy all AWS resources"
      exit 0
      ;;
  esac
done

###############################################################################
# Helper Functions
###############################################################################

log()  { echo -e "${BLUE}[FEL]${NC} $1"; }
ok()   { echo -e "${GREEN}[✅]${NC} $1"; }
warn() { echo -e "${YELLOW}[⚠️]${NC} $1"; }
err()  { echo -e "${RED}[❌]${NC} $1"; }
step() { echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; echo -e "${CYAN}  $1${NC}"; echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"; }

check_tool() {
  if ! command -v "$1" &>/dev/null; then
    err "$1 is not installed."
    echo "  Install with: $2"
    return 1
  fi
  ok "$1 found: $(command -v "$1")"
}

###############################################################################
# Teardown Mode
###############################################################################

if [ "$TEARDOWN" = true ]; then
  step "🗑  TEARING DOWN ALL AWS RESOURCES"
  warn "This will DESTROY all AWS infrastructure for Final Evolution Lab."
  echo ""
  read -p "Are you sure? Type 'yes' to confirm: " confirm
  if [ "$confirm" != "yes" ]; then
    log "Teardown cancelled."
    exit 0
  fi
  cd "$TERRAFORM_DIR"
  terraform destroy -auto-approve
  ok "All AWS resources destroyed."
  log "Monthly charges will stop within the hour."
  exit 0
fi

###############################################################################
# Step 1: Check Prerequisites
###############################################################################

step "1/6  Checking Prerequisites"

MISSING=0

check_tool "aws" "brew install awscli" || ((MISSING++))
check_tool "terraform" "brew install hashicorp/tap/terraform" || ((MISSING++))
check_tool "jq" "brew install jq" || ((MISSING++))
check_tool "tar" "(built into macOS)" || ((MISSING++))

# Check AWS credentials
if aws sts get-caller-identity &>/dev/null; then
  ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
  ok "AWS credentials valid (Account: $ACCOUNT_ID)"
else
  err "AWS credentials not configured. Run: aws configure"
  ((MISSING++))
fi

# Check SSH key
if [ -f "$SSH_KEY" ]; then
  ok "SSH key found: $SSH_KEY"
else
  warn "SSH key not found at $SSH_KEY"
  log "Generate with: ssh-keygen -t ed25519 -f $SSH_KEY -N ''"
  ((MISSING++))
fi

if [ "$MISSING" -gt 0 ]; then
  err "$MISSING prerequisite(s) missing. Fix them and re-run."
  exit 1
fi

ok "All prerequisites met!"

###############################################################################
# Step 2: Validate UE5 Build
###############################################################################

step "2/6  Validating UE5 Linux Build"

if [ ! -d "$BUILD_DIR" ]; then
  err "Linux build not found at: $BUILD_DIR"
  echo ""
  echo "  Build the project first:"
  echo "  1. Open UE5 Editor: open \"\$FEL_PROJECT\""
  echo "  2. File → Package Project → Linux"
  echo "  3. Output to: $BUILD_DIR"
  echo ""
  echo "  Or via command line (see MAC_MINI_SETUP_GUIDE.md, Section 7)"
  exit 1
fi

BUILD_SIZE=$(du -sh "$BUILD_DIR" | cut -f1)
FILE_COUNT=$(find "$BUILD_DIR" -type f | wc -l | tr -d ' ')
ok "Linux build found: $BUILD_SIZE ($FILE_COUNT files)"

# Check for server binary
SERVER_BIN=$(find "$BUILD_DIR" -name "*Server*" -type f | head -1)
if [ -n "$SERVER_BIN" ]; then
  ok "Server binary: $(basename "$SERVER_BIN")"
else
  warn "No server binary found. Build may need '-server' flag."
fi

###############################################################################
# Step 3: Create Build Archive
###############################################################################

step "3/6  Creating Build Archive"

if [ "$SKIP_UPLOAD" = true ]; then
  log "Skipping archive creation (--skip-upload)"
else
  if [ -f "$BUILD_ARCHIVE" ] && [ "$BUILD_ARCHIVE" -nt "$BUILD_DIR" ]; then
    ARCHIVE_SIZE=$(du -sh "$BUILD_ARCHIVE" | cut -f1)
    log "Using existing archive: $BUILD_ARCHIVE ($ARCHIVE_SIZE)"
  else
    log "Compressing build to $BUILD_ARCHIVE..."
    cd "$PROJECT_ROOT/Builds"
    tar -czf "fel-linux-build.tar.gz" Linux/
    ARCHIVE_SIZE=$(du -sh "$BUILD_ARCHIVE" | cut -f1)
    ok "Archive created: $ARCHIVE_SIZE"
  fi
fi

###############################################################################
# Step 4: Deploy Infrastructure with Terraform
###############################################################################

step "4/6  Deploying AWS Infrastructure"

if [ "$SKIP_TERRAFORM" = true ]; then
  log "Skipping Terraform (--skip-terraform)"
else
  cd "$TERRAFORM_DIR"

  # Check terraform.tfvars exists
  if [ ! -f "terraform.tfvars" ]; then
    err "terraform.tfvars not found!"
    echo "  Copy and edit the example:"
    echo "  cp terraform.tfvars.example terraform.tfvars"
    echo "  nano terraform.tfvars"
    exit 1
  fi

  log "Initializing Terraform..."
  terraform init -input=false

  log "Planning infrastructure..."
  terraform plan -out=tfplan -input=false

  log "Applying infrastructure..."
  terraform apply -input=false tfplan
  rm -f tfplan

  ok "Infrastructure deployed!"

  # Save outputs
  terraform output -json > "$PROJECT_ROOT/terraform-outputs.json"
  log "Outputs saved to terraform-outputs.json"
fi

###############################################################################
# Step 5: Upload Build to S3
###############################################################################

step "5/6  Uploading Build to S3"

if [ "$SKIP_UPLOAD" = true ]; then
  log "Skipping upload (--skip-upload)"
else
  # Get bucket name
  cd "$TERRAFORM_DIR"
  BUCKET=$(terraform output -raw s3_bucket_name 2>/dev/null || echo "")

  if [ -z "$BUCKET" ]; then
    err "Could not get S3 bucket name from Terraform."
    echo "  Check terraform output: cd $TERRAFORM_DIR && terraform output"
    exit 1
  fi

  log "Uploading to s3://$BUCKET/builds/..."
  log "Archive size: $(du -sh "$BUILD_ARCHIVE" | cut -f1)"

  aws s3 cp "$BUILD_ARCHIVE" \
    "s3://$BUCKET/builds/fel-linux-build.tar.gz" \
    --region "$AWS_REGION"

  ok "Build uploaded to S3!"

  # Verify
  aws s3 ls "s3://$BUCKET/builds/" --region "$AWS_REGION"
fi

###############################################################################
# Step 6: Deploy to EC2
###############################################################################

step "6/6  Deploying to EC2"

# Get instance info
INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=final-evolution-lab" "Name=instance-state-name,Values=running" \
  --query 'Reservations[0].Instances[0].InstanceId' \
  --output text --region "$AWS_REGION" 2>/dev/null)

INSTANCE_IP=$(aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=final-evolution-lab" "Name=instance-state-name,Values=running" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text --region "$AWS_REGION" 2>/dev/null)

if [ "$INSTANCE_ID" = "None" ] || [ -z "$INSTANCE_ID" ]; then
  err "No running EC2 instance found with tag Project=final-evolution-lab"
  echo "  Check: aws ec2 describe-instances --region $AWS_REGION"
  exit 1
fi

log "Instance: $INSTANCE_ID ($INSTANCE_IP)"

# Get bucket name
cd "$TERRAFORM_DIR"
BUCKET=$(terraform output -raw s3_bucket_name 2>/dev/null || echo "fel-builds")

# Deploy via SSH
log "Deploying game server on EC2..."
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no -o ConnectTimeout=10 "ubuntu@$INSTANCE_IP" << DEPLOY_SCRIPT
set -e
echo "[EC2] Downloading build from S3..."
sudo mkdir -p /opt/fel
cd /opt/fel
sudo aws s3 cp s3://$BUCKET/builds/fel-linux-build.tar.gz . --region $AWS_REGION

echo "[EC2] Extracting build..."
sudo tar -xzf fel-linux-build.tar.gz

echo "[EC2] Setting permissions..."
sudo chmod +x Linux/BasketballGame/Binaries/Linux/* 2>/dev/null || true
sudo chmod +x Linux/*.sh 2>/dev/null || true

echo "[EC2] Stopping existing server..."
sudo pkill -f BasketballGameServer 2>/dev/null || true
sleep 2

echo "[EC2] Starting game server with Pixel Streaming..."
cd /opt/fel/Linux
nohup ./BasketballGame/Binaries/Linux/BasketballGameServer \
  -RenderOffScreen \
  -PixelStreamingIP=0.0.0.0 \
  -PixelStreamingPort=8888 \
  -Res=1920x1080 \
  -log > /var/log/fel-server.log 2>&1 &

echo "[EC2] Server started (PID: \$!)"
sleep 5

echo "[EC2] Checking server process..."
if pgrep -f BasketballGameServer > /dev/null; then
  echo "[EC2] ✅ Server is running"
else
  echo "[EC2] ⚠️  Server may still be starting..."
fi
DEPLOY_SCRIPT

ok "Deployment complete!"

###############################################################################
# Summary
###############################################################################

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  🎮 Final Evolution Lab — Deployment Complete!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  ${CYAN}Instance:${NC}  $INSTANCE_ID"
echo -e "  ${CYAN}IP:${NC}        $INSTANCE_IP"
echo -e "  ${CYAN}Region:${NC}    $AWS_REGION"
echo ""
echo -e "  ${CYAN}Game URL:${NC}  http://$INSTANCE_IP:80"
echo -e "  ${CYAN}Signal:${NC}    ws://$INSTANCE_IP:8888"
echo ""
echo -e "  ${YELLOW}Next Steps:${NC}"
echo "  1. Open in browser: open http://$INSTANCE_IP:80"
echo "  2. Check health:    curl http://$INSTANCE_IP:8888/healthz"
echo "  3. SSH access:      ssh -i $SSH_KEY ubuntu@$INSTANCE_IP"
echo "  4. GPU status:      ssh -i $SSH_KEY ubuntu@$INSTANCE_IP nvidia-smi"
echo "  5. View logs:       ssh -i $SSH_KEY ubuntu@$INSTANCE_IP tail -f /var/log/fel-server.log"
echo ""
echo -e "  ${RED}💰 Cost Warning:${NC} Instance costs ~\$12-18/day while running."
echo "  Stop when not in use: aws ec2 stop-instances --instance-ids $INSTANCE_ID --region $AWS_REGION"
echo ""
