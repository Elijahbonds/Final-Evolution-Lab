#!/usr/bin/env bash
# =============================================================================
# fel_ue5_win64_cook_only.sh
# Final Evolution Lab — **Mac as Win64 “content factory”** (M4 Pro, etc.).
#
# Runs Epic **RunUAT.sh BuildCookRun** so Venice Beach / gameplay content is **cooked
# for Windows** on your machine; proprietary source stays local. Final **.exe packaging**
# is still done on a **Windows** host or VM — this script does not build the Win64 binary.
#
# Prerequisites:
#   - Epic **macOS** UE 5.7 with the **Windows target platform (cook support)** installed
#     — this is **not** “package on Mac”; it is the **Launcher add-on** that lets the
#     editor **cook for Win64** from macOS.
#     (Launcher → Library → UE 5.7 → ⋯ → Options → Target Platforms → **Windows**).
#   - **UPROJECT** optional: absolute path to `.uproject`. If unset, tries (1) repo
#     `UnrealStarter/.../FinalEvolutionLab.uproject`, (2) auto-find
#     `**/FinalEvolutionLab 5.7/FinalEvolutionLab.uproject` under `~/Documents` and `~/UnrealProjects`.
#   - Merge Config/DefaultEngine.pixelstreaming2.snippet.ini into DefaultEngine.ini
#     so Pixel Streaming 2 / WebRTC defaults are baked into the cook.
#
# Outputs:
#   artifacts/Cooked_Win64/          — staged Win64 cooked data (+ Pixel Streaming WebServers tree)
#
# Usage:
#   export UE_ROOT="/Users/Shared/Epic Games/UE_5.7"
#   UPROJECT="/path/to/FinalEvolutionLab.uproject" ./fel_ue5_win64_cook_only.sh
#   SKIP_BUILD=0 ./fel_ue5_win64_cook_only.sh    # omit -skipbuild (often fails on Mac for Win64 exe)
#   ./fel_ue5_win64_cook_only.sh --verify-only
#
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"

# PROJECT_DIR / UPROJECT / DEFAULT_ENGINE are set in resolve_project_paths().
# Do not initialize UPROJECT here — it would override UPROJECT passed from the environment.
LEGACY_UPROJECT="$REPO_ROOT/UnrealStarter/BasketballGame/FinalEvolutionLab.uproject"
SNIPPET_TEMPLATE_REPO="$REPO_ROOT/UnrealStarter/BasketballGame/Config/DefaultEngine.pixelstreaming2.snippet.ini"

COOK_ARTIFACT="${COOK_ARTIFACT:-$REPO_ROOT/artifacts/Cooked_Win64}"
# Default 1 = content-only workflow (`-skipbuild`). Set SKIP_BUILD=0 to try compiling Win64 from Mac (usually unsupported).
SKIP_BUILD="${SKIP_BUILD:-1}"

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
    die "Set UPROJECT to your .uproject (absolute path), or place the project under ~/Documents or ~/UnrealProjects. Example:
  UPROJECT=\"/Users/you/UnrealProjects/FinalEvolutionLab/FinalEvolutionLab.uproject\" ./fel_ue5_win64_cook_only.sh"
  fi
  [[ -f "$chosen" ]] || die "UPROJECT not found: $chosen"
  PROJECT_DIR="$(cd "$(dirname "$chosen")" && pwd)"
  UPROJECT="$PROJECT_DIR/$(basename "$chosen")"
  DEFAULT_ENGINE="$PROJECT_DIR/Config/DefaultEngine.ini"
  local snippet_proj="$PROJECT_DIR/Config/DefaultEngine.pixelstreaming2.snippet.ini"
  if [[ -z "${PIXEL_SNIPPET:-}" ]]; then
    if [[ -f "$snippet_proj" ]]; then
      PIXEL_SNIPPET="$snippet_proj"
    elif [[ -f "$SNIPPET_TEMPLATE_REPO" ]]; then
      PIXEL_SNIPPET="$SNIPPET_TEMPLATE_REPO"
    else
      PIXEL_SNIPPET="$snippet_proj"
    fi
  fi
}

# Epic may install RunUAT at .../UE_5.7/Engine/... or nested .../UE_5.7/Engine/UE_5.7/Engine/...
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
  $UE_ROOT/Engine/Build/BatchFiles/  nor  $UE_ROOT/Engine/UE_5.7/Engine/Build/BatchFiles/
Fix UE_ROOT or omit it to use auto-detection."
  fi
  local flat="/Users/Shared/Epic Games/UE_5.7"
  resolve_runuat_engine_root "$flat" && return 0
  echo ""
}

verify_project_paths() {
  [[ -f "$UPROJECT" ]] || die "Missing .uproject (clone or sync Unreal project): $UPROJECT"
  [[ -f "$DEFAULT_ENGINE" ]] || die "Missing DefaultEngine.ini: $DEFAULT_ENGINE"
}

verify_pixel_streaming_plugin() {
  echo ">>> Checking $(basename "$UPROJECT") for Pixel Streaming plugin..."
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
    print("FAIL: Enable PixelStreaming (or PixelStreaming2) in .uproject Plugins.", file=sys.stderr)
    sys.exit(1)
print("OK: Pixel Streaming plugin enabled in .uproject")
PY
}

verify_default_engine_pixel_streaming() {
  echo ">>> Checking DefaultEngine.ini for Pixel Streaming WebRTC / encoder CVars..."
  if ! grep -qE "(PixelStreaming2|PixelStreaming)\.(WebRTC|Encoder)" "$DEFAULT_ENGINE"; then
    echo "WARN: DefaultEngine.ini has no PixelStreaming(2).WebRTC* / PixelStreaming(2).Encoder* lines."
    echo "      Append contents of: $PIXEL_SNIPPET"
    die "Fix DefaultEngine.ini (merge pixelstreaming2 snippet) and re-run."
  fi
  echo "OK: DefaultEngine.ini references PixelStreaming WebRTC/encoder settings"
  grep -n "PixelStreaming" "$DEFAULT_ENGINE" | head -25 || true
}

verify_windows_target_installed() {
  local ue_root="$1"
  [[ -d "$ue_root/Engine/Platforms/Windows" ]] || die \
    "This UE engine does not include the **Windows** platform tree (missing Engine/Platforms/Windows).
On macOS, enable **Windows** target for your Mac engine in Epic Launcher → UE 5.7 → ⋯ → Options → Target Platforms → Windows."
  local modules="$ue_root/Engine/Binaries/Mac/UnrealEditor.modules"
  [[ -f "$modules" ]] || die "Missing $modules (is UE_ROOT the engine root?)"
  if ! grep -q "WindowsTargetPlatform" "$modules"; then
    die "The **Windows target platform** (for **cooking** Win64 content from macOS) is not installed — no WindowsTargetPlatform in UnrealEditor.modules.
This is separate from packaging a **.exe** on Windows: you still need Epic’s **Windows** add-on on the Mac so RunUAT can cook for Win64 locally.
• Epic Games Launcher → Unreal Engine 5.7.x → **Library** → your 5.7 install **⋯** → **Options** → enable **Windows (64-bit)** and finish the download."
  fi
  echo ">>> OK: Windows Target Platform modules present — Win64 cooks can run from this Mac engine."
}

verify_ue_is_mac_engine() {
  local ue_root="$1"
  [[ -d "$ue_root/Engine/Binaries/Mac" ]] || die \
    "UE_ROOT does not look like a **macOS** Unreal Engine (missing Engine/Binaries/Mac): $ue_root"
}

run_verify() {
  verify_project_paths
  verify_pixel_streaming_plugin
  verify_default_engine_pixel_streaming
  [[ -f "$PIXEL_SNIPPET" ]] || echo "WARN: snippet missing (optional reference only): $PIXEL_SNIPPET"

  local ue_root
  ue_root="$(detect_ue_root)"
  if [[ -n "$ue_root" ]]; then
    verify_ue_is_mac_engine "$ue_root"
    verify_windows_target_installed "$ue_root"
  else
    echo "WARN: UE_ROOT not auto-detected (install UE 5.7 or set UE_ROOT). Skipping Win64 engine pre-check."
  fi

  echo ""
  echo "=== Pre-flight verification: PASSED ==="
}

bundle_pixel_streaming_webservers() {
  local dest="$COOK_ARTIFACT/PixelStreaming_WebServers"
  mkdir -p "$COOK_ARTIFACT"

  if [[ -d "$PROJECT_DIR/Samples/PixelStreaming/WebServers" ]]; then
    rm -rf "$dest"
    cp -a "$PROJECT_DIR/Samples/PixelStreaming/WebServers" "$dest"
    echo ">>> Staged project Pixel Streaming WebServers (Signalling, scripts) → $dest"
    return 0
  fi

  local ue_root="$1"
  local engine_ps="${ue_root}/Engine/Plugins/Media/PixelStreaming"
  if [[ -d "${engine_ps}/Resources/WebServers" ]]; then
    rm -rf "$dest"
    cp -a "${engine_ps}/Resources/WebServers" "$dest"
    echo ">>> Staged engine Pixel Streaming WebServers → $dest"
    return 0
  fi
  if [[ -d "${engine_ps}/WebServers" ]]; then
    rm -rf "$dest"
    cp -a "${engine_ps}/WebServers" "$dest"
    echo ">>> Staged engine Pixel Streaming WebServers → $dest"
    return 0
  fi

  echo "WARN: No WebServers folder found under project Samples or Engine PixelStreaming plugin."
  echo "      Install the Pixel Streaming infrastructure or copy SignallingWebServer manually for your host."
}

sync_staged_if_engine_ignored_custom_path() {
  # Some UAT builds ignore -stagingdirectory; mirror the default Win64 staged tree so artifacts are complete.
  local default_stage="$PROJECT_DIR/Saved/StagedBuilds/WindowsNoEditor"
  if [[ -d "$default_stage" ]]; then
    mkdir -p "$COOK_ARTIFACT"
    rsync -a "$default_stage/" "$COOK_ARTIFACT/_staged_FromSaved_StagedBuilds_WindowsNoEditor/"
    echo ">>> Mirrored Saved/StagedBuilds/WindowsNoEditor → $COOK_ARTIFACT/_staged_FromSaved_StagedBuilds_WindowsNoEditor/"
  fi
}

verify_staged_pixel_streaming_ini() {
  local root="$COOK_ARTIFACT"
  [[ -d "$root" ]] || die "Artifact directory missing: $root"

  echo ">>> Checking staged/cooked tree for Pixel Streaming (UE 5.7) settings in .ini files..."
  local f found=""
  while IFS= read -r f; do
    [[ -f "$f" ]] || continue
    if grep -qE "(PixelStreaming2|PixelStreaming)\.(WebRTC|Encoder)" "$f" 2>/dev/null; then
      echo "OK: Pixel Streaming WebRTC / encoder CVars appear in staged config:"
      echo "    $f"
      grep -n "PixelStreaming" "$f" | head -25 || true
      found=1
      break
    fi
  done < <(find "$root" -type f \( -iname '*.ini' \) 2>/dev/null | head -400)

  if [[ -z "$found" ]]; then
    die "No staged .ini under $root contains PixelStreaming(2).WebRTC / PixelStreaming(2).Encoder.
Your project DefaultEngine.ini (with the snippet merged) may not have been folded into this cook output.
Re-merge $PIXEL_SNIPPET into $DEFAULT_ENGINE and re-run the cook."
  fi
}

verify_cooked_maps_venice_and_zen_dojo() {
  local root="$COOK_ARTIFACT"
  [[ -d "$root" ]] || die "Artifact directory missing: $root"

  local paths
  paths="$(find "$root" 2>/dev/null | head -40000 || true)"

  echo "$paths" | grep -qi 'venice' || die \
    "Verification failed: no path matching **Venice** (Venice Beach) under $root"

  if echo "$paths" | grep -qiE 'zendojo|zen[._-]?dojo'; then
    :
  elif echo "$paths" | grep -i 'zen' | grep -qi 'dojo'; then
    :
  else
    die "Verification failed: no path matching **Zen Dojo** (try ZenDojo / Zen_Dojo map naming) under $root"
  fi

  echo ""
  echo "=== Map spot-check OK: Venice Beach + Zen Dojo markers found in staged/cooked tree ==="
  echo "    (Sample paths — includes .pak / folder names)"
  find "$root" -type f 2>/dev/null | grep -i 'venice' | head -3 || true
  find "$root" -type f 2>/dev/null | grep -iE 'zendojo|zen|dojo' | head -6 || true
}

cook_win64_stage_only() {
  local ue_root
  ue_root="$(detect_ue_root)"
  [[ -n "$ue_root" ]] || die "UE_ROOT not found. Install UE 5.7 (with Windows target) or set UE_ROOT."

  verify_ue_is_mac_engine "$ue_root"
  verify_windows_target_installed "$ue_root"

  local runuat="$ue_root/Engine/Build/BatchFiles/RunUAT.sh"
  [[ -f "$runuat" ]] || die "RunUAT not found: $runuat"

  rm -rf "$COOK_ARTIFACT"
  mkdir -p "$COOK_ARTIFACT"

  local staging_internal="$COOK_ARTIFACT/_internal_staging"
  mkdir -p "$staging_internal"

  echo ">>> RunUAT BuildCookRun — Win64 cook + stage + archive (content factory; all maps)..."
  echo "    Engine root: $ue_root"
  echo "    Archive / golden folder: $COOK_ARTIFACT"

  # -platform=Win64  (UAT spelling for Win64 content; not -targetplatform=)
  # -cook -stage -archive -archivedirectory  (hand-off folder for Windows packaging machine)
  # -skipbuild: default on Mac so we do not try to compile the Win64 game binary here (set SKIP_BUILD=0 to attempt)
  # -allmaps: cook every map (all game modes that have levels in the project)
  local -a uat_args=(
    BuildCookRun
    -project="$UPROJECT"
    -noP4
    -platform=Win64
    -clientconfig=Shipping
    -cook
    -stage
    -archive
    -archivedirectory="$COOK_ARTIFACT"
    -stagingdirectory="$staging_internal"
    -allmaps
    -utf8output
  )
  if [[ "$SKIP_BUILD" == "1" ]]; then
    uat_args+=( -skipbuild )
  fi

  "$runuat" "${uat_args[@]}"

  rm -rf "$staging_internal"

  sync_staged_if_engine_ignored_custom_path
  bundle_pixel_streaming_webservers "$ue_root"
  verify_staged_pixel_streaming_ini
  verify_cooked_maps_venice_and_zen_dojo

  local cook_abs
  cook_abs="$(cd "$COOK_ARTIFACT" && pwd)"

  echo ""
  echo "=== WIN64 COOK + STAGE + ARCHIVE OK (content factory) ==="
  echo "Golden folder (absolute path — copy to a Windows PC/VM for the final package / upload to your stream host):"
  echo "  $cook_abs"
  du -sh "$cook_abs" 2>/dev/null || true
}

main() {
  resolve_project_paths
  run_verify
  if [[ "$VERIFY_ONLY" == true ]]; then
    echo "(--verify-only: skipping RunUAT)"
    exit 0
  fi
  cook_win64_stage_only
}

main "$@"
