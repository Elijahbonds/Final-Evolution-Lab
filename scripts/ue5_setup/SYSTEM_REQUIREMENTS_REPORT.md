# System Requirements Assessment — Current VM

**Date**: 2026-04-01
**Machine**: DeepAgent Cloud VM (AWS)

## Hardware Assessment

| Component | Available | UE5 Requirement | Status |
|-----------|-----------|-----------------|--------|
| **CPU** | 32 cores (Intel Xeon 6975P-C) | 6+ cores | ✅ Exceeds |
| **RAM** | 247 GB | 32 GB | ✅ Exceeds |
| **Disk** | 335 GB free / 503 GB total | 200 GB | ✅ Sufficient |
| **GPU** | None | NVIDIA GTX 1080+ | ❌ **Missing** |
| **OS** | Debian 12 (bookworm) x86_64 | Ubuntu 22.04+ | ✅ Compatible |

## Limitation Impact

### What CAN be done on this VM:
- ✅ Project configuration and file setup
- ✅ Script creation and preparation
- ✅ iOS app code updates (Config.swift, PixelStreamingService)
- ✅ UE5 source download and partial build (build tools only)
- ✅ Asset manifest and import script generation
- ✅ Docker/deployment configuration

### What CANNOT be done on this VM:
- ❌ UE5 Editor rendering (requires GPU)
- ❌ Asset import into UE5 (requires running Editor)
- ❌ Project cooking/packaging (requires GPU for shader compilation)
- ❌ Pixel Streaming server (requires GPU for real-time rendering)
- ❌ iOS build (requires macOS + Xcode)

## Recommended GPU Machines

### Cloud (for Linux server build + cooking)
- **AWS**: g5.4xlarge (NVIDIA A10G, 64GB RAM) — ~$1.62/hr
- **GCP**: n1-standard-8 + T4 GPU — ~$0.95/hr
- **Azure**: NC6s_v3 (NVIDIA V100) — ~$3.06/hr

### Local (for full development)
- **macOS**: Mac Studio M2 Ultra (for iOS + UE5 Editor)
- **Windows/Linux**: RTX 3080+ desktop (for UE5 Editor + cooking)

## Transfer Instructions

```bash
# Tar the project for transfer
cd /home/ubuntu
tar czf fel-project.tar.gz rork-final-evolution-lab/

# SCP to GPU machine
scp fel-project.tar.gz user@gpu-machine:~/

# On GPU machine
cd ~
tar xzf fel-project.tar.gz
cd rork-final-evolution-lab
./scripts/ue5_setup/fel_complete_pipeline.sh
```
