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
#   ./fel_ue5_ios_shipping_package.sh --full-cook   # -clean + wipe Saved/Cooked + StagedBuilds (force full recook)
#   ./fel_ue5_ios_shipping_package.sh --full-cook --shipping   # force IOS_CLIENTCONFIG=Shipping (default; debug text stripped in game)
#   ./fel_ue5_ios_shipping_package.sh --full-cook --development # IOS_CLIENTCONFIG=Development (verbose on device)
#   ./fel_ue5_ios_shipping_package.sh --full-cook --verbose   # pass -verbose to RunUAT BuildCookRun
#   ./fel_ue5_ios_shipping_package.sh --full-cook -map=VeniceBeach  # cook one map (e.g. Venice) instead of -allmaps
#   ./fel_ue5_ios_shipping_package.sh --full-cook --allmaps   # explicit: cook all maps (default when -map is omitted)
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
FULL_COOK=false
VERBOSE_UAT=false
COOK_MAP_SHORT=""
EXPORT_IPA=false
for arg in "$@"; do
  [[ "$arg" == "--verify-only" ]] && VERIFY_ONLY=true
  [[ "$arg" == "--open-xcode" ]] && OPEN_XCODE_ONLY=true
  [[ "$arg" == "--full-cook" ]] && FULL_COOK=true
  [[ "$arg" == "--verbose" ]] && VERBOSE_UAT=true
  [[ "$arg" == "--export-ipa" ]] && EXPORT_IPA=true
  [[ "$arg" == "--shipping" ]] && export IOS_CLIENTCONFIG=Shipping
  [[ "$arg" == "--development" ]] && export IOS_CLIENTCONFIG=Development
  [[ "$arg" == "--allmaps" ]] && COOK_MAP_SHORT=""
  case "$arg" in
    -map=*|--map=*) COOK_MAP_SHORT="${arg#*=}" ;;
  esac
done
[[ "${IOS_FULL_COOK:-}" == "1" ]] && FULL_COOK=true

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
    die "Set UPROJECT to your .uproject file, or place FinalEvolutionLab under ~/Documents or ~/UnrealProjects."
  fi
  [[ -f "$chosen" ]] || die "UPROJECT not found: $chosen"
  PROJECT_DIR="$(cd "$(dirname "$chosen")" && pwd)"
  UPROJECT="$PROJECT_DIR/$(basename "$chosen")"
  DEFAULT_ENGINE="$PROJECT_DIR/Config/DefaultEngine.ini"
  DEFAULT_GAME="$PROJECT_DIR/Config/DefaultGame.ini"

  # Prefer staging/archives outside iCloud-backed Documents paths to avoid codesign failures:
  # "resource fork, Finder information, or similar detritus not allowed".
  # If user didn't override IOS_ARCHIVE, relocate it into the UE project tree (usually ~/Developer/...).
  local default_archive="$REPO_ROOT/artifacts/IOS_Shipping_Archive"
  if [[ "${IOS_ARCHIVE:-}" == "$default_archive" ]]; then
    case "$REPO_ROOT" in
    */Documents/*|*/Desktop/*)
      IOS_ARCHIVE="$PROJECT_DIR/Artifacts/IOS_${IOS_CLIENTCONFIG}_Archive"
      ;;
    esac
  fi
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

# Per-path xattr -c clears com.apple.FinderInfo that iCloud can reapply; codesign rejects it ("detritus").
# Use `-exec … {} +` (not `\\;`): Xcode expands shellScript into Script-*.sh and the lone `\\;` becomes `;`, breaking -exec.
find_strip = '\\nfind \\"${CONFIGURATION_BUILD_DIR}/${CONTENTS_FOLDER_PATH}\\" -exec xattr -c {} + 2>/dev/null || true'

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
        broken_find = '\\nfind \\"${CONFIGURATION_BUILD_DIR}/${CONTENTS_FOLDER_PATH}\\" -exec xattr -c {} ; 2>/dev/null || true'
        if broken_find in body:
            body = body.replace(broken_find, '')
        xattr_line = '\\nxattr -cr \\"${CONFIGURATION_BUILD_DIR}/${CONTENTS_FOLDER_PATH}\\" 2>/dev/null || true'
        # codesign rejects com.apple.FinderInfo on bundles under iCloud-backed paths; xattr -cr alone may not clear it.
        need_xattr = "xattr -cr" not in body
        need_find = "-exec xattr -c {} +" not in body
        suffix = ""
        if need_xattr:
            suffix += xattr_line
        if need_find:
            suffix += find_strip
        if suffix:
            text = text[:start_body] + body + suffix + text[end_quote:]

# --- B) Strip / ThinApp phase (runs after Copy, before CodeSign) ---
# UE 5.7 pbxproj escapes quotes inside shellScript as \\" … \\" — match the stored form exactly.
thin_tail = '\\"${UE_ENGINE_DIR}/Build/BatchFiles/Mac/ThinApp.sh\\" \\"${CONFIGURATION_BUILD_DIR}/${CONTENTS_FOLDER_PATH}\\" \\"${CONFIGURATION_BUILD_DIR}/${EXECUTABLE_PATH}\\"'
thin_xattr_only = '\\nxattr -cr \\"${CONFIGURATION_BUILD_DIR}/${CONTENTS_FOLDER_PATH}\\" 2>/dev/null || true'
thin_both = thin_xattr_only + find_strip
if thin_tail in text:
    j = text.find(thin_tail)
    tail_rest = text[j + len(thin_tail) : j + len(thin_tail) + 900]
    if "-exec xattr -c {} +" in tail_rest:
        pass
    elif tail_rest.startswith(thin_xattr_only) and "-exec xattr -c {} +" not in tail_rest:
        text = text.replace(thin_tail + thin_xattr_only, thin_tail + thin_both, 1)
    else:
        text = text.replace(thin_tail, thin_tail + thin_both, 1)

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
    echo "      macOS reapplies com.apple.FinderInfo on bundles there; Xcode codesign then fails (“detritus”)."
    echo "      Copy or clone the whole project to a path outside Desktop & Documents (e.g. ~/Developer/FEL57 or a non-synced disk),"
    echo "      then set UPROJECT to that .uproject and re-run this script."
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
    if [[ -d "$app/cookeddata" ]] || find "$app" -maxdepth 8 -name '*.pak' -print -quit 2>/dev/null | grep -q .; then
      echo ">>> OK: cooked payload present (cookeddata/ and/or .pak in bundle)."
    else
      echo "WARN: No cookeddata/ or .pak under $app — device may show \"Failed to open descriptor file\" or launch to a grey screen."
    fi
  else
    echo "WARN: Info.plist missing or empty — Xcode signing likely did not finalize: $app"
    echo "      Open FinalEvolutionLab (IOS).xcworkspace → Signing & Capabilities → Team, then re-run or use --open-xcode."
  fi
}

# RunUAT's archive step copies `Binaries/IOS/*.app` into -archivedirectory — but that bundle is often produced *before*
# the Xcode "Copy Executable and Staged Data" phase rsyncs `cookeddata/` into the *stagingdirectory* tree. The result is
# a runnable shell with no maps/content → "Failed to open descriptor file" / missing project descriptor on device.
copy_ios_deploy_artifacts() {
  local proj="${1:-}"
  [[ -z "$proj" ]] && return 0
  local deploy="$proj/Binaries/IOS/Deploy"
  mkdir -p "$deploy"
  if [[ -f "$proj/Binaries/IOS/manifest.plist" ]]; then
    cp -f "$proj/Binaries/IOS/manifest.plist" "$deploy/manifest.plist"
    echo ">>> Copied manifest.plist → $deploy/"
  fi
  local ipa=""
  ipa="$(find "$proj/Binaries/IOS" -maxdepth 1 -name '*.ipa' -print 2>/dev/null | head -1)"
  if [[ -z "$ipa" && -n "${IOS_ARCHIVE:-}" ]]; then
    ipa="$(find "$IOS_ARCHIVE" -maxdepth 3 -name 'FinalEvolutionLab.ipa' -print 2>/dev/null | head -1)"
  fi
  if [[ -n "$ipa" && -f "$ipa" ]]; then
    cp -f "$ipa" "$deploy/FinalEvolutionLab.ipa"
    echo ">>> Copied $(basename "$ipa") → $deploy/FinalEvolutionLab.ipa"
  else
    echo ">>> NOTE: No FinalEvolutionLab.ipa found under Binaries/IOS or archive — export IPA from Xcode Organizer if needed."
  fi
  if [[ -f "$proj/apps.json" ]]; then
    cp -f "$proj/apps.json" "$deploy/apps.json"
    echo ">>> Copied apps.json → $deploy/apps.json"
  fi
}

# Replace manifest.plist bundle-version placeholder using CFBundleVersion from staged .app (OTA + AltStore parity).
patch_manifest_bundle_version_from_app() {
  local proj="${1:-}"
  [[ -z "$proj" ]] && return 0
  local bin_ios="$proj/Binaries/IOS"
  local mp="$bin_ios/manifest.plist"
  [[ -f "$mp" ]] || return 0
  local app=""
  app="$(find "$bin_ios" -maxdepth 1 -name '*.app' -type d 2>/dev/null | head -1)"
  [[ -n "$app" && -f "$app/Info.plist" ]] || return 0
  local bv
  bv="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$app/Info.plist" 2>/dev/null || true)"
  [[ -n "$bv" ]] || return 0
  if grep -q 'REPLACE_WITH_CFBundleVersion_FROM_IPA' "$mp" 2>/dev/null; then
    /usr/bin/sed -i '' "s|<string>REPLACE_WITH_CFBundleVersion_FROM_IPA</string>|<string>${bv}</string>|" "$mp" 2>/dev/null || true
    echo ">>> manifest.plist bundle-version ← CFBundleVersion $bv ($(basename "$app"))"
  fi
}

# AltStore / SideStore Source JSON — same file for both clients. Refreshes on every successful cook.
refresh_altstore_source_json() {
  local proj="${1:-}"
  [[ -z "$proj" ]] && return 0
  local gen="$SCRIPT_DIR/scripts/fel_refresh_altstore_source.py"
  [[ -f "$gen" ]] || {
    echo "WARN: AltStore generator missing: $gen"
    return 0
  }
  if command -v python3 >/dev/null 2>&1; then
    python3 "$gen" "$proj" || echo "WARN: fel_refresh_altstore_source.py exited non-zero"
  else
    echo "WARN: python3 not found — skipping apps.json refresh"
  fi
}

# Before deleting _internal_staging, promote the fully staged signed .app back into Binaries + archive root.
promote_fully_staged_ios_app_from_internal_staging() {
  local staging_root="$1"
  [[ -d "$staging_root" ]] || return 0
  local staged_app="" cand
  while IFS= read -r cand; do
    [[ -d "$cand/cookeddata" ]] && {
      staged_app="$cand"
      break
    }
    find "$cand" -maxdepth 8 -name '*.pak' -print -quit 2>/dev/null | grep -q . && {
      staged_app="$cand"
      break
    }
  done < <(find "$staging_root" -name 'FinalEvolutionLab.app' -type d 2>/dev/null)
  [[ -n "$staged_app" ]] || {
    echo "WARN: No FinalEvolutionLab.app with cookeddata/ or .pak under $staging_root — cook/stage may have failed or paths differ."
    return 0
  }
  local bin_app="$PROJECT_DIR/Binaries/IOS/FinalEvolutionLab.app"
  local arch_app="$IOS_ARCHIVE/FinalEvolutionLab.app"
  echo ">>> Promoting fully staged iOS .app (has cookeddata — fixes empty archive / descriptor errors):"
  echo "    $staged_app"
  mkdir -p "$(dirname "$bin_app")" "$(dirname "$arch_app")"
  rm -rf "$bin_app" "$arch_app"
  ditto "$staged_app" "$bin_app"
  ditto "$staged_app" "$arch_app"
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

  if [[ "$FULL_COOK" == "true" ]]; then
    echo ">>> --full-cook: wiping Saved cook/stage caches + DDC and passing -clean to BuildCookRun."
    rm -rf \
      "$PROJECT_DIR/Saved" \
      "$PROJECT_DIR/DerivedDataCache" \
      2>/dev/null || true
  fi

  mkdir -p "$PROJECT_DIR/Saved/Logs"

  local cook_map_full=""
  if [[ -n "${COOK_MAP_SHORT:-}" ]]; then
    cook_map_full="$COOK_MAP_SHORT"
    shopt -s nocasematch
    case "${COOK_MAP_SHORT}" in
      VeniceBeach|Venice)
        cook_map_full="/Game/FEL/Venues/VeniceBeach/VeniceBeach"
        ;;
    esac
    shopt -u nocasematch
    if [[ "$cook_map_full" != /* ]]; then
      die "Unknown or invalid -map/--map value: $COOK_MAP_SHORT (use VeniceBeach or full /Game/... path)."
    fi
    echo ">>> Cooking single map: $cook_map_full (instead of -allmaps)."
  fi

  local uat_extra=()
  [[ "$FULL_COOK" == "true" ]] && uat_extra+=(-clean)
  [[ "$VERBOSE_UAT" == "true" ]] && uat_extra+=(-verbose)

  local cook_tokens=(-cook)
  if [[ -n "$cook_map_full" ]]; then
    cook_tokens+=(-map="$cook_map_full")
  else
    cook_tokens+=(-allmaps)
  fi

  local log_file="$PROJECT_DIR/Saved/Logs/fel_ios_shipping_last.txt"
  set +o pipefail
  set +e
  "$runuat" BuildCookRun \
    -project="$UPROJECT" \
    -noP4 \
    -platform=iOS \
    -clientconfig="$IOS_CLIENTCONFIG" \
    -build \
    "${cook_tokens[@]}" \
    -stage \
    -archive \
    -archivedirectory="$IOS_ARCHIVE" \
    -stagingdirectory="$staging_internal" \
    -utf8output \
    "${uat_extra[@]}" 2>&1 | tee "$log_file"
  uat_ec="${PIPESTATUS[0]}"
  set -e
  set -o pipefail
  if [[ "$uat_ec" -eq 0 ]]; then
    echo "BUILD SUCCEEDED." >> "$log_file"
  fi
  [[ "$uat_ec" -eq 0 ]] || die "RunUAT BuildCookRun failed (exit $uat_ec). See: $log_file"

  promote_fully_staged_ios_app_from_internal_staging "$staging_internal"

  rm -rf "$staging_internal"

  trap - RETURN
  cleanup_ios_xattr_patch_loop

  verify_ios_app_bundle_plist

  emit_ota_manifest_plist_to_binaries_ios "$PROJECT_DIR"
  patch_manifest_bundle_version_from_app "$PROJECT_DIR"
  refresh_altstore_source_json "$PROJECT_DIR"
  copy_ios_deploy_artifacts "$PROJECT_DIR"
  if [[ "$EXPORT_IPA" == true ]]; then
    export_ipa_from_xcode_archive "$PROJECT_DIR"
  fi

  local abs
  abs="$(cd "$IOS_ARCHIVE" && pwd)"
  echo ""
  echo "=== iOS $IOS_CLIENTCONFIG ARCHIVE COMPLETE ==="
  echo "Absolute path (install via Xcode Organizer / Devices, or distribute per your workflow):"
  echo "  $abs"
  du -sh "$abs" 2>/dev/null || true
  echo ""
  echo ">>> App bundle (TestFlight / devicectl install):"
  local bin_ios="$PROJECT_DIR/Binaries/IOS"
  [[ -d "$bin_ios" ]] && find "$bin_ios" -maxdepth 2 \( -name '*.ipa' -o -name '*.app' \) -print 2>/dev/null || true
  echo ">>> To produce a signed .ipa for Transporter / TestFlight: Xcode → Window → Organizer → Distribute App,"
  echo "    or xcodebuild -exportArchive after archiving FinalEvolutionLab (IOS)."
  echo ">>> Emergent telemetry on device: set Config/DefaultGame.ini [Emergent] SovereignHubHost=<Mac Mini LAN IP>"
  echo "    (GameWebSocketUrl may stay ws://127.0.0.1:PORT/... — the bridge rewrites localhost to the hub IP)."
  print_sideload_distribution_hint "$PROJECT_DIR"
}

emit_ota_manifest_plist_to_binaries_ios() {
  local proj="${1:-}"
  [[ -z "$proj" ]] && return 0
  local out_dir="$proj/Binaries/IOS"
  mkdir -p "$out_dir"
  local tmpl="$SCRIPT_DIR/manifest.plist"
  [[ -f "$tmpl" ]] || {
    echo "WARN: manifest template missing: $tmpl"
    return 0
  }
  /bin/cp -f "$tmpl" "$out_dir/manifest.plist"
  if [[ -n "${FEL_OTA_IPA_URL:-}" ]]; then
    /usr/bin/sed -i '' "s|https://finalevolutionlab.com/app/FinalEvolutionLab.ipa|${FEL_OTA_IPA_URL//&/\\&}|g" \
      "$out_dir/manifest.plist" 2>/dev/null || true
  fi
  echo ""
  echo ">>> OTA manifest (itms-services install): $out_dir/manifest.plist"
  echo "    (set FEL_OTA_IPA_URL to retarget the .ipa before re-running this step if needed)"
}

print_sideload_distribution_hint() {
  local proj="${1:-.}"
  echo ""
  echo "=== Third-party sideload (OTA / AltStore-style) ==="
  echo "1. Merge UnrealIntegration/Config/DefaultEngine.FEL_iOS_sideload.snippet.ini into UE Config/DefaultEngine.ini"
  echo "   (disables Game Center / Sign in with Apple entitlements — identity via Sovereign Hub)."
  echo "2. Export a signed FinalEvolutionLab.ipa (Xcode Organizer → Distribute → Ad Hoc or Development)."
  echo "3. Upload .ipa + repo-root manifest.plist over **HTTPS** (same host/path as manifest URLs)."
  echo "4. Update manifest.plist bundle-version + software-package url; set apps.json versions[0].downloadURL + size."
  echo "5. iPhone install link (safari / bio link):"
  echo "   itms-services://?action=download-manifest&url=https://finalevolutionlab.com/app/manifest.plist"
  echo "   Repo templates: $SCRIPT_DIR/manifest.plist , $SCRIPT_DIR/apps.json"
  echo "   AltStore / SideStore source (same JSON): https://finalevolutionlab.com/apps.json"
  echo "   Add button deep link: altstore://source?url=https://finalevolutionlab.com/apps.json"
  echo "   Typical .ipa: export from Xcode Organizer after archive, or under Binaries/IOS if UAT emitted one."
  local ipa_found
  ipa_found="$(find "$proj/Binaries/IOS" -maxdepth 1 -name '*.ipa' -print 2>/dev/null | head -3)"
  if [[ -z "$ipa_found" ]]; then
    ipa_found="$(find "$proj" -maxdepth 7 -name 'FinalEvolutionLab.ipa' -print 2>/dev/null | head -3)"
  fi
  if [[ -n "$ipa_found" ]]; then
    echo "   Found .ipa candidate(s):"
    sed 's/^/     /' <<< "$ipa_found"
  fi
}

export_ipa_from_xcode_archive() {
  local proj="${1:-}"
  [[ -z "$proj" ]] && return 0
  local ws="$proj/FinalEvolutionLab (IOS).xcworkspace"
  [[ -d "$ws" ]] || { echo "WARN: iOS workspace missing: $ws"; return 0; }

  local xcarchive="$IOS_ARCHIVE/FinalEvolutionLab.xcarchive"
  local export_dir="$IOS_ARCHIVE/_ipa_export"
  mkdir -p "$IOS_ARCHIVE" "$export_dir"

  echo ""
  echo ">>> Xcode archive → $xcarchive"
  xcodebuild -workspace "$ws" -scheme FinalEvolutionLab -configuration Shipping -destination "generic/platform=iOS" \
    -archivePath "$xcarchive" archive || { echo "WARN: xcodebuild archive failed"; return 0; }

  # Minimal export options for Development-style installs; adjust for App Store/TestFlight.
  local opts="$IOS_ARCHIVE/ExportOptions.plist"
  /usr/bin/plutil -create xml1 "$opts" 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Delete :method" "$opts" 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Add :method string development" "$opts" 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Delete :signingStyle" "$opts" 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Add :signingStyle string automatic" "$opts" 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Delete :compileBitcode" "$opts" 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Add :compileBitcode bool false" "$opts" 2>/dev/null || true

  echo ">>> Exporting .ipa → $export_dir"
  xcodebuild -exportArchive -archivePath "$xcarchive" -exportPath "$export_dir" -exportOptionsPlist "$opts" \
    || { echo "WARN: xcodebuild -exportArchive failed"; return 0; }

  local ipa
  ipa="$(find "$export_dir" -maxdepth 2 -name '*.ipa' -print 2>/dev/null | head -1)"
  if [[ -n "$ipa" ]]; then
    /bin/cp -f "$ipa" "$proj/Binaries/IOS/FinalEvolutionLab.ipa" 2>/dev/null || true
    echo ">>> Wrote .ipa: $proj/Binaries/IOS/FinalEvolutionLab.ipa"
  else
    echo "WARN: No .ipa produced under $export_dir"
  fi
}

print_apple_business_manager_hint() {
  echo ""
  echo "=== Apple Business Manager / enterprise distribution (summary) ==="
  echo "1. App Store Connect: upload the .ipa (or use Xcode Organizer → Distribute to TestFlight)."
  echo "2. Apple Business Manager (business.apple.com): add your org, purchase or assign apps, MDM device assignment."
  echo "3. For custom B2B private apps, use App Store Connect + Business Manager linking (see Apple 'Custom Apps')."
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
  print_apple_business_manager_hint
}

main "$@"
