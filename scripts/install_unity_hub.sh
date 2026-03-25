#!/usr/bin/env bash
# Installs Unity Hub via Homebrew. Editor + iOS/Mac modules must be added in Unity Hub (or hub CLI with license).
set -euo pipefail

if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew not found. Install from https://brew.sh then re-run." >&2
  exit 1
fi

echo "Installing Unity Hub (cask)..."
brew install --cask unity-hub

cat <<'EOF'

Next steps (manual — Apple/Unity licensing):
  1) Open Unity Hub → Installs → Install Editor → choose the version matching your project (this repo's UnityProject uses 6000.x per ProjectSettings/ProjectVersion.txt), or 2022.3 LTS if you use an older branch.
  2) Add modules: iOS Build Support, Mac Build Support (match your IL2CPP/Mono template).
  3) Create or open your URP project; export iOS build with Unity as a Library when integrating with this Swift app.

CLI reference (optional, requires Hub + auth): see Unity documentation for 'hub' command-line installs.

EOF
