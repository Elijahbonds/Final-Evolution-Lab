#!/usr/bin/env bash
# Phase 6 — Swift GameModeId strings ⊆ ArenaSettings.json keys; Unreal header lists canonical ids.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export ROOT
JSON="$ROOT/UnrealStarter/BasketballGame/Content/FEL/Config/ArenaSettings.json"
HDR="$ROOT/UnrealStarter/BasketballGame/Source/FinalEvolutionLab/FELArenaModeDefinitions.h"
SWIFT="$ROOT/ios/FinalEvolutionLab/Models/GameMode.swift"

for f in "$JSON" "$HDR" "$SWIFT"; do
  if [[ ! -f "$f" ]]; then
    echo "verify_fel_phase6_arena_modes: missing $f" >&2
    exit 1
  fi
done

python3 - "$JSON" "$SWIFT" <<'PY'
import json, re, sys
json_path, swift_path = sys.argv[1], sys.argv[2]
with open(json_path) as f:
    modes = set(json.load(f)["modes"].keys())
with open(swift_path) as f:
    text = f.read()
# GameModeId cases: `case name = "id"`
raw_cases = re.findall(r"case\s+\w+\s*=\s*\"([a-z0-9_]+)\"", text)
swift_ids = set(raw_cases)
missing = sorted(swift_ids - modes)
if missing:
    print("verify_fel_phase6_arena_modes: Swift GameModeId not in ArenaSettings.json:", missing)
    sys.exit(1)
print("verify_fel_phase6_arena_modes: Swift→JSON OK (%d ids)" % len(swift_ids))
PY

for id in basketball_h2h brain_brawl market_browse surfing skateboarding snowboarding; do
  grep -q "$id" "$HDR" || { echo "verify_fel_phase6_arena_modes: expected id in header: $id"; exit 1; }
done

grep -q "FELArenaDiagnosticsPreference" "$ROOT/ios/FinalEvolutionLab/Views/GamePlayView.swift" || {
  echo "verify_fel_phase6_arena_modes: GamePlayView diagnostics gate missing"; exit 1
}

echo "verify_fel_phase6_arena_modes: OK"
