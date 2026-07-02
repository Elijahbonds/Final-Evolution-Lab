#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────
# DEPRECATED — Cloud streaming has been disabled. Use native local builds.
# ──────────────────────────────────────────────────────────────────
# deploy_e3ds.sh — One-command E3DS deploy via Pulumi
#
# Usage:
#   export E3DS_API_KEY="your-key"
#   export E3DS_ACCOUNT_ID="your-account-id"
#   export FEL_BUILD_URL="https://s3.amazonaws.com/your-bucket/FinalEvolutionLab-Shipping.zip"
#   ./deploy_e3ds.sh
#
# After deploy, the script refreshes ../backend/.env with stream URLs while
# preserving/writing E3DS_API_KEY so `/api/streaming/status` stays configured.
# ──────────────────────────────────────────────────────────────────
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INFRA_DIR="$SCRIPT_DIR/e3ds"
BACKEND_ENV="$SCRIPT_DIR/../backend/.env"

echo "╔══════════════════════════════════════════════════════╗"
echo "║  FINAL EVOLUTION LAB — Eagle 3D Streaming Deploy    ║"
echo "╚══════════════════════════════════════════════════════╝"

# Validate env
: "${E3DS_API_KEY:?Set E3DS_API_KEY}"
: "${E3DS_ACCOUNT_ID:?Set E3DS_ACCOUNT_ID}"
: "${FEL_BUILD_URL:?Set FEL_BUILD_URL to your packaged UE5 build zip URL}"

cd "$INFRA_DIR"

# Install deps
pip install -r requirements.txt -q

# Set Pulumi config
pulumi stack select dev 2>/dev/null || pulumi stack init dev
pulumi config set --secret e3dsApiKey "$E3DS_API_KEY"
pulumi config set e3dsAccountId "$E3DS_ACCOUNT_ID"
pulumi config set buildZipUrl "$FEL_BUILD_URL"
pulumi config set e3dsAppName "FinalEvolutionLab"
pulumi config set e3dsRegion "${E3DS_REGION:-us-east}"
pulumi config set gpuTier "${E3DS_GPU_TIER:-rtx4080}"
pulumi config set maxStreams "${E3DS_MAX_STREAMS:-4}"

echo ""
echo "▸ Deploying to Eagle 3D Streaming..."
pulumi up --yes --skip-preview

# Capture outputs
E3DS_STREAM_URL=$(pulumi stack output E3DS_STREAM_URL 2>/dev/null || echo "")
E3DS_IFRAME_URL=$(pulumi stack output E3DS_IFRAME_URL 2>/dev/null || echo "")
E3DS_APP_ID=$(pulumi stack output E3DS_APP_ID 2>/dev/null || echo "")

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  E3DS Deployment Complete"
echo "═══════════════════════════════════════════════════════"
echo "  App ID:      $E3DS_APP_ID"
echo "  Stream URL:  $E3DS_STREAM_URL"
echo "  Iframe URL:  $E3DS_IFRAME_URL"
echo "═══════════════════════════════════════════════════════"

# Write stream metadata to backend .env (preserve E3DS_API_KEY and other E3DS_* secrets)
touch "$BACKEND_ENV"
if [ -n "$E3DS_STREAM_URL" ] && [ "$E3DS_STREAM_URL" != "" ]; then
    tmp="$(mktemp)"
    grep -v '^E3DS_STREAM_URL=\|^E3DS_IFRAME_URL=\|^E3DS_APP_ID=' "$BACKEND_ENV" > "$tmp" || true
    mv "$tmp" "$BACKEND_ENV"

    echo "E3DS_STREAM_URL=$E3DS_STREAM_URL" >> "$BACKEND_ENV"
    echo "E3DS_IFRAME_URL=$E3DS_IFRAME_URL" >> "$BACKEND_ENV"
    echo "E3DS_APP_ID=$E3DS_APP_ID" >> "$BACKEND_ENV"

    # Persist API key reference for backend /api/streaming/status (optional second line if env already set)
    if [ -n "${E3DS_API_KEY:-}" ]; then
        tmp="$(mktemp)"
        grep -v '^E3DS_API_KEY=' "$BACKEND_ENV" > "$tmp" || true
        mv "$tmp" "$BACKEND_ENV"
        echo "E3DS_API_KEY=$E3DS_API_KEY" >> "$BACKEND_ENV"
    fi

    echo ""
    echo "▸ Backend .env updated with E3DS stream URLs (E3DS_API_KEY preserved or refreshed)"
    echo "▸ Restart backend so FastAPI picks up env: sudo supervisorctl restart backend"
else
    echo ""
    echo "⚠ No stream URL captured — check E3DS control panel"
fi
