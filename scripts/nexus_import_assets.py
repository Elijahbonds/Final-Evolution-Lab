#!/usr/bin/env python3
"""Download Seele/Meshy/Luma exports and convert to NEXUS .nexusmesh.json (stub pipeline)."""

from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.request
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MANIFEST = REPO_ROOT / "assets" / "nexus" / "manifests" / "nexus_asset_manifest.json"
IMPORT_ROOT = REPO_ROOT / "assets" / "nexus" / "imported"
SOURCE_ROOT = REPO_ROOT / "assets" / "nexus" / "source"


def load_manifest(path: Path) -> dict[str, Any]:
    with path.open(encoding="utf-8") as handle:
        return json.load(handle)


def download_url(url: str, dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    print(f"Downloading {url} -> {dest}")
    urllib.request.urlretrieve(url, dest)


def stub_convert_to_nexusmesh(source_path: Path, dest_path: Path, name: str) -> None:
    """Placeholder conversion: writes a colored pyramid marker until Blender/assimp wired."""
    dest_path.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "format": "nexusmesh",
        "version": "1",
        "name": name,
        "source_file": str(source_path.name),
        "vertices": [
            {"position": [0.0, 0.0, 0.6], "color": [0.2, 0.75, 0.95]},
            {"position": [-0.5, 0.0, -0.4], "color": [0.15, 0.65, 0.85]},
            {"position": [0.5, 0.0, -0.4], "color": [0.15, 0.65, 0.85]},
            {"position": [0.0, 1.0, 0.0], "color": [0.35, 0.9, 1.0]},
        ],
        "indices": [0, 1, 3, 1, 2, 3, 2, 0, 3, 0, 2, 1],
    }
    with dest_path.open("w", encoding="utf-8") as handle:
        json.dump(payload, handle, indent=2)
    print(f"Stub converted -> {dest_path}")


def process_asset(asset: dict[str, Any], download: bool, convert: bool) -> None:
    asset_id = asset["id"]
    source_url = asset.get("source_url")
    imported_mesh = asset.get("imported_mesh")

    if not source_url:
        return

    raw_name = f"{asset_id}.fbx"
    if source_url.endswith(".glb"):
        raw_name = f"{asset_id}.glb"
    elif source_url.endswith(".gltf"):
        raw_name = f"{asset_id}.gltf"

    raw_path = SOURCE_ROOT / raw_name
    if download and source_url:
        download_url(source_url, raw_path)

    if convert:
        if imported_mesh:
            dest = REPO_ROOT / asset.get("_import_root", "assets/nexus/imported") / imported_mesh
        else:
            dest = IMPORT_ROOT / f"{asset_id}.nexusmesh.json"
        if raw_path.exists():
            stub_convert_to_nexusmesh(raw_path, dest, asset_id)
        else:
            print(f"Skip convert (missing source): {raw_path}")


def main() -> int:
    parser = argparse.ArgumentParser(description="NEXUS asset import pipeline")
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--download", action="store_true", help="Download source_url to assets/nexus/source/")
    parser.add_argument("--convert", action="store_true", help="Stub convert downloaded meshes to .nexusmesh.json")
    parser.add_argument("--asset", help="Process single asset id")
    args = parser.parse_args()

    if not args.manifest.exists():
        print(f"Manifest not found: {args.manifest}", file=sys.stderr)
        return 1

    manifest = load_manifest(args.manifest)
    import_root = manifest.get("import_root", "assets/nexus/imported")

    for asset in manifest.get("assets", []):
        asset["_import_root"] = import_root
        if args.asset and asset.get("id") != args.asset:
            continue
        if args.download or args.convert:
            process_asset(asset, download=args.download, convert=args.convert)

    if not args.download and not args.convert:
        total = len(manifest.get("assets", []))
        with_url = sum(1 for a in manifest.get("assets", []) if a.get("source_url"))
        print(f"Manifest: {args.manifest}")
        print(f"  assets: {total} ({with_url} with source_url)")
        print(f"  venues: {len(manifest.get('venues', []))}")
        print("Use --download then --convert to fetch Seele CDN FBX and stub-convert.")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
