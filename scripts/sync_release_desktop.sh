#!/usr/bin/env bash
# Refresh ~/Desktop/FEL-Release-Reference from this repo (setup-healthkit).
# Shared docs come from release-reference/*.md; Desktop-specific files from release-reference/desktop-bundle/.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DEST="${DEST:-$HOME/Desktop/FEL-Release-Reference}"

mkdir -p "$DEST"

shopt -s nullglob
for f in "$REPO_ROOT/release-reference/"*.md; do
  base="$(basename "$f")"
  [[ "$base" == "README.md" ]] && continue
  cp -a "$f" "$DEST/"
done

# Canonical repo-root architecture lock (Windsurf / agents: read before shell or commerce changes).
if [[ -f "$REPO_ROOT/SHIPPING_ARCHITECTURE.md" ]]; then
  cp -a "$REPO_ROOT/SHIPPING_ARCHITECTURE.md" "$DEST/"
fi

cp -a "$REPO_ROOT/release-reference/desktop-bundle/"* "$DEST/"
echo ">>> Updated: $DEST"
echo "    Point Windsurf at: $DEST"
echo "    Repo clone path:   $(cat "$DEST/REPOSITORY_ROOT.txt")"
