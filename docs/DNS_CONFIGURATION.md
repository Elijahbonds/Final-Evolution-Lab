# DNS Configuration Guide for Finalevolutiongroup.com

## Overview

This document provides complete DNS configuration instructions for deploying Final Evolution Lab services under the `finalevolutiongroup.com` domain.

---

## 1. Required DNS Records

### Core Records

| Type  | Name                    | Value                          | TTL   | Purpose                        |
|-------|-------------------------|--------------------------------|-------|--------------------------------|
| A     | `@`                     | `<WEB_SERVER_IP>`              | 300   | Root domain → marketing site   |
| CNAME | `www`                   | `finalevolutiongroup.com`      | 300   | www redirect → root domain     |
| CNAME | `stream`                | `<STREAMING_SERVER_HOSTNAME>`  | 300   | Pixel Streaming signalling     |
| CNAME | `app`                   | `<WEB_APP_HOSTNAME>`           | 300   | Web app (game client)          |
| A     | `turn`                  | `<TURN_SERVER_IP>`             | 300   | TURN/STUN relay server         |
| CNAME | `api`                   | `<API_SERVER_HOSTNAME>`        | 300   | REST API endpoints             |

### Email Records (Optional)

| Type  | Name  | Value                                       | TTL   | Purpose         |
|-------|-------|---------------------------------------------|-------|-----------------|
| MX    | `@`   | `10 mail.finalevolutiongroup.com`           | 3600  | Email routing   |
| TXT   | `@`   | `v=spf1 include:_spf.google.com ~all`      | 3600  | SPF record      |
| TXT   | `_dmarc` | `v=DMARC1; p=quarantine; rua=mailto:...` | 3600  | DMARC policy    |

---

## 2. SSL/TLS Certificate Setup

### Option A: Let's Encrypt (Free, Recommended)

```bash
# Install certbot
sudo apt update && sudo apt install -y certbot python3-certbot-nginx

# Obtain certificates for all subdomains
sudo certbot certonly --nginx \
  -d finalevolutiongroup.com \
  -d www.finalevolutiongroup.com \
  -d stream.finalevolutiongroup.com \
  -d app.finalevolutiongroup.com \
  -d api.finalevolutiongroup.com \
  -d turn.finalevolutiongroup.com

# Auto-renewal (add to crontab)
0 0 1 * * certbot renew --quiet
```

### Option B: Cloudflare Origin Certificates

If using Cloudflare as your DNS provider:

1. Go to **SSL/TLS → Origin Server** in Cloudflare dashboard
2. Click **Create Certificate**
3. Select hostnames: `*.finalevolutiongroup.com`, `finalevolutiongroup.com`
4. Choose validity period (15 years recommended)
5. Download the certificate and private key
6. Install on your origin server:

```bash
sudo mkdir -p /etc/ssl/finalevolutiongroup
sudo cp origin-cert.pem /etc/ssl/finalevolutiongroup/cert.pem
sudo cp origin-key.pem /etc/ssl/finalevolutiongroup/key.pem
sudo chmod 600 /etc/ssl/finalevolutiongroup/key.pem
```

### Option C: Wildcard Certificate with Let's Encrypt

```bash
sudo certbot certonly --manual --preferred-challenges dns \
  -d '*.finalevolutiongroup.com' \
  -d finalevolutiongroup.com
```

---

## 3. Cloudflare Configuration

### Initial Setup

1. **Add Site**: Go to [dash.cloudflare.com](https://dash.cloudflare.com) → Add Site → Enter `finalevolutiongroup.com`
2. **Select Plan**: Free plan is sufficient for initial deployment
3. **Update Nameservers**: At your domain registrar, change nameservers to:
   - `ns1.cloudflare.com` (actual values provided by Cloudflare)
   - `ns2.cloudflare.com`

### DNS Records in Cloudflare

```
# Proxied (orange cloud) — gets Cloudflare CDN + DDoS protection
A     @       <WEB_SERVER_IP>              Proxied
CNAME www     finalevolutiongroup.com      Proxied
CNAME app     <WEB_APP_HOSTNAME>           Proxied
CNAME api     <API_SERVER_HOSTNAME>        Proxied

# DNS-only (gray cloud) — for WebSocket/streaming (must NOT be proxied)
CNAME stream  <STREAMING_SERVER_HOSTNAME>  DNS Only
A     turn    <TURN_SERVER_IP>             DNS Only
```

> **IMPORTANT**: `stream` and `turn` subdomains must be DNS-only (gray cloud).
> Cloudflare proxying interferes with WebSocket connections and TURN relay.

### SSL/TLS Settings

1. **SSL Mode**: Full (Strict)
2. **Minimum TLS Version**: TLS 1.2
3. **Always Use HTTPS**: ON
4. **Automatic HTTPS Rewrites**: ON
5. **HSTS**: Enable with max-age 6 months

### Security Settings

1. **WAF**: Enable managed rules
2. **Bot Fight Mode**: ON
3. **Under Attack Mode**: OFF (enable if under DDoS)
4. **Rate Limiting**: Create rule for `/api/*` (100 req/min per IP)

### Page Rules

```
# Force HTTPS
http://*finalevolutiongroup.com/*  →  Always Use HTTPS

# Cache marketing site
finalevolutiongroup.com/*  →  Cache Level: Standard, Edge TTL: 4 hours

# No cache for streaming
stream.finalevolutiongroup.com/*  →  Cache Level: Bypass
```

---

## 4. Nginx Configuration

### Marketing Website (finalevolutiongroup.com)

```nginx
server {
    listen 443 ssl http2;
    server_name finalevolutiongroup.com www.finalevolutiongroup.com;

    ssl_certificate     /etc/ssl/finalevolutiongroup/cert.pem;
    ssl_certificate_key /etc/ssl/finalevolutiongroup/key.pem;

    # NextJS static export or proxy to Next server
    root /var/www/finalevolutiongroup/out;
    index index.html;

    location / {
        try_files $uri $uri.html $uri/index.html =404;
    }

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline' fonts.googleapis.com; font-src fonts.gstatic.com;" always;

    # Gzip
    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml;
}

server {
    listen 80;
    server_name finalevolutiongroup.com www.finalevolutiongroup.com;
    return 301 https://$host$request_uri;
}
```

### Streaming Signalling Server (stream.finalevolutiongroup.com)

```nginx
server {
    listen 443 ssl http2;
    server_name stream.finalevolutiongroup.com;

    ssl_certificate     /etc/ssl/finalevolutiongroup/cert.pem;
    ssl_certificate_key /etc/ssl/finalevolutiongroup/key.pem;

    location / {
        proxy_pass http://127.0.0.1:8888;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_read_timeout 86400;
    }
}
```

### Web App (app.finalevolutiongroup.com)

```nginx
server {
    listen 443 ssl http2;
    server_name app.finalevolutiongroup.com;

    ssl_certificate     /etc/ssl/finalevolutiongroup/cert.pem;
    ssl_certificate_key /etc/ssl/finalevolutiongroup/key.pem;

    root /var/www/fel-webapp/dist;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }
}
```

---

## 5. Service Configuration Updates

After DNS is configured, update these files:

### iOS App Config
```swift
// ios/FinalEvolutionLab/Config.swift
static let STREAMING_SERVER_URL = "wss://stream.finalevolutiongroup.com"
static let STREAMING_API_URL = "https://stream.finalevolutiongroup.com"
static let TURN_SERVER_URL = "turn:turn.finalevolutiongroup.com:3478"
static let STUN_SERVER_URL = "stun:turn.finalevolutiongroup.com:3478"
static let WEBSITE_URL = "https://finalevolutiongroup.com"
static let WEB_APP_URL = "https://app.finalevolutiongroup.com"
```

### UE5 Pixel Streaming Config
```ini
# FEL_PixelStreaming_iOS.ini
SignallingServerURL=wss://stream.finalevolutiongroup.com
```

### Docker Compose Environment
```yaml
environment:
  - SIGNALLING_URL=wss://stream.finalevolutiongroup.com
  - TURN_SERVER=turn:turn.finalevolutiongroup.com:3478
  - PUBLIC_IP=<SERVER_PUBLIC_IP>
```

---

## 6. Verification Checklist

```bash
# Verify DNS propagation
dig finalevolutiongroup.com +short
dig www.finalevolutiongroup.com +short
dig stream.finalevolutiongroup.com +short
dig turn.finalevolutiongroup.com +short
dig app.finalevolutiongroup.com +short

# Verify SSL certificates
openssl s_client -connect finalevolutiongroup.com:443 -servername finalevolutiongroup.com </dev/null 2>/dev/null | openssl x509 -noout -dates

# Verify website
curl -sI https://finalevolutiongroup.com | head -5

# Verify streaming WebSocket
wscat -c wss://stream.finalevolutiongroup.com

# Verify TURN server
turnutils_uclient -T turn.finalevolutiongroup.com
```

---

## 7. Troubleshooting

| Issue | Solution |
|-------|----------|
| DNS not resolving | Wait 24-48h for propagation; check with `dig @8.8.8.8` |
| SSL error | Verify cert covers subdomain; check Cloudflare SSL mode |
| WebSocket 502 | Ensure stream subdomain is DNS-only (not proxied) |
| TURN connection failed | Open UDP ports 3478, 49152-65535 on firewall |
| www not redirecting | Add CNAME for www pointing to root domain |
