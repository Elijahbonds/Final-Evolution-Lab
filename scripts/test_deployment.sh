#!/usr/bin/env bash
# Final Evolution Lab — Deployment Test Suite
# Tests streaming infrastructure, web app, and WebRTC readiness

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

SIGNALLING_HOST="${SIGNALLING_HOST:-localhost}"
SIGNALLING_PORT="${SIGNALLING_PORT:-8888}"
FRONTEND_HOST="${FRONTEND_HOST:-localhost}"
FRONTEND_PORT="${FRONTEND_PORT:-3000}"
TURN_HOST="${TURN_HOST:-localhost}"
TURN_PORT="${TURN_PORT:-3478}"

pass() { PASS=$((PASS+1)); echo -e "  ${GREEN}✓ PASS${NC}: $1"; }
fail() { FAIL=$((FAIL+1)); echo -e "  ${RED}✗ FAIL${NC}: $1"; }
warn() { WARN=$((WARN+1)); echo -e "  ${YELLOW}⚠ WARN${NC}: $1"; }
info() { echo -e "  ${BLUE}ℹ${NC} $1"; }

echo "╔══════════════════════════════════════════════════════╗"
echo "║   Final Evolution Lab — Deployment Test Suite       ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

# ── Test 1: Signalling Server Health ──
echo "── Test 1: Signalling Server ──"
HEALTH=$(curl -sf --max-time 5 "http://${SIGNALLING_HOST}:${SIGNALLING_PORT}/healthz" 2>/dev/null || echo "")
if [ -n "$HEALTH" ]; then
  pass "Signalling server is reachable at ${SIGNALLING_HOST}:${SIGNALLING_PORT}"
  STATUS=$(echo "$HEALTH" | python3 -c "import sys,json; print(json.load(sys.stdin)['status'])" 2>/dev/null || echo "")
  if [ "$STATUS" = "ok" ]; then
    pass "Health check returns status=ok"
  else
    fail "Health check status: $STATUS"
  fi
  STREAMER=$(echo "$HEALTH" | python3 -c "import sys,json; print(json.load(sys.stdin)['streamerConnected'])" 2>/dev/null || echo "")
  if [ "$STREAMER" = "True" ]; then
    pass "UE5 Streamer is connected"
  else
    warn "UE5 Streamer not connected (expected if UE server not running)"
  fi
else
  fail "Signalling server not reachable at ${SIGNALLING_HOST}:${SIGNALLING_PORT}"
fi
echo ""

# ── Test 2: Modes API ──
echo "── Test 2: Game Modes API ──"
MODES=$(curl -sf --max-time 5 "http://${SIGNALLING_HOST}:${SIGNALLING_PORT}/api/modes" 2>/dev/null || echo "")
if [ -n "$MODES" ]; then
  MODE_COUNT=$(echo "$MODES" | python3 -c "import sys,json; print(len(json.load(sys.stdin)['modes']))" 2>/dev/null || echo "0")
  if [ "$MODE_COUNT" -ge 16 ] 2>/dev/null; then
    pass "Modes API returns $MODE_COUNT game modes (expected ≥16)"
  else
    fail "Modes API returns only $MODE_COUNT modes (expected ≥16)"
  fi
  for mode in basketball_h2h karate_h2h soccer golf brain_brawl surfing; do
    if echo "$MODES" | grep -q "$mode"; then
      pass "Mode '$mode' present"
    else
      fail "Mode '$mode' missing"
    fi
  done
else
  fail "Modes API not reachable"
fi
echo ""

# ── Test 3: Frontend ──
echo "── Test 3: Web Frontend ──"
FRONTEND=$(curl -sf --max-time 5 "http://${FRONTEND_HOST}:${FRONTEND_PORT}" 2>/dev/null || echo "")
if [ -n "$FRONTEND" ]; then
  pass "Frontend is reachable at ${FRONTEND_HOST}:${FRONTEND_PORT}"
  if echo "$FRONTEND" | grep -qi "final\|evolution\|fel\|root"; then
    pass "Frontend HTML loads correctly"
  else
    warn "Frontend loads but content may not match expected"
  fi
else
  fail "Frontend not reachable at ${FRONTEND_HOST}:${FRONTEND_PORT}"
fi
echo ""

# ── Test 4: WebSocket Connectivity ──
echo "── Test 4: WebSocket Connectivity ──"
WS_RESULT=$(timeout 10 python3 << 'PYEOF' 2>&1 || echo "ERROR:timeout or python failed"
import asyncio, json, sys
try:
    import websockets
except ImportError:
    print('SKIP:websockets not installed')
    sys.exit(0)

async def test_ws():
    try:
        async with websockets.connect('ws://localhost:8888', open_timeout=5, close_timeout=2) as ws:
            msg = await asyncio.wait_for(ws.recv(), timeout=5)
            data = json.loads(msg)
            if data.get('type') == 'playerConnected' and data.get('playerId'):
                print(f'OK:playerId={data["playerId"]}')
            else:
                print(f'UNEXPECTED:{msg[:100]}')
    except Exception as e:
        print(f'ERROR:{e}')

asyncio.run(test_ws())
PYEOF
)

if [[ "$WS_RESULT" == OK:* ]]; then
  pass "WebSocket connection established, received playerConnected"
  info "Player ID: ${WS_RESULT#OK:playerId=}"
elif [[ "$WS_RESULT" == SKIP:* ]]; then
  warn "Skipped WebSocket test (websockets library not installed: pip install websockets)"
else
  fail "WebSocket connection failed: $WS_RESULT"
fi
echo ""

# ── Test 5: TURN Server ──
echo "── Test 5: TURN/STUN Server ──"
if nc -z -w2 "${TURN_HOST}" "${TURN_PORT}" 2>/dev/null; then
  pass "TURN server is reachable at ${TURN_HOST}:${TURN_PORT}"
else
  warn "TURN server not reachable at ${TURN_HOST}:${TURN_PORT} (expected if coturn not running)"
fi
echo ""

# ── Test 6: Docker Services ──
echo "── Test 6: Docker Services ──"
if command -v docker &>/dev/null; then
  pass "Docker installed: $(docker --version 2>/dev/null | head -1)"
  if docker compose version &>/dev/null 2>&1; then
    pass "Docker Compose available"
  else
    warn "Docker Compose not available"
  fi
else
  warn "Docker not installed"
fi
echo ""

# ── Test 7: Build Artifacts ──
echo "── Test 7: Build Artifacts ──"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

if [ -d "$PROJECT_ROOT/streaming/frontend/dist" ]; then
  pass "Frontend production build exists"
  FILE_COUNT=$(find "$PROJECT_ROOT/streaming/frontend/dist" -type f | wc -l)
  info "Build contains $FILE_COUNT files"
else
  fail "Frontend production build not found (run: cd streaming/frontend && npm run build)"
fi

if [ -f "$PROJECT_ROOT/UnrealStarter/BasketballGame/Source/FinalEvolutionLab/FELGeneratedAssetPaths.h" ]; then
  ASSET_COUNT=$(grep -c 'static const TCHAR' "$PROJECT_ROOT/UnrealStarter/BasketballGame/Source/FinalEvolutionLab/FELGeneratedAssetPaths.h" || echo "0")
  pass "UE Asset Paths header exists with $ASSET_COUNT asset references"
else
  fail "FELGeneratedAssetPaths.h not found"
fi

if [ -f "$PROJECT_ROOT/GeneratedAssets/pipeline_report.json" ]; then
  pass "AI pipeline report exists"
else
  warn "AI pipeline report not found"
fi
echo ""

# ── Summary ──
echo "══════════════════════════════════════════════════════"
TOTAL=$((PASS + FAIL + WARN))
echo -e "Results: ${GREEN}${PASS} passed${NC}, ${RED}${FAIL} failed${NC}, ${YELLOW}${WARN} warnings${NC} (${TOTAL} total)"
if [ "$FAIL" -eq 0 ]; then
  echo -e "${GREEN}All critical tests passed!${NC}"
  exit 0
else
  echo -e "${RED}Some tests failed — see details above.${NC}"
  exit 1
fi
