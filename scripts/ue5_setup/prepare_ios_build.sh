#!/usr/bin/env bash
###############################################################################
# prepare_ios_build.sh — Prepare iOS build for TestFlight/App Store submission
# 
# This script:
#   1. Updates Xcode project configuration
#   2. Configures code signing  
#   3. Builds the iOS app
#   4. Creates IPA for distribution
#   5. Optionally uploads to TestFlight
#
# Must run on macOS with Xcode 15+
#
# Usage:
#   ./prepare_ios_build.sh [--upload-testflight]
###############################################################################
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
IOS_DIR="${ROOT}/ios"
XCODE_PROJECT="${IOS_DIR}/FinalEvolutionLab.xcodeproj"
BUILD_DIR="${ROOT}/Builds/iOS_App"
LOG_FILE="${ROOT}/logs/ios_build_$(date +%Y%m%d_%H%M%S).log"
UPLOAD_TESTFLIGHT=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --upload-testflight) UPLOAD_TESTFLIGHT=true; shift;;
    *) shift;;
  esac
done

mkdir -p "${BUILD_DIR}" "$(dirname "$LOG_FILE")"

log() { echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG_FILE"; }
err() { log "ERROR: $*"; exit 1; }

# ── Platform Check ───────────────────────────────────────────────────────────
if [[ "$(uname)" != "Darwin" ]]; then
  log "⚠ This script must run on macOS. Generating configuration files only..."
  PREPARE_ONLY=true
else
  PREPARE_ONLY=false
  xcode-select -p &>/dev/null || err "Xcode required: xcode-select --install"
fi

log "═══════════════════════════════════════════════════════════════"
log " FEL iOS Build Preparation"
log " Project: ${XCODE_PROJECT}"
log "═══════════════════════════════════════════════════════════════"

# ── Step 1: Update Info.plist ────────────────────────────────────────────────
log "Step 1: Updating Info.plist..."

INFO_PLIST="${IOS_DIR}/FinalEvolutionLab/Info.plist"
if [[ ! -f "$INFO_PLIST" ]]; then
  cat > "$INFO_PLIST" <<'PLIST_EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDisplayName</key>
    <string>Final Evolution Lab</string>
    <key>CFBundleExecutable</key>
    <string>$(EXECUTABLE_NAME)</string>
    <key>CFBundleIdentifier</key>
    <string>com.finalevolutiongroup.lab</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$(PRODUCT_NAME)</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSRequiresIPhoneOS</key>
    <true/>
    <key>UILaunchStoryboardName</key>
    <string>LaunchScreen</string>
    <key>UIRequiredDeviceCapabilities</key>
    <array>
        <string>armv7</string>
        <string>metal</string>
    </array>
    <key>UISupportedInterfaceOrientations</key>
    <array>
        <string>UIInterfaceOrientationPortrait</string>
        <string>UIInterfaceOrientationLandscapeLeft</string>
        <string>UIInterfaceOrientationLandscapeRight</string>
    </array>
    <key>UIStatusBarHidden</key>
    <false/>
    <key>NSCameraUsageDescription</key>
    <string>Final Evolution Lab uses the camera for motion capture and AR features.</string>
    <key>NSMotionUsageDescription</key>
    <string>Final Evolution Lab uses motion sensors to track your movements during exercises.</string>
    <key>NSHealthShareUsageDescription</key>
    <string>Final Evolution Lab reads health data to personalize your training.</string>
    <key>NSHealthUpdateUsageDescription</key>
    <string>Final Evolution Lab saves workout data to Apple Health.</string>
    <key>NSLocalNetworkUsageDescription</key>
    <string>Final Evolution Lab uses local networking for multiplayer features.</string>
    <key>NSMicrophoneUsageDescription</key>
    <string>Final Evolution Lab uses the microphone for voice chat in multiplayer.</string>
    <key>ITSAppUsesNonExemptEncryption</key>
    <false/>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key>
        <false/>
        <key>NSExceptionDomains</key>
        <dict>
            <key>finalevolutiongroup.com</key>
            <dict>
                <key>NSIncludesSubdomains</key>
                <true/>
                <key>NSExceptionAllowsInsecureHTTPLoads</key>
                <false/>
                <key>NSExceptionRequiresForwardSecrecy</key>
                <true/>
            </dict>
        </dict>
    </dict>
</dict>
</plist>
PLIST_EOF
  log "  Created Info.plist ✓"
else
  log "  Info.plist already exists ✓"
fi

# ── Step 2: Create ExportOptions.plist ───────────────────────────────────────
log "Step 2: Creating ExportOptions.plist..."

EXPORT_OPTIONS="${ROOT}/scripts/ExportOptions_AppStore.plist"
cat > "${EXPORT_OPTIONS}" <<'EXPORT_EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store-connect</string>
    <key>teamID</key>
    <string>YOUR_TEAM_ID</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>stripSwiftSymbols</key>
    <true/>
    <key>uploadBitcode</key>
    <false/>
    <key>uploadSymbols</key>
    <true/>
    <key>destination</key>
    <string>upload</string>
</dict>
</plist>
EXPORT_EOF

# Also create ad-hoc for testing
EXPORT_OPTIONS_ADHOC="${ROOT}/scripts/ExportOptions_AdHoc.plist"
cat > "${EXPORT_OPTIONS_ADHOC}" <<'ADHOC_EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>ad-hoc</string>
    <key>teamID</key>
    <string>YOUR_TEAM_ID</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>stripSwiftSymbols</key>
    <true/>
    <key>compileBitcode</key>
    <false/>
    <key>thinning</key>
    <string>&lt;none&gt;</string>
</dict>
</plist>
ADHOC_EOF

log "  ExportOptions created ✓"

# ── Step 3: Create entitlements ──────────────────────────────────────────────
log "Step 3: Updating entitlements..."

ENTITLEMENTS="${IOS_DIR}/FinalEvolutionLab/FinalEvolutionLab.entitlements"
cat > "${ENTITLEMENTS}" <<'ENT_EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.healthkit</key>
    <true/>
    <key>com.apple.developer.healthkit.access</key>
    <array>
        <string>health-records</string>
    </array>
    <key>com.apple.developer.networking.multicast</key>
    <true/>
    <key>aps-environment</key>
    <string>production</string>
</dict>
</plist>
ENT_EOF

log "  Entitlements updated ✓"

# ── Step 4: Build & Archive (macOS only) ─────────────────────────────────────
if [[ "${PREPARE_ONLY}" == "false" ]]; then
  log "Step 4: Building iOS app..."
  
  ARCHIVE_PATH="${BUILD_DIR}/FinalEvolutionLab.xcarchive"
  IPA_PATH="${BUILD_DIR}/IPA"
  
  # Clean
  xcodebuild clean \
    -project "${XCODE_PROJECT}" \
    -scheme FinalEvolutionLab \
    -configuration Release \
    2>&1 | tee -a "$LOG_FILE"
  
  # Archive
  log "  Archiving..."
  xcodebuild archive \
    -project "${XCODE_PROJECT}" \
    -scheme FinalEvolutionLab \
    -configuration Release \
    -destination 'generic/platform=iOS' \
    -archivePath "${ARCHIVE_PATH}" \
    CODE_SIGN_IDENTITY="Apple Distribution" \
    DEVELOPMENT_TEAM="YOUR_TEAM_ID" \
    PRODUCT_BUNDLE_IDENTIFIER="com.finalevolutiongroup.lab" \
    MARKETING_VERSION="1.0.0" \
    CURRENT_PROJECT_VERSION="1" \
    2>&1 | tee -a "$LOG_FILE"
  
  log "  Archive created: ${ARCHIVE_PATH} ✓"
  
  # Export IPA
  log "  Exporting IPA..."
  xcodebuild -exportArchive \
    -archivePath "${ARCHIVE_PATH}" \
    -exportOptionsPlist "${EXPORT_OPTIONS}" \
    -exportPath "${IPA_PATH}" \
    2>&1 | tee -a "$LOG_FILE"
  
  IPA_FILE=$(find "${IPA_PATH}" -name "*.ipa" | head -1)
  if [[ -n "$IPA_FILE" ]]; then
    IPA_SIZE=$(du -sh "$IPA_FILE" | cut -f1)
    log "  IPA created: ${IPA_FILE} (${IPA_SIZE}) ✓"
  else
    log "  ⚠ IPA not found in ${IPA_PATH}"
  fi
  
  # ── Step 5: Upload to TestFlight ───────────────────────────────────────
  if [[ "${UPLOAD_TESTFLIGHT}" == "true" && -n "$IPA_FILE" ]]; then
    log "Step 5: Uploading to TestFlight..."
    
    xcrun altool --upload-app \
      --type ios \
      --file "${IPA_FILE}" \
      --apiKey "${APP_STORE_API_KEY:-YOUR_API_KEY}" \
      --apiIssuer "${APP_STORE_ISSUER:-YOUR_ISSUER_ID}" \
      2>&1 | tee -a "$LOG_FILE" || {
      log "  ⚠ TestFlight upload failed. Manual upload required via Xcode or Transporter."
    }
  fi
else
  log "Step 4: ⚠ Skipping build (requires macOS)"
  log "  Configuration files prepared. Run on macOS to build."
fi

log ""
log "═══════════════════════════════════════════════════════════════"
log " iOS Build Preparation Complete"
log ""
log " Next steps on macOS:"
log "   1. Open ${XCODE_PROJECT} in Xcode"
log "   2. Set Team ID in Signing & Capabilities"
log "   3. Update YOUR_TEAM_ID in ExportOptions plists"
log "   4. Run: ./prepare_ios_build.sh --upload-testflight"
log ""
log " Log: ${LOG_FILE}"
log "═══════════════════════════════════════════════════════════════"
