#!/usr/bin/env python3
"""
validate_assets.py — THE ASSET GATE. Fails closed.

    python3 tools/validate_assets.py assets/ready
    python3 tools/validate_assets.py assets/ready --json report.json

Parses GLB files directly (pure stdlib — no Blender, no trimesh, no network)
and rejects anything that violates the FEL budget or spec. Exit code 1 on any
violation so CI can gate on it.

WHY PURE STDLIB: this runs on every push and on every dropped asset. A gate
that needs a heavy toolchain gets skipped, and a skipped gate is no gate.
A GLB is a tiny binary header plus a JSON chunk — everything below reads it
with `struct` and `json`.

SKELETON RULE — READ THIS
-------------------------
FEL resolves bones by UNPREFIXED name at runtime (`Hips`, `LeftArm`, ...).
This gate therefore checks for the REQUIRED NAME SET, and REJECTS
`mixamorig:`-prefixed rigs. It deliberately does NOT enforce "exactly 65
bones": a count check would reject a good rig carrying extra twist/finger
bones and accept a 65-bone rig with names nothing can resolve. Names are
what the engine resolves; names are what we validate.
See docs/abacus-batches/m65-avatar-system-phase0/AvatarSkeletonSpec.md.
"""

import argparse
import json
import os
import struct
import sys

# ── budgets ───────────────────────────────────────────────────────────────
TRI_BUDGET = {
    "avatar": 25000,     # full avatar, all slots
    "part": 8000,        # one slot item
    "prop": 5000,
    "environment": 150000,
    "animation": 0,      # animation GLBs must carry NO mesh data
}
TEXTURE_MAX = {"albedo": 1024, "normal": 512, "orm": 512, "mask": 1024, "default": 1024}

REQUIRED_BONES = {
    "Hips", "Spine", "Spine1", "Spine2", "Neck", "Head",
    "LeftShoulder", "LeftArm", "LeftForeArm", "LeftHand",
    "RightShoulder", "RightArm", "RightForeArm", "RightHand",
    "LeftUpLeg", "LeftLeg", "LeftFoot", "LeftToeBase",
    "RightUpLeg", "RightLeg", "RightFoot", "RightToeBase",
}

GLB_MAGIC = 0x46546C67
CHUNK_JSON = 0x4E4F534A


class Violation:
    def __init__(self, severity, code, message):
        self.severity = severity          # "error" | "warning"
        self.code = code
        self.message = message

    def as_dict(self):
        return {"severity": self.severity, "code": self.code, "message": self.message}


def read_glb_json(path):
    """Return the glTF JSON chunk of a .glb, or None if not a valid GLB."""
    with open(path, "rb") as fh:
        header = fh.read(12)
        if len(header) < 12:
            return None
        magic, _version, _length = struct.unpack("<III", header)
        if magic != GLB_MAGIC:
            return None
        while True:
            chunk_header = fh.read(8)
            if len(chunk_header) < 8:
                return None
            chunk_len, chunk_type = struct.unpack("<II", chunk_header)
            data = fh.read(chunk_len)
            if chunk_type == CHUNK_JSON:
                return json.loads(data.decode("utf-8"))
            # skip padding to 4-byte alignment
            pad = (4 - (chunk_len % 4)) % 4
            fh.read(pad)


def classify(path, gltf):
    """Infer the asset class from the path, falling back to content."""
    p = path.lower()
    for key in ("animation", "environment", "avatar", "prop", "part"):
        if key in p:
            return key
    if not gltf.get("meshes") and gltf.get("animations"):
        return "animation"
    return "part"


def triangle_count(gltf):
    accessors = gltf.get("accessors", [])
    total = 0
    for mesh in gltf.get("meshes", []):
        for prim in mesh.get("primitives", []):
            # mode 4 == TRIANGLES (default when absent)
            if prim.get("mode", 4) != 4:
                continue
            if "indices" in prim:
                idx = prim["indices"]
                if idx < len(accessors):
                    total += accessors[idx].get("count", 0) // 3
            else:
                pos = prim.get("attributes", {}).get("POSITION")
                if pos is not None and pos < len(accessors):
                    total += accessors[pos].get("count", 0) // 3
    return total


def bone_names(gltf):
    nodes = gltf.get("nodes", [])
    names = set()
    for skin in gltf.get("skins", []):
        for joint in skin.get("joints", []):
            if joint < len(nodes):
                names.add(nodes[joint].get("name", ""))
    return names


def texture_kind(name):
    n = (name or "").lower()
    for key in ("albedo", "normal", "orm", "mask"):
        if key in n:
            return key
    return "default"


def check_textures(gltf, violations):
    images = gltf.get("images", [])
    ext_used = gltf.get("extensionsUsed", [])
    basisu = "KHR_texture_basisu" in ext_used

    for img in images:
        name = img.get("name") or img.get("uri") or "<embedded>"
        mime = img.get("mimeType", "")
        uri = img.get("uri", "")
        is_ktx2 = "ktx2" in mime.lower() or uri.lower().endswith(".ktx2") or basisu
        if not is_ktx2:
            violations.append(Violation(
                "error", "TEX_UNCOMPRESSED",
                "texture '%s' is not KTX2/Basis (mime=%s). Convert before shipping." % (name, mime or "n/a"),
            ))

    # dimensions live on the KHR_texture_basisu / source images; glTF JSON
    # doesn't always carry them, so this is a warning-level heuristic on name
    for tex in gltf.get("textures", []):
        src = tex.get("source")
        if src is None or src >= len(images):
            continue
        kind = texture_kind(images[src].get("name") or images[src].get("uri"))
        limit = TEXTURE_MAX.get(kind, TEXTURE_MAX["default"])
        # only reportable when the exporter wrote extras.width/height
        extras = images[src].get("extras") or {}
        w, h = extras.get("width"), extras.get("height")
        if w and h:
            if w > limit or h > limit:
                violations.append(Violation(
                    "error", "TEX_OVERSIZE",
                    "texture '%s' is %dx%d, over the %dpx budget for '%s'." % (
                        images[src].get("name", "?"), w, h, limit, kind),
                ))
            if (w & (w - 1)) or (h & (h - 1)):
                violations.append(Violation(
                    "error", "TEX_NOT_POW2",
                    "texture '%s' is %dx%d — dimensions must be power-of-two." % (
                        images[src].get("name", "?"), w, h),
                ))


def check_transform(gltf, violations):
    """Scene root must sit at the origin with identity scale."""
    nodes = gltf.get("nodes", [])
    scenes = gltf.get("scenes", [])
    if not scenes:
        return
    roots = scenes[gltf.get("scene", 0)].get("nodes", [])
    for r in roots:
        if r >= len(nodes):
            continue
        n = nodes[r]
        t = n.get("translation")
        if t and any(abs(v) > 0.001 for v in t):
            violations.append(Violation(
                "warning", "ROOT_OFFSET",
                "root node '%s' is offset from the origin by %s." % (n.get("name", "?"), t),
            ))
        s = n.get("scale")
        if s and any(abs(v - 1.0) > 0.001 for v in s):
            violations.append(Violation(
                "warning", "ROOT_SCALED",
                "root node '%s' carries a non-identity scale %s — bake it." % (n.get("name", "?"), s),
            ))


def validate_file(path):
    violations = []
    gltf = read_glb_json(path)
    if gltf is None:
        return [Violation("error", "NOT_GLB", "not a valid .glb container")], {}

    asset_class = classify(path, gltf)
    tris = triangle_count(gltf)
    bones = bone_names(gltf)

    budget = TRI_BUDGET.get(asset_class, TRI_BUDGET["part"])
    if asset_class == "animation":
        if gltf.get("meshes"):
            violations.append(Violation(
                "error", "ANIM_HAS_MESH",
                "animation asset contains %d mesh(es) — export skeleton + animation only."
                % len(gltf["meshes"]),
            ))
    elif tris > budget:
        violations.append(Violation(
            "error", "TRI_BUDGET",
            "%d triangles exceeds the %d budget for class '%s'." % (tris, budget, asset_class),
        ))

    # ── skeleton (see the module docstring for why names, not counts) ──
    if bones:
        prefixed = [b for b in bones if b.startswith("mixamorig:")]
        if prefixed:
            violations.append(Violation(
                "error", "BONE_PREFIX",
                "%d bone(s) carry the 'mixamorig:' prefix. FEL resolves bones by "
                "UNPREFIXED name — every authored clip would silently no-op and "
                "characters would freeze at bind pose. Strip the prefix at import."
                % len(prefixed),
            ))
        stripped = {b.replace("mixamorig:", "") for b in bones}
        missing = sorted(REQUIRED_BONES - stripped)
        if missing:
            violations.append(Violation(
                "error", "BONE_MISSING",
                "skinned asset is missing required bones: %s" % ", ".join(missing),
            ))

    check_textures(gltf, violations)
    check_transform(gltf, violations)

    stats = {
        "class": asset_class,
        "triangles": tris,
        "bones": len(bones),
        "meshes": len(gltf.get("meshes", [])),
        "animations": len(gltf.get("animations", [])),
        "images": len(gltf.get("images", [])),
    }
    return violations, stats


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("path", help="file or directory to validate")
    ap.add_argument("--json", help="write a machine-readable report here")
    ap.add_argument("--warn-only", action="store_true",
                    help="report but always exit 0 (use while onboarding assets)")
    args = ap.parse_args()

    targets = []
    if os.path.isdir(args.path):
        for root, _dirs, files in os.walk(args.path):
            targets += [os.path.join(root, f) for f in files if f.lower().endswith(".glb")]
    elif os.path.isfile(args.path):
        targets = [args.path]

    if not targets:
        print("[GATE] no .glb files found under %s — nothing to validate." % args.path)
        return 0

    report = {"files": [], "errors": 0, "warnings": 0}
    for path in sorted(targets):
        violations, stats = validate_file(path)
        errs = [v for v in violations if v.severity == "error"]
        warns = [v for v in violations if v.severity == "warning"]
        report["errors"] += len(errs)
        report["warnings"] += len(warns)
        report["files"].append({
            "path": path, "stats": stats,
            "violations": [v.as_dict() for v in violations],
        })

        status = "FAIL" if errs else ("WARN" if warns else "PASS")
        print("[GATE] %-4s %s  (%s, %s tris, %s bones)" % (
            status, path, stats.get("class", "?"), stats.get("triangles", "?"), stats.get("bones", "?")))
        for v in violations:
            print("       %-7s %-16s %s" % (v.severity.upper(), v.code, v.message))

    print("\n[GATE] %d file(s): %d error(s), %d warning(s)"
          % (len(targets), report["errors"], report["warnings"]))

    if args.json:
        with open(args.json, "w") as fh:
            json.dump(report, fh, indent=2)

    if report["errors"] and not args.warn_only:
        print("[GATE] FAILING THE BUILD — fix the errors above or move the asset out of ready/.")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
