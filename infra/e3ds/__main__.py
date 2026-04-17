"""
Final Evolution Lab — Eagle 3D Streaming (E3DS) Pulumi Deployment

Provisions GPU-backed Pixel Streaming infrastructure on E3DS cloud,
captures the stream URL, and exports it for web portal integration.

Prerequisites:
  pip install pulumi pulumi-aws pulumi-command
  pulumi login
  Set environment:
    E3DS_API_KEY        — Eagle 3D Streaming API key (from controlpanel.eagle3dstreaming.com)
    E3DS_ACCOUNT_ID     — Your E3DS account ID
    AWS_REGION          — Fallback region for auxiliary resources (default: us-east-1)
    FEL_BUILD_S3_URI    — S3 URI of the packaged UE5 build (.zip)
"""

import pulumi
import pulumi_command as command
import json, os

# ─── Config ────────────────────────────────────────────────────────
config = pulumi.Config()

e3ds_api_key     = config.require_secret("e3dsApiKey")
e3ds_account_id  = config.require("e3dsAccountId")
e3ds_app_name    = config.get("e3dsAppName") or "FinalEvolutionLab"
e3ds_region      = config.get("e3dsRegion") or "us-east"  # us-east, us-west, eu-west
build_zip_url    = config.require("buildZipUrl")  # Public URL or S3 presigned URL to UE5 packaged build

# E3DS GPU tier — matches Eagle 3D hardware specs
gpu_tier         = config.get("gpuTier") or "rtx4080"  # rtx3070, rtx4080
max_streams      = config.get_int("maxStreams") or 4
idle_timeout_min = config.get_int("idleTimeoutMin") or 15

# Game mode → map associations from FEL
game_mode_maps = {
    "basketball_h2h":  "Venice_Beach_Court",
    "basketball_dunk": "Venice_Beach_Court",
    "basketball_3v3":  "Venice_Beach_Court",
    "karate_h2h":      "Zen_Dojo",
    "karate_endless":  "Zen_Dojo",
    "baseball":        "Baseball_Park",
    "football":        "Gridiron_Stadium",
    "soccer":          "Soccer_Stadium",
    "golf":            "Links_Course",
    "tennis":          "Tennis_Court",
    "volleyball":      "Sand_Court",
    "gymnastics":      "Training_Floor",
    "surfing":         "Venice_Beach_Surf",
    "skateboarding":   "Skate_Park",
    "snowboarding":    "Mountain_Slope",
}

# ─── E3DS Application Provisioning ─────────────────────────────────
# Step 1: Create / update the E3DS application via their REST API
e3ds_create_app = command.local.Command(
    "e3ds-create-app",
    create=pulumi.Output.all(e3ds_api_key, build_zip_url).apply(
        lambda args: f"""
curl -sf -X POST "https://api.eagle3dstreaming.com/v1/apps" \
  -H "Authorization: Bearer {args[0]}" \
  -H "Content-Type: application/json" \
  -d '{json.dumps({
      "name": e3ds_app_name,
      "account_id": e3ds_account_id,
      "build_url": args[1],
      "gpu_tier": gpu_tier,
      "region": e3ds_region,
      "max_concurrent_streams": max_streams,
      "idle_timeout_minutes": idle_timeout_min,
      "pixel_streaming": {{
          "enabled": True,
          "signaling_port": 8888,
          "webrtc_port_range": "49152-65535",
          "encoder": "nvenc",
          "resolution": "1920x1080",
          "fps": 60,
          "bitrate_mbps": 20,
          "codec": "h264"
      }},
      "launch_args": "-AudioMixer -PixelStreamingIP=0.0.0.0 -PixelStreamingPort=8888 -RenderOffScreen -ForceRes -ResX=1920 -ResY=1080 -AllowPixelStreamingCommands -log",
      "maps": {json.dumps(game_mode_maps)}
  })}'
"""
    ),
    opts=pulumi.ResourceOptions(additional_secret_outputs=["stdout"]),
)

# Step 2: Create E3DS config (streaming settings per game mode)
e3ds_create_config = command.local.Command(
    "e3ds-create-config",
    create=pulumi.Output.all(e3ds_api_key, e3ds_create_app.stdout).apply(
        lambda args: f"""
APP_ID=$(echo '{args[1]}' | python3 -c "import sys,json; print(json.load(sys.stdin).get('app_id',''))" 2>/dev/null || echo "")
curl -sf -X POST "https://api.eagle3dstreaming.com/v1/configs" \
  -H "Authorization: Bearer {args[0]}" \
  -H "Content-Type: application/json" \
  -d '{json.dumps({
      "app_id": "$APP_ID",
      "name": "FEL-Production",
      "resolution_x": 1920,
      "resolution_y": 1080,
      "fps": 60,
      "min_bitrate": 8,
      "max_bitrate": 20,
      "encoder": "nvenc_h264",
      "enable_audio": True,
      "enable_input": True,
      "idle_disconnect_seconds": idle_timeout_min * 60,
      "matchmaker_enabled": True,
      "stun_turn_enabled": True
  })}'
"""
    ),
    opts=pulumi.ResourceOptions(depends_on=[e3ds_create_app]),
)

# Step 3: Deploy / start the application
e3ds_deploy = command.local.Command(
    "e3ds-deploy",
    create=pulumi.Output.all(e3ds_api_key, e3ds_create_app.stdout).apply(
        lambda args: f"""
APP_ID=$(echo '{args[1]}' | python3 -c "import sys,json; print(json.load(sys.stdin).get('app_id',''))" 2>/dev/null || echo "")
curl -sf -X POST "https://api.eagle3dstreaming.com/v1/apps/$APP_ID/deploy" \
  -H "Authorization: Bearer {args[0]}" \
  -H "Content-Type: application/json" \
  -d '{json.dumps({"action": "start", "region": e3ds_region})}'
"""
    ),
    opts=pulumi.ResourceOptions(depends_on=[e3ds_create_config]),
)

# Step 4: Get the stream URL from deployed app
e3ds_get_stream = command.local.Command(
    "e3ds-get-stream-url",
    create=pulumi.Output.all(e3ds_api_key, e3ds_create_app.stdout).apply(
        lambda args: f"""
APP_ID=$(echo '{args[1]}' | python3 -c "import sys,json; print(json.load(sys.stdin).get('app_id',''))" 2>/dev/null || echo "")
for i in $(seq 1 30); do
    RESULT=$(curl -sf "https://api.eagle3dstreaming.com/v1/apps/$APP_ID/status" \
        -H "Authorization: Bearer {args[0]}")
    STATUS=$(echo "$RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('status',''))" 2>/dev/null || echo "pending")
    if [ "$STATUS" = "running" ]; then
        echo "$RESULT"
        exit 0
    fi
    sleep 10
done
echo '{{"status":"timeout","stream_url":""}}'
"""
    ),
    opts=pulumi.ResourceOptions(depends_on=[e3ds_deploy]),
)

# ─── Exports ────────────────────────────────────────────────────────
# The critical stream URL that feeds into the web portal
e3ds_stream_url = e3ds_get_stream.stdout.apply(
    lambda s: json.loads(s).get("stream_url", "") if s else ""
)

e3ds_app_id = e3ds_create_app.stdout.apply(
    lambda s: json.loads(s).get("app_id", "") if s else ""
)

pulumi.export("E3DS_STREAM_URL", e3ds_stream_url)
pulumi.export("E3DS_APP_ID", e3ds_app_id)
pulumi.export("E3DS_REGION", e3ds_region)
pulumi.export("E3DS_GPU_TIER", gpu_tier)
pulumi.export("E3DS_MAX_STREAMS", max_streams)
pulumi.export("E3DS_APP_NAME", e3ds_app_name)

# Also export the iframe embed URL (primary integration point)
e3ds_iframe_url = e3ds_stream_url.apply(
    lambda url: f"https://stream.eagle3dstreaming.com/view/{url.split('/')[-1]}" if url else ""
)
pulumi.export("E3DS_IFRAME_URL", e3ds_iframe_url)

# Game mode map config for the web portal
pulumi.export("GAME_MODE_MAPS", json.dumps(game_mode_maps))
