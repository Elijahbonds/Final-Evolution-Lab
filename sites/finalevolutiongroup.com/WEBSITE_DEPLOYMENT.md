# Final Evolution Group — Website Deployment Guide

> **Stack:** React 18 · Vite 5 · Tailwind CSS 3 · TypeScript  
> **Build output:** `dist/` (static HTML + hashed JS/CSS assets)  
> **Environment variables:** None required — all content is static.

---

## Quick Start (Local Preview)

```bash
cd sites/finalevolutiongroup.com
npm install
npm run build      # → dist/
npm run preview    # → http://localhost:4173
```

---

## Option 1 — Vercel (Recommended)

Vercel auto-detects Vite projects. A `vercel.json` is included for SPA rewrites and caching headers.

### CLI Deploy

```bash
npm i -g vercel
cd sites/finalevolutiongroup.com
vercel            # follow prompts — framework: Vite, output: dist
vercel --prod     # promote to production
```

### Git Integration

1. Push the repo to GitHub / GitLab / Bitbucket.
2. Import the project in [vercel.com/new](https://vercel.com/new).
3. Set **Root Directory** to `sites/finalevolutiongroup.com`.
4. Framework Preset → **Vite**.
5. Deploy. Every push to `main` auto-deploys.

### Custom Domain

In **Vercel → Project → Settings → Domains**, add `finalevolutiongroup.com` and `www.finalevolutiongroup.com`. Vercel provides free SSL.

---

## Option 2 — Netlify

A `netlify.toml` is included with build command, publish directory, SPA redirects, and security headers.

### CLI Deploy

```bash
npm i -g netlify-cli
cd sites/finalevolutiongroup.com
netlify init      # link or create site
netlify deploy --build --prod
```

### Git Integration

1. Go to [app.netlify.com](https://app.netlify.com) → **Add new site → Import from Git**.
2. Set **Base directory** to `sites/finalevolutiongroup.com`.
3. Build command: `npm run build` · Publish directory: `dist`.
4. Deploy. Continuous deployment on push.

### Custom Domain

In **Site settings → Domain management**, add `finalevolutiongroup.com`. Netlify provides free SSL via Let's Encrypt.

---

## Option 3 — AWS S3 + CloudFront

Best for maximum control and scalability.

### 1. Create S3 Bucket

```bash
aws s3 mb s3://finalevolutiongroup-com --region us-east-1

# Enable static website hosting
aws s3 website s3://finalevolutiongroup-com \
  --index-document index.html \
  --error-document index.html
```

### 2. Build & Upload

```bash
cd sites/finalevolutiongroup.com
npm run build

# Sync dist to S3 with proper cache headers
aws s3 sync dist/ s3://finalevolutiongroup-com/ \
  --delete \
  --cache-control "public, max-age=0, must-revalidate"

# Override cache for hashed assets (immutable)
aws s3 sync dist/assets/ s3://finalevolutiongroup-com/assets/ \
  --cache-control "public, max-age=31536000, immutable"
```

### 3. Create CloudFront Distribution

```bash
aws cloudfront create-distribution \
  --origin-domain-name finalevolutiongroup-com.s3-website-us-east-1.amazonaws.com \
  --default-root-object index.html
```

**Key CloudFront settings:**
- **Custom Error Response:** 403 & 404 → `/index.html` with 200 status (SPA routing).
- **SSL:** Request a free certificate via ACM for `finalevolutiongroup.com`.
- **Compress Objects:** Enable Gzip + Brotli.

### 4. DNS

Point `finalevolutiongroup.com` to the CloudFront distribution via Route 53 or your DNS provider (CNAME / ALIAS record).

---

## Option 4 — Docker / Nginx (Self-Hosted)

```dockerfile
# Dockerfile
FROM node:20-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM nginx:alpine
COPY --from=build /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
```

```nginx
# nginx.conf
server {
    listen 80;
    server_name finalevolutiongroup.com;
    root /usr/share/nginx/html;
    index index.html;

    # SPA fallback
    location / {
        try_files $uri $uri/ /index.html;
    }

    # Cache hashed assets
    location /assets/ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Security headers
    add_header X-Content-Type-Options nosniff;
    add_header X-Frame-Options DENY;
    add_header X-XSS-Protection "1; mode=block";

    # Gzip
    gzip on;
    gzip_types text/css application/javascript application/json image/svg+xml;
}
```

```bash
docker build -t fel-website .
docker run -d -p 80:80 fel-website
```

---

## Build Verification Checklist

| Check | Command / Action |
|-------|-----------------|
| Dependencies install | `npm install` — no errors |
| TypeScript compiles | `npx tsc --noEmit` |
| Production build | `npm run build` — exits 0, `dist/` created |
| Preview works | `npm run preview` → open http://localhost:4173 |
| All sections render | Hero, GameModes, BodyScan, ShardEconomy, FamilySharing, Pricing, Footer |
| Favicon loads | `/favicon.svg` present in `dist/` |
| No console errors | Open DevTools → Console in preview |

---

## Project Structure

```
sites/finalevolutiongroup.com/
├── dist/                 # Production build output
├── public/
│   └── favicon.svg
├── src/
│   ├── components/
│   │   ├── Hero.tsx
│   │   ├── Nav.tsx
│   │   ├── GameModes.tsx
│   │   ├── BodyScanSection.tsx
│   │   ├── ShardEconomySection.tsx
│   │   ├── FamilySharingSection.tsx
│   │   ├── PricingSection.tsx
│   │   ├── VideoShowcase.tsx
│   │   ├── StreamingSection.tsx
│   │   ├── AcademySection.tsx
│   │   ├── ShopSection.tsx
│   │   ├── DownloadSection.tsx
│   │   ├── InstallSection.tsx
│   │   ├── PRQSection.tsx
│   │   └── Footer.tsx
│   ├── App.tsx
│   ├── main.tsx
│   └── index.css
├── index.html
├── package.json
├── tailwind.config.js
├── postcss.config.js
├── tsconfig.json
├── vite.config.ts
├── vercel.json           # Vercel deployment config
├── netlify.toml          # Netlify deployment config
├── .env.example          # Env var template (none required currently)
└── WEBSITE_DEPLOYMENT.md # This file
```

---

## Subscription Tiers (Displayed on Site)

| Tier | Price | Description |
|------|-------|-------------|
| Individual | $6/week | Single user access |
| Family2 | $10/week | 2 family members |
| Family5+ | $19.99/week | 5+ family members |

---

## Notes

- **No SSR / API routes** — this is a fully static SPA.
- **No environment variables** are consumed at build or runtime.
- **Tailwind purges unused CSS** automatically via the `content` config.
- Hashed asset filenames (`index-[hash].js`) enable aggressive CDN caching.
- The SPA redirect rule (`/* → /index.html`) is critical for any future client-side routing.
