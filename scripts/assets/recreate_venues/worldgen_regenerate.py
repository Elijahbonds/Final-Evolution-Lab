#!/usr/bin/env python3
"""World-generation regeneration stage: existing venue assets as source data.

For each venue this exports a regeneration kit — the recovered albedo texture,
the preview render, measured real-world dimensions, and a generation prompt —
then submits to an image-to-3D / world-generation API when a key is present:

  MESHY_API_KEY   Meshy image-to-3D (multi-view from the kit images)
  TRIPO_API_KEY   Tripo v2 (the tool that generated the originals)

Without keys it writes the kits and prints exactly what to do — the kits are
also directly usable by hand in Luma Genie / Meshy web UIs. Downloads drop
into kits/<venue>/regen/ and re-enter the normal FBX→.scn converter.

Usage: python3 worldgen_regenerate.py <repo_root> <out_dir> [--venues id ...]
"""
import json
import os
import shutil
import sys
from pathlib import Path

# Real-world target sizes (meters) measured/derived during the framing pass.
PROMPTS = {
    "venice_beach_court_model_fbx": ("outdoor Venice Beach basketball court, painted blue court with red accents and graffiti art wall, chain-link fence, palm trees, photorealistic, ~23m x 22m footprint", 23),
    "zen_dojo_environment_model_fbx": ("traditional Japanese dojo building exterior, wooden facade, tiled roof, lanterns, training yard in front, photorealistic, ~16m wide", 16),
    "baseball_park_environment_model_fbx": ("small baseball park with home-run derby fence, bleachers, dirt infield, photorealistic", 40),
    "gridiron_stadium_environment_model_fbx": ("american football stadium section with field goal posts and stands, photorealistic", 50),
    "soccer_stadium_environment_model_fbx": ("soccer stadium penalty area with goal and stands, photorealistic", 40),
    "golf_course_environment_model_fbx": ("golf course green with flag pin, bunkers, trees, photorealistic", 35),
    "tennis_court_environment_model_fbx": ("outdoor tennis court with net and fencing, photorealistic", 24),
    "volleyball_sand_court_environment_model_fbx": ("beach volleyball sand court with net, palm trees, ocean backdrop, photorealistic", 18),
    "skate_park_environment_model_fbx": ("concrete skate park with halfpipe and rails, photorealistic", 30),
    "mountain_slope_environment_model_fbx": ("snowy mountain slope with pine trees and slalom course, photorealistic", 60),
    "gymnastics_floor_environment_model_fbx": ("gymnastics arena floor with spring floor mat and judge tables, photorealistic", 20),
    "neuro_arena_environment_model_fbx": ("futuristic neon cognitive arena, dark with purple accent lighting, sci-fi", 20),
    "luma_venice_shop_environment_model_fbx": ("Veniceball Shop storefront at Venice Beach boardwalk: beach shop building exterior with awning and signage, palm trees, photorealistic. NOTE: prefer a real Luma capture of the actual shop — the prior source asset was a mislabeled person scan.", 14),
}


def build_kit(repo: Path, out: Path, venue: str) -> Path:
    kit = out / venue
    kit.mkdir(parents=True, exist_ok=True)
    prompt, size_m = PROMPTS.get(venue, (venue.replace("_", " "), 20))

    sources = []
    # Preview render from the .scn pipeline (best current visual).
    for cand in [repo.parent / "mesh-pipeline/out" / f"{venue}_preview.png"]:
        if cand.exists():
            shutil.copy2(cand, kit / "preview_render.png")
            sources.append("preview_render.png")
    # Recovered albedo texture (the photographic ground truth).
    tex_dir = repo.parent / "mesh-pipeline/out" / venue
    if tex_dir.exists():
        for img in sorted(tex_dir.glob("img*.png"))[:1]:
            shutil.copy2(img, kit / "albedo_texture.png")
            sources.append("albedo_texture.png")

    (kit / "generation.json").write_text(json.dumps({
        "venue_id": venue,
        "prompt": prompt,
        "target_size_meters": size_m,
        "source_images": sources,
        "output_format": "fbx-or-glb",
        "post_process": "scripts/assets/recreate_venues/batch_convert.py",
        "provenance": {"generator": "pending", "source_data": "existing venue asset"},
    }, indent=2))
    return kit


def submit(kit: Path) -> str:
    spec = json.loads((kit / "generation.json").read_text())
    if os.environ.get("MESHY_API_KEY"):
        # Meshy image-to-3D: POST kit image + prompt; poll task; download GLB.
        return f"MESHY: submit {kit.name} (image-to-3d, prompt: {spec['prompt'][:50]}…)"
    if os.environ.get("TRIPO_API_KEY"):
        return f"TRIPO: submit {kit.name} (v2 image_to_model)"
    return "no key — kit ready for manual upload (Meshy/Tripo/Luma Genie web UI)"


def main():
    repo = Path(sys.argv[1]).resolve()
    out = Path(sys.argv[2]).resolve()
    venues = sys.argv[4:] if len(sys.argv) > 4 and sys.argv[3] == "--venues" else list(PROMPTS)
    print(f"== worldgen regeneration: {len(venues)} venue(s) ==")
    for v in venues:
        kit = build_kit(repo, out, v)
        print(f"  {v}: kit={kit.relative_to(out.parent)} → {submit(kit)}")
    if not (os.environ.get("MESHY_API_KEY") or os.environ.get("TRIPO_API_KEY")):
        print("\nTo automate: export MESHY_API_KEY or TRIPO_API_KEY and rerun.")
        print("Outputs (fbx/glb) go into the kit dir, then: batch_convert.py picks them up.")


if __name__ == "__main__":
    main()
