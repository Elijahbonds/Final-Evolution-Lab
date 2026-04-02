#!/bin/bash
# =============================================================================
# Final Evolution Lab - GPU Instance Bootstrap Script
# =============================================================================
# This script runs on first boot to configure a GPU instance for Pixel Streaming
# =============================================================================
set -euo pipefail
exec > >(tee /var/log/fel-bootstrap.log) 2>&1

echo "========================================"
echo "FEL Pixel Streaming Instance Bootstrap"
echo "Started: $(date -u)"
echo "========================================"

# --- Environment Variables ---
export DEBIAN_FRONTEND=noninteractive
export AWS_REGION="${aws_region}"
export S3_BUILDS_BUCKET="${s3_builds_bucket}"
export ENVIRONMENT="${environment}"
export PROJECT_NAME="${project_name}"
export TURN_SERVER_IP="${turn_server_ip}"
export TURN_SECRET="${turn_secret}"
export SIGNALING_PORT="${signaling_port}"
export WEBSOCKET_PORT="${websocket_port}"
export LOG_GROUP="${log_group}"

# Save environment for services
cat > /etc/fel-env << 'ENVEOF'
AWS_REGION=${aws_region}
S3_BUILDS_BUCKET=${s3_builds_bucket}
ENVIRONMENT=${environment}
PROJECT_NAME=${project_name}
TURN_SERVER_IP=${turn_server_ip}
TURN_SECRET=${turn_secret}
SIGNALING_PORT=${signaling_port}
WEBSOCKET_PORT=${websocket_port}
LOG_GROUP=${log_group}
ENVEOF

# --- System Updates ---
echo "[1/8] Updating system packages..."
apt-get update -qq
apt-get upgrade -y -qq

# --- Install NVIDIA GPU Drivers ---
echo "[2/8] Installing NVIDIA GPU drivers..."
apt-get install -y -qq linux-headers-$(uname -r) build-essential

# Add NVIDIA driver repo
wget -q https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.1-1_all.deb
dpkg -i cuda-keyring_1.1-1_all.deb
apt-get update -qq
apt-get install -y -qq nvidia-driver-535 nvidia-utils-535

# Verify GPU
nvidia-smi || echo "WARNING: nvidia-smi failed - GPU may not be available yet (reboot may be needed)"

# --- Install Dependencies ---
echo "[3/8] Installing dependencies..."
apt-get install -y -qq \
  awscli \
  docker.io \
  docker-compose \
  nodejs \
  npm \
  nginx \
  certbot \
  python3-certbot-nginx \
  jq \
  htop \
  nvtop \
  unzip \
  net-tools \
  dumb-init

# Enable Docker
systemctl enable docker
systemctl start docker
usermod -aG docker ubuntu

# Install Node.js 20.x
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y -qq nodejs

# --- Install CloudWatch Agent ---
echo "[4/8] Installing CloudWatch agent..."
wget -q https://amazoncloudwatch-agent.s3.amazonaws.com/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
dpkg -i amazon-cloudwatch-agent.deb

# Configure CloudWatch agent
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << 'CWEOF'
{
  "agent": {
    "metrics_collection_interval": 60,
    "logfile": "/opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log"
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/fel-bootstrap.log",
            "log_group_name": "/fel/pixel-streaming",
            "log_stream_name": "{instance_id}/bootstrap"
          },
          {
            "file_path": "/opt/fel/logs/ue5-server.log",
            "log_group_name": "/fel/ue5-server",
            "log_stream_name": "{instance_id}/ue5"
          },
          {
            "file_path": "/opt/fel/logs/signaling.log",
            "log_group_name": "/fel/signaling-server",
            "log_stream_name": "{instance_id}/signaling"
          }
        ]
      }
    }
  },
  "metrics": {
    "namespace": "FinalEvolutionLab",
    "metrics_collected": {
      "cpu": {
        "measurement": ["cpu_usage_idle", "cpu_usage_user", "cpu_usage_system"],
        "totalcpu": true
      },
      "mem": {
        "measurement": ["mem_used_percent", "mem_available"]
      },
      "disk": {
        "measurement": ["used_percent"],
        "resources": ["/"]
      },
      "net": {
        "measurement": ["bytes_sent", "bytes_recv"]
      }
    },
    "append_dimensions": {
      "InstanceId": "$${aws:InstanceId}",
      "AutoScalingGroupName": "$${aws:AutoScalingGroupName}"
    }
  }
}
CWEOF

/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config -m ec2 \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s

# --- Create Application Directories ---
echo "[5/8] Setting up application directories..."
mkdir -p /opt/fel/{builds,current,logs,config,signaling}
chown -R ubuntu:ubuntu /opt/fel

# --- Download Latest Build from S3 ---
echo "[6/8] Downloading latest build from S3..."
LATEST_BUILD=$(aws s3 ls s3://$S3_BUILDS_BUCKET/builds/ --recursive | sort | tail -1 | awk '{print $4}' || true)

if [ -n "$LATEST_BUILD" ]; then
  echo "Downloading build: $LATEST_BUILD"
  aws s3 cp "s3://$S3_BUILDS_BUCKET/$LATEST_BUILD" /opt/fel/builds/latest.tar.gz
  tar -xzf /opt/fel/builds/latest.tar.gz -C /opt/fel/current/
  echo "Build extracted successfully"
else
  echo "WARNING: No builds found in S3 bucket. Instance will wait for deployment."
fi

# --- Setup Signaling Server ---
echo "[7/8] Setting up signaling server..."
cat > /opt/fel/signaling/package.json << 'PKGEOF'
{
  "name": "fel-signaling-server",
  "version": "1.0.0",
  "main": "server.js",
  "dependencies": {
    "ws": "^8.16.0",
    "express": "^4.18.2",
    "uuid": "^9.0.0"
  }
}
PKGEOF

cd /opt/fel/signaling && npm install --production

# Copy signaling server code (will be in the build, fallback to bundled)
if [ ! -f /opt/fel/signaling/server.js ]; then
  cat > /opt/fel/signaling/server.js << 'SERVEREOF'
const express = require('express');
const { WebSocketServer } = require('ws');
const { v4: uuidv4 } = require('uuid');
const http = require('http');

const app = express();
const server = http.createServer(app);
const wss = new WebSocketServer({ server, path: '/ws' });

const PORT = process.env.SIGNALING_PORT || 8888;
const WS_PORT = process.env.WEBSOCKET_PORT || 8889;

let streamer = null;
const players = new Map();

app.get('/healthz', (req, res) => {
  res.json({
    status: 'ok',
    streamer: !!streamer,
    players: players.size,
    uptime: process.uptime()
  });
});

app.get('/api/modes', (req, res) => {
  res.json({
    modes: [
      'basketball_h2h', 'basketball_3v3', 'basketball_5v5',
      'karate_h2h', 'mma_h2h', 'boxing_h2h', 'soccer',
      'football', 'baseball', 'volleyball', 'tennis',
      'swimming', 'track_field', 'gymnastics',
      'skateboarding', 'surfing', 'training'
    ]
  });
});

wss.on('connection', (ws) => {
  const id = uuidv4();
  console.log(`[${new Date().toISOString()}] Client connected: $${id}`);

  ws.on('message', (data) => {
    try {
      const msg = JSON.parse(data);
      if (msg.type === 'streamer') {
        streamer = { ws, id };
        console.log(`Streamer registered: $${id}`);
      } else if (msg.type === 'player') {
        players.set(id, { ws });
        ws.send(JSON.stringify({ type: 'playerConnected', playerId: id }));
        if (streamer) {
          streamer.ws.send(JSON.stringify({ type: 'playerConnected', playerId: id }));
        }
      }
    } catch (e) {
      console.error('Message parse error:', e.message);
    }
  });

  ws.on('close', () => {
    if (streamer && streamer.id === id) {
      streamer = null;
      console.log('Streamer disconnected');
    }
    players.delete(id);
    console.log(`Client disconnected: $${id}`);
  });
});

server.listen(PORT, () => {
  console.log(`Signaling server running on port $${PORT}`);
});
SERVEREOF
fi

# --- Setup Systemd Services ---
echo "[8/8] Creating systemd services..."

# Signaling server service
cat > /etc/systemd/system/fel-signaling.service << 'SVCEOF'
[Unit]
Description=FEL Pixel Streaming Signaling Server
After=network.target
Wants=network-online.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/opt/fel/signaling
EnvironmentFile=/etc/fel-env
ExecStart=/usr/bin/node server.js
Restart=always
RestartSec=5
StandardOutput=append:/opt/fel/logs/signaling.log
StandardError=append:/opt/fel/logs/signaling.log

[Install]
WantedBy=multi-user.target
SVCEOF

# UE5 Pixel Streaming server service
cat > /etc/systemd/system/fel-ue5-server.service << 'SVCEOF'
[Unit]
Description=FEL UE5 Pixel Streaming Server
After=network.target fel-signaling.service
Wants=fel-signaling.service

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/opt/fel/current
EnvironmentFile=/etc/fel-env
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

# GPU memory management
OOMScoreAdjust=-500

[Install]
WantedBy=multi-user.target
SVCEOF

# Enable services
systemctl daemon-reload
systemctl enable fel-signaling
systemctl start fel-signaling

# Only start UE5 server if build exists
if [ -f /opt/fel/current/FinalEvolutionLab.sh ]; then
  chmod +x /opt/fel/current/FinalEvolutionLab.sh
  systemctl enable fel-ue5-server
  systemctl start fel-ue5-server
fi

# --- Setup Nginx Reverse Proxy ---
cat > /etc/nginx/sites-available/fel-streaming << 'NGINXEOF'
upstream signaling {
    server 127.0.0.1:8888;
}

server {
    listen 80 default_server;
    server_name _;

    # Health check endpoint
    location /healthz {
        proxy_pass http://signaling/healthz;
    }

    # API endpoints
    location /api/ {
        proxy_pass http://signaling;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    # WebSocket for signaling
    location /ws {
        proxy_pass http://127.0.0.1:8889;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_read_timeout 86400;
        proxy_send_timeout 86400;
    }

    # Frontend
    location / {
        proxy_pass http://signaling;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
NGINXEOF

rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/fel-streaming /etc/nginx/sites-enabled/
nginx -t && systemctl restart nginx

echo "========================================"
echo "FEL Instance Bootstrap Complete"
echo "Finished: $(date -u)"
echo "========================================"
