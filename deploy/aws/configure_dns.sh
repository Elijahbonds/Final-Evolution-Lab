#!/usr/bin/env bash
###############################################################################
# FEL Production Endpoints & DNS Configuration
# Configures Nginx reverse proxy, SSL, and generates DNS guide
###############################################################################
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
DOMAIN="finalevolutiongroup.com"

# Get public IP
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || \
            curl -s https://ifconfig.me 2>/dev/null || \
            echo "YOUR_SERVER_IP")

log() { echo "[$(date '+%H:%M:%S')] $*"; }

log "Configuring production endpoints for $DOMAIN ($PUBLIC_IP)"

###############################################################################
# Nginx Configuration — All Subdomains
###############################################################################

# Main website
sudo tee /etc/nginx/sites-available/fel-main << NGINX
# finalevolutiongroup.com — Marketing Website
server {
    listen 80;
    server_name finalevolutiongroup.com www.finalevolutiongroup.com;

    location / {
        proxy_pass http://127.0.0.1:3001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
NGINX

# Pixel Streaming
sudo tee /etc/nginx/sites-available/fel-stream << NGINX
# stream.finalevolutiongroup.com — Pixel Streaming Signalling
server {
    listen 80;
    server_name stream.finalevolutiongroup.com;

    # WebSocket upgrade for Pixel Streaming
    location / {
        proxy_pass http://127.0.0.1:8888;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_read_timeout 86400;
    }
}
NGINX

# Web App (streaming frontend)
sudo tee /etc/nginx/sites-available/fel-app << NGINX
# app.finalevolutiongroup.com — Web App (Game Frontend)
server {
    listen 80;
    server_name app.finalevolutiongroup.com;

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
NGINX

# API
sudo tee /etc/nginx/sites-available/fel-api << NGINX
# api.finalevolutiongroup.com — REST API
server {
    listen 80;
    server_name api.finalevolutiongroup.com;

    location / {
        proxy_pass http://127.0.0.1:8888;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        # CORS
        add_header Access-Control-Allow-Origin *;
        add_header Access-Control-Allow-Methods 'GET, POST, OPTIONS';
        add_header Access-Control-Allow-Headers 'DNT,X-CustomHeader,Keep-Alive,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Authorization';
    }
}
NGINX

# Enable all sites
for site in fel-main fel-stream fel-app fel-api; do
  sudo ln -sf "/etc/nginx/sites-available/$site" /etc/nginx/sites-enabled/
done
sudo rm -f /etc/nginx/sites-enabled/default 2>/dev/null || true

# Test and reload
sudo nginx -t && sudo systemctl reload nginx
log "✅ Nginx configured for all subdomains"

###############################################################################
# SSL Certificates
###############################################################################
log "Setting up SSL certificates..."

DOMAINS="-d $DOMAIN -d www.$DOMAIN -d stream.$DOMAIN -d app.$DOMAIN -d api.$DOMAIN"
sudo certbot --nginx $DOMAINS \
  --non-interactive --agree-tos --email "admin@$DOMAIN" \
  2>/dev/null || {
  log "⚠️  Certbot failed — DNS must point to this server first."
  log "  After DNS propagation, run:"
  log "  sudo certbot --nginx $DOMAINS"
}

###############################################################################
# Health Check Endpoints
###############################################################################
log "Setting up health checks..."

sudo tee /etc/nginx/sites-available/fel-health << 'NGINX'
server {
    listen 9090;
    server_name _;

    location /health {
        return 200 '{"status":"healthy","service":"fel-nginx","timestamp":"$time_iso8601"}';
        add_header Content-Type application/json;
    }

    location /health/stream {
        proxy_pass http://127.0.0.1:8888/healthz;
        proxy_connect_timeout 5s;
        proxy_read_timeout 5s;
    }

    location /health/app {
        proxy_pass http://127.0.0.1:3000;
        proxy_connect_timeout 5s;
        proxy_read_timeout 5s;
    }

    location /health/website {
        proxy_pass http://127.0.0.1:3001;
        proxy_connect_timeout 5s;
        proxy_read_timeout 5s;
    }
}
NGINX
sudo ln -sf /etc/nginx/sites-available/fel-health /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx

###############################################################################
# DNS Configuration Guide
###############################################################################

DNS_GUIDE="${ROOT}/deploy/aws/DNS_CONFIGURATION.md"
cat > "$DNS_GUIDE" << MD
# Final Evolution Lab — DNS Configuration Guide

## Server IP: \`$PUBLIC_IP\`

## Required DNS Records

Add these records at your domain registrar (GoDaddy, Namecheap, Cloudflare, etc.):

| Type  | Name    | Value           | TTL  | Purpose                    |
|-------|---------|-----------------|------|----------------------------|
| A     | @       | $PUBLIC_IP      | 300  | Main website               |
| A     | www     | $PUBLIC_IP      | 300  | www redirect               |
| A     | stream  | $PUBLIC_IP      | 300  | Pixel Streaming signalling |
| A     | app     | $PUBLIC_IP      | 300  | Web app / game frontend    |
| A     | api     | $PUBLIC_IP      | 300  | REST API endpoints         |

## Production Endpoints

Once DNS is configured:

| Service             | URL                                          | Port  |
|---------------------|----------------------------------------------|-------|
| Marketing Website   | https://finalevolutiongroup.com              | 443   |
| Pixel Streaming     | wss://stream.finalevolutiongroup.com         | 443   |
| Web App             | https://app.finalevolutiongroup.com          | 443   |
| REST API            | https://api.finalevolutiongroup.com          | 443   |
| Health Check        | http://$PUBLIC_IP:9090/health                | 9090  |
| TURN Server         | turn:$PUBLIC_IP:3478                         | 3478  |

## Direct IP Access (before DNS)

| Service             | URL                                          |
|---------------------|----------------------------------------------|
| Marketing Website   | http://$PUBLIC_IP:3001                       |
| Pixel Streaming     | ws://$PUBLIC_IP:8888                         |
| Web App             | http://$PUBLIC_IP:3000                       |
| REST API            | http://$PUBLIC_IP:8888/api/modes             |
| Health Check        | http://$PUBLIC_IP:9090/health                |

## SSL Setup

After DNS propagation (check with \`dig $DOMAIN\`):

\`\`\`bash
sudo certbot --nginx \\
  -d $DOMAIN \\
  -d www.$DOMAIN \\
  -d stream.$DOMAIN \\
  -d app.$DOMAIN \\
  -d api.$DOMAIN
\`\`\`

## Verify DNS

\`\`\`bash
dig $DOMAIN +short              # Should return $PUBLIC_IP
dig stream.$DOMAIN +short      # Should return $PUBLIC_IP
curl -I https://$DOMAIN        # Should return 200
\`\`\`

## Cloudflare (Recommended)

If using Cloudflare:
1. Add A records as above
2. Set SSL mode to "Full (strict)" after certbot
3. Enable "Always Use HTTPS"
4. Create Page Rule for \`stream.$DOMAIN\` → SSL: Off (for WebSocket)
   OR configure WebSocket support in Cloudflare dashboard

## iOS App Configuration

Update \`ios/FinalEvolutionLab/Config.swift\`:
\`\`\`swift
static let STREAMING_SERVER_URL = "wss://stream.$DOMAIN"
static let STREAMING_API_URL = "https://api.$DOMAIN"
static let WEBSITE_URL = "https://$DOMAIN"
static let WEB_APP_URL = "https://app.$DOMAIN"
\`\`\`
MD

log "✅ DNS guide saved: $DNS_GUIDE"
log ""
log "═══ Endpoint Summary ═══"
log "  Website:     http://$PUBLIC_IP:3001  →  https://$DOMAIN"
log "  Streaming:   ws://$PUBLIC_IP:8888    →  wss://stream.$DOMAIN"
log "  Web App:     http://$PUBLIC_IP:3000  →  https://app.$DOMAIN"
log "  API:         http://$PUBLIC_IP:8888  →  https://api.$DOMAIN"
log "  Health:      http://$PUBLIC_IP:9090/health"
