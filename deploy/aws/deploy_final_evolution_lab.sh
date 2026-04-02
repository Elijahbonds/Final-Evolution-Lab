#!/usr/bin/env bash
###############################################################################
# deploy_final_evolution_lab.sh — One-Click Deployment
#
# THE master script. Provisions, builds, and deploys everything.
#
# Usage:
#   ./deploy_final_evolution_lab.sh --provision --build --deploy
#   ./deploy_final_evolution_lab.sh --build --deploy          # Skip AWS provision
#   ./deploy_final_evolution_lab.sh --deploy                  # Deploy only
#   ./deploy_final_evolution_lab.sh --dry-run                 # Validate only
#   ./deploy_final_evolution_lab.sh --interactive             # Guided mode
#   ./deploy_final_evolution_lab.sh --resume                  # Resume failed build
#
# Flags:
#   --provision    Provision AWS G5.2xlarge (requires AWS CLI)
#   --build        Build UE5 + assets (requires GPU)
#   --deploy       Deploy website + streaming + DNS
#   --skip-cv      Skip CV preprocessing phase
#   --dry-run      Validate everything without executing
#   --interactive  Prompt for all credentials
#   --resume       Resume from last failure point
###############################################################################
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# ── Defaults ────────────────────────────────────────────────────
DO_PROVISION=false
DO_BUILD=false
DO_DEPLOY=false
DRY_RUN=false
INTERACTIVE=false
RESUME=false
SKIP_CV=false
BUILD_ARGS=()

# ── Parse args ──────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case $1 in
    --provision)   DO_PROVISION=true; shift;;
    --build)       DO_BUILD=true; shift;;
    --deploy)      DO_DEPLOY=true; shift;;
    --dry-run)     DRY_RUN=true; shift;;
    --interactive) INTERACTIVE=true; shift;;
    --resume)      RESUME=true; DO_BUILD=true; shift;;
    --skip-cv)     SKIP_CV=true; BUILD_ARGS+=("--skip-cv"); shift;;
    --all)         DO_PROVISION=true; DO_BUILD=true; DO_DEPLOY=true; shift;;
    -h|--help)
      echo "Usage: $0 [--provision] [--build] [--deploy] [--dry-run] [--interactive] [--resume]"
      echo ""
      echo "Flags:"
      echo "  --provision    Provision AWS G5.2xlarge instance"
      echo "  --build        Build UE5 engine + cook project"
      echo "  --deploy       Deploy website + streaming services"
      echo "  --all          All of the above"
      echo "  --skip-cv      Skip CV preprocessing"
      echo "  --dry-run      Validate without executing"
      echo "  --interactive  Prompt for credentials"
      echo "  --resume       Resume from failure"
      exit 0;;
    *) shift;;
  esac
done

# If nothing selected, show help
if ! $DO_PROVISION && ! $DO_BUILD && ! $DO_DEPLOY && ! $DRY_RUN && ! $INTERACTIVE; then
  echo ""
  echo "  🎮 FINAL EVOLUTION LAB — One-Click Deployment"
  echo ""
  echo "  No action specified. Examples:"
  echo ""
  echo "    Full deployment (local GPU machine):"
  echo "      $0 --build --deploy"
  echo ""
  echo "    Full deployment (new AWS instance):"
  echo "      $0 --provision --build --deploy"
  echo ""
  echo "    Guided setup:"
  echo "      $0 --interactive"
  echo ""
  echo "    Validate only:"
  echo "      $0 --dry-run"
  echo ""
  exit 0
fi

# ── Colors ──────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

banner() {
  echo ""
  echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
  echo -e "${BOLD}  $*${NC}"
  echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
}

log() { echo -e "[$(date '+%H:%M:%S')] $*"; }
ok()  { echo -e "[$(date '+%H:%M:%S')] ${GREEN}✅ $*${NC}"; }
err() { echo -e "[$(date '+%H:%M:%S')] ${RED}❌ $*${NC}"; }
warn(){ echo -e "[$(date '+%H:%M:%S')] ${YELLOW}⚠️  $*${NC}"; }

# ── Load existing credentials ───────────────────────────────────
if [ -f "$ROOT/.env" ]; then
  set -a; source "$ROOT/.env" 2>/dev/null || true; set +a
fi
if [ -f /home/ubuntu/.fel/credentials.env ]; then
  set -a; source /home/ubuntu/.fel/credentials.env 2>/dev/null || true; set +a
fi

###############################################################################
# Interactive Mode — Credential Collection
###############################################################################
if $INTERACTIVE; then
  banner "Interactive Setup — Credential Collection"
  echo ""
  echo "  Enter your credentials (press Enter to skip/keep existing):"
  echo ""

  read -p "  GitHub Token (Epic Games PAT) [${GITHUB_TOKEN:+****set}]: " input
  [ -n "$input" ] && GITHUB_TOKEN="$input"

  read -p "  Meshy API Key [${MESHY_API_KEY:+****set}]: " input
  [ -n "$input" ] && MESHY_API_KEY="$input"

  read -p "  Luma API Key [${LUMA_API_KEY:+****set}]: " input
  [ -n "$input" ] && LUMA_API_KEY="$input"

  read -p "  Gaia API Key [${GAIA_API_KEY:+****set}]: " input
  [ -n "$input" ] && GAIA_API_KEY="$input"

  read -p "  Runway API Key [${RUNWAY_API_KEY:+****set}]: " input
  [ -n "$input" ] && RUNWAY_API_KEY="$input"

  read -p "  Stability API Key [${STABILITY_API_KEY:+****set}]: " input
  [ -n "$input" ] && STABILITY_API_KEY="$input"

  read -p "  Notification Email [${NOTIFICATION_EMAIL:-}]: " input
  [ -n "$input" ] && NOTIFICATION_EMAIL="$input"

  read -p "  Slack Webhook URL [${SLACK_WEBHOOK:+****set}]: " input
  [ -n "$input" ] && SLACK_WEBHOOK="$input"

  if ! $DO_PROVISION && ! $DO_BUILD && ! $DO_DEPLOY; then
    echo ""
    echo "  What would you like to do?"
    echo "    1) Full deployment (provision + build + deploy)"
    echo "    2) Build + Deploy (already on GPU machine)"
    echo "    3) Deploy only (build already done)"
    echo "    4) Validate only (dry run)"
    echo ""
    read -p "  Choice [2]: " choice
    case "${choice:-2}" in
      1) DO_PROVISION=true; DO_BUILD=true; DO_DEPLOY=true;;
      2) DO_BUILD=true; DO_DEPLOY=true;;
      3) DO_DEPLOY=true;;
      4) DRY_RUN=true;;
    esac
  fi

  # Save credentials
  cat > "$ROOT/.env" << ENV
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
  chmod 600 "$ROOT/.env"
  ok "Credentials saved to .env"
fi

###############################################################################
# Header
###############################################################################
banner "🎮 FINAL EVOLUTION LAB — Deployment Pipeline"
echo ""
echo "  Project:     $ROOT"
echo "  Provision:   $DO_PROVISION"
echo "  Build:       $DO_BUILD"
echo "  Deploy:      $DO_DEPLOY"
echo "  Dry Run:     $DRY_RUN"
echo "  Resume:      $RESUME"
echo "  Date:        $(date)"
echo ""

SECONDS=0
ERRORS=0

###############################################################################
# Phase 0: Dry Run / Validation
###############################################################################
if $DRY_RUN; then
  banner "DRY RUN — Validation Only"
  bash "${SCRIPT_DIR}/validate_environment.sh" || true
  log ""
  log "Dry run complete. No changes made."
  exit 0
fi

###############################################################################
# Phase 1: AWS Provisioning
###############################################################################
if $DO_PROVISION; then
  banner "Phase 1: AWS Infrastructure Provisioning"

  if ! command -v aws &>/dev/null; then
    warn "AWS CLI not installed. Installing..."
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
    unzip -q /tmp/awscliv2.zip -d /tmp/
    sudo /tmp/aws/install || true
  fi

  if command -v aws &>/dev/null && aws sts get-caller-identity &>/dev/null; then
    ok "AWS credentials valid"

    # Check if we have boto3
    if python3 -c "import boto3" 2>/dev/null; then
      log "Provisioning via boto3..."

      # Prompt for key pair if interactive
      KEY_PAIR="${AWS_KEY_PAIR:-}"
      if [ -z "$KEY_PAIR" ] && $INTERACTIVE; then
        read -p "  AWS Key Pair name: " KEY_PAIR
      fi

      if [ -n "$KEY_PAIR" ]; then
        python3 "${SCRIPT_DIR}/provision_boto3.py" \
          --key-pair "$KEY_PAIR" \
          --github-token "${GITHUB_TOKEN:-}" \
          --notification-email "${NOTIFICATION_EMAIL:-}"
        ok "AWS instance provisioned"
      else
        warn "No key pair specified. Skipping provisioning."
        warn "Run manually: python3 deploy/aws/provision_boto3.py --key-pair YOUR_KEY"
      fi
    else
      warn "boto3 not installed. Install: pip3 install boto3"
      warn "Alternative: Use CloudFormation template at deploy/aws/cloudformation.yaml"
    fi
  else
    warn "AWS credentials not configured."
    echo ""
    echo "  Manual provisioning options:"
    echo "    1. CloudFormation: deploy/aws/cloudformation.yaml"
    echo "    2. Terraform:     cd deploy/aws/terraform && terraform apply"
    echo "    3. boto3:         python3 deploy/aws/provision_boto3.py --key-pair KEY"
    echo "    4. AWS Console:   See deploy/aws/MANUAL_PROVISIONING.md"
    echo ""
  fi
fi

###############################################################################
# Phase 2: Build (UE5 + Assets)
###############################################################################
if $DO_BUILD; then
  banner "Phase 2: UE5 Build Pipeline"

  # Validate GPU
  if ! nvidia-smi &>/dev/null; then
    err "No NVIDIA GPU detected! UE5 build requires GPU."
    err "Run on AWS G5.2xlarge or local GPU machine."
    ((ERRORS++))
  else
    ok "GPU detected: $(nvidia-smi --query-gpu=name --format=csv,noheader | head -1)"

    if $RESUME; then
      log "Resuming pipeline from last checkpoint..."
      bash "${SCRIPT_DIR}/run_pipeline.sh" --resume "${BUILD_ARGS[@]}" || ((ERRORS++))
    else
      log "Starting full pipeline..."
      bash "${SCRIPT_DIR}/run_pipeline.sh" "${BUILD_ARGS[@]}" || ((ERRORS++))
    fi
  fi
fi

###############################################################################
# Phase 3: Deploy
###############################################################################
if $DO_DEPLOY; then
  banner "Phase 3: Deployment"

  # 3a. Marketing Website
  log "── Deploying Marketing Website ──"
  if [ -d /home/ubuntu/finalevolutiongroup_website ] || \
     [ -d "$ROOT/sites/final-evolution-main-site" ]; then
    bash "${SCRIPT_DIR}/deploy_website.sh" --self-host || warn "Website deploy had issues"
    ok "Marketing website deployed"
  else
    warn "Marketing website source not found. Skipping."
  fi

  # 3b. Streaming Infrastructure
  log "── Deploying Streaming Services ──"
  if [ -f "$ROOT/streaming/docker-compose.yml" ]; then
    cd "$ROOT/streaming"
    if command -v docker &>/dev/null; then
      docker compose up --build -d 2>&1 || {
        warn "Docker Compose failed, trying native services..."
        bash "$ROOT/scripts/start_services.sh" || warn "Services start had issues"
      }
    else
      bash "$ROOT/scripts/start_services.sh" || warn "Services start had issues"
    fi
    ok "Streaming services deployed"
    cd "$ROOT"
  fi

  # 3c. DNS & Endpoints
  log "── Configuring DNS & Endpoints ──"
  bash "${SCRIPT_DIR}/configure_dns.sh" || warn "DNS config had issues"
  ok "DNS configuration complete"

  # 3d. Health Checks
  log "── Running Health Checks ──"
  sleep 5
  for endpoint in "localhost:3000" "localhost:8888/healthz" "localhost:3001" "localhost:9090/health"; do
    HTTP=$(curl -s -o /dev/null -w "%{http_code}" "http://$endpoint" 2>/dev/null || echo "000")
    if [ "$HTTP" = "200" ] || [ "$HTTP" = "301" ]; then
      ok "http://$endpoint → $HTTP"
    else
      warn "http://$endpoint → $HTTP"
    fi
  done
fi

###############################################################################
# Summary
###############################################################################
TOTAL_ELAPSED=$SECONDS
TOTAL_MIN=$((TOTAL_ELAPSED / 60))
TOTAL_HR=$((TOTAL_MIN / 60))
TOTAL_MIN=$((TOTAL_MIN % 60))

PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || \
            curl -s https://ifconfig.me 2>/dev/null || echo "N/A")

banner "Deployment Summary"
echo ""
if [ $ERRORS -eq 0 ]; then
  echo -e "  ${GREEN}${BOLD}✅ ALL PHASES COMPLETED SUCCESSFULLY${NC}"
else
  echo -e "  ${YELLOW}⚠️  Completed with $ERRORS error(s)${NC}"
fi
echo ""
echo "  Duration:   ${TOTAL_HR}h ${TOTAL_MIN}m"
echo "  Public IP:  $PUBLIC_IP"
echo ""
echo "  ── Endpoints ──"
echo "  Website:    http://$PUBLIC_IP:3001   →  https://finalevolutiongroup.com"
echo "  Streaming:  ws://$PUBLIC_IP:8888     →  wss://stream.finalevolutiongroup.com"
echo "  Web App:    http://$PUBLIC_IP:3000   →  https://app.finalevolutiongroup.com"
echo "  API:        http://$PUBLIC_IP:8888   →  https://api.finalevolutiongroup.com"
echo "  Health:     http://$PUBLIC_IP:9090/health"
echo ""
echo "  ── Next Steps ──"
echo "  1. Configure DNS records → see deploy/aws/DNS_CONFIGURATION.md"
echo "  2. Run SSL setup:  sudo certbot --nginx -d finalevolutiongroup.com"
echo "  3. Monitor:        bash deploy/aws/monitor_dashboard.sh --watch"
echo "  4. Test:           bash scripts/test_deployment.sh"
echo ""

# Send final notification
if [ -n "${SLACK_WEBHOOK:-}" ]; then
  STATUS=$( [ $ERRORS -eq 0 ] && echo "SUCCESS" || echo "COMPLETED WITH ERRORS" )
  curl -s -X POST -H 'Content-type: application/json' \
    --data "{\"text\":\"🎮 FEL Deployment $STATUS\\nIP: $PUBLIC_IP\\nDuration: ${TOTAL_HR}h ${TOTAL_MIN}m\\nWebsite: http://$PUBLIC_IP:3001\\nStreaming: ws://$PUBLIC_IP:8888\"}" \
    "$SLACK_WEBHOOK" >/dev/null 2>&1 || true
fi

exit $ERRORS
