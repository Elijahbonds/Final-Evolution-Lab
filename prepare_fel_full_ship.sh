#!/usr/bin/env bash
# =============================================================================
# prepare_fel_full_ship.sh
# Merge **full sideload ship** packaging into a UE project's DefaultGame.ini:
# bCookAll, MapsToCook, EmergentPlayMap, EmergentHubDiscovery, FELFeaturedMode.
#
# Uses infra/ue5_config/DefaultGame.ini as the canonical merged reference — copies the
# shipment-specific sections into your live Config without overwriting an existing
# [Emergent] block (your hub URL / secrets stay yours).
#
# Usage:
#   PROJECT_DIR="/path/to/FinalEvolutionLab 5.7" ./prepare_fel_full_ship.sh
#
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
REF_MERGED="$REPO_ROOT/infra/ue5_config/DefaultGame.ini"

die() { echo "ERROR: $*" >&2; exit 1; }

PROJECT_DIR="${PROJECT_DIR:-}"
[[ -n "$PROJECT_DIR" ]] || die "Set PROJECT_DIR to your Unreal project root (directory with Config/)."
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"
[[ -d "$PROJECT_DIR/Config" ]] || die "Missing Config/: $PROJECT_DIR"
[[ -f "$REF_MERGED" ]] || die "Missing reference: $REF_MERGED"

DG="$PROJECT_DIR/Config/DefaultGame.ini"
[[ -f "$DG" ]] || touch "$DG"

extract_ship_sections() {
  awk '/^\[\/Script\/UnrealEd.ProjectPackagingSettings\]/ { ok=1 } ok' "$REF_MERGED"
}

if grep -q '^\[/Script/UnrealEd.ProjectPackagingSettings\]' "$DG" 2>/dev/null \
  && grep -q '^bCookAll=True' "$DG" 2>/dev/null; then
  echo ">>> $DG already has ProjectPackagingSettings + bCookAll=True — not appending ship sections."
  echo "    Diff against reference: $REF_MERGED"
  exit 0
fi

{
  echo ""
  echo "; --- FEL full ship — merged by prepare_fel_full_ship.sh ($(date -u +%Y-%m-%dT%H:%MZ)) ---"
  extract_ship_sections
} >>"$DG"

echo ">>> Appended full ship packaging + EmergentPlayMap + hub discovery + FELFeaturedMode to:"
echo "    $DG"
echo ">>> Next: open UE → Project Settings → Packaging (confirm), then iOS cook/archive."
