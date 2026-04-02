#!/usr/bin/env bash
###############################################################################
# import_all_assets.sh — Run all asset import scripts inside UE5 Editor
#
# This script launches UE5 in commandlet mode and executes the Python import
# scripts to bring in all 49 AI-generated assets + Elijah Bonds animations.
#
# Usage:
#   source ../../.ue5_env   # or set UE_ROOT/FEL_PROJECT manually
#   ./import_all_assets.sh
###############################################################################
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Source UE5 environment if available
[[ -f "${ROOT}/.ue5_env" ]] && source "${ROOT}/.ue5_env"

UE_CMD="${UE_CMD:-${UE_ROOT}/Engine/Binaries/Linux/UnrealEditor-Cmd}"
PROJECT="${FEL_PROJECT:-${ROOT}/UnrealStarter/BasketballGame/FinalEvolutionLab.uproject}"

EDITOR_PYTHON_DIR="${ROOT}/UnrealStarter/BasketballGame/EditorPython"

log() { echo "[$(date '+%H:%M:%S')] $*"; }
err() { log "ERROR: $*"; exit 1; }

[[ -f "${PROJECT}" ]] || err "Project not found: ${PROJECT}"
[[ -f "${UE_CMD}" ]] || err "UE5 Cmd not found: ${UE_CMD}. Set UE_ROOT or source .ue5_env"

log "═══════════════════════════════════════════════════════════════"
log " FEL Asset Import Pipeline"
log "═══════════════════════════════════════════════════════════════"

# Step 1: Import 49 AI-generated assets (Meshy, Luma, DeepMotion)
log "Step 1: Importing 49 AI-generated assets..."
IMPORT_SCRIPT_1="${EDITOR_PYTHON_DIR}/fel_import_ai_assets.py"
if [[ -f "$IMPORT_SCRIPT_1" ]]; then
  "${UE_CMD}" "${PROJECT}" \
    -run=pythonscript \
    -script="${IMPORT_SCRIPT_1}" \
    -nosplash -unattended -nopause \
    2>&1 | tee "${ROOT}/logs/import_ai_assets.log"
  log "  AI assets imported ✓"
else
  log "  ⚠ Script not found: ${IMPORT_SCRIPT_1}"
fi

# Step 2: Import Elijah Bonds DeepMotion animations
log "Step 2: Importing Elijah Bonds animations..."
IMPORT_SCRIPT_2="${EDITOR_PYTHON_DIR}/fel_import_elijahbonds_animations.py"
if [[ -f "$IMPORT_SCRIPT_2" ]]; then
  "${UE_CMD}" "${PROJECT}" \
    -run=pythonscript \
    -script="${IMPORT_SCRIPT_2}" \
    -nosplash -unattended -nopause \
    2>&1 | tee "${ROOT}/logs/import_elijahbonds.log"
  log "  Elijah Bonds animations imported ✓"
else
  log "  ⚠ Script not found: ${IMPORT_SCRIPT_2}"
fi

# Step 3: Import UE5 catalogue animations
log "Step 3: Importing UE5 catalogue animations..."
IMPORT_SCRIPT_3="${EDITOR_PYTHON_DIR}/fel_import_catalogue_animations.py"
if [[ -f "$IMPORT_SCRIPT_3" ]]; then
  "${UE_CMD}" "${PROJECT}" \
    -run=pythonscript \
    -script="${IMPORT_SCRIPT_3}" \
    -nosplash -unattended -nopause \
    2>&1 | tee "${ROOT}/logs/import_catalogue.log"
  log "  Catalogue animations imported ✓"
else
  log "  ⚠ Script not found: ${IMPORT_SCRIPT_3}"
fi

# Step 4: Import OpenArt enhanced environment assets
log "Step 4: Importing OpenArt enhanced environment assets (504 files)..."
IMPORT_SCRIPT_4="${EDITOR_PYTHON_DIR}/fel_import_openart_assets.py"
if [[ -f "$IMPORT_SCRIPT_4" ]]; then
  "${UE_CMD}" "${PROJECT}" \
    -run=pythonscript \
    -script="${IMPORT_SCRIPT_4}" \
    -nosplash -unattended -nopause \
    2>&1 | tee "${ROOT}/logs/import_openart_assets.log"
  log "  OpenArt enhanced assets imported ✓"
else
  log "  ⚠ Script not found: ${IMPORT_SCRIPT_4}"
fi

# Step 5: Verify all assets
log "Step 5: Verifying asset imports..."
VERIFY_SCRIPT="${EDITOR_PYTHON_DIR}/fel_verify_assets.py"
if [[ -f "$VERIFY_SCRIPT" ]]; then
  "${UE_CMD}" "${PROJECT}" \
    -run=pythonscript \
    -script="${VERIFY_SCRIPT}" \
    -nosplash -unattended -nopause \
    2>&1 | tee "${ROOT}/logs/verify_assets.log"
  log "  Asset verification completed ✓"
fi

log ""
log "═══════════════════════════════════════════════════════════════"
log " Asset Import Complete"
log " Check logs in: ${ROOT}/logs/"
log "═══════════════════════════════════════════════════════════════"
