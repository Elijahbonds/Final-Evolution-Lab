#!/usr/bin/env bash
###############################################################################
# cook_fel_linux_server.sh — Cook/Package FEL for Linux Dedicated Server
# with Pixel Streaming enabled for cloud deployment.
#
# Usage:
#   source ../../.ue5_env
#   ./cook_fel_linux_server.sh [--config Development|Shipping]
###############################################################################
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
[[ -f "${ROOT}/.ue5_env" ]] && source "${ROOT}/.ue5_env"

CONFIG="${1:-Development}"
case "$CONFIG" in
  --config) CONFIG="${2:-Development}"; shift 2 2>/dev/null || true;;
esac

PROJECT="${FEL_PROJECT:-${ROOT}/UnrealStarter/BasketballGame/FinalEvolutionLab.uproject}"
RUN_UAT="${RUN_UAT:-${UE_ROOT:-/opt/UnrealEngine}/Engine/Build/BatchFiles/RunUAT.sh}"
UE_EDITOR_CMD="${UE_CMD:-${UE_ROOT:-/opt/UnrealEngine}/Engine/Binaries/Linux/UnrealEditor-Cmd}"
ARCHIVE_DIR="${ROOT}/Builds/LinuxServer"
LOG_FILE="${ROOT}/logs/cook_linux_$(date +%Y%m%d_%H%M%S).log"

mkdir -p "$(dirname "$LOG_FILE")" "${ARCHIVE_DIR}"

log() { echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG_FILE"; }
err() { log "ERROR: $*"; exit 1; }

[[ -f "${PROJECT}" ]] || err "Project not found: ${PROJECT}"
[[ -f "${RUN_UAT}" ]] || err "RunUAT not found: ${RUN_UAT}"

log "═══════════════════════════════════════════════════════════════"
log " Cooking FEL for Linux Dedicated Server"
log " Config: ${CONFIG}"
log " Project: ${PROJECT}"
log "═══════════════════════════════════════════════════════════════"

# ── Step 1: Ensure Pixel Streaming plugin is enabled ─────────────────────────
log "Step 1: Verifying Pixel Streaming plugin..."
if grep -q '"PixelStreaming"' "$PROJECT"; then
  log "  Pixel Streaming plugin found in .uproject ✓"
else
  log "  Adding Pixel Streaming plugin to .uproject..."
  python3 -c "
import json
with open('${PROJECT}', 'r') as f:
    proj = json.load(f)
plugins = proj.setdefault('Plugins', [])
if not any(p.get('Name') == 'PixelStreaming' for p in plugins):
    plugins.append({'Name': 'PixelStreaming', 'Enabled': True})
with open('${PROJECT}', 'w') as f:
    json.dump(proj, f, indent='\t')
"
  log "  Added Pixel Streaming plugin ✓"
fi

# ── Step 2: Cook for Linux Server ────────────────────────────────────────────
log "Step 2: Building & Cooking for Linux Server..."

"${RUN_UAT}" BuildCookRun \
  -project="${PROJECT}" \
  -noP4 \
  -platform=Linux \
  -targetplatform=Linux \
  -target=FinalEvolutionLabServer \
  -serverconfig="${CONFIG}" \
  -server \
  -noclient \
  -cook \
  -allmaps \
  -build \
  -stage \
  -pak \
  -archive \
  -archivedirectory="${ARCHIVE_DIR}" \
  -installed \
  -unrealexe="${UE_EDITOR_CMD}" \
  -utf8output \
  -compressed \
  2>&1 | tee -a "$LOG_FILE"

log "  Build completed ✓"

# ── Step 3: Create launch script ─────────────────────────────────────────────
log "Step 3: Creating server launch script..."

LAUNCH_SCRIPT="${ARCHIVE_DIR}/launch_pixel_streaming.sh"
cat > "${LAUNCH_SCRIPT}" <<'LAUNCH_EOF'
#!/usr/bin/env bash
###############################################################################
# launch_pixel_streaming.sh — Launch FEL with Pixel Streaming
#
# Environment variables:
#   SIGNAL_URL   — Signalling server WebSocket URL (default: ws://localhost:8888)
#   RES_X        — Render resolution width (default: 1920)
#   RES_Y        — Render resolution height (default: 1080)
#   FPS          — Target frame rate (default: 60)
#   EXTRA_ARGS   — Additional UE command line args
###############################################################################
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BINARY="${SCRIPT_DIR}/LinuxServer/FinalEvolutionLabServer"

SIGNAL_URL="${SIGNAL_URL:-ws://localhost:8888}"
RES_X="${RES_X:-1920}"
RES_Y="${RES_Y:-1080}"
FPS="${FPS:-60}"

if [[ ! -f "${BINARY}" ]]; then
  echo "ERROR: Server binary not found: ${BINARY}"
  echo "  Check the archive directory structure."
  exit 1
fi

chmod +x "${BINARY}"

echo "Starting FEL Pixel Streaming Server..."
echo "  Signal URL: ${SIGNAL_URL}"
echo "  Resolution: ${RES_X}x${RES_Y} @ ${FPS}fps"

exec "${BINARY}" \
  -AudioMixer \
  -PixelStreamingIP=0.0.0.0 \
  -PixelStreamingPort=8888 \
  -PixelStreamingURL="${SIGNAL_URL}" \
  -RenderOffscreen \
  -Windowed \
  -ResX=${RES_X} \
  -ResY=${RES_Y} \
  -ForceRes \
  -FPS=${FPS} \
  -FullStdOutLogOutput \
  -nosplash \
  -unattended \
  -nosound \
  ${EXTRA_ARGS:-} \
  "$@"
LAUNCH_EOF
chmod +x "${LAUNCH_SCRIPT}"

# ── Step 4: Create Docker config ─────────────────────────────────────────────
log "Step 4: Creating Docker deployment config..."

cat > "${ARCHIVE_DIR}/Dockerfile" <<'DOCKER_EOF'
FROM nvidia/cuda:12.2.0-runtime-ubuntu22.04

RUN apt-get update && apt-get install -y \
    libvulkan1 libx11-6 libxext6 libxrandr2 \
    libasound2 libpulse0 libgl1-mesa-glx \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/fel

COPY . /opt/fel/

RUN chmod +x /opt/fel/launch_pixel_streaming.sh \
    && chmod +x /opt/fel/LinuxServer/FinalEvolutionLabServer 2>/dev/null || true

ENV SIGNAL_URL=ws://signalling:8888
ENV RES_X=1920
ENV RES_Y=1080
ENV FPS=60

EXPOSE 8888

ENTRYPOINT ["/opt/fel/launch_pixel_streaming.sh"]
DOCKER_EOF

cat > "${ARCHIVE_DIR}/docker-compose.yml" <<'COMPOSE_EOF'
version: '3.8'

services:
  fel-server:
    build: .
    runtime: nvidia
    environment:
      - NVIDIA_VISIBLE_DEVICES=all
      - SIGNAL_URL=ws://signalling:8888
      - RES_X=1920
      - RES_Y=1080
      - FPS=60
    ports:
      - "8888:8888"
    depends_on:
      - signalling
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]

  signalling:
    image: node:20-slim
    working_dir: /app
    volumes:
      - ../../streaming/signalling:/app
    command: ["node", "server.js"]
    ports:
      - "8889:8889"

  coturn:
    image: coturn/coturn:latest
    ports:
      - "3478:3478"
      - "3478:3478/udp"
    command: >
      -n --log-file=stdout
      --realm=finalevolutiongroup.com
      --fingerprint
      --lt-cred-mech
      --user=fel:felpass
COMPOSE_EOF

log "  Docker config created ✓"

log ""
log "═══════════════════════════════════════════════════════════════"
log " Linux Server Build Complete"
log " Output: ${ARCHIVE_DIR}"
log " Launch: ${LAUNCH_SCRIPT}"
log " Docker: docker compose -f ${ARCHIVE_DIR}/docker-compose.yml up"
log " Log: ${LOG_FILE}"
log "═══════════════════════════════════════════════════════════════"
