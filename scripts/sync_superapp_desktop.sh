#!/usr/bin/env bash
# Refresh ~/Desktop/FEL-Superapp-Reference from this repo (setup-healthkit).
# Shared docs come from superapp-reference/*.md; Desktop-specific files from superapp-reference/desktop-bundle/.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DEST="${DEST:-$HOME/Desktop/FEL-Superapp-Reference}"

mkdir -p "$DEST"

shopt -s nullglob
for f in "$REPO_ROOT/superapp-reference/"*.md; do
  base="$(basename "$f")"
  [[ "$base" == "README.md" ]] && continue
  cp -a "$f" "$DEST/"
done

cp -a "$REPO_ROOT/superapp-reference/desktop-bundle/"* "$DEST/"
echo ">>> Updated: $DEST"
echo "    Point Windsurf at: $DEST"
echo "    Repo clone path:   $(cat "$DEST/REPOSITORY_ROOT.txt")"
