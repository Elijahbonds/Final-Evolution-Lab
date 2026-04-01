#!/usr/bin/env bash
# Mirrors XCODE_CLEAN_AND_RUN.md — clean module cache / DerivedData so the next build is fully fresh.
# Run before Cmd+R when you need a deterministic Gold Master build (same as Xcode Clean + DerivedData delete).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FULL_PURGE="${FEL_DERIVED_DATA_FULL_PURGE:-0}"

echo "==> Final Evolution Lab — Xcode clean prep (root=$ROOT)"

if [[ "${FULL_PURGE}" == "1" ]]; then
  echo "    Mode: FULL purge of ~/Library/Developer/Xcode/DerivedData"
  rm -rf "${HOME}/Library/Developer/Xcode/DerivedData"
else
  echo "    Mode: project-scoped FinalEvolutionLab-* (set FEL_DERIVED_DATA_FULL_PURGE=1 for full DerivedData wipe)"
  rm -rf "${HOME}/Library/Developer/Xcode/DerivedData"/FinalEvolutionLab-* 2>/dev/null || true
fi

echo "==> Done. Next: quit Xcode (⌘Q), reopen ios/FinalEvolutionLab.xcodeproj, Product → Clean Build Folder (⇧⌘K), then Build (⌘B) / Run (⌘R)."
echo "    See XCODE_CLEAN_AND_RUN.md for the full checklist."
