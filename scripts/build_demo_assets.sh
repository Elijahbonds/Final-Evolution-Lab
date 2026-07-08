#!/usr/bin/env bash
# FEL demo asset builder — curates the raw downloads pulled by
# scripts/fetch_assets.sh into the small (<1MB each) committed demo assets
# consumed by the Brain Brawl / Who Scene It web demos, then records sha256
# for every emitted file in infra/ASSET_CHECKSUMS.json.
#
# Sources (see infra/asset_sources.json + infra/ASSET_ATTRIBUTION.md):
#   audio     Kenney Interface Sounds (CC0)  + Yo Frankie! applause (CC-BY 3.0)
#   icons     game-icons.net SVGs (CC-BY 3.0)
#   backdrops Poly Haven tonemapped HDRI renders (CC0)
#   vfx       Kenney Particle Pack (CC0) -> celebration sprite sheet
#
# Usage: scripts/build_demo_assets.sh   (run scripts/fetch_assets.sh first)
#
# Determinism: all outputs are byte-reproducible from the pinned raw downloads
# EXCEPT audio/crowd_cheer.m4a (AAC container embeds encode metadata) and
# assets/mock/opentdb_questions.json (random API draw + timestamp) — for those
# two, infra/ASSET_CHECKSUMS.json pins the COMMITTED file, so expect new
# hashes when you deliberately rebuild/refresh them.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EXT="$ROOT/assets/external"
DEMO="$ROOT/assets/demo"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
missing=0
need() { [ -e "$1" ] || { echo "MISSING: $1 (run scripts/fetch_assets.sh)"; missing=1; }; }
need "$EXT/audio/kenney_interfaceSounds.zip"
need "$EXT/audio/applause.wav"
need "$EXT/vfx/kenney_particlePack.zip"
need "$EXT/backdrop/music_hall_01.jpg"
need "$EXT/backdrop/theater_01.jpg"
need "$EXT/ui_icon/stopwatch.svg"
[ "$missing" = "0" ] || exit 1
mkdir -p "$DEMO/audio" "$DEMO/icons" "$DEMO/backdrops" "$DEMO/vfx"

# --- 1. UI SFX: curated Kenney Interface Sounds clips (already OGG) --------
unzip -oq "$EXT/audio/kenney_interfaceSounds.zip" 'Audio/*' -d "$TMP/sfx"
while IFS=: read -r src dst; do
  cp "$TMP/sfx/Audio/$src" "$DEMO/audio/$dst"
done <<'MAP'
confirmation_001.ogg:correct_ding.ogg
confirmation_002.ogg:celebrate_chime.ogg
error_004.ogg:wrong_buzz.ogg
error_006.ogg:buzzer.ogg
tick_001.ogg:countdown_tick.ogg
question_001.ogg:question_sting.ogg
glass_005.ogg:reveal_sting.ogg
click_001.ogg:ui_confirm.ogg
MAP

# --- 2. Crowd stinger: Yo Frankie! applause WAV -> AAC .m4a (<1MB) --------
if command -v afconvert >/dev/null; then
  afconvert -f m4af -d aac -b 96000 "$EXT/audio/applause.wav" \
            "$DEMO/audio/crowd_cheer.m4a" || echo "afconvert failed"
  afinfo "$DEMO/audio/crowd_cheer.m4a" | grep -qi aac || echo "WARN: crowd_cheer.m4a not AAC"
else
  echo "afconvert not found (macOS-only); manual: ffmpeg -i applause.wav -b:a 96k crowd_cheer.m4a"
fi

# --- 3. UI icons: game-icons.net SVGs, logical names -----------------------
while IFS=: read -r src dst; do
  cp "$EXT/ui_icon/$src" "$DEMO/icons/$dst"
done <<'MAP'
stopwatch.svg:timer.svg
ringing-bell.svg:buzzer.svg
check-mark.svg:correct.svg
cross-mark.svg:wrong.svg
flame.svg:streak.svg
podium.svg:podium.svg
trophy-cup.svg:trophy.svg
MAP

# --- 4. Stage backdrops: downscale Poly Haven tonemapped JPGs to <1MB ------
if command -v sips >/dev/null; then
  sips -Z 1920 -s format jpeg -s formatOptions 78 \
       "$EXT/backdrop/music_hall_01.jpg" --out "$DEMO/backdrops/stage_music_hall.jpg" >/dev/null
  sips -Z 1920 -s format jpeg -s formatOptions 78 \
       "$EXT/backdrop/theater_01.jpg" --out "$DEMO/backdrops/stage_theater.jpg" >/dev/null
else
  python3 - "$EXT/backdrop" "$DEMO/backdrops" <<'PY'
import pathlib, sys
from PIL import Image  # fallback when sips (macOS) is unavailable
src, dst = map(pathlib.Path, sys.argv[1:3])
for name, out in [("music_hall_01.jpg", "stage_music_hall.jpg"),
                  ("theater_01.jpg", "stage_theater.jpg")]:
    im = Image.open(src / name); im.thumbnail((1920, 1920))
    im.save(dst / out, "JPEG", quality=78, optimize=True)
PY
fi

# --- 5. Celebration particle sprite sheet (Kenney Particle Pack) -----------
unzip -oq "$EXT/vfx/kenney_particlePack.zip" 'PNG/*' -d "$TMP/vfx"
python3 - "$TMP/vfx/PNG" "$DEMO/vfx" <<'PY'
import json, pathlib, sys
from PIL import Image
src, dst = map(pathlib.Path, sys.argv[1:3])
frames = ["star_01", "star_05", "star_09", "spark_04",
          "spark_05", "light_02", "magic_01", "twirl_02"]
cell, cols = 256, 4
sheet = Image.new("RGBA", (cell * cols, cell * ((len(frames) + cols - 1) // cols)))
meta = {"cell": cell, "columns": cols, "source": "Kenney Particle Pack (CC0)",
        "frames": {}}
for i, name in enumerate(frames):
    im = Image.open(src / f"{name}.png").convert("RGBA")
    im.thumbnail((cell, cell))
    x, y = (i % cols) * cell, (i // cols) * cell
    sheet.paste(im, (x + (cell - im.width) // 2, y + (cell - im.height) // 2))
    meta["frames"][name] = {"x": x, "y": y, "w": cell, "h": cell}
sheet.save(dst / "celebration_particles.png", optimize=True)
(dst / "celebration_particles.json").write_text(json.dumps(meta, indent=2) + "\n")
print(f"sprite sheet -> {dst/'celebration_particles.png'} "
      f"({(dst/'celebration_particles.png').stat().st_size} bytes, {len(frames)} frames)")
PY

# --- 6. Checksums + size gate for every committed demo asset ---------------
python3 - "$ROOT" <<'PY'
import hashlib, json, pathlib, sys
root = pathlib.Path(sys.argv[1])
checks_path = root / "infra/ASSET_CHECKSUMS.json"
checks = json.load(open(checks_path))
src = {e.get("asset_name", ""): e for e in json.load(open(root / "infra/asset_sources.json"))["sources"]}
ATTR = {
    "audio/crowd_cheer.m4a": ("https://opengameart.org/content/applause",
                              "CC-BY 3.0 (Blender Foundation, Yo Frankie! project)"),
    "icons/timer.svg": ("https://game-icons.net/1x1/lorc/stopwatch.html", "CC-BY 3.0 (Lorc, game-icons.net)"),
    "icons/buzzer.svg": ("https://game-icons.net/1x1/lorc/ringing-bell.html", "CC-BY 3.0 (Lorc, game-icons.net)"),
    "icons/correct.svg": ("https://game-icons.net/1x1/delapouite/check-mark.html", "CC-BY 3.0 (Delapouite, game-icons.net)"),
    "icons/wrong.svg": ("https://game-icons.net/1x1/lorc/cross-mark.html", "CC-BY 3.0 (Lorc, game-icons.net)"),
    "icons/streak.svg": ("https://game-icons.net/1x1/carl-olsen/flame.html", "CC-BY 3.0 (Carl Olsen, game-icons.net)"),
    "icons/podium.svg": ("https://game-icons.net/1x1/delapouite/podium.html", "CC-BY 3.0 (Delapouite, game-icons.net)"),
    "icons/trophy.svg": ("https://game-icons.net/1x1/delapouite/trophy-cup.html", "CC-BY 3.0 (Delapouite, game-icons.net)"),
    "backdrops/stage_music_hall.jpg": ("https://polyhaven.com/a/music_hall_01", "CC0 1.0"),
    "backdrops/stage_theater.jpg": ("https://polyhaven.com/a/theater_01", "CC0 1.0"),
    "vfx/celebration_particles.png": ("https://opengameart.org/content/particle-pack-80-sprites", "CC0 1.0"),
    "vfx/celebration_particles.json": ("generated by scripts/build_demo_assets.sh", "n/a (frame metadata)"),
}
KENNEY_SFX = ("https://opengameart.org/content/interface-sounds", "CC0 1.0")
oversize = []
for f in sorted((root / "assets/demo").rglob("*")):
    if not f.is_file():
        continue
    rel = f.relative_to(root / "assets/demo").as_posix()
    url, lic = ATTR.get(rel, KENNEY_SFX if rel.startswith("audio/") else (None, None))
    if url is None:
        print(f"WARN: no attribution mapping for {rel}"); url, lic = "UNKNOWN", "UNKNOWN"
    checks["files"][f"assets/demo/{rel}"] = {
        "sha256": hashlib.sha256(f.read_bytes()).hexdigest(),
        "source_url": url, "license": lic}
    size = f.stat().st_size
    if size > 1_000_000:
        oversize.append((rel, size))
    print(f"  {rel:42s} {size/1024:8.1f} KB  {lic}")
checks_path.write_text(json.dumps(checks, indent=2) + "\n")
if oversize:
    print("FAIL: demo assets over 1MB:", oversize); sys.exit(1)
print("checksums updated ->", checks_path)
PY
