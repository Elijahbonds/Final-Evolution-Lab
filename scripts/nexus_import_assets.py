#!/usr/bin/env python3
"""Download Seele/Meshy/Luma exports and convert to NEXUS .nexusmesh.json."""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile
import urllib.request
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MANIFEST = REPO_ROOT / "assets" / "nexus" / "manifests" / "nexus_asset_manifest.json"
IMPORT_ROOT = REPO_ROOT / "assets" / "nexus" / "imported"
SOURCE_ROOT = REPO_ROOT / "assets" / "nexus" / "source"

DEFAULT_VERTEX_COLOR = [0.8, 0.85, 0.9]


def load_manifest(path: Path) -> dict[str, Any]:
    with path.open(encoding="utf-8") as handle:
        return json.load(handle)


def download_url(url: str, dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    print(f"Downloading {url} -> {dest}")
    urllib.request.urlretrieve(url, dest)


def find_assimp_cli() -> Path | None:
    candidates = [
        shutil.which("assimp"),
        "/opt/homebrew/bin/assimp",
        "/usr/local/bin/assimp",
    ]
    for candidate in candidates:
        if candidate and Path(candidate).is_file():
            return Path(candidate)
    return None


def find_blender_cli() -> Path | None:
    candidates = [
        shutil.which("blender"),
        "/Applications/Blender.app/Contents/MacOS/Blender",
    ]
    for candidate in candidates:
        if candidate and Path(candidate).is_file():
            return Path(candidate)
    return None


def pyassimp_available() -> bool:
    try:
        import pyassimp  # noqa: F401
    except BaseException:
        return False
    return True


def trimesh_available() -> bool:
    try:
        import trimesh  # noqa: F401
    except Exception:
        return False
    return True


def stub_pyramid_payload(name: str, source_path: Path) -> dict[str, Any]:
    return {
        "format": "nexusmesh",
        "version": "1",
        "name": name,
        "source_file": str(source_path.name),
        "conversion_method": "stub_pyramid",
        "vertices": [
            {"position": [0.0, 0.0, 0.6], "color": [0.2, 0.75, 0.95]},
            {"position": [-0.5, 0.0, -0.4], "color": [0.15, 0.65, 0.85]},
            {"position": [0.5, 0.0, -0.4], "color": [0.15, 0.65, 0.85]},
            {"position": [0.0, 1.0, 0.0], "color": [0.35, 0.9, 1.0]},
        ],
        "indices": [0, 1, 3, 1, 2, 3, 2, 0, 3, 0, 2, 1],
    }


def scene_to_trimesh(mesh: Any) -> Any:
    import trimesh

    if isinstance(mesh, trimesh.Trimesh):
        return mesh
    if isinstance(mesh, trimesh.Scene):
        parts = [
            geometry
            for geometry in mesh.geometry.values()
            if isinstance(geometry, trimesh.Trimesh) and len(geometry.vertices) > 0
        ]
        if not parts:
            raise ValueError("scene contains no triangle meshes")
        if len(parts) == 1:
            return parts[0]
        return trimesh.util.concatenate(parts)
    raise TypeError(f"unsupported mesh type: {type(mesh)!r}")


def load_with_trimesh(source_path: Path) -> tuple[Any, str]:
    import trimesh

    suffix = source_path.suffix.lower()
    if suffix == ".fbx":
        raise NotImplementedError("trimesh cannot import FBX directly")
    loaded = trimesh.load(source_path, force="mesh", process=False)
    return scene_to_trimesh(loaded), "trimesh"


def load_with_pyassimp(source_path: Path) -> tuple[Any, str]:
    import numpy as np
    import trimesh
    import pyassimp

    scene = pyassimp.load(str(source_path))
    try:
        parts: list[Any] = []
        for mesh in scene.meshes:
            if not mesh.vertices or not mesh.faces:
                continue
            vertices = np.array(mesh.vertices, dtype=np.float64)
            faces = np.array(mesh.faces, dtype=np.int64)
            if faces.ndim != 2 or faces.shape[1] != 3:
                continue
            parts.append(trimesh.Trimesh(vertices=vertices, faces=faces, process=False))
        if not parts:
            raise ValueError("pyassimp produced no triangle meshes")
        combined = parts[0] if len(parts) == 1 else trimesh.util.concatenate(parts)
        return combined, "pyassimp"
    finally:
        pyassimp.release(scene)


def load_with_assimp_cli(source_path: Path) -> tuple[Any, str]:
    assimp = find_assimp_cli()
    if assimp is None:
        raise RuntimeError("assimp CLI not found")

    with tempfile.TemporaryDirectory(prefix="nexusmesh-") as tmp:
        obj_path = Path(tmp) / "converted.obj"
        result = subprocess.run(
            [str(assimp), "export", str(source_path), str(obj_path)],
            capture_output=True,
            text=True,
            check=False,
        )
        if result.returncode != 0 or not obj_path.exists():
            stderr = (result.stderr or result.stdout or "").strip()
            raise RuntimeError(f"assimp export failed: {stderr}")
        return load_with_trimesh(obj_path)


def load_with_blender_cli(source_path: Path) -> tuple[Any, str]:
    blender = find_blender_cli()
    if blender is None:
        raise RuntimeError("blender CLI not found")

    with tempfile.TemporaryDirectory(prefix="nexusmesh-") as tmp:
        obj_path = Path(tmp) / "converted.obj"
        script = f"""
import bpy
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath={json.dumps(str(source_path))})
bpy.ops.export_scene.obj(filepath={json.dumps(str(obj_path))}, use_selection=False)
"""
        result = subprocess.run(
            [str(blender), "--background", "--python-expr", script],
            capture_output=True,
            text=True,
            check=False,
        )
        if result.returncode != 0 or not obj_path.exists():
            stderr = (result.stderr or result.stdout or "").strip()
            raise RuntimeError(f"blender export failed: {stderr}")
        mesh, _ = load_with_trimesh(obj_path)
        return mesh, "blender-cli+trimesh"


def load_source_mesh(source_path: Path) -> tuple[Any, str]:
    errors: list[str] = []

    if trimesh_available():
        try:
            return load_with_trimesh(source_path)
        except NotImplementedError:
            pass
        except Exception as exc:
            errors.append(f"trimesh: {exc}")

    if pyassimp_available():
        try:
            return load_with_pyassimp(source_path)
        except Exception as exc:
            errors.append(f"pyassimp: {exc}")

    if find_assimp_cli() is not None:
        try:
            mesh, inner_method = load_with_assimp_cli(source_path)
            return mesh, f"assimp-cli+{inner_method}"
        except Exception as exc:
            errors.append(f"assimp-cli: {exc}")

    if find_blender_cli() is not None:
        try:
            return load_with_blender_cli(source_path)
        except Exception as exc:
            errors.append(f"blender-cli: {exc}")

    detail = "; ".join(errors) if errors else "no mesh backends available"
    raise RuntimeError(detail)


def trimesh_to_payload(mesh: Any, name: str, source_path: Path, method: str) -> dict[str, Any]:
    import numpy as np

    mesh = scene_to_trimesh(mesh)
    mesh.merge_vertices()
    if mesh.faces is None or len(mesh.faces) == 0:
        raise ValueError("mesh has no faces")

    vertex_colors = None
    visual = getattr(mesh, "visual", None)
    colors = getattr(visual, "vertex_colors", None) if visual is not None else None
    if colors is not None and len(colors) == len(mesh.vertices):
        vertex_colors = np.asarray(colors)[:, :3] / 255.0

    vertices: list[dict[str, Any]] = []
    for index, position in enumerate(mesh.vertices):
        if vertex_colors is not None:
            color = vertex_colors[index].tolist()
        else:
            color = DEFAULT_VERTEX_COLOR
        vertices.append(
            {
                "position": [float(position[0]), float(position[1]), float(position[2])],
                "color": [float(color[0]), float(color[1]), float(color[2])],
            }
        )

    indices = mesh.faces.reshape(-1).astype(np.uint32).tolist()
    return {
        "format": "nexusmesh",
        "version": "1",
        "name": name,
        "source_file": str(source_path.name),
        "conversion_method": method,
        "vertices": vertices,
        "indices": indices,
    }


def write_nexusmesh_payload(dest_path: Path, payload: dict[str, Any]) -> None:
    dest_path.parent.mkdir(parents=True, exist_ok=True)
    compact = len(payload.get("vertices", [])) > 256
    with dest_path.open("w", encoding="utf-8") as handle:
        if compact:
            json.dump(payload, handle, separators=(",", ":"))
        else:
            json.dump(payload, handle, indent=2)


def stub_convert_to_nexusmesh(source_path: Path, dest_path: Path, name: str) -> tuple[str, int, bool]:
    """Convert source geometry to NEXUS mesh JSON using trimesh, pyassimp, or Blender/assimp CLI."""
    try:
        mesh, method = load_source_mesh(source_path)
        payload = trimesh_to_payload(mesh, name, source_path, method)
        write_nexusmesh_payload(dest_path, payload)
        vertex_count = len(payload["vertices"])
        print(f"Converted ({method}) -> {dest_path} ({vertex_count} vertices)")
        return method, vertex_count, True
    except Exception as exc:
        print(f"Conversion failed for {source_path.name}: {exc}", file=sys.stderr)
        payload = stub_pyramid_payload(name, source_path)
        write_nexusmesh_payload(dest_path, payload)
        vertex_count = len(payload["vertices"])
        print(f"Stub fallback -> {dest_path} ({vertex_count} vertices)")
        return "stub_pyramid", vertex_count, False


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
    parser.add_argument(
        "--convert",
        action="store_true",
        help="Convert downloaded meshes to .nexusmesh.json (trimesh / pyassimp / assimp / Blender)",
    )
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
        print("Use --download then --convert to fetch Seele CDN FBX and convert to nexusmesh.")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
