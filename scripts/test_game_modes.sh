#!/usr/bin/env bash
# Final Evolution Lab — Game Mode Verification
# Tests all 16+ game modes are registered and accessible via API

SIGNALLING_HOST="${SIGNALLING_HOST:-localhost}"
SIGNALLING_PORT="${SIGNALLING_PORT:-8888}"

echo "╔══════════════════════════════════════════════════════╗"
echo "║   FEL — 16 Game Mode Verification                   ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

MODES_JSON=$(curl -sf --max-time 5 "http://${SIGNALLING_HOST}:${SIGNALLING_PORT}/api/modes" 2>/dev/null || echo "")

if [ -z "$MODES_JSON" ]; then
  echo "ERROR: Cannot reach signalling server at ${SIGNALLING_HOST}:${SIGNALLING_PORT}"
  echo "Start the server first: cd streaming/signalling && node server.js"
  exit 1
fi

PASS=0
FAIL=0

# Expected modes - id:name:category
EXPECTED=(
  "basketball_h2h|Street · 1v1|basketball"
  "basketball_dunk|Dunk Contest|basketball"
  "basketball_3v3|Street · 3v3|basketball"
  "karate_h2h|Karate · 1v1|combat"
  "karate_endless|Karate · Endless|combat"
  "baseball|Baseball · Ballpark|field"
  "football|Football · Kick Return|field"
  "soccer|Soccer · Stadium|field"
  "golf|Golf · Links|precision"
  "tennis|Tennis · Court|court"
  "volleyball|Volleyball · Sand|court"
  "gymnastics|Gymnastics · Floor|performance"
  "brain_brawl|Academy · Brain Brawl|academy"
  "surfing|Surf · Line|board"
  "skateboarding|Skate · Park|board"
  "snowboarding|Snow · Line|board"
  "market_browse|Sovereign Shop|shop"
)

for entry in "${EXPECTED[@]}"; do
  IFS='|' read -r id name category <<< "$entry"
  if echo "$MODES_JSON" | grep -q "\"$id\""; then
    PASS=$((PASS+1))
    echo "  ✓ ${name} (${id}) [${category}]"
  else
    FAIL=$((FAIL+1))
    echo "  ✗ MISSING: ${name} (${id}) [${category}]"
  fi
done

echo ""
echo "Results: ${PASS} found, ${FAIL} missing out of ${#EXPECTED[@]} expected modes"

if [ "$FAIL" -eq 0 ]; then
  echo "✅ All game modes registered correctly!"
else
  echo "❌ Some modes are missing."
  exit 1
fi

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "📋 Manual Testing Checklist (with UE5 server running):"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "For each mode, verify in the web frontend:"
echo ""
echo "  1. Mode Selection: Click card → loading screen → correct venue"
echo "  2. Gameplay: Player spawns, inputs work, rules function, HUD OK"
echo "  3. Exercise Panel: 3D demo plays, animation correct, props appear"
echo "  4. Streaming: 60fps, <100ms latency, audio OK, adaptive bitrate"
echo "  5. Session: Exit returns to launcher, reconnection works"
echo ""
