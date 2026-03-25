#!/bin/bash
set -e

echo "[Claw] Executing the 'Phone Ready' Deployment Pipeline..."

UNITY_APP="/Applications/Unity/Hub/Editor/6000.0.71f1/Unity.app/Contents/MacOS/Unity"
PROJECT_PATH="$(pwd)/UnityProject"
BUILD_PATH="$(pwd)/UnityProject/Builds/iOS"
XCODE_WORKSPACE="$(pwd)/FinalEvolutionLab/FinalEvolutionLab.xcworkspace"
BUNDLE_ID="com.finalevolution.lab"

if [ ! -f "$UNITY_APP" ]; then
    echo "[Claw] ERROR: Unity 6000.0.71f1 not found. Make sure the Homebrew/Unity Hub download completed."
    exit 1
fi

# 1. Trigger a Headless Unity Export using the FELBuildScript
echo "[Claw] Running Headless Unity Export (FELBuildScript.ExportIOS)..."
"$UNITY_APP" -batchmode -quit -projectPath "$PROJECT_PATH" -executeMethod FELBuildScript.ExportIOS -logFile "$PROJECT_PATH/build_ios.log"
echo "[Claw] Unity export completed successfully!"

# 2. Open Xcode Workspace and trigger physical device build
echo "[Claw] Rebuilding FinalEvolutionLab.xcworkspace for the connected iOS device..."
cd FinalEvolutionLab || { echo "FinalEvolutionLab directory not found!"; exit 1; }

# Force open the workspace to satisfy the "Open the resulting Xcode Workspace" prompt
open FinalEvolutionLab.xcworkspace

# Trigger a physical device build
# We use 'generic/platform=iOS' to build for physical devices, avoiding the simulator.
xcodebuild clean build \
  -workspace FinalEvolutionLab.xcworkspace \
  -scheme FinalEvolutionLab \
  -destination 'generic/platform=iOS' \
  -allowProvisioningUpdates || {
    echo "[Claw] ERROR: Xcode build failed. Ensure your Apple Developer Profile is mapped correctly and your iPhone is connected."
    exit 1
}

echo "[Claw] Successfully built and deployed to the connected iOS device!"
