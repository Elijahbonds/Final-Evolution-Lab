#!/bin/bash
# =============================================================================
# Final Evolution Lab - GPU Server Setup Script
# =============================================================================
# Run this on a fresh Ubuntu 22.04 server with an NVIDIA GPU to prepare it
# for UE5 Pixel Streaming. This is the manual equivalent of the EC2 user_data.
#
# Usage:
#   chmod +x setup-gpu-server.sh
#   sudo ./setup-gpu-server.sh
#
# Prerequisites:
#   - Ubuntu 22.04 LTS
#   - NVIDIA GPU (T4, A10G, RTX, etc.)
#   - Root/sudo access
#   - Internet connectivity
# =============================================================================
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()  { echo -e "${BLUE}[INFO]${NC}  $1"; }
log_ok()    { echo -e "${GREEN}[OK]${NC}    $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check root
if [ "$EUID" -ne 0 ]; then
  log_error "Please run as root (sudo ./setup-gpu-server.sh)"
  exit 1
fi

# Check Ubuntu
if ! grep -q 'Ubuntu' /etc/os-release; then
  log_error "This script requires Ubuntu 22.04"
  exit 1
fi

echo "================================================================"
echo "  Final Evolution Lab - GPU Server Setup"
echo "  $(date -u)"
echo "================================================================"

# ---- Phase 1: System Updates ----
log_info "Phase 1: System updates..."
apt-get update -qq
apt-get upgrade -y -qq
apt-get install -y -qq \
  build-essential \
  linux-headers-$(uname -r) \
  software-properties-common \
  curl wget git \
  htop nvtop iotop \
  net-tools jq unzip \
  python3-pip \
  dumb-init
log_ok "System packages installed"

# ---- Phase 2: NVIDIA Drivers ----
log_info "Phase 2: Installing NVIDIA GPU drivers..."

# Check for GPU
if ! lspci | grep -qi nvidia; then
  log_warn "No NVIDIA GPU detected. Skipping driver installation."
  log_warn "Pixel Streaming requires a GPU to function."
else
  # Install NVIDIA drivers
  wget -q https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.1-1_all.deb
  dpkg -i cuda-keyring_1.1-1_all.deb
  rm cuda-keyring_1.1-1_all.deb
  apt-get update -qq
  apt-get install -y -qq nvidia-driver-535 nvidia-utils-535
  
  # Verify
  if nvidia-smi &>/dev/null; then
    log_ok "NVIDIA drivers installed successfully"
    nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader
  else
    log_warn "NVIDIA drivers installed but GPU not accessible (reboot may be required)"
  fi
fi

# ---- Phase 3: Docker ----
log_info "Phase 3: Installing Docker..."
apt-get install -y -qq docker.io docker-compose
systemctl enable docker
systemctl start docker
usermod -aG docker ubuntu 2>/dev/null || true
log_ok "Docker installed"

# Install NVIDIA Container Toolkit for GPU in Docker
if lspci | grep -qi nvidia; then
  curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
  curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
    tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
  apt-get update -qq
  apt-get install -y -qq nvidia-container-toolkit
  nvidia-ctk runtime configure --runtime=docker
  systemctl restart docker
  log_ok "NVIDIA Container Toolkit installed"
fi

# ---- Phase 4: Node.js ----
log_info "Phase 4: Installing Node.js 20.x..."
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y -qq nodejs
log_ok "Node.js $(node --version) installed"

# ---- Phase 5: Nginx ----
log_info "Phase 5: Installing and configuring Nginx..."
apt-get install -y -qq nginx certbot python3-certbot-nginx

# Write Nginx config for Pixel Streaming
cat > /etc/nginx/sites-available/fel-streaming << 'NGINXEOF'
# Final Evolution Lab - Pixel Streaming Reverse Proxy
# Handles HTTP, WebSocket, and HTTPS termination

# Rate limiting zones
limit_req_zone $binary_remote_addr zone=api:10m rate=30r/s;
limit_req_zone $binary_remote_addr zone=ws:10m rate=5r/s;
limit_conn_zone $binary_remote_addr zone=streams:10m;

upstream signaling_backend {
    server 127.0.0.1:8888;
    keepalive 32;
}

upstream websocket_backend {
    server 127.0.0.1:8889;
}

server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    # ACME challenge for Let's Encrypt
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }

    # Health check (no rate limit)
    location /healthz {
        proxy_pass http://signaling_backend/healthz;
        access_log off;
    }

    # API endpoints
    location /api/ {
        limit_req zone=api burst=50 nodelay;
        proxy_pass http://signaling_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # WebSocket signaling
    location /ws {
        limit_req zone=ws burst=10 nodelay;
        limit_conn streams 50;

        proxy_pass http://websocket_backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;

        # Long timeout for persistent WebSocket connections
        proxy_read_timeout 86400s;
        proxy_send_timeout 86400s;
    }

    # Frontend static files
    location / {
        proxy_pass http://signaling_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Deny access to hidden files
    location ~ /\. {
        deny all;
    }
}
NGINXEOF

rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/fel-streaming /etc/nginx/sites-enabled/
nginx -t && systemctl restart nginx
log_ok "Nginx configured"

# ---- Phase 6: Application Directories ----
log_info "Phase 6: Creating application structure..."
mkdir -p /opt/fel/{builds,current,logs,config,signaling}
chown -R ubuntu:ubuntu /opt/fel
log_ok "Application directories created"

# ---- Phase 7: Systemd Services ----
log_info "Phase 7: Creating systemd service files..."

# Signaling server
cat > /etc/systemd/system/fel-signaling.service << 'EOF'
[Unit]
Description=FEL Pixel Streaming Signaling Server
After=network.target
Wants=network-online.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/opt/fel/signaling
ExecStart=/usr/bin/node server.js
Restart=always
RestartSec=5
StandardOutput=append:/opt/fel/logs/signaling.log
StandardError=append:/opt/fel/logs/signaling.log
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOF

# UE5 server
cat > /etc/systemd/system/fel-ue5-server.service << 'EOF'
[Unit]
Description=FEL UE5 Pixel Streaming Server
After=network.target fel-signaling.service
Wants=fel-signaling.service

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/opt/fel/current
ExecStartPre=/bin/bash -c 'test -f /opt/fel/current/FinalEvolutionLab.sh'
ExecStart=/opt/fel/current/FinalEvolutionLab.sh \
  -RenderOffscreen \
  -Windowed \
  -ForceRes \
  -ResX=1920 \
  -ResY=1080 \
  -PixelStreamingIP=127.0.0.1 \
  -PixelStreamingPort=8889 \
  -AllowPixelStreamingCommands \
  -log
Restart=on-failure
RestartSec=15
StandardOutput=append:/opt/fel/logs/ue5-server.log
StandardError=append:/opt/fel/logs/ue5-server.log
LimitNOFILE=65536
OOMScoreAdjust=-500

[Install]
WantedBy=multi-user.target
EOF

# Log rotation
cat > /etc/logrotate.d/fel << 'EOF'
/opt/fel/logs/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    copytruncate
}
EOF

systemctl daemon-reload
log_ok "Systemd services created"

# ---- Phase 8: CoTURN (optional) ----
log_info "Phase 8: Installing TURN/STUN server (coturn)..."
apt-get install -y -qq coturn

PUBLIC_IP=$(curl -s http://checkip.amazonaws.com || echo "0.0.0.0")
PRIVATE_IP=$(hostname -I | awk '{print $1}')

TURN_SECRET=$(openssl rand -hex 16)

cat > /etc/turnserver.conf << TURNEOF
realm=finalevolutiongroup.com
fingerprint
lt-cred-mech
use-auth-secret
static-auth-secret=$TURN_SECRET

listening-port=3478
tls-listening-port=5349
listening-ip=$PRIVATE_IP
external-ip=$PUBLIC_IP/$PRIVATE_IP
relay-ip=$PRIVATE_IP
min-port=49152
max-port=65535

no-multicast-peers
no-cli
no-tlsv1
no-tlsv1_1

log-file=/var/log/turnserver.log
verbose

total-quota=100
max-bps=0
stale-nonce=600
TURNEOF

sed -i 's/#TURNSERVER_ENABLED=1/TURNSERVER_ENABLED=1/' /etc/default/coturn

# Save TURN secret for reference
echo "TURN_SECRET=$TURN_SECRET" >> /opt/fel/config/turn.env
echo "TURN_PUBLIC_IP=$PUBLIC_IP" >> /opt/fel/config/turn.env

log_ok "CoTURN installed (secret saved to /opt/fel/config/turn.env)"

# ---- Summary ----
echo ""
echo "================================================================"
echo "  Setup Complete!"
echo "================================================================"
echo ""
echo "  GPU:        $(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null || echo 'Not detected')"
echo "  Docker:     $(docker --version 2>/dev/null || echo 'Not installed')"
echo "  Node.js:    $(node --version 2>/dev/null || echo 'Not installed')"
echo "  Nginx:      $(nginx -v 2>&1 | awk -F/ '{print $2}')"
echo "  TURN secret: $TURN_SECRET"
echo ""
echo "  Next steps:"
echo "    1. Upload your UE5 build to /opt/fel/current/"
echo "    2. Setup the signaling server: /opt/fel/signaling/"
echo "    3. Setup SSL: sudo certbot --nginx -d your-domain.com"
echo "    4. Start services: sudo systemctl start fel-signaling fel-ue5-server"
echo ""
echo "  If the GPU was just installed, please REBOOT:"
echo "    sudo reboot"
echo "================================================================"
