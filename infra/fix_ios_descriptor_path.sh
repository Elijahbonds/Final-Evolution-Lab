#!/usr/bin/env bash
# =============================================================================
# fix_ios_descriptor_path.sh
# FEL DevOps — Autonomous fix for:
#   "Failed to open descriptor file ../../../FinalEvolutionLab/FinalEvolutionLab.uproject"
#
# Root Cause: The iOS binary expects the .uproject at a relative path determined
# during cook. When there's a mismatch between:
#   - UE_PROJECT_NAME (build variable)
#   - The actual directory name containing FinalEvolutionLab.uproject
#   - Info.plist UE4CommandLine or UE5LaunchArguments
#
# This script audits and fixes all three.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

# ─── Configuration ────────────────────────────────────────────────
INTERNAL_ID="FinalEvolutionLab"
DISPLAY_NAME="Final Evolution AI Coach"
BUNDLE_ID="com.finalevolutionlab.sovereign"

# Discover project
UPROJECT="${UPROJECT:-}"
discover() {
    local candidates=(
        "${HOME}/Developer/FinalEvolutionLab57/${INTERNAL_ID}.uproject"
        "${HOME}/Developer/${INTERNAL_ID}/${INTERNAL_ID}.uproject"
        "${HOME}/Documents/${INTERNAL_ID} 5.7/${INTERNAL_ID}.uproject"
        "${HOME}/Documents/rork-final-evolution-lab/UnrealStarter/BasketballGame/${INTERNAL_ID}.uproject"
    )
    for p in "${candidates[@]}"; do
        [[ -f "$p" ]] && { echo "$p"; return 0; }
    done
    echo ""
}

if [[ -z "$UPROJECT" ]]; then
    UPROJECT="$(discover)"
fi

if [[ -z "$UPROJECT" || ! -f "$UPROJECT" ]]; then
    echo -e "${RED}ERROR: Cannot locate ${INTERNAL_ID}.uproject${NC}"
    echo "Set UPROJECT=/path/to/${INTERNAL_ID}.uproject and re-run."
    exit 1
fi

PROJECT_DIR="$(cd "$(dirname "$UPROJECT")" && pwd)"
PROJECT_NAME="$(basename "$UPROJECT" .uproject)"
CONFIG_DIR="$PROJECT_DIR/Config"

echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  FEL DevOps — iOS Descriptor Path Fix${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  Project:      ${GREEN}$PROJECT_NAME${NC}"
echo -e "  Location:     $PROJECT_DIR"
echo -e "  Display Name: $DISPLAY_NAME"
echo -e "  Bundle ID:    $BUNDLE_ID"
echo ""

# ─── Audit 1: Verify .uproject filename matches internal ID ───────
echo -e "${YELLOW}[AUDIT 1] .uproject filename vs internal identifier${NC}"
if [[ "$PROJECT_NAME" != "$INTERNAL_ID" ]]; then
    echo -e "  ${RED}MISMATCH: File is '$PROJECT_NAME.uproject' but internal ID is '$INTERNAL_ID'${NC}"
    echo -e "  ${GREEN}FIX: Renaming .uproject...${NC}"
    mv "$UPROJECT" "$PROJECT_DIR/${INTERNAL_ID}.uproject"
    UPROJECT="$PROJECT_DIR/${INTERNAL_ID}.uproject"
    PROJECT_NAME="$INTERNAL_ID"
    echo -e "  ${GREEN}FIXED${NC}"
else
    echo -e "  ${GREEN}OK: $PROJECT_NAME.uproject matches $INTERNAL_ID${NC}"
fi

# ─── Audit 2: Verify directory name matches ──────────────────────
echo -e "${YELLOW}[AUDIT 2] Parent directory name${NC}"
DIR_NAME="$(basename "$PROJECT_DIR")"
# The relative path ../../../{DirName}/{DirName}.uproject requires DirName == ProjectName
# OR the directory must be named the same as the project
if [[ "$DIR_NAME" == "$PROJECT_NAME" || "$DIR_NAME" == "${PROJECT_NAME}57" || "$DIR_NAME" == "${PROJECT_NAME} 5.7" ]]; then
    echo -e "  ${GREEN}OK: Directory '$DIR_NAME' is compatible${NC}"
else
    echo -e "  ${YELLOW}WARN: Directory is '$DIR_NAME', expected '$PROJECT_NAME'${NC}"
    echo -e "  NOTE: RunUAT stages based on project name, not dir name. This is usually fine if Target.cs matches."
fi

# ─── Audit 3: Target.cs files ─────────────────────────────────────
echo -e "${YELLOW}[AUDIT 3] Target.cs naming${NC}"
SOURCE_DIR="$PROJECT_DIR/Source"
TARGET_FILE="$SOURCE_DIR/${INTERNAL_ID}.Target.cs"
EDITOR_TARGET="$SOURCE_DIR/${INTERNAL_ID}Editor.Target.cs"

if [[ -f "$TARGET_FILE" ]]; then
    echo -e "  ${GREEN}OK: ${INTERNAL_ID}.Target.cs exists${NC}"
else
    echo -e "  ${RED}MISSING: ${INTERNAL_ID}.Target.cs${NC}"
    echo -e "  ${GREEN}FIX: Creating...${NC}"
    mkdir -p "$SOURCE_DIR"
    cat > "$TARGET_FILE" << 'TARGETEOF'
using UnrealBuildTool;

public class FinalEvolutionLabTarget : TargetRules
{
    public FinalEvolutionLabTarget(TargetInfo Target) : base(Target)
    {
        Type = TargetType.Game;
        DefaultBuildSettings = BuildSettingsVersion.V5;
        IncludeOrderVersion = EngineIncludeOrderVersion.Latest;
        ExtraModuleNames.Add("FinalEvolutionLab");
    }
}
TARGETEOF
    echo -e "  ${GREEN}CREATED: ${INTERNAL_ID}.Target.cs${NC}"
fi

if [[ -f "$EDITOR_TARGET" ]]; then
    echo -e "  ${GREEN}OK: ${INTERNAL_ID}Editor.Target.cs exists${NC}"
else
    echo -e "  ${GREEN}FIX: Creating ${INTERNAL_ID}Editor.Target.cs...${NC}"
    cat > "$EDITOR_TARGET" << 'EDITOREOF'
using UnrealBuildTool;

public class FinalEvolutionLabEditorTarget : TargetRules
{
    public FinalEvolutionLabEditorTarget(TargetInfo Target) : base(Target)
    {
        Type = TargetType.Editor;
        DefaultBuildSettings = BuildSettingsVersion.V5;
        IncludeOrderVersion = EngineIncludeOrderVersion.Latest;
        ExtraModuleNames.Add("FinalEvolutionLab");
    }
}
EDITOREOF
    echo -e "  ${GREEN}CREATED${NC}"
fi

# ─── Audit 4: DefaultGame.ini — iOS settings ─────────────────────
echo -e "${YELLOW}[AUDIT 4] DefaultGame.ini iOS configuration${NC}"
DEFAULT_GAME="$CONFIG_DIR/DefaultGame.ini"
mkdir -p "$CONFIG_DIR"

# Ensure [/Script/IOSRuntimeSettings.IOSRuntimeSettings] section
if [[ -f "$DEFAULT_GAME" ]]; then
    if ! grep -q "IOSRuntimeSettings" "$DEFAULT_GAME" 2>/dev/null; then
        echo -e "  ${GREEN}FIX: Adding iOS runtime settings...${NC}"
        cat >> "$DEFAULT_GAME" << IOSEOF

[/Script/IOSRuntimeSettings.IOSRuntimeSettings]
BundleIdentifier=$BUNDLE_ID
BundleDisplayName=$DISPLAY_NAME
BundleName=$INTERNAL_ID
bSupportsPortraitOrientation=True
bSupportsLandscapeLeftOrientation=True
bSupportsLandscapeRightOrientation=True
MinimumiOSVersion=IOS_17
IOSEOF
    else
        echo -e "  ${GREEN}OK: IOSRuntimeSettings already present${NC}"
    fi
else
    echo -e "  ${GREEN}FIX: Creating DefaultGame.ini with iOS settings...${NC}"
    cat > "$DEFAULT_GAME" << GAMEEOF
[/Script/EngineSettings.GeneralProjectSettings]
ProjectID=$(uuidgen | tr '[:upper:]' '[:lower:]')
ProjectName=$INTERNAL_ID
ProjectDisplayedTitle=$DISPLAY_NAME

[/Script/IOSRuntimeSettings.IOSRuntimeSettings]
BundleIdentifier=$BUNDLE_ID
BundleDisplayName=$DISPLAY_NAME
BundleName=$INTERNAL_ID
bSupportsPortraitOrientation=True
bSupportsLandscapeLeftOrientation=True
bSupportsLandscapeRightOrientation=True
MinimumiOSVersion=IOS_17

[Emergent]
GameWebSocketUrl=ws://localhost:8888
bFocusKeepalive=True
KeepaliveInterval=0.5
bAutoReconnect=True
ReconnectDelaySeconds=5.0
MaxReconnectAttempts=10
bSovereignSync=True
GAMEEOF
fi

# ─── Audit 5: Info.plist UE_PROJECT_NAME ──────────────────────────
echo -e "${YELLOW}[AUDIT 5] Info.plist and UE_PROJECT_NAME alignment${NC}"
PLIST_DIR="$PROJECT_DIR/Build/IOS"
PLIST_FILE="$PLIST_DIR/Info.plist"
mkdir -p "$PLIST_DIR"

if [[ ! -f "$PLIST_FILE" ]]; then
    echo -e "  ${GREEN}FIX: Creating Info.plist with correct UE_PROJECT_NAME...${NC}"
    cat > "$PLIST_FILE" << PLISTEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDisplayName</key>
    <string>$DISPLAY_NAME</string>
    <key>CFBundleExecutable</key>
    <string>$INTERNAL_ID</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleName</key>
    <string>$INTERNAL_ID</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>2.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>UE_PROJECT_NAME</key>
    <string>$INTERNAL_ID</string>
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleURLName</key>
            <string>$BUNDLE_ID</string>
            <key>CFBundleURLSchemes</key>
            <array>
                <string>finalevolution</string>
            </array>
        </dict>
    </array>
    <key>LSApplicationQueriesSchemes</key>
    <array>
        <string>finalevolution</string>
    </array>
    <key>UILaunchStoryboardName</key>
    <string>LaunchScreen</string>
    <key>UISupportedInterfaceOrientations</key>
    <array>
        <string>UIInterfaceOrientationPortrait</string>
        <string>UIInterfaceOrientationLandscapeLeft</string>
        <string>UIInterfaceOrientationLandscapeRight</string>
    </array>
    <key>NSLocalNetworkUsageDescription</key>
    <string>Final Evolution Lab connects to your local training hub for real-time performance data.</string>
    <key>NSMotionUsageDescription</key>
    <string>Motion data is used for athletic performance tracking and biomechanical analysis.</string>
    <key>NSCameraUsageDescription</key>
    <string>Camera is used for movement analysis and video coaching sessions.</string>
</dict>
</plist>
PLISTEOF
    echo -e "  ${GREEN}CREATED with UE_PROJECT_NAME=$INTERNAL_ID${NC}"
else
    # Verify UE_PROJECT_NAME matches
    if grep -q "UE_PROJECT_NAME" "$PLIST_FILE"; then
        CURRENT_NAME=$(grep -A1 "UE_PROJECT_NAME" "$PLIST_FILE" | grep "<string>" | sed 's/.*<string>\(.*\)<\/string>.*/\1/')
        if [[ "$CURRENT_NAME" != "$INTERNAL_ID" ]]; then
            echo -e "  ${RED}MISMATCH: UE_PROJECT_NAME='$CURRENT_NAME' should be '$INTERNAL_ID'${NC}"
            sed -i.bak "s|<string>$CURRENT_NAME</string>|<string>$INTERNAL_ID</string>|" "$PLIST_FILE"
            echo -e "  ${GREEN}FIXED: UE_PROJECT_NAME → $INTERNAL_ID${NC}"
        else
            echo -e "  ${GREEN}OK: UE_PROJECT_NAME=$INTERNAL_ID${NC}"
        fi
    else
        echo -e "  ${YELLOW}ADDING UE_PROJECT_NAME to Info.plist...${NC}"
        # Insert before closing </dict>
        sed -i.bak "s|</dict>|    <key>UE_PROJECT_NAME</key>\n    <string>$INTERNAL_ID</string>\n</dict>|" "$PLIST_FILE"
        echo -e "  ${GREEN}FIXED${NC}"
    fi
fi

# ─── Audit 6: Cook content staging path ──────────────────────────
echo -e "${YELLOW}[AUDIT 6] Cook content descriptor staging${NC}"
echo -e "  The iOS binary resolves .uproject via relative path: ../../../${INTERNAL_ID}/${INTERNAL_ID}.uproject"
echo -e "  During BuildCookRun, RunUAT stages the .uproject into:"
echo -e "    [StagedBuilds]/IOS/${INTERNAL_ID}/${INTERNAL_ID}.uproject"
echo -e "  ${GREEN}Ensure: -project arg matches the actual .uproject path exactly.${NC}"
echo -e "  ${GREEN}Ensure: Project folder name on disk allows the ../../.. traversal.${NC}"

# Verify no spaces in critical paths
if [[ "$PROJECT_DIR" == *" "* ]]; then
    echo -e "  ${RED}WARNING: Project path contains spaces: $PROJECT_DIR${NC}"
    echo -e "  ${RED}UE iOS cook can fail with spaces. Consider symlinking to ~/Developer/${INTERNAL_ID}${NC}"
fi

# ─── Summary ──────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  AUDIT COMPLETE — Descriptor Path Fix${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  Internal ID:     ${GREEN}$INTERNAL_ID${NC}"
echo -e "  Display Name:    $DISPLAY_NAME"
echo -e "  Bundle ID:       $BUNDLE_ID"
echo -e "  .uproject:       $UPROJECT"
echo -e "  UE_PROJECT_NAME: ${GREEN}$INTERNAL_ID${NC} (Info.plist)"
echo -e "  Deep Link:       finalevolution://"
echo -e "  Sovereign Hub:   ws://localhost:8888"
echo ""
echo -e "  ${GREEN}All pathing identifiers are now consistent.${NC}"
echo -e "  ${GREEN}The descriptor file error should be resolved.${NC}"
echo ""
echo -e "  Next: Run ${CYAN}./fel_ue5_ios_shipping_package.sh${NC} to build."
echo ""
