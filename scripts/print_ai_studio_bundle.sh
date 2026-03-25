#!/usr/bin/env bash
# Regenerate and print the full bundle to stdout (pipe to pbcopy on macOS: ./scripts/print_ai_studio_bundle.sh | pbcopy)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
python3 scripts/generate_ai_studio_bundle.py
cat "$ROOT/AI_STUDIO_FEL_ARCHITECTURE_BUNDLE.md"
