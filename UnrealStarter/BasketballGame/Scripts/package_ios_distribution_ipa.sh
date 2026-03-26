#!/usr/bin/env bash
# Final Evolution Lab — iOS Shipping cook + archive (.ipa path depends on signing).
# Prereqs: UE 5.7, Xcode, Apple dev account, iOS provisioning in Unreal / Xcode.
#
# After RunUAT, use Xcode Organizer to export Ad Hoc / Enterprise .ipa if the
# automated path does not produce a signed IPA for OTA.
#
#   bash "/path/to/Scripts/package_ios_distribution_ipa.sh"
#
# Optional: UE_ROOT, OUT_DIR, PROJECT_FILE

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GAME_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
export UE_ROOT="${UE_ROOT:-/Users/Shared/Epic Games/UE_5.7}"
UAT="${UE_ROOT}/Engine/Build/BatchFiles/RunUAT.sh"
export PROJECT_FILE="${PROJECT_FILE:-${GAME_DIR}/FinalEvolutionLab.uproject}"
export OUT_DIR="${OUT_DIR:-${GAME_DIR}/Saved/Archive/IOS_Distribution_Shipping}"

if [[ ! -x "${UAT}" ]]; then
  echo "RunUAT not found: ${UAT} — set UE_ROOT" >&2
  exit 1
fi
if [[ ! -f "${PROJECT_FILE}" ]]; then
  echo ".uproject not found: ${PROJECT_FILE}" >&2
  exit 1
fi

mkdir -p "${OUT_DIR}"

echo "=== BuildCookRun iOS Shipping + Distribution signing (Ad Hoc / App Store–style Distribution cert) ==="
"${UAT}" BuildCookRun \
  -project="${PROJECT_FILE}" \
  -noP4 \
  -platform=IOS \
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
  -distribution

IOS_BIN="${GAME_DIR}/Binaries/IOS"
echo "=== Normalizing OTA filename → ${OUT_DIR}/FinalEvolutionLab.ipa ==="
IPA_FOUND=""
if [[ -d "${IOS_BIN}" ]]; then
  IPA_FOUND="$(find "${IOS_BIN}" -maxdepth 1 -name "*.ipa" -type f | head -1 || true)"
fi
if [[ -n "${IPA_FOUND}" ]]; then
  cp -f "${IPA_FOUND}" "${OUT_DIR}/FinalEvolutionLab.ipa"
  echo "Copied: ${IPA_FOUND}"
  echo "  → ${OUT_DIR}/FinalEvolutionLab.ipa"
else
  echo "No .ipa found under ${IOS_BIN} — open Xcode project from Intermediate/ProjectFilesIOS, Archive, and export Distribution .ipa, then copy to ${OUT_DIR}/FinalEvolutionLab.ipa" >&2
fi

echo "=== Done. Upload public IPA to Supabase: sovereign-assets/ios/FinalEvolutionLab.ipa ==="
