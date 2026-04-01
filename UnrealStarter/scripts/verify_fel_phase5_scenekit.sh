#!/usr/bin/env bash
# Phase 5 — SceneKit arena scale: ensure ArenaSceneConfig + parameterized court lines exist.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GSF="$ROOT/ios/FinalEvolutionLab/Views/GameSceneFactory.swift"
CFG="$ROOT/ios/FinalEvolutionLab/Models/ArenaSceneConfig.swift"
for f in "$GSF" "$CFG"; do
  if [[ ! -f "$f" ]]; then
    echo "verify_fel_phase5_scenekit: missing $f" >&2
    exit 1
  fi
done
grep -q "enum ArenaSceneConfig" "$CFG" || { echo "ArenaSceneConfig enum missing"; exit 1; }
grep -q "arenaTwilightSkyGradientImage" "$CFG" || { echo "sky gradient helper missing"; exit 1; }
grep -q "addCourtLines(to scene: SCNScene, halfWidth: Float, halfDepth: Float)" "$GSF" || {
  echo "parameterized addCourtLines missing"; exit 1
}
grep -q "ArenaSceneConfig.BasketballH2H" "$GSF" || { echo "H2H config wiring missing"; exit 1; }
grep -q "ArenaSceneConfig.Basketball3v3" "$GSF" || { echo "3v3 config wiring missing"; exit 1; }
grep -q "ArenaSceneConfig.BasketballDunk" "$GSF" || { echo "Dunk config wiring missing"; exit 1; }
echo "verify_fel_phase5_scenekit: OK"
