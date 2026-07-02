#!/usr/bin/env python3
"""Generates the starter animation library (procedural, physics-plausible)
in NexusAnimationAsset JSON — the same format bvh_to_nexus_animation.py emits
from DeepMotion/Rokoko output, so mocap of real dunks replaces these 1:1.

Usage: python3 generate_starter_animations.py <out_dir>
"""
import json
import math
import sys
from datetime import datetime, timezone
from pathlib import Path

FPS = 30.0
G = 9.81

def quat_x(deg):
    h = math.radians(deg) / 2
    return {"x": math.sin(h), "y": 0.0, "z": 0.0, "w": math.cos(h)}

def quat_z(deg):
    h = math.radians(deg) / 2
    return {"x": 0.0, "y": 0.0, "z": math.sin(h), "w": math.cos(h)}

def quat_y(deg):
    h = math.radians(deg) / 2
    return {"x": 0.0, "y": math.sin(h), "z": 0.0, "w": math.cos(h)}

def frames(duration, build):
    out = []
    n = int(duration * FPS)
    for i in range(n + 1):
        t = i / FPS
        p = t / duration if duration else 0
        rot, off = build(t, p)
        out.append({"timestamp": round(t, 4),
                    "jointRotations": rot,
                    "translationOffsets": off})
    return out

def asset(aid, title, category, duration, build):
    kf = frames(duration, build)
    return {
        "header": {
            "id": aid, "title": title, "competitionName": "",
            "category": category, "creatorId": "procedural_starter",
            "captureTimestamp": datetime.now(timezone.utc).isoformat(),
            "frameRate": FPS, "duration": duration,
            "jointCount": len({j for f in kf for j in f["jointRotations"]}),
        },
        "keyframes": kf,
    }

def jump_height(t, flight):
    """Ballistic arc: 0 at takeoff/landing, apex g*T^2/8."""
    if t < 0 or t > flight:
        return 0.0
    v0 = G * flight / 2
    return v0 * t - 0.5 * G * t * t

# --- Library ---------------------------------------------------------------

def idle_breathe(t, p):
    s = math.sin(2 * math.pi * t / 3.0)
    return ({
        "torso": quat_x(1.5 * s),
        "head": quat_x(-1.0 * s),
        "lArm": quat_z(-4 + 1.5 * s),
        "rArm": quat_z(4 - 1.5 * s),
    }, {})

def jump_charge(t, p):
    dip = math.sin(math.pi * p)  # crouch then extend
    return ({
        "hip": quat_x(18 * dip),
        "torso": quat_x(12 * dip),
        "lLeg": quat_x(-30 * dip), "rLeg": quat_x(-30 * dip),
        "lShin": quat_x(45 * dip), "rShin": quat_x(45 * dip),
        "lArm": quat_x(-35 * dip), "rArm": quat_x(-35 * dip),
    }, {"hip": {"x": 0, "y": -0.14 * dip, "z": 0}})

def dunk_power(t, p):
    flight = 0.62
    h = jump_height(t, flight)
    windup = min(1.0, p * 2.2)
    slam = max(0.0, (p - 0.62) / 0.38)
    return ({
        "hip": quat_x(-8 * windup),
        "torso": quat_x(-14 * windup + 26 * slam),
        "rArm": quat_x(-165 * windup + 120 * slam),
        "lArm": quat_x(-45 * windup + 20 * slam),
        "lLeg": quat_x(24 * windup), "rLeg": quat_x(30 * windup),
        "lShin": quat_x(38 * windup * (1 - slam)),
        "rShin": quat_x(42 * windup * (1 - slam)),
        "head": quat_x(-6 * windup),
    }, {"hip": {"x": 0, "y": h, "z": -0.35 * p}})

def dunk_windmill(t, p):
    flight = 0.68
    h = jump_height(t, flight)
    sweep = 360.0 * min(1.0, max(0.0, (p - 0.15) / 0.7))
    return ({
        "hip": quat_y(10 * math.sin(math.pi * p)),
        "torso": quat_x(-10 + 18 * p),
        "rArm": {"x": math.sin(math.radians(sweep) / 2), "y": 0.0, "z": 0.0,
                 "w": math.cos(math.radians(sweep) / 2)},
        "lArm": quat_z(30 * math.sin(math.pi * p)),
        "lLeg": quat_x(20), "rLeg": quat_x(26),
        "lShin": quat_x(30), "rShin": quat_x(34),
    }, {"hip": {"x": 0, "y": h, "z": -0.3 * p}})

def land_recover(t, p):
    absorb = math.sin(math.pi * min(1.0, p * 1.6)) * (1 - p)
    return ({
        "hip": quat_x(14 * absorb),
        "torso": quat_x(10 * absorb),
        "lLeg": quat_x(-22 * absorb), "rLeg": quat_x(-22 * absorb),
        "lShin": quat_x(34 * absorb), "rShin": quat_x(34 * absorb),
        "lArm": quat_x(-15 * absorb), "rArm": quat_x(-15 * absorb),
    }, {"hip": {"x": 0, "y": -0.10 * absorb, "z": 0}})

def celebrate(t, p):
    pump = math.sin(2 * math.pi * t / 0.5)
    return ({
        "torso": quat_x(-8),
        "head": quat_x(-10),
        "rArm": quat_x(-150 - 15 * pump),
        "lArm": quat_z(20 + 10 * pump),
        "hip": quat_x(-4),
    }, {"hip": {"x": 0, "y": max(0.0, 0.06 * pump), "z": 0}})

LIBRARY = [
    ("starter_idle_breathe", "Idle", "locomotion", 3.0, idle_breathe),
    ("starter_jump_charge", "Jump Charge", "dunk", 0.5, jump_charge),
    ("starter_dunk_power", "Power Slam", "dunk", 1.0, dunk_power),
    ("starter_dunk_windmill", "Windmill", "dunk", 1.1, dunk_windmill),
    ("starter_land_recover", "Landing", "dunk", 0.6, land_recover),
    ("starter_celebrate", "Celebration", "reaction", 1.5, celebrate),
]

def main():
    out = Path(sys.argv[1] if len(sys.argv) > 1 else ".")
    out.mkdir(parents=True, exist_ok=True)
    for aid, title, category, duration, build in LIBRARY:
        a = asset(aid, title, category, duration, build)
        path = out / f"{aid}.nexusanim.json"
        json.dump(a, open(path, "w"), indent=1)
        print(f"OK {path.name}: {len(a['keyframes'])} frames / {duration}s")

if __name__ == "__main__":
    main()
