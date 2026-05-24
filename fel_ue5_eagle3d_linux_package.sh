#!/usr/bin/env bash
# =============================================================================
# ⚠️  DEPRECATED — This script is for E3DS cloud streaming builds only.
# The project has pivoted to native local builds (IPA/APK).
# Use fel_ue5_ios_shipping_package.sh for iOS native builds instead.
# Kept for reference. See docs/STREAMING_TO_LOCAL_AUDIT.md for details.
# =============================================================================
# fel_ue5_eagle3d_linux_package.sh
# Eagle 3D (E3DS) — **Linux Shipping** streamer build from **macOS** (M4 Pro, etc.).
#
# Why Linux on a Mac: Epic does not ship a full **Windows cross-compile** stack for macOS the way
# it does for **Linux**. For sovereign/local workflows without a Windows PC, **Linux Target +
# RunUAT -platform=Linux** is the standard cloud-streaming path (Pixel Streaming on Linux hosts).
#
# Prerequisites (macOS host running this script):
#   - Epic **macOS** UE 5.7 with **Linux Target Platform** installed
#     (Launcher → Library → UE 5.7 → ⋯ → Options → enable **Linux**).
#   - **Linux cross-compilation toolchain** for your engine version (Clang toolchain Epic documents
#     for UE 5.x — install so UBT can produce Linux binaries from Darwin).
#     https://dev.epicgames.com/documentation/unreal-engine/linux-development-requirements-for-unreal-engine
#   - If UBT cannot find the Linux compiler after installing the toolchain, set (example):
#       export LINUX_MULTIARCH_ROOT="/absolute/path/to/v22_clang-...-centos7"
#     Use the folder Epic documents for **your** UE 5.7 patch; this script exports it into RunUAT when set.
#   - Do **not** set UE_ROOT to a Linux-only engine tarball on the Mac — RunUAT must be the **Mac**
#     engine; Engine/Platforms/Linux must exist inside it.
#
# Outputs:
#   artifacts/Linux/FEL_UE5_E3DS_Linux_Package.zip   — upload to E3DS Control Panel (override with ZIP_OUT)
#   artifacts/Linux/eagle3d_build/                   — RunUAT -archive tree before zip
#
# Emergent / FELEmergentBridgeSubsystem: uses UE **WebSockets** + **Json** — supported on Linux
# Shipping builds (no Windows-specific APIs in that bridge).
#
# Usage:
#   export UE_ROOT="/Users/Shared/Epic Games/UE_5.7"
#   export LINUX_MULTIARCH_ROOT="/path/to/epic-linux-toolchain"   # optional, if UBT asks for clang
#   ./fel_ue5_eagle3d_linux_package.sh
#   UPROJECT="/path/to/FinalEvolutionLab.uproject" ./fel_ue5_eagle3d_linux_package.sh --verify-only
#
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"

LEGACY_UPROJECT="$REPO_ROOT/UnrealStarter/BasketballGame/FinalEvolutionLab.uproject"
LINUX_ARTIFACT_ROOT="${LINUX_ARTIFACT_ROOT:-$REPO_ROOT/artifacts/Linux}"
ARCHIVE_PARENT="${ARCHIVE_PARENT:-$LINUX_ARTIFACT_ROOT/eagle3d_build}"
ZIP_OUT="${ZIP_OUT:-$LINUX_ARTIFACT_ROOT/FEL_UE5_E3DS_Linux_Package.zip}"

VERIFY_ONLY=false
for arg in "$@"; do
  [[ "$arg" == "--verify-only" ]] && VERIFY_ONLY=true
done

die() { echo "ERROR: $*" >&2; exit 1; }

discover_fel_uproject() {
  local p base
  for base in "${HOME}/Documents" "${HOME}/UnrealProjects"; do
    [[ -d "$base" ]] || continue
    p="$(find "$base" -path '*/FinalEvolutionLab 5.7/FinalEvolutionLab.uproject' 2>/dev/null | head -1)"
    [[ -n "$p" && -f "$p" ]] && { echo "$p"; return 0; }
  done
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

verify_pixel_streaming_plugin() {
  echo ">>> Checking $(basename "$UPROJECT") for Pixel Streaming (v1 and/or v2)..."
  export UPROJECT_PATH="$UPROJECT"
  python3 << 'PY' || die "uproject parse failed"
import json, sys, os
path = os.environ["UPROJECT_PATH"]
with open(path) as f:
    d = json.load(f)
plugins = d.get("Plugins") or []
names = {p.get("Name") for p in plugins}
ok = ("PixelStreaming" in names or "PixelStreaming2" in names) and any(
    (p.get("Name") in ("PixelStreaming", "PixelStreaming2") and p.get("Enabled", False))
    for p in plugins
)
if not ok:
    print("FAIL: Enable PixelStreaming and/or PixelStreaming2 in .uproject Plugins.", file=sys.stderr)
    sys.exit(1)
print("OK: Pixel Streaming plugin(s) enabled for Linux streamer build")
PY
}

verify_default_engine_ini() {
  echo ">>> Checking DefaultEngine.ini for Pixel Streaming WebRTC / encoder CVars..."
  [[ -f "$DEFAULT_ENGINE" ]] || die "Missing $DEFAULT_ENGINE"
  if ! grep -qE "(PixelStreaming2|PixelStreaming)\.(WebRTC|Encoder)|PixelStreaming2\.AutoStartStream" "$DEFAULT_ENGINE"; then
    die "DefaultEngine.ini should contain PixelStreaming(2) encoder/WebRTC or PixelStreaming2.AutoStartStream.
Merge repo: UnrealStarter/BasketballGame/Config/DefaultEngine.pixelstreaming2.snippet.ini"
  fi
  echo "OK: DefaultEngine.ini references Pixel Streaming settings"
  grep -nE "PixelStreaming2|PixelStreaming\." "$DEFAULT_ENGINE" | head -30 || true
}

warn_emergent_bridge_sources() {
  local src="$PROJECT_DIR/Source"
  if [[ -d "$src" ]] && grep -rqs "FELEmergentBridgeSubsystem\|WebSockets" "$src" 2>/dev/null; then
    echo ">>> OK: Project Source mentions Emergent bridge / WebSockets — confirm module lists WebSockets + Json in *.Build.cs for Linux."
  else
    echo "WARN: Copy UnrealIntegration/* bridge sources into $src (see UnrealIntegration/COPY_INTO_GAME_MODULE.txt) before relying on ws:// scoring on Linux."
  fi
}

verify_linux_ps_notes() {
  echo ">>> Linux Pixel Streaming runtime (Eagle VM / container — manual):"
  echo "    - Vulkan ICD + libvulkan1 (+ vendor drivers)"
  echo "    - Launch streamer per Eagle docs; FELEmergentBridgeSubsystem uses plain UE WebSockets (Linux-safe)."
}

verify_ue_matches_host_os() {
  local ue_root="$1"
  case "$(uname -s)" in
    Darwin)
      if [[ ! -d "$ue_root/Engine/Binaries/Mac" ]]; then
        die "UE_ROOT must be the **macOS** Epic engine on this Mac (Engine/Binaries/Mac missing).

Do not point UE_ROOT at a Linux-only engine zip. Enable **Linux Target** on your Mac UE install."
      fi
      ;;
    Linux)
      if [[ ! -d "$ue_root/Engine/Binaries/Linux" ]]; then
        die "UE_ROOT does not look like a Linux Unreal Engine: $ue_root"
      fi
      ;;
  esac
}

verify_engine_linux_target() {
  local ue_root="$1"
  [[ -d "$ue_root/Engine/Platforms/Linux" ]] || die \
    "Missing Engine/Platforms/Linux — enable **Linux** target for your UE 5.7 install (Launcher → Library → UE 5.7 → ⋯ → Options).

Install Epic’s **Linux cross-compilation toolchain** for your engine version (Clang) so UBT can link Linux from macOS:
https://dev.epicgames.com/documentation/unreal-engine/linux-development-requirements-for-unreal-engine"
  echo ">>> OK: Engine/Platforms/Linux present — UAT can target Linux from this host."
}

bundle_pixel_streaming_webservers() {
  local ue_root="$1"
  local dest="$ARCHIVE_PARENT/PixelStreaming_WebServers"
  mkdir -p "$ARCHIVE_PARENT"

  if [[ -d "$PROJECT_DIR/Samples/PixelStreaming/WebServers" ]]; then
    rm -rf "$dest"
    cp -a "$PROJECT_DIR/Samples/PixelStreaming/WebServers" "$dest"
    echo ">>> Bundled project PixelStreaming WebServers → $dest"
    return 0
  fi

  for engine_ps in \
    "${ue_root}/Engine/Plugins/Media/PixelStreaming2" \
    "${ue_root}/Engine/Plugins/Media/PixelStreaming"
  do
    if [[ -d "${engine_ps}/Resources/WebServers" ]]; then
      rm -rf "$dest"
      cp -a "${engine_ps}/Resources/WebServers" "$dest"
      echo ">>> Bundled engine Pixel Streaming WebServers → $dest"
      return 0
    fi
    if [[ -d "${engine_ps}/WebServers" ]]; then
      rm -rf "$dest"
      cp -a "${engine_ps}/WebServers" "$dest"
      echo ">>> Bundled engine Pixel Streaming WebServers → $dest"
      return 0
    fi
  done

  local legacy="$REPO_ROOT/UnrealStarter/BasketballGame/Samples/PixelStreaming/WebServers"
  if [[ -d "$legacy" ]]; then
    rm -rf "$dest"
    cp -a "$legacy" "$dest"
    echo ">>> Bundled repo template WebServers → $dest"
    return 0
  fi

  echo "WARN: No PixelStreaming WebServers folder found — add Samples or use engine plugin Resources/WebServers."
}

package_linux_shipping() {
  local ue_root
  ue_root="$(detect_ue_root)"
  [[ -n "$ue_root" ]] || die "UE_ROOT not found. export UE_ROOT=\"/Users/Shared/Epic Games/UE_5.7\" or install UE 5.7."

  local runuat="$ue_root/Engine/Build/BatchFiles/RunUAT.sh"
  [[ -f "$runuat" ]] || die "RunUAT not found: $runuat"

  verify_ue_matches_host_os "$ue_root"
  verify_engine_linux_target "$ue_root"

  rm -rf "$ARCHIVE_PARENT"
  mkdir -p "$ARCHIVE_PARENT"

  echo ">>> RunUAT BuildCookRun — Linux Shipping (Pixel Streaming streamer for E3DS)..."
  echo "    Project: $UPROJECT"
  echo "    Archive: $ARCHIVE_PARENT"
  if [[ -n "${LINUX_MULTIARCH_ROOT:-}" ]]; then
    export LINUX_MULTIARCH_ROOT
    echo ">>> LINUX_MULTIARCH_ROOT=$LINUX_MULTIARCH_ROOT"
  fi

  "$runuat" BuildCookRun \
    -project="$UPROJECT" \
    -noP4 \
    -platform=Linux \
    -clientconfig=Shipping \
    -cook \
    -allmaps \
    -build \
    -stage \
    -pak \
    -archive \
    -archivedirectory="$ARCHIVE_PARENT" \
    -prereqs \
    -compressed \
    -utf8output

  bundle_pixel_streaming_webservers "$ue_root"

  mkdir -p "$(dirname "$ZIP_OUT")"
  rm -f "$ZIP_OUT"
  echo ">>> Zipping → $ZIP_OUT"
  (cd "$ARCHIVE_PARENT" && zip -r -q "$ZIP_OUT" .) || die "zip failed"

  local abs_zip
  abs_zip="$(cd "$(dirname "$ZIP_OUT")" && pwd)/$(basename "$ZIP_OUT")"
  echo ""
  echo "=== LINUX E3DS PACKAGE OK ==="
  echo "Upload for Eagle 3D Control Panel:"
  echo "  $abs_zip"
  echo "Size: $(du -h "$abs_zip" | cut -f1)"
  echo "Extracted archive tree: $ARCHIVE_PARENT"
}

run_verify() {
  resolve_project_paths
  [[ -f "$UPROJECT" ]] || die "Missing .uproject"
  [[ -f "$DEFAULT_ENGINE" ]] || die "Missing DefaultEngine.ini — $DEFAULT_ENGINE"

  verify_pixel_streaming_plugin
  verify_default_engine_ini
  warn_emergent_bridge_sources
  verify_linux_ps_notes

  local ue_root
  ue_root="$(detect_ue_root)"
  if [[ -n "$ue_root" ]]; then
    verify_ue_matches_host_os "$ue_root"
    if [[ "$VERIFY_ONLY" == true ]]; then
      if [[ -d "$ue_root/Engine/Platforms/Linux" ]]; then
        echo ">>> OK: Engine/Platforms/Linux present."
      else
        echo "WARN: Engine/Platforms/Linux missing — enable Linux target + toolchain before full package (verify-only continues)."
      fi
    else
      verify_engine_linux_target "$ue_root"
    fi
  else
    echo "WARN: UE_ROOT not detected — set UE_ROOT for engine checks."
  fi

  echo ""
  echo "=== Pre-flight verification: PASSED ==="
}

main() {
  run_verify
  if [[ "$VERIFY_ONLY" == true ]]; then
    echo "(--verify-only: skipping RunUAT)"
    exit 0
  fi
  package_linux_shipping
}

main "$@"
