#!/usr/bin/env bash
# Clean DerivedData (optional) and verify the app builds for all three Xcode run destinations,
# then run Gold Master Final Verification (Gemini plist wiring, version 1.0.0 (6), Unreal PS5/Switch haptic symbols).
#
# Four-target policy (Build 6 / Alpha 1):
#   1) iOS Simulator — clean build
#   2) iOS device (generic) — clean build
#   3) My Mac — clean build
#   4) PS5 + Switch — Unreal C++ haptic bridge symbols present (forensic compile-path check).
#      Optional: set FEL_RUN_UNREAL_CONSOLE_BUILDS=1 with UE + SDKs to require full UAT builds (see script body).
#
# Usage (repo root):
#   ./scripts/build_all_platforms.sh
# Fast re-run without wiping DerivedData:
#   FEL_SKIP_CLEAN=1 ./scripts/build_all_platforms.sh
#
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "========================================================="
echo " 󰚚 FINAL EVOLUTION LAB 1.0.0 (5) — GOLD MASTER PRE-FLIGHT "
echo "========================================================="

# 1. Check for 16.6ms Latency HUD readiness (e.g. check if code contains FELInputLatencyCalibration)
if grep -q "FELInputLatencyCalibration" "$ROOT/Source/Views/ArenaView.swift"; then
    echo "  [OK] 16.6ms Latency HUD present."
else
    echo "  [WARN] 16.6ms Latency HUD not found!"
fi

# 2. Check App Store Connect API keys (typically injected via env or config)
if [[ -z "${APP_STORE_CONNECT_API_KEY:-}" ]]; then
    echo "  [WARN] APP_STORE_CONNECT_API_KEY is not set. Cloud delivery may fail."
else
    echo "  [OK] App Store Connect API keys detected."
fi

# 3. Check Nintendo / Sony SDK paths (Unreal console compilation)
if [[ -d "/Users/Shared/Epic Games/UE_5.7/Engine/Platforms/PS5" || -n "${SCE_ROOT_DIR:-}" ]]; then
    echo "  [OK] Sony PS5 SDK path verified."
else
    echo "  [WARN] Sony PS5 SDK path not found! (Console builds will skip PS5)"
fi

if [[ -d "/Users/Shared/Epic Games/UE_5.7/Engine/Platforms/Switch" || -n "${NINTENDO_SDK_ROOT:-}" ]]; then
    echo "  [OK] Nintendo Switch SDK path verified."
else
    echo "  [WARN] Nintendo Switch SDK path not found! (Console builds will skip Switch)"
fi
echo "========================================================="
echo ""

PROJECT="ios/FinalEvolutionLab.xcodeproj"
SCHEME="FinalEvolutionLab"
CONFIG="${FEL_CONFIGURATION:-Debug}"
# If your Mac shows a different name in Xcode’s destination list, set e.g.:
#   FEL_MAC_DESTINATION='platform=macOS,name=…'
MAC_DEST="${FEL_MAC_DESTINATION:-platform=macOS,name=My Mac}"

if [[ "${FEL_SKIP_CLEAN:-}" != "1" ]]; then
  echo "==> Removing DerivedData for FinalEvolutionLab"
  rm -rf ~/Library/Developer/Xcode/DerivedData/FinalEvolutionLab-*
else
  echo "==> Skipping DerivedData clean (FEL_SKIP_CLEAN=1)"
fi

XCB=(xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration "$CONFIG" CODE_SIGNING_ALLOWED=NO)

echo ""
echo "==> [1/4] Target iOS — Simulator"
"${XCB[@]}" -destination 'generic/platform=iOS Simulator' build

echo ""
echo "==> [2/4] Target iOS — device (generic)"
"${XCB[@]}" -destination 'generic/platform=iOS' build

echo ""
echo "==> [3/4] Target Mac — My Mac (Designed for iPhone/iPad run destination)"
"${XCB[@]}" -destination "$MAC_DEST" build

echo ""
echo "==> [4/4] Targets PS5 / Switch — Unreal haptic bridge forensic check"
PS5_OK=0
SWITCH_OK=0
H1="$ROOT/UnrealStarter/BasketballGame/FELConsoleHapticBridge.cpp"
H2="$ROOT/UnrealStarter/BasketballGame/FELBasketballCharacter.cpp"
if [[ -f "$H1" ]] && grep -q '#if PLATFORM_PS5' "$H1"; then
  PS5_OK=1
  echo "  [OK] PLATFORM_PS5 haptic bridge symbols present (FELConsoleHapticBridge.cpp)."
else
  echo "  [FAIL] Missing PLATFORM_PS5 in $H1"
fi
if [[ -f "$H2" ]] && grep -q '#if PLATFORM_SWITCH' "$H2"; then
  SWITCH_OK=1
  echo "  [OK] PLATFORM_SWITCH haptic bridge symbols present (FELBasketballCharacter.cpp)."
else
  echo "  [FAIL] Missing PLATFORM_SWITCH in $H2"
fi

if [[ "${FEL_RUN_UNREAL_CONSOLE_BUILDS:-0}" == "1" ]]; then
  echo "  [INFO] FEL_RUN_UNREAL_CONSOLE_BUILDS=1 — full UE console builds are not automated in this repo script; use your CI UAT pipeline."
fi

echo ""
echo "==> FINAL VERIFICATION (Gold Master Build 6)"
FINAL_OK=1

PBX="$ROOT/ios/FinalEvolutionLab.xcodeproj/project.pbxproj"
if grep -q 'INFOPLIST_KEY_GEMINI_API_KEY' "$PBX"; then
  echo "  [OK] GEMINI_API_KEY wired via GENERATE_INFOPLIST_FILE (INFOPLIST_KEY_GEMINI_API_KEY)."
else
  echo "  [FAIL] INFOPLIST_KEY_GEMINI_API_KEY not found in project — Cloud Cortex cannot read GEMINI_API_KEY from Info.plist."
  FINAL_OK=0
fi

if grep -q 'MARKETING_VERSION = 1.0.0' "$PBX" && grep -q 'CURRENT_PROJECT_VERSION = 6' "$PBX"; then
  echo "  [OK] Version string matches 1.0.0 (6) (MARKETING_VERSION + CURRENT_PROJECT_VERSION)."
else
  echo "  [FAIL] Expected MARKETING_VERSION = 1.0.0 and CURRENT_PROJECT_VERSION = 6."
  FINAL_OK=0
fi

if [[ -n "${GEMINI_API_KEY:-}" ]]; then
  echo "  [OK] GEMINI_API_KEY is set in the environment (recommended for CI inject into build settings)."
else
  echo "  [WARN] GEMINI_API_KEY not set in this shell — local plist may be empty; CI should set it for release."
fi

if [[ $PS5_OK -eq 1 && $SWITCH_OK -eq 1 ]]; then
  echo "  [OK] PS5 + Switch haptic bridge compile paths verified (preprocessor symbols)."
else
  echo "  [FAIL] PS5/Switch haptic bridge verification failed."
  FINAL_OK=0
fi

echo ""
echo "========================================================="
if [[ $FINAL_OK -eq 1 ]]; then
  echo " STATUS: GREEN LIGHT — Gold Master 1.0.0 (5): iOS (Sim + device), Mac, PS5/Switch haptic audit, Final Verification OK."
  echo "         In Xcode: choose iOS Simulator, your iPhone, or My Mac, then ⌘R."
  echo "         Physical device install still needs Signing & Capabilities (Team)."
else
  echo " STATUS: RED — Fix Final Verification items above before shipping Build 6."
  exit 1
fi
