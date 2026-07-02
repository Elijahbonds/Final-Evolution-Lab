#!/usr/bin/env bash
# FEL NEXUS Spec v1 — integration smoke (macOS dev host)
# Usage: ./scripts/smoke_v1.sh [--skip-build]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${ROOT}/build-full"
SKIP_BUILD=0

for arg in "$@"; do
  case "$arg" in
    --skip-build) SKIP_BUILD=1 ;;
    -h|--help)
      echo "Usage: $0 [--skip-build]"
      exit 0
      ;;
  esac
done

cd "$ROOT"

if [[ "$SKIP_BUILD" -eq 0 ]]; then
  echo "==> Configure + build"
  cmake -S . -B "$BUILD_DIR" -DNEXUS_ENABLE_RENDERER=ON
  cmake --build "$BUILD_DIR" -j"$(sysctl -n hw.ncpu 2>/dev/null || nproc)"
fi

echo "==> ctest"
ctest --test-dir "$BUILD_DIR" --output-on-failure

echo "==> Venue mesh validate (manifest + mobile LOD decimation)"
cd "$ROOT"
BUILD_DIR="$BUILD_DIR" "$ROOT/scripts/nexus_validate_production_modes.sh"

echo "==> Headless gameplay: production mode agent/HUD contracts"
"$BUILD_DIR/nexus_gameplay_test" >/dev/null
echo "    nexus_gameplay_test OK (includes all production runtime mode probes)"

cat <<'QA'

==> Manual agent TCP QA (optional — start runtime first)
    ./build-full/nexus_runtime --mode basketball_dunk

    # Session
    {"type":"command","id":"1","payload":{"command":"fel.arena.start_session","params":{"mode_id":"basketball_dunk","user_id":"smoke"}}}

    # Dunk loop
    {"type":"command","id":"2","payload":{"command":"fel.dunk.charge_begin","params":{}}}
    {"type":"command","id":"3","payload":{"command":"fel.dunk.charge_release","params":{"power":0.9}}}
    {"type":"command","id":"4","payload":{"command":"fel.dunk.apex_tap","params":{}}}

    # State / receipt
    {"type":"query","id":"5","payload":{"query":"fel.query.get_mode_state"}}
    {"type":"query","id":"6","payload":{"query":"fel.query.get_pending_session_receipts"}}

    # Karate
    {"type":"command","id":"7","payload":{"command":"fel.arena.start_session","params":{"mode_id":"karate_endless","user_id":"smoke"}}}
    {"type":"command","id":"8","payload":{"command":"fel.karate.action","params":{"action":"heavy_strike"}}}

QA

echo "==> smoke_v1 PASS"
echo ""
echo "Optional: Cursor playtest artifacts → ./scripts/nexus_playtest.sh --skip-build"
