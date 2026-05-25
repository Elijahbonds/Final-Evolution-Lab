#!/usr/bin/env bash
# =============================================================================
# prepare_fel_bridge.sh
# Merge Emergent DefaultGame snippet + optionally copy FELFELBridge sources into a UE project.
#
# Prerequisites: PROJECT_DIR = UE project folder (contains Config/DefaultGame.ini and .uproject).
#
# Usage:
#   PROJECT_DIR="/path/to/FinalEvolutionLab 5.7" ./prepare_fel_bridge.sh
#   PROJECT_DIR="..." ./prepare_fel_bridge.sh --copy-sources
#
# Env:
#   FEL_MERGE_SNIPPET=0   skip Appending DefaultGame.FEL_Bridge.snippet.ini (default: merge if [FELBridge] absent)
#
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
SNIPPET="$REPO_ROOT/UnrealIntegration/Config/DefaultGame.FEL_Bridge.snippet.ini"
INTEGRATION_SRC="$REPO_ROOT/UnrealIntegration/Source/FinalEvolutionLab"

die() { echo "ERROR: $*" >&2; exit 1; }

COPY_SOURCES=0
MERGE_SNIPPET="${FEL_MERGE_SNIPPET:-1}"

for arg in "$@"; do
  [[ "$arg" == "--copy-sources" ]] && COPY_SOURCES=1
done

PROJECT_DIR="${PROJECT_DIR:-}"
[[ -n "$PROJECT_DIR" ]] || die "Set PROJECT_DIR to your Unreal project root (directory with Config/ and *.uproject)."

PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"
[[ -d "$PROJECT_DIR/Config" ]] || die "Missing Config/: $PROJECT_DIR"

[[ -f "$SNIPPET" ]] || die "Missing snippet: $SNIPPET"

merge_emergent_ini() {
  [[ "$MERGE_SNIPPET" == "1" ]] || {
    echo "(FEL_MERGE_SNIPPET=0 — skipping snippet merge)"
    return 0
  }
  local dg="$PROJECT_DIR/Config/DefaultGame.ini"
  [[ -f "$dg" ]] || touch "$dg"

  if grep -q '^\[Emergent\]' "$dg" 2>/dev/null; then
    echo ">>> DefaultGame.ini already has [FELBridge]; not appending snippet."
    echo "    Compare with repo reference: $SNIPPET"
    return 0
  fi

  {
    echo ""
    echo "; --- FEL Emergent — merged by prepare_fel_bridge.sh ($(date -u +%Y-%m-%dT%H:%MZ)) ---"
    cat "$SNIPPET"
  } >>"$dg"

  echo ">>> Appended [FELBridge] block to $dg"
}

merge_emergent_ini

if [[ "$COPY_SOURCES" == "1" ]]; then
  [[ -d "$INTEGRATION_SRC" ]] || die "Missing integration sources: $INTEGRATION_SRC"
  mkdir -p "$PROJECT_DIR/Source/FinalEvolutionLab"
  # shellcheck disable=SC2086
  cp -rv "$INTEGRATION_SRC"/* "$PROJECT_DIR/Source/FinalEvolutionLab/"
  echo ">>> Copied bridge sources recursively → $PROJECT_DIR/Source/FinalEvolutionLab/"
  echo ">>> Next: confirm FinalEvolutionLab.Build.cs includes WebSockets + Json; enable WebSockets plugin."
fi

echo ""
echo "=== Emergent checklist ==="
echo "  • Full iOS cook (bCookAll + all venue maps): PROJECT_DIR=\"$PROJECT_DIR\" $REPO_ROOT/prepare_fel_full_ship.sh"
echo "  • Config: $PROJECT_DIR/Config/DefaultGame.ini → [FELBridge] GameWebSocketUrl (or leave empty)."
echo "  • Runtime override: FEL_GAME_WS_URL=wss://host/ws/game/roomId"
echo "  • Pixel Streaming 2 (E3DS): merge UnrealStarter/BasketballGame/Config/DefaultEngine.pixelstreaming2.snippet.ini → DefaultEngine.ini"
echo "  • Venue registry: copy UnrealStarter/BasketballGame/Config/FEL_VenueRegistry.production.json beside Config/"
echo ""
