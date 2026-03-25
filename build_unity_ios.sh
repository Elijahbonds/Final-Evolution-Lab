#!/bin/bash
set -e

echo "[Claw] Starting Unity to iOS Export Pipeline..."

UNITY_APP="/Applications/Unity/Hub/Editor/6000.0.71f1/Unity.app/Contents/MacOS/Unity"
PROJECT_PATH="$(pwd)/UnityProject"
BUILD_PATH="$(pwd)/UnityProject/Builds/iOS"
XCODE_WORKSPACE="$(pwd)/FinalEvolutionLab/FinalEvolutionLab.xcworkspace"
BUNDLE_ID="com.finalevolution.lab"

if [ ! -f "$UNITY_APP" ]; then
    echo "[Claw] Unity 6000.0.71f1 not found. Ensure it's installed via Unity Hub."
    exit 1
fi

# 1. Trigger a Headless Unity Export
echo "[Claw] Triggering Headless Unity Build for iOS..."
"$UNITY_APP" -quit -batchmode -projectPath "$PROJECT_PATH" -executeMethod FELBuildScript.ExportIOS -logFile build_ios.log
echo "[Claw] Unity export finished. Check UnityProject/build_ios.log for details."

# 2. Clean and Rebuild the Xcode Workspace
echo "[Claw] Cleaning and Rebuilding Xcode Workspace..."
cd FinalEvolutionLab || exit
xcodebuild clean -workspace FinalEvolutionLab.xcworkspace -scheme FinalEvolutionLab
echo "[Claw] Building and deploying to physical device..."

# Build for Physical iOS Device connected
xcodebuild build -workspace FinalEvolutionLab.xcworkspace -scheme FinalEvolutionLab -destination 'generic/platform=iOS' -allowProvisioningUpdates || {
    echo "[Claw] ERROR: Ensure your Apple Developer Profile is mapped correctly in Xcode and your iPhone is connected."
    exit 1
}

echo "[Claw] Pipeline Complete!"
