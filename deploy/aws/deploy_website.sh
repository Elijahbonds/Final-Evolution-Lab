#!/usr/bin/env bash
###############################################################################
# FEL Marketing Website Deployment
# Deploys finalevolutiongroup_website to production
#
# Usage:
#   ./deploy_website.sh [--self-host|--vercel|--netlify]
###############################################################################
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
WEBSITE_DIR="/home/ubuntu/finalevolutiongroup_website"
DEPLOY_MODE="${1:---self-host}"
DOMAIN="finalevolutiongroup.com"

log() { echo "[$(date '+%H:%M:%S')] $*"; }

# ── Check website exists ────────────────────────────────────────
if [ ! -d "$WEBSITE_DIR" ]; then
  # Try project-local path
  if [ -d "$ROOT/sites/final-evolution-main-site" ]; then
    WEBSITE_DIR="$ROOT/sites/final-evolution-main-site"
  else
    echo "❌ Website directory not found at $WEBSITE_DIR"
    echo "  Expected: /home/ubuntu/finalevolutiongroup_website"
    echo "  Or:       $ROOT/sites/final-evolution-main-site"
    exit 1
  fi
fi

log "Website source: $WEBSITE_DIR"
cd "$WEBSITE_DIR"

# ── Install dependencies ────────────────────────────────────────
log "Installing dependencies..."
npm install

# ── Build production bundle ─────────────────────────────────────
log "Building production bundle..."
npm run build || npx next build

BUILD_DIR="$WEBSITE_DIR/.next"
STATIC_DIR="$WEBSITE_DIR/out"

# Try static export if Next.js
if [ -d "$BUILD_DIR" ] && ! [ -d "$STATIC_DIR" ]; then
  npm run export 2>/dev/null || npx next export 2>/dev/null || true
fi

case "$DEPLOY_MODE" in
  # ═══════════════════════════════════════════════════════════════
  --self-host)
    log "Deploying via self-hosted Nginx..."

    # If Next.js, run with PM2
    if [ -f "$WEBSITE_DIR/next.config.ts" ] || [ -f "$WEBSITE_DIR/next.config.js" ]; then
      log "Detected Next.js — deploying with PM2..."

      # Install PM2
      sudo npm install -g pm2 2>/dev/null || true

      # Start/restart
      cd "$WEBSITE_DIR"
      pm2 delete fel-website 2>/dev/null || true
      PORT=3001 pm2 start npm --name "fel-website" -- start
      pm2 save

      # Nginx reverse proxy
      sudo tee /etc/nginx/sites-available/finalevolutiongroup << 'NGINX'
server {
    listen 80;
    server_name finalevolutiongroup.com www.finalevolutiongroup.com;

    location / {
        proxy_pass http://127.0.0.1:3001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}
NGINX

    else
      # Static site
      SERVE_DIR="${STATIC_DIR:-$WEBSITE_DIR/dist}"
      if [ ! -d "$SERVE_DIR" ]; then
        SERVE_DIR="$WEBSITE_DIR/out"
      fi
      if [ ! -d "$SERVE_DIR" ]; then
        SERVE_DIR="$WEBSITE_DIR/build"
      fi

      sudo tee /etc/nginx/sites-available/finalevolutiongroup << NGINX
server {
    listen 80;
    server_name finalevolutiongroup.com www.finalevolutiongroup.com;

    root $SERVE_DIR;
    index index.html;

    location / {
        try_files \$uri \$uri/ /index.html;
    }

    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml;
}
NGINX
    fi

    # Enable site
    sudo ln -sf /etc/nginx/sites-available/finalevolutiongroup /etc/nginx/sites-enabled/
    sudo rm -f /etc/nginx/sites-enabled/default 2>/dev/null || true
    sudo nginx -t && sudo systemctl reload nginx

    # SSL with Let's Encrypt
    log "Setting up SSL..."
    sudo certbot --nginx -d "$DOMAIN" -d "www.$DOMAIN" \
      --non-interactive --agree-tos --email "admin@$DOMAIN" \
      2>/dev/null || {
      log "⚠️  Certbot failed (DNS may not be configured yet)"
      log "  Run later: sudo certbot --nginx -d $DOMAIN -d www.$DOMAIN"
    }

    log "✅ Website deployed at http://$DOMAIN (self-hosted)"
    ;;

  # ═══════════════════════════════════════════════════════════════
  --vercel)
    log "Deploying to Vercel..."
    if ! command -v vercel &>/dev/null; then
      sudo npm install -g vercel
    fi

    cd "$WEBSITE_DIR"
    vercel --prod --yes 2>&1 || {
      log "⚠️  Vercel deploy requires authentication."
      log "  Run: vercel login && vercel --prod"
      log "  Then configure DNS: CNAME www -> cname.vercel-dns.com"
    }
    ;;

  # ═══════════════════════════════════════════════════════════════
  --netlify)
    log "Deploying to Netlify..."
    if ! command -v netlify &>/dev/null; then
      sudo npm install -g netlify-cli
    fi

    cd "$WEBSITE_DIR"
    netlify deploy --prod --dir="${STATIC_DIR:-out}" 2>&1 || {
      log "⚠️  Netlify deploy requires authentication."
      log "  Run: netlify login && netlify deploy --prod"
    }
    ;;

  *)
    echo "Usage: $0 [--self-host|--vercel|--netlify]"
    exit 1
    ;;
esac

# ── Verification ────────────────────────────────────────────────
log "Running deployment verification..."
sleep 3

VERIFY_URLS=(
  "http://localhost:3001"
  "http://localhost:80"
)

for url in "${VERIFY_URLS[@]}"; do
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")
  if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "301" ] || [ "$HTTP_CODE" = "302" ]; then
    log "✅ $url → HTTP $HTTP_CODE"
  else
    log "⚠️  $url → HTTP $HTTP_CODE"
  fi
done

log "Website deployment complete!"
