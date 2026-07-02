#!/usr/bin/env bash
# =============================================================================
# fel_ue5_mac_package.sh
# Final Evolution Lab — **native macOS packaging** (cook + stage + archive + zip).
#
# Runs Epic **RunUAT.sh BuildCookRun** to build, cook, and package a native standalone
# macOS client (.app bundle) on this machine. Compress it into a standalone .zip
# and stage it directly into the frontend public downloads directory.
#
# Prerequisites:
#   - Epic **macOS** UE 5.7 installed at `/Users/Shared/Epic Games/UE_5.7`.
#   - Xcode installed and configured.
#   - **UPROJECT** absolute path to `.uproject`. If unset, auto-discovers under
#     `~/Developer/FinalEvolutionLab57` or the workspace folder.
#
# Outputs:
#   artifacts/Mac_Shipping/          — staged macOS shipping build
#   frontend/public/downloads/FinalEvolutionLab_Mac.zip — local downloadable archive
#
# Usage:
#   export UE_ROOT="/Users/Shared/Epic Games/UE_5.7"
#   ./fel_ue5_mac_package.sh
#   ./fel_ue5_mac_package.sh --verify-only
#   ./fel_ue5_mac_package.sh --full-cook
#
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
PROJECT_NAME="FinalEvolutionLab"

LEGACY_UPROJECT="$REPO_ROOT/UnrealStarter/BasketballGame/FinalEvolutionLab.uproject"
MAC_ARCHIVE="${MAC_ARCHIVE:-$REPO_ROOT/artifacts/Mac_Shipping}"
ZIP_OUT="${ZIP_OUT:-$REPO_ROOT/frontend/public/downloads/FinalEvolutionLab_Mac.zip}"
MAC_CLIENTCONFIG="${MAC_CLIENTCONFIG:-Shipping}"

VERIFY_ONLY=false
FULL_COOK=false
VERBOSE_UAT=false
for arg in "$@"; do
  [[ "$arg" == "--verify-only" ]] && VERIFY_ONLY=true
  [[ "$arg" == "--full-cook" ]] && FULL_COOK=true
  [[ "$arg" == "--verbose" ]] && VERBOSE_UAT=true
done

die() { echo "ERROR: $*" >&2; exit 1; }

discover_fel_uproject() {
  local p base
  local fixed="${HOME}/Developer/FinalEvolutionLab57/FinalEvolutionLab.uproject"
  [[ -f "$fixed" ]] && { echo "$fixed"; return 0; }
  for base in "${HOME}/Documents" "${HOME}/UnrealProjects"; do
    [[ -d "$base" ]] || continue
    p="$(find "$base" -path '*/FinalEvolutionLab 5.7/FinalEvolutionLab.uproject' 2>/dev/null | head -1)"
    [[ -n "$p" && -f "$p" ]] && { echo "$p"; return 0; }
  done
  echo ""
}

resolve_runuat_engine_root() {
  local cand="$1"
  if [[ -f "${cand}/Engine/Build/BatchFiles/RunUAT.sh" ]]; then
    echo "$cand"
    return 0
  fi
  if [[ -f "${cand}/Engine/UE_5.7/Engine/Build/BatchFiles/RunUAT.sh" ]]; then
    echo "${cand}/Engine/UE_5.7"
    return 0
  fi
  return 1
}

detect_ue_root() {
  if [[ -n "${UE_ROOT:-}" ]]; then
    resolve_runuat_engine_root "$UE_ROOT" && return 0
    die "UE_ROOT is set but RunUAT.sh was not found under:
  $UE_ROOT/Engine/Build/BatchFiles/  nor  $UE_ROOT/Engine/UE_5.7/Engine/Build/BatchFiles/"
  fi
  local flat="/Users/Shared/Epic Games/UE_5.7"
  resolve_runuat_engine_root "$flat" && return 0
  echo ""
}

resolve_project_paths() {
  local chosen="${UPROJECT:-}"
  if [[ -z "$chosen" ]]; then
    if [[ -f "$LEGACY_UPROJECT" ]]; then
      chosen="$LEGACY_UPROJECT"
    else
      chosen="$(discover_fel_uproject)"
    fi
  fi
  if [[ -z "$chosen" ]]; then
    die "Set UPROJECT to your .uproject (absolute path), or place FinalEvolutionLab under ~/Documents or ~/UnrealProjects."
  fi
  [[ -f "$chosen" ]] || die "UPROJECT not found: $chosen"
  PROJECT_DIR="$(cd "$(dirname "$chosen")" && pwd)"
  UPROJECT="$PROJECT_DIR/$(basename "$chosen")"
  DEFAULT_ENGINE="$PROJECT_DIR/Config/DefaultEngine.ini"
  DEFAULT_GAME="$PROJECT_DIR/Config/DefaultGame.ini"
}

verify_project_paths() {
  [[ -f "$UPROJECT" ]] || die "Missing .uproject: $UPROJECT"
  [[ -f "$DEFAULT_ENGINE" ]] || die "Missing DefaultEngine.ini: $DEFAULT_ENGINE"
}

verify_ue_is_mac_engine() {
  local ue_root="$1"
  [[ -d "$ue_root/Engine/Binaries/Mac" ]] || die "UE_ROOT is not a macOS engine: $ue_root"
}

verify_mac_target_installed() {
  local ue_root="$1"
  [[ -f "$ue_root/Engine/Binaries/Mac/UnrealEditor-MacTargetPlatform.dylib" ]] || die \
    "Missing Engine/Binaries/Mac/UnrealEditor-MacTargetPlatform.dylib — check your UE 5.7 installation."
  echo ">>> OK: Mac target platform payload present."
}

run_verify() {
  verify_project_paths
  local ue_root
  ue_root="$(detect_ue_root)"
  if [[ -n "$ue_root" ]]; then
    verify_ue_is_mac_engine "$ue_root"
    verify_mac_target_installed "$ue_root"
  else
    echo "WARN: UE_ROOT not auto-detected. Skipping engine pre-check."
  fi
  echo "=== macOS Pre-flight verification: PASSED ==="
}

package_mac_standalone() {
  local ue_root
  ue_root="$(detect_ue_root)"
  [[ -n "$ue_root" ]] || die "UE_ROOT not found. export UE_ROOT=\"/Users/Shared/Epic Games/UE_5.7\""

  local runuat="$ue_root/Engine/Build/BatchFiles/RunUAT.sh"
  [[ -f "$runuat" ]] || die "RunUAT not found: $runuat"

  rm -rf "$MAC_ARCHIVE"
  mkdir -p "$MAC_ARCHIVE"

  local staging_internal="$MAC_ARCHIVE/_internal_staging"
  mkdir -p "$staging_internal"

  echo ">>> RunUAT BuildCookRun — macOS Standalone (**build** + cook + stage + archive)..."
  echo "    Project: $UPROJECT"
  echo "    Archive: $MAC_ARCHIVE"
  echo "    Configuration: $MAC_CLIENTCONFIG"

  if [[ "$FULL_COOK" == "true" ]]; then
    echo ">>> --full-cook: cleaning Saved cook/stage caches."
    rm -rf "$PROJECT_DIR/Saved" "$PROJECT_DIR/DerivedDataCache" 2>/dev/null || true
  fi

  local -a uat_args=(
    BuildCookRun
    -project="$UPROJECT"
    -noP4
    -platform=Mac
    -clientconfig="$MAC_CLIENTCONFIG"
    -build
    -cook
    -allmaps
    -stage
    -archive
    -archivedirectory="$MAC_ARCHIVE"
    -stagingdirectory="$staging_internal"
    -utf8output
  )
  if [[ "$VERBOSE_UAT" == "true" ]]; then
    uat_args+=( -verbose )
  fi
  if [[ "$FULL_COOK" == "true" ]]; then
    uat_args+=( -clean )
  fi

  # Ensure resource-fork detritus is avoided:
  export COPYFILE_DISABLE=1

  "$runuat" "${uat_args[@]}"

  rm -rf "$staging_internal"

  # Find packaged .app bundle
  local app_bundle=""
  local cand
  while IFS= read -r cand; do
    [[ -d "$cand" ]] && app_bundle="$cand"
  done < <(find "$MAC_ARCHIVE" -maxdepth 3 -name "*.app" -type d 2>/dev/null)

  if [[ -z "$app_bundle" ]]; then
    die "Could not find packaged macOS .app bundle under $MAC_ARCHIVE"
  fi

  echo ">>> Packaged macOS bundle found: $app_bundle"

  # Stage zip output in frontend downloads
  mkdir -p "$(dirname "$ZIP_OUT")"
  rm -f "$ZIP_OUT"

  echo ">>> Compressing macOS standalone application with ditto..."
  local app_dir
  app_dir="$(dirname "$app_bundle")"
  local app_name
  app_name="$(basename "$app_bundle")"

  (
    cd "$app_dir"
    ditto -c -k --sequesterRsrc --keepParent "$app_name" "$ZIP_OUT"
  )

  echo ">>> Staged macOS zip package directly under frontend downloads:"
  echo "    $ZIP_OUT"
  du -sh "$ZIP_OUT"
}

main() {
  resolve_project_paths
  run_verify
  if [[ "$VERIFY_ONLY" == true ]]; then
    echo "(--verify-only: skipping RunUAT)"
    exit 0
  fi
  package_mac_standalone
}

main "$@"
