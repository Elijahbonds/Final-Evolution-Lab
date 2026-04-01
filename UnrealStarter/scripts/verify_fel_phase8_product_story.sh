#!/usr/bin/env bash
# Phase 8 — Unified product story strings and UNREAL_ONLY convergence paragraph.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
UO="$ROOT/UNREAL_ONLY.md"
PREF="$ROOT/ios/FinalEvolutionLab/Models/FELArenaRuntimePreference.swift"
GPV="$ROOT/ios/FinalEvolutionLab/Views/GamePlayView.swift"
SET="$ROOT/ios/FinalEvolutionLab/Views/SettingsSheet.swift"

for f in "$UO" "$PREF" "$GPV" "$SET"; do
  if [[ ! -f "$f" ]]; then
    echo "verify_fel_phase8_product_story: missing $f" >&2
    exit 1
  fi
done

grep -q "Dual track until convergence" "$UO" || { echo "UNREAL_ONLY convergence section missing"; exit 1; }
grep -q "Lightweight Arena (native)" "$PREF" || { echo "FELArenaRuntimePreference native title missing"; exit 1; }
grep -q "Full Simulation (Unreal)" "$PREF" || { echo "FELArenaRuntimePreference Unreal title missing"; exit 1; }
grep -q "Full simulation (Unreal):" "$GPV" || { echo "GamePlayView banner copy missing"; exit 1; }
grep -q "Arena experience" "$SET" || { echo "Settings Arena experience label missing"; exit 1; }
grep -q "Two experiences:" "$SET" || { echo "Settings Phase 8 footer missing"; exit 1; }

echo "verify_fel_phase8_product_story: OK"
