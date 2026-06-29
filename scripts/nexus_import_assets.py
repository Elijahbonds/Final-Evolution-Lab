#!/usr/bin/env python3
"""Download Seele/Meshy/Luma exports and convert to NEXUS .nexusmesh.json."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
import random
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


# --------------------------------------------------------------------------- #
# Procedural venue mesh generator (deterministic fallback)
#
# When no source mesh can be downloaded/converted (no FBX backend available, or
# the asset lives only on a remote CDN we cannot reach), we still want every
# venue to render as a recognisable arena instead of a degenerate 4-vertex
# tetrahedron. The generator below builds a parametric venue: a subdivided
# ground plane, raised boundary walls / tiered stands, and a few court/field
# markers, coloured per a venue palette and parameterised by venue type so the
# different venues look distinguishable. Output is the exact .nexusmesh.json
# schema the engine importer (engine/assets/src/mesh_importer.cpp) parses:
#   {"format","version","name","vertices":[{"position":[x,y,z],"color":[r,g,b]}],
#    "indices":[...]}.
# Everything is deterministic (seeded only on the asset id), so re-running the
# pipeline reproduces byte-identical output.
# --------------------------------------------------------------------------- #

Vec3 = tuple[float, float, float]

# A venue file with more than this many vertices is treated as real, imported
# geometry and is NEVER overwritten by the procedural fallback (protects the
# real Venice Beach mesh, ~65k verts, from being clobbered).
PROCEDURAL_PROTECT_VERTEX_THRESHOLD = 512

# Ground plane half-extent (world units) and grid resolution (cells per side).
GROUND_HALF = 12.0
GROUND_GRID = 44


def _clamp01(value: float) -> float:
    return 0.0 if value < 0.0 else (1.0 if value > 1.0 else value)


def _mix(a: Vec3, b: Vec3, t: float) -> Vec3:
    t = _clamp01(t)
    return (
        a[0] + (b[0] - a[0]) * t,
        a[1] + (b[1] - a[1]) * t,
        a[2] + (b[2] - a[2]) * t,
    )


def _jitter(color: Vec3, amount: float, rng: random.Random) -> Vec3:
    delta = (rng.uniform(-amount, amount), rng.uniform(-amount, amount), rng.uniform(-amount, amount))
    return (
        _clamp01(color[0] + delta[0]),
        _clamp01(color[1] + delta[1]),
        _clamp01(color[2] + delta[2]),
    )


# Per-venue-type look: palette + terrain shaping + court markings + stands.
#   ground / ground_alt : two floor shades blended by a marking pattern
#   wall                 : boundary wall colour
#   stand                : tiered stand / bleacher colour
#   marker               : court line / accent colour
#   terrain              : "flat" | "slope" | "rolling" | "dunes" | "ramps"
#   markings             : "court" | "diamond" | "gridiron" | "pitch" |
#                          "fairway" | "net" | "grid" | "aisles" | "none"
#   wall_height          : boundary wall height (world units)
#   tiers                : number of stand tiers above the wall (0 = none)
VENUE_LIBRARY: dict[str, dict[str, Any]] = {
    "basketball": {
        "ground": (0.74, 0.53, 0.30), "ground_alt": (0.66, 0.45, 0.24),
        "wall": (0.15, 0.17, 0.27), "stand": (0.22, 0.25, 0.38), "marker": (0.94, 0.86, 0.26),
        "terrain": "flat", "markings": "court", "wall_height": 2.0, "tiers": 2,
    },
    "tennis": {
        "ground": (0.20, 0.46, 0.32), "ground_alt": (0.16, 0.38, 0.27),
        "wall": (0.12, 0.20, 0.16), "stand": (0.18, 0.30, 0.24), "marker": (0.95, 0.95, 0.95),
        "terrain": "flat", "markings": "net", "wall_height": 1.6, "tiers": 1,
    },
    "dojo": {
        "ground": (0.62, 0.49, 0.27), "ground_alt": (0.52, 0.40, 0.22),
        "wall": (0.26, 0.16, 0.10), "stand": (0.33, 0.21, 0.13), "marker": (0.80, 0.12, 0.12),
        "terrain": "flat", "markings": "court", "wall_height": 2.4, "tiers": 0,
    },
    "baseball": {
        "ground": (0.24, 0.55, 0.26), "ground_alt": (0.55, 0.37, 0.21),
        "wall": (0.13, 0.30, 0.16), "stand": (0.20, 0.22, 0.34), "marker": (0.95, 0.95, 0.95),
        "terrain": "flat", "markings": "diamond", "wall_height": 2.6, "tiers": 3,
    },
    "gridiron": {
        "ground": (0.20, 0.50, 0.23), "ground_alt": (0.16, 0.42, 0.19),
        "wall": (0.12, 0.16, 0.26), "stand": (0.18, 0.20, 0.32), "marker": (0.96, 0.96, 0.96),
        "terrain": "flat", "markings": "gridiron", "wall_height": 2.8, "tiers": 3,
    },
    "soccer": {
        "ground": (0.18, 0.52, 0.24), "ground_alt": (0.15, 0.45, 0.20),
        "wall": (0.12, 0.16, 0.24), "stand": (0.17, 0.19, 0.30), "marker": (0.96, 0.96, 0.96),
        "terrain": "flat", "markings": "pitch", "wall_height": 2.8, "tiers": 3,
    },
    "golf": {
        "ground": (0.31, 0.60, 0.28), "ground_alt": (0.40, 0.52, 0.24),
        "wall": (0.20, 0.40, 0.20), "stand": (0.26, 0.45, 0.24), "marker": (0.96, 0.96, 0.92),
        "terrain": "rolling", "markings": "fairway", "wall_height": 1.0, "tiers": 0,
    },
    "beach": {
        "ground": (0.85, 0.78, 0.55), "ground_alt": (0.78, 0.70, 0.47),
        "wall": (0.60, 0.55, 0.38), "stand": (0.30, 0.55, 0.70), "marker": (0.97, 0.97, 0.97),
        "terrain": "dunes", "markings": "net", "wall_height": 0.8, "tiers": 0,
    },
    "skatepark": {
        "ground": (0.55, 0.55, 0.58), "ground_alt": (0.48, 0.48, 0.51),
        "wall": (0.32, 0.33, 0.37), "stand": (0.40, 0.41, 0.45), "marker": (0.95, 0.40, 0.15),
        "terrain": "ramps", "markings": "none", "wall_height": 1.4, "tiers": 0,
    },
    "slope": {
        "ground": (0.90, 0.93, 0.97), "ground_alt": (0.78, 0.84, 0.92),
        "wall": (0.30, 0.36, 0.46), "stand": (0.40, 0.32, 0.26), "marker": (0.20, 0.45, 0.85),
        "terrain": "slope", "markings": "none", "wall_height": 1.2, "tiers": 0,
    },
    "gymnastics": {
        "ground": (0.16, 0.36, 0.66), "ground_alt": (0.13, 0.28, 0.54),
        "wall": (0.20, 0.22, 0.30), "stand": (0.26, 0.28, 0.40), "marker": (0.96, 0.78, 0.20),
        "terrain": "flat", "markings": "court", "wall_height": 2.0, "tiers": 1,
    },
    "neuro": {
        "ground": (0.07, 0.09, 0.16), "ground_alt": (0.10, 0.13, 0.22),
        "wall": (0.10, 0.13, 0.24), "stand": (0.14, 0.18, 0.32), "marker": (0.12, 0.90, 0.92),
        "terrain": "flat", "markings": "grid", "wall_height": 2.4, "tiers": 1,
    },
    "shop": {
        "ground": (0.46, 0.41, 0.46), "ground_alt": (0.39, 0.35, 0.40),
        "wall": (0.30, 0.30, 0.36), "stand": (0.36, 0.32, 0.30), "marker": (0.95, 0.80, 0.35),
        "terrain": "flat", "markings": "aisles", "wall_height": 2.6, "tiers": 0,
    },
    "arena": {
        "ground": (0.30, 0.32, 0.40), "ground_alt": (0.24, 0.26, 0.34),
        "wall": (0.16, 0.18, 0.26), "stand": (0.22, 0.24, 0.34), "marker": (0.85, 0.85, 0.90),
        "terrain": "flat", "markings": "court", "wall_height": 2.0, "tiers": 1,
    },
}

# Substring -> venue type. First match wins (ordered by specificity).
_VENUE_KEYWORDS: list[tuple[str, str]] = [
    ("volleyball", "beach"),
    ("sand", "beach"),
    ("baseball", "baseball"),
    ("gridiron", "gridiron"),
    ("football", "gridiron"),
    ("soccer", "soccer"),
    ("golf", "golf"),
    ("tennis", "tennis"),
    ("skate", "skatepark"),
    ("mountain", "slope"),
    ("slope", "slope"),
    ("snow", "slope"),
    ("gymnastics", "gymnastics"),
    ("neuro", "neuro"),
    ("shop", "shop"),
    ("dojo", "dojo"),
    ("zen", "dojo"),
    ("basketball", "basketball"),
    ("court", "basketball"),
]


def classify_venue(asset_id: str, name: str) -> str:
    """Map an asset id / display name to a venue type key in VENUE_LIBRARY."""
    haystack = f"{asset_id} {name}".lower()
    for keyword, venue_type in _VENUE_KEYWORDS:
        if keyword in haystack:
            return venue_type
    return "arena"


def _terrain_height(kind: str, x: float, z: float) -> float:
    """Deterministic ground height for a terrain style at normalised world (x,z)."""
    nx = x / GROUND_HALF
    nz = z / GROUND_HALF
    if kind == "slope":
        # A ski-run style incline along +Z with gentle moguls.
        return (nz + 1.0) * 3.0 + 0.25 * math.sin(nx * 6.0) * math.cos(nz * 5.0)
    if kind == "rolling":
        # Golf-style undulating fairway.
        return 0.6 * math.sin(nx * 2.3) + 0.5 * math.cos(nz * 1.9) + 0.25 * math.sin((nx + nz) * 3.1)
    if kind == "dunes":
        # Soft beach dunes near the edges, flat play area in the middle.
        edge = max(abs(nx), abs(nz))
        return 0.4 * edge * edge * (1.0 + 0.3 * math.sin(nx * 5.0 + nz * 4.0))
    if kind == "ramps":
        # Skatepark: a couple of raised quarter-pipe ridges.
        ramp = 0.0
        ramp += 1.6 * math.exp(-((x - 6.0) ** 2) / 6.0)
        ramp += 1.6 * math.exp(-((x + 6.0) ** 2) / 6.0)
        ramp += 0.9 * math.exp(-((z - 4.0) ** 2) / 5.0)
        return ramp
    return 0.0  # flat


def _ground_color(
    markings: str,
    x: float,
    z: float,
    spec: dict[str, Any],
    rng: random.Random,
) -> Vec3:
    """Region-aware floor colour: blends ground/ground_alt to suggest court markings."""
    base: Vec3 = spec["ground"]
    alt: Vec3 = spec["ground_alt"]
    marker: Vec3 = spec["marker"]
    r = math.hypot(x, z)

    if markings == "diamond":
        # Baseball: dirt infield diamond (rotated square) around home plate region.
        if abs(x) + abs(z) < 6.5:
            base = alt
        if abs(abs(x) - abs(z)) < 0.35 and abs(x) + abs(z) < 7.0:
            return _jitter(marker, 0.02, rng)
    elif markings in ("pitch", "court", "grid"):
        # Center circle + halfway line.
        if abs(r - 4.0) < 0.18 or abs(x) < 0.18:
            return _jitter(marker, 0.02, rng)
        if markings == "grid" and (math.sin(x * 2.6) > 0.94 or math.sin(z * 2.6) > 0.94):
            return _jitter(marker, 0.03, rng)
    elif markings == "gridiron":
        # Yard lines every couple of units across the field.
        if abs(math.sin(z * 1.6)) > 0.96:
            return _jitter(marker, 0.02, rng)
    elif markings == "net":
        # Net / center divider line across X.
        if abs(z) < 0.16:
            return _jitter(marker, 0.02, rng)
    elif markings == "aisles":
        # Shop aisles: alternating banded floor.
        if math.sin(x * 1.6) > 0.5:
            base = alt
    elif markings == "fairway":
        # Golf: putting-green pad around the hole near +Z.
        if math.hypot(x, z - 6.0) < 2.2:
            return _jitter(_mix(base, (0.2, 0.7, 0.3), 0.6), 0.02, rng)

    # Subtle checker so the floor reads as a tiled court even without markings.
    checker = ((int((x + GROUND_HALF) * 1.0) + int((z + GROUND_HALF) * 1.0)) & 1)
    blended = _mix(base, alt, 0.35 if checker else 0.0)
    return _jitter(blended, 0.025, rng)


def _add_quad(
    vertices: list[dict[str, Any]],
    indices: list[int],
    p0: Vec3,
    p1: Vec3,
    p2: Vec3,
    p3: Vec3,
    color: Vec3,
) -> None:
    base = len(vertices)
    for p in (p0, p1, p2, p3):
        vertices.append(
            {
                "position": [float(p[0]), float(p[1]), float(p[2])],
                "color": [float(color[0]), float(color[1]), float(color[2])],
            }
        )
    indices.extend([base, base + 1, base + 2, base, base + 2, base + 3])


def _build_ground(
    vertices: list[dict[str, Any]],
    indices: list[int],
    spec: dict[str, Any],
    rng: random.Random,
) -> None:
    """Subdivided NxN ground plane with shared vertices, terrain shaping + markings."""
    n = GROUND_GRID
    half = GROUND_HALF
    step = (2.0 * half) / n
    terrain = spec["terrain"]
    markings = spec["markings"]

    base_index = len(vertices)
    for i in range(n + 1):
        x = -half + i * step
        for j in range(n + 1):
            z = -half + j * step
            y = _terrain_height(terrain, x, z)
            color = _ground_color(markings, x, z, spec, rng)
            vertices.append(
                {
                    "position": [float(x), float(y), float(z)],
                    "color": [float(color[0]), float(color[1]), float(color[2])],
                }
            )

    stride = n + 1
    for i in range(n):
        for j in range(n):
            a = base_index + i * stride + j
            b = base_index + (i + 1) * stride + j
            c = base_index + (i + 1) * stride + (j + 1)
            d = base_index + i * stride + (j + 1)
            indices.extend([a, b, c, a, c, d])


def _build_walls(
    vertices: list[dict[str, Any]],
    indices: list[int],
    spec: dict[str, Any],
    rng: random.Random,
) -> None:
    """Raised boundary walls plus optional outward-stepping tiered stands."""
    half = GROUND_HALF
    segs = GROUND_GRID // 2
    step = (2.0 * half) / segs
    wall_h = float(spec["wall_height"])
    if wall_h <= 0.0:
        return
    wall_color: Vec3 = spec["wall"]
    stand_color: Vec3 = spec["stand"]
    tiers = int(spec["tiers"])

    # Four sides defined as (constant_axis, sign): build vertical wall + top cap,
    # then step outward/upward for each stand tier.
    sides = [("z", 1.0), ("z", -1.0), ("x", 1.0), ("x", -1.0)]
    for axis, sign in sides:
        for s in range(segs):
            t0 = -half + s * step
            t1 = -half + (s + 1) * step
            if axis == "z":
                base = half * sign
                p0 = (t0, 0.0, base)
                p1 = (t1, 0.0, base)
                p2 = (t1, wall_h, base)
                p3 = (t0, wall_h, base)
            else:
                base = half * sign
                p0 = (base, 0.0, t0)
                p1 = (base, 0.0, t1)
                p2 = (base, wall_h, t1)
                p3 = (base, wall_h, t0)
            col = _jitter(wall_color, 0.03, rng)
            _add_quad(vertices, indices, p0, p1, p2, p3, col)

            # Tiered stands: each tier steps outward (away from center) and upward.
            inner_h = wall_h
            inner_off = half
            for tier in range(tiers):
                outer_off = inner_off + 1.2
                outer_h = inner_h + 1.1
                scol = _jitter(stand_color, 0.04, rng)
                if axis == "z":
                    q0 = (t0, inner_h, inner_off * sign)
                    q1 = (t1, inner_h, inner_off * sign)
                    q2 = (t1, outer_h, outer_off * sign)
                    q3 = (t0, outer_h, outer_off * sign)
                else:
                    q0 = (inner_off * sign, inner_h, t0)
                    q1 = (inner_off * sign, inner_h, t1)
                    q2 = (outer_off * sign, outer_h, t1)
                    q3 = (outer_off * sign, outer_h, t0)
                _add_quad(vertices, indices, q0, q1, q2, q3, scol)
                inner_h = outer_h
                inner_off = outer_off


def _build_features(
    vertices: list[dict[str, Any]],
    indices: list[int],
    spec: dict[str, Any],
    rng: random.Random,
) -> None:
    """A couple of simple recognisable props per venue (poles, net posts, flag, beacon)."""
    marker: Vec3 = spec["marker"]
    markings = spec["markings"]

    def add_box(cx: float, cz: float, sx: float, sz: float, y0: float, y1: float, color: Vec3) -> None:
        x0, x1 = cx - sx, cx + sx
        z0, z1 = cz - sz, cz + sz
        # 4 side faces (top/bottom omitted - not needed for a solid-looking prop).
        _add_quad(vertices, indices, (x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0), color)
        _add_quad(vertices, indices, (x1, y0, z1), (x0, y0, z1), (x0, y1, z1), (x1, y1, z1), color)
        _add_quad(vertices, indices, (x1, y0, z0), (x1, y0, z1), (x1, y1, z1), (x1, y1, z0), color)
        _add_quad(vertices, indices, (x0, y0, z1), (x0, y0, z0), (x0, y1, z0), (x0, y1, z1), color)
        _add_quad(vertices, indices, (x0, y1, z0), (x1, y1, z0), (x1, y1, z1), (x0, y1, z1), color)

    if markings == "net":
        # Two net posts on the center divider.
        add_box(-GROUND_HALF * 0.55, 0.0, 0.18, 0.18, 0.0, 2.4, marker)
        add_box(GROUND_HALF * 0.55, 0.0, 0.18, 0.18, 0.0, 2.4, marker)
    elif markings == "fairway":
        # Flag pin on the putting green.
        add_box(0.0, 6.0, 0.08, 0.08, 0.0, 2.6, (0.95, 0.95, 0.92))
        add_box(0.35, 6.0, 0.45, 0.05, 2.0, 2.6, (0.9, 0.15, 0.15))
    elif markings in ("court", "diamond", "gridiron", "pitch", "grid"):
        # Goal / hoop posts at each end.
        end = GROUND_HALF * 0.85
        add_box(0.0, end, 0.6, 0.18, 0.0, 3.0, marker)
        add_box(0.0, -end, 0.6, 0.18, 0.0, 3.0, marker)

    # A center beacon so every venue has a vertical landmark.
    add_box(0.0, 0.0, 0.25, 0.25, 0.0, 1.6, _jitter(marker, 0.05, rng))


def procedural_venue_payload(
    name: str,
    source_path: Path,
    asset_id: str,
    kind: str = "environment",
) -> dict[str, Any]:
    """Build a deterministic procedural venue (or marker) mesh in nexusmesh schema."""
    seed = int(hashlib.md5(asset_id.encode("utf-8")).hexdigest(), 16) % (2**32)
    rng = random.Random(seed)

    vertices: list[dict[str, Any]] = []
    indices: list[int] = []

    if kind == "marker":
        # A standalone landmark obelisk rather than a full arena.
        spec = VENUE_LIBRARY["arena"]
        accent: Vec3 = (0.18, 0.85, 0.95)
        # Octagonal base pad.
        ring = 8
        cx, cz = 0.0, 0.0
        center_top = len(vertices)
        vertices.append({"position": [0.0, 0.05, 0.0], "color": list(_mix(accent, (1, 1, 1), 0.3))})
        for k in range(ring):
            ang = 2.0 * math.pi * k / ring
            x = cx + 2.2 * math.cos(ang)
            z = cz + 2.2 * math.sin(ang)
            col = _jitter(accent, 0.04, rng)
            vertices.append({"position": [x, 0.0, z], "color": list(col)})
        for k in range(ring):
            a = center_top
            b = center_top + 1 + k
            c = center_top + 1 + ((k + 1) % ring)
            indices.extend([a, b, c])
        # Tapering obelisk on top of the pad.
        levels = 6
        prev_ring: list[int] = []
        for lvl in range(levels + 1):
            y = 0.05 + lvl * 0.9
            radius = max(0.05, 1.1 * (1.0 - lvl / (levels + 0.5)))
            cur_ring: list[int] = []
            shade = _mix(accent, (0.9, 0.2, 0.6), lvl / levels)
            for k in range(4):
                ang = math.pi / 4.0 + 2.0 * math.pi * k / 4.0
                x = radius * math.cos(ang)
                z = radius * math.sin(ang)
                cur_ring.append(len(vertices))
                vertices.append({"position": [x, y, z], "color": list(_jitter(shade, 0.03, rng))})
            if prev_ring:
                for k in range(4):
                    a = prev_ring[k]
                    b = prev_ring[(k + 1) % 4]
                    c = cur_ring[(k + 1) % 4]
                    d = cur_ring[k]
                    indices.extend([a, b, c, a, c, d])
            prev_ring = cur_ring
    else:
        venue_type = classify_venue(asset_id, name)
        spec = VENUE_LIBRARY.get(venue_type, VENUE_LIBRARY["arena"])
        _build_ground(vertices, indices, spec, rng)
        _build_walls(vertices, indices, spec, rng)
        _build_features(vertices, indices, spec, rng)
        spec = {**spec, "venue_type": venue_type}

    return {
        "format": "nexusmesh",
        "version": "1",
        "name": name,
        "source_file": str(source_path.name),
        "conversion_method": "procedural_venue",
        "venue_type": spec.get("venue_type", "marker" if kind == "marker" else "arena"),
        "vertices": vertices,
        "indices": indices,
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


def stub_convert_to_nexusmesh(
    source_path: Path,
    dest_path: Path,
    name: str,
    asset_id: str | None = None,
    kind: str = "environment",
) -> tuple[str, int, bool]:
    """Convert source geometry to NEXUS mesh JSON using trimesh, pyassimp, or Blender/assimp CLI.

    When no mesh backend can load the source, fall back to a deterministic
    procedural venue mesh instead of a degenerate 4-vertex pyramid.
    """
    try:
        mesh, method = load_source_mesh(source_path)
        payload = trimesh_to_payload(mesh, name, source_path, method)
        write_nexusmesh_payload(dest_path, payload)
        vertex_count = len(payload["vertices"])
        print(f"Converted ({method}) -> {dest_path} ({vertex_count} vertices)")
        return method, vertex_count, True
    except Exception as exc:
        print(f"Conversion failed for {source_path.name}: {exc}", file=sys.stderr)
        payload = procedural_venue_payload(name, source_path, asset_id or name, kind)
        write_nexusmesh_payload(dest_path, payload)
        vertex_count = len(payload["vertices"])
        print(
            f"Procedural fallback ({payload['venue_type']}) -> {dest_path} "
            f"({vertex_count} vertices, {len(payload['indices']) // 3} triangles)"
        )
        return "procedural_venue", vertex_count, False


def _existing_vertex_count(path: Path) -> int:
    """Cheap read of an existing nexusmesh vertex count (0 if missing/unreadable)."""
    if not path.exists():
        return 0
    try:
        with path.open(encoding="utf-8") as handle:
            data = json.load(handle)
        return len(data.get("vertices", []))
    except Exception:
        return 0


def regenerate_procedural_fallbacks(
    manifest: dict[str, Any],
    only_asset: str | None = None,
    force: bool = False,
) -> list[dict[str, Any]]:
    """Regenerate procedural venue meshes for every degenerate/missing fallback.

    Driven by the manifest asset list. Real imported geometry (vertex count above
    PROCEDURAL_PROTECT_VERTEX_THRESHOLD) is left untouched unless ``force`` is set,
    which guarantees the real Venice Beach mesh is never clobbered.
    """
    import_root = manifest.get("import_root", "assets/nexus/imported")
    results: list[dict[str, Any]] = []

    for asset in manifest.get("assets", []):
        asset_id = asset.get("id")
        imported_mesh = asset.get("imported_mesh")
        if not asset_id or not imported_mesh:
            continue
        if only_asset and asset_id != only_asset:
            continue

        dest = REPO_ROOT / import_root / imported_mesh
        existing = _existing_vertex_count(dest)
        if existing > PROCEDURAL_PROTECT_VERTEX_THRESHOLD and not force:
            print(f"Protect (real geometry, {existing} verts) -> {dest.name}")
            results.append({"id": asset_id, "file": dest.name, "action": "protected", "vertices": existing})
            continue

        name = asset_id
        source_path = Path(imported_mesh)
        payload = procedural_venue_payload(name, source_path, asset_id, asset.get("kind", "environment"))
        write_nexusmesh_payload(dest, payload)
        verts = len(payload["vertices"])
        tris = len(payload["indices"]) // 3
        print(
            f"Procedural ({payload['venue_type']}) -> {dest.name} "
            f"({verts} verts, {tris} tris)"
        )
        results.append(
            {
                "id": asset_id,
                "file": dest.name,
                "action": "regenerated",
                "venue_type": payload["venue_type"],
                "vertices": verts,
                "triangles": tris,
            }
        )
    return results


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
            stub_convert_to_nexusmesh(raw_path, dest, asset_id, asset_id, asset.get("kind", "environment"))
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
    parser.add_argument(
        "--regenerate-procedural",
        action="store_true",
        help="Regenerate procedural venue meshes for degenerate/missing fallbacks "
        "(protects real imported geometry such as Venice Beach)",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="With --regenerate-procedural, also overwrite real geometry (NOT recommended)",
    )
    args = parser.parse_args()

    if not args.manifest.exists():
        print(f"Manifest not found: {args.manifest}", file=sys.stderr)
        return 1

    manifest = load_manifest(args.manifest)
    import_root = manifest.get("import_root", "assets/nexus/imported")

    if args.regenerate_procedural:
        results = regenerate_procedural_fallbacks(manifest, only_asset=args.asset, force=args.force)
        regenerated = sum(1 for r in results if r["action"] == "regenerated")
        protected = sum(1 for r in results if r["action"] == "protected")
        print(f"\nRegenerated {regenerated} procedural venue meshes, protected {protected} real meshes.")
        return 0

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
