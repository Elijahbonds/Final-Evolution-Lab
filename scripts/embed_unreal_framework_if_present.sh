#!/usr/bin/env bash
# Mirrors the inline script in FinalEvolutionLab.xcodeproj (Embed Unreal Framework phase).
# Use this from CI if you prefer invoking a file instead of duplicating the Run Script.
# Copies UnrealFramework.framework into the app bundle when present under
# FinalEvolutionLab/EmbeddedFrameworks/ (Swift + Unreal container shipping path).
set -euo pipefail

SRC="${SRCROOT}/FinalEvolutionLab/EmbeddedFrameworks/UnrealFramework.framework"
DEST_DIR="${TARGET_BUILD_DIR}/${WRAPPER_NAME}/Frameworks"

if [[ ! -d "$SRC" ]]; then
  echo "note: Unreal framework not found at ${SRC} — skipping embed (expected until UE exports the framework)."
  exit 0
fi

mkdir -p "${DEST_DIR}"
rm -rf "${DEST_DIR}/UnrealFramework.framework"
cp -R "${SRC}" "${DEST_DIR}/"

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
