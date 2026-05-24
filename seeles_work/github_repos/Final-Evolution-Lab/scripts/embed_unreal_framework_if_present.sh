#!/usr/bin/env bash
# Mirrors the inline script in FinalEvolutionLab.xcodeproj (Embed Unreal Framework phase).
# Use this from CI if you prefer invoking a file instead of duplicating the Run Script.
# Copies UnrealFramework.framework into the app bundle when present under
# FinalEvolutionLab/EmbeddedFrameworks/ (Swift + Unreal container shipping path).
set -euo pipefail

SRC="${SRCROOT}/FinalEvolutionLab/EmbeddedFrameworks/UnrealFramework.framework"
DEST_DIR="${TARGET_BUILD_DIR}/${WRAPPER_NAME}/Frameworks"
FW_NAME="UnrealFramework"

if [[ ! -d "$SRC" ]]; then
  echo "note: Unreal framework not found at ${SRC} — skipping embed (expected until UE exports the framework)."
  exit 0
fi

mkdir -p "${DEST_DIR}"
rm -rf "${DEST_DIR}/UnrealFramework.framework"
cp -R "${SRC}" "${DEST_DIR}/"

FW_BIN="${DEST_DIR}/${FW_NAME}.framework/${FW_NAME}"
if [[ -f "${FW_BIN}" ]]; then
  echo "UnrealFramework binary: ${FW_BIN}"
  echo "Architectures before strip: $(/usr/bin/lipo -archs "${FW_BIN}" 2>/dev/null || echo "unknown")"

  # Phase 7: Strip simulator slices from device builds.
  # UE exports often produce fat binaries; shipping x86_64 in an iPhoneOS framework breaks App Store validation.
  if [[ "${PLATFORM_NAME:-}" == "iphoneos" ]]; then
    for arch in x86_64 i386; do
      if /usr/bin/lipo -info "${FW_BIN}" 2>/dev/null | /usr/bin/grep -q "${arch}"; then
        echo "Stripping ${arch} slice for iphoneos…"
        /usr/bin/lipo -remove "${arch}" -output "${FW_BIN}" "${FW_BIN}" || true
      fi
    done
  fi

  echo "Architectures after strip:  $(/usr/bin/lipo -archs "${FW_BIN}" 2>/dev/null || echo "unknown")"
else
  echo "warning: UnrealFramework binary not found at ${FW_BIN} (unexpected framework layout)."
fi

if [[ -n "${EXPANDED_CODE_SIGN_IDENTITY:-}" && "${EXPANDED_CODE_SIGN_IDENTITY}" != "-" ]]; then
  /usr/bin/codesign --force --sign "${EXPANDED_CODE_SIGN_IDENTITY}" \
    --timestamp=none \
    --preserve-metadata=identifier,entitlements,flags \
    --generate-entitlement-der \
    "${DEST_DIR}/UnrealFramework.framework"
  echo "embedded and codesigned UnrealFramework.framework → ${DEST_DIR}"
else
  echo "embedded UnrealFramework.framework (no codesign identity — typical for some simulator runs)"
fi
