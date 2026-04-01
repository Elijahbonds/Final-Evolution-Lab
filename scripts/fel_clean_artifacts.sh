#!/usr/bin/env bash
# Remove Xcode / SwiftPM artifacts before a clean push or CI run (safe for repo; does not delete source).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "==> Removing DerivedData for FinalEvolutionLab (if present)"
rm -rf "${HOME}/Library/Developer/Xcode/DerivedData"/FinalEvolutionLab-* 2>/dev/null || true

echo "==> Removing SwiftPM local build dirs"
rm -rf .build .swiftpm 2>/dev/null || true

echo "==> Removing Xcode user-specific project state (optional; re-created by Xcode)"
find . -name xcuserdata -type d -exec rm -rf {} + 2>/dev/null || true
find . -name '*.xcuserstate' -delete 2>/dev/null || true

echo "==> Done. Repository tree is ready for a clean import or CI run (from repo root)."
