# Final Evolution Lab — Troubleshooting Playbook

## Quick Diagnostics

```bash
# Run full validation
bash deploy/aws/validate_environment.sh

# Check GPU
nvidia-smi

# Check services
docker compose -f streaming/docker-compose.yml ps
curl http://localhost:8888/healthz
curl http://localhost:3000

# Check logs
tail -100 logs/pipeline_*.log
tail -50 /var/log/fel-bootstrap.log
```

---

## GPU Issues

### No NVIDIA GPU detected
**Symptom**: `nvidia-smi` returns error
**Causes & Fixes**:

```bash
# 1. Check if GPU hardware exists
lspci | grep -i nvidia

# 2. If hardware exists but driver not loaded
sudo apt install nvidia-driver-535
sudo reboot

# 3. If driver installed but fails
sudo dmesg | grep -i nvidia
# Check for secure boot issues
mokutil --sb-state

# 4. Nuclear option: reinstall
sudo apt purge 'nvidia-*'
sudo apt autoremove
sudo ubuntu-drivers install
sudo reboot
```

### Driver version mismatch
**Symptom**: CUDA errors, driver too old
```bash
# Check current version
nvidia-smi | head -3

# Need 535+? Upgrade:
sudo apt install nvidia-driver-535
sudo reboot

# Verify CUDA compatibility
nvcc --version
```

### GPU out of memory
**Symptom**: `CUDA out of memory` errors during UE5 build
```bash
# Check GPU memory
nvidia-smi --query-gpu=memory.used,memory.total --format=csv

# Kill other GPU processes
nvidia-smi --query-compute-apps=pid --format=csv,noheader | xargs -r kill

# If persistent, upgrade instance:
# g5.2xlarge (24GB) → g5.4xlarge (24GB) → g5.12xlarge (4x24GB)
```

---

## UE5 Build Failures

### GitHub 403 error (UE5 clone)
**Symptom**: `fatal: Authentication failed` or `403 Forbidden`
```bash
# Verify token
curl -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/user

# Verify Epic Games access
curl -H "Authorization: token $GITHUB_TOKEN" \
  https://api.github.com/repos/EpicGames/UnrealEngine

# Fix: Ensure GitHub account is linked to Epic Games
# Visit: https://www.unrealengine.com/en-US/ue-on-github
```

### Out of disk space
**Symptom**: `No space left on device`
```bash
# Check disk usage
df -h /home
du -sh /home/ubuntu/* | sort -rh | head -20

# Clean up
rm -rf /home/ubuntu/rork-final-evolution-lab/Builds/old-*
docker system prune -af
sudo apt autoremove

# If still not enough, resize EBS:
# AWS Console → EC2 → Volumes → Modify → increase size
sudo growpart /dev/nvme0n1 1  # or /dev/xvda1
sudo resize2fs /dev/nvme0n1p1
```

### Build compilation errors
**Symptom**: Build fails with C++ errors
```bash
# Check the exact error
tail -100 logs/pipeline_*.log | grep -i error

# Common fix: missing dependencies
sudo apt install -y build-essential clang libssl-dev

# Retry build
bash scripts/ue5_setup/install_ue5_linux.sh
```

---

## Networking Issues

### Pixel Streaming not connecting
```bash
# Check signalling server
curl http://localhost:8888/healthz

# Check WebSocket
wscat -c ws://localhost:8888 2>/dev/null || \
  python3 -c "import asyncio, websockets; asyncio.run(websockets.connect('ws://localhost:8888'))"

# Check security group allows ports 8888, 8889, 3478
aws ec2 describe-security-groups --group-ids sg-XXX \
  --query 'SecurityGroups[].IpPermissions[].[FromPort,ToPort]'

# Check firewall
sudo ufw status
sudo iptables -L -n | grep -E '(8888|8889|3478)'
```

### TURN server not working
```bash
# Check TURN
nc -zv localhost 3478
docker logs $(docker ps -q -f name=coturn) 2>/dev/null

# Test TURN
turnutils_uclient -T -p 3478 -u fel -w fel_streaming_2026 localhost
```

---

## Service Issues

### Docker containers not starting
```bash
# Check Docker
sudo systemctl status docker
docker compose -f streaming/docker-compose.yml logs

# Fix GPU access for Docker
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker

# Rebuild
docker compose -f streaming/docker-compose.yml down
docker compose -f streaming/docker-compose.yml up --build -d
```

### Website not loading
```bash
# Check Nginx
sudo nginx -t
sudo systemctl status nginx
sudo tail -20 /var/log/nginx/error.log

# Check website process
pm2 status
pm2 logs fel-website

# Restart
pm2 restart fel-website
sudo systemctl restart nginx
```

### SSL certificate issues
```bash
# Check cert
sudo certbot certificates

# Renew
sudo certbot renew --dry-run
sudo certbot renew

# Reissue
sudo certbot --nginx -d finalevolutiongroup.com
```

---

## Pipeline Resume

```bash
# Check where pipeline failed
cat logs/pipeline_resume.json

# Resume from failure point
bash deploy/aws/deploy_final_evolution_lab.sh --resume

# Or skip to specific phase
bash scripts/ue5_setup/fel_complete_pipeline.sh --skip-cv --skip-install
```

---

## Memory Issues

### System out of RAM
```bash
# Check memory
free -m
top -o %MEM | head -20

# Create swap (if not exists)
sudo fallocate -l 16G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

# Kill memory hogs
ps aux --sort=-%mem | head -10
```

---

## Rollback

```bash
# Stop all services
bash scripts/stop_services.sh
docker compose -f streaming/docker-compose.yml down
pm2 delete all 2>/dev/null || true

# Git rollback
cd /home/ubuntu/rork-final-evolution-lab
git stash
git checkout main
git pull

# Restart
bash deploy/aws/deploy_final_evolution_lab.sh --deploy
```

---

## Emergency Contacts / Escalation

1. Check logs: `logs/pipeline_*.log`
2. Check bootstrap: `/var/log/fel-bootstrap.log`
3. GPU issues: `dmesg | grep -i nvidia`
4. Network: `ss -tlnp` to see what's listening
5. Full diagnostic: `bash deploy/aws/validate_environment.sh`
