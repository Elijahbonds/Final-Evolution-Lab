#!/usr/bin/env bash
# =============================================================================
# fel_ue5_ios_shipping_package.sh
# Final Evolution Lab — **native iOS Shipping** (cook + stage + archive) on Apple Silicon.
#
# 1) Ensures Xcode-friendly project files exist (GenerateProjectFiles).
# 2) RunUAT BuildCookRun for **iOS Shipping** with cook / all maps / stage / archive.
# 3) Checks Bundle Identifier + reminds you about signing / provisioning (Xcode / Apple Developer).
#
# Prerequisites:
#   - Xcode installed; **Xcode → Settings → Accounts**: sign in with Apple ID (personal **Team** is OK for
#     on-device testing; paid Apple Developer Program required for App Store / wider distribution).
#   - **Signing:** After GenerateProjectFiles, open **FinalEvolutionLab (IOS).xcworkspace** → target
#     **FinalEvolutionLab** → **Signing & Capabilities** → select **Team** and enable **Automatically manage
#     signing**. Set **Bundle Identifier** in UE (Project Settings → iOS) so it matches the provisioning profile.
#     Cursor/CLI cannot apply your Team ID without that UI step or matching UE iOS settings.
#   - UE 5.7 macOS engine with **iOS** target support (Launcher → UE 5.7 → Options → iOS).
#   - Project **Bundle Identifier** set (Project Settings → iOS, or Config/DefaultGame.ini).
#
# Optional:
#   IOS_CLIENTCONFIG=Development   # local device builds with Development provisioning (default: Shipping)
#   IOS_DEVELOPMENT_TEAM=XXXXXXXXXX   # optional: writes CodeSigningTeam + IOSTeamID into Config before GPF/RunUAT so UE
#       regeneration picks up the same Team ID (RunUAT re-runs the Xcode generator and would otherwise restore ini values).
# Epic’s Xcode generator reads signing from **DefaultEngine.ini**:
#   [/Script/MacTargetPlatform.XcodeProjectSettings]
#   bUseAutomaticCodeSigning=True
#   CodeSigningTeam=<10-char Team ID>
#   BundleIdentifier=com.yourcompany.yourapp
#   CodeSigningPrefix=com.yourcompany
# (IOSTeamID alone is not what fills DEVELOPMENT_TEAM in xcconfig — use CodeSigningTeam.)
#
# Usage:
#   export UE_ROOT="/Users/Shared/Epic Games/UE_5.7"
#   ./fel_ue5_ios_shipping_package.sh
#   ./fel_ue5_ios_shipping_package.sh --open-xcode   # regenerate + open iOS workspace (signing / archive in Xcode)
#   UPROJECT="/path/to/FinalEvolutionLab.uproject" ./fel_ue5_ios_shipping_package.sh --verify-only
#
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"

LEGACY_UPROJECT="$REPO_ROOT/UnrealStarter/BasketballGame/FinalEvolutionLab.uproject"
METAL_SNIPPET_REPO="$REPO_ROOT/UnrealStarter/BasketballGame/Config/DefaultEngine.ios_metal_mobile.snippet.ini"
PACKAGING_SNIPPET_REPO="$REPO_ROOT/UnrealStarter/BasketballGame/Config/DefaultGame.packaging_metalar_workaround.snippet.ini"

IOS_ARCHIVE="${IOS_ARCHIVE:-$REPO_ROOT/artifacts/IOS_Shipping_Archive}"
IOS_CLIENTCONFIG="${IOS_CLIENTCONFIG:-Shipping}"
SKIP_GENERATE="${SKIP_GENERATE:-0}"
# Set to 1 only if you intentionally keep Share Material Shader Code enabled (metal-ar may still fail on Xcode 26).
SKIP_SHARE_SHADER_CHECK="${SKIP_SHARE_SHADER_CHECK:-0}"

VERIFY_ONLY=false
OPEN_XCODE_ONLY=false
for arg in "$@"; do
  [[ "$arg" == "--verify-only" ]] && VERIFY_ONLY=true
  [[ "$arg" == "--open-xcode" ]] && OPEN_XCODE_ONLY=true
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
    die "Set UPROJECT to your .uproject file, or place FinalEvolutionLab under ~/Documents or ~/UnrealProjects."
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
  [[ -f "$DEFAULT_GAME" ]] || echo "WARN: Missing DefaultGame.ini (create in Editor or Config/)."
}

verify_ue_is_mac_engine() {
  local ue_root="$1"
  [[ -d "$ue_root/Engine/Binaries/Mac" ]] || die "UE_ROOT is not a macOS engine: $ue_root"
}

verify_ios_target_installed() {
  local ue_root="$1"
  [[ -d "$ue_root/Engine/Platforms/IOS" ]] || die "Missing Engine/Platforms/IOS — enable **iOS** for this engine in Epic Launcher → UE 5.7 → Options."
  [[ -f "$ue_root/Engine/Binaries/Mac/IOS/UnrealEditor-IOSTargetPlatform.dylib" ]] || die \
    "iOS Target Platform binaries missing under Engine/Binaries/Mac/IOS. Re-install or repair UE 5.7 iOS components."
  echo ">>> OK: iOS target platform payload present."
}

verify_bundle_identifier_configured() {
  echo ">>> Checking Config for iOS Bundle Identifier..."
  local found=""
  if [[ -f "$DEFAULT_GAME" ]] && grep -qE '^[^;]*BundleIdentifier=' "$DEFAULT_GAME"; then
    grep -n 'BundleIdentifier' "$DEFAULT_GAME" | grep -v '^;' | head -8 || true
    found=1
  fi
  if [[ -f "$DEFAULT_ENGINE" ]] && grep -qE '^[^;]*BundleIdentifier=' "$DEFAULT_ENGINE" 2>/dev/null; then
    echo "    (DefaultEngine.ini)"
    grep -n 'BundleIdentifier' "$DEFAULT_ENGINE" | grep -v '^;' | head -8 || true
    found=1
  fi
  shopt -s nullglob
  local extra
  for extra in "$PROJECT_DIR"/Config/{IOS,DefaultGame}.ini "$PROJECT_DIR"/Config/Mobile/*.ini; do
    [[ -f "$extra" ]] || continue
    if grep -qE '^[^;]*BundleIdentifier=' "$extra" 2>/dev/null; then
      echo "    (also in $extra)"
      grep -n 'BundleIdentifier' "$extra" | grep -v '^;' | head -8 || true
      found=1
    fi
  done
  shopt -u nullglob
  [[ -n "$found" ]] || echo "WARN: No BundleIdentifier= found in scanned .ini files. Set it in Editor → Project Settings → Platforms → iOS → Bundle Information."
  echo ">>> Provisioning: map **Signing Certificate** + **Provisioning Profile** in Xcode (generated project) or UE iOS settings to your Apple Developer team."
}

warn_if_metal_snippet_not_merged() {
  [[ -f "$METAL_SNIPPET_REPO" ]] || return 0
  if [[ -f "$DEFAULT_ENGINE" ]] && grep -q 'r.Streaming.PoolSize' "$DEFAULT_ENGINE" 2>/dev/null; then
    echo ">>> DefaultEngine.ini appears to include mobile streaming pool / Metal-related CVars."
    return 0
  fi
  echo "WARN: For Metal/mobile tuning (iPhone 15/16 Pro class), merge optional snippet into DefaultEngine.ini:"
  echo "      $METAL_SNIPPET_REPO"
}

# Xcode 26 + cryptex Metal toolchain: metal-ar can fail (?C); disabling shared shader code skips metallib archive.
verify_share_material_shader_code_for_metalar() {
  [[ "$SKIP_SHARE_SHADER_CHECK" == "1" ]] && echo "(SKIP_SHARE_SHADER_CHECK=1 — not checking bShareMaterialShaderCode)" && return 0
  [[ -f "$DEFAULT_GAME" ]] || {
    echo "WARN: Missing $DEFAULT_GAME — create it or merge snippet so bShareMaterialShaderCode=False can be set."
    echo "      $PACKAGING_SNIPPET_REPO"
    return 0
  }
  if grep -qiE '^[[:space:]]*bShareMaterialShaderCode[[:space:]]*=[[:space:]]*true' "$DEFAULT_GAME"; then
    die "DefaultGame.ini sets bShareMaterialShaderCode=True. Your cook fails at metal-ar / shared Metallib on this macOS+Xcode combo.

Fix: Project Settings → Packaging → **Share Material Shader Code** → OFF, or merge into DefaultGame.ini:
  $PACKAGING_SNIPPET_REPO
(Re-run this script afterward.)"
  fi
  if grep -qiE '^[[:space:]]*bShareMaterialShaderCode[[:space:]]*=[[:space:]]*false' "$DEFAULT_GAME"; then
    echo ">>> OK: bShareMaterialShaderCode=False (metal-ar shared-library archive skipped)."
  else
    echo "WARN: DefaultGame.ini does not set bShareMaterialShaderCode=False. If cook fails with metal-ar / ?C, merge:"
    echo "      $PACKAGING_SNIPPET_REPO"
  fi
}

generate_xcode_project_files() {
  local ue_root="$1"
  local gen="$ue_root/Engine/Build/BatchFiles/Mac/GenerateProjectFiles.sh"
  [[ -f "$gen" ]] || die "GenerateProjectFiles.sh not found: $gen"
  echo ">>> GenerateProjectFiles.sh (-game) for Xcode / toolchain..."
  "$gen" -project="$UPROJECT" -game
}

# RunUAT regenerates Intermediate/.../Xcconfig from DefaultEngine.ini — pre-RunUAT xcconfig edits alone are not enough.
sync_ios_team_into_project_config() {
  local team="${IOS_DEVELOPMENT_TEAM:-}"
  [[ -n "$team" ]] || return 0
  if [[ ! "$team" =~ ^[A-Z0-9]{10}$ ]]; then
    echo "WARN: IOS_DEVELOPMENT_TEAM should be a 10-character Team ID; skipping Config sync."
    return 0
  fi
  local f
  for f in "$DEFAULT_ENGINE" "$DEFAULT_GAME"; do
    [[ -f "$f" ]] || continue
    if grep -qE '^CodeSigningTeam=' "$f" 2>/dev/null; then
      sed -i '' -E "s/^CodeSigningTeam=.*/CodeSigningTeam=$team/" "$f"
      echo ">>> Synced CodeSigningTeam=$team in $(basename "$f")"
    fi
    if grep -qE '^IOSTeamID=' "$f" 2>/dev/null; then
      sed -i '' -E "s/^IOSTeamID=.*/IOSTeamID=$team/" "$f"
      echo ">>> Synced IOSTeamID=$team in $(basename "$f")"
    fi
  done
}

# UE leaves DEVELOPMENT_TEAM blank in FinalEvolutionLab.xcconfig until set in Editor / Xcode — optional env injection.
patch_ios_xcconfig_development_team() {
  local team="${IOS_DEVELOPMENT_TEAM:-}"
  [[ -n "$team" ]] || return 0
  if [[ ! "$team" =~ ^[A-Z0-9]{10}$ ]]; then
    echo "WARN: IOS_DEVELOPMENT_TEAM should be the 10-character Team ID (letters/digits), not your email."
  fi
  # RunUAT/xcodebuild use Intermediate/ProjectFiles/... (not only ProjectFilesIOS/). Patch every iOS xcconfig copy.
  local xc n=0
  while IFS= read -r xc; do
    [[ -f "$xc" ]] || continue
    if grep -qE '^DEVELOPMENT_TEAM *= *' "$xc"; then
      sed -i '' "s/^DEVELOPMENT_TEAM *= *.*/DEVELOPMENT_TEAM = $team/" "$xc"
      echo ">>> Patched DEVELOPMENT_TEAM=$team in: $xc"
      n=$((n + 1))
    fi
  done < <(find "$PROJECT_DIR/Intermediate" -path '*/XcconfigsIOS/FinalEvolutionLab.xcconfig' 2>/dev/null)
  if [[ "$n" -eq 0 ]]; then
    echo "WARN: No XcconfigsIOS/FinalEvolutionLab.xcconfig found under $PROJECT_DIR/Intermediate — run GenerateProjectFiles first."
  fi
}

# UE sometimes leaves TargetAttributes without DevelopmentTeam; xcodebuild then ignores empty xcconfig. Patch pbxproj.
patch_ios_pbxproj_development_team() {
  local team="${IOS_DEVELOPMENT_TEAM:-}"
  [[ -n "$team" ]] || return 0
  export TEAM="$team"
  local pb
  while IFS= read -r pb; do
    [[ -f "$pb" ]] || continue
    if grep -q 'DevelopmentTeam = ' "$pb" 2>/dev/null; then
      perl -i -pe 's/DevelopmentTeam = [A-Z0-9]+;/DevelopmentTeam = $ENV{TEAM};/g' "$pb"
      echo ">>> Updated DevelopmentTeam=$team in: $pb"
    elif grep -q 'ProvisioningStyle = Automatic;' "$pb"; then
      perl -i -0777 -pe '
        if (!/DevelopmentTeam = /) {
          s/(\t\t\t\t\t[0-9A-F]{24} = \{\n)(\t+)(ProvisioningStyle = Automatic;)/$1$2DevelopmentTeam = $ENV{TEAM};\n$2$3/g;
        }
      ' "$pb"
      echo ">>> Patched TargetAttributes DevelopmentTeam in: $pb"
    fi
  done < <(find "$PROJECT_DIR/Intermediate" -path '*/FinalEvolutionLab (IOS).xcodeproj/project.pbxproj' 2>/dev/null)
}

# UE iOS Xcode project: (1) Copy Runnable rsyncs staged data; (2) strip/ThinApp runs after Copy. Either can leave xattrs;
# codesign then fails (“resource fork … detritus”). Append xattr -cr after Copy and again after ThinApp (RunUAT may regen pbxproj).
patch_ios_pbxproj_copy_phase_xattr_strip() {
  local pb
  while IFS= read -r pb; do
    [[ -f "$pb" ]] || continue
    python3 - "$pb" <<'PY'
import pathlib, sys
pb = pathlib.Path(sys.argv[1])
text0 = pb.read_text(encoding="utf-8")
text = text0

# --- A) Copy Runnable phase (SRC_EXE…) ---
start_mark = 'shellScript = "set -eo pipefail\\nSRC_EXE'
start = text.find(start_mark)
if start >= 0:
    start_body = start + len('shellScript = "')
    i = start_body
    while i < len(text):
        if text[i] == "\\":
            i += 2
            continue
        if text[i] == '"' and text[i + 1 : i + 3] == ";\n":
            end_quote = i
            break
        i += 1
    else:
        end_quote = -1
    if end_quote > 0:
        body = text[start_body:end_quote]
        if not ("xattr -cr" in body and "CONTENTS_FOLDER_PATH" in body):
            suffix = '\\nxattr -cr \\"${CONFIGURATION_BUILD_DIR}/${CONTENTS_FOLDER_PATH}\\" 2>/dev/null || true'
            text = text[:start_body] + body + suffix + text[end_quote:]

# --- B) Strip / ThinApp phase (runs after Copy, before CodeSign) ---
thin_tail = '\"${UE_ENGINE_DIR}/Build/BatchFiles/Mac/ThinApp.sh\" \"${CONFIGURATION_BUILD_DIR}/${CONTENTS_FOLDER_PATH}\" \"${CONFIGURATION_BUILD_DIR}/${EXECUTABLE_PATH}\"'
if thin_tail in text:
    j = text.find(thin_tail)
    snippet = text[j : j + 420]
    if "xattr -cr" not in snippet:
        sfx = '\\nxattr -cr \\"${CONFIGURATION_BUILD_DIR}/${CONTENTS_FOLDER_PATH}\\" 2>/dev/null || true'
        text = text.replace(thin_tail, thin_tail + sfx, 1)

if text != text0:
    pb.write_text(text, encoding="utf-8")
    print(">>> Patched iOS pbxproj xattr strips (Copy + ThinApp phases):", pb)
PY
  done < <(find "$PROJECT_DIR/Intermediate" -path '*/FinalEvolutionLab (IOS).xcodeproj/project.pbxproj' 2>/dev/null)
}

# RunUAT regenerates FinalEvolutionLab (IOS).xcodeproj mid-build (UBT calls xcodebuild via an absolute path; PATH hooks do not run).
# While RunUAT is running, we periodically re-apply the Copy-phase xattr strip so the materialized Script-*.sh contains xattr -cr before CodeSign.
IOS_XATTR_PATCH_PID=""

cleanup_ios_xattr_patch_loop() {
  if [[ -n "${IOS_XATTR_PATCH_PID:-}" ]]; then
    kill "$IOS_XATTR_PATCH_PID" 2>/dev/null || true
    wait "$IOS_XATTR_PATCH_PID" 2>/dev/null || true
    unset IOS_XATTR_PATCH_PID
  fi
}

warn_ios_icloud_path_may_break_codesign() {
  case "$PROJECT_DIR" in
  */Documents/Documents\ -\ *)
    echo "WARN: UE project appears to live under iCloud-linked “Documents …” folders."
    echo "      Builds there often pick up com.apple.provenance metadata that codesign rejects (“detritus”)."
    echo "      Prefer cloning the project to a non-synced directory (e.g. ~/UnrealProjects/FinalEvolutionLab 5.7)."
    ;;
  esac
}

start_ios_xattr_patch_loop() {
  cleanup_ios_xattr_patch_loop
  export PROJECT_DIR
  export -f patch_ios_pbxproj_copy_phase_xattr_strip
  (
    set +e
    while true; do
      patch_ios_pbxproj_copy_phase_xattr_strip
      sleep "${IOS_XATTR_PATCH_INTERVAL:-0.35}"
    done
  ) &
  IOS_XATTR_PATCH_PID=$!
}

# Opens the UE-generated iOS Xcode workspace (Signing & Capabilities lives here).
open_ios_workspace_in_xcode() {
  local ws="$PROJECT_DIR/FinalEvolutionLab (IOS).xcworkspace"
  [[ -d "$ws" ]] || die "iOS workspace not found (run GenerateProjectFiles first): $ws"
  echo ">>> Opening in Xcode:"
  echo "    $ws"
  open -a Xcode "$ws"
}

# After RunUAT, confirm the staged iOS .app has a real Info.plist (invalid/empty bundle if signing failed).
verify_ios_app_bundle_plist() {
  local dir="$PROJECT_DIR/Binaries/IOS"
  [[ -d "$dir" ]] || {
    echo "WARN: No Binaries/IOS yet — $dir"
    return 0
  }
  local app
  app="$(find "$dir" -maxdepth 1 -name '*.app' -type d 2>/dev/null | head -1)"
  [[ -n "$app" ]] || {
    echo "WARN: No .app bundle found under $dir"
    return 0
  }
  if [[ -f "$app/Info.plist" ]] && [[ -s "$app/Info.plist" ]]; then
    echo ">>> OK: Bundle Info.plist present: $app/Info.plist"
    if command -v /usr/libexec/PlistBuddy >/dev/null 2>&1; then
      /usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$app/Info.plist" 2>/dev/null \
        && echo "    (CFBundleIdentifier printed above)"
    fi
  else
    echo "WARN: Info.plist missing or empty — Xcode signing likely did not finalize: $app"
    echo "      Open FinalEvolutionLab (IOS).xcworkspace → Signing & Capabilities → Team, then re-run or use --open-xcode."
  fi
}

run_ios_shipping_archive() {
  local ue_root="$1"
  verify_ue_is_mac_engine "$ue_root"
  verify_ios_target_installed "$ue_root"

  local runuat="$ue_root/Engine/Build/BatchFiles/RunUAT.sh"
  [[ -f "$runuat" ]] || die "RunUAT not found: $runuat"

  if [[ "$SKIP_GENERATE" != "1" ]]; then
    sync_ios_team_into_project_config
    generate_xcode_project_files "$ue_root"
    patch_ios_xcconfig_development_team
    patch_ios_pbxproj_development_team
    patch_ios_pbxproj_copy_phase_xattr_strip
  else
    echo "(SKIP_GENERATE=1 — skipping GenerateProjectFiles)"
    sync_ios_team_into_project_config
    patch_ios_xcconfig_development_team
    patch_ios_pbxproj_development_team
    patch_ios_pbxproj_copy_phase_xattr_strip
  fi

  rm -rf "$IOS_ARCHIVE"
  mkdir -p "$IOS_ARCHIVE"
  local staging_internal="$IOS_ARCHIVE/_internal_staging"
  mkdir -p "$staging_internal"

  echo ">>> RunUAT BuildCookRun — iOS **$IOS_CLIENTCONFIG** (**build** + cook + stage + archive)..."
  echo "    Archive directory: $IOS_ARCHIVE"
  echo "    (First iOS compile can take many minutes — leave Terminal open.)"
  [[ "$IOS_CLIENTCONFIG" == "Development" ]] && echo "    (Development config — common for local device install / personal team.)"

  warn_ios_icloud_path_may_break_codesign

  start_ios_xattr_patch_loop
  trap 'cleanup_ios_xattr_patch_loop' RETURN

  # Avoid Finder/resource-fork metadata in staged bundles (codesign rejects “detritus”).
  export COPYFILE_DISABLE=1
  if [[ -d "$PROJECT_DIR/Binaries/IOS" ]]; then
    xattr -cr "$PROJECT_DIR/Binaries/IOS" 2>/dev/null || true
  fi

  "$runuat" BuildCookRun \
    -project="$UPROJECT" \
    -noP4 \
    -platform=iOS \
    -clientconfig="$IOS_CLIENTCONFIG" \
    -build \
    -cook \
    -allmaps \
    -stage \
    -archive \
    -archivedirectory="$IOS_ARCHIVE" \
    -stagingdirectory="$staging_internal" \
    -utf8output

  rm -rf "$staging_internal"

  trap - RETURN
  cleanup_ios_xattr_patch_loop

  verify_ios_app_bundle_plist

  local abs
  abs="$(cd "$IOS_ARCHIVE" && pwd)"
  echo ""
  echo "=== iOS $IOS_CLIENTCONFIG ARCHIVE COMPLETE ==="
  echo "Absolute path (install via Xcode Organizer / Devices, or distribute per your workflow):"
  echo "  $abs"
  du -sh "$abs" 2>/dev/null || true
}

run_verify() {
  resolve_project_paths
  verify_project_paths
  verify_share_material_shader_code_for_metalar
  verify_bundle_identifier_configured
  warn_if_metal_snippet_not_merged

  local ue_root
  ue_root="$(detect_ue_root)"
  [[ -n "$ue_root" ]] || die "UE_ROOT not found. export UE_ROOT=/Users/Shared/Epic Games/UE_5.7 or install UE 5.7."
  verify_ue_is_mac_engine "$ue_root"
  verify_ios_target_installed "$ue_root"

  echo ""
  echo "=== Pre-flight verification: PASSED ==="
}

main() {
  run_verify
  if [[ "$VERIFY_ONLY" == true ]]; then
    echo "(--verify-only: skipping GenerateProjectFiles + RunUAT)"
    exit 0
  fi
  local ue_root
  ue_root="$(detect_ue_root)"
  [[ -n "$ue_root" ]] || die "UE_ROOT not found."

  if [[ "$OPEN_XCODE_ONLY" == true ]]; then
    sync_ios_team_into_project_config
    generate_xcode_project_files "$ue_root"
    patch_ios_xcconfig_development_team
    patch_ios_pbxproj_development_team
    patch_ios_pbxproj_copy_phase_xattr_strip
    open_ios_workspace_in_xcode
    echo ">>> In Xcode: select target FinalEvolutionLab → Signing & Capabilities → Team, then Product → Archive if you ship from Xcode."
    exit 0
  fi

  run_ios_shipping_archive "$ue_root"
}

main "$@"
