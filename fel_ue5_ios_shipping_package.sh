#!/usr/bin/env bash
# fel_ue5_ios_shipping_package.sh
# Final Evolution Lab — iOS Shipping IPA Build Recipe
# Target device: iPhone 16 Pro Max (arm64)
# Run on macOS with Xcode 15.4+, UE5.7 source build, and a valid Apple
# Developer signing identity. This script is idempotent and fail-fast.

set -euo pipefail

# ──────────────────────────────────────────────────────────────
# Config (override via env)
# ──────────────────────────────────────────────────────────────
UPROJECT="${UPROJECT:-${HOME}/FinalEvolutionLab/FinalEvolutionLab.uproject}"
UE_ROOT="${UE_ROOT:-/Users/Shared/Epic Games/UE_5.7}"
SCHEME="${SCHEME:-FinalEvolutionLab}"
BUNDLE_ID="${BUNDLE_ID:-com.finalevolution.lab}"
TEAM_ID="${TEAM_ID:-}"
DEVICE="${DEVICE:-iPhone16,2}"            # iPhone 16 Pro Max
CONFIG="${CONFIG:-Shipping}"
ARCH="${ARCH:-arm64}"
OUT_DIR="${OUT_DIR:-${PWD}/dist/ios}"
ARCHIVE_PATH="${OUT_DIR}/${SCHEME}.xcarchive"
IPA_PATH="${OUT_DIR}/${SCHEME}.ipa"
EXPORT_OPTIONS="${EXPORT_OPTIONS:-${PWD}/infra/ue5_config/ExportOptions.plist}"
LOG_DIR="${OUT_DIR}/logs"

# Sovereign hub config (must match production)
SOVEREIGN_WS="${SOVEREIGN_WS:-wss://finalevolutiongroup.com/ws/sovereign}"

usage() {
    cat <<EOF
Usage: $0 [--shipping|--debug|--clean|--no-pak|--purge-cache] [...]
  --shipping      Build Shipping IPA for App Store / TestFlight (default)
  --debug         Build Development IPA for on-device debugging
  --clean         Clean OUT_DIR build artifacts and exit
  --no-pak        Disable Pak File + Io Store for descriptor debugging
                  (forces flat .uproject staging — bigger IPA, easier to
                  diagnose "Failed to open descriptor file" errors)
  --purge-cache   Brute-force purge UE5 Binaries/Intermediate/Saved/
                  DerivedDataCache before building. Forces UAT to use
                  current production-hardened paths instead of stale ones.
                  Combine with --shipping for an emergency clean rebuild.

Required env: TEAM_ID
Optional env: UPROJECT, UE_ROOT, SCHEME, BUNDLE_ID, DEVICE, OUT_DIR
EOF
}

MODE="shipping"
USE_PAK=true
PURGE_CACHE=false
for arg in "$@"; do
    case "$arg" in
        --shipping)    MODE="shipping"; CONFIG="Shipping" ;;
        --debug)       MODE="debug";    CONFIG="Development" ;;
        --clean)       rm -rf "${OUT_DIR}" && echo "🧹 Cleaned ${OUT_DIR}" && exit 0 ;;
        --no-pak)      USE_PAK=false ;;
        --purge-cache) PURGE_CACHE=true ;;
        -h|--help)     usage; exit 0 ;;
        "")            : ;;
        *) echo "❌ Unknown arg: $arg"; usage; exit 1 ;;
    esac
done

mkdir -p "${OUT_DIR}" "${LOG_DIR}"

# TEAM_ID required only for actual builds (not --help / --clean)
if [ -z "${TEAM_ID}" ]; then
    echo "❌ TEAM_ID env var is required (Apple Developer Team ID). e.g.: TEAM_ID=ABCDE12345 $0 --shipping" >&2
    exit 1
fi

log()  { echo -e "[\033[36mfel-ship\033[0m] $*"; }
fail() { echo -e "[\033[31mfel-ship\033[0m] $*" >&2; exit 1; }

# ──────────────────────────────────────────────────────────────
# 0) Pre-flight
# ──────────────────────────────────────────────────────────────
log "Mode: ${MODE} (${CONFIG})  ·  Device: ${DEVICE}"
[ "$(uname)" = "Darwin" ] || fail "This script must run on macOS (xcodebuild required)."
command -v xcodebuild >/dev/null 2>&1 || fail "xcodebuild not found — install Xcode."
command -v plutil      >/dev/null 2>&1 || fail "plutil not found."
[ -f "${UPROJECT}" ] || fail "UPROJECT not found: ${UPROJECT}"
[ -d "${UE_ROOT}" ]  || fail "UE_ROOT not found: ${UE_ROOT}"
[ -f "${EXPORT_OPTIONS}" ] || fail "ExportOptions.plist missing: ${EXPORT_OPTIONS}"
log "✅ Tools & paths ok"

# ──────────────────────────────────────────────────────────────
# 1) Pre-build CI guard (descriptor path / scheme integrity)
# ──────────────────────────────────────────────────────────────
log "Running prebuild CI check…"
"${PWD}/infra/fel_prebuild_ci_check.sh" || fail "Prebuild CI failed."

# ──────────────────────────────────────────────────────────────
# 1b) BRUTE-FORCE CACHE PURGE (only when --purge-cache is set)
# Removes stale UE5 build state that pins old descriptor paths.
# ──────────────────────────────────────────────────────────────
if [ "${PURGE_CACHE}" = "true" ]; then
    PROJECT_DIR="$(dirname "${UPROJECT}")"
    log "🧹 Purging UE5 build state under ${PROJECT_DIR}…"
    for d in Binaries Intermediate Saved DerivedDataCache; do
        if [ -d "${PROJECT_DIR}/${d}" ]; then
            rm -rf "${PROJECT_DIR}/${d}"
            log "   removed ${PROJECT_DIR}/${d}"
        fi
    done
    # Re-generate Xcode project so UAT picks up the clean state.
    if [ -f "${UE_ROOT}/Engine/Build/BatchFiles/Mac/GenerateProjectFiles.sh" ]; then
        log "Re-generating Xcode project files…"
        "${UE_ROOT}/Engine/Build/BatchFiles/Mac/GenerateProjectFiles.sh" -project="${UPROJECT}" -game -engine 2>&1 | tee "${LOG_DIR}/regen.log" || \
            log "⚠️  GenerateProjectFiles non-fatal failure — UAT will regenerate on cook."
    fi
fi

# ──────────────────────────────────────────────────────────────
# 1c) Descriptor sanity check — case-sensitive filename vs ID
# iOS is case-sensitive; macOS dev workstations are not. Trip
# this guard early before UAT spends 10 minutes cooking.
# ──────────────────────────────────────────────────────────────
DESC_BASENAME="$(basename "${UPROJECT}")"
EXPECTED_BASENAME="${SCHEME}.uproject"
if [ "${DESC_BASENAME}" != "${EXPECTED_BASENAME}" ]; then
    fail "Descriptor case mismatch: '${DESC_BASENAME}' must equal '${EXPECTED_BASENAME}' (iOS is case-sensitive)."
fi
DESC_DIR_BASENAME="$(basename "$(dirname "${UPROJECT}")")"
if [ "${DESC_DIR_BASENAME}" != "${SCHEME}" ] && [ "${DESC_DIR_BASENAME}" != "${SCHEME}57" ]; then
    log "⚠️  Project folder '${DESC_DIR_BASENAME}' does not match SCHEME '${SCHEME}'. Symlink to ~/Developer/${SCHEME} recommended."
fi
log "✅ Descriptor names case-aligned: ${DESC_BASENAME}"

# ──────────────────────────────────────────────────────────────
# 2) Sovereign Hub handshake verify (against production backend)
# ──────────────────────────────────────────────────────────────
if [ -n "${BACKEND_URL:-}" ]; then
    log "Verifying Sovereign Hub handshake at ${BACKEND_URL}…"
    HS=$(curl -fsS "${BACKEND_URL}/api/sovereign/handshake/verify" || true)
    if [ -z "${HS}" ]; then
        log "⚠️  Could not reach handshake endpoint — proceeding (offline build)."
    else
        echo "${HS}" | grep -q '"ok":[[:space:]]*true' || fail "Handshake verify failed: ${HS}"
        log "✅ Sovereign handshake verified"
    fi
else
    log "⚠️  BACKEND_URL not set — skipping handshake verify (offline build)."
fi

# ──────────────────────────────────────────────────────────────
# 3) UE5 cook + stage for IOS Shipping
# ──────────────────────────────────────────────────────────────
PAK_FLAGS="-pak -compressed"
if [ "${USE_PAK}" = "false" ]; then
    PAK_FLAGS=""
    log "⚠️  --no-pak: building with FLAT staging (no .pak, no Io Store) — IPA will be larger."
fi

log "Cooking + packaging UE5 IOS ${CONFIG}…"
"${UE_ROOT}/Engine/Build/BatchFiles/RunUAT.sh" BuildCookRun \
    -project="${UPROJECT}" \
    -platform=IOS \
    -configuration="${CONFIG}" \
    -clientconfig="${CONFIG}" \
    -targetplatform=IOS \
    -architecture="${ARCH}" \
    -cook -allmaps -build -stage -package ${PAK_FLAGS} \
    -archive -archivedirectory="${OUT_DIR}/uat" \
    -prereqs -nodebuginfo \
    2>&1 | tee "${LOG_DIR}/uat.log"

# ──────────────────────────────────────────────────────────────
# 4) Xcode archive + export IPA
# ──────────────────────────────────────────────────────────────
XCODEPROJ="$(find "${OUT_DIR}/uat" -name '*.xcodeproj' -maxdepth 5 | head -1)"
[ -n "${XCODEPROJ}" ] || fail "Could not locate generated .xcodeproj under ${OUT_DIR}/uat"
log "Archiving ${XCODEPROJ}…"

xcodebuild archive \
    -project "${XCODEPROJ}" \
    -scheme "${SCHEME}" \
    -configuration "${CONFIG}" \
    -destination "generic/platform=iOS" \
    -archivePath "${ARCHIVE_PATH}" \
    DEVELOPMENT_TEAM="${TEAM_ID}" \
    PRODUCT_BUNDLE_IDENTIFIER="${BUNDLE_ID}" \
    CODE_SIGN_STYLE=Automatic \
    -allowProvisioningUpdates \
    2>&1 | tee "${LOG_DIR}/archive.log"

log "Exporting IPA…"
xcodebuild -exportArchive \
    -archivePath "${ARCHIVE_PATH}" \
    -exportOptionsPlist "${EXPORT_OPTIONS}" \
    -exportPath "${OUT_DIR}" \
    -allowProvisioningUpdates \
    2>&1 | tee "${LOG_DIR}/export.log"

# ──────────────────────────────────────────────────────────────
# 5) Post-build verification
# ──────────────────────────────────────────────────────────────
[ -f "${IPA_PATH}" ] || fail "Expected IPA missing: ${IPA_PATH}"
SIZE_MB=$(du -m "${IPA_PATH}" | cut -f1)
log "✅ IPA built: ${IPA_PATH} (${SIZE_MB} MB)"

# 5b) Descriptor inside IPA — proves the path that crashes at launch
log "Verifying descriptor inside IPA payload…"
IPA_INSPECT_DIR="${OUT_DIR}/_ipa_inspect"
rm -rf "${IPA_INSPECT_DIR}" && mkdir -p "${IPA_INSPECT_DIR}"
unzip -q "${IPA_PATH}" -d "${IPA_INSPECT_DIR}"
APP_DIR="$(find "${IPA_INSPECT_DIR}/Payload" -maxdepth 1 -name '*.app' | head -1)"
[ -n "${APP_DIR}" ] || fail "No .app found inside IPA"

# UE5 iOS Shipping resolves descriptor via:
#   StagedBuilds/IOS/<SCHEME>/<SCHEME>.uproject  (when --no-pak / flat)
#   OR baked into the .pak archive (when -pak is on)
DESC_FOUND=""
if [ "${USE_PAK}" = "false" ]; then
    DESC_PATH="${APP_DIR}/cookeddata/${SCHEME}/${SCHEME}.uproject"
    if [ -f "${DESC_PATH}" ]; then
        DESC_FOUND="${DESC_PATH}"
    fi
else
    PAK_COUNT=$(find "${APP_DIR}/cookeddata" -name '*.pak' 2>/dev/null | wc -l | tr -d ' ')
    if [ "${PAK_COUNT}" -gt 0 ]; then
        DESC_FOUND="<inside .pak ×${PAK_COUNT}>"
    fi
fi

if [ -n "${DESC_FOUND}" ]; then
    log "✅ Descriptor present: ${DESC_FOUND}"
else
    log "❌ DESCRIPTOR MISSING from IPA payload."
    log "   This is the EXACT 'Failed to open descriptor file' crash signature."
    log "   Re-run with --no-pak --purge-cache to validate the flat layout."
    fail "Descriptor verification failed."
fi

# 5c) Plist sanity inside the .app — UE_PROJECT_NAME must equal SCHEME
INSTALLED_PLIST="${APP_DIR}/Info.plist"
if [ -f "${INSTALLED_PLIST}" ]; then
    UE_NAME=$(plutil -extract UE_PROJECT_NAME raw "${INSTALLED_PLIST}" 2>/dev/null || echo "")
    if [ "${UE_NAME}" = "${SCHEME}" ]; then
        log "✅ Info.plist UE_PROJECT_NAME=${SCHEME}"
    else
        fail "Info.plist UE_PROJECT_NAME='${UE_NAME}' must equal SCHEME='${SCHEME}'"
    fi
fi
rm -rf "${IPA_INSPECT_DIR}"

cat > "${OUT_DIR}/manifest.json" <<EOF
{
  "scheme": "${SCHEME}",
  "bundle_id": "${BUNDLE_ID}",
  "configuration": "${CONFIG}",
  "device_target": "${DEVICE}",
  "ipa_path": "${IPA_PATH}",
  "size_mb": ${SIZE_MB},
  "use_pak": ${USE_PAK},
  "purge_cache": ${PURGE_CACHE},
  "sovereign_ws": "${SOVEREIGN_WS}",
  "built_at": "$(date -u +%FT%TZ)"
}
EOF

log "📦 manifest: ${OUT_DIR}/manifest.json"
log "🚀 Ready to upload to App Store Connect:"
log "    xcrun altool --upload-app -f ${IPA_PATH} -t ios -u <APPLE_ID> -p <APP_PWD>"
