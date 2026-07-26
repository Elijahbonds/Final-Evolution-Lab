#!/usr/bin/env bash
# conform_clips.sh — turn a folder of Meshy/DeepMotion exports into clips FEL
# can actually play.
#
#     bash tools/conform_clips.sh assets/incoming assets/ready/anim
#
# This is step 2 of the chain, and it is the step that silently kills
# everything when it is skipped. `tools/fel_conform.py` has existed since M65
# and — as far as I can tell — has never been run. This wraps it so running it
# is one command over a whole folder, and so the result is CHECKED rather than
# assumed.
#
# Requires Blender 4.x on PATH (or $BLENDER). Blender is not available in the
# CI container, so this cannot be exercised there; `tools/clip_check.mjs` runs
# anywhere and is what verifies the output.

set -euo pipefail

IN="${1:-assets/incoming}"
OUT="${2:-assets/ready/anim}"
BLENDER="${BLENDER:-blender}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v "$BLENDER" >/dev/null 2>&1; then
  cat >&2 <<'EOF'
[CONFORM] Blender not found.

  macOS:  brew install --cask blender
          export BLENDER=/Applications/Blender.app/Contents/MacOS/Blender
  Linux:  sudo snap install blender --classic

Blender is only needed ONCE PER FILE, on your machine, to rename bones and
strip the mesh. It is not a runtime dependency and nothing in the deployed
game touches it.
EOF
  exit 127
fi

if [ ! -d "$IN" ]; then
  echo "[CONFORM] no input folder at $IN — put your Meshy/DeepMotion exports there." >&2
  exit 1
fi

mkdir -p "$OUT"

shopt -s nullglob nocaseglob
files=("$IN"/*.fbx "$IN"/*.glb "$IN"/*.gltf)
shopt -u nocaseglob

if [ ${#files[@]} -eq 0 ]; then
  echo "[CONFORM] $IN has no .fbx/.glb/.gltf files. Nothing to do."
  exit 1
fi

echo "[CONFORM] ${#files[@]} file(s): $IN → $OUT"
fails=0

for f in "${files[@]}"; do
  base="$(basename "${f%.*}")"
  # The output name IS the clip id. Normalise it here so a file called
  # "Dunk Launch (1).fbx" cannot quietly become a clip nothing ever plays.
  id="$(echo "$base" | tr '[:upper:] ' '[:lower:]_' | sed -E 's/[^a-z0-9_]//g; s/_+/_/g; s/^_|_$//g')"
  dst="$OUT/$id.glb"

  echo "[CONFORM] $base → $id.glb"
  if ! "$BLENDER" --background --python "$HERE/fel_conform.py" -- \
        --input "$f" --output "$dst" --strip-mesh --json "$OUT/$id.report.json"; then
    echo "[CONFORM]   FAILED — see the Blender output above" >&2
    fails=$((fails + 1))
    continue
  fi
done

echo
echo "[CONFORM] verifying the output — this is the part that matters"
if ! node "$HERE/clip_check.mjs" "$OUT"; then
  echo "[CONFORM] conformed files did NOT pass the checker. Do not drop these." >&2
  exit 1
fi

if [ "$fails" -gt 0 ]; then
  echo "[CONFORM] $fails file(s) failed to convert." >&2
  exit 1
fi

cat <<EOF

[CONFORM] done. Next:
  1. Rename each file in $OUT to exactly the clip id it replaces
     (see anim/clipManifest.ts — 'run.glb', not 'running_v2.glb').
  2. Serve $OUT at /assets/ready/anim/.
  3. Load with:  node tools/clip_check.mjs $OUT   → must be all PASS.
EOF
