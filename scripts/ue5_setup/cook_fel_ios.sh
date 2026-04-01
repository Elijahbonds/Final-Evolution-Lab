#!/usr/bin/env bash
###############################################################################
# cook_fel_ios.sh — Cook/Package FEL for iOS
# Requires macOS with Xcode installed and UE5 for Mac.
#
# Usage:
#   export UE_ROOT="/Users/Shared/Epic Games/UE_5.4"
#   ./cook_fel_ios.sh [--config Development|Shipping]
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
ARCHIVE_DIR="${ROOT}/Builds/iOS"
LOG_FILE="${ROOT}/logs/cook_ios_$(date +%Y%m%d_%H%M%S).log"

mkdir -p "$(dirname "$LOG_FILE")" "${ARCHIVE_DIR}"

log() { echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG_FILE"; }
err() { log "ERROR: $*"; exit 1; }

# ── Platform Check ───────────────────────────────────────────────────────────
if [[ "$(uname)" != "Darwin" ]]; then
  log "⚠ WARNING: iOS builds require macOS with Xcode."
  log "  This script can prepare the project, but cooking must run on macOS."
  log "  Preparing project configuration only..."
  
  # Still configure the project for iOS
  MACOS_ONLY=true
else
  MACOS_ONLY=false
  
  # Verify Xcode
  if ! xcode-select -p &>/dev/null; then
    err "Xcode not found. Install from App Store or: xcode-select --install"
  fi
  
  XCODE_VER=$(xcodebuild -version | head -1)
  log "  Xcode: ${XCODE_VER} ✓"
fi

# ── Detect UE5 paths (macOS) ────────────────────────────────────────────────
if [[ "${MACOS_ONLY}" == "false" ]]; then
  UE_ROOT="${UE_ROOT:-/Users/Shared/Epic Games/UE_5.4}"
  RUN_UAT="${UE_ROOT}/Engine/Build/BatchFiles/RunUAT.sh"
  UE_EDITOR="${UE_ROOT}/Engine/Binaries/Mac/UnrealEditor"
  
  # Try alternative paths
  for ue_ver in "5.7" "5.6" "5.5" "5.4" "5.3"; do
    if [[ -f "/Users/Shared/Epic Games/UE_${ue_ver}/Engine/Build/BatchFiles/RunUAT.sh" ]]; then
      UE_ROOT="/Users/Shared/Epic Games/UE_${ue_ver}"
      RUN_UAT="${UE_ROOT}/Engine/Build/BatchFiles/RunUAT.sh"
      UE_EDITOR="${UE_ROOT}/Engine/Binaries/Mac/UnrealEditor"
      log "  Found UE ${ue_ver} at: ${UE_ROOT}"
      break
    fi
  done
  
  [[ -f "${RUN_UAT}" ]] || err "RunUAT not found. Set UE_ROOT to your UE5 install path."
fi

[[ -f "${PROJECT}" ]] || err "Project not found: ${PROJECT}"

log "═══════════════════════════════════════════════════════════════"
log " Cooking FEL for iOS"
log " Config: ${CONFIG}"
log " Project: ${PROJECT}"
log "═══════════════════════════════════════════════════════════════"

# ── Step 1: Configure iOS Platform Support ───────────────────────────────────
log "Step 1: Configuring iOS platform support..."

# Update DefaultEngine.ini for iOS
IOS_CONFIG_DIR="${ROOT}/UnrealStarter/BasketballGame/Config/IOS"
mkdir -p "${IOS_CONFIG_DIR}"

cat > "${IOS_CONFIG_DIR}/IOSEngine.ini" <<'INI_EOF'
[/Script/IOSRuntimeSettings.IOSRuntimeSettings]
bSupportsPortraitOrientation=False
bSupportsUpsideDownOrientation=False
bSupportsLandscapeLeftOrientation=True
bSupportsLandscapeRightOrientation=True
MinimumiOSVersion=IOS_16
bGeneratedSYMFile=True
bGeneratedSYMBundle=True
bShipForBitcode=False
bEnableRemoteNotificationsSupport=True
AdditionalPlistData=<key>UIRequiresFullScreen</key><true/>
BundleDisplayName=Final Evolution Lab
BundleName=FinalEvolutionLab
BundleIdentifier=com.finalevolutiongroup.lab
bSupportsOpenGLES2=False
bSupportsMetal=True
bSupportsMetalMRT=True
MetalLanguageVersion=5
INI_EOF

log "  iOS config created: ${IOS_CONFIG_DIR}/IOSEngine.ini ✓"

# ── Step 2: Configure Pixel Streaming for iOS Client ─────────────────────────
log "Step 2: Configuring Pixel Streaming client settings..."

# Create iOS-specific Pixel Streaming config
cat > "${ROOT}/UnrealStarter/BasketballGame/Config/FEL_PixelStreaming_iOS.ini" <<'PS_INI_EOF'
[PixelStreaming]
; iOS Pixel Streaming Client Configuration
; The iOS app connects to the cloud UE5 server via WebRTC
WebRTCMaxBitrate=20000000
WebRTCMinBitrate=1000000
WebRTCStartBitrate=5000000
WebRTCFps=60
; Signal server URL — set to production domain
SignallingServerURL=wss://stream.finalevolutiongroup.com
; Adaptive streaming for mobile networks  
AdaptiveStreaming=true
QualityControlOwnership=Signalling
; iOS-specific optimizations
EnableHardwareH264Decoding=true
PS_INI_EOF

log "  Pixel Streaming iOS config created ✓"

# ── Step 3: Cook for iOS (macOS only) ────────────────────────────────────────
if [[ "${MACOS_ONLY}" == "false" ]]; then
  log "Step 3: Building & Cooking for iOS..."
  
  "${RUN_UAT}" BuildCookRun \
    -project="${PROJECT}" \
    -noP4 \
    -platform=IOS \
    -clientconfig="${CONFIG}" \
    -cook \
    -allmaps \
    -build \
    -stage \
    -pak \
    -archive \
    -archivedirectory="${ARCHIVE_DIR}" \
    -installed \
    -unrealexe="${UE_EDITOR}" \
    -utf8output \
    -compressed \
    -distribution \
    2>&1 | tee -a "$LOG_FILE"
  
  log "  iOS build completed ✓"
  log "  Output: ${ARCHIVE_DIR}"
else
  log "Step 3: ⚠ Skipping iOS cook (requires macOS)"
  log "  Run this script on macOS with Xcode and UE5 installed."
  log "  Configuration files have been prepared."
fi

# ── Step 4: Generate IPA instructions ────────────────────────────────────────
log "Step 4: IPA generation instructions..."

cat > "${ARCHIVE_DIR}/BUILD_IPA_INSTRUCTIONS.md" <<'MD_EOF'
# Building FEL iOS IPA

## Prerequisites
- macOS with Xcode 15+
- Apple Developer account
- Valid provisioning profile and signing certificate
- UE5 5.4+ installed

## Signing Configuration
1. Open Xcode → Preferences → Accounts → Add Apple ID
2. Download provisioning profiles for `com.finalevolutiongroup.lab`
3. Set in project settings:
   - Team: Final Evolution Group
   - Bundle ID: com.finalevolutiongroup.lab
   - Signing Certificate: Apple Distribution

## Build Steps
```bash
# 1. Cook the project (this script)
./cook_fel_ios.sh --config Shipping

# 2. Open in Xcode
open Builds/iOS/FinalEvolutionLab.xcodeproj

# 3. Or use xcodebuild CLI
xcodebuild -project Builds/iOS/FinalEvolutionLab.xcodeproj \
  -scheme FinalEvolutionLab \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath Builds/iOS/FinalEvolutionLab.xcarchive \
  archive

# 4. Export IPA
xcodebuild -exportArchive \
  -archivePath Builds/iOS/FinalEvolutionLab.xcarchive \
  -exportOptionsPlist scripts/ExportOptions.plist \
  -exportPath Builds/iOS/IPA/
```

## TestFlight Upload
```bash
# Using xcrun
xcrun altool --upload-app \
  --type ios \
  --file Builds/iOS/IPA/FinalEvolutionLab.ipa \
  --apiKey YOUR_API_KEY \
  --apiIssuer YOUR_ISSUER_ID
```
MD_EOF

log "  Build instructions: ${ARCHIVE_DIR}/BUILD_IPA_INSTRUCTIONS.md ✓"

log ""
log "═══════════════════════════════════════════════════════════════"
log " iOS Build Preparation Complete"
log " Config: ${IOS_CONFIG_DIR}/"
log " Archive: ${ARCHIVE_DIR}/"
log " Log: ${LOG_FILE}"
log "═══════════════════════════════════════════════════════════════"
