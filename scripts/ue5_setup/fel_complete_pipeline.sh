#!/usr/bin/env bash
###############################################################################
# fel_complete_pipeline.sh — Master Orchestration Script
# Runs the complete FEL pipeline: UE5 install → assets → cook → iOS
#
# Usage:
#   ./fel_complete_pipeline.sh [--skip-install] [--skip-cook] [--ios-only]
#
# Prerequisites:
#   - GPU-enabled machine (NVIDIA recommended)
#   - 200GB+ free disk space
#   - GitHub account linked to Epic Games
#   - macOS with Xcode for iOS builds
###############################################################################
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

SKIP_INSTALL=false
SKIP_COOK=false
IOS_ONLY=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --skip-install) SKIP_INSTALL=true; shift;;
    --skip-cook) SKIP_COOK=true; shift;;
    --ios-only) IOS_ONLY=true; shift;;
    *) shift;;
  esac
done

mkdir -p "${ROOT}/logs"

log() { echo "[$(date '+%H:%M:%S')] ═══ $* ═══"; }

log "FINAL EVOLUTION LAB — Complete Pipeline"
echo ""
echo "  Project: ${ROOT}"
echo "  Date: $(date)"
echo "  System: $(uname -s) $(uname -m)"
echo ""

# ── Phase 1: UE5 Installation ───────────────────────────────────────────────
if [[ "${SKIP_INSTALL}" == "false" && "${IOS_ONLY}" == "false" ]]; then
  log "PHASE 1: UE5 Installation"
  bash "${SCRIPT_DIR}/install_ue5_linux.sh"
fi

# Source environment
[[ -f "${ROOT}/.ue5_env" ]] && source "${ROOT}/.ue5_env"

# ── Phase 2: Asset Import ───────────────────────────────────────────────────
if [[ "${IOS_ONLY}" == "false" ]]; then
  log "PHASE 2: Asset Import"
  bash "${SCRIPT_DIR}/import_all_assets.sh"
fi

# ── Phase 3: Cook for Linux Server ──────────────────────────────────────────
if [[ "${SKIP_COOK}" == "false" && "${IOS_ONLY}" == "false" ]]; then
  log "PHASE 3: Cook Linux Server Build"
  bash "${SCRIPT_DIR}/cook_fel_linux_server.sh" --config Shipping
fi

# ── Phase 4: Cook for iOS ───────────────────────────────────────────────────
if [[ "$(uname)" == "Darwin" ]]; then
  log "PHASE 4: Cook iOS Build"
  bash "${SCRIPT_DIR}/cook_fel_ios.sh" --config Shipping
  
  log "PHASE 5: Prepare iOS App"
  bash "${SCRIPT_DIR}/prepare_ios_build.sh"
else
  log "PHASE 4-5: iOS (Skipped — requires macOS)"
  echo "  iOS configuration files have been prepared."
  echo "  Transfer project to macOS and run:"
  echo "    ./scripts/ue5_setup/cook_fel_ios.sh"
  echo "    ./scripts/ue5_setup/prepare_ios_build.sh"
fi

log "PIPELINE COMPLETE"
echo ""
echo "  Logs: ${ROOT}/logs/"
echo "  Linux build: ${ROOT}/Builds/LinuxServer/"
echo "  iOS build: ${ROOT}/Builds/iOS_App/"
echo ""
echo "  Deployment:"
echo "    Linux: docker compose -f Builds/LinuxServer/docker-compose.yml up"
echo "    iOS: Open Builds/iOS_App/ in Xcode → TestFlight"
