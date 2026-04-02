#!/usr/bin/env python3
"""
OpenArt Enhanced Environment Pipeline.

Generates enhanced world assets for all 12 preset environments using the
OpenArt API client (with procedural fallback). Produces:
  • Props (12 per environment)
  • Textures (5 per environment)
  • PBR Material Sets (3 per environment × 5 maps each)
  • Atmospheric Overlays (3 per environment)
  • Skybox Variations (3 per environment)
  • Detail Decals (4 per environment)

All assets are organized into the project's GeneratedAssets/ tree and
tracked in an OpenArt-specific manifest for UE5 import.

Usage:
    python -m scripts.environment_gen.openart_enhanced_pipeline [options]

Options:
    --env ENV_KEY       Generate for a single environment only
    --category CAT      Generate a single category (props|textures|materials|atmosphere|skybox|details)
    --dry-run           Preview what would be generated without writing files
    --resolution N      Override default texture resolution (default: 1024)
    --quality PRESET    Quality preset: ultra|high|medium|mobile (default: high)
    --list              List all environments and asset counts
"""

import argparse
import json
import sys
import time
from pathlib import Path
from typing import Dict, List, Any, Optional

# Ensure project root is on sys.path
PROJECT_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(PROJECT_ROOT))

from scripts.environment_gen.openart_api_client import (
    OpenArtAPIClient, OpenArtConfig, AssetType, TextureMapType,
)
from scripts.environment_gen.openart_prompt_templates import (
    ENVIRONMENT_ASSET_PROMPTS,
    get_all_environment_keys,
    get_environment_prompts,
    get_total_asset_count,
)

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

GENERATED_ROOT = PROJECT_ROOT / "GeneratedAssets" / "Environments"
MANIFEST_PATH = GENERATED_ROOT / "openart_asset_manifest.json"

QUALITY_RESOLUTIONS = {
    "ultra": {"texture": 2048, "prop": 1024, "material": 2048, "skybox": 4096, "atmosphere": 2048, "detail": 1024},
    "high": {"texture": 1024, "prop": 512, "material": 1024, "skybox": 2048, "atmosphere": 1024, "detail": 512},
    "medium": {"texture": 512, "prop": 512, "material": 512, "skybox": 1024, "atmosphere": 512, "detail": 512},
    "mobile": {"texture": 512, "prop": 256, "material": 512, "skybox": 1024, "atmosphere": 512, "detail": 256},
}

CATEGORY_TO_ASSET_TYPE = {
    "props": AssetType.PROP,
    "textures": AssetType.TEXTURE,
    "materials": AssetType.MATERIAL,
    "atmosphere": AssetType.ATMOSPHERE,
    "skybox": AssetType.SKYBOX,
    "details": AssetType.DETAIL,
}

# ---------------------------------------------------------------------------
# Manifest management
# ---------------------------------------------------------------------------

class OpenArtManifest:
    """Track generated OpenArt assets."""

    def __init__(self, path: Path = MANIFEST_PATH):
        self.path = path
        self.data: Dict[str, Any] = {"version": "1.0", "environments": {}, "stats": {}}
        self._load()

    def _load(self):
        if self.path.exists():
            try:
                self.data = json.loads(self.path.read_text())
            except Exception:
                pass

    def save(self):
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self.path.write_text(json.dumps(self.data, indent=2))

    def has(self, env_key: str, category: str, asset_id: str) -> bool:
        entry = (
            self.data.get("environments", {})
            .get(env_key, {})
            .get(category, {})
            .get(asset_id)
        )
        if not entry:
            return False
        fpath = entry.get("file_path", "")
        return fpath and Path(fpath).exists()

    def set(self, env_key: str, category: str, asset_id: str, result: Dict):
        envs = self.data.setdefault("environments", {})
        env = envs.setdefault(env_key, {})
        cat = env.setdefault(category, {})
        cat[asset_id] = result

    def get_stats(self) -> Dict:
        total = 0
        by_env = {}
        by_cat = {}
        for env_key, cats in self.data.get("environments", {}).items():
            env_total = 0
            for cat, assets in cats.items():
                count = len(assets)
                env_total += count
                by_cat[cat] = by_cat.get(cat, 0) + count
            by_env[env_key] = env_total
            total += env_total
        return {"total": total, "by_environment": by_env, "by_category": by_cat}


# ---------------------------------------------------------------------------
# Generation pipeline
# ---------------------------------------------------------------------------

def generate_environment_assets(
    env_key: str,
    client: OpenArtAPIClient,
    manifest: OpenArtManifest,
    quality: str = "high",
    categories: Optional[List[str]] = None,
    dry_run: bool = False,
    resolution_override: int = 0,
) -> Dict[str, Any]:
    """Generate all enhanced assets for a single environment."""
    prompts = get_environment_prompts(env_key)
    if not prompts:
        print(f"[WARN] No prompts defined for environment: {env_key}")
        return {"status": "skipped", "reason": "no prompts"}

    resolutions = QUALITY_RESOLUTIONS.get(quality, QUALITY_RESOLUTIONS["high"])
    env_dir = GENERATED_ROOT / env_key / "openart"
    results = {"environment": env_key, "categories": {}}
    categories_to_process = categories or list(prompts.keys())

    for category in categories_to_process:
        if category not in prompts:
            continue

        cat_dir = env_dir / category
        cat_results = []
        items = prompts[category]

        print(f"\n  [{env_key}] Generating {len(items)} {category}...")

        for item in items:
            asset_id = item["id"]

            # Check cache
            if manifest.has(env_key, category, asset_id):
                print(f"    ✓ {asset_id} (cached)")
                cat_results.append({"id": asset_id, "status": "cached"})
                continue

            if dry_run:
                print(f"    ○ {asset_id} (dry-run)")
                cat_results.append({"id": asset_id, "status": "dry-run"})
                continue

            prompt = item["prompt"]
            res = resolution_override or resolutions.get(category, 1024)

            if category == "materials":
                # Generate full PBR material set
                mat_dir = cat_dir / asset_id
                result = client.generate_pbr_material_set(
                    prompt=prompt,
                    output_dir=mat_dir,
                    resolution=res,
                )
                if result.get("status") == "completed":
                    manifest.set(env_key, category, asset_id, {
                        "file_path": str(mat_dir),
                        "maps": list(result.get("maps", {}).keys()),
                        "status": "completed",
                        "prompt": prompt,
                    })
                    print(f"    ✓ {asset_id} (PBR set: {len(result.get('maps', {}))} maps)")
                else:
                    print(f"    ✗ {asset_id} ({result.get('status', 'error')})")
            elif category == "skybox":
                # Equirectangular skybox (2:1 ratio)
                skybox_path = cat_dir / f"{asset_id}.png"
                skybox_res = resolution_override or resolutions.get("skybox", 2048)
                result = client.generate_skybox_variation(
                    prompt=prompt,
                    output_path=skybox_path,
                    width=skybox_res,
                    height=skybox_res // 2,
                )
                if result.get("status") == "completed":
                    manifest.set(env_key, category, asset_id, {
                        **result,
                        "prompt": prompt,
                    })
                    print(f"    ✓ {asset_id} ({skybox_res}x{skybox_res // 2})")
                else:
                    print(f"    ✗ {asset_id}")
            elif category == "atmosphere":
                atm_path = cat_dir / f"{asset_id}.png"
                result = client.generate_atmosphere_overlay(
                    prompt=prompt,
                    output_path=atm_path,
                    width=res,
                    height=res,
                )
                if result.get("status") == "completed":
                    manifest.set(env_key, category, asset_id, {**result, "prompt": prompt})
                    print(f"    ✓ {asset_id}")
                else:
                    print(f"    ✗ {asset_id}")
            else:
                # Props, textures, details
                asset_type = CATEGORY_TO_ASSET_TYPE.get(category, AssetType.TEXTURE)
                file_path = cat_dir / f"{asset_id}.png"
                result = client.generate_world_asset(
                    prompt=prompt,
                    asset_type=asset_type,
                    output_path=file_path,
                    width=res,
                    height=res,
                )
                if result.get("status") == "completed":
                    manifest.set(env_key, category, asset_id, {**result, "prompt": prompt})
                    print(f"    ✓ {asset_id}")
                else:
                    print(f"    ✗ {asset_id}")

            cat_results.append({"id": asset_id, "status": result.get("status", "unknown") if not dry_run else "dry-run"})

        results["categories"][category] = cat_results
        manifest.save()

    return results


def generate_all_environments(
    client: OpenArtAPIClient,
    manifest: OpenArtManifest,
    quality: str = "high",
    env_filter: Optional[str] = None,
    category_filter: Optional[str] = None,
    dry_run: bool = False,
    resolution_override: int = 0,
) -> Dict[str, Any]:
    """Generate enhanced assets for all (or filtered) environments."""
    env_keys = [env_filter] if env_filter else get_all_environment_keys()
    categories = [category_filter] if category_filter else None

    all_results = {}
    start_time = time.time()

    print("=" * 70)
    print("  OpenArt Enhanced Environment Asset Generation")
    print("=" * 70)
    print(f"  Environments: {len(env_keys)}")
    print(f"  Quality:      {quality}")
    print(f"  Dry-run:      {dry_run}")
    print(f"  API:          {'OpenArt.ai' if client.api_available else 'Procedural Fallback'}")
    if categories:
        print(f"  Categories:   {categories}")
    print("=" * 70)

    for i, env_key in enumerate(env_keys, 1):
        print(f"\n[{i}/{len(env_keys)}] Generating assets for: {env_key}")
        result = generate_environment_assets(
            env_key=env_key,
            client=client,
            manifest=manifest,
            quality=quality,
            categories=categories,
            dry_run=dry_run,
            resolution_override=resolution_override,
        )
        all_results[env_key] = result

    elapsed = time.time() - start_time
    stats = manifest.get_stats()

    # Update manifest stats
    manifest.data["stats"] = {
        **stats,
        "generation_time_seconds": round(elapsed, 2),
        "quality_preset": quality,
        "api_used": "openart" if client.api_available else "procedural",
    }
    manifest.save()

    print("\n" + "=" * 70)
    print("  Generation Complete!")
    print("=" * 70)
    print(f"  Total assets: {stats['total']}")
    print(f"  Time:         {elapsed:.1f}s")
    for env_key, count in stats.get("by_environment", {}).items():
        print(f"    {env_key}: {count} assets")
    print(f"\n  Manifest: {MANIFEST_PATH}")
    print("=" * 70)

    return all_results


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="OpenArt Enhanced Environment Generator")
    parser.add_argument("--env", help="Generate for a single environment")
    parser.add_argument("--category", help="Generate a single category (props|textures|materials|atmosphere|skybox|details)")
    parser.add_argument("--dry-run", action="store_true", help="Preview without generating")
    parser.add_argument("--resolution", type=int, default=0, help="Override texture resolution")
    parser.add_argument("--quality", default="high", choices=["ultra", "high", "medium", "mobile"])
    parser.add_argument("--list", action="store_true", help="List environments and asset counts")

    args = parser.parse_args()

    if args.list:
        print("\nEnvironment Asset Counts:")
        print("-" * 50)
        total = 0
        for env_key in get_all_environment_keys():
            prompts = get_environment_prompts(env_key)
            env_total = sum(len(v) for v in prompts.values())
            total += env_total
            print(f"  {env_key}:")
            for cat, items in prompts.items():
                print(f"    {cat}: {len(items)}")
        print(f"\n  Total: {total} assets across {len(get_all_environment_keys())} environments")
        # Count PBR maps separately
        mat_count = sum(
            len(get_environment_prompts(ek).get("materials", []))
            for ek in get_all_environment_keys()
        )
        print(f"  PBR material sets: {mat_count} × 5 maps = {mat_count * 5} texture files")
        print(f"  Grand total files: ~{total + mat_count * 4}")  # 4 extra maps per material
        return

    client = OpenArtAPIClient()
    manifest = OpenArtManifest()

    generate_all_environments(
        client=client,
        manifest=manifest,
        quality=args.quality,
        env_filter=args.env,
        category_filter=args.category,
        dry_run=args.dry_run,
        resolution_override=args.resolution,
    )


if __name__ == "__main__":
    main()
