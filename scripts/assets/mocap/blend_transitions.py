#!/usr/bin/env python3
"""Generates state-transition animations by slerp-crossfading two assets.

Builds the glue the state machine needs (idle→charge, charge→dunk,
dunk→land, land→celebrate, fail→stumble…) from any pair of library
assets — starter or mocap, same format either way.

Usage:
  python3 blend_transitions.py <library_dir> [--overlap 0.25]
  python3 blend_transitions.py <library_dir> --pair starter_idle_breathe starter_jump_charge
"""
import argparse
import json
import math
import sys
from datetime import datetime, timezone
from pathlib import Path

DEFAULT_CHAINS = [
    ("starter_idle_breathe", "starter_jump_charge"),
    ("starter_jump_charge", "starter_dunk_power"),
    ("starter_jump_charge", "starter_dunk_windmill"),
    ("starter_dunk_power", "starter_land_recover"),
    ("starter_dunk_windmill", "starter_land_recover"),
    ("starter_land_recover", "starter_celebrate"),
]

IDENTITY = {"x": 0.0, "y": 0.0, "z": 0.0, "w": 1.0}
ZERO = {"x": 0.0, "y": 0.0, "z": 0.0}


def slerp(qa, qb, t):
    ax, ay, az, aw = qa["x"], qa["y"], qa["z"], qa["w"]
    bx, by, bz, bw = qb["x"], qb["y"], qb["z"], qb["w"]
    dot = ax * bx + ay * by + az * bz + aw * bw
    if dot < 0:
        bx, by, bz, bw, dot = -bx, -by, -bz, -bw, -dot
    if dot > 0.9995:
        x, y, z, w = (ax + (bx - ax) * t, ay + (by - ay) * t,
                      az + (bz - az) * t, aw + (bw - aw) * t)
        n = math.sqrt(x * x + y * y + z * z + w * w) or 1.0
        return {"x": x / n, "y": y / n, "z": z / n, "w": w / n}
    th = math.acos(max(-1.0, min(1.0, dot)))
    sa, sb = math.sin((1 - t) * th) / math.sin(th), math.sin(t * th) / math.sin(th)
    return {"x": ax * sa + bx * sb, "y": ay * sa + by * sb,
            "z": az * sa + bz * sb, "w": aw * sa + bw * sb}


def sample(asset, t):
    """Interpolated (rotations, offsets) at time t."""
    kf = asset["keyframes"]
    t = max(kf[0]["timestamp"], min(t, kf[-1]["timestamp"]))
    for i in range(len(kf) - 1):
        a, b = kf[i], kf[i + 1]
        if a["timestamp"] <= t <= b["timestamp"]:
            span = b["timestamp"] - a["timestamp"] or 1.0
            u = (t - a["timestamp"]) / span
            joints = set(a["jointRotations"]) | set(b["jointRotations"])
            rot = {j: slerp(a["jointRotations"].get(j, IDENTITY),
                            b["jointRotations"].get(j, IDENTITY), u) for j in joints}
            offs = set(a["translationOffsets"]) | set(b["translationOffsets"])
            off = {}
            for j in offs:
                pa = a["translationOffsets"].get(j, ZERO)
                pb = b["translationOffsets"].get(j, ZERO)
                off[j] = {k: pa[k] + (pb[k] - pa[k]) * u for k in ("x", "y", "z")}
            return rot, off
    last = kf[-1]
    return last["jointRotations"], last["translationOffsets"]


def blend(a, b, overlap, fps=30.0):
    """Tail of `a` crossfades into head of `b` over `overlap` seconds."""
    a_end = a["keyframes"][-1]["timestamp"]
    frames = max(4, int(overlap * fps))
    keyframes = []
    for i in range(frames + 1):
        u = i / frames                      # 0 → 1 across the transition
        ease = u * u * (3 - 2 * u)          # smoothstep
        ta = a_end - overlap * (1 - u)      # walk out of a's tail
        tb = u * overlap                    # walk into b's head
        ra, oa = sample(a, ta)
        rb, ob = sample(b, tb)
        joints = set(ra) | set(rb)
        rot = {j: slerp(ra.get(j, IDENTITY), rb.get(j, IDENTITY), ease) for j in joints}
        offs = set(oa) | set(ob)
        off = {}
        for j in offs:
            pa, pb = oa.get(j, ZERO), ob.get(j, ZERO)
            off[j] = {k: pa[k] + (pb[k] - pa[k]) * ease for k in ("x", "y", "z")}
        keyframes.append({"timestamp": round(i / fps, 5),
                          "jointRotations": rot, "translationOffsets": off})
    return keyframes


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("library")
    ap.add_argument("--overlap", type=float, default=0.25)
    ap.add_argument("--pair", nargs=2, action="append")
    args = ap.parse_args()
    lib = Path(args.library)

    def load(aid):
        p = lib / f"{aid}.nexusanim.json"
        if not p.exists():
            sys.exit(f"missing asset: {p}")
        return json.load(open(p))

    pairs = args.pair or DEFAULT_CHAINS
    for src, dst in pairs:
        a, b = load(src), load(dst)
        kf = blend(a, b, args.overlap)
        tid = f"trans_{src.replace('starter_', '')}__{dst.replace('starter_', '')}"
        asset = {
            "header": {
                "id": tid,
                "title": f"{a['header']['title']} → {b['header']['title']}",
                "competitionName": "", "category": "transition",
                "creatorId": "blend_pipeline",
                "captureTimestamp": datetime.now(timezone.utc).isoformat(),
                "frameRate": 30.0,
                "duration": kf[-1]["timestamp"],
                "jointCount": len(kf[0]["jointRotations"]),
            },
            "keyframes": kf,
        }
        out = lib / f"{tid}.nexusanim.json"
        json.dump(asset, open(out, "w"), indent=1)
        print(f"OK {out.name}: {len(kf)} frames")


if __name__ == "__main__":
    main()
