#!/bin/bash
# =============================================================================
# Final Evolution Lab - GPU Monitoring & CloudWatch Metrics Publisher
# =============================================================================
# Publishes custom GPU metrics to CloudWatch. Run via cron every minute.
#
# Cron setup:
#   * * * * * /opt/fel/scripts/monitor-gpu.sh
# =============================================================================

AWS_REGION="${AWS_REGION:-us-west-2}"
NAMESPACE="FinalEvolutionLab"
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id 2>/dev/null || echo "unknown")

# Get GPU metrics
if nvidia-smi &>/dev/null; then
  GPU_UTIL=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits | head -1 | tr -d ' ')
  GPU_MEM_USED=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits | head -1 | tr -d ' ')
  GPU_MEM_TOTAL=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | head -1 | tr -d ' ')
  GPU_TEMP=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits | head -1 | tr -d ' ')
  GPU_POWER=$(nvidia-smi --query-gpu=power.draw --format=csv,noheader,nounits | head -1 | tr -d ' ')
  
  # Calculate memory percentage
  if [ "$GPU_MEM_TOTAL" -gt 0 ] 2>/dev/null; then
    GPU_MEM_PCT=$(echo "scale=1; $GPU_MEM_USED * 100 / $GPU_MEM_TOTAL" | bc)
  else
    GPU_MEM_PCT=0
  fi
  
  # Publish to CloudWatch
  aws cloudwatch put-metric-data \
    --namespace "$NAMESPACE" \
    --metric-data \
      "MetricName=GPUUtilization,Value=$GPU_UTIL,Unit=Percent,Dimensions=[{Name=InstanceId,Value=$INSTANCE_ID}]" \
      "MetricName=GPUMemoryUsed,Value=$GPU_MEM_USED,Unit=Megabytes,Dimensions=[{Name=InstanceId,Value=$INSTANCE_ID}]" \
      "MetricName=GPUMemoryPercent,Value=$GPU_MEM_PCT,Unit=Percent,Dimensions=[{Name=InstanceId,Value=$INSTANCE_ID}]" \
      "MetricName=GPUTemperature,Value=$GPU_TEMP,Unit=None,Dimensions=[{Name=InstanceId,Value=$INSTANCE_ID}]" \
      "MetricName=GPUPowerDraw,Value=$GPU_POWER,Unit=None,Dimensions=[{Name=InstanceId,Value=$INSTANCE_ID}]" \
    --region "$AWS_REGION" 2>/dev/null
  
  # Count active streaming sessions
  ACTIVE_SESSIONS=$(curl -s http://localhost:8888/healthz 2>/dev/null | python3 -c "import json,sys; print(json.load(sys.stdin).get('players',0))" 2>/dev/null || echo "0")
  
  aws cloudwatch put-metric-data \
    --namespace "$NAMESPACE" \
    --metric-data \
      "MetricName=ActiveStreamingSessions,Value=$ACTIVE_SESSIONS,Unit=Count,Dimensions=[{Name=InstanceId,Value=$INSTANCE_ID}]" \
    --region "$AWS_REGION" 2>/dev/null
fi
