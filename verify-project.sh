#!/bin/bash
# ============================================================
# Final Evolution Lab — Project Verification Script
# Run this on your Mac Mini after transferring the project
# Usage: bash verify-project.sh
# ============================================================

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

check() {
    local desc="$1"
    local path="$2"
    if [ -e "$path" ]; then
        echo -e "  ${GREEN}✓${NC} $desc"
        ((PASS++))
    else
        echo -e "  ${RED}✗${NC} $desc — MISSING: $path"
        ((FAIL++))
    fi
}

warn_check() {
    local desc="$1"
    local path="$2"
    if [ -e "$path" ]; then
        echo -e "  ${GREEN}✓${NC} $desc"
        ((PASS++))
    else
        echo -e "  ${YELLOW}⚠${NC} $desc — Not found (optional): $path"
        ((WARN++))
    fi
}

echo ""
echo "========================================================"
echo "  Final Evolution Lab — Project Integrity Verification"
echo "========================================================"
echo ""

# --- Core Project Files ---
echo "▸ Core Project Files"
check ".uproject file" "UnrealStarter/BasketballGame/BasketballGame.uproject"
check "Exercise Catalog" "UnrealStarter/BasketballGame/Content/FEL/Config/ExerciseCatalog.json"
check "Asset Paths Header" "UnrealStarter/BasketballGame/Source/FinalEvolutionLab/FELGeneratedAssetPaths.h"
check "Elijah Bonds Anim Paths" "UnrealStarter/BasketballGame/Source/FinalEvolutionLab/FELElijahBondsAnimPaths.h"
check "AI Asset Manager .h" "UnrealStarter/BasketballGame/Source/FinalEvolutionLab/UFELAIAssetManagerSubsystem.h"
check "AI Asset Manager .cpp" "UnrealStarter/BasketballGame/Source/FinalEvolutionLab/UFELAIAssetManagerSubsystem.cpp"
echo ""

# --- Editor Python Scripts ---
echo "▸ Unreal Editor Python Scripts"
check "Import AI Assets" "UnrealStarter/BasketballGame/EditorPython/fel_import_ai_assets.py"
check "Import Elijah Bonds Anims" "UnrealStarter/BasketballGame/EditorPython/fel_import_elijahbonds_animations.py"
check "Import Catalogue Anims" "UnrealStarter/BasketballGame/EditorPython/fel_import_catalogue_animations.py"
echo ""

# --- AI Asset Pipeline ---
echo "▸ AI Asset Pipeline"
check "Pipeline __init__" "scripts/ai_asset_pipeline/__init__.py"
check "Pipeline config" "scripts/ai_asset_pipeline/config.py"
check "Meshy service" "scripts/ai_asset_pipeline/meshy_service.py"
check "Luma service" "scripts/ai_asset_pipeline/luma_service.py"
check "DeepMotion service" "scripts/ai_asset_pipeline/deepmotion_service.py"
check "Local-first pipeline" "scripts/ai_asset_pipeline/local_first_pipeline.py"
check "Requirements" "scripts/ai_asset_pipeline/requirements.txt"
check ".env.example" "scripts/ai_asset_pipeline/.env.example"
echo ""

# --- Streaming Infrastructure ---
echo "▸ Streaming Infrastructure"
check "Signalling server.js" "streaming/signalling/server.js"
check "Signalling package.json" "streaming/signalling/package.json"
check "Frontend package.json" "streaming/frontend/package.json"
check "Frontend App.tsx" "streaming/frontend/src/App.tsx"
echo ""

# --- iOS App ---
echo "▸ iOS App"
check "Config.swift" "ios/FinalEvolutionLab/Config.swift"
check "PixelStreamingService" "ios/FinalEvolutionLab/Services/PixelStreamingService.swift"
echo ""

# --- UE5 Setup Scripts ---
echo "▸ UE5 Setup & Deployment Scripts"
check "Complete pipeline" "scripts/ue5_setup/fel_complete_pipeline.sh"
check "Import all assets" "scripts/ue5_setup/import_all_assets.sh"
check "Cook Linux server" "scripts/ue5_setup/cook_fel_linux_server.sh"
check "Cook iOS" "scripts/ue5_setup/cook_fel_ios.sh"
check "Prepare iOS build" "scripts/ue5_setup/prepare_ios_build.sh"
echo ""

# --- Generated Assets ---
echo "▸ Generated Assets"
check "Animation manifest" "GeneratedAssets/Animations/animation_manifest.json"
check "UE5 animation mapping" "GeneratedAssets/Animations/ue5_animation_mapping.json"
check "Pipeline report" "GeneratedAssets/pipeline_report.json"
warn_check "Meshy assets (large)" "GeneratedAssets/meshy"
echo ""

# --- Source Videos ---
echo "▸ Source Videos"
check "Video metadata" "SourceVideos/Instagram/video_metadata.json"
warn_check "Instagram videos" "SourceVideos/Instagram/basketball"
echo ""

# --- Documentation ---
echo "▸ Documentation"
check "Deployment Guide" "DEPLOYMENT_GUIDE.md"
check "Download Instructions" "DOWNLOAD_INSTRUCTIONS.md"
check "UE5 Setup README" "scripts/ue5_setup/README.md"
check "AI Pipeline README" "scripts/ai_asset_pipeline/README.md"
echo ""

# --- Marketing Site ---
echo "▸ Marketing Site"
check "Site package.json" "sites/finalevolutiongroup.com/package.json"
echo ""

# --- Environment Config ---
echo "▸ Environment & Config"
warn_check ".env file" ".env"
check ".gitignore" ".gitignore"
warn_check ".ue5_env" ".ue5_env"
echo ""

# --- System Checks ---
echo "▸ System Checks"
if command -v node &>/dev/null; then
    echo -e "  ${GREEN}✓${NC} Node.js installed: $(node --version)"
    ((PASS++))
else
    echo -e "  ${YELLOW}⚠${NC} Node.js not found — install with: brew install node"
    ((WARN++))
fi

if command -v python3 &>/dev/null; then
    echo -e "  ${GREEN}✓${NC} Python3 installed: $(python3 --version 2>&1)"
    ((PASS++))
else
    echo -e "  ${YELLOW}⚠${NC} Python3 not found — install with: brew install python3"
    ((WARN++))
fi

if command -v git &>/dev/null; then
    echo -e "  ${GREEN}✓${NC} Git installed: $(git --version)"
    ((PASS++))
else
    echo -e "  ${RED}✗${NC} Git not found — install with: brew install git"
    ((FAIL++))
fi
echo ""

# --- Summary ---
echo "========================================================"
echo "  RESULTS: ${GREEN}${PASS} passed${NC}, ${RED}${FAIL} failed${NC}, ${YELLOW}${WARN} warnings${NC}"
echo "========================================================"

if [ $FAIL -eq 0 ]; then
    echo -e "  ${GREEN}🎉 Project integrity check PASSED!${NC}"
    echo "  Your project is ready for UE5 development."
else
    echo -e "  ${RED}⚠ Some required files are missing.${NC}"
    echo "  Please re-download or re-clone the project."
fi
echo ""
exit $FAIL
