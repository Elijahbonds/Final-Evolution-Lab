#!/usr/bin/env bash
# Final Evolution Lab — Stop All Services

echo "=== Stopping FEL Services ==="

for port in 8888 8889 3000; do
  PIDS=$(lsof -ti :$port 2>/dev/null || true)
  if [ -n "$PIDS" ]; then
    echo "Stopping process(es) on port $port: $PIDS"
    echo "$PIDS" | xargs kill 2>/dev/null || true
  fi
done

# Also stop docker containers if any
if command -v docker &>/dev/null; then
  RUNNING=$(docker ps --format '{{.Names}}' 2>/dev/null | grep -c 'fel\|signalling\|coturn' || echo "0")
  if [ "$RUNNING" -gt 0 ]; then
    echo "Stopping FEL Docker containers..."
    cd "$(dirname "$0")/../streaming" && docker compose down 2>/dev/null || true
  fi
fi

echo "✅ All FEL services stopped."
