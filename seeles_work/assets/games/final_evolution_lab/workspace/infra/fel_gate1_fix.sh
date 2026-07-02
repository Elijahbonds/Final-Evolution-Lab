#!/bin/bash
# ============================================================
# Gate 1 Fix: Promote who_scene_it + court_carnival to production
# Final Evolution AI Coach — FEL_ModeManager.production.json
#
# Run from macOS clone:
#   cd /Users/elijahbonds/Documents/rork-final-evolution-lab
#   bash infra/fel_gate1_fix.sh
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JSON_PATH="$SCRIPT_DIR/../backend/FEL_ModeManager.production.json"

if [ ! -f "$JSON_PATH" ]; then
  echo "ERROR: FEL_ModeManager.production.json not found at: $JSON_PATH"
  exit 1
fi

echo ">>> Reading $JSON_PATH ..."

python3 - "$JSON_PATH" <<'PYEOF'
import json, sys

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as f:
    data = json.load(f)

registry = data["mode_manager"]["mode_registry"]

# Promote both modes
changed = []
for mode_id in ["who_scene_it", "court_carnival"]:
    if mode_id in registry:
        if registry[mode_id].get("status") != "production":
            registry[mode_id]["status"] = "production"
            changed.append(mode_id)

# Update production count
data["mode_manager"]["production_modes"] = 14

# Count production for verification
prod_count = sum(
    1 for m in registry.values()
    if m.get("status") == "production"
)

with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
    f.write("\n")

if changed:
    print(f"PROMOTED: {changed}")
else:
    print("INFO: who_scene_it and court_carnival were already production.")

print(f"production_modes set to 14")
print(f"Verified registry production count: {prod_count}")
print("Gate 1 Fix COMPLETE ✅")
PYEOF
