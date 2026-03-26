#!/usr/bin/env bash
# Gold Master — Mac Shipping .app via RunUAT + compressed Sovereign Lab .dmg (UDZO).
# Prereqs: Xcode, UE 5.7+, Shipping C++ game target, clinical venue .umap present.
#
# Shipping / no debug symbols:
#   - RunUAT: -clientconfig=Shipping -serverconfig=Shipping -nodebuginfo
#   - Config/DefaultGame.ini: BuildConfiguration=PPBC_Shipping, IncludeDebugFiles=False, ForDistribution=True
#
# Universal binary (arm64 + x86_64):
#   - Config/DefaultEngine.ini → [/Script/MacTargetPlatform.MacTargetSettings] TargetArchitecture=MacTargetArchitectureUniversal
#   - Distribution cook (ForDistribution=True) uses universal slices per Epic UBT.
#
# One command (from anywhere):
#   bash "/path/to/UnrealStarter/BasketballGame/Scripts/package_gold_master_mac_shipping.sh"
#
# Optional env overrides:
#   UE_ROOT, OUT_DIR, DMG_NAME, PROJECT_FILE
#   FEL_MAC_UNIVERSAL=1  →  pass -ClientArchitecture=arm64+x86_64 to UAT (requires Xcode toolchain;
#                          verify with `lipo -archs` on Contents/MacOS executable — expect arm64 x86_64).
#   FEL_REQUIRE_UNIVERSAL=1  →  exit non-zero if the game binary is not multi-arch (after lipo check).
#
# Phase 8 — notarization (Developer ID + hardened runtime on the .app; see DefaultEngine.ini signing):
#   FEL_NOTARIZE=1  and  FEL_NOTARY_KEYCHAIN_PROFILE=<notarytool keychain profile name>
#   Runs: xcrun notarytool submit <dmg> --keychain-profile … --wait  then  xcrun stapler staple <dmg>
#
# Mac mini / fixed archive root (example):
#   export OUT_DIR="$HOME/FEL_Builds/GoldMaster_Mac_Shipping"
#   bash .../package_gold_master_mac_shipping.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GAME_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
export UE_ROOT="${UE_ROOT:-/Users/Shared/Epic Games/UE_5.7}"
UAT="${UE_ROOT}/Engine/Build/BatchFiles/RunUAT.sh"
export PROJECT_FILE="${PROJECT_FILE:-${GAME_DIR}/FinalEvolutionLab.uproject}"
export OUT_DIR="${OUT_DIR:-${GAME_DIR}/Saved/Archive/GoldMaster_Mac_Shipping}"
# Upload to Supabase bucket sovereign-assets (path mac/<DMG_NAME> — keep in sync with sites/.../downloads.ts).
DMG_NAME="${DMG_NAME:-SovereignLab_1.0_Gold.dmg}"
# Staged game target name matches UBT game target (FinalEvolutionLab), not display ProjectName.
GAME_TARGET="FinalEvolutionLab"

if [[ ! -x "${UAT}" ]]; then
  echo "RunUAT not found: ${UAT} — set UE_ROOT" >&2
  exit 1
fi
if [[ ! -f "${PROJECT_FILE}" ]]; then
  echo ".uproject not found: ${PROJECT_FILE}" >&2
  exit 1
fi

mkdir -p "${OUT_DIR}"

UAT_EXTRA=()
if [[ "${FEL_MAC_UNIVERSAL:-0}" == "1" ]]; then
  UAT_EXTRA+=("-ClientArchitecture=arm64+x86_64")
  echo "=== FEL_MAC_UNIVERSAL=1 → requesting arm64+x86_64 client binary ==="
fi

echo "=== BuildCookRun Mac Shipping (maps from DefaultGame.ini MapsToCook) ==="
"${UAT}" BuildCookRun \
  -project="${PROJECT_FILE}" \
  -noP4 \
  -platform=Mac \
  -clientconfig=Shipping \
  -serverconfig=Shipping \
  -cook \
  -build \
  -stage \
  -pak \
  -compressed \
  -archive \
  -archivedirectory="${OUT_DIR}" \
  -prereqs \
  -nodebuginfo \
  "${UAT_EXTRA[@]}"

# UE 5.7 + Modern Xcode often stages "${GAME_TARGET}-Mac-Shipping.app"; older layouts use "${GAME_TARGET}.app".
APP_PATH="${OUT_DIR}/Mac/${GAME_TARGET}.app"
if [[ ! -d "${APP_PATH}" ]]; then
  APP_PATH="${OUT_DIR}/Mac/${GAME_TARGET}-Mac-Shipping.app"
fi
if [[ ! -d "${APP_PATH}" ]]; then
  APP_PATH="${OUT_DIR}/MacNoEditor/${GAME_TARGET}.app"
fi
if [[ ! -d "${APP_PATH}" ]]; then
  APP_PATH="${OUT_DIR}/MacNoEditor/${GAME_TARGET}-Mac-Shipping.app"
fi
if [[ ! -d "${APP_PATH}" ]]; then
  echo "Packaged .app not found under ${OUT_DIR}/Mac or .../MacNoEditor (expected ${GAME_TARGET}.app or ${GAME_TARGET}-Mac-Shipping.app)" >&2
  exit 1
fi

MACOS_BIN="${APP_PATH}/Contents/MacOS/${GAME_TARGET}"
if [[ ! -x "${MACOS_BIN}" ]]; then
  MACOS_BIN="$(find "${APP_PATH}/Contents/MacOS" -maxdepth 1 -type f -perm -111 2>/dev/null | head -1)"
fi
ARCH_WORDS=0
if [[ -n "${MACOS_BIN}" && -x "${MACOS_BIN}" ]]; then
  echo "=== Mach-O architectures (Universal = arm64 + x86_64) ==="
  if command -v lipo >/dev/null 2>&1; then
    ARCHS="$(lipo -archs "${MACOS_BIN}" 2>/dev/null || true)"
    echo "${ARCHS}"
    ARCH_WORDS="$(echo "${ARCHS}" | wc -w | tr -d ' ')"
    if [[ "${ARCH_WORDS}" -lt 2 ]]; then
      echo "Note: single-architecture binary. Re-run with FEL_MAC_UNIVERSAL=1 for fat binary, or build on CI with both slices." >&2
    fi
  else
    echo "(lipo not in PATH — skip arch check)" >&2
  fi
else
  echo "Warning: could not locate executable under ${APP_PATH}/Contents/MacOS for lipo check" >&2
fi
if [[ "${FEL_REQUIRE_UNIVERSAL:-0}" == "1" ]]; then
  if ! command -v lipo >/dev/null 2>&1; then
    echo "ERROR: FEL_REQUIRE_UNIVERSAL=1 requires lipo (Xcode CLT)." >&2
    exit 1
  fi
  if [[ -z "${MACOS_BIN}" || ! -x "${MACOS_BIN}" ]] || [[ "${ARCH_WORDS}" -lt 2 ]]; then
    echo "ERROR: FEL_REQUIRE_UNIVERSAL=1 but game binary is not multi-arch (got ${ARCH_WORDS} slice(s)). Try FEL_MAC_UNIVERSAL=1." >&2
    exit 1
  fi
fi

DMG_OUT="${OUT_DIR}/${DMG_NAME}"
echo "=== hdiutil UDZO → ${DMG_OUT} ==="
rm -f "${DMG_OUT}"
hdiutil create -volname "Sovereign Lab" -srcfolder "${APP_PATH}" -ov -format UDZO "${DMG_OUT}"

if [[ "${FEL_NOTARIZE:-0}" == "1" ]]; then
  if [[ -z "${FEL_NOTARY_KEYCHAIN_PROFILE:-}" ]]; then
    echo "ERROR: FEL_NOTARIZE=1 requires FEL_NOTARY_KEYCHAIN_PROFILE (see: xcrun notarytool --help; Apple TN3147 for API keys)." >&2
    exit 1
  fi
  echo "=== notarytool submit + stapler → ${DMG_OUT} ==="
  xcrun notarytool submit "${DMG_OUT}" --keychain-profile "${FEL_NOTARY_KEYCHAIN_PROFILE}" --wait
  xcrun stapler staple "${DMG_OUT}"
  echo "=== staple OK (Gatekeeper-ready DMG) ==="
fi

echo "Done. Upload to Supabase: sovereign-assets/mac/${DMG_NAME}"
echo "  ${DMG_OUT}"
