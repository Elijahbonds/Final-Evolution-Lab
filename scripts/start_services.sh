#!/usr/bin/env bash
# Final Evolution Lab — Start All Services
# Starts signalling server and frontend for development/testing

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "=== Final Evolution Lab — Starting Services ==="
echo ""

# Kill existing instances
for port in 8888 8889 3000; do
  PID=$(lsof -ti :$port 2>/dev/null || true)
  if [ -n "$PID" ]; then
    echo "Stopping existing process on port $port (PID: $PID)"
    kill $PID 2>/dev/null || true
    sleep 1
  fi
done

# Start Signalling Server
echo "Starting Signalling Server on :8888 (streamer :8889)..."
cd "$PROJECT_ROOT/streaming/signalling"
if [ ! -d node_modules ]; then
  echo "Installing signalling dependencies..."
  npm install --production
fi
nohup node server.js > /tmp/fel-signalling.log 2>&1 &
SIG_PID=$!
echo "  Signalling PID: $SIG_PID"
sleep 2

# Verify signalling
if curl -sf http://localhost:8888/healthz > /dev/null 2>&1; then
  echo "  ✓ Signalling server healthy"
else
  echo "  ✗ Signalling server failed to start"
  exit 1
fi

# Build & Serve Frontend
echo ""
echo "Building and starting Frontend on :3000..."
cd "$PROJECT_ROOT/streaming/frontend"
if [ ! -d node_modules ]; then
  echo "Installing frontend dependencies..."
  npm install
fi
if [ ! -d dist ] || [ package.json -nt dist/index.html ]; then
  echo "Building frontend..."
  npm run build
fi
nohup npx serve dist -l 3000 --cors > /tmp/fel-frontend.log 2>&1 &
FE_PID=$!
echo "  Frontend PID: $FE_PID"
sleep 2

# Verify frontend
if curl -sf http://localhost:3000 > /dev/null 2>&1; then
  echo "  ✓ Frontend serving correctly"
else
  echo "  ✗ Frontend failed to start"
  exit 1
fi

echo ""
echo "══════════════════════════════════════════════════════"
echo "✅ All services running!"
echo ""
echo "  Frontend:        http://localhost:3000"
echo "  Signalling WS:   ws://localhost:8888"
echo "  Health Check:    http://localhost:8888/healthz"
echo "  Modes API:       http://localhost:8888/api/modes"
echo "  Streamer Port:   8889 (for UE5 connection)"
echo ""
echo "  Logs:"
echo "    Signalling:  tail -f /tmp/fel-signalling.log"
echo "    Frontend:    tail -f /tmp/fel-frontend.log"
echo ""
echo "  To stop: kill $SIG_PID $FE_PID"
echo "══════════════════════════════════════════════════════"
