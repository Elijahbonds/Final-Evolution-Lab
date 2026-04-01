#!/usr/bin/env bash
# FEL Pixel Streaming — Deployment Script
# Usage: ./deploy.sh [local|cloud]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_MODE="${1:-local}"

echo "=== Final Evolution Lab — Pixel Streaming Deploy ==="
echo "Mode: ${DEPLOY_MODE}"
echo "Directory: ${SCRIPT_DIR}"

# Ensure Docker is available
if ! command -v docker &>/dev/null; then
  echo "ERROR: Docker is required. Install from https://docs.docker.com/get-docker/"
  exit 1
fi

if ! command -v docker-compose &>/dev/null && ! docker compose version &>/dev/null 2>&1; then
  echo "ERROR: Docker Compose is required."
  exit 1
fi

cd "${SCRIPT_DIR}"

case "${DEPLOY_MODE}" in
  local)
    echo ""
    echo "Starting local Pixel Streaming stack..."
    echo "  - Signalling Server: ws://localhost:8888"
    echo "  - Frontend: http://localhost:3000"
    echo "  - TURN: localhost:3478"
    echo ""

    docker compose up --build -d

    echo ""
    echo "✅ Stack is running!"
    echo "  Frontend:    http://localhost:3000"
    echo "  Health:      http://localhost:8888/healthz"
    echo "  Modes API:   http://localhost:8888/api/modes"
    echo ""
    echo "To view logs: docker compose logs -f"
    echo "To stop:      docker compose down"
    ;;

  cloud)
    echo ""
    echo "Cloud deployment checklist:"
    echo "  1. Build UE5 Linux Shipping server with Pixel Streaming"
    echo "  2. Copy packaged build to streaming/docker/build/"
    echo "  3. Configure streaming/config/streaming_config.json with public IPs"
    echo "  4. Set up SSL certificates for HTTPS/WSS"
    echo "  5. Deploy to GPU cloud (AWS g4dn, GCP T4, Azure NCv3)"
    echo ""
    echo "For AWS:"
    echo "  aws ecr create-repository --repository-name fel-streaming"
    echo "  docker compose build"
    echo "  docker tag fel-streaming:latest <account>.dkr.ecr.<region>.amazonaws.com/fel-streaming:latest"
    echo "  docker push <account>.dkr.ecr.<region>.amazonaws.com/fel-streaming:latest"
    echo ""
    echo "For GCP:"
    echo "  gcloud builds submit --tag gcr.io/<project>/fel-streaming ."
    echo "  gcloud run deploy fel-streaming --image gcr.io/<project>/fel-streaming --gpu 1"
    ;;

  *)
    echo "Usage: $0 [local|cloud]"
    exit 1
    ;;
esac
