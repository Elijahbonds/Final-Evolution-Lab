#!/usr/bin/env python3
"""BVH → NexusAnimationAsset JSON.

Feed this the BVH exported by any video-to-motion tool (DeepMotion, Rokoko
Video, Plask, Move.ai) — driven by AI-generated video or real footage — and it
emits a keyframe asset the app's existing player (CourtSceneView
.playKeyframeAnimation / NexusAnimationAsset) consumes directly.

Usage:
  python3 bvh_to_nexus_animation.py in.bvh out.json \
      --id dunk_windmill_v1 --title "Windmill Dunk" --category dunk

Joint mapping: standard mocap skeleton names → the app's capsule-rig node
names (see GameSceneFactory.addPlayerAvatar / NexusGameplayAvatarLoader).
Unmapped BVH joints are ignored; missing rig joints just don't animate.
"""
import argparse
import json
import math
import re
import sys
from datetime import datetime, timezone

# mocap skeleton (DeepMotion/Mixamo/CMU conventions, case-insensitive,
# optional prefixes like "mixamorig:") → app rig node names
JOINT_MAP = {
    "hips": "hip",
    "spine": "torso", "spine1": "torso", "chest": "torso",
    "neck": "neck",
    "head": "head",
    "leftarm": "lArm", "leftupperarm": "lArm", "leftshoulder": "lArm",
    "rightarm": "rArm", "rightupperarm": "rArm", "rightshoulder": "rArm",
    "leftupleg": "lLeg", "leftupperleg": "lLeg", "leftthigh": "lLeg",
    "rightupleg": "rLeg", "rightupperleg": "rLeg", "rightthigh": "rLeg",
    "leftleg": "lShin", "leftlowerleg": "lShin", "leftshin": "lShin",
    "rightleg": "rShin", "rightlowerleg": "rShin", "rightshin": "rShin",
}


def normalize(name: str) -> str:
    return re.sub(r"^.*:", "", name).replace("_", "").lower()


def euler_to_quat(rx, ry, rz, order):
    """Per-axis quaternions composed in BVH channel order (degrees)."""
    def axis_quat(axis, deg):
        h = math.radians(deg) / 2.0
        s = math.sin(h)
        return {
            "X": (s, 0.0, 0.0, math.cos(h)),
            "Y": (0.0, s, 0.0, math.cos(h)),
            "Z": (0.0, 0.0, s, math.cos(h)),
        }[axis]

    def mul(a, b):
        ax, ay, az, aw = a
        bx, by, bz, bw = b
        return (
            aw * bx + ax * bw + ay * bz - az * by,
            aw * by - ax * bz + ay * bw + az * bx,
            aw * bz + ax * by - ay * bx + az * bw,
            aw * bw - ax * bx - ay * by - az * bz,
        )

    q = (0.0, 0.0, 0.0, 1.0)
    values = {"X": rx, "Y": ry, "Z": rz}
    for axis in order:
        q = mul(q, axis_quat(axis, values[axis]))
    return q


def parse_bvh(path):
    text = open(path).read()
    if "MOTION" not in text:
        sys.exit("not a BVH file (no MOTION section)")
    hierarchy, motion = text.split("MOTION", 1)

    # Joint order + channels
    joints = []  # (name, [channels])
    stack = []
    for line in hierarchy.splitlines():
        line = line.strip()
        if line.startswith(("ROOT", "JOINT")):
            stack.append(line.split()[1])
        elif line.startswith("End Site"):
            stack.append(None)
        elif line.startswith("CHANNELS"):
            parts = line.split()
            joints.append((stack[-1], parts[2:2 + int(parts[1])]))
        elif line.startswith("}"):
            if stack:
                stack.pop()

    lines = [l.strip() for l in motion.splitlines() if l.strip()]
    frame_count = int(lines[0].split(":")[1])
    frame_time = float(lines[1].split(":")[1])
    frames = [[float(x) for x in l.split()] for l in lines[2:2 + frame_count]]
    return joints, frames, frame_time


def convert(args):
    joints, frames, frame_time = parse_bvh(args.bvh)
    keyframes = []
    for fi, values in enumerate(frames):
        rotations, offsets = {}, {}
        cursor = 0
        for name, channels in joints:
            n = len(channels)
            chunk = values[cursor:cursor + n]
            cursor += n
            if name is None:
                continue
            rig = JOINT_MAP.get(normalize(name))
            if rig is None:
                continue
            rot = {"X": 0.0, "Y": 0.0, "Z": 0.0}
            pos = {}
            order = ""
            for ch, v in zip(channels, chunk):
                if ch.endswith("rotation"):
                    axis = ch[0].upper()
                    rot[axis] = v
                    order += axis
                elif ch.endswith("position"):
                    pos[ch[0].lower()] = v
            x, y, z, w = euler_to_quat(rot["X"], rot["Y"], rot["Z"], order or "ZXY")
            rotations[rig] = {"x": x, "y": y, "z": z, "w": w}
            if rig == "hip" and pos:
                s = args.position_scale
                offsets[rig] = {"x": pos.get("x", 0) * s,
                                "y": pos.get("y", 0) * s,
                                "z": pos.get("z", 0) * s}
        keyframes.append({
            "timestamp": round(fi * frame_time, 5),
            "jointRotations": rotations,
            "translationOffsets": offsets,
        })

    duration = round(len(frames) * frame_time, 4)
    asset = {
        "header": {
            "id": args.id,
            "title": args.title,
            "competitionName": args.competition,
            "category": args.category,
            "creatorId": args.creator,
            "captureTimestamp": datetime.now(timezone.utc).isoformat(),
            "frameRate": round(1.0 / frame_time, 2),
            "duration": duration,
            "jointCount": len({j for f in keyframes for j in f["jointRotations"]}),
        },
        "keyframes": keyframes,
    }
    json.dump(asset, open(args.out, "w"), indent=1)
    print(f"OK {args.out}: {len(keyframes)} frames, {duration}s, "
          f"{asset['header']['jointCount']} rig joints")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("bvh")
    ap.add_argument("out")
    ap.add_argument("--id", required=True)
    ap.add_argument("--title", default="Imported Motion")
    ap.add_argument("--category", default="dunk")
    ap.add_argument("--competition", default="")
    ap.add_argument("--creator", default="mocap")
    ap.add_argument("--position-scale", type=float, default=0.01,
                    help="BVH cm → scene meters")
    convert(ap.parse_args())
