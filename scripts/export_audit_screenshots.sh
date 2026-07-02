#!/usr/bin/env bash
# Build + run screenshot UITests, export PNG attachments, and rename for docs/audit.
#
# Usage:
#   ./scripts/export_audit_screenshots.sh
#   DESTINATION='platform=iOS Simulator,name=iPhone 17,OS=latest' ./scripts/export_audit_screenshots.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUT="$ROOT/docs/audit/screenshots"
RAW="$OUT/_raw"

SCHEME="${SCHEME:-FinalEvolutionLab}"
DESTINATION="${DESTINATION:-platform=iOS Simulator,name=iPhone 17,OS=latest}"

mkdir -p "$RAW"

echo "== Export audit screenshots =="
cd "$ROOT"

xcodebuild \
  -scheme "$SCHEME" \
  -destination "$DESTINATION" \
  -only-testing:FinalEvolutionLabUITests/GameModeScreenshotUITests \
  -resultBundlePath "$RAW/TestResults.xcresult" \
  test

xcrun xcresulttool export attachments \
  --path "$RAW/TestResults.xcresult" \
  --output-path "$RAW"

python3 - "$RAW" "$OUT" <<'PY'
import json, os, re, shutil, sys
raw_dir, out_dir = sys.argv[1:3]
manifest = os.path.join(raw_dir, "manifest.json")
if not os.path.isfile(manifest):
    raise SystemExit(f"Missing manifest: {manifest}")
with open(manifest) as f:
    data = json.load(f)
os.makedirs(out_dir, exist_ok=True)
for entry in data:
    for att in entry.get("attachments", []):
        src = os.path.join(raw_dir, att["exportedFileName"])
        if not os.path.isfile(src):
            continue
        suggested = att.get("suggestedHumanReadableName", att["exportedFileName"])
        base = re.sub(r"(_0_[0-9A-F-]+\.png)$", ".png", suggested, flags=re.I)
        dst = os.path.join(out_dir, base)
        shutil.copy2(src, dst)
        print(f"  {base}")
print(f"\nScreenshots in: {out_dir}")
PY

echo "Done."
