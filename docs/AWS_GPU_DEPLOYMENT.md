# AWS GPU Deployment Guide — Final Evolution Lab

## Overview

This guide covers deploying the FEL pipeline to an AWS G5.2xlarge instance
with NVIDIA A10G GPU for:

- Unreal Engine 5 compilation and cooking
- CV preprocessing with GPU acceleration
- Pixel Streaming server
- Complete build pipeline execution

## Instance Specifications

| Component | G5.2xlarge Spec |
|-----------|----------------|
| GPU | NVIDIA A10G (24GB VRAM) |
| vCPUs | 8 |
| RAM | 32 GB |
| Storage | 500 GB gp3 (configured) |
| Network | Up to 10 Gbps |
| Cost | ~$1.21/hr on-demand |

## Prerequisites

1. **AWS Account** with EC2 permissions
2. **AWS CLI** installed and configured (`aws configure`)
3. **GitHub account** linked to Epic Games (for UE5 source)
4. **SSH key pair** (auto-created or existing)

## Quick Start

### Step 1: Configure Environment

```bash
cp .env.template .env
# Edit .env with your AWS credentials and GitHub PAT
```

Required `.env` variables:
```
AWS_ACCESS_KEY_ID=AKIA...
AWS_SECRET_ACCESS_KEY=...
AWS_REGION=us-east-1
GITHUB_PAT=ghp_...
```

### Step 2: Provision GPU Instance

```bash
python3 scripts/aws_deployment/provision_g5_instance.py --launch
```

This will:
- Create SSH key pair (`~/.ssh/fel-gpu-key.pem`)
- Set up security group with required ports
- Launch G5.2xlarge with Ubuntu 22.04
- Install NVIDIA drivers, CUDA, Vulkan (via user-data)
- Save instance info to `~/.fel-gpu-instance.json`

### Step 3: Deploy Project to GPU

```bash
# Wait ~5 minutes for instance initialization
bash scripts/aws_deployment/deploy_to_gpu.sh <GPU_IP>
```

### Step 4: Run Pipeline on GPU

```bash
# SSH into GPU instance
ssh -i ~/.ssh/fel-gpu-key.pem ubuntu@<GPU_IP>

# Navigate to project
cd /home/ubuntu/fel-workspace/rork-final-evolution-lab

# Run complete pipeline
bash scripts/ue5_setup/fel_complete_pipeline.sh
```

### Step 5: Monitor Progress

From your local machine:
```bash
python3 scripts/aws_deployment/monitor_pipeline.py --remote <GPU_IP> --dashboard
```

### Step 6: Retrieve Builds

```bash
# Download Linux server build
scp -i ~/.ssh/fel-gpu-key.pem -r ubuntu@<GPU_IP>:/home/ubuntu/fel-workspace/rork-final-evolution-lab/Builds/LinuxServer/ ./Builds/

# Download iOS build files (if cooked on Linux)
scp -i ~/.ssh/fel-gpu-key.pem -r ubuntu@<GPU_IP>:/home/ubuntu/fel-workspace/rork-final-evolution-lab/Builds/iOS/ ./Builds/
```

### Step 7: Terminate Instance (IMPORTANT!)

```bash
# Check status
python3 scripts/aws_deployment/provision_g5_instance.py --status

# Terminate to stop charges
python3 scripts/aws_deployment/provision_g5_instance.py --terminate --instance-id i-xxxxx
```

## Security Group Ports

| Port | Protocol | Purpose |
|------|----------|--------|
| 22 | TCP | SSH |
| 80 | TCP | HTTP |
| 443 | TCP | HTTPS |
| 3000 | TCP | Frontend web app |
| 3478 | TCP/UDP | TURN/STUN (WebRTC) |
| 8888 | TCP | Pixel Streaming signalling |
| 8889 | TCP | Pixel Streaming HTTPS |

## Cost Optimization

### Spot Instances (60-70% savings)

Modify `provision_g5_instance.py` to use spot pricing:
```python
# Add to launch command
"--instance-market-options", json.dumps({
    "MarketType": "spot",
    "SpotOptions": {
        "MaxPrice": "0.50",  # Set max hourly price
        "SpotInstanceType": "one-time"
    }
})
```

### Estimated Pipeline Costs

| Phase | Estimated Time | Cost (On-Demand) |
|-------|---------------|------------------|
| CV Preprocessing | ~30 min | ~$0.60 |
| UE5 Build | ~2-4 hours | ~$2.42-$4.84 |
| Cook Linux | ~1-2 hours | ~$1.21-$2.42 |
| Cook iOS | ~1-2 hours | ~$1.21-$2.42 |
| **Total** | **~5-9 hours** | **~$6-$11** |

## Troubleshooting

### Instance Won't Launch
- Check service quotas: `aws service-quotas get-service-quota --service-code ec2 --quota-code L-3819A6DF`
- G5 instances may not be available in all AZs — try different subnet
- Request quota increase if needed

### GPU Not Detected After Launch
- Wait for user-data script to complete (~10 minutes)
- Check setup log: `ssh ... 'cat /var/log/fel-setup.log'`
- May need reboot: `ssh ... 'sudo reboot'`

### UE5 GitHub Clone Fails
- Verify `GITHUB_PAT` is set correctly
- Ensure GitHub account is linked to Epic Games at: https://www.unrealengine.com/en-US/ue-on-github
- Test: `curl -H "Authorization: token YOUR_PAT" https://api.github.com/repos/EpicGames/UnrealEngine`

### Out of Disk Space
- Default 500GB should be sufficient
- Check: `df -h`
- Clean UE5 intermediate: `rm -rf Engine/Intermediate`

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for more details.
