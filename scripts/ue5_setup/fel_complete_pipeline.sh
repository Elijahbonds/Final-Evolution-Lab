#!/usr/bin/env bash
###############################################################################
# fel_complete_pipeline.sh — Master Orchestration Script
# Runs the complete FEL pipeline:
#   CV Preprocessing → Validation → UE5 install → assets → cook → iOS
#
# Usage:
#   ./fel_complete_pipeline.sh [--skip-install] [--skip-cook] [--ios-only]
#                              [--skip-cv] [--cv-only]
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
SKIP_CV=false
IOS_ONLY=false
CV_ONLY=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --skip-install) SKIP_INSTALL=true; shift;;
    --skip-cook) SKIP_COOK=true; shift;;
    --skip-cv) SKIP_CV=true; shift;;
    --ios-only) IOS_ONLY=true; shift;;
    --cv-only) CV_ONLY=true; shift;;
    *) shift;;
  esac
done

mkdir -p "${ROOT}/logs"
PIPELINE_START=$(date +%s)
PIPELINE_LOG="${ROOT}/logs/pipeline_$(date '+%Y%m%d_%H%M%S').log"

log() { echo "[$(date '+%H:%M:%S')] ═══ $* ═══" | tee -a "$PIPELINE_LOG"; }
progress() { echo "[$(date '+%H:%M:%S')]   $*" | tee -a "$PIPELINE_LOG"; }

log "FINAL EVOLUTION LAB — Complete Pipeline v2.0"
echo ""
echo "  Project: ${ROOT}"
echo "  Date: $(date)"
echo "  System: $(uname -s) $(uname -m)"
echo "  Log: ${PIPELINE_LOG}"
echo "  Options: skip_cv=${SKIP_CV} skip_install=${SKIP_INSTALL} skip_cook=${SKIP_COOK}"
echo ""

# ── Helper: Rollback on failure ─────────────────────────────────────────────
CURRENT_PHASE=""
rollback() {
  local exit_code=$?
  if [[ $exit_code -ne 0 && -n "$CURRENT_PHASE" ]]; then
    log "FAILURE in ${CURRENT_PHASE} (exit code: ${exit_code})"
    progress "Pipeline halted. Check ${PIPELINE_LOG} for details."
    progress "Last successful phase completed before: ${CURRENT_PHASE}"
    progress "To resume, fix the issue and re-run with appropriate --skip flags."
    
    # Save failure state
    cat > "${ROOT}/logs/pipeline_failure.json" <<EOF
{
  "failed_phase": "${CURRENT_PHASE}",
  "exit_code": ${exit_code},
  "timestamp": "$(date -Iseconds)",
  "log_file": "${PIPELINE_LOG}",
  "resume_hint": "Fix the issue, then re-run with --skip flags for completed phases"
}
EOF
  fi
}
trap rollback EXIT

# ── Phase 0: CV Preprocessing (Biomechanical Isolation) ────────────────────
if [[ "${SKIP_CV}" == "false" ]]; then
  CURRENT_PHASE="CV_PREPROCESSING"
  log "PHASE 0a: CV Preprocessing — Biomechanical Isolation"
  
  if command -v python3 &>/dev/null; then
    cd "${ROOT}"
    python3 scripts/cv_preprocessing/preprocessing_pipeline.py --all \
      --method kalman --confidence 0.4 2>&1 | tee -a "$PIPELINE_LOG" || {
      progress "[WARN] CV preprocessing had errors — continuing with raw videos"
    }
    
    # Quality control checkpoint
    log "PHASE 0b: Biomechanical Validation"
    CV_META_DIR="${ROOT}/GeneratedAssets/CVPreprocessed/metadata"
    if [[ -d "$CV_META_DIR" ]]; then
      python3 scripts/cv_preprocessing/biomechanical_validator.py \
        --batch "$CV_META_DIR" \
        --output "${ROOT}/logs/validation_reports" 2>&1 | tee -a "$PIPELINE_LOG" || {
        progress "[WARN] Validation had errors — review logs"
      }
      
      # Check if validation passed
      VALID_REPORT="${ROOT}/logs/validation_reports/validation_aggregate.json"
      if [[ -f "$VALID_REPORT" ]]; then
        READY_COUNT=$(python3 -c "
import json
data = json.load(open('$VALID_REPORT'))
print(data.get('deepmotion_ready', 0))
" 2>/dev/null || echo "0")
        progress "DeepMotion-ready videos: ${READY_COUNT}/10"
        
        if [[ "$READY_COUNT" -eq 0 ]]; then
          progress "[WARN] No videos passed validation — check CV preprocessing quality"
        fi
      fi
    else
      progress "[WARN] No CV metadata found — skipping validation"
    fi
  else
    progress "[ERROR] Python3 not available — skipping CV preprocessing"
  fi
  
  if [[ "${CV_ONLY}" == "true" ]]; then
    log "CV_ONLY mode — stopping after preprocessing"
    exit 0
  fi
fi

# ── Phase 1: UE5 Installation ───────────────────────────────────────────────
if [[ "${SKIP_INSTALL}" == "false" && "${IOS_ONLY}" == "false" ]]; then
  CURRENT_PHASE="UE5_INSTALLATION"
  log "PHASE 1: UE5 Installation"
  bash "${SCRIPT_DIR}/install_ue5_linux.sh" 2>&1 | tee -a "$PIPELINE_LOG"
fi

# Source environment
[[ -f "${ROOT}/.ue5_env" ]] && source "${ROOT}/.ue5_env"

# ── Phase 1.5: OpenArt Enhanced Environment Asset Generation ─────────────────
if [[ "${IOS_ONLY}" == "false" ]]; then
  CURRENT_PHASE="OPENART_GENERATION"
  log "PHASE 1.5: OpenArt Enhanced Environment Assets"
  if [[ -f "${ROOT}/GeneratedAssets/Environments/openart_asset_manifest.json" ]]; then
    log "  OpenArt assets already generated (manifest found) — skipping"
  else
    log "  Generating OpenArt enhanced assets for 12 environments..."
    cd "${ROOT}"
    python3 -m scripts.environment_gen.openart_enhanced_pipeline --quality high 2>&1 | tee -a "$PIPELINE_LOG"
    log "  OpenArt asset generation complete ✓"
  fi
fi

# ── Phase 2: Asset Import ───────────────────────────────────────────────────
if [[ "${IOS_ONLY}" == "false" ]]; then
  CURRENT_PHASE="ASSET_IMPORT"
  log "PHASE 2: Asset Import (includes OpenArt enhanced assets)"
  bash "${SCRIPT_DIR}/import_all_assets.sh" 2>&1 | tee -a "$PIPELINE_LOG"
fi

# ── Phase 3: Cook for Linux Server ──────────────────────────────────────────
if [[ "${SKIP_COOK}" == "false" && "${IOS_ONLY}" == "false" ]]; then
  CURRENT_PHASE="LINUX_COOK"
  log "PHASE 3: Cook Linux Server Build"
  bash "${SCRIPT_DIR}/cook_fel_linux_server.sh" --config Shipping 2>&1 | tee -a "$PIPELINE_LOG"
fi

# ── Phase 4: Cook for iOS ───────────────────────────────────────────────────
if [[ "$(uname)" == "Darwin" ]]; then
  CURRENT_PHASE="IOS_COOK"
  log "PHASE 4: Cook iOS Build"
  bash "${SCRIPT_DIR}/cook_fel_ios.sh" --config Shipping 2>&1 | tee -a "$PIPELINE_LOG"
  
  CURRENT_PHASE="IOS_BUILD"
  log "PHASE 5: Prepare iOS App"
  bash "${SCRIPT_DIR}/prepare_ios_build.sh" 2>&1 | tee -a "$PIPELINE_LOG"
else
  log "PHASE 4-5: iOS (Skipped — requires macOS)"
  echo "  iOS configuration files have been prepared."
  echo "  Transfer project to macOS and run:"
  echo "    ./scripts/ue5_setup/cook_fel_ios.sh"
  echo "    ./scripts/ue5_setup/prepare_ios_build.sh"
fi

# ── Pipeline Summary ────────────────────────────────────────────────────────
CURRENT_PHASE=""
PIPELINE_END=$(date +%s)
PIPELINE_DURATION=$(( PIPELINE_END - PIPELINE_START ))
PIPELINE_MINS=$(( PIPELINE_DURATION / 60 ))

log "PIPELINE COMPLETE"
echo ""
echo "  Total time: ${PIPELINE_MINS} minutes (${PIPELINE_DURATION}s)"
echo "  Log: ${PIPELINE_LOG}"
echo ""

# Generate completion summary
cat > "${ROOT}/logs/pipeline_complete.json" <<EOF
{
  "status": "complete",
  "timestamp": "$(date -Iseconds)",
  "duration_seconds": ${PIPELINE_DURATION},
  "duration_minutes": ${PIPELINE_MINS},
  "phases_completed": [
    $([ "${SKIP_CV}" == "false" ] && echo '"cv_preprocessing", "validation",' || echo '')
    $([ "${SKIP_INSTALL}" == "false" ] && echo '"ue5_installation",' || echo '')
    "asset_import",
    $([ "${SKIP_COOK}" == "false" ] && echo '"linux_cook",' || echo '')
    $([ "$(uname)" == "Darwin" ] && echo '"ios_cook", "ios_build"' || echo '"ios_skipped"')
  ],
  "log_file": "${PIPELINE_LOG}"
}
EOF

echo "  Completion info saved to: ${ROOT}/logs/pipeline_complete.json"
echo ""
echo "  Logs: ${ROOT}/logs/"
echo "  Linux build: ${ROOT}/Builds/LinuxServer/"
echo "  iOS build: ${ROOT}/Builds/iOS_App/"
echo ""
echo "  Deployment:"
echo "    Linux: docker compose -f Builds/LinuxServer/docker-compose.yml up"
echo "    iOS: Open Builds/iOS_App/ in Xcode → TestFlight"
