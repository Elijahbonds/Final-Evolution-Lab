#!/bin/bash
# =============================================================================
# Final Evolution Lab - SSL/TLS Certificate Setup (Let's Encrypt)
# =============================================================================
# Usage:
#   sudo ./setup-ssl.sh <domain>
#   sudo ./setup-ssl.sh stream.finalevolutiongroup.com
# =============================================================================
set -euo pipefail

DOMAIN="${1:-stream.finalevolutiongroup.com}"
EMAIL="${2:-deploy@finalevolutiongroup.com}"

echo "Setting up SSL for: $DOMAIN"
echo "Contact email: $EMAIL"

# Check certbot
if ! command -v certbot &>/dev/null; then
  echo "Installing certbot..."
  apt-get update -qq
  apt-get install -y -qq certbot python3-certbot-nginx
fi

# Obtain certificate
certbot --nginx \
  -d "$DOMAIN" \
  --email "$EMAIL" \
  --agree-tos \
  --no-eff-email \
  --redirect \
  --non-interactive

# Verify
if certbot certificates | grep -q "$DOMAIN"; then
  echo "SSL certificate installed successfully for $DOMAIN"
else
  echo "ERROR: Certificate installation may have failed"
  exit 1
fi

# Setup auto-renewal
if ! systemctl is-active certbot.timer &>/dev/null; then
  systemctl enable certbot.timer
  systemctl start certbot.timer
  echo "Auto-renewal timer enabled"
fi

# Add post-renewal hook to restart nginx
cat > /etc/letsencrypt/renewal-hooks/post/reload-nginx.sh << 'EOF'
#!/bin/bash
nginx -t && systemctl reload nginx
EOF
chmod +x /etc/letsencrypt/renewal-hooks/post/reload-nginx.sh

echo "SSL setup complete. Certificate will auto-renew."
