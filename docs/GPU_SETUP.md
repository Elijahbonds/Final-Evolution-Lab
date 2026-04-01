# GPU Machine Setup Guide for UE5

## Recommended GPU Machines

### AWS
| Instance | GPU | vCPU | RAM | Storage | Cost/hr |
|----------|-----|------|-----|---------|----------|
| g4dn.xlarge | T4 16GB | 4 | 16GB | 125GB NVMe | ~$0.526 |
| g4dn.2xlarge | T4 16GB | 8 | 32GB | 225GB NVMe | ~$0.752 |
| g5.2xlarge | A10G 24GB | 8 | 32GB | 450GB NVMe | ~$1.212 |
| **g5.4xlarge** | **A10G 24GB** | **16** | **64GB** | **600GB NVMe** | **~$1.624** |

> **Recommended**: g5.4xlarge for UE5 build + runtime

### GCP
| Machine | GPU | vCPU | RAM | Cost/hr |
|---------|-----|------|-----|---------|
| n1-standard-8 + T4 | T4 16GB | 8 | 30GB | ~$0.95 |
| **n1-standard-16 + T4** | **T4 16GB** | **16** | **60GB** | **~$1.35** |
| a2-highgpu-1g | A100 40GB | 12 | 85GB | ~$3.67 |

### Azure
| VM Size | GPU | vCPU | RAM | Cost/hr |
|---------|-----|------|-----|---------|
| NC4as_T4_v3 | T4 16GB | 4 | 28GB | ~$0.526 |
| **NC8as_T4_v3** | **T4 16GB** | **8** | **56GB** | **~$0.752** |

---

## Setup Steps

### 1. Provision Machine

```bash
# AWS Example
aws ec2 run-instances \
  --image-id ami-0abcdef1234567890 \
  --instance-type g5.4xlarge \
  --key-name your-key \
  --security-group-ids sg-xxx \
  --block-device-mappings '[{"DeviceName":"/dev/sda1","Ebs":{"VolumeSize":500,"VolumeType":"gp3"}}]'
```

### 2. Install GPU Drivers

```bash
# NVIDIA drivers (Ubuntu 22.04)
sudo apt update
sudo apt install -y linux-headers-$(uname -r)
sudo apt install -y nvidia-driver-535 nvidia-utils-535
sudo reboot

# Verify
nvidia-smi
```

### 3. Install Vulkan (for UE5)

```bash
sudo apt install -y vulkan-tools libvulkan-dev
vulkaninfo --summary
```

### 4. Transfer Project

```bash
# From development machine
rsync -avz --exclude='node_modules' --exclude='.git' --exclude='Builds' \
  /home/ubuntu/rork-final-evolution-lab/ \
  gpu-server:/home/ubuntu/rork-final-evolution-lab/
```

### 5. Build UE5 & Cook Project

```bash
# Run the complete pipeline
cd /home/ubuntu/rork-final-evolution-lab
chmod +x scripts/ue5_setup/*.sh
./scripts/ue5_setup/fel_complete_pipeline.sh
```

### 6. Launch Pixel Streaming

```bash
# Start UE5 with Pixel Streaming
./Builds/LinuxServer/FinalEvolutionLab.sh \
  -RenderOffscreen \
  -PixelStreamingURL=ws://localhost:8888 \
  -PixelStreamingIP=0.0.0.0 \
  -Res=1920x1080 \
  -FPS=60
```

---

## Firewall Rules

| Port | Protocol | Purpose |
|------|----------|---------|
| 22 | TCP | SSH |
| 80 | TCP | HTTP redirect |
| 443 | TCP | HTTPS |
| 8888 | TCP | Signalling server |
| 3478 | TCP/UDP | TURN/STUN |
| 49152-65535 | UDP | TURN relay range |
