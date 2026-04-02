# Final Evolution Lab — AWS Deployment

## Quick Start

### Option 1: One-Click (Interactive)
```bash
bash deploy/aws/deploy_final_evolution_lab.sh --interactive
```

### Option 2: Full Automated
```bash
# Set credentials
export GITHUB_TOKEN="ghp_..."    # Epic Games PAT
export MESHY_API_KEY="msy_..."    # Meshy AI
export LUMA_API_KEY="..."         # Luma AI

# Provision + Build + Deploy
bash deploy/aws/deploy_final_evolution_lab.sh --all
```

### Option 3: Step by Step
```bash
# 1. Provision AWS G5.2xlarge
bash deploy/aws/deploy_final_evolution_lab.sh --provision

# 2. SSH to instance, then:
bash deploy/aws/bootstrap.sh
bash deploy/aws/validate_environment.sh
bash deploy/aws/deploy_final_evolution_lab.sh --build --deploy
```

## Files

| File | Description |
|------|-------------|
| `deploy_final_evolution_lab.sh` | **Master one-click deployment script** |
| `bootstrap.sh` | GPU drivers, CUDA, Vulkan, deps install |
| `validate_environment.sh` | Pre-flight checks (GPU, RAM, disk, deps) |
| `run_pipeline.sh` | Pipeline orchestrator with retry/monitoring |
| `monitor_dashboard.sh` | Real-time terminal dashboard |
| `deploy_website.sh` | Marketing website deployment |
| `configure_dns.sh` | Nginx, SSL, DNS setup |
| `provision_boto3.py` | Python-based AWS provisioning |
| `cloudformation.yaml` | CloudFormation template |
| `terraform/` | Terraform configuration |
| `MANUAL_PROVISIONING.md` | Step-by-step manual guide |
| `TROUBLESHOOTING.md` | Error resolution playbook |

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                 AWS G5.2xlarge                       │
│  ┌───────────────────────────────────────────────┐  │
│  │  NVIDIA A10G GPU (24GB VRAM)                  │  │
│  │  8 vCPU, 32GB RAM, 500GB gp3 EBS             │  │
│  └───────────────────────────────────────────────┘  │
│                                                     │
│  ┌─────────┐  ┌──────────┐  ┌─────────────────┐   │
│  │ UE5     │  │ Signalling│  │ Marketing       │   │
│  │ Server  │──│ :8888     │  │ Website :3001   │   │
│  │ (GPU)   │  │ :8889     │  │ (Next.js/PM2)   │   │
│  └─────────┘  └──────────┘  └─────────────────┘   │
│                                                     │
│  ┌─────────┐  ┌──────────┐  ┌─────────────────┐   │
│  │ CoTURN  │  │ Frontend │  │ Nginx           │   │
│  │ :3478   │  │ :3000    │  │ :80/:443        │   │
│  └─────────┘  └──────────┘  └─────────────────┘   │
│                                                     │
│              Elastic IP: x.x.x.x                    │
└─────────────────────────────────────────────────────┘
                        │
        DNS: finalevolutiongroup.com
        ├── @        → Marketing Website
        ├── stream   → Pixel Streaming (WSS)
        ├── app      → Web App Frontend
        └── api      → REST API
```

## Pipeline Phases

| Phase | Description | Duration (est.) |
|-------|-------------|------------------|
| 0 | CV Preprocessing (10 @elijahbonds videos) | ~15 min |
| 1 | UE5 Engine Build from source | ~2-4 hours |
| 2 | Environment Generation (12 presets) | ~30 min |
| 3 | Asset Import (472+ animations) | ~30 min |
| 4 | Project Cooking (Linux Server + iOS) | ~1-2 hours |
| 5 | Deployment Package | ~15 min |
| **Total** | | **~4-8 hours** |

## Monitoring

```bash
# Live dashboard
bash deploy/aws/monitor_dashboard.sh --watch

# Check progress
cat logs/pipeline_progress.json | jq .

# Tail logs
tail -f logs/pipeline_*.log
```

## Cost Optimization

- **Build phase**: g5.2xlarge (~$1.21/hr) — Stop after build completes
- **Production**: Consider g4dn.xlarge (~$0.53/hr) for streaming only
- **Spot instances**: Up to 90% savings for builds (use `--spot` if available)
- Use `aws ec2 stop-instances` when not serving traffic
