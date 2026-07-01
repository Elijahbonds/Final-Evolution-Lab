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
FULL_IMPORT_ROOT = IMPORT_ROOT / "full"
SOURCE_ROOT = REPO_ROOT / "assets" / "nexus" / "source"

DEFAULT_VERTEX_COLOR = [0.8, 0.85, 0.9]
DEFAULT_MAX_VERTS = 50_000
DEFAULT_MAX_TRIS = 80_000

# Per-spec tri budgets (FEL NEXUS spec §6.1 / §6.3).
VENUE_LOD_BUDGETS: dict[str, dict[str, int]] = {
    "venice_beach_court_model_fbx": {"max_verts": 50_000, "max_tris": 80_000},
    "zen_dojo_environment_model_fbx": {"max_verts": 40_000, "max_tris": 60_000},
}

DEFAULT_LOD_BUDGET = {"max_verts": DEFAULT_MAX_VERTS, "max_tris": DEFAULT_MAX_TRIS}


def load_manifest(path: Path) -> dict[str, Any]:
    with path.open(encoding="utf-8") as handle:
        return json.load(handle)


def save_manifest(path: Path, manifest: dict[str, Any]) -> None:
    cleaned = json.loads(json.dumps(manifest))
    for asset in cleaned.get("assets", []):
        asset.pop("_import_root", None)
    with path.open("w", encoding="utf-8") as handle:
        json.dump(cleaned, handle, indent=2)
        handle.write("\n")


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


def fast_simplification_available() -> bool:
    try:
        import fast_simplification  # noqa: F401
    except Exception:
        return False
    return True


def pyfqmr_available() -> bool:
    try:
        import pyfqmr  # noqa: F401
    except Exception:
        return False
    return True


def simplify_to_target_tris(mesh: Any, target_tris: int) -> Any:
    import trimesh

    mesh = scene_to_trimesh(mesh)
    target_tris = max(4, min(target_tris, len(mesh.faces)))

    if fast_simplification_available():
        return mesh.simplify_quadric_decimation(target_tris)

    if pyfqmr_available():
        import numpy as np
        import pyfqmr

        simplifier = pyfqmr.Simplify()
        simplifier.setMesh(mesh.vertices, mesh.faces)
        simplifier.simplify_mesh(target_count=target_tris, aggressiveness=7, preserve_border=True)
        verts, faces, _normals = simplifier.getMesh()
        return trimesh.Trimesh(vertices=np.asarray(verts), faces=np.asarray(faces), process=False)

    raise RuntimeError(
        "No decimation backend — run: pip3 install pyfqmr  (or fast_simplification on Python 3.10+)"
    )


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


def mesh_stats(mesh: Any) -> tuple[int, int]:
    mesh = scene_to_trimesh(mesh)
    mesh.merge_vertices()
    return len(mesh.vertices), len(mesh.faces)


def decimate_mesh(mesh: Any, max_verts: int, max_tris: int) -> tuple[Any, bool]:
    """Reduce mesh to mobile LOD budget. Returns (mesh, was_decimated)."""
    import trimesh

    mesh = scene_to_trimesh(mesh)
    mesh.merge_vertices()
    vert_count, tri_count = len(mesh.vertices), len(mesh.faces)

    if vert_count <= max_verts and tri_count <= max_tris:
        return mesh, False

    if not fast_simplification_available() and not pyfqmr_available():
        raise RuntimeError(
            "Decimation backend required — run: pip3 install pyfqmr  (or fast_simplification on Python 3.10+)"
        )

    target_tris = min(max_tris, max(4, int(tri_count * max_verts / max(vert_count, 1))))
    target_tris = min(target_tris, tri_count - 1) if tri_count > 1 else tri_count

    decimated = mesh
    for attempt in range(8):
        candidate_tris = max(4, int(target_tris * (0.85**attempt)))
        decimated = simplify_to_target_tris(mesh, candidate_tris)
        decimated.merge_vertices()
        if len(decimated.vertices) <= max_verts and len(decimated.faces) <= max_tris:
            break

    # Final pass: if still over tri budget, decimate from last result.
    while len(decimated.faces) > max_tris and len(decimated.faces) > 4:
        candidate_tris = max(4, int(len(decimated.faces) * 0.85))
        decimated = simplify_to_target_tris(decimated, candidate_tris)
        decimated.merge_vertices()

    while len(decimated.vertices) > max_verts and len(decimated.faces) > 4:
        ratio = max_verts / max(len(decimated.vertices), 1)
        candidate_tris = max(4, int(len(decimated.faces) * ratio * 0.9))
        decimated = simplify_to_target_tris(decimated, candidate_tris)
        decimated.merge_vertices()

    return decimated, True


def mobile_mesh_path(dest_path: Path) -> Path:
    if dest_path.name.endswith(".nexusmesh.json"):
        return dest_path.with_name(dest_path.name.replace(".nexusmesh.json", "_mobile.nexusmesh.json"))
    return dest_path.with_name(f"{dest_path.stem}_mobile{dest_path.suffix}")


def nexusmesh_json_to_trimesh(payload: dict[str, Any]) -> Any:
    import numpy as np
    import trimesh

    vertices = np.array(
        [[v["position"][0], v["position"][1], v["position"][2]] for v in payload["vertices"]],
        dtype=np.float64,
    )
    faces = np.array(payload["indices"], dtype=np.int64).reshape(-1, 3)
    return trimesh.Trimesh(vertices=vertices, faces=faces, process=False)


def path_for_stats(path: Path) -> str:
    try:
        return str(path.relative_to(REPO_ROOT))
    except ValueError:
        return str(path)


def decimate_existing_asset(
    asset: dict[str, Any],
    *,
    max_verts: int,
    max_tris: int,
    import_root: Path,
) -> dict[str, Any] | None:
    imported_mesh = asset.get("imported_mesh")
    if not imported_mesh:
        return None

    desktop_path = import_root / imported_mesh
    if not desktop_path.exists():
        print(f"Skip mobile (--mobile): desktop mesh missing {desktop_path}", file=sys.stderr)
        return None

    mobile_path = mobile_mesh_path(desktop_path)
    with desktop_path.open(encoding="utf-8") as handle:
        payload = json.load(handle)

    mesh = nexusmesh_json_to_trimesh(payload)
    source_verts, source_tris = mesh_stats(mesh)
    budget = lod_budget_for_asset(asset["id"], max_verts, max_tris)
    decimated, was_decimated = decimate_mesh(mesh, budget["max_verts"], budget["max_tris"])
    mobile_payload = trimesh_to_payload(
        decimated,
        asset["id"],
        desktop_path,
        "nexusmesh+decimate" if was_decimated else "nexusmesh",
        lod="mobile",
        source_vertex_count=source_verts,
        source_tri_count=source_tris,
    )
    write_nexusmesh_payload(mobile_path, mobile_payload)
    print(
        f"Mobile LOD -> {mobile_path} "
        f"({mobile_payload['vertex_count']} verts, {mobile_payload['tri_count']} tris)"
    )
    return {
        "asset_id": asset["id"],
        "success": True,
        "desktop_path": path_for_stats(desktop_path),
        "mobile_path": path_for_stats(mobile_path),
        "vertex_count": mobile_payload["vertex_count"],
        "tri_count": mobile_payload["tri_count"],
        "source_vertex_count": source_verts,
        "source_tri_count": source_tris,
        "decimated": was_decimated,
        "method": "nexusmesh+decimate",
    }


def trimesh_to_payload(
    mesh: Any,
    name: str,
    source_path: Path,
    method: str,
    *,
    lod: str = "mobile",
    source_vertex_count: int | None = None,
    source_tri_count: int | None = None,
) -> dict[str, Any]:
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
    payload: dict[str, Any] = {
        "format": "nexusmesh",
        "version": "1",
        "name": name,
        "source_file": str(source_path.name),
        "conversion_method": method,
        "lod": lod,
        "vertex_count": len(vertices),
        "tri_count": len(indices) // 3,
        "vertices": vertices,
        "indices": indices,
    }
    if source_vertex_count is not None:
        payload["source_vertex_count"] = source_vertex_count
    if source_tri_count is not None:
        payload["source_tri_count"] = source_tri_count
    return payload


def write_nexusmesh_payload(dest_path: Path, payload: dict[str, Any]) -> None:
    dest_path.parent.mkdir(parents=True, exist_ok=True)
    compact = len(payload.get("vertices", [])) > 256
    with dest_path.open("w", encoding="utf-8") as handle:
        if compact:
            json.dump(payload, handle, separators=(",", ":"))
        else:
            json.dump(payload, handle, indent=2)


def lod_budget_for_asset(asset_id: str, max_verts: int, max_tris: int) -> dict[str, int]:
    budget = VENUE_LOD_BUDGETS.get(asset_id, DEFAULT_LOD_BUDGET)
    return {
        "max_verts": max_verts if max_verts != DEFAULT_MAX_VERTS else budget["max_verts"],
        "max_tris": max_tris if max_tris != DEFAULT_MAX_TRIS else budget["max_tris"],
    }


def convert_to_nexusmesh(
    source_path: Path,
    dest_path: Path,
    name: str,
    *,
    mobile_lod: bool,
    max_verts: int,
    max_tris: int,
    allow_stub: bool,
    write_full: bool,
    write_desktop: bool,
) -> dict[str, Any]:
    """Convert source geometry to NEXUS mesh JSON. Returns conversion stats."""
    stats: dict[str, Any] = {
        "asset_id": name,
        "success": False,
        "method": "",
        "desktop_path": "",
        "mobile_path": "",
        "vertex_count": 0,
        "tri_count": 0,
        "source_vertex_count": 0,
        "source_tri_count": 0,
        "decimated": False,
    }

    try:
        mesh, method = load_source_mesh(source_path)
        source_verts, source_tris = mesh_stats(mesh)
        stats["source_vertex_count"] = source_verts
        stats["source_tri_count"] = source_tris
        stats["method"] = method

        if write_desktop:
            desktop_payload = trimesh_to_payload(
                mesh,
                name,
                source_path,
                method,
                lod="desktop",
                source_vertex_count=source_verts,
                source_tri_count=source_tris,
            )
            write_nexusmesh_payload(dest_path, desktop_payload)
            stats["desktop_path"] = path_for_stats(dest_path)
            stats["desktop_vertex_count"] = desktop_payload["vertex_count"]
            stats["desktop_tri_count"] = desktop_payload["tri_count"]
            print(
                f"Desktop mesh -> {dest_path} "
                f"({desktop_payload['vertex_count']} verts, {desktop_payload['tri_count']} tris)"
            )

            if write_full:
                full_path = FULL_IMPORT_ROOT / dest_path.name
                write_nexusmesh_payload(full_path, desktop_payload)
                stats["full_path"] = path_for_stats(full_path)
                print(
                    f"Full mesh copy -> {full_path} "
                    f"({desktop_payload['vertex_count']} verts, {desktop_payload['tri_count']} tris)"
                )

        budget = lod_budget_for_asset(name, max_verts, max_tris)
        if mobile_lod:
            mobile_mesh, was_decimated = decimate_mesh(mesh, budget["max_verts"], budget["max_tris"])
            stats["decimated"] = was_decimated
            mobile_path = mobile_mesh_path(dest_path)
            mobile_payload = trimesh_to_payload(
                mobile_mesh,
                name,
                source_path,
                f"{method}+decimate" if was_decimated else method,
                lod="mobile",
                source_vertex_count=source_verts,
                source_tri_count=source_tris,
            )
            write_nexusmesh_payload(mobile_path, mobile_payload)
            stats["mobile_path"] = path_for_stats(mobile_path)
            stats["vertex_count"] = mobile_payload["vertex_count"]
            stats["tri_count"] = mobile_payload["tri_count"]
            print(
                f"Mobile mesh ({mobile_payload['conversion_method']}) -> {mobile_path} "
                f"({mobile_payload['vertex_count']} verts, {mobile_payload['tri_count']} tris)"
            )
        elif write_desktop:
            stats["vertex_count"] = stats.get("desktop_vertex_count", 0)
            stats["tri_count"] = stats.get("desktop_tri_count", 0)
        else:
            raise RuntimeError("Nothing to write — enable --mobile-lod or --write-desktop")

        stats["success"] = True
        return stats
    except Exception as exc:
        print(f"Conversion failed for {source_path.name}: {exc}", file=sys.stderr)
        if not allow_stub:
            stats["error"] = str(exc)
            return stats
        payload = stub_pyramid_payload(name, source_path)
        write_nexusmesh_payload(dest_path, payload)
        stats["method"] = "stub_pyramid"
        stats["vertex_count"] = len(payload["vertices"])
        stats["tri_count"] = len(payload["indices"]) // 3
        print(f"Stub fallback -> {dest_path} ({stats['vertex_count']} vertices)")
        return stats


def update_manifest_asset(
    manifest: dict[str, Any], asset_id: str, stats: dict[str, Any], import_root: str
) -> None:
    for asset in manifest.get("assets", []):
        if asset.get("id") != asset_id:
            continue
        if stats.get("success"):
            if stats.get("desktop_path"):
                desktop_rel = stats["desktop_path"]
                if desktop_rel.startswith(import_root + "/"):
                    desktop_rel = desktop_rel[len(import_root) + 1 :]
                asset["imported_mesh_desktop"] = desktop_rel.split("/")[-1]
            if stats.get("desktop_path"):
                desktop_rel = stats["desktop_path"]
                if desktop_rel.startswith(import_root + "/"):
                    desktop_rel = desktop_rel[len(import_root) + 1 :]
                desktop_name = desktop_rel.split("/")[-1]
                asset["imported_mesh"] = desktop_name
                asset["imported_mesh_desktop"] = desktop_name
            if stats.get("mobile_path"):
                mobile_rel = stats["mobile_path"]
                if mobile_rel.startswith(import_root + "/"):
                    mobile_rel = mobile_rel[len(import_root) + 1 :]
                mobile_name = mobile_rel.split("/")[-1]
                asset["imported_mesh_mobile"] = mobile_name
                if not stats.get("desktop_path"):
                    base_name = mobile_name.replace("_mobile.nexusmesh.json", ".nexusmesh.json")
                    asset["imported_mesh"] = base_name
            if stats.get("full_path"):
                full_rel = stats["full_path"]
                if full_rel.startswith(import_root + "/"):
                    full_rel = full_rel[len(import_root) + 1 :]
                asset["imported_mesh_full"] = full_rel.split("/")[-1]
            if stats.get("vertex_count") is not None:
                asset["mobile_vertex_count"] = stats["vertex_count"]
                asset["vertex_count"] = stats["vertex_count"]
            if stats.get("tri_count") is not None:
                asset["mobile_tri_count"] = stats["tri_count"]
                asset["tri_count"] = stats["tri_count"]
            if stats.get("desktop_vertex_count") is not None:
                asset["desktop_vertex_count"] = stats["desktop_vertex_count"]
                asset["desktop_tri_count"] = stats["desktop_tri_count"]
            asset["source_vertex_count"] = stats.get("source_vertex_count")
            asset["source_tri_count"] = stats.get("source_tri_count")
            asset["mobile_decimated"] = stats.get("decimated", False)
        break


def process_asset(
    asset: dict[str, Any],
    *,
    download: bool,
    convert: bool,
    mobile_lod: bool,
    max_verts: int,
    max_tris: int,
    allow_stub: bool,
    write_full: bool,
    write_desktop: bool,
) -> dict[str, Any] | None:
    asset_id = asset["id"]
    source_url = asset.get("source_url")
    imported_mesh = asset.get("imported_mesh")

    if not source_url and convert:
        if imported_mesh:
            raw_candidates = list(SOURCE_ROOT.glob(f"{asset_id}.*"))
            if not raw_candidates:
                return None
        else:
            return None

    raw_name = f"{asset_id}.fbx"
    if source_url:
        if source_url.endswith(".glb"):
            raw_name = f"{asset_id}.glb"
        elif source_url.endswith(".gltf"):
            raw_name = f"{asset_id}.gltf"

    raw_path = SOURCE_ROOT / raw_name
    if download and source_url:
        download_url(source_url, raw_path)

    if not convert:
        return None

    dest = IMPORT_ROOT / f"{asset_id}.nexusmesh.json"

    if not raw_path.exists():
        raw_candidates = sorted(SOURCE_ROOT.glob(f"{asset_id}.*"))
        if raw_candidates:
            raw_path = raw_candidates[0]
        else:
            print(f"Skip convert (missing source): {raw_path}")
            return None

    return convert_to_nexusmesh(
        raw_path,
        dest,
        asset_id,
        mobile_lod=mobile_lod,
        max_verts=max_verts,
        max_tris=max_tris,
        allow_stub=allow_stub,
        write_full=write_full,
        write_desktop=write_desktop,
    )


def main() -> int:
    parser = argparse.ArgumentParser(description="NEXUS asset import pipeline")
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--download", action="store_true", help="Download source_url to assets/nexus/source/")
    parser.add_argument(
        "--convert",
        action="store_true",
        help="Convert downloaded meshes to .nexusmesh.json (assimp + trimesh + mobile LOD)",
    )
    parser.add_argument("--asset", help="Process single asset id")
    parser.add_argument(
        "--from-gltf",
        type=Path,
        metavar="PATH",
        help="Convert a local .gltf/.glb file to .nexusmesh.json (minimal glTF path; no manifest required)",
    )
    parser.add_argument(
        "--output",
        type=Path,
        help="Output .nexusmesh.json path for --from-gltf (default: imported/<stem>.nexusmesh.json)",
    )
    parser.add_argument(
        "--mobile",
        action="store_true",
        help="Emit *_mobile.nexusmesh.json via trimesh decimation (implies --convert --mobile-lod)",
    )
    parser.add_argument(
        "--mobile-lod",
        action=argparse.BooleanOptionalAction,
        default=True,
        help="Decimate to iOS mobile vertex/tri budget (default: on when --convert)",
    )
    parser.add_argument(
        "--max-verts",
        type=int,
        default=DEFAULT_MAX_VERTS,
        help=f"Mobile LOD vertex cap (default: {DEFAULT_MAX_VERTS})",
    )
    parser.add_argument(
        "--max-tris",
        type=int,
        default=DEFAULT_MAX_TRIS,
        help=f"Mobile LOD triangle cap (default: {DEFAULT_MAX_TRIS})",
    )
    parser.add_argument(
        "--write-full",
        action="store_true",
        help="Also write full-resolution copy under assets/nexus/imported/full/ (gitignored)",
    )
    parser.add_argument(
        "--write-desktop",
        action="store_true",
        help="Write undecimated desktop mesh alongside mobile LOD (large; not for git)",
    )
    parser.add_argument(
        "--allow-stub",
        action="store_true",
        help="On conversion failure, write pyramid stub instead of skipping",
    )
    parser.add_argument(
        "--update-manifest",
        action="store_true",
        help="Write tri/vertex counts and mobile mesh paths back to manifest JSON",
    )
    args = parser.parse_args()

    if args.mobile:
        args.convert = True
        args.mobile_lod = True
        if not args.update_manifest:
            args.update_manifest = True

    if args.from_gltf:
        source = args.from_gltf.resolve()
        if source.suffix.lower() not in {".gltf", ".glb"}:
            print(f"--from-gltf requires .gltf or .glb, got: {source}", file=sys.stderr)
            return 1
        if not source.exists():
            print(f"glTF source not found: {source}", file=sys.stderr)
            return 1
        dest = args.output or (IMPORT_ROOT / f"{source.stem}.nexusmesh.json")
        stats = convert_to_nexusmesh(
            source,
            dest,
            source.stem,
            mobile_lod=args.mobile_lod,
            max_verts=args.max_verts,
            max_tris=args.max_tris,
            allow_stub=args.allow_stub,
            write_full=args.write_full,
            write_desktop=args.write_desktop or not args.mobile_lod,
        )
        if not stats.get("success"):
            return 1
        return 0

    if not args.manifest.exists():
        print(f"Manifest not found: {args.manifest}", file=sys.stderr)
        return 1

    manifest = load_manifest(args.manifest)
    import_root = manifest.get("import_root", "assets/nexus/imported")
    conversion_stats: list[dict[str, Any]] = []

    for asset in manifest.get("assets", []):
        asset["_import_root"] = import_root
        if args.asset and asset.get("id") != args.asset:
            continue
        if args.download or args.convert:
            stats = process_asset(
                asset,
                download=args.download,
                convert=args.convert,
                mobile_lod=args.mobile_lod,
                max_verts=args.max_verts,
                max_tris=args.max_tris,
                allow_stub=args.allow_stub,
                write_full=args.write_full,
                write_desktop=args.write_desktop,
            )
            if stats is None and args.mobile and asset.get("imported_mesh"):
                stats = decimate_existing_asset(
                    asset,
                    max_verts=args.max_verts,
                    max_tris=args.max_tris,
                    import_root=REPO_ROOT / import_root,
                )
            if stats is not None:
                conversion_stats.append(stats)
                if args.update_manifest and stats.get("success"):
                    update_manifest_asset(manifest, asset["id"], stats, import_root)

    if args.update_manifest and conversion_stats:
        save_manifest(args.manifest, manifest)
        print(f"Updated manifest: {args.manifest}")

    if not args.download and not args.convert and not args.mobile:
        total = len(manifest.get("assets", []))
        with_url = sum(1 for a in manifest.get("assets", []) if a.get("source_url"))
        print(f"Manifest: {args.manifest}")
        print(f"  assets: {total} ({with_url} with source_url)")
        print(f"  venues: {len(manifest.get('venues', []))}")
        print("Use --download then --convert to fetch Seele CDN FBX and convert to nexusmesh.")
        print("Mobile LOD defaults: 50k verts / 80k tris (zen_dojo: 40k/60k).")
        return 0

    if args.convert:
        ok = sum(1 for s in conversion_stats if s.get("success"))
        stub = sum(1 for s in conversion_stats if s.get("method") == "stub_pyramid")
        failed = len(conversion_stats) - ok - stub
        print(f"\nConversion summary: {ok} real, {stub} stub, {failed} failed")
        if failed and not args.allow_stub:
            return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
