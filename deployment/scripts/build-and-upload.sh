#!/bin/bash
# =============================================================================
# Final Evolution Lab - Build UE5 Project and Upload to S3
# =============================================================================
# Packages the UE5 project for Linux server with Pixel Streaming enabled,
# then uploads the build artifact to S3 for deployment.
#
# Usage:
#   ./build-and-upload.sh [--config Development|Shipping] [--skip-cook] [--skip-upload]
#
# Prerequisites:
#   - UE5 installed and .ue5_env configured
#   - AWS CLI configured with appropriate permissions
#   - S3 bucket created (via Terraform)
# =============================================================================
set -euo pipefail

# --- Configuration ---
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Load UE5 environment
if [ -f "$PROJECT_ROOT/.ue5_env" ]; then
  source "$PROJECT_ROOT/.ue5_env"
else
  echo "ERROR: .ue5_env not found. Run scripts/ue5_setup/install_ue5_linux.sh first."
  exit 1
fi

# Defaults
CONFIG="Shipping"
SKIP_COOK=false
SKIP_UPLOAD=false
S3_BUCKET="${FEL_S3_BUCKET:-fel-ue5-builds}"
AWS_REGION="${AWS_REGION:-us-west-2}"
BUILD_DIR="$PROJECT_ROOT/Builds/LinuxServer"
BUILD_VERSION="$(date +%Y%m%d-%H%M%S)-$(git -C $PROJECT_ROOT rev-parse --short HEAD 2>/dev/null || echo 'unknown')"

# Parse args
while [[ $# -gt 0 ]]; do
  case $1 in
    --config) CONFIG="$2"; shift 2 ;;
    --skip-cook) SKIP_COOK=true; shift ;;
    --skip-upload) SKIP_UPLOAD=true; shift ;;
    --bucket) S3_BUCKET="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

echo "================================================================"
echo "  FEL Build & Upload Pipeline"
echo "  Config: $CONFIG"
echo "  Version: $BUILD_VERSION"
echo "  S3 Bucket: $S3_BUCKET"
echo "================================================================"

# --- Step 1: Verify Pixel Streaming Plugin ---
echo "[1/5] Verifying Pixel Streaming plugin..."
UPROJECT="$PROJECT_ROOT/UnrealStarter/BasketballGame/BasketballGame.uproject"

if ! grep -q 'PixelStreaming' "$UPROJECT" 2>/dev/null; then
  echo "Enabling Pixel Streaming plugin in .uproject..."
  python3 -c "
import json, sys
with open('$UPROJECT', 'r') as f:
    proj = json.load(f)
if 'Plugins' not in proj:
    proj['Plugins'] = []
plugins_to_add = ['PixelStreaming', 'PixelStreamingPlayer']
for plugin in plugins_to_add:
    if not any(p.get('Name') == plugin for p in proj['Plugins']):
        proj['Plugins'].append({'Name': plugin, 'Enabled': True})
with open('$UPROJECT', 'w') as f:
    json.dump(proj, f, indent=2)
print('Pixel Streaming plugins enabled')
"
fi
echo "  Pixel Streaming plugin verified."

# --- Step 2: Cook/Package the Project ---
if [ "$SKIP_COOK" = false ]; then
  echo "[2/5] Cooking project for Linux server ($CONFIG)..."
  mkdir -p "$BUILD_DIR"
  
  "$RUN_UAT" BuildCookRun \
    -project="$UPROJECT" \
    -noP4 \
    -platform=Linux \
    -clientconfig="$CONFIG" \
    -serverconfig="$CONFIG" \
    -cook \
    -build \
    -stage \
    -pak \
    -archive \
    -archivedirectory="$BUILD_DIR" \
    -server \
    -noclient \
    -compressed \
    -prereqs \
    -utf8output \
    2>&1 | tee "$PROJECT_ROOT/Builds/cook-$BUILD_VERSION.log"
  
  echo "  Cook completed successfully."
else
  echo "[2/5] Skipping cook (--skip-cook)"
fi

# --- Step 3: Create Launch Script ---
echo "[3/5] Creating launch script..."
cat > "$BUILD_DIR/LinuxServer/launch_pixel_streaming.sh" << 'LAUNCHEOF'
#!/bin/bash
# Launch FEL Pixel Streaming Server
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Default parameters
RES_X=${RES_X:-1920}
RES_Y=${RES_Y:-1080}
SIGNALING_IP=${SIGNALING_IP:-127.0.0.1}
SIGNALING_PORT=${SIGNALING_PORT:-8889}
FPS=${FPS:-60}

exec "$SCRIPT_DIR/FinalEvolutionLab.sh" \
  -RenderOffscreen \
  -Windowed \
  -ForceRes \
  -ResX=$RES_X \
  -ResY=$RES_Y \
  -PixelStreamingIP=$SIGNALING_IP \
  -PixelStreamingPort=$SIGNALING_PORT \
  -AllowPixelStreamingCommands \
  -PixelStreamingEncoderRateControl=VBR \
  -PixelStreamingEncoderMaxBitrate=20000000 \
  -PixelStreamingFPS=$FPS \
  -log \
  "$@"
LAUNCHEOF
chmod +x "$BUILD_DIR/LinuxServer/launch_pixel_streaming.sh"

# --- Step 4: Package Build ---
echo "[4/5] Packaging build artifact..."
ARTIFACT_NAME="fel-build-$BUILD_VERSION.tar.gz"
ARTIFACT_PATH="$PROJECT_ROOT/Builds/$ARTIFACT_NAME"

tar -czf "$ARTIFACT_PATH" -C "$BUILD_DIR" LinuxServer/

ARTIFACT_SIZE=$(du -h "$ARTIFACT_PATH" | awk '{print $1}')
echo "  Build artifact: $ARTIFACT_PATH ($ARTIFACT_SIZE)"

# Create build manifest
cat > "$PROJECT_ROOT/Builds/build-$BUILD_VERSION.json" << MANIFESTEOF
{
  "version": "$BUILD_VERSION",
  "config": "$CONFIG",
  "artifact": "$ARTIFACT_NAME",
  "size": "$ARTIFACT_SIZE",
  "built_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "git_commit": "$(git -C $PROJECT_ROOT rev-parse HEAD 2>/dev/null || echo 'unknown')",
  "git_branch": "$(git -C $PROJECT_ROOT rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'unknown')"
}
MANIFESTEOF

# --- Step 5: Upload to S3 ---
if [ "$SKIP_UPLOAD" = false ]; then
  echo "[5/5] Uploading to S3..."
  
  aws s3 cp "$ARTIFACT_PATH" "s3://$S3_BUCKET/builds/$ARTIFACT_NAME" \
    --region "$AWS_REGION" \
    --storage-class STANDARD
  
  aws s3 cp "$PROJECT_ROOT/Builds/build-$BUILD_VERSION.json" \
    "s3://$S3_BUCKET/builds/build-$BUILD_VERSION.json" \
    --region "$AWS_REGION"
  
  # Update latest pointer
  echo "$BUILD_VERSION" | aws s3 cp - "s3://$S3_BUCKET/builds/LATEST" \
    --region "$AWS_REGION"
  
  echo "  Uploaded to s3://$S3_BUCKET/builds/$ARTIFACT_NAME"
else
  echo "[5/5] Skipping upload (--skip-upload)"
fi

echo ""
echo "================================================================"
echo "  Build Complete!"
echo "  Version:  $BUILD_VERSION"
echo "  Artifact: $ARTIFACT_NAME ($ARTIFACT_SIZE)"
echo "  S3:       s3://$S3_BUCKET/builds/$ARTIFACT_NAME"
echo "================================================================"
