#!/bin/bash
# =============================================================================
# Final Evolution Lab - Fleet-Wide Deployment via ASG Instance Refresh
# =============================================================================
# Triggers a rolling deployment across all GPU instances in the Auto Scaling Group
#
# Usage:
#   ./deploy-fleet.sh [--version <build-version>] [--min-healthy 50]
# =============================================================================
set -euo pipefail

S3_BUCKET="${FEL_S3_BUCKET:-fel-ue5-builds}"
AWS_REGION="${AWS_REGION:-us-west-2}"
ASG_NAME="${FEL_ASG_NAME:-final-evolution-lab-production-gpu-asg}"
MIN_HEALTHY_PCT=50
VERSION=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --version) VERSION="$2"; shift 2 ;;
    --min-healthy) MIN_HEALTHY_PCT="$2"; shift 2 ;;
    --asg) ASG_NAME="$2"; shift 2 ;;
    *) echo "Unknown: $1"; exit 1 ;;
  esac
done

# Get latest version if not specified
if [ -z "$VERSION" ]; then
  VERSION=$(aws s3 cp "s3://$S3_BUCKET/builds/LATEST" - --region "$AWS_REGION")
fi

echo "================================================================"
echo "  FEL Fleet Deployment"
echo "  Version: $VERSION"
echo "  ASG: $ASG_NAME"
echo "  Min Healthy: ${MIN_HEALTHY_PCT}%"
echo "================================================================"

# Verify build exists
if ! aws s3 ls "s3://$S3_BUCKET/builds/fel-build-$VERSION.tar.gz" --region "$AWS_REGION" &>/dev/null; then
  echo "ERROR: Build not found in S3"
  exit 1
fi

# Start instance refresh (rolling deployment)
REFRESH_ID=$(aws autoscaling start-instance-refresh \
  --auto-scaling-group-name "$ASG_NAME" \
  --preferences "MinHealthyPercentage=$MIN_HEALTHY_PCT,InstanceWarmup=600" \
  --region "$AWS_REGION" \
  --query 'InstanceRefreshId' \
  --output text)

echo "Instance refresh started: $REFRESH_ID"
echo "Monitor: aws autoscaling describe-instance-refreshes --auto-scaling-group-name $ASG_NAME --region $AWS_REGION"

# Monitor progress
while true; do
  STATUS=$(aws autoscaling describe-instance-refreshes \
    --auto-scaling-group-name "$ASG_NAME" \
    --instance-refresh-ids "$REFRESH_ID" \
    --region "$AWS_REGION" \
    --query 'InstanceRefreshes[0].Status' \
    --output text)
  
  PCT=$(aws autoscaling describe-instance-refreshes \
    --auto-scaling-group-name "$ASG_NAME" \
    --instance-refresh-ids "$REFRESH_ID" \
    --region "$AWS_REGION" \
    --query 'InstanceRefreshes[0].PercentageComplete' \
    --output text 2>/dev/null || echo "0")
  
  echo "[$(date -u +%H:%M:%S)] Status: $STATUS (${PCT}% complete)"
  
  case $STATUS in
    Successful)
      echo "Fleet deployment complete! ✅"
      exit 0
      ;;
    Failed|Cancelled|RollbackSuccessful|RollbackFailed)
      echo "Fleet deployment failed: $STATUS ❌"
      exit 1
      ;;
  esac
  
  sleep 30
done
